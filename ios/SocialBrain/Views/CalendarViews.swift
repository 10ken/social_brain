import SwiftData
import SwiftUI

@MainActor
struct CalendarWorkspaceView: View {
    @Query(sort: \SocialEventRecord.startTime) private var allEvents: [SocialEventRecord]
    private let calendarService: any CalendarService
    private let settingsOpener: any ApplicationSettingsOpening
    @State private var showingEditor = false
    @State private var showingAccessInfo = false
    @State private var showingDeviceImport = false
    @State private var calendarState: CalendarAuthorizationState = .unavailable

    init(
        calendarService: any CalendarService = EventKitCalendarService(),
        settingsOpener: any ApplicationSettingsOpening = SystemApplicationSettingsOpener()
    ) {
        self.calendarService = calendarService
        self.settingsOpener = settingsOpener
    }

    private var events: [SocialEventRecord] { allEvents.filter(\.isVisibleInDefaultLists) }

    var body: some View {
        NavigationStack {
            List {
                CalendarAccessCard(
                    state: calendarState,
                    showingAccessInfo: $showingAccessInfo,
                    requestAccess: requestCalendarAccess,
                    requestWriteOnlyAccess: requestCalendarWriteOnlyAccess,
                    openSettings: settingsOpener.openApplicationSettings,
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
                            SocialEventDetailView(
                                event: event,
                                calendarService: calendarService,
                                settingsOpener: settingsOpener
                            )
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

    private func requestCalendarWriteOnlyAccess() {
        Task {
            calendarState = await calendarService.requestWriteOnlyAccess()
        }
    }
}

private struct CalendarAccessCard: View {
    let state: CalendarAuthorizationState
    @Binding var showingAccessInfo: Bool
    let requestAccess: () -> Void
    let requestWriteOnlyAccess: () -> Void
    let openSettings: () -> Void
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
                Button("Allow Calendar Import and Export", action: requestAccess)
                Button("Allow Export Only", action: requestWriteOnlyAccess)
                Text("Import requires full access. Export-only access lets you add a confirmed event without reading calendar events.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .denied:
                Label("Calendar access was denied", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text("Enable calendar access in iOS Settings to read or write selected events.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Open Settings", action: openSettings)
            case .restricted:
                Label("Calendar access is restricted", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                Text("This device currently prevents calendar access. Local events remain available.")
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
                Button("Enable Event Import", action: requestAccess)
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
    @Query(sort: \SocialEventRecord.updatedAt, order: .reverse) private var allEvents: [SocialEventRecord]
    @State private var deviceEvents: [DeviceCalendarEvent] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var importableDeviceEvents: [DeviceCalendarEvent] {
        deviceEvents.filter { $0.socialBrainOwnerID == nil }
    }

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
                } else if importableDeviceEvents.isEmpty {
                    ContentUnavailableView(
                        "No new upcoming device events",
                        systemImage: "calendar",
                        description: Text("Events previously exported by Social Brain are not imported again.")
                    )
                } else {
                    ForEach(importableDeviceEvents) { deviceEvent in
                        Button {
                            importEvent(deviceEvent)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(deviceEvent.title).font(.headline)
                                Text(deviceEvent.startDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                                    .font(.footnote)
                                .foregroundStyle(.secondary)
                                if importedRecord(for: deviceEvent) != nil {
                                    Text("Already imported")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .disabled(importedRecord(for: deviceEvent) != nil)
                    }
                }
            }
            .navigationTitle("Import Calendar Events")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task { loadEvents() }
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
        guard importedRecord(for: deviceEvent) == nil else { return }
        let record = SocialEventRecord(title: deviceEvent.title, startTime: deviceEvent.startDate)
        record.endTime = deviceEvent.endDate
        record.location = deviceEvent.location
        record.evidenceText = deviceEvent.notes
        record.confidenceState = "confirmed"
        record.externalEventIdentifier = deviceEvent.id
        record.externalCalendarIdentifier = deviceEvent.calendarIdentifier
        record.calendarLinkMode = CalendarLinkMode.imported.rawValue
        modelContext.insert(record)
        guard saveLocalChanges(modelContext) else {
            modelContext.rollback()
            errorMessage = "The selected event could not be saved locally."
            return
        }
        dismiss()
    }

    private func importedRecord(for deviceEvent: DeviceCalendarEvent) -> SocialEventRecord? {
        allEvents.first {
            $0.isVisibleInDefaultLists &&
            $0.externalCalendarLinkMode == .imported &&
            $0.externalEventIdentifier == deviceEvent.id &&
            $0.externalCalendarIdentifier == deviceEvent.calendarIdentifier
        }
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
                    Text("When enabled, exporting writes only a confirmed Social Brain event to your device calendar. It never changes an event without your action, and it only removes exports marked as Social Brain events.")
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
    private let calendarServiceOverride: (any CalendarService)?
    private let settingsOpener: any ApplicationSettingsOpening

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var environment: AppEnvironment
    @Query(sort: \GroupRecord.name) private var groups: [GroupRecord]
    @Query(sort: \PersonRecord.fullName) private var people: [PersonRecord]
    @Query private var attendeeLinks: [EventAttendeeRecord]
    @State private var showingEditor = false
    @State private var showingCalendarRationale = false
    @State private var showingCalendarDeletionConfirmation = false
    @State private var calendarExportMessage: String?

    init(
        event: SocialEventRecord,
        calendarService: (any CalendarService)? = nil,
        settingsOpener: any ApplicationSettingsOpening = SystemApplicationSettingsOpener()
    ) {
        self.event = event
        calendarServiceOverride = calendarService
        self.settingsOpener = settingsOpener
    }

    /// Calendar actions reached from Home, Recall, and evidence links share
    /// the same root service as the Calendar tab. A direct override keeps
    /// preview and focused UI-test construction deterministic.
    private var calendarService: any CalendarService {
        calendarServiceOverride ?? environment.calendarService
    }

    private var attendees: [PersonRecord] {
        let personIDs = Set(attendeeLinks.filter {
            $0.eventID == event.id && $0.isVisibleInDefaultLists
        }.map(\.personID))
        return people.filter { personIDs.contains($0.id) && $0.isVisibleInDefaultLists }
    }

    private var exportedCalendarLink: (eventIdentifier: String, calendarIdentifier: String)? {
        guard event.externalCalendarLinkMode == .exported,
              let eventIdentifier = event.externalEventIdentifier,
              let calendarIdentifier = event.externalCalendarIdentifier
        else { return nil }
        return (eventIdentifier, calendarIdentifier)
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
                if event.externalCalendarLinkMode == .imported {
                    Label("Imported from Device Calendar", systemImage: "calendar.badge.checkmark")
                        .foregroundStyle(.secondary)
                    Text("This local event already represents a device-calendar event. It is not exported again as a second event.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if event.startTime != nil, event.endTime != nil {
                    Button(exportedCalendarLink == nil ? "Add to Device Calendar" : "Update Device Calendar Event") {
                        exportToCalendar()
                    }
                    if exportedCalendarLink != nil {
                        Button("Remove Social Brain Export", role: .destructive) {
                            showingCalendarDeletionConfirmation = true
                        }
                    }
                } else {
                    Label("Add a start and end time to export", systemImage: "calendar.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                }
                if calendarService.authorizationState == .denied {
                    Button("Open Calendar Settings", action: settingsOpener.openApplicationSettings)
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
                        _ = RecordLifecycleService().archive(event, in: modelContext)
                    },
                    restore: {
                        _ = RecordLifecycleService().restore(event, in: modelContext)
                    },
                    delete: {
                        _ = RecordLifecycleService().softDelete(event: event, in: modelContext)
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
        .confirmationDialog(
            "Remove the Social Brain export?",
            isPresented: $showingCalendarDeletionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove from Device Calendar", role: .destructive, action: removeCalendarExport)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only the device-calendar event created and marked by Social Brain will be removed. Your local event stays here.")
        }
    }

    private func exportToCalendar() {
        guard let start = event.startTime, let end = event.endTime else { return }
        guard calendarService.authorizationState != .notDetermined else {
            Task {
                let state = await calendarService.requestWriteOnlyAccess()
                guard state.canWrite else {
                    calendarExportMessage = "Calendar write access is needed before exporting this event."
                    return
                }
                saveCalendarExport(start: start, end: end)
            }
            return
        }
        guard calendarService.authorizationState.canWrite else {
            calendarExportMessage = "Calendar write access is needed before exporting this event."
            return
        }
        saveCalendarExport(start: start, end: end)
    }

    private func saveCalendarExport(start: Date, end: Date) {
        do {
            let deviceEvent = try calendarService.save(CalendarEventDraft(
                eventIdentifier: exportedCalendarLink?.eventIdentifier,
                title: event.title,
                startDate: start,
                endDate: end,
                location: event.location,
                notes: event.evidenceText,
                calendarIdentifier: exportedCalendarLink?.calendarIdentifier,
                socialBrainOwnerID: event.id
            ))
            event.externalEventIdentifier = deviceEvent.id
            event.externalCalendarIdentifier = deviceEvent.calendarIdentifier
            event.calendarLinkMode = CalendarLinkMode.exported.rawValue
            event.markUpdated()
            guard saveLocalChanges(modelContext) else {
                calendarExportMessage = "The device event was saved, but Social Brain could not store its link. Do not export it again until local storage is available."
                return
            }
            calendarExportMessage = "Device calendar event saved."
        } catch {
            calendarExportMessage = "This event could not be saved to the device calendar."
        }
    }

    private func removeCalendarExport() {
        guard let link = exportedCalendarLink else { return }
        do {
            try calendarService.deleteSocialBrainExportedEvent(
                identifier: link.eventIdentifier,
                calendarIdentifier: link.calendarIdentifier,
                ownerID: event.id
            )
            event.externalEventIdentifier = nil
            event.externalCalendarIdentifier = nil
            event.calendarLinkMode = nil
            event.markUpdated()
            guard saveLocalChanges(modelContext) else {
                calendarExportMessage = "The device export was removed, but its local link could not be cleared."
                return
            }
            calendarExportMessage = "Social Brain export removed from the device calendar."
        } catch {
            calendarExportMessage = "Only a matching Social Brain export can be removed. This device-calendar event was left unchanged."
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
            // Creating one manual event is a review action, not completion:
            // other suggestions can still be pending for this capture.
            sourceCapture.reviewState = CaptureReviewState.inProgress.rawValue
            sourceCapture.processed = false
            sourceCapture.markUpdated()
        }
        guard saveLocalChanges(modelContext) else { return }
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
