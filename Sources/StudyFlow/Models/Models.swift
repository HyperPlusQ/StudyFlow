import Foundation
import SwiftData

enum AssignmentStatus: String, Codable, CaseIterable, Sendable {
    case active
    case completed
}

enum Priority: Int, Codable, CaseIterable, Identifiable, Sendable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .low: "低"
        case .medium: "中"
        case .high: "高"
        case .critical: "紧急"
        }
    }
    var symbol: String {
        switch self {
        case .low: "arrow.down"
        case .medium: "equal"
        case .high: "exclamationmark"
        case .critical: "exclamationmark.2"
        }
    }
}

@Model
final class Subject {
    @Attribute(.unique) var id: UUID
    var name: String
    var symbol: String
    var colorHex: String
    var parentId: UUID?
    var sortOrder: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String = "book.closed",
        colorHex: String = "#4F7DF3",
        parentId: UUID? = nil,
        sortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.parentId = parentId
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

@Model
final class Assignment {
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String
    var dueDate: Date?
    var submissionMethod: String
    var subjectId: UUID?
    var priorityRaw: Int
    var statusRaw: String
    var weight: Int
    var reminderLeadHours: Int
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var calendarEventIdentifier: String?

    @Relationship(deleteRule: .cascade, inverse: \Subtask.assignment)
    var subtasks: [Subtask]

    init(
        id: UUID = UUID(),
        title: String,
        details: String = "",
        dueDate: Date? = nil,
        submissionMethod: String = "",
        subjectId: UUID? = nil,
        priority: Priority = .medium,
        status: AssignmentStatus = .active,
        weight: Int = 3,
        reminderLeadHours: Int = 24,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        completedAt: Date? = nil,
        calendarEventIdentifier: String? = nil,
        subtasks: [Subtask] = []
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.dueDate = dueDate
        self.submissionMethod = submissionMethod
        self.subjectId = subjectId
        self.priorityRaw = priority.rawValue
        self.statusRaw = status.rawValue
        self.weight = weight
        self.reminderLeadHours = reminderLeadHours
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.calendarEventIdentifier = calendarEventIdentifier
        self.subtasks = subtasks
    }

    var status: AssignmentStatus {
        get { AssignmentStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var isCompleted: Bool { status == .completed }

    var completedCount: Int { subtasks.filter(\.isCompleted).count }

    var progress: Double {
        guard !subtasks.isEmpty else { return isCompleted ? 1 : 0 }
        return Double(completedCount) / Double(subtasks.count)
    }
}

@Model
final class Subtask {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var sortOrder: Int
    var assignment: Assignment?

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        assignment: Assignment? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.assignment = assignment
    }
}

@Model
final class TimeBlock {
    @Attribute(.unique) var id: UUID
    var title: String
    var assignmentId: UUID?
    var subjectId: UUID?
    var startDate: Date
    var durationMinutes: Int
    var notes: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        assignmentId: UUID? = nil,
        subjectId: UUID? = nil,
        startDate: Date,
        durationMinutes: Int = 60,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.assignmentId = assignmentId
        self.subjectId = subjectId
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.createdAt = createdAt
    }

    var endDate: Date { startDate.addingTimeInterval(TimeInterval(durationMinutes * 60)) }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? self
    }

    func isInSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
