import Foundation
import SwiftData

/// Single save path used by user-facing edits. Saving also refreshes the local
/// iCloud comparison mirror when automatic synchronization is enabled.
@MainActor
enum PersistentStore {
    static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            NSLog("StudyFlow failed to save model context: \(error.localizedDescription)")
            return
        }
        ICloudSyncCoordinator.shared.refreshLocalSnapshotIfNeeded(context: context)
    }
}
