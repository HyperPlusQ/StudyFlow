import Foundation

public enum WidgetSnapshotStore {
    public static let appGroupIdentifier = "group.com.openai.studyflow"
    public static let fileName = "widget-snapshot.json"

    public static func save(_ snapshot: WidgetSnapshot) throws {
        guard let container = sharedContainer() else {
            throw WidgetSnapshotError.unavailableContainer
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(snapshot)
        try data.write(
            to: container.appendingPathComponent(fileName, isDirectory: false),
            options: .atomic
        )
    }

    public static func load() -> WidgetSnapshot? {
        guard let container = sharedContainer(),
              let data = try? Data(
                contentsOf: container.appendingPathComponent(fileName, isDirectory: false)
              )
        else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    public static func remove() {
        guard let container = sharedContainer() else { return }
        try? FileManager.default.removeItem(
            at: container.appendingPathComponent(fileName, isDirectory: false)
        )
    }

    private static func sharedContainer() -> URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }
}

public enum WidgetSnapshotError: LocalizedError {
    case unavailableContainer

    public var errorDescription: String? {
        "无法访问小组件共享数据容器。"
    }
}
