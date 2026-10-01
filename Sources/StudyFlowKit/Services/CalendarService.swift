import EventKit
import Foundation

enum CalendarServiceError: LocalizedError {
    case accessDenied
    case eventCreationFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "没有日历访问权限，请在“设置 → 隐私与安全性 → 日历”中允许 StudyFlow。"
        case .eventCreationFailed: "无法创建或更新日历事件。"
        case .unknown: "日历同步发生未知错误。"
        }
    }
}

@MainActor
final class CalendarService {
    static let shared = CalendarService()
    static let alwaysSyncDefaultsKey = "StudyFlow.alwaysSyncCalendar"

    private let store = EKEventStore()
    private let defaults = UserDefaults.standard
    private init() {}

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var alwaysSyncsToSystemCalendar: Bool {
        get { defaults.bool(forKey: Self.alwaysSyncDefaultsKey) }
        set { defaults.set(newValue, forKey: Self.alwaysSyncDefaultsKey) }
    }

    /// 打开自动同步开关时请求日历权限。
    func requestAccessForAutomaticSync() async throws {
        switch authorizationStatus {
        case .fullAccess, .writeOnly:
            return
        case .notDetermined:
            guard try await requestAccess() else {
                throw CalendarServiceError.accessDenied
            }
        default:
            throw CalendarServiceError.accessDenied
        }
    }

    /// 作业变化后自动创建、更新或删除日历事件。
    func synchronizeAfterAssignmentChange(
        _ assignment: Assignment,
        subjectName: String?
    ) async throws {
        guard alwaysSyncsToSystemCalendar || assignment.calendarEventIdentifier != nil else {
            return
        }
        try await sync(assignment, subjectName: subjectName)
    }

    /// 将作业状态同步到系统日历。
    func sync(_ assignment: Assignment, subjectName: String?) async throws {
        guard !assignment.isCompleted, let due = assignment.dueDate else {
            if assignment.calendarEventIdentifier != nil {
                try removeEvent(for: assignment)
            }
            return
        }

        guard try await ensureAccess() else {
            throw CalendarServiceError.accessDenied
        }

        let existingEvent = assignment.calendarEventIdentifier.flatMap { store.event(withIdentifier: $0) }
        let event = existingEvent ?? EKEvent(eventStore: store)

        if existingEvent == nil {
            guard let calendar = store.defaultCalendarForNewEvents else {
                throw CalendarServiceError.eventCreationFailed
            }
            event.calendar = calendar
        }

        event.title = assignment.title
        event.notes = [
            subjectName.map { "科目：\($0)" },
            assignment.submissionMethod.isEmpty ? nil : "提交方式：\(assignment.submissionMethod)",
            assignment.details.isEmpty ? nil : assignment.details
        ].compactMap { $0 }.joined(separator: "\n")
        event.startDate = due.addingTimeInterval(-3600)
        event.endDate = due
        event.isAllDay = false

        // 更新已有事件时重建提醒，避免每次编辑都叠加重复警报。
        event.alarms?.forEach { event.removeAlarm($0) }
        event.addAlarm(EKAlarm(relativeOffset: -86400))

        try store.save(event, span: .thisEvent)
        assignment.calendarEventIdentifier = event.eventIdentifier
    }

    /// 删除作业已关联的系统日历事件。
    func removeEvent(for assignment: Assignment) throws {
        guard let id = assignment.calendarEventIdentifier else { return }

        if let event = store.event(withIdentifier: id) {
            try store.remove(event, span: .thisEvent)
        }
        assignment.calendarEventIdentifier = nil
    }

    private func ensureAccess() async throws -> Bool {
        switch authorizationStatus {
        case .fullAccess, .writeOnly:
            return true
        case .notDetermined:
            return try await requestAccess()
        default:
            return false
        }
    }

    private func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await withCheckedThrowingContinuation { continuation in
                store.requestFullAccessToEvents { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
}
