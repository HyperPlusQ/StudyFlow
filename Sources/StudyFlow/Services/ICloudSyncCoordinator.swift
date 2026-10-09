import AppKit
import Foundation
import Observation
import SwiftData

/// Coordinates launch, daily-time, and manual synchronization of the local
/// SwiftData snapshot with a user-selected iCloud Drive folder.
@MainActor
@Observable
final class ICloudSyncCoordinator {
    static let shared = ICloudSyncCoordinator()

    static let fileName = "StudyFlow-Sync.zip"

    private enum Key {
        static let enabled = "iCloudSyncEnabled"
        static let hour = "iCloudSyncHour"
        static let minute = "iCloudSyncMinute"
        static let bookmark = "iCloudSyncFolderBookmark"
        static let folderName = "iCloudSyncFolderName"
        static let lastScheduledDay = "iCloudLastScheduledSyncDay"
        static let lastSyncDate = "iCloudLastSyncDate"
        static let lastMessage = "iCloudLastSyncMessage"
    }

    private(set) var isEnabled: Bool
    private(set) var syncHour: Int
    private(set) var syncMinute: Int
    private(set) var folderName: String?
    private(set) var lastSyncDate: Date?
    private(set) var lastMessage: String
    private(set) var isSynchronizing = false

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var lastScheduledSyncDay: String?

    private init() {
        let storedEnabled = defaults.bool(forKey: Key.enabled)
        let storedHour = defaults.object(forKey: Key.hour) as? Int ?? 21
        let storedMinute = defaults.object(forKey: Key.minute) as? Int ?? 0
        let storedFolderName = defaults.string(forKey: Key.folderName)
        let storedSyncDate = defaults.object(forKey: Key.lastSyncDate) as? Date
        let storedMessage = defaults.string(forKey: Key.lastMessage)
            ?? (storedEnabled ? "等待下次同步。" : "尚未开启自动同步。")
        let storedScheduledDay = defaults.string(forKey: Key.lastScheduledDay)

        isEnabled = storedEnabled
        syncHour = storedHour
        syncMinute = storedMinute
        folderName = storedFolderName
        lastSyncDate = storedSyncDate
        lastMessage = storedMessage
        lastScheduledSyncDay = storedScheduledDay
    }

    var scheduleDescription: String {
        String(format: "每天 %02d:%02d", syncHour, syncMinute)
    }

    @discardableResult
    /// 开启或关闭 iCloud 云盘自动同步。
    func setEnabled(_ enabled: Bool, context: ModelContext) -> Bool {
        if enabled {
            guard folderBookmark != nil || chooseFolder() else {
                lastMessage = "未选择同步文件夹，自动同步保持关闭。"
                return false
            }
            isEnabled = true
            defaults.set(true, forKey: Key.enabled)
            Task { await synchronize(context: context) }
        } else {
            isEnabled = false
            defaults.set(false, forKey: Key.enabled)
            lastMessage = "已关闭自动同步；本地与 iCloud 文件保持当前状态。"
            defaults.set(lastMessage, forKey: Key.lastMessage)
        }
        return true
    }

    @discardableResult
    func chooseFolder(context: ModelContext? = nil) -> Bool {
        guard let folder = chooseFolderInPanel() else { return false }
        do {
            let bookmark = try folder.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(bookmark, forKey: Key.bookmark)
            folderName = folder.lastPathComponent
            defaults.set(folderName, forKey: Key.folderName)
            if let context {
                Task { await synchronize(context: context) }
            } else {
                lastMessage = "同步文件夹已更新。"
                defaults.set(lastMessage, forKey: Key.lastMessage)
            }
            return true
        } catch {
            lastMessage = "无法保存同步文件夹访问权限：\(error.localizedDescription)"
            defaults.set(lastMessage, forKey: Key.lastMessage)
            return false
        }
    }

    func setSyncTime(hour: Int, minute: Int) {
        syncHour = min(max(hour, 0), 23)
        syncMinute = min(max(minute, 0), 59)
        defaults.set(syncHour, forKey: Key.hour)
        defaults.set(syncMinute, forKey: Key.minute)
        lastScheduledSyncDay = nil
        defaults.removeObject(forKey: Key.lastScheduledDay)
    }

    @discardableResult
    /// 按修改时间比较并合并本地与 iCloud 文件；打包与文件读写全部在后台执行。
    func synchronize(context: ModelContext) async -> Bool {
        guard isEnabled else {
            lastMessage = "自动同步尚未开启。"
            return false
        }
        guard !isSynchronizing else { return true }
        guard let folder = try? resolveFolder() else {
            lastMessage = "无法访问同步文件夹，请重新选择 iCloud 文件夹。"
            defaults.set(lastMessage, forKey: Key.lastMessage)
            return false
        }

        isSynchronizing = true
        defer { isSynchronizing = false }

        let hasSecurityAccess = folder.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                folder.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let localURL = try localSyncURL()
            let cloudURL = folder.appendingPathComponent(Self.fileName, isDirectory: false)
            let container = context.container

            // 读文件、按数据库重建含图片的 ZIP 都放到后台线程：
            // 主线程只负责数据库写入，启动与手动同步都不再卡顿。
            let outcome = try await Self.onBackground {
                try Self.mergeFiles(container: container, localURL: localURL, cloudURL: cloudURL)
            }

            switch outcome {
            case let .finished(message):
                recordSuccessfulSync(message: message)
                return true
            case let .pulled(data, date, message):
                // 云端较新：先在主线程恢复数据库，再把云端文件写回本地镜像。
                try DataExportService.restore(data: data, into: context)
                try await Self.onBackground {
                    try DataExportService.write(data, to: localURL, modificationDate: date)
                }
                recordSuccessfulSync(message: message)
                return true
            }
        } catch {
            lastMessage = "同步失败：\(error.localizedDescription)"
            defaults.set(lastMessage, forKey: Key.lastMessage)
            return false
        }
    }

    /// 后台线程完成的同步结果。
    private enum SyncOutcome: Sendable {
        /// 已处理完成（推送或无需改动），只带提示文案。
        case finished(String)
        /// 云端较新：携带云端数据，由主线程恢复数据库。
        case pulled(data: Data, date: Date, message: String)
    }

    /// 在后台队列执行重活（打包备份 / 文件读写），避免阻塞主线程。
    private nonisolated static func onBackground<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 比较并更新本地/云端同步文件；只在后台线程调用。
    /// 本地镜像每次用当前数据库重建（保持原比较时间戳），推送时直接复制文件。
    private nonisolated static func mergeFiles(
        container: ModelContainer,
        localURL: URL,
        cloudURL: URL
    ) throws -> SyncOutcome {
        let fileManager = FileManager.default
        let localExists = fileManager.fileExists(atPath: localURL.path)
        let cloudExists = fileManager.fileExists(atPath: cloudURL.path)
        let backgroundContext = ModelContext(container)

        if localExists {
            let localDate = try DataExportService.modificationDate(of: localURL)
            try DataExportService.writeArchive(
                context: backgroundContext,
                to: localURL,
                modificationDate: localDate
            )
        }

        if localExists, cloudExists {
            let localDate = try DataExportService.modificationDate(of: localURL)
            let cloudDate = try DataExportService.modificationDate(of: cloudURL)

            if localDate > cloudDate {
                try copyReplacingFile(from: localURL, to: cloudURL)
                try fileManager.setAttributes(
                    [.modificationDate: localDate],
                    ofItemAtPath: cloudURL.path
                )
                return .finished("同步完成：本地文件较新，已更新 iCloud 文件。")
            }
            if cloudDate > localDate {
                let data = try Data(contentsOf: cloudURL)
                return .pulled(
                    data: data,
                    date: cloudDate,
                    message: "同步完成：iCloud 文件较新，已更新本地数据。"
                )
            }
            return .finished("同步完成：两端修改时间相同，无需覆盖。")
        }

        if cloudExists {
            let cloudDate = try DataExportService.modificationDate(of: cloudURL)
            let data = try Data(contentsOf: cloudURL)
            return .pulled(data: data, date: cloudDate, message: "已从 iCloud 文件更新本地数据。")
        }

        let timestamp = localExists
            ? try DataExportService.modificationDate(of: localURL)
            : Date.now
        if !localExists {
            try DataExportService.writeArchive(
                context: backgroundContext,
                to: localURL,
                modificationDate: timestamp
            )
        }
        try copyReplacingFile(from: localURL, to: cloudURL)
        try fileManager.setAttributes(
            [.modificationDate: timestamp],
            ofItemAtPath: cloudURL.path
        )
        return .finished(
            localExists
                ? "已将本地同步文件写入 iCloud。"
                : "已创建本地与 iCloud 同步文件。"
        )
    }

    /// 文件到文件的复制替换：避免把整份 ZIP 读回内存。
    private nonisolated static func copyReplacingFile(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        let tempURL = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try fileManager.copyItem(at: source, to: tempURL)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw error
        }
    }

    /// 应用启动时执行到期或必要的同步；打包在后台完成，不拖慢启动。
    func performLaunchSyncIfNeeded(context: ModelContext) async {
        guard isEnabled else { return }

        if scheduledTimeReached && lastScheduledSyncDay != todayKey {
            if await synchronize(context: context) {
                markScheduledSyncCompleted()
            }
        } else {
            await synchronize(context: context)
        }
    }

    /// 应用运行期间检查每日同步时间。
    func checkScheduledSyncIfNeeded(context: ModelContext) async {
        guard isEnabled,
              scheduledTimeReached,
              lastScheduledSyncDay != todayKey
        else { return }

        if await synchronize(context: context) {
            markScheduledSyncCompleted()
        }
    }

    /// 数据变更后刷新本地同步比较文件。
    func refreshLocalSnapshotIfNeeded(context: ModelContext) {
        guard isEnabled, let localURL = try? localSyncURL() else { return }

        do {
            if FileManager.default.fileExists(atPath: localURL.path) {
                // 只更新比较时间戳：ZIP 内容交给下一次同步按需重建，
                // 避免每次保存都把全部图片重新 Base64 并打包一遍。
                try DataExportService.touchModificationDate(at: localURL)
            } else {
                // 首次开启同步：建立一次比较文件。
                try DataExportService.writeArchive(
                    context: context,
                    to: localURL,
                    modificationDate: .now
                )
            }
        } catch {
            NSLog("StudyFlow local sync snapshot refresh failed: \(error.localizedDescription)")
        }
    }

    private var folderBookmark: Data? {
        defaults.data(forKey: Key.bookmark)
    }

    private var scheduledTimeReached: Bool {
        let now = Calendar.current.dateComponents([.hour, .minute], from: .now)
        let hour = now.hour ?? 0
        let minute = now.minute ?? 0
        return hour > syncHour || (hour == syncHour && minute >= syncMinute)
    }

    private var todayKey: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func markScheduledSyncCompleted() {
        lastScheduledSyncDay = todayKey
        defaults.set(todayKey, forKey: Key.lastScheduledDay)
    }

    private func recordSuccessfulSync(message: String) {
        let date = Date.now
        lastSyncDate = date
        lastMessage = message
        defaults.set(date, forKey: Key.lastSyncDate)
        defaults.set(message, forKey: Key.lastMessage)
    }

    private func localSyncURL() throws -> URL {
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return support
            .appendingPathComponent("StudyFlow", isDirectory: true)
            .appendingPathComponent("Sync", isDirectory: true)
            .appendingPathComponent(Self.fileName, isDirectory: false)
    }

    private func resolveFolder() throws -> URL {
        guard let bookmark = folderBookmark else {
            throw CocoaError(.fileNoSuchFile)
        }

        var isStale = false
        let folder = try URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            let refreshed = try folder.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(refreshed, forKey: Key.bookmark)
        }
        return folder
    }

    private func chooseFolderInPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "选择 iCloud 同步文件夹"
        panel.message = "请选择 iCloud 云盘中的文件夹；StudyFlow 会在此处保存 \(Self.fileName)。"
        panel.prompt = "选择文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)

        if let bookmark = folderBookmark {
            var isStale = false
            if let current = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                panel.directoryURL = current
            }
        }

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        let standardizedPath = url.standardizedFileURL.path
        guard standardizedPath.contains("/Library/Mobile Documents/com~apple~CloudDocs") else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "请选择 iCloud 云盘中的文件夹"
            alert.informativeText = "StudyFlow 的自动同步需要把 \(Self.fileName) 保存在 iCloud 云盘，才能在设备之间同步。"
            alert.addButton(withTitle: "好")
            alert.runModal()
            return nil
        }
        return url
    }
}
