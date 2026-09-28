import Foundation

enum DueWindow: String, CaseIterable, Identifiable, Sendable {
    case all
    case overdue
    case today
    case week
    case noDate

    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: "全部日期"
        case .overdue: "已逾期"
        case .today: "今天截止"
        case .week: "本周截止"
        case .noDate: "无截止日期"
        }
    }

    func contains(_ date: Date?, reference: Date = .now) -> Bool {
        guard let date else { return self == .noDate }
        if self == .noDate { return false }
        let calendar = Calendar.current
        switch self {
        case .all:
            return true
        case .overdue:
            return date < reference
        case .today:
            return calendar.isDate(date, inSameDayAs: reference)
        case .noDate:
            return false
        case .week:
            guard let week = calendar.date(byAdding: .day, value: 7, to: reference) else { return false }
            return date >= reference && date <= week
        }
    }
}

enum ListScope: String, Hashable, Sendable {
    case today
    case upcoming
    case all
    case completed
    case dashboard

    var title: String {
        switch self {
        case .today: "今天"
        case .upcoming: "即将到期"
        case .all: "所有作业"
        case .completed: "已完成"
        case .dashboard: "仪表盘"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .upcoming: "calendar"
        case .all: "tray.full"
        case .completed: "checkmark.circle"
        case .dashboard: "chart.bar.xaxis"
        }
    }
}

struct AssignmentFilter: Equatable, Sendable {
    var searchText: String = ""
    var subjectId: UUID?
    var dueWindow: DueWindow = .all
    var priority: Priority?
    var hasChecklistOnly = false

    var isDefault: Bool {
        searchText.isEmpty && subjectId == nil && dueWindow == .all && priority == nil && !hasChecklistOnly
    }

    mutating func reset() {
        searchText = ""
        subjectId = nil
        dueWindow = .all
        priority = nil
        hasChecklistOnly = false
    }
}

struct SidebarSelection: Hashable {
    var scope: ListScope
    var subjectId: UUID?
    var parentSubjectId: UUID?

    init(scope: ListScope, subjectId: UUID? = nil, parentSubjectId: UUID? = nil) {
        self.scope = scope
        self.subjectId = subjectId
        self.parentSubjectId = parentSubjectId
    }

    static func subject(_ id: UUID?) -> SidebarSelection {
        SidebarSelection(scope: .all, subjectId: id)
    }
}
