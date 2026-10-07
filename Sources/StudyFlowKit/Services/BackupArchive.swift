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

    /// 以 ZIP Store 方式创建无额外依赖的合法备份包。
    static func create(entries: [Entry]) throws -> Data {
        var localData = Data()
        var centralData = Data()
        var offsets: [Int] = []

        for entry in entries {
            let name = Data(entry.path.utf8)
            let crc = crc32(entry.data)
            let offset = localData.count
            offsets.append(offset)

            var local = Data()
            local.appendLE(localHeaderSignature)
            local.appendLE(UInt16(20))
            local.appendLE(utf8Flag)
            local.appendLE(UInt16(0))
            local.appendLE(dosTime(from: .now))
            local.appendLE(dosDate(from: .now))
            local.appendLE(crc)
            local.appendLE(UInt32(entry.data.count))
            local.appendLE(UInt32(entry.data.count))
            local.appendLE(UInt16(name.count))
            local.appendLE(UInt16(0))
            local.append(name)
            local.append(entry.data)
            localData.append(local)
        }

        let centralOffset = localData.count
        for (index, entry) in entries.enumerated() {
            let name = Data(entry.path.utf8)
            let crc = crc32(entry.data)
            var central = Data()
            central.appendLE(centralHeaderSignature)
            central.appendLE(UInt16(20))
            central.appendLE(UInt16(20))
            central.appendLE(utf8Flag)
            central.appendLE(UInt16(0))
            central.appendLE(dosTime(from: .now))
            central.appendLE(dosDate(from: .now))
            central.appendLE(crc)
            central.appendLE(UInt32(entry.data.count))
            central.appendLE(UInt32(entry.data.count))
            central.appendLE(UInt16(name.count))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt32(0))
            central.appendLE(UInt32(offsets[index]))
            central.append(name)
            centralData.append(central)
        }

        var end = Data()
        end.appendLE(endSignature)
        end.appendLE(UInt16(0))
        end.appendLE(UInt16(0))
        end.appendLE(UInt16(entries.count))
        end.appendLE(UInt16(entries.count))
        end.appendLE(UInt32(centralData.count))
        end.appendLE(UInt32(centralOffset))
        end.appendLE(UInt16(0))

        var archive = Data()
        archive.append(localData)
        archive.append(centralData)
        archive.append(end)
        return archive
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

    private static func crc32(_ data: Data) -> UInt32 {
        var crc = UInt32.max
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
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
