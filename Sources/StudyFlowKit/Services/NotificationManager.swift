import Foundation
import UserNotifications

final class NotificationManager: @unchecked Sendable {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            NSLog("StudyFlow notification authorization failed: \(error.localizedDescription)")
        }
    }

    func schedule(for assignment: Assignment) {
        cancel(for: assignment.id)
        guard !assignment.isCompleted,
              let due = assignment.dueDate,
              let triggerDate = Calendar.current.date(
                byAdding: .hour,
                value: -assignment.reminderLeadHours,
                to: due
              ),
              triggerDate > .now
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "作业即将截止"
        content.body = "\(assignment.title) · \(formatRelativeDue(due))"
        content.sound = .default
        content.userInfo = ["assignmentID": assignment.id.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let request = UNNotificationRequest(
            identifier: "assignment-\(assignment.id.uuidString)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancel(for id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["assignment-\(id.uuidString)"])
    }

    private func formatRelativeDue(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
