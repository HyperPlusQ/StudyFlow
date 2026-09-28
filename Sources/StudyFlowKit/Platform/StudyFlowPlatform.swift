import Foundation

/// Presentation-specific JSON export implementation. macOS uses `NSSavePanel`;
/// a future iOS target can present `fileExporter` or a document picker.
@MainActor
public protocol StudyFlowDataExporter: AnyObject {
    func export(
        data: Data,
        suggestedFileName: String,
        destination: StudyFlowExportDestination
    ) throws -> Bool
}

public enum StudyFlowExportDestination: Sendable {
    case anywhere
    case iCloudDrive
}

/// Owns security-scoped bookmark creation and resolution so the shared iCloud
/// coordinator never depends on AppKit's `NSOpenPanel`.
@MainActor
public protocol StudyFlowCloudFolderProvider: AnyObject {
    func chooseFolder(currentBookmark: Data?) throws -> Data
    func resolveFolder(bookmark: Data) throws -> URL
}
