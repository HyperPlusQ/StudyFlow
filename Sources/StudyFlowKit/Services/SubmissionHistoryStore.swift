import Foundation
import SwiftData

@Model
final class SubmissionHistoryEntry {
    @Attribute(.unique) var id: UUID
    var subjectId: UUID
    var value: String
    var lastUsedAt: Date

    init(
        id: UUID = UUID(),
        subjectId: UUID,
        value: String,
        lastUsedAt: Date = .now
    ) {
        self.id = id
        self.subjectId = subjectId
        self.value = value
        self.lastUsedAt = lastUsedAt
    }
}

@MainActor
enum SubmissionHistoryStore {
    static func remember(value: String, subjectId: UUID?, context: ModelContext) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let subjectId else { return }

        let descriptor = FetchDescriptor<SubmissionHistoryEntry>(
            predicate: #Predicate { entry in
                entry.subjectId == subjectId
            }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        let normalized = normalizedKey(trimmed)

        if let match = existing.first(where: { normalizedKey($0.value) == normalized }) {
            match.value = trimmed
            match.lastUsedAt = .now
        } else {
            context.insert(
                SubmissionHistoryEntry(subjectId: subjectId, value: trimmed)
            )
        }
        PersistentStore.save(context)
    }

    static func entries(for subjectId: UUID?, context: ModelContext) -> [SubmissionHistoryEntry] {
        guard let subjectId else { return [] }
        let descriptor = FetchDescriptor<SubmissionHistoryEntry>(
            predicate: #Predicate { entry in
                entry.subjectId == subjectId
            },
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? [])
    }

    static func delete(_ entry: SubmissionHistoryEntry, context: ModelContext) {
        context.delete(entry)
        PersistentStore.save(context)
    }

    private static func normalizedKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
