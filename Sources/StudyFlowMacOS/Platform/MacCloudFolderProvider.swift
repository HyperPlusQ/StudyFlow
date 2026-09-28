import AppKit
import Foundation
import StudyFlowKit

@MainActor
public final class MacCloudFolderProvider: StudyFlowCloudFolderProvider {
    public init() {}

    public func chooseFolder(currentBookmark: Data?) throws -> Data {
        let panel = NSOpenPanel()
        panel.title = "选择 iCloud 同步文件夹"
        panel.message = "请选择 iCloud 云盘中的文件夹；StudyFlow 会在此处保存 StudyFlow-Sync.json。"
        panel.prompt = "选择文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Mobile Documents/com~apple~CloudDocs",
                isDirectory: true
            )

        if let currentBookmark {
            var isStale = false
            if let current = try? URL(
                resolvingBookmarkData: currentBookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                panel.directoryURL = current
            }
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            throw CocoaError(.userCancelled)
        }

        let standardizedPath = url.standardizedFileURL.path
        guard standardizedPath.contains(
            "/Library/Mobile Documents/com~apple~CloudDocs"
        ) else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "请选择 iCloud 云盘中的文件夹"
            alert.informativeText = "StudyFlow 的自动同步需要把 StudyFlow-Sync.json 保存在 iCloud 云盘，才能在设备之间同步。"
            alert.addButton(withTitle: "好")
            alert.runModal()
            throw CocoaError(.fileWriteNoPermission)
        }

        return try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    public func resolveFolder(bookmark: Data) throws -> URL {
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
            UserDefaults.standard.set(
                refreshed,
                forKey: "iCloudSyncFolderBookmark"
            )
        }
        return folder
    }
}
