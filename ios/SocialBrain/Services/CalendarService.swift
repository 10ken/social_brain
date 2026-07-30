import EventKit
import Foundation

enum CalendarAuthorizationState: Equatable {
    case notDetermined
    case fullAccess
    case writeOnly
    case denied
    case restricted
    case unavailable

    var canRead: Bool { self == .fullAccess }
    var canWrite: Bool { self == .fullAccess || self == .writeOnly }
}

struct CalendarEventDraft: Equatable, Identifiable {
    let id: UUID
    var eventIdentifier: String?
    var title: String
    var startDate: Date
    var endDate: Date
    var location: String?
    var notes: String?
    var calendarIdentifier: String?
    /// The local SocialEventRecord UUID. When present, EventKit receives an
    /// ownership marker so only this app's exports can later be removed.
    var socialBrainOwnerID: UUID?

    init(
        id: UUID = UUID(),
        eventIdentifier: String? = nil,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String? = nil,
        calendarIdentifier: String? = nil,
        socialBrainOwnerID: UUID? = nil
    ) {
        self.id = id
        self.eventIdentifier = eventIdentifier
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.calendarIdentifier = calendarIdentifier
        self.socialBrainOwnerID = socialBrainOwnerID
    }
}

struct DeviceCalendarEvent: Equatable, Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let calendarIdentifier: String
    let socialBrainOwnerID: UUID?

    init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String? = nil,
        calendarIdentifier: String,
        socialBrainOwnerID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.calendarIdentifier = calendarIdentifier
        self.socialBrainOwnerID = socialBrainOwnerID
    }
}

enum CalendarServiceError: Error, Equatable {
    case calendarUnavailable
    case readAccessRequired
    case writeAccessRequired
    case invalidDateRange
    case eventNotFound
    case noWritableCalendar
    case calendarMismatch
    case eventIsNotSocialBrainExport
}

/// A small, deterministic ownership marker. It is intentionally checked by
/// both the UI and EventKit service before a destructive delete is attempted.
enum CalendarEventOwnership {
    private static let markerPrefix = "[Social Brain export:"

    static func marker(for ownerID: UUID) -> String {
        "\(markerPrefix) \(ownerID.uuidString.lowercased())]"
    }

    static func ownerID(in notes: String?) -> UUID? {
        guard let notes,
              let start = notes.range(of: markerPrefix),
              let end = notes[start.lowerBound...].firstIndex(of: "]")
        else { return nil }
        return UUID(uuidString: String(notes[start.upperBound..<end]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func notes(_ notes: String?, ownerID: UUID?) -> String? {
        let normalized = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ownerID else { return normalized?.isEmpty == false ? normalized : nil }
        let marker = marker(for: ownerID)
        guard normalized?.contains(marker) != true else { return normalized }
        return [normalized?.isEmpty == false ? normalized : nil, marker]
            .compactMap { $0 }
            .joined(separator: "\n\n")
    }
}

/// EventKit is accessed only through explicit user actions. No calendar event
/// is created, changed, or read by background sync.
@MainActor
protocol CalendarService: AnyObject {
    var authorizationState: CalendarAuthorizationState { get }
    func requestFullAccess() async -> CalendarAuthorizationState
    func requestWriteOnlyAccess() async -> CalendarAuthorizationState
    func events(from startDate: Date, through endDate: Date) throws -> [DeviceCalendarEvent]
    func save(_ draft: CalendarEventDraft) throws -> DeviceCalendarEvent
    func deleteSocialBrainExportedEvent(
        identifier: String,
        calendarIdentifier: String,
        ownerID: UUID
    ) throws
}

@MainActor
final class EventKitCalendarService: CalendarService {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    var authorizationState: CalendarAuthorizationState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notDetermined
        case .authorized: return .fullAccess
        case .fullAccess: return .fullAccess
        case .writeOnly: return .writeOnly
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .unavailable
        }
    }

    func requestFullAccess() async -> CalendarAuthorizationState {
        guard authorizationState == .notDetermined || authorizationState == .writeOnly else {
            return authorizationState
        }
        do {
            _ = try await eventStore.requestFullAccessToEvents()
        } catch {
            // The caller only needs the resulting state; EventKit errors can
            // contain implementation details that should not be surfaced.
        }
        return authorizationState
    }

    func requestWriteOnlyAccess() async -> CalendarAuthorizationState {
        guard authorizationState == .notDetermined else { return authorizationState }
        do {
            _ = try await eventStore.requestWriteOnlyAccessToEvents()
        } catch {
            // The caller deliberately receives only a safe, user-actionable
            // resulting state rather than an EventKit implementation error.
        }
        return authorizationState
    }

    func events(from startDate: Date, through endDate: Date) throws -> [DeviceCalendarEvent] {
        guard startDate <= endDate else { throw CalendarServiceError.invalidDateRange }
        guard authorizationState.canRead else { throw CalendarServiceError.readAccessRequired }
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate).compactMap(Self.deviceEvent(from:))
    }

    func save(_ draft: CalendarEventDraft) throws -> DeviceCalendarEvent {
        guard draft.startDate < draft.endDate else { throw CalendarServiceError.invalidDateRange }
        guard authorizationState.canWrite else { throw CalendarServiceError.writeAccessRequired }

        let event: EKEvent
        if let identifier = draft.eventIdentifier {
            guard let existingEvent = eventStore.event(withIdentifier: identifier) else {
                throw CalendarServiceError.eventNotFound
            }
            event = existingEvent
        } else {
            event = EKEvent(eventStore: eventStore)
        }

        event.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.location = emptyToNil(draft.location)
        event.notes = CalendarEventOwnership.notes(draft.notes, ownerID: draft.socialBrainOwnerID)
        if let calendarIdentifier = draft.calendarIdentifier {
            guard let calendar = eventStore.calendar(withIdentifier: calendarIdentifier), calendar.allowsContentModifications else {
                throw CalendarServiceError.noWritableCalendar
            }
            event.calendar = calendar
        } else if event.calendar == nil {
            guard let calendar = eventStore.defaultCalendarForNewEvents else {
                throw CalendarServiceError.noWritableCalendar
            }
            event.calendar = calendar
        }

        try eventStore.save(event, span: .thisEvent, commit: true)
        guard let deviceEvent = Self.deviceEvent(from: event) else { throw CalendarServiceError.calendarUnavailable }
        return deviceEvent
    }

    func deleteSocialBrainExportedEvent(
        identifier: String,
        calendarIdentifier: String,
        ownerID: UUID
    ) throws {
        guard authorizationState.canWrite else { throw CalendarServiceError.writeAccessRequired }
        guard let event = eventStore.event(withIdentifier: identifier) else { throw CalendarServiceError.eventNotFound }
        guard let calendar = event.calendar, calendar.calendarIdentifier == calendarIdentifier else {
            throw CalendarServiceError.calendarMismatch
        }
        guard CalendarEventOwnership.ownerID(in: event.notes) == ownerID else {
            throw CalendarServiceError.eventIsNotSocialBrainExport
        }
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }

    private static func deviceEvent(from event: EKEvent) -> DeviceCalendarEvent? {
        guard let identifier = event.eventIdentifier,
              let calendar = event.calendar
        else { return nil }
        // EKCalendar.calendarIdentifier is non-optional on current iOS SDKs.
        let calendarIdentifier = calendar.calendarIdentifier
        return DeviceCalendarEvent(
            id: identifier,
            title: event.title ?? "Untitled event",
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location,
            notes: event.notes,
            calendarIdentifier: calendarIdentifier,
            socialBrainOwnerID: CalendarEventOwnership.ownerID(in: event.notes)
        )
    }

    private func emptyToNil(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
