import Foundation
import SwiftData

@MainActor
enum StudyOperations {
    /// 递归收集指定科目的全部子科目。
    static func descendants(of subject: Subject, in subjects: [Subject]) -> [Subject] {
        var queue = [subject]
        var collected: [Subject] = []
        while let current = queue.popLast() {
            let children = subjects.filter { $0.parentId == current.id }
            collected.append(contentsOf: children)
            queue.append(contentsOf: children)
        }
        return collected
    }

    /// 判断候选科目是否位于指定科目层级内。
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
