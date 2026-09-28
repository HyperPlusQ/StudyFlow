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
        let data = try encoder.encode(document)
        try data.write(to: url, options: [.atomic])
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
