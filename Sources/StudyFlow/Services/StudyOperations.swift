import Foundation
import SwiftData

enum StudyOperations {
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

    static func isDescendant(_ candidate: Subject, of root: Subject, in subjects: [Subject]) -> Bool {
        candidate.id == root.id || descendants(of: root, in: subjects).contains { $0.id == candidate.id }
    }

    static func delete(_ subject: Subject, from subjects: [Subject], assignments: [Assignment], context: ModelContext) {
        for child in subjects where child.parentId == subject.id {
            child.parentId = subject.parentId
        }
        for assignment in assignments where assignment.subjectId == subject.id {
            assignment.subjectId = nil
        }
        for block in (try? context.fetch(FetchDescriptor<TimeBlock>())) ?? [] where block.subjectId == subject.id {
            block.subjectId = nil
        }
        context.delete(subject)
        try? context.save()
    }
}
