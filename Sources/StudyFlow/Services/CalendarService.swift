import EventKit
import Foundation

enum CalendarServiceError: LocalizedError {
    case accessDenied
    case eventCreationFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .accessDenied: "没有日历访问权限，请在“系统设置 → 隐私与安全性 → 日历”中允许 StudyFlow。"
        case .eventCreationFailed: "无法创建日历事件。"
        case .unknown: "日历同步发生未知错误。"
        }
    }
}

@MainActor
final class CalendarService {
    static let shared = CalendarService()
    private let store = EKEventStore()
    private init() {}

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func sync(_ assignment: Assignment, subjectName: String?) async throws {
        guard let due = assignment.dueDate else {
            throw CalendarServiceError.eventCreationFailed
        }

        let hasAccess: Bool
        if #available(macOS 14.0, *) {
            switch authorizationStatus {
            case .fullAccess, .writeOnly:
                hasAccess = true
            default:
                hasAccess = try await requestAccess()
            }
        } else {
            hasAccess = authorizationStatus == .authorized ? true : try await requestAccess()
        }
        guard hasAccess else { throw CalendarServiceError.accessDenied }

        let event: EKEvent
        if let id = assignment.calendarEventIdentifier, let existing = store.event(withIdentifier: id) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
        }

        event.title = assignment.title
        event.notes = [
            subjectName.map { "科目：\($0)" },
            assignment.submissionMethod.isEmpty ? nil : "提交方式：\(assignment.submissionMethod)",
            assignment.details.isEmpty ? nil : assignment.details
        ].compactMap { $0 }.joined(separator: "\n")
        event.calendar = store.defaultCalendarForNewEvents
        event.startDate = due.addingTimeInterval(-3600)
        event.endDate = due
        event.addAlarm(EKAlarm(relativeOffset: -86400))

        try store.save(event, span: .thisEvent)
        assignment.calendarEventIdentifier = event.eventIdentifier
    }

    func removeEvent(for assignment: Assignment) throws {
        guard let id = assignment.calendarEventIdentifier,
              let event = store.event(withIdentifier: id)
        else { return }
        try store.remove(event, span: .thisEvent)
        assignment.calendarEventIdentifier = nil
    }

    private func requestAccess() async throws -> Bool {
        if #available(macOS 14.0, *) {
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
