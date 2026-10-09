import Foundation
import UserNotifications

final class NotificationManager: @unchecked Sendable {
    static let shared = NotificationManager()
    private init() {}

    /// 系统通知中心只在真正的 App Bundle 中可用；命令行与单元测试进程没有 bundle proxy，
    /// 直接调用 UNUserNotificationCenter.current() 会抛出无法捕获的 NSException。
    private static var notificationCenter: UNUserNotificationCenter? {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return UNUserNotificationCenter.current()
    }

    func requestAuthorization() async {
        guard let center = Self.notificationCenter else { return }
        do {
            _ = try await center
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            NSLog("StudyFlow notification authorization failed: \(error.localizedDescription)")
        }
    }

    /// 按截止时间和提前提醒时长创建本地通知。
    func schedule(for assignment: Assignment) {
        cancel(for: assignment.id)
        guard let center = Self.notificationCenter,
              !assignment.isCompleted,
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
        center.add(request)
    }

    /// 取消指定作业的本地通知。
    func cancel(for id: UUID) {
        guard let center = Self.notificationCenter else { return }
        center.removePendingNotificationRequests(withIdentifiers: ["assignment-\(id.uuidString)"])
    }


    /// 按科目的作业布置间隔创建下一次登记提醒。
    func scheduleSubjectReminder(subject: Subject, latestAssignmentCreatedAt: Date?) {
        cancelSubjectReminder(for: subject.id)
        guard let center = Self.notificationCenter,
              let days = subject.assignmentIntervalDays,
              days > 0
        else { return }

        let registeredAt = subject.lastAssignmentRegisteredAt
            ?? latestAssignmentCreatedAt
            ?? subject.createdAt
        guard let targetDate = Calendar.current.date(
            byAdding: .day,
            value: days,
            to: registeredAt
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = "该登记作业了"
        content.body = "“\(subject.name)”距离上一次登记作业已过 \(days) 天。"
        content.sound = .default
        content.userInfo = ["subjectID": subject.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "subject-reminder-\(subject.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, targetDate.timeIntervalSinceNow),
                repeats: false
            )
        )
        center.add(request)
    }

    /// 启动、导入、同步和保存后统一刷新所有科目的布置提醒。
    static func scheduleAllSubjectReminders(
        subjects: [Subject],
        assignments: [Assignment]
    ) {
        var latestBySubject: [UUID: Date] = [:]
        for assignment in assignments {
            guard let subjectID = assignment.subjectId else { continue }
            latestBySubject[subjectID] = max(
                latestBySubject[subjectID] ?? .distantPast,
                assignment.createdAt
            )
        }
        for subject in subjects {
            shared.scheduleSubjectReminder(
                subject: subject,
                latestAssignmentCreatedAt: latestBySubject[subject.id]
            )
        }
    }

    /// 取消指定科目的作业布置提醒。
    func cancelSubjectReminder(for id: UUID) {
        guard let center = Self.notificationCenter else { return }
        center.removePendingNotificationRequests(
                withIdentifiers: ["subject-reminder-\(id.uuidString)"]
            )
    }

    private func formatRelativeDue(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
