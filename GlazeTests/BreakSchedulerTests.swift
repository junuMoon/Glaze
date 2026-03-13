import XCTest
@testable import Glaze

final class BreakSchedulerTests: XCTestCase {
    func testTransitionsFromHeadsUpToBreakAndBackToWork() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let scheduler = BreakScheduler(
            settings: BreakSettings(workMinutes: 5, breakSeconds: 10, headsUpSeconds: 10),
            now: start
        )

        let headsUpSnapshot = scheduler.tick(now: start.addingTimeInterval(290))
        XCTAssertEqual(headsUpSnapshot.phase, .headsUp)
        XCTAssertEqual(headsUpSnapshot.remaining, 10, accuracy: 0.001)

        let breakSnapshot = scheduler.tick(now: start.addingTimeInterval(300))
        XCTAssertEqual(breakSnapshot.phase, .breaking)
        XCTAssertEqual(breakSnapshot.remaining, 10, accuracy: 0.001)

        let nextWorkSnapshot = scheduler.tick(now: start.addingTimeInterval(310))
        XCTAssertEqual(nextWorkSnapshot.phase, .working)
        XCTAssertEqual(nextWorkSnapshot.cycleCount, 2)
        XCTAssertEqual(nextWorkSnapshot.remaining, 300, accuracy: 0.001)
    }

    func testUpdatingSettingsWhilePausedPreservesPausedRemaining() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let scheduler = BreakScheduler(
            settings: BreakSettings(workMinutes: 5, breakSeconds: 20, headsUpSeconds: 0),
            now: start
        )

        _ = scheduler.tick(now: start.addingTimeInterval(30))
        let pausedSnapshot = scheduler.pause(now: start.addingTimeInterval(30))
        XCTAssertEqual(pausedSnapshot.phase, .paused(resumePhase: .working))
        XCTAssertEqual(pausedSnapshot.remaining, 270, accuracy: 0.001)

        let updatedSnapshot = scheduler.updateSettings(
            BreakSettings(workMinutes: 25, breakSeconds: 45, headsUpSeconds: 15),
            now: start.addingTimeInterval(50)
        )
        XCTAssertEqual(updatedSnapshot.phase, .paused(resumePhase: .working))
        XCTAssertEqual(updatedSnapshot.remaining, 270, accuracy: 0.001)

        let resumedSnapshot = scheduler.resume(now: start.addingTimeInterval(80))
        XCTAssertEqual(resumedSnapshot.phase, .working)
        XCTAssertEqual(resumedSnapshot.remaining, 270, accuracy: 0.001)
    }

    func testSettingsAreSanitizedToSupportedRanges() {
        let sanitized = BreakSettings(
            workMinutes: 0,
            breakSeconds: 3,
            headsUpSeconds: 999
        ).sanitized()

        XCTAssertEqual(sanitized.workMinutes, 5)
        XCTAssertEqual(sanitized.breakSeconds, 10)
        XCTAssertEqual(sanitized.headsUpSeconds, 120)
    }
}
