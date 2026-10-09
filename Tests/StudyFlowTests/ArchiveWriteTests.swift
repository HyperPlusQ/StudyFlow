import SwiftData
import XCTest

@testable import StudyFlow

/// 图片附件参与打包/写盘的规则：流式写文件、时间戳语义、替换已有文件。
@MainActor
final class ArchiveWriteTests: XCTestCase {
    private var directory: URL!

    private let imageBytes = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x11, 0x22, 0x33, 0x44])

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyFlowArchiveTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Subject.self,
            Assignment.self,
            Subtask.self,
            ImageAttachment.self,
            TimeBlock.self,
            SubmissionHistoryEntry.self
        ])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }

    @discardableResult
    private func seedAssignment(withAttachmentIn container: ModelContainer) throws -> Assignment {
        let context = ModelContext(container)
        let assignment = Assignment(title: "带图片的作业")
        context.insert(assignment)
        context.insert(
            ImageAttachment(
                fileName: "photo.jpg",
                mimeType: "image/jpeg",
                imageData: imageBytes,
                assignment: assignment
            )
        )
        try context.save()
        return assignment
    }

    /// Foundation 的 JSONEncoder 会把 base64 中的 “/” 转义成 “\/”，比较前先还原。
    private func jsonText(in archive: Data) throws -> String {
        let json = try BackupArchive.readEntry(named: "studyflow.json", from: archive)
        return String(decoding: json, as: UTF8.self).replacingOccurrences(of: "\\/", with: "/")
    }

    func testStreamingWriteMatchesInMemoryCreateSizeAndEntries() throws {
        let entries = [
            BackupArchive.Entry(path: "studyflow.json", data: Data("{\"format\":\"StudyFlow\"}".utf8)),
            BackupArchive.Entry(path: "attachments/A/I.jpg", data: imageBytes)
        ]

        let inMemory = try BackupArchive.create(entries: entries)
        let fileURL = directory.appendingPathComponent("stream.zip")
        try BackupArchive.write(entries: entries, to: fileURL)
        let streamed = try Data(contentsOf: fileURL)

        // 两个实现只在 DOS 时间字段上有差异，长度与条目内容必须一致。
        XCTAssertEqual(streamed.count, inMemory.count)
        XCTAssertEqual(
            try BackupArchive.readEntry(named: "studyflow.json", from: streamed),
            try BackupArchive.readEntry(named: "studyflow.json", from: inMemory)
        )
        XCTAssertEqual(
            try BackupArchive.readEntry(named: "attachments/A/I.jpg", from: streamed),
            imageBytes
        )
    }

    func testWriteArchiveStreamsAttachmentBytesAndSetsTimestamp() throws {
        let container = try makeContainer()
        try seedAssignment(withAttachmentIn: container)

        let url = directory.appendingPathComponent("StudyFlow-Sync.zip")
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        try DataExportService.writeArchive(
            context: ModelContext(container),
            to: url,
            modificationDate: stamp
        )

        let archive = try Data(contentsOf: url)
        XCTAssertTrue(
            try jsonText(in: archive).contains(imageBytes.base64EncodedString()),
            "写盘的 ZIP 必须包含图片的 Base64 数据"
        )

        let assignmentID = try ModelContext(container).fetch(FetchDescriptor<Assignment>())[0].id
        let attachmentID = try ModelContext(container).fetch(FetchDescriptor<ImageAttachment>())[0].id
        let entryPath = BackupArchive.path(
            forAttachment: attachmentID,
            assignmentID: assignmentID,
            mimeType: "image/jpeg"
        )
        XCTAssertEqual(try BackupArchive.readEntry(named: entryPath, from: archive), imageBytes)

        let written = try DataExportService.modificationDate(of: url)
        XCTAssertEqual(written.timeIntervalSince1970.rounded(), stamp.timeIntervalSince1970.rounded())
    }

    func testWriteArchiveReplacesExistingFile() throws {
        let container = try makeContainer()
        try seedAssignment(withAttachmentIn: container)
        let url = directory.appendingPathComponent("StudyFlow-Sync.zip")

        try DataExportService.writeArchive(context: ModelContext(container), to: url, modificationDate: .now)
        let firstSize = try Data(contentsOf: url).count

        // 再写一次必须替换旧文件，而不是失败或留下临时文件。
        try DataExportService.writeArchive(context: ModelContext(container), to: url, modificationDate: .now)
        XCTAssertEqual(try Data(contentsOf: url).count, firstSize)

        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".tmp") }
        XCTAssertTrue(leftovers.isEmpty, "临时文件必须被清理：\(leftovers)")
    }

    func testTouchModificationDateRefreshesExistingFileOnly() throws {
        let url = directory.appendingPathComponent("mirror.zip")
        try Data("x".utf8).write(to: url)
        let oldDate = Date(timeIntervalSince1970: 1_000_000_000)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: url.path)

        try DataExportService.touchModificationDate(at: url)
        XCTAssertGreaterThan(
            try DataExportService.modificationDate(of: url),
            oldDate,
            "保存/导入后必须刷新比较时间戳，否则本地改动不会上传"
        )

        let missing = directory.appendingPathComponent("missing.zip")
        XCTAssertThrowsError(try DataExportService.touchModificationDate(at: missing))
    }
}
