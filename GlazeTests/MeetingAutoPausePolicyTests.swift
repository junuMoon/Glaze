import XCTest
@testable import Glaze

final class MeetingAutoPausePolicyTests: XCTestCase {
    private let policy = MeetingAutoPausePolicy()

    func testPausesAnyRunningPhaseDuringMeeting() {
        XCTAssertEqual(
            policy.action(for: .working, pauseSource: nil, isMeetingActive: true),
            .pause
        )
        XCTAssertEqual(
            policy.action(for: .headsUp, pauseSource: nil, isMeetingActive: true),
            .pause
        )
        XCTAssertEqual(
            policy.action(for: .breaking, pauseSource: nil, isMeetingActive: true),
            .pause
        )
    }

    func testAdoptsMeetingPauseWhenAlreadyPausedByIdle() {
        XCTAssertEqual(
            policy.action(
                for: .paused(resumePhase: .working),
                pauseSource: .idle,
                isMeetingActive: true
            ),
            .adoptMeetingPause
        )
    }

    func testDoesNotOverrideManualPause() {
        XCTAssertEqual(
            policy.action(
                for: .paused(resumePhase: .working),
                pauseSource: .manual,
                isMeetingActive: true
            ),
            .none
        )
    }

    func testResumesWhenMeetingEnds() {
        XCTAssertEqual(
            policy.action(
                for: .paused(resumePhase: .breaking),
                pauseSource: .meeting,
                isMeetingActive: false
            ),
            .resume
        )
    }
}
