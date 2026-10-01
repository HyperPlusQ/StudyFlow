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
                    // 系统恢复或全新安装后首次启动时，也为小组件生成数据。
                    WidgetSnapshotRefreshQueue.schedule(context: container.mainContext)
                }
                .onOpenURL { _ in
                    // 点击小组件只需将 StudyFlow 带回前台。
                }
        }
    }
}

@MainActor
private enum WidgetSnapshotRefreshQueue {
    /// 延迟刷新小组件共享数据。
    static func schedule(context: ModelContext) {
        DispatchQueue.main.async {
            StudyFlowWidgetBridge.refresh(context: context)
        }
    }
}
