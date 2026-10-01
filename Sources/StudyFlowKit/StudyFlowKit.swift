import SwiftData
import SwiftUI

/// 创建 StudyFlow 各应用目标共用的 SwiftData 容器。
@MainActor
public enum StudyFlowStorage {
    /// 创建应用和测试共享的 SwiftData 容器。
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

/// 让应用壳层无需直接依赖小组件共享目标即可刷新小组件数据。
@MainActor
public enum StudyFlowWidgetBridge {
    /// 将最新作业摘要写入小组件共享存储。
    public static func refresh(context: ModelContext) {
        WidgetSnapshotService.refresh(context: context)
    }
}

/// iOS 应用的共享功能入口，负责挂载主界面并恢复 iCloud 自动同步。
@MainActor
public struct StudyFlowRootView: View {
    public init() {}

    public var body: some View {
        ContentView()
    }
}

/// 让平台壳层触发共享工具栏操作，同时隐藏内部通知名称。
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
