import XCTest
@testable import Glaze

final class BreakDailyStatsTests: XCTestCase {
    func testRecordsBreakDurationWithinSameDay() {
        let store = InMemoryBreakStatsStore()
        let tracker = BreakDailyStatsTracker(store: store, calendar: fixedCalendar)
        let start = date(year: 2026, month: 3, day: 20, hour: 10, minute: 0, second: 0)
        let end = date(year: 2026, month: 3, day: 20, hour: 10, minute: 5, second: 0)

        tracker.recordBreak(from: start, to: end)

        let summary = tracker.summary(for: date(year: 2026, month: 3, day: 20, hour: 12, minute: 0, second: 0))
        XCTAssertEqual(summary.breakDuration, 300, accuracy: 0.001)
        XCTAssertEqual(summary.dayFraction, 300 / 43_200, accuracy: 0.0001)
    }

    func testSplitsBreakAcrossMidnight() {
        let store = InMemoryBreakStatsStore()
        let tracker = BreakDailyStatsTracker(store: store, calendar: fixedCalendar)
        let start = date(year: 2026, month: 3, day: 20, hour: 23, minute: 59, second: 50)
        let end = date(year: 2026, month: 3, day: 21, hour: 0, minute: 0, second: 10)

        tracker.recordBreak(from: start, to: end)

        let march20Summary = tracker.summary(for: date(year: 2026, month: 3, day: 20, hour: 23, minute: 59, second: 59))
        let march21Summary = tracker.summary(for: date(year: 2026, month: 3, day: 21, hour: 0, minute: 1, second: 0))

        XCTAssertEqual(march20Summary.breakDuration, 10, accuracy: 0.001)
        XCTAssertEqual(march21Summary.breakDuration, 10, accuracy: 0.001)
    }

    func testIgnoresEmptyOrBackwardsIntervals() {
        let store = InMemoryBreakStatsStore()
        let tracker = BreakDailyStatsTracker(store: store, calendar: fixedCalendar)
        let pointInTime = date(year: 2026, month: 3, day: 20, hour: 10, minute: 0, second: 0)

        tracker.recordBreak(from: pointInTime, to: pointInTime)
        tracker.recordBreak(from: pointInTime.addingTimeInterval(5), to: pointInTime)

        let summary = tracker.summary(for: date(year: 2026, month: 3, day: 20, hour: 11, minute: 0, second: 0))
        XCTAssertEqual(summary.breakDuration, 0, accuracy: 0.001)
    }

    private var fixedCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) -> Date {
        let components = DateComponents(
            calendar: fixedCalendar,
            timeZone: fixedCalendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )

        return components.date ?? Date(timeIntervalSinceReferenceDate: 0)
    }
}

private final class InMemoryBreakStatsStore: BreakStatsStoring {
    private var durations: [String: TimeInterval] = [:]

    func loadDailyBreakDurations() -> [String: TimeInterval] {
        durations
    }

    func saveDailyBreakDurations(_ durations: [String: TimeInterval]) {
        self.durations = durations
    }
}
