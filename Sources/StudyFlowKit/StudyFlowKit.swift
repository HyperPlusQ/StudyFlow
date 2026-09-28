import SwiftData
import SwiftUI

/// Creates the SwiftData container used by every StudyFlow application target.
@MainActor
public enum StudyFlowStorage {
    public static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Subject.self,
            Assignment.self,
            Subtask.self,
            TimeBlock.self,
            SubmissionHistoryEntry.self
        ])

        if let path = ProcessInfo.processInfo.environment["STUDYFLOW_STORE_PATH"],
           !path.isEmpty {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            let configuration = ModelConfiguration(
                schema: schema,
                url: url,
                allowsSave: true
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        }

        return try ModelContainer(for: schema)
    }
}

/// Platform-neutral entry point for the shared StudyFlow feature shell.
@MainActor
public struct StudyFlowRootView: View {
    private let exporter: (any StudyFlowDataExporter)?
    private let cloudFolderProvider: (any StudyFlowCloudFolderProvider)?

    public init(
        exporter: (any StudyFlowDataExporter)? = nil,
        cloudFolderProvider: (any StudyFlowCloudFolderProvider)? = nil
    ) {
        self.exporter = exporter
        self.cloudFolderProvider = cloudFolderProvider
    }

    public var body: some View {
        ContentView(
            exporter: exporter,
            cloudFolderProvider: cloudFolderProvider
        )
        .onAppear {
            ICloudSyncCoordinator.shared.configure(
                folderProvider: cloudFolderProvider
            )
        }
    }
}

/// Lets platform shells trigger shared toolbar/menu actions without exposing
/// the internal notification names used by `ContentView`.
@MainActor
public enum StudyFlowCommands {
    public static func postNewAssignment() {
        NotificationCenter.default.post(name: .studyFlowNewAssignment, object: nil)
    }

    public static func postNewSubject() {
        NotificationCenter.default.post(name: .studyFlowNewSubject, object: nil)
    }

    public static func postNewTimeBlock() {
        NotificationCenter.default.post(name: .studyFlowNewTimeBlock, object: nil)
    }
}

/// macOS exposes settings in a separate scene; future Apple platforms can
/// present the same shared settings content from their own navigation shell.
@MainActor
public struct StudyFlowSettingsView: View {
    private let exporter: (any StudyFlowDataExporter)?
    private let cloudFolderProvider: (any StudyFlowCloudFolderProvider)?

    public init(
        exporter: (any StudyFlowDataExporter)? = nil,
        cloudFolderProvider: (any StudyFlowCloudFolderProvider)? = nil
    ) {
        self.exporter = exporter
        self.cloudFolderProvider = cloudFolderProvider
    }

    public var body: some View {
        SettingsView(
            exporter: exporter,
            cloudFolderProvider: cloudFolderProvider
        )
        .onAppear {
            ICloudSyncCoordinator.shared.configure(
                folderProvider: cloudFolderProvider
            )
        }
    }
}
