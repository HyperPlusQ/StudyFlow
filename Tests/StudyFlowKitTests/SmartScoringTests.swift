import XCTest
@testable import StudyFlowKit

final class SmartScoringTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testOverdueAssignmentScoresHigherThanFutureAssignment() {
        let overdue = Assignment(
            title: "逾期作业",
            dueDate: now.addingTimeInterval(-3_600),
            priority: .medium,
            weight: 3,
            createdAt: now
        )
        let future = Assignment(
            title: "未来作业",
            dueDate: now.addingTimeInterval(8 * 86_400),
            priority: .medium,
            weight: 3,
            createdAt: now
        )

        XCTAssertGreaterThan(
            SmartScoring.score(for: overdue, now: now),
            SmartScoring.score(for: future, now: now)
        )
    }

    func testEqualScoresPreferEarlierDueDate() {
        let earlier = Assignment(
            title: "更早截止",
            dueDate: now.addingTimeInterval(25 * 3_600),
            priority: .medium,
            weight: 3,
            createdAt: now
        )
        let later = Assignment(
            title: "更晚截止",
            dueDate: now.addingTimeInterval(40 * 3_600),
            priority: .medium,
            weight: 3,
            createdAt: now
        )

        XCTAssertEqual(
            SmartScoring.score(for: earlier, now: now),
            SmartScoring.score(for: later, now: now)
        )

        let sorted = SmartScoring.sorted([later, earlier], now: now)
        XCTAssertEqual(sorted.first?.assignment.id, Optional(earlier.id))
    }

    func testCompletedAssignmentIsSortedLast() {
        let completed = Assignment(
            title: "已完成",
            dueDate: now.addingTimeInterval(-3_600),
            priority: .critical,
            status: .completed,
            weight: 5,
            createdAt: now
        )
        let active = Assignment(
            title: "进行中",
            dueDate: now.addingTimeInterval(8 * 86_400),
            priority: .low,
            weight: 1,
            createdAt: now
        )

        let sorted = SmartScoring.sorted([completed, active], now: now)
        XCTAssertEqual(sorted.first?.assignment.id, Optional(active.id))
        XCTAssertEqual(sorted.last?.assignment.id, Optional(completed.id))
        XCTAssertLessThan(SmartScoring.score(for: completed, now: now), 0)
    }
}
