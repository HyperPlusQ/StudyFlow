import Foundation

/// StudyFlow 主应用与小组件共享的只读数据快照。
///
/// 独立目标确保主应用与扩展使用相同结构，同时避免小组件进程依赖 SwiftData。
public struct WidgetSnapshot: Codable, Sendable {
    public struct Item: Codable, Sendable, Identifiable, Hashable {
        public let id: UUID
        public let title: String
        public let subject: String
        public let dueDate: Date?
        public let completedSubtasks: Int
        public let totalSubtasks: Int
        public let priorityRaw: Int
        public let weight: Int

        public init(
            id: UUID,
            title: String,
            subject: String,
            dueDate: Date?,
            completedSubtasks: Int,
            totalSubtasks: Int,
            priorityRaw: Int,
            weight: Int
        ) {
            self.id = id
            self.title = title
            self.subject = subject
            self.dueDate = dueDate
            self.completedSubtasks = completedSubtasks
            self.totalSubtasks = totalSubtasks
            self.priorityRaw = priorityRaw
            self.weight = weight
        }
    }

    public let generatedAt: Date
    public let activeCount: Int
    public let dueTodayCount: Int
    public let overdueCount: Int
    public let completedCount: Int
    public let items: [Item]

    public init(
        generatedAt: Date,
        activeCount: Int,
        dueTodayCount: Int,
        overdueCount: Int,
        completedCount: Int,
        items: [Item]
    ) {
        self.generatedAt = generatedAt
        self.activeCount = activeCount
        self.dueTodayCount = dueTodayCount
        self.overdueCount = overdueCount
        self.completedCount = completedCount
        self.items = items
    }
}
