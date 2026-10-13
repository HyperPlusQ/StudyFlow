import Foundation
import SwiftData

@MainActor
enum StudyOperations {
    /// 递归收集指定科目的全部子科目。
    /// 使用一次性构建的“父科目 → 子科目”索引（整体 O(n)），并以 visited 集合防止
    /// 科目层级出现环（例如 A.parent = B 且 B.parent = A）时无限循环。
    static func descendants(of subject: Subject, in subjects: [Subject]) -> [Subject] {
        var childrenByParent: [UUID: [Subject]] = [:]
        for candidate in subjects {
            guard let parentId = candidate.parentId else { continue }
            childrenByParent[parentId, default: []].append(candidate)
        }
        var visited: Set<UUID> = [subject.id]
        var queue = [subject]
        var collected: [Subject] = []
        while let current = queue.popLast() {
            for child in childrenByParent[current.id] ?? [] where visited.insert(child.id).inserted {
                collected.append(child)
                queue.append(child)
            }
        }
        return collected
    }

    static func isDescendant(_ candidate: Subject, of root: Subject, in subjects: [Subject]) -> Bool {
        candidate.id == root.id || descendants(of: root, in: subjects).contains { $0.id == candidate.id }
    }

    /// 删除科目并解除作业、时间块和历史记录关联。
    static func delete(_ subject: Subject, from subjects: [Subject], assignments: [Assignment], context: ModelContext) {
        // 删除层级连同其全部后代，先移除这些科目的待发布置提醒。
        for removable in [subject] + descendants(of: subject, in: subjects) {
            NotificationManager.shared.cancelSubjectReminder(for: removable.id)
        }
        for child in subjects where child.parentId == subject.id {
            child.parentId = subject.parentId
        }
        for assignment in assignments where assignment.subjectId == subject.id {
            assignment.subjectId = nil
        }
        for block in (try? context.fetch(FetchDescriptor<TimeBlock>())) ?? [] where block.subjectId == subject.id {
            block.subjectId = nil
        }
        for entry in (try? context.fetch(FetchDescriptor<SubmissionHistoryEntry>())) ?? []
        where entry.subjectId == subject.id {
            context.delete(entry)
        }
        context.delete(subject)
        PersistentStore.save(context)
    }
}
