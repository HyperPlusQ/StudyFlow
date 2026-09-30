import EventKit
import Foundation

enum CalendarServiceError: LocalizedError {
    case accessDenied
    case eventCreationFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            #if os(macOS)
            "没有日历访问权限，请在“系统设置 → 隐私与安全性 → 日历”中允许 StudyFlow。"
            #else
            "没有日历访问权限，请在“设置 → 隐私与安全性 → 日历”中允许 StudyFlow。"
            #endif
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

    /// 设置开关打开时调用；系统仅会在权限尚未决定时实际弹出授权提示。
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

    /// 统一处理新建、编辑与完成后的日历状态：
    /// - 已有事件的作业始终更新；完成或失去截止日期时删除事件；
    /// - 尚无事件时，仅在“总是同步”开启时创建。
    func synchronizeAfterAssignmentChange(
        _ assignment: Assignment,
        subjectName: String?
    ) async throws {
        guard alwaysSyncsToSystemCalendar || assignment.calendarEventIdentifier != nil else {
            return
        }
        try await sync(assignment, subjectName: subjectName)
    }

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
        if #available(macOS 14.0, iOS 17.0, *) {
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
