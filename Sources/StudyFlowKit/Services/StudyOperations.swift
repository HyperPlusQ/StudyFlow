import Foundation
import SwiftData

@MainActor
enum StudyOperations {
    /// 递归收集指定科目的全部子科目。
    /// 使用一次性构建的“父科目 → 子科目”索引（整体 O(n)），并以 visited 集合防止
    /// 科目层级出现环（例如 A.parent = B 且 B.parent = A）时无限循环。
    static func descendants(of subject: Subject, in subjects: [Subject]) -> [Subject] {
        SubjectHierarchy(subjects).descendants(of: subject)
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

/// 预计算的科目层级索引。
///
/// 一次构建「父科目 → 子科目」映射后，视图可以 O(1) 取直接子科目、O(子树) 取全部后代，
/// 不必在每一行渲染时重复扫描全部科目。`visited` 集合保证层级出现环时也不会死循环。
struct SubjectHierarchy {
    private let allSubjects: [Subject]
    private let childrenByParent: [UUID: [Subject]]

    init(_ subjects: [Subject]) {
        allSubjects = subjects
        var index: [UUID: [Subject]] = [:]
        for candidate in subjects {
            guard let parentId = candidate.parentId else { continue }
            index[parentId, default: []].append(candidate)
        }
        childrenByParent = index
    }

    /// 顶层科目（无父级），按 sortOrder 升序。
    func roots() -> [Subject] {
        allSubjects
            .filter { $0.parentId == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 直接子科目，按 sortOrder 升序。
    func children(of subject: Subject) -> [Subject] {
        (childrenByParent[subject.id] ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 指定科目的全部后代（含环安全）。
    func descendants(of subject: Subject) -> [Subject] {
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

    /// 指定科目自身 + 全部后代的 id 集合。
    func descendantIds(of subject: Subject) -> Set<UUID> {
        var ids: Set<UUID> = [subject.id]
        for child in descendants(of: subject) {
            ids.insert(child.id)
        }
        return ids
    }
}
