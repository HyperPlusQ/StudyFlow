import Foundation
import SwiftData

/// 用户编辑的统一保存入口，并在开启同步时刷新本地比较文件。
@MainActor
enum PersistentStore {
    /// 统一保存数据库并刷新同步与小组件快照。
    static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            NSLog("StudyFlow failed to save model context: \(error.localizedDescription)")
            return
        }
        ICloudSyncCoordinator.shared.refreshLocalSnapshotIfNeeded(context: context)
        WidgetSnapshotService.refresh(context: context)
    }
}
