import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers

enum DataExportService {
    enum Destination: Sendable {
        case anywhere
        case iCloudDrive

        var title: String {
            switch self {
            case .anywhere: "导出 StudyFlow 数据"
            case .iCloudDrive: "导出 StudyFlow 数据到 iCloud 云盘"
            }
        }
    }

    private struct ExportDocument: Codable {
        let format: String
        let formatVersion: Int
        let exportedAt: Date
        let subjects: [SubjectRecord]
        let assignments: [AssignmentRecord]
        let timeBlocks: [TimeBlockRecord]
        let submissionHistory: [SubmissionHistoryRecord]
    }

    private struct SubjectRecord: Codable {
        let id: UUID
        let name: String
        let symbol: String
        let colorHex: String
        let parentId: UUID?
        let sortOrder: Int
        let createdAt: Date
    }

    private struct AssignmentRecord: Codable {
        let id: UUID
        let title: String
        let details: String
        let dueDate: Date?
        let submissionMethod: String
        let subjectId: UUID?
        let priority: Int
        let status: String
        let weight: Int
        let reminderLeadHours: Int
        let createdAt: Date
        let updatedAt: Date
        let completedAt: Date?
        let calendarEventIdentifier: String?
        let subtasks: [SubtaskRecord]
    }

    private struct SubtaskRecord: Codable {
        let id: UUID
        let title: String
        let isCompleted: Bool
        let sortOrder: Int
    }

    private struct TimeBlockRecord: Codable {
        let id: UUID
        let title: String
        let assignmentId: UUID?
        let subjectId: UUID?
        let startDate: Date
        let durationMinutes: Int
        let notes: String
        let createdAt: Date
    }

    private struct SubmissionHistoryRecord: Codable {
        let id: UUID
        let subjectId: UUID
        let value: String
        let lastUsedAt: Date
    }

    @MainActor
    static func export(
        subjects: [Subject],
        assignments: [Assignment],
        timeBlocks: [TimeBlock],
        submissionHistory: [SubmissionHistoryEntry],
        destination: Destination
    ) throws {
        guard let url = chooseDestination(for: destination) else { return }
        let data = try encodedDocument(
            subjects: subjects,
            assignments: assignments,
            timeBlocks: timeBlocks,
            submissionHistory: submissionHistory
        )
        try write(data, to: url)
    }

    @MainActor
    static func currentData(context: ModelContext) throws -> Data {
        try encodedDocument(
            subjects: try context.fetch(FetchDescriptor<Subject>()),
            assignments: try context.fetch(FetchDescriptor<Assignment>()),
            timeBlocks: try context.fetch(FetchDescriptor<TimeBlock>()),
            submissionHistory: try context.fetch(FetchDescriptor<SubmissionHistoryEntry>())
        )
    }

    /// Decodes and validates a complete snapshot before making any destructive database change.
    @MainActor
    static func restore(data: Data, into context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(ExportDocument.self, from: data)
        try validate(document)

        let previousAssignments = (try? context.fetch(FetchDescriptor<Assignment>())) ?? []
        previousAssignments.forEach { NotificationManager.shared.cancel(for: $0.id) }

        ((try? context.fetch(FetchDescriptor<TimeBlock>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<Assignment>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<Subject>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<SubmissionHistoryEntry>())) ?? []).forEach { context.delete($0) }

        document.subjects.forEach { record in
            context.insert(
                Subject(
                    id: record.id,
                    name: record.name,
                    symbol: record.symbol,
                    colorHex: record.colorHex,
                    parentId: record.parentId,
                    sortOrder: record.sortOrder,
                    createdAt: record.createdAt
                )
            )
        }

        document.assignments.forEach { record in
            let assignment = Assignment(
                id: record.id,
                title: record.title,
                details: record.details,
                dueDate: record.dueDate,
                submissionMethod: record.submissionMethod,
                subjectId: record.subjectId,
                weight: record.weight,
                reminderLeadHours: record.reminderLeadHours,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                completedAt: record.completedAt,
                calendarEventIdentifier: record.calendarEventIdentifier
            )
            assignment.priorityRaw = record.priority
            assignment.statusRaw = record.status
            assignment.subtasks = record.subtasks
                .sorted { $0.sortOrder < $1.sortOrder }
                .map {
                    Subtask(
                        id: $0.id,
                        title: $0.title,
                        isCompleted: $0.isCompleted,
                        sortOrder: $0.sortOrder,
                        assignment: assignment
                    )
                }
            context.insert(assignment)
        }

        document.timeBlocks.forEach { record in
            context.insert(
                TimeBlock(
                    id: record.id,
                    title: record.title,
                    assignmentId: record.assignmentId,
                    subjectId: record.subjectId,
                    startDate: record.startDate,
                    durationMinutes: record.durationMinutes,
                    notes: record.notes,
                    createdAt: record.createdAt
                )
            )
        }

        document.submissionHistory.forEach { record in
            context.insert(
                SubmissionHistoryEntry(
                    id: record.id,
                    subjectId: record.subjectId,
                    value: record.value,
                    lastUsedAt: record.lastUsedAt
                )
            )
        }

        try context.save()
        WidgetSnapshotService.refresh(context: context)

        ((try? context.fetch(FetchDescriptor<Assignment>())) ?? []).forEach {
            NotificationManager.shared.schedule(for: $0)
        }
    }

    static func write(_ data: Data, to url: URL, modificationDate: Date? = nil) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic])
        if let modificationDate {
            try FileManager.default.setAttributes(
                [.modificationDate: modificationDate],
                ofItemAtPath: url.path
            )
        }
    }

    static func modificationDate(of url: URL) throws -> Date {
        guard let date = try url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate else {
            throw SyncFileError.missingModificationDate
        }
        return date
    }

    private static func encodedDocument(
        subjects: [Subject],
        assignments: [Assignment],
        timeBlocks: [TimeBlock],
        submissionHistory: [SubmissionHistoryEntry]
    ) throws -> Data {
        let document = ExportDocument(
            format: "StudyFlow",
            formatVersion: 1,
            exportedAt: .now,
            subjects: subjects
                .sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
                .map {
                    SubjectRecord(
                        id: $0.id,
                        name: $0.name,
                        symbol: $0.symbol,
                        colorHex: $0.colorHex,
                        parentId: $0.parentId,
                        sortOrder: $0.sortOrder,
                        createdAt: $0.createdAt
                    )
                },
            assignments: assignments
                .sorted { $0.createdAt < $1.createdAt }
                .map {
                    AssignmentRecord(
                        id: $0.id,
                        title: $0.title,
                        details: $0.details,
                        dueDate: $0.dueDate,
                        submissionMethod: $0.submissionMethod,
                        subjectId: $0.subjectId,
                        priority: $0.priorityRaw,
                        status: $0.statusRaw,
                        weight: $0.weight,
                        reminderLeadHours: $0.reminderLeadHours,
                        createdAt: $0.createdAt,
                        updatedAt: $0.updatedAt,
                        completedAt: $0.completedAt,
                        calendarEventIdentifier: $0.calendarEventIdentifier,
                        subtasks: $0.subtasks
                            .sorted { $0.sortOrder < $1.sortOrder }
                            .map {
                                SubtaskRecord(
                                    id: $0.id,
                                    title: $0.title,
                                    isCompleted: $0.isCompleted,
                                    sortOrder: $0.sortOrder
                                )
                            }
                    )
                },
            timeBlocks: timeBlocks
                .sorted { $0.startDate < $1.startDate }
                .map {
                    TimeBlockRecord(
                        id: $0.id,
                        title: $0.title,
                        assignmentId: $0.assignmentId,
                        subjectId: $0.subjectId,
                        startDate: $0.startDate,
                        durationMinutes: $0.durationMinutes,
                        notes: $0.notes,
                        createdAt: $0.createdAt
                    )
                },
            submissionHistory: submissionHistory
                .sorted { $0.lastUsedAt > $1.lastUsedAt }
                .map {
                    SubmissionHistoryRecord(
                        id: $0.id,
                        subjectId: $0.subjectId,
                        value: $0.value,
                        lastUsedAt: $0.lastUsedAt
                    )
                }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    private static func validate(_ document: ExportDocument) throws {
        guard document.format == "StudyFlow" else {
            throw SyncFileError.unsupportedFormat
        }
        guard document.formatVersion == 1 else {
            throw SyncFileError.unsupportedVersion(document.formatVersion)
        }
        try requireUniqueIDs(document.subjects.map(\.id))
        try requireUniqueIDs(document.assignments.map(\.id))
        try requireUniqueIDs(document.timeBlocks.map(\.id))
        try requireUniqueIDs(document.submissionHistory.map(\.id))

        let subjectIDs = Set(document.subjects.map(\.id))
        for subject in document.subjects {
            if let parentID = subject.parentId {
                guard subjectIDs.contains(parentID) else {
                    throw SyncFileError.invalidSubjectHierarchy(subject.id)
                }
            }
        }

        try requireUniqueIDs(document.assignments.flatMap(\.subtasks).map(\.id))

        let assignmentIDs = Set(document.assignments.map(\.id))
        for assignment in document.assignments {
            if let subjectID = assignment.subjectId {
                guard subjectIDs.contains(subjectID) else {
                    throw SyncFileError.invalidSubjectReference(assignment.id)
                }
            }
        }
        for block in document.timeBlocks {
            if let assignmentID = block.assignmentId {
                guard assignmentIDs.contains(assignmentID) else {
                    throw SyncFileError.invalidAssignmentReference(block.id)
                }
            }
            if let subjectID = block.subjectId {
                guard subjectIDs.contains(subjectID) else {
                    throw SyncFileError.invalidSubjectReference(block.id)
                }
            }
        }
    }

    private static func requireUniqueIDs(_ ids: [UUID]) throws {
        guard Set(ids).count == ids.count else {
            throw SyncFileError.duplicateIdentifier
        }
    }

    @MainActor
    private static func chooseDestination(for destination: Destination) -> URL? {
        let panel = NSSavePanel()
        panel.title = destination.title
        panel.message = destination == .iCloudDrive
            ? "确认文件名为 StudyFlow 备份，然后保存到 iCloud 云盘。"
            : "可选择本机文件夹或 iCloud 云盘作为备份位置。"
        panel.prompt = "导出"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "StudyFlow-Backup-\(Self.dateStamp()).json"

        if destination == .iCloudDrive {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        }

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: .now)
    }
}

enum SyncFileError: LocalizedError {
    case missingModificationDate
    case unsupportedFormat
    case unsupportedVersion(Int)
    case duplicateIdentifier
    case invalidSubjectHierarchy(UUID)
    case invalidSubjectReference(UUID)
    case invalidAssignmentReference(UUID)

    var errorDescription: String? {
        switch self {
        case .missingModificationDate:
            "无法读取同步文件的修改时间。"
        case .unsupportedFormat:
            "所选文件不是 StudyFlow 数据快照。"
        case .unsupportedVersion(let version):
            "StudyFlow 快照版本 \(version) 不受当前应用支持。"
        case .duplicateIdentifier:
            "StudyFlow 快照包含重复的数据标识。"
        case .invalidSubjectHierarchy(let id):
            "科目快照 \(id.uuidString) 的上级科目不存在。"
        case .invalidSubjectReference(let id):
            "记录 \(id.uuidString) 引用了不存在的科目。"
        case .invalidAssignmentReference(let id):
            "记录 \(id.uuidString) 引用了不存在的作业。"
        }
    }
}
