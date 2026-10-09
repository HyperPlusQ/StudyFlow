import Foundation

/// 生成并读取 StudyFlow 的 ZIP 备份；图片与 JSON 一并封装，兼容 iOS 沙盒。
enum BackupArchive {
    struct Entry: Sendable {
        let path: String
        let data: Data
    }

    private static let localHeaderSignature: UInt32 = 0x0403_4B50
    private static let centralHeaderSignature: UInt32 = 0x0201_4B50
    private static let endSignature: UInt32 = 0x0605_4B50
    private static let utf8Flag: UInt16 = 0x0800

    /// 标准 CRC-32（IEEE 反射式）查表实现：与逐位算法结果一致，速度快一个数量级。
    private static let crcTable: [UInt32] = makeCRCTable()

    private static func makeCRCTable() -> [UInt32] {
        (0..<256).map { index in
            var value = UInt32(index)
            for _ in 0..<8 {
                value = (value & 1) == 1 ? (value >> 1) ^ 0xEDB8_8320 : value >> 1
            }
            return value
        }
    }

    /// 以 ZIP Store 方式创建无额外依赖的合法备份包。
    static func create(entries: [Entry]) throws -> Data {
        var localData = Data()
        var centralData = Data()
        var offsets: [Int] = []
        var checksums: [UInt32] = []

        for entry in entries {
            let crc = crc32(entry.data)
            offsets.append(localData.count)
            checksums.append(crc)
            localData.append(localHeader(for: entry, crc: crc))
            localData.append(entry.data)
        }

        let centralOffset = localData.count
        for (index, entry) in entries.enumerated() {
            centralData.append(
                centralHeader(for: entry, crc: checksums[index], offset: offsets[index])
            )
        }

        let end = endRecord(
            entryCount: entries.count,
            centralSize: centralData.count,
            centralOffset: centralOffset
        )

        var archive = Data()
        archive.append(localData)
        archive.append(centralData)
        archive.append(end)
        return archive
    }

    /// 把条目直接流式写入 ZIP 文件，避免在内存里再拼一份同样大小的归档。
    /// 附件很多时，这一步能显著降低同步的峰值内存。
    static func write(entries: [Entry], to url: URL) throws {
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let tempURL = directory
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        guard fileManager.createFile(atPath: tempURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let handle = try FileHandle(forWritingTo: tempURL)
        do {
            var offset = 0
            var offsets: [Int] = []
            var checksums: [UInt32] = []
            for entry in entries {
                let crc = crc32(entry.data)
                let header = localHeader(for: entry, crc: crc)
                offsets.append(offset)
                checksums.append(crc)
                try handle.write(contentsOf: header)
                try handle.write(contentsOf: entry.data)
                offset += header.count + entry.data.count
            }

            let centralOffset = offset
            var centralSize = 0
            for (index, entry) in entries.enumerated() {
                let header = centralHeader(for: entry, crc: checksums[index], offset: offsets[index])
                try handle.write(contentsOf: header)
                centralSize += header.count
            }

            try handle.write(contentsOf: endRecord(
                entryCount: entries.count,
                centralSize: centralSize,
                centralOffset: centralOffset
            ))
            try handle.close()
        } catch {
            try? handle.close()
            try? fileManager.removeItem(at: tempURL)
            throw error
        }

        do {
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: url)
            }
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw error
        }
    }

    /// 从 StudyFlow ZIP 中读取指定条目；只支持本应用生成的 Store 归档。
    static func readEntry(named path: String, from archive: Data) throws -> Data {
        var cursor = 0
        while cursor + 4 <= archive.count {
            let signature = archive.readUInt32(at: cursor)
            if signature == centralHeaderSignature || signature == endSignature { break }
            guard signature == localHeaderSignature, cursor + 30 <= archive.count else {
                throw BackupArchiveError.invalidArchive
            }

            let flags = archive.readUInt16(at: cursor + 6)
            let method = archive.readUInt16(at: cursor + 8)
            let compressedSize = Int(archive.readUInt32(at: cursor + 18))
            let uncompressedSize = Int(archive.readUInt32(at: cursor + 22))
            let nameLength = Int(archive.readUInt16(at: cursor + 26))
            let extraLength = Int(archive.readUInt16(at: cursor + 28))
            let nameStart = cursor + 30
            let dataStart = nameStart + nameLength + extraLength
            guard dataStart + compressedSize <= archive.count else {
                throw BackupArchiveError.invalidArchive
            }

            let nameEnd = nameStart + nameLength
            let name = String(decoding: archive[nameStart..<nameEnd], as: UTF8.self)
            let payloadStart = dataStart
            let payloadEnd = dataStart + compressedSize
            defer { cursor = payloadEnd }

            guard name == path else {
                if flags & 0x08 != 0 && compressedSize == 0 { throw BackupArchiveError.unsupportedEntry }
                continue
            }
            guard method == 0, compressedSize == uncompressedSize else {
                throw BackupArchiveError.unsupportedEntry
            }
            let payload = archive[payloadStart..<payloadEnd]
            guard crc32(payload) == archive.readUInt32(at: cursor + 14) else {
                throw BackupArchiveError.checksumMismatch
            }
            return Data(payload)
        }
        throw BackupArchiveError.entryNotFound
    }

    static func isArchive(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        return data.readUInt32(at: 0) == localHeaderSignature
    }

    static func path(forAttachment attachmentID: UUID, assignmentID: UUID, mimeType: String) -> String {
        "attachments/\(assignmentID.uuidString)/\(attachmentID.uuidString).\(fileExtension(for: mimeType))"
    }

    static func fileExtension(for mimeType: String) -> String {
        switch mimeType.lowercased() {
        case "image/png": "png"
        case "image/heic", "image/heif": "heic"
        case "image/gif": "gif"
        case "image/webp": "webp"
        case "image/bmp": "bmp"
        default: "jpg"
        }
    }

    // MARK: - ZIP 头部构造（create 与 write 共用，保证两种写法字节一致）

    private static func localHeader(for entry: Entry, crc: UInt32) -> Data {
        let name = Data(entry.path.utf8)
        var header = Data()
        header.appendLE(localHeaderSignature)
        header.appendLE(UInt16(20))
        header.appendLE(utf8Flag)
        header.appendLE(UInt16(0))
        header.appendLE(dosTime(from: .now))
        header.appendLE(dosDate(from: .now))
        header.appendLE(crc)
        header.appendLE(UInt32(entry.data.count))
        header.appendLE(UInt32(entry.data.count))
        header.appendLE(UInt16(name.count))
        header.appendLE(UInt16(0))
        header.append(name)
        return header
    }

    private static func centralHeader(for entry: Entry, crc: UInt32, offset: Int) -> Data {
        let name = Data(entry.path.utf8)
        var header = Data()
        header.appendLE(centralHeaderSignature)
        header.appendLE(UInt16(20))
        header.appendLE(UInt16(20))
        header.appendLE(utf8Flag)
        header.appendLE(UInt16(0))
        header.appendLE(dosTime(from: .now))
        header.appendLE(dosDate(from: .now))
        header.appendLE(crc)
        header.appendLE(UInt32(entry.data.count))
        header.appendLE(UInt32(entry.data.count))
        header.appendLE(UInt16(name.count))
        header.appendLE(UInt16(0))
        header.appendLE(UInt16(0))
        header.appendLE(UInt16(0))
        header.appendLE(UInt16(0))
        header.appendLE(UInt32(0))
        header.appendLE(UInt32(offset))
        header.append(name)
        return header
    }

    private static func endRecord(entryCount: Int, centralSize: Int, centralOffset: Int) -> Data {
        var end = Data()
        end.appendLE(endSignature)
        end.appendLE(UInt16(0))
        end.appendLE(UInt16(0))
        end.appendLE(UInt16(entryCount))
        end.appendLE(UInt16(entryCount))
        end.appendLE(UInt32(centralSize))
        end.appendLE(UInt32(centralOffset))
        end.appendLE(UInt16(0))
        return end
    }

    // MARK: - 校验与时序

    private static func crc32(_ data: Data) -> UInt32 {
        var crc = UInt32.max
        data.withUnsafeBytes { rawBuffer in
            for byte in rawBuffer.bindMemory(to: UInt8.self) {
                crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
            }
        }
        return crc ^ UInt32.max
    }

    private static func dosTime(from date: Date) -> UInt16 {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return UInt16(((components.hour ?? 0) << 11)
            | ((components.minute ?? 0) << 5)
            | ((components.second ?? 0) / 2))
    }

    private static func dosDate(from date: Date) -> UInt16 {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = max(components.year ?? 1980, 1980)
        return UInt16(((year - 1980) << 9) | ((components.month ?? 1) << 5) | (components.day ?? 1))
    }
}

enum BackupArchiveError: LocalizedError {
    case invalidArchive
    case unsupportedEntry
    case checksumMismatch
    case entryNotFound

    var errorDescription: String? {
        switch self {
        case .invalidArchive: "ZIP 备份结构损坏。"
        case .unsupportedEntry: "ZIP 备份包含当前版本不支持的压缩方式。"
        case .checksumMismatch: "ZIP 备份校验失败，文件可能已损坏。"
        case .entryNotFound: "ZIP 备份中缺少 studyflow.json。"
        }
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    func readUInt16(at offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= count else { return 0 }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func readUInt32(at offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= count else { return 0 }
        return UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }
}
