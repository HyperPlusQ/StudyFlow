import Foundation
import SwiftData
import WidgetKit

/// Builds the widget payload after every successful SwiftData save so widgets
/// stay aligned with the app without opening the main database.
@MainActor
enum WidgetSnapshotService {
    static func refresh(context: ModelContext) {
        do {
            let snapshot = try makeSnapshot(context: context)
            try WidgetSnapshotStore.save(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            NSLog("StudyFlow failed to refresh widget snapshot: %@", error.localizedDescription)
        }
    }

    private static func makeSnapshot(context: ModelContext) throws -> WidgetSnapshot {
        let subjects = try context.fetch(FetchDescriptor<Subject>())
        let assignments = try context.fetch(FetchDescriptor<Assignment>())
        let now = Date.now
        let active = assignments.filter { !$0.isCompleted }
        let calendar = Calendar.current

        let dueToday = active.filter {
            guard let due = $0.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: now)
        }
        let overdue = active.filter {
            guard let due = $0.dueDate else { return false }
            return due < now
        }
        let subjectNames = Dictionary(
            subjects.map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )

        let items = SmartScoring.sorted(active, now: now)
            .prefix(6)
            .map { result in
                let assignment = result.assignment
                return WidgetSnapshot.Item(
                    id: assignment.id,
                    title: assignment.title,
                    subject: assignment.subjectId.flatMap { subjectNames[$0] } ?? "未分类",
                    dueDate: assignment.dueDate,
                    completedSubtasks: assignment.completedCount,
                    totalSubtasks: assignment.subtasks.count,
                    priorityRaw: assignment.priorityRaw,
                    weight: assignment.weight
                )
            }

        return WidgetSnapshot(
            generatedAt: now,
            activeCount: active.count,
            dueTodayCount: dueToday.count,
            overdueCount: overdue.count,
            completedCount: assignments.count - active.count,
            items: items
        )
    }
}
