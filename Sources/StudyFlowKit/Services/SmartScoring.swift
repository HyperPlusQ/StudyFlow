import Foundation

struct ScoredAssignment: Identifiable {
    let assignment: Assignment
    let score: Double
    var id: UUID { assignment.id }
}

enum SmartScoring {
    static func score(for assignment: Assignment, now: Date = .now) -> Double {
        guard !assignment.isCompleted else { return -1 }

        var score = Double(assignment.weight) * 35
        score += Double(assignment.priority.rawValue) * 25

        if let due = assignment.dueDate {
            let remainingHours = due.timeIntervalSince(now) / 3600
            switch remainingHours {
            case ..<0:
                score += 1_000 + min(abs(remainingHours), 240) * 2
            case 0..<6:
                score += 720 - remainingHours * 12
            case 6..<24:
                score += 520
            case 24..<72:
                score += 360
            case 72..<168:
                score += 220
            default:
                score += 80
            }
        } else {
            score += 140
        }

        let checklistPenalty = assignment.progress * 80
        return max(0, score - checklistPenalty)
    }

    static func sorted(_ assignments: [Assignment], now: Date = .now) -> [(assignment: Assignment, score: Double)] {
        assignments
            .map { ($0, score(for: $0, now: now)) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                switch (lhs.0.dueDate, rhs.0.dueDate) {
                case let (l?, r?): return l < r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return lhs.0.createdAt < rhs.0.createdAt
                }
            }
    }
}
