import EventKit
import Foundation

enum MeetingAutoPauseAction: Equatable {
    case none
    case pause
    case adoptMeetingPause
    case resume
}

struct MeetingAutoPausePolicy: Equatable {
    func action(
        for phase: SessionPhase,
        pauseSource: PauseSource?,
        isMeetingActive: Bool
    ) -> MeetingAutoPauseAction {
        if pauseSource == .manual {
            return .none
        }

        if isMeetingActive {
            if pauseSource == .meeting {
                return .none
            }

            if case .paused = phase {
                return .adoptMeetingPause
            }

            return .pause
        }

        return pauseSource == .meeting ? .resume : .none
    }
}

@MainActor
protocol MeetingStatusProviding: AnyObject {
    func start()
    func isMeetingInProgress(at date: Date) -> Bool
}

struct MeetingParticipantSnapshot: Equatable {
    let isCurrentUser: Bool
    let status: EKParticipantStatus
    let role: EKParticipantRole
}

struct MeetingEventSnapshot: Equatable {
    let isAllDay: Bool
    let eventStatus: EKEventStatus
    let availability: EKEventAvailability
    let organizerIsCurrentUser: Bool
    let participants: [MeetingParticipantSnapshot]
}

struct MeetingEventHeuristics {
    func shouldPause(for event: MeetingEventSnapshot) -> Bool {
        guard !event.isAllDay else { return false }
        guard event.eventStatus != .canceled else { return false }
        guard event.availability != .free else { return false }
        guard currentUserIsInMeeting(event) else { return false }
        return hasAnotherParticipant(event)
    }

    private func currentUserIsInMeeting(_ event: MeetingEventSnapshot) -> Bool {
        if event.organizerIsCurrentUser {
            return true
        }

        return event.participants.contains { participant in
            participant.isCurrentUser
                && participant.role != .nonParticipant
                && participant.status != .declined
        }
    }

    private func hasAnotherParticipant(_ event: MeetingEventSnapshot) -> Bool {
        event.participants.contains { participant in
            !participant.isCurrentUser
                && participant.role != .nonParticipant
                && participant.status != .declined
        }
    }
}

@MainActor
final class MeetingMonitor: MeetingStatusProviding {
    private let eventStore: EKEventStore
    private let heuristics: MeetingEventHeuristics
    private var accessRequested = false

    init(
        eventStore: EKEventStore = EKEventStore(),
        heuristics: MeetingEventHeuristics = MeetingEventHeuristics()
    ) {
        self.eventStore = eventStore
        self.heuristics = heuristics
    }

    func start() {
        requestAccessIfNeeded()
    }

    func isMeetingInProgress(at date: Date) -> Bool {
        requestAccessIfNeeded()

        guard hasCalendarAccess else { return false }

        let predicate = eventStore.predicateForEvents(
            withStart: date.addingTimeInterval(-60),
            end: date.addingTimeInterval(60),
            calendars: nil
        )

        return eventStore.events(matching: predicate).contains { event in
            event.startDate <= date
                && event.endDate > date
                && shouldPause(for: event)
        }
    }

    private var hasCalendarAccess: Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess:
            return true
        case .denied, .restricted, .notDetermined, .writeOnly:
            return false
        @unknown default:
            return false
        }
    }

    private func requestAccessIfNeeded() {
        guard !accessRequested else { return }
        guard EKEventStore.authorizationStatus(for: .event) == .notDetermined else { return }

        accessRequested = true

        if #available(macOS 14.0, *) {
            Task { @MainActor in
                _ = try? await eventStore.requestFullAccessToEvents()
            }
        } else {
            eventStore.requestAccess(to: .event) { _, _ in }
        }
    }

    private func shouldPause(for event: EKEvent) -> Bool {
        heuristics.shouldPause(
            for: MeetingEventSnapshot(
                isAllDay: event.isAllDay,
                eventStatus: event.status,
                availability: event.availability,
                organizerIsCurrentUser: event.organizer?.isCurrentUser ?? false,
                participants: (event.attendees ?? []).map { participant in
                    MeetingParticipantSnapshot(
                        isCurrentUser: participant.isCurrentUser,
                        status: participant.participantStatus,
                        role: participant.participantRole
                    )
                }
            )
        )
    }
}
