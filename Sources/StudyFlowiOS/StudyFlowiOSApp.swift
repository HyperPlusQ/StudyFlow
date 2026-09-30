import SwiftData
import SwiftUI

@main
struct StudyFlowiOSApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try StudyFlowStorage.makeContainer()
        } catch {
            fatalError("无法初始化 StudyFlow 数据库：\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            StudyFlowRootView()
                .modelContainer(container)
                .onAppear {
                    // Ensure widgets have data even when the app is launched for the
                    // first time after an OS restore or fresh install.
                    WidgetSnapshotRefreshQueue.schedule(context: container.mainContext)
                }
                .onOpenURL { _ in
                    // Widget taps simply bring StudyFlow to the foreground.
                }
        }
    }
}

@MainActor
private enum WidgetSnapshotRefreshQueue {
    static func schedule(context: ModelContext) {
        DispatchQueue.main.async {
            StudyFlowWidgetBridge.refresh(context: context)
        }
    }
}
