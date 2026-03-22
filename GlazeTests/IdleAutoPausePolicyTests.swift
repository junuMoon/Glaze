import XCTest
@testable import Glaze

final class IdleAutoPausePolicyTests: XCTestCase {
    private let policy = IdleAutoPausePolicy(pauseThreshold: 120, resumeThreshold: 2)

    func testPausesWorkingOrHeadsUpAfterIdleThreshold() {
        XCTAssertEqual(
            policy.action(for: .working, pauseSource: nil, idleSeconds: 120),
            .pause
        )
        XCTAssertEqual(
            policy.action(for: .headsUp, pauseSource: nil, idleSeconds: 180),
            .pause
        )
    }

    func testDoesNotPauseDuringBreakOrManualPause() {
        XCTAssertEqual(
            policy.action(for: .breaking, pauseSource: nil, idleSeconds: 180),
            .none
        )
        XCTAssertEqual(
            policy.action(for: .working, pauseSource: .manual, idleSeconds: 180),
            .none
        )
    }

    func testResumesAutoPausedSessionWhenActivityReturns() {
        XCTAssertEqual(
            policy.action(for: .paused(resumePhase: .working), pauseSource: .idle, idleSeconds: 1),
            .resume
        )
    }

    func testKeepsAutoPausedSessionPausedWhileStillIdle() {
        XCTAssertEqual(
            policy.action(for: .paused(resumePhase: .working), pauseSource: .idle, idleSeconds: 30),
            .none
        )
    }
}
