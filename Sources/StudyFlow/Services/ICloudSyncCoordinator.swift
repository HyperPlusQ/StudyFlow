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

    static let fileName = "StudyFlow-Sync.json"

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
    func setEnabled(_ enabled: Bool, context: ModelContext) -> Bool {
        if enabled {
            guard folderBookmark != nil || chooseFolder() else {
                lastMessage = "未选择同步文件夹，自动同步保持关闭。"
                return false
            }
            isEnabled = true
            defaults.set(true, forKey: Key.enabled)
            synchronize(context: context)
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
                synchronize(context: context)
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
    func synchronize(context: ModelContext) -> Bool {
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
            let fileManager = FileManager.default
            let localExists = fileManager.fileExists(atPath: localURL.path)
            let cloudExists = fileManager.fileExists(atPath: cloudURL.path)

            // Keep the local mirror synchronized with SwiftData while preserving
            // its file timestamp until an explicit newer-wins comparison.
            if localExists {
                let localDate = try DataExportService.modificationDate(of: localURL)
                try DataExportService.write(
                    DataExportService.currentData(context: context),
                    to: localURL,
                    modificationDate: localDate
                )
            }

            let message: String
            if localExists, cloudExists {
                let localDate = try DataExportService.modificationDate(of: localURL)
                let cloudDate = try DataExportService.modificationDate(of: cloudURL)

                if localDate > cloudDate {
                    let data = try Data(contentsOf: localURL)
                    try DataExportService.write(data, to: cloudURL, modificationDate: localDate)
                    message = "同步完成：本地文件较新，已更新 iCloud 文件。"
                } else if cloudDate > localDate {
                    let data = try Data(contentsOf: cloudURL)
                    try DataExportService.restore(data: data, into: context)
                    try DataExportService.write(data, to: localURL, modificationDate: cloudDate)
                    message = "同步完成：iCloud 文件较新，已更新本地数据。"
                } else {
                    message = "同步完成：两端修改时间相同，无需覆盖。"
                }
            } else if cloudExists {
                let cloudDate = try DataExportService.modificationDate(of: cloudURL)
                let data = try Data(contentsOf: cloudURL)
                try DataExportService.restore(data: data, into: context)
                try DataExportService.write(data, to: localURL, modificationDate: cloudDate)
                message = "已从 iCloud 文件更新本地数据。"
            } else {
                let data = localExists
                    ? try Data(contentsOf: localURL)
                    : try DataExportService.currentData(context: context)
                let timestamp = localExists
                    ? try DataExportService.modificationDate(of: localURL)
                    : .now
                if !localExists {
                    try DataExportService.write(data, to: localURL, modificationDate: timestamp)
                }
                try DataExportService.write(data, to: cloudURL, modificationDate: timestamp)
                message = localExists
                    ? "已将本地同步文件写入 iCloud。"
                    : "已创建本地与 iCloud 同步文件。"
            }

            recordSuccessfulSync(message: message)
            return true
        } catch {
            lastMessage = "同步失败：\(error.localizedDescription)"
            defaults.set(lastMessage, forKey: Key.lastMessage)
            return false
        }
    }

    func performLaunchSyncIfNeeded(context: ModelContext) {
        guard isEnabled else { return }

        if scheduledTimeReached && lastScheduledSyncDay != todayKey {
            if synchronize(context: context) {
                markScheduledSyncCompleted()
            }
        } else {
            synchronize(context: context)
        }
    }

    func checkScheduledSyncIfNeeded(context: ModelContext) {
        guard isEnabled,
              scheduledTimeReached,
              lastScheduledSyncDay != todayKey
        else { return }

        if synchronize(context: context) {
            markScheduledSyncCompleted()
        }
    }

    /// Refreshes the local comparison file after a database save and advances
    /// its modification timestamp so the next synchronization can propagate it.
    func refreshLocalSnapshotIfNeeded(context: ModelContext) {
        guard isEnabled, let localURL = try? localSyncURL() else { return }
        guard FileManager.default.fileExists(atPath: localURL.path) else { return }

        do {
            // A local edit must make the local comparison file newer than the
            // last synchronized iCloud copy so the next sync can propagate it.
            try DataExportService.write(
                DataExportService.currentData(context: context),
                to: localURL,
                modificationDate: .now
            )
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
