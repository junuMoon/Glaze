import Contacts
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
    let type: EKParticipantType
    let email: String?
}

struct MeetingEventSnapshot: Equatable {
    let isAllDay: Bool
    let eventStatus: EKEventStatus
    let availability: EKEventAvailability
    let organizerIsCurrentUser: Bool
    let organizerEmail: String?
    let selfEmails: Set<String>
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
        if organizerIsSelf(event) {
            return true
        }

        return event.participants.contains { participant in
            participantIsSelf(participant, in: event)
                && participant.role != .nonParticipant
                && isActiveResponseStatus(participant.status)
        }
    }

    private func hasAnotherParticipant(_ event: MeetingEventSnapshot) -> Bool {
        event.participants.contains { participant in
            !participantIsSelf(participant, in: event)
                && participant.type == .person
                && participant.role != .nonParticipant
                && isActiveResponseStatus(participant.status)
        }
    }

    private func organizerIsSelf(_ event: MeetingEventSnapshot) -> Bool {
        event.organizerIsCurrentUser
            || event.organizerEmail.map(event.selfEmails.contains) == true
    }

    private func participantIsSelf(
        _ participant: MeetingParticipantSnapshot,
        in event: MeetingEventSnapshot
    ) -> Bool {
        participant.isCurrentUser
            || participant.email.map(event.selfEmails.contains) == true
    }

    private func isActiveResponseStatus(_ status: EKParticipantStatus) -> Bool {
        switch status {
        case .accepted, .tentative, .inProcess:
            return true
        case .unknown, .pending, .declined, .delegated, .completed:
            return false
        @unknown default:
            return false
        }
    }
}

@MainActor
protocol SelfEmailProviding: AnyObject {
    func start()
    func selfEmails() -> Set<String>
}

@MainActor
final class ContactSelfEmailProvider: SelfEmailProviding {
    private let contactStore: CNContactStore
    private var accessRequested = false

    init(contactStore: CNContactStore = CNContactStore()) {
        self.contactStore = contactStore
    }

    func start() {
        requestAccessIfNeeded()
    }

    func selfEmails() -> Set<String> {
        requestAccessIfNeeded()
        guard hasContactsAccess else { return [] }

        let keys: [CNKeyDescriptor] = [CNContactEmailAddressesKey as CNKeyDescriptor]
        guard let meContact = try? contactStore.unifiedMeContactWithKeys(toFetch: keys) else {
            return []
        }

        return Set(
            meContact.emailAddresses.compactMap { labeledValue in
                normalizedEmail(from: labeledValue.value as String)
            }
        )
    }

    private var hasContactsAccess: Bool {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            return true
        case .denied, .restricted, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    private func requestAccessIfNeeded() {
        guard !accessRequested else { return }
        guard CNContactStore.authorizationStatus(for: .contacts) == .notDetermined else { return }

        accessRequested = true

        contactStore.requestAccess(for: .contacts) { _, _ in }
    }
}

@MainActor
final class MeetingMonitor: MeetingStatusProviding {
    private enum DefaultsKey {
        static let selfEmails = "Glaze.meetingSelfEmails"
    }

    private static let selfEmailRefreshInterval: TimeInterval = 60 * 60
    private static let selfEmailDiscoveryWindow: TimeInterval = 60 * 60 * 24 * 90

    private let eventStore: EKEventStore
    private let heuristics: MeetingEventHeuristics
    private let selfEmailProvider: SelfEmailProviding
    private let defaults: UserDefaults
    private var accessRequested = false
    private var knownSelfEmails: Set<String>
    private var lastSelfEmailRefreshAt: Date?

    init(
        eventStore: EKEventStore = EKEventStore(),
        heuristics: MeetingEventHeuristics = MeetingEventHeuristics(),
        selfEmailProvider: SelfEmailProviding = ContactSelfEmailProvider(),
        defaults: UserDefaults = .standard
    ) {
        self.eventStore = eventStore
        self.heuristics = heuristics
        self.selfEmailProvider = selfEmailProvider
        self.defaults = defaults
        knownSelfEmails = Set(defaults.stringArray(forKey: DefaultsKey.selfEmails) ?? [])
    }

    func start() {
        requestAccessIfNeeded()
        selfEmailProvider.start()
    }

    func isMeetingInProgress(at date: Date) -> Bool {
        requestAccessIfNeeded()

        guard hasCalendarAccess else { return false }
        refreshKnownSelfEmailsIfNeeded(around: date)

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

    private func refreshKnownSelfEmailsIfNeeded(around date: Date) {
        guard shouldRefreshSelfEmails(at: date) else { return }
        lastSelfEmailRefreshAt = date

        let predicate = eventStore.predicateForEvents(
            withStart: date.addingTimeInterval(-Self.selfEmailDiscoveryWindow),
            end: date.addingTimeInterval(Self.selfEmailDiscoveryWindow),
            calendars: nil
        )

        let discoveredEmails = eventStore.events(matching: predicate).reduce(into: Set<String>()) { emails, event in
            if event.organizer?.isCurrentUser == true,
               let organizerEmail = normalizedEmail(from: event.organizer?.url) {
                emails.insert(organizerEmail)
            }

            for attendee in event.attendees ?? [] where attendee.isCurrentUser {
                if let attendeeEmail = normalizedEmail(from: attendee.url) {
                    emails.insert(attendeeEmail)
                }
            }
        }

        mergeKnownSelfEmails(discoveredEmails)
    }

    private func shouldRefreshSelfEmails(at date: Date) -> Bool {
        if knownSelfEmails.isEmpty {
            return true
        }

        guard let lastSelfEmailRefreshAt else { return true }
        return date.timeIntervalSince(lastSelfEmailRefreshAt) >= Self.selfEmailRefreshInterval
    }

    private func mergeKnownSelfEmails(_ emails: Set<String>) {
        guard !emails.isEmpty else { return }

        let updatedEmails = knownSelfEmails.union(emails)
        guard updatedEmails != knownSelfEmails else { return }

        knownSelfEmails = updatedEmails
        defaults.set(Array(updatedEmails).sorted(), forKey: DefaultsKey.selfEmails)
    }

    private func shouldPause(for event: EKEvent) -> Bool {
        let organizerEmail = normalizedEmail(from: event.organizer?.url)
        let participants = (event.attendees ?? []).map { participant in
            MeetingParticipantSnapshot(
                isCurrentUser: participant.isCurrentUser,
                status: participant.participantStatus,
                role: participant.participantRole,
                type: participant.participantType,
                email: normalizedEmail(from: participant.url)
            )
        }
        mergeKnownSelfEmails(selfEmailProvider.selfEmails())
        let eventSelfEmails = Set(
            participants.compactMap { participant in
                participant.isCurrentUser ? participant.email : nil
            }
        )
        mergeKnownSelfEmails(eventSelfEmails)
        var selfEmails = knownSelfEmails

        if event.organizer?.isCurrentUser == true, let organizerEmail {
            mergeKnownSelfEmails([organizerEmail])
            selfEmails.insert(organizerEmail)
        }

        for participant in participants where participant.isCurrentUser {
            if let email = participant.email {
                selfEmails.insert(email)
            }
        }

        return heuristics.shouldPause(
            for: MeetingEventSnapshot(
                isAllDay: event.isAllDay,
                eventStatus: event.status,
                availability: event.availability,
                organizerIsCurrentUser: event.organizer?.isCurrentUser ?? false,
                organizerEmail: organizerEmail,
                selfEmails: selfEmails,
                participants: participants
            )
        )
    }
}

private func normalizedEmail(from url: URL?) -> String? {
    guard let url else { return nil }

    let rawValue = url.absoluteString
    let mailtoPrefix = "mailto:"

    if rawValue.lowercased().hasPrefix(mailtoPrefix) {
        return normalizedEmail(from: String(rawValue.dropFirst(mailtoPrefix.count)))
    }

    return normalizedEmail(from: rawValue)
}

private func normalizedEmail(from rawValue: String?) -> String? {
    guard let rawValue else { return nil }

    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    guard !trimmed.isEmpty else { return nil }
    return trimmed
}
