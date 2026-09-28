import AppKit
import Foundation
import StudyFlowKit
import UniformTypeIdentifiers

@MainActor
public final class MacDataExporter: StudyFlowDataExporter {
    public init() {}

    public func export(
        data: Data,
        suggestedFileName: String,
        destination: StudyFlowExportDestination
    ) throws -> Bool {
        let panel = NSSavePanel()
        panel.title = destination == .iCloudDrive
            ? "导出 StudyFlow 数据到 iCloud 云盘"
            : "导出 StudyFlow 数据"
        panel.message = destination == .iCloudDrive
            ? "确认文件名为 StudyFlow 备份，然后保存到 iCloud 云盘。"
            : "可选择本机文件夹或 iCloud 云盘作为备份位置。"
        panel.prompt = "导出"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedFileName

        if destination == .iCloudDrive {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(
                    "Library/Mobile Documents/com~apple~CloudDocs",
                    isDirectory: true
                )
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }
        try data.write(to: url, options: [.atomic])
        return true
    }
}
