import EventKit
import XCTest
@testable import Glaze

final class MeetingEventHeuristicsTests: XCTestCase {
    private let heuristics = MeetingEventHeuristics()

    func testIgnoresBusyEventWithoutCurrentUser() {
        XCTAssertFalse(
            heuristics.shouldPause(
                for: event(
                    organizerIsCurrentUser: false,
                    participants: [
                        participant(isCurrentUser: false, status: .accepted)
                    ]
                )
            )
        )
    }

    func testIgnoresSoloBusyBlockOwnedByCurrentUser() {
        XCTAssertFalse(
            heuristics.shouldPause(
                for: event(
                    organizerIsCurrentUser: true,
                    participants: [
                        participant(isCurrentUser: true, status: .accepted)
                    ]
                )
            )
        )
    }

    func testAcceptsMeetingWhenCurrentUserIsAttendeeWithOthers() {
        XCTAssertTrue(
            heuristics.shouldPause(
                for: event(
                    organizerIsCurrentUser: false,
                    participants: [
                        participant(isCurrentUser: true, status: .accepted),
                        participant(isCurrentUser: false, status: .accepted)
                    ]
                )
            )
        )
    }

    func testAcceptsMeetingWhenCurrentUserIsOrganizerWithOthers() {
        XCTAssertTrue(
            heuristics.shouldPause(
                for: event(
                    organizerIsCurrentUser: true,
                    participants: [
                        participant(isCurrentUser: false, status: .accepted)
                    ]
                )
            )
        )
    }

    func testIgnoresDeclinedMeetings() {
        XCTAssertFalse(
            heuristics.shouldPause(
                for: event(
                    organizerIsCurrentUser: false,
                    participants: [
                        participant(isCurrentUser: true, status: .declined),
                        participant(isCurrentUser: false, status: .accepted)
                    ]
                )
            )
        )
    }

    private func event(
        isAllDay: Bool = false,
        status: EKEventStatus = .confirmed,
        availability: EKEventAvailability = .busy,
        organizerIsCurrentUser: Bool,
        participants: [MeetingParticipantSnapshot]
    ) -> MeetingEventSnapshot {
        MeetingEventSnapshot(
            isAllDay: isAllDay,
            eventStatus: status,
            availability: availability,
            organizerIsCurrentUser: organizerIsCurrentUser,
            participants: participants
        )
    }

    private func participant(
        isCurrentUser: Bool,
        status: EKParticipantStatus,
        role: EKParticipantRole = .required
    ) -> MeetingParticipantSnapshot {
        MeetingParticipantSnapshot(
            isCurrentUser: isCurrentUser,
            status: status,
            role: role
        )
    }
}
