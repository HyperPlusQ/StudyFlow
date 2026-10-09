import SwiftData
import XCTest

@testable import StudyFlow

/// iCloud 同步与普通导出共用同一套 ZIP 打包/恢复核心，
/// 这里锁定“图片附件必须随同步文件来回”的行为。
@MainActor
final class AttachmentBackupTests: XCTestCase {
    private let imageBytes = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02, 0x03, 0x04, 0x05])

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

    /// Foundation 的 JSONEncoder 会把 base64 中的 “/” 转义成 “\/”，比较前先还原。
    private func jsonText(from backup: Data) throws -> String {
        let json = try BackupArchive.readEntry(named: "studyflow.json", from: backup)
        return String(decoding: json, as: UTF8.self).replacingOccurrences(of: "\\/", with: "/")
    }

    @discardableResult
    private func seedAssignment(withAttachmentIn container: ModelContainer) throws -> (assignmentID: UUID, attachmentID: UUID) {
        let context = ModelContext(container)
        let assignment = Assignment(title: "带图片的作业")
        context.insert(assignment)
        let attachment = ImageAttachment(
            fileName: "photo.jpg",
            mimeType: "image/jpeg",
            imageData: imageBytes,
            assignment: assignment
        )
        context.insert(attachment)
        try context.save()
        return (assignment.id, attachment.id)
    }

    func testBackupCarriesAttachmentBytesInJsonAndZipEntry() throws {
        let container = try makeContainer()
        let ids = try seedAssignment(withAttachmentIn: container)

        let backup = try DataExportService.makeBackup(context: ModelContext(container))

        XCTAssertTrue(BackupArchive.isArchive(backup))
        XCTAssertTrue(
            try jsonText(from: backup).contains(imageBytes.base64EncodedString()),
            "同步 ZIP 的 JSON 必须内嵌图片数据"
        )

        let entryPath = BackupArchive.path(
            forAttachment: ids.attachmentID,
            assignmentID: ids.assignmentID,
            mimeType: "image/jpeg"
        )
        XCTAssertEqual(
            try BackupArchive.readEntry(named: entryPath, from: backup),
            imageBytes,
            "同步 ZIP 必须包含原始图片文件条目"
        )
    }

    func testRestorePersistsAttachments() throws {
        let source = try makeContainer()
        try seedAssignment(withAttachmentIn: source)
        let backup = try DataExportService.makeBackup(context: ModelContext(source))

        let target = try makeContainer()
        try DataExportService.restore(data: backup, into: ModelContext(target))

        let context = ModelContext(target)
        let assignments = try context.fetch(FetchDescriptor<Assignment>())
        XCTAssertEqual(assignments.count, 1)
        XCTAssertEqual(assignments.first?.attachments.count, 1, "作业关系中必须保留附件")

        let stored = try context.fetch(FetchDescriptor<ImageAttachment>())
        XCTAssertEqual(stored.count, 1, "附件对象必须真正写入数据库")
        XCTAssertEqual(stored.first?.imageData, imageBytes)
    }

    func testSyncRoundTripKeepsAttachments() throws {
        // 模拟 iCloud 同步的两个方向：导出 → 另一端恢复 → 再导出。
        let source = try makeContainer()
        try seedAssignment(withAttachmentIn: source)
        let first = try DataExportService.makeBackup(context: ModelContext(source))

        let target = try makeContainer()
        try DataExportService.restore(data: first, into: ModelContext(target))
        let second = try DataExportService.makeBackup(context: ModelContext(target))

        XCTAssertTrue(
            try jsonText(from: second).contains(imageBytes.base64EncodedString()),
            "同步来回之后图片数据不能丢失"
        )
    }

    func testBackupAfterAttachmentChangeReflectsLatestImage() throws {
        let container = try makeContainer()
        let assignmentID = try seedAssignment(withAttachmentIn: container).assignmentID

        // 追加第二张图，模拟用户保存新附件后刷新本地同步镜像。
        let context = ModelContext(container)
        let assignment = try context.fetch(FetchDescriptor<Assignment>())
            .first { $0.id == assignmentID }
        let extraBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0A, 0x1A, 0x0A, 0x07])
        let extra = ImageAttachment(
            fileName: "second.png",
            mimeType: "image/png",
            imageData: extraBytes,
            assignment: assignment
        )
        context.insert(extra)
        try context.save()

        let backup = try DataExportService.makeBackup(context: ModelContext(container))
        let text = try jsonText(from: backup)
        XCTAssertTrue(text.contains(imageBytes.base64EncodedString()))
        XCTAssertTrue(text.contains(extraBytes.base64EncodedString()), "新增图片必须进入下一次同步包")
    }
}
