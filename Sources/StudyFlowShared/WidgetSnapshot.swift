import Foundation

struct WidgetSnapshot: Codable, Sendable {
    struct Item: Codable, Sendable, Identifiable {
        let id: UUID
        let title: String
        let subject: String
        let dueDate: Date?
        let completedSubtasks: Int
        let totalSubtasks: Int
    }

    let generatedAt: Date
    let activeCount: Int
    let dueTodayCount: Int
    let overdueCount: Int
    let completedCount: Int
    let items: [Item]
}

enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.openai.studyflow"
    private static let fileName = "widget-snapshot.json"

    static func save(_ snapshot: WidgetSnapshot) throws {
        guard let container = sharedContainer() else {
            throw WidgetSnapshotError.unavailableContainer
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(snapshot).write(to: container.appendingPathComponent(fileName), options: .atomic)
    }

    static func load() -> WidgetSnapshot? {
        guard let container = sharedContainer(),
              let data = try? Data(contentsOf: container.appendingPathComponent(fileName))
        else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    private static func sharedContainer() -> URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }
}

enum WidgetSnapshotError: LocalizedError {
    case unavailableContainer

    var errorDescription: String? {
        "无法访问小组件共享数据容器。"
    }
}
