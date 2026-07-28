import SwiftData
import SwiftUI

@MainActor
struct CalendarWorkspaceView: View {
    @Query(sort: \SocialEventRecord.startTime) private var allEvents: [SocialEventRecord]
    private let calendarService = EventKitCalendarService()
    @State private var showingEditor = false
    @State private var showingAccessInfo = false
    @State private var showingDeviceImport = false
    @State private var calendarState: CalendarAuthorizationState = .unavailable

    private var events: [SocialEventRecord] { allEvents.filter(\.isVisibleInDefaultLists) }

    var body: some View {
        NavigationStack {
            List {
                CalendarAccessCard(
                    state: calendarState,
                    showingAccessInfo: $showingAccessInfo,
                    requestAccess: requestCalendarAccess,
                    importEvents: { showingDeviceImport = true }
                )

                Section("Events") {
                    if events.isEmpty {
                        ContentUnavailableView(
                            "No events yet",
                            systemImage: "calendar.badge.plus",
                            description: Text("Create an event manually or confirm one from a reviewed capture.")
                        )
                    }
                    ForEach(events) { event in
                        NavigationLink {
                            SocialEventDetailView(event: event)
                        } label: {
                            EventSummaryRow(event: event)
                        }
                    }
                }
            }
            .navigationTitle("Calendar")
            .toolbar {
                Button("Add", systemImage: "plus") { showingEditor = true }
            }
            .sheet(isPresented: $showingEditor) {
                SocialEventEditorView(event: nil, sourceCapture: nil)
            }
            .sheet(isPresented: $showingAccessInfo) {
                CalendarAccessRationaleView()
            }
            .sheet(isPresented: $showingDeviceImport) {
                DeviceCalendarImportView(calendarService: calendarService)
            }
            .task {
                calendarState = calendarService.authorizationState
            }
        }
    }

    private func requestCalendarAccess() {
        Task {
            calendarState = await calendarService.requestFullAccess()
        }
    }
}

private struct CalendarAccessCard: View {
    let state: CalendarAuthorizationState
    @Binding var showingAccessInfo: Bool
    let requestAccess: () -> Void
    let importEvents: () -> Void

    var body: some View {
        Section("Device Calendar") {
            switch state {
            case .unavailable:
                Label("Calendar connection is not configured", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                Text("You can still plan events locally. Calendar access is unavailable on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .notDetermined:
                Label("Calendar permission needed", systemImage: "calendar.badge.clock")
                Button("Allow Calendar Access", action: requestAccess)
            case .denied, .restricted:
                Label("Calendar access was denied", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text("Enable calendar access in iOS Settings to read or write selected events.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .fullAccess:
                Label("Device calendar available", systemImage: "calendar.badge.checkmark")
                    .foregroundStyle(.green)
                Button("Import upcoming events", action: importEvents)
            case .writeOnly:
                Label("Calendar write access is available", systemImage: "calendar.badge.checkmark")
                    .foregroundStyle(.green)
                Text("You can export a confirmed event, but iOS has not granted read access for import.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("How calendar access works") {
                showingAccessInfo = true
            }
        }
    }
}

@MainActor
private struct DeviceCalendarImportView: View {
    let calendarService: any CalendarService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var deviceEvents: [DeviceCalendarEvent] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var eventPendingDeletion: DeviceCalendarEvent?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    ContentUnavailableView("Calendar events unavailable", systemImage: "calendar.badge.exclamationmark", description: Text(errorMessage))
                } else if isLoading {
                    HStack {
                        ProgressView()
                        Text("Loading upcoming events…")
                    }
                } else if deviceEvents.isEmpty {
                    ContentUnavailableView("No upcoming device events", systemImage: "calendar")
                } else {
                    ForEach(deviceEvents) { deviceEvent in
                        Button {
                            importEvent(deviceEvent)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(deviceEvent.title).font(.headline)
                                Text(deviceEvent.startDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                                    .font(.footnote)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                eventPendingDeletion = deviceEvent
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import Calendar Events")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task { loadEvents() }
            .confirmationDialog(
                "Delete this device-calendar event?",
                isPresented: Binding(
                    get: { eventPendingDeletion != nil },
                    set: { if !$0 { eventPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete from Device Calendar", role: .destructive, action: deletePendingEvent)
                Button("Cancel", role: .cancel) { eventPendingDeletion = nil }
            } message: {
                Text("This removes the selected event from the device calendar. It does not affect other local Social Brain records.")
            }
        }
    }

    private func loadEvents() {
        do {
            let end = Calendar.current.date(byAdding: .day, value: 60, to: .now) ?? .now
            deviceEvents = try calendarService.events(from: .now, through: end)
            isLoading = false
        } catch {
            errorMessage = "Grant full calendar access to import selected events."
            isLoading = false
        }
    }

    private func importEvent(_ deviceEvent: DeviceCalendarEvent) {
        let record = SocialEventRecord(title: deviceEvent.title, startTime: deviceEvent.startDate)
        record.endTime = deviceEvent.endDate
        record.location = deviceEvent.location
        record.evidenceText = deviceEvent.notes
        record.confidenceState = "confirmed"
        modelContext.insert(record)
        saveLocalChanges(modelContext)
        dismiss()
    }

    private func deletePendingEvent() {
        guard let event = eventPendingDeletion else { return }
        do {
            try calendarService.deleteEvent(identifier: event.id)
            deviceEvents.removeAll { $0.id == event.id }
        } catch {
            errorMessage = "This device-calendar event could not be deleted."
        }
        eventPendingDeletion = nil
    }
}

private struct CalendarAccessRationaleView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Read") {
                    Text("When enabled, importing reads only the device-calendar events you select for review. It does not automatically copy your whole calendar into Social Brain.")
                }
                Section("Write") {
                    Text("When enabled, exporting writes only a confirmed Social Brain event to the calendar you choose. It never changes an event without your action.")
                }
                Section("If access is denied") {
                    Text("Local events continue to work. You can grant access later in iOS Settings.")
                }
            }
            .navigationTitle("Calendar Access")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

@MainActor
struct SocialEventDetailView: View {
    let event: SocialEventRecord

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroupRecord.name) private var groups: [GroupRecord]
    @Query(sort: \PersonRecord.fullName) private var people: [PersonRecord]
    @Query private var attendeeLinks: [EventAttendeeRecord]
    @State private var showingEditor = false
    @State private var showingCalendarRationale = false
    @State private var calendarExportMessage: String?

    private var attendees: [PersonRecord] {
        let personIDs = Set(attendeeLinks.filter {
            $0.eventID == event.id && $0.isVisibleInDefaultLists
        }.map(\.personID))
        return people.filter { personIDs.contains($0.id) && $0.isVisibleInDefaultLists }
    }

    var body: some View {
        Form {
            Section("Event") {
                LabeledContent("Title", value: event.title)
                if let start = event.startTime {
                    LabeledContent("Starts", value: start.formatted(date: .abbreviated, time: .shortened))
                }
                if let end = event.endTime {
                    LabeledContent("Ends", value: end.formatted(date: .abbreviated, time: .shortened))
                }
                if let dateText = event.dateText, !dateText.isEmpty, event.startTime == nil {
                    LabeledContent("When", value: dateText)
                }
                if let location = event.location, !location.isEmpty {
                    LabeledContent("Location", value: location)
                }
                HStack {
                    Text("Status")
                    Spacer()
                    ConfidenceBadge(state: event.confidenceState)
                }
            }

            if let group = groups.first(where: { $0.id == event.groupID }) {
                Section("Group") {
                    NavigationLink(group.name) { GroupDetailView(group: group) }
                }
            }

            if !attendees.isEmpty {
                Section("Attendees") {
                    ForEach(attendees) { attendee in
                        NavigationLink(attendee.fullName) { PersonDetailView(person: attendee) }
                    }
                }
            }

            Section("Device Calendar") {
                if event.startTime != nil, event.endTime != nil {
                    Button("Add to Device Calendar") { exportToCalendar() }
                } else {
                    Label("Add a start and end time to export", systemImage: "calendar.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                }
                Button("About calendar export") { showingCalendarRationale = true }
                Text(calendarExportMessage ?? "Export only happens when you tap Add to Device Calendar. This local event is never shared automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            EvidenceSection(evidenceText: event.evidenceText, sourceID: event.sourceID)
        }
        .navigationTitle(event.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit", systemImage: "pencil") { showingEditor = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                RecordLifecycleActions(
                    isArchived: event.archivedAt != nil,
                    archive: {
                        event.archivedAt = .now
                        event.markUpdated()
                        saveLocalChanges(modelContext)
                    },
                    restore: {
                        event.archivedAt = nil
                        event.markUpdated()
                        saveLocalChanges(modelContext)
                    },
                    delete: {
                        event.deletedAt = .now
                        event.markUpdated()
                        saveLocalChanges(modelContext)
                    }
                )
            }
        }
        .sheet(isPresented: $showingEditor) {
            SocialEventEditorView(event: event, sourceCapture: nil)
        }
        .sheet(isPresented: $showingCalendarRationale) {
            CalendarAccessRationaleView()
        }
    }

    private func exportToCalendar() {
        guard let start = event.startTime, let end = event.endTime else { return }
        let service = EventKitCalendarService()
        guard service.authorizationState.canWrite else {
            calendarExportMessage = "Grant Calendar write access before exporting this event."
            return
        }
        do {
            _ = try service.save(CalendarEventDraft(
                title: event.title,
                startDate: start,
                endDate: end,
                location: event.location,
                notes: event.evidenceText
            ))
            calendarExportMessage = "Added to your device calendar."
        } catch {
            calendarExportMessage = "This event could not be added to the selected device calendar."
        }
    }
}

struct SocialEventEditorView: View {
    let event: SocialEventRecord?
    let sourceCapture: CaptureRecord?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroupRecord.name) private var allGroups: [GroupRecord]
    @Query(sort: \PersonRecord.fullName) private var allPeople: [PersonRecord]
    @Query private var attendeeLinks: [EventAttendeeRecord]
    @State private var title: String
    @State private var hasSchedule: Bool
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var dateText: String
    @State private var location: String
    @State private var groupID: UUID?
    @State private var selectedPersonIDs: Set<UUID> = []
    @State private var evidenceText: String
    @State private var didLoadAttendees = false

    init(event: SocialEventRecord?, sourceCapture: CaptureRecord?, prefillText: String? = nil) {
        self.event = event
        self.sourceCapture = sourceCapture
        _title = State(initialValue: event?.title ?? prefillText ?? "")
        _hasSchedule = State(initialValue: event?.startTime != nil)
        _startTime = State(initialValue: event?.startTime ?? .now)
        _endTime = State(initialValue: event?.endTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now)
        _dateText = State(initialValue: event?.dateText ?? "")
        _location = State(initialValue: event?.location ?? "")
        _groupID = State(initialValue: event?.groupID)
        _evidenceText = State(initialValue: event?.evidenceText ?? prefillText ?? "")
    }

    private var people: [PersonRecord] { allPeople.filter(\.isVisibleInDefaultLists) }
    private var groups: [GroupRecord] { allGroups.filter(\.isVisibleInDefaultLists) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Title", text: $title)
                    Toggle("Set date and time", isOn: $hasSchedule)
                    if hasSchedule {
                        DatePicker("Starts", selection: $startTime)
                        DatePicker("Ends", selection: $endTime, in: startTime...)
                    } else {
                        TextField("When (optional)", text: $dateText)
                    }
                    TextField("Location", text: $location)
                }
                Section("Community") {
                    Picker("Group", selection: $groupID) {
                        Text("None").tag(UUID?.none)
                        ForEach(groups) { group in
                            Text(group.name).tag(group.id as UUID?)
                        }
                    }
                    NavigationLink {
                        AttendeePickerView(
                            people: people,
                            selectedPersonIDs: $selectedPersonIDs
                        )
                    } label: {
                        HStack {
                            Label("Attendees", systemImage: "person.2")
                            Spacer()
                            Text(selectedPersonIDs.isEmpty ? "None" : "\(selectedPersonIDs.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Evidence") {
                    TextField("Why is this event relevant?", text: $evidenceText, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(event == nil ? "New Event" : "Edit Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (hasSchedule && endTime < startTime))
                }
            }
            .onAppear(perform: loadExistingAttendees)
        }
    }

    private func loadExistingAttendees() {
        guard !didLoadAttendees, let event else { return }
        selectedPersonIDs = Set(attendeeLinks.filter {
            $0.eventID == event.id && $0.isVisibleInDefaultLists
        }.map(\.personID))
        didLoadAttendees = true
    }

    private func save() {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = event ?? SocialEventRecord(title: value, startTime: hasSchedule ? startTime : nil)
        record.title = value
        record.startTime = hasSchedule ? startTime : nil
        record.endTime = hasSchedule ? endTime : nil
        record.dateText = hasSchedule ? nil : optional(dateText)
        record.location = optional(location)
        record.groupID = groupID
        record.sourceID = sourceCapture?.id ?? record.sourceID
        record.evidenceText = optional(evidenceText)
        record.confidenceState = "confirmed"
        record.markUpdated()
        if event == nil { modelContext.insert(record) }

        updateAttendees(for: record)

        if let sourceCapture {
            sourceCapture.processed = true
            sourceCapture.markUpdated()
        }
        saveLocalChanges(modelContext)
        dismiss()
    }

    private func updateAttendees(for event: SocialEventRecord) {
        let currentLinks = attendeeLinks.filter { $0.eventID == event.id && $0.deletedAt == nil }
        let currentIDs = Set(currentLinks.map(\.personID))

        for link in currentLinks where !selectedPersonIDs.contains(link.personID) {
            link.deletedAt = .now
            link.markUpdated()
        }
        for personID in selectedPersonIDs where !currentIDs.contains(personID) {
            modelContext.insert(EventAttendeeRecord(eventID: event.id, personID: personID))
        }
    }
}

private struct AttendeePickerView: View {
    let people: [PersonRecord]
    @Binding var selectedPersonIDs: Set<UUID>

    var body: some View {
        List(people) { person in
            Button {
                if selectedPersonIDs.contains(person.id) {
                    selectedPersonIDs.remove(person.id)
                } else {
                    selectedPersonIDs.insert(person.id)
                }
            } label: {
                HStack {
                    Text(person.fullName)
                    Spacer()
                    if selectedPersonIDs.contains(person.id) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .navigationTitle("Attendees")
    }
}
