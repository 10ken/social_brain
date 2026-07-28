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

    init(
        id: UUID = UUID(),
        eventIdentifier: String? = nil,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String? = nil,
        calendarIdentifier: String? = nil
    ) {
        self.id = id
        self.eventIdentifier = eventIdentifier
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.calendarIdentifier = calendarIdentifier
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
}

enum CalendarServiceError: Error, Equatable {
    case calendarUnavailable
    case readAccessRequired
    case writeAccessRequired
    case invalidDateRange
    case eventNotFound
    case noWritableCalendar
}

/// EventKit is accessed only through explicit user actions. No calendar event
/// is created, changed, or read by background sync.
@MainActor
protocol CalendarService: AnyObject {
    var authorizationState: CalendarAuthorizationState { get }
    func requestFullAccess() async -> CalendarAuthorizationState
    func events(from startDate: Date, through endDate: Date) throws -> [DeviceCalendarEvent]
    func save(_ draft: CalendarEventDraft) throws -> DeviceCalendarEvent
    func deleteEvent(identifier: String) throws
}

@MainActor
final class EventKitCalendarService: CalendarService {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    var authorizationState: CalendarAuthorizationState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: .notDetermined
        case .authorized: .fullAccess
        case .fullAccess: .fullAccess
        case .writeOnly: .writeOnly
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .unavailable
        }
    }

    func requestFullAccess() async -> CalendarAuthorizationState {
        guard authorizationState == .notDetermined else { return authorizationState }
        do {
            _ = try await eventStore.requestFullAccessToEvents()
        } catch {
            // The caller only needs the resulting state; EventKit errors can
            // contain implementation details that should not be surfaced.
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
        event.notes = emptyToNil(draft.notes)
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

    func deleteEvent(identifier: String) throws {
        guard authorizationState.canWrite else { throw CalendarServiceError.writeAccessRequired }
        guard let event = eventStore.event(withIdentifier: identifier) else { throw CalendarServiceError.eventNotFound }
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }

    private static func deviceEvent(from event: EKEvent) -> DeviceCalendarEvent? {
        guard let identifier = event.eventIdentifier,
              let calendar = event.calendar,
              let calendarIdentifier = calendar.calendarIdentifier
        else { return nil }
        return DeviceCalendarEvent(
            id: identifier,
            title: event.title ?? "Untitled event",
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location,
            notes: event.notes,
            calendarIdentifier: calendarIdentifier
        )
    }

    private func emptyToNil(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
