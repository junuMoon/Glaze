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

    func testIgnoresMeetingsWhenCurrentUserHasNotAccepted() {
        XCTAssertFalse(
            heuristics.shouldPause(
                for: event(
                    organizerIsCurrentUser: false,
                    participants: [
                        participant(isCurrentUser: true, status: .pending),
                        participant(isCurrentUser: false, status: .accepted)
                    ]
                )
            )
        )
    }

    func testIgnoresRoomOnlyEvents() {
        XCTAssertFalse(
            heuristics.shouldPause(
                for: event(
                    organizerIsCurrentUser: true,
                    participants: [
                        participant(
                            isCurrentUser: false,
                            status: .accepted,
                            type: .room
                        )
                    ]
                )
            )
        )
    }

    func testIgnoresSecondarySelfAliasAsAnotherParticipant() {
        XCTAssertFalse(
            heuristics.shouldPause(
                for: event(
                    organizerIsCurrentUser: false,
                    selfEmails: ["fran@rtzr.ai", "francomoon7@gmail.com"],
                    participants: [
                        participant(
                            isCurrentUser: true,
                            status: .accepted,
                            email: "fran@rtzr.ai"
                        ),
                        participant(
                            isCurrentUser: false,
                            status: .accepted,
                            email: "francomoon7@gmail.com"
                        )
                    ]
                )
            )
        )
    }

    func testAcceptsMeetingWhenThirdPartyExistsAlongsideSelfAliases() {
        XCTAssertTrue(
            heuristics.shouldPause(
                for: event(
                    organizerIsCurrentUser: false,
                    selfEmails: ["fran@rtzr.ai", "francomoon7@gmail.com"],
                    participants: [
                        participant(
                            isCurrentUser: true,
                            status: .accepted,
                            email: "fran@rtzr.ai"
                        ),
                        participant(
                            isCurrentUser: false,
                            status: .accepted,
                            email: "francomoon7@gmail.com"
                        ),
                        participant(
                            isCurrentUser: false,
                            status: .accepted,
                            email: "jk@rtzr.ai"
                        )
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
        organizerEmail: String? = nil,
        selfEmails: Set<String> = [],
        participants: [MeetingParticipantSnapshot]
    ) -> MeetingEventSnapshot {
        MeetingEventSnapshot(
            isAllDay: isAllDay,
            eventStatus: status,
            availability: availability,
            organizerIsCurrentUser: organizerIsCurrentUser,
            organizerEmail: organizerEmail,
            selfEmails: selfEmails,
            participants: participants
        )
    }

    private func participant(
        isCurrentUser: Bool,
        status: EKParticipantStatus,
        role: EKParticipantRole = .required,
        type: EKParticipantType = .person,
        email: String? = nil
    ) -> MeetingParticipantSnapshot {
        MeetingParticipantSnapshot(
            isCurrentUser: isCurrentUser,
            status: status,
            role: role,
            type: type,
            email: email
        )
    }
}
