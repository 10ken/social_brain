import SwiftData
import SwiftUI

struct HomeWorkspaceView: View {
    @Query(sort: \SocialEventRecord.startTime) private var allEvents: [SocialEventRecord]
    @Query(sort: \ReminderRecord.dueDate) private var allReminders: [ReminderRecord]
    @Query(sort: \MemoryRecord.updatedAt, order: .reverse) private var allMemories: [MemoryRecord]
    @State private var showingMemoryEditor = false
    @State private var showingReminderEditor = false

    private var upcomingEvents: [SocialEventRecord] {
        allEvents.filter { event in
            guard event.isVisibleInDefaultLists else { return false }
            guard let start = event.startTime else { return true }
            return start >= Calendar.current.startOfDay(for: .now)
        }
    }

    private var openReminders: [ReminderRecord] {
        allReminders.filter { $0.isVisibleInDefaultLists && !$0.completed }
    }

    private var memories: [MemoryRecord] {
        allMemories.filter(\.isVisibleInDefaultLists)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Coming up") {
                    if upcomingEvents.isEmpty {
                        Text("No upcoming events.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(upcomingEvents.prefix(4)) { event in
                        NavigationLink {
                            SocialEventDetailView(event: event)
                        } label: {
                            EventSummaryRow(event: event)
                        }
                    }
                }

                Section("Follow-ups") {
                    if openReminders.isEmpty {
                        Text("Nothing needs attention.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(openReminders.prefix(4)) { reminder in
                        NavigationLink {
                            ReminderDetailView(reminder: reminder)
                        } label: {
                            ReminderSummaryRow(reminder: reminder)
                        }
                    }
                    NavigationLink("All reminders") {
                        RemindersListView()
                    }
                }

                Section("Recent memories") {
                    if memories.isEmpty {
                        Text("Save a detail you want to remember.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(memories.prefix(3)) { memory in
                        NavigationLink {
                            MemoryDetailView(memory: memory)
                        } label: {
                            Text(memory.content)
                                .lineLimit(2)
                        }
                    }
                    NavigationLink("All memories") {
                        MemoriesListView()
                    }
                }
            }
            .navigationTitle("Social Brain")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New Memory", systemImage: "brain.head.profile") {
                            showingMemoryEditor = true
                        }
                        Button("New Reminder", systemImage: "checklist") {
                            showingReminderEditor = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingMemoryEditor) {
                MemoryEditorView(memory: nil, sourceCapture: nil)
            }
            .sheet(isPresented: $showingReminderEditor) {
                ReminderEditorView(reminder: nil, sourceCapture: nil)
            }
        }
    }
}

struct EventSummaryRow: View {
    let event: SocialEventRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(event.title).font(.headline)
            HStack(spacing: 6) {
                if let start = event.startTime {
                    Text(start, format: .dateTime.month(.abbreviated).day().hour().minute())
                } else if let dateText = event.dateText, !dateText.isEmpty {
                    Text(dateText)
                } else {
                    Text("Date to be confirmed")
                }
                if let location = event.location, !location.isEmpty {
                    Text("•")
                    Text(location)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

struct ReminderSummaryRow: View {
    let reminder: ReminderRecord

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: reminder.completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(reminder.completed ? .green : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title)
                if let due = reminder.dueDate {
                    Text(due, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct MemoriesListView: View {
    @Query(sort: \MemoryRecord.updatedAt, order: .reverse) private var allMemories: [MemoryRecord]
    @State private var showingEditor = false

    private var memories: [MemoryRecord] { allMemories.filter(\.isVisibleInDefaultLists) }

    var body: some View {
        List {
            if memories.isEmpty {
                ContentUnavailableView(
                    "No memories yet",
                    systemImage: "brain.head.profile",
                    description: Text("Save a memory manually or confirm one while reviewing a capture.")
                )
            }
            ForEach(memories) { memory in
                NavigationLink {
                    MemoryDetailView(memory: memory)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(memory.content)
                            .lineLimit(2)
                        HStack {
                            Text(memory.memoryType.capitalized)
                            ConfidenceBadge(state: memory.confidenceState)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Memories")
        .toolbar {
            Button("Add", systemImage: "plus") { showingEditor = true }
        }
        .sheet(isPresented: $showingEditor) {
            MemoryEditorView(memory: nil, sourceCapture: nil)
        }
    }
}

struct MemoryDetailView: View {
    let memory: MemoryRecord

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonRecord.fullName) private var people: [PersonRecord]
    @Query(sort: \GroupRecord.name) private var groups: [GroupRecord]
    @Query(sort: \SocialEventRecord.startTime) private var events: [SocialEventRecord]
    @State private var showingEditor = false

    var body: some View {
        Form {
            Section("Memory") {
                Text(memory.content)
                    .textSelection(.enabled)
                LabeledContent("Type", value: memory.memoryType.capitalized)
                HStack {
                    Text("Status")
                    Spacer()
                    ConfidenceBadge(state: memory.confidenceState)
                }
            }

            if let person = people.first(where: { $0.id == memory.personID }) {
                Section("Person") {
                    NavigationLink(person.fullName) { PersonDetailView(person: person) }
                }
            }
            if let group = groups.first(where: { $0.id == memory.groupID }) {
                Section("Group") {
                    NavigationLink(group.name) { GroupDetailView(group: group) }
                }
            }
            if let event = events.first(where: { $0.id == memory.eventID }) {
                Section("Event") {
                    NavigationLink(event.title) { SocialEventDetailView(event: event) }
                }
            }

            EvidenceSection(evidenceText: memory.evidenceText, sourceID: memory.sourceID)
        }
        .navigationTitle("Memory")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit", systemImage: "pencil") { showingEditor = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                RecordLifecycleActions(
                    isArchived: memory.archivedAt != nil,
                    archive: {
                        _ = RecordLifecycleService().archive(memory, in: modelContext)
                    },
                    restore: {
                        _ = RecordLifecycleService().restore(memory, in: modelContext)
                    },
                    delete: {
                        _ = RecordLifecycleService().softDelete(memory, in: modelContext)
                    }
                )
            }
        }
        .sheet(isPresented: $showingEditor) {
            MemoryEditorView(memory: memory, sourceCapture: nil)
        }
    }
}

struct MemoryEditorView: View {
    let memory: MemoryRecord?
    let sourceCapture: CaptureRecord?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonRecord.fullName) private var allPeople: [PersonRecord]
    @Query(sort: \GroupRecord.name) private var allGroups: [GroupRecord]
    @Query(sort: \SocialEventRecord.startTime) private var allEvents: [SocialEventRecord]
    @State private var content: String
    @State private var memoryType: String
    @State private var personID: UUID?
    @State private var groupID: UUID?
    @State private var eventID: UUID?
    @State private var evidenceText: String

    private let memoryTypes = ["note", "preference", "milestone", "conversation", "other"]

    init(memory: MemoryRecord?, sourceCapture: CaptureRecord?, prefillText: String? = nil) {
        self.memory = memory
        self.sourceCapture = sourceCapture
        _content = State(initialValue: memory?.content ?? prefillText ?? "")
        _memoryType = State(initialValue: memory?.memoryType ?? "note")
        _personID = State(initialValue: memory?.personID)
        _groupID = State(initialValue: memory?.groupID)
        _eventID = State(initialValue: memory?.eventID)
        _evidenceText = State(initialValue: memory?.evidenceText ?? prefillText ?? "")
    }

    private var people: [PersonRecord] { allPeople.filter(\.isVisibleInDefaultLists) }
    private var groups: [GroupRecord] { allGroups.filter(\.isVisibleInDefaultLists) }
    private var events: [SocialEventRecord] { allEvents.filter(\.isVisibleInDefaultLists) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Memory") {
                    TextField("What do you want to remember?", text: $content, axis: .vertical)
                        .lineLimit(4...10)
                    Picker("Type", selection: $memoryType) {
                        ForEach(memoryTypes, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }
                Section("Link to") {
                    Picker("Person", selection: $personID) {
                        Text("None").tag(UUID?.none)
                        ForEach(people) { Text($0.fullName).tag($0.id as UUID?) }
                    }
                    Picker("Group", selection: $groupID) {
                        Text("None").tag(UUID?.none)
                        ForEach(groups) { Text($0.name).tag($0.id as UUID?) }
                    }
                    Picker("Event", selection: $eventID) {
                        Text("None").tag(UUID?.none)
                        ForEach(events) { Text($0.title).tag($0.id as UUID?) }
                    }
                }
                Section("Evidence") {
                    TextField("Why is this useful or true?", text: $evidenceText, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(memory == nil ? "New Memory" : "Edit Memory")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let value = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = memory ?? MemoryRecord(content: value, memoryType: memoryType)
        record.content = value
        record.memoryType = memoryType
        record.personID = personID
        record.groupID = groupID
        record.eventID = eventID
        record.sourceID = sourceCapture?.id ?? record.sourceID
        record.evidenceText = optional(evidenceText)
        record.confidenceState = "confirmed"
        record.markUpdated()
        if memory == nil { modelContext.insert(record) }
        if let sourceCapture {
            sourceCapture.reviewState = CaptureReviewState.inProgress.rawValue
            sourceCapture.processed = false
            sourceCapture.markUpdated()
        }
        guard saveLocalChanges(modelContext) else { return }
        dismiss()
    }
}

struct RemindersListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReminderRecord.dueDate) private var allReminders: [ReminderRecord]
    @State private var showingEditor = false

    private var reminders: [ReminderRecord] { allReminders.filter(\.isVisibleInDefaultLists) }

    var body: some View {
        List {
            if reminders.isEmpty {
                ContentUnavailableView(
                    "No reminders yet",
                    systemImage: "checklist",
                    description: Text("Create a follow-up manually or while reviewing a capture.")
                )
            }
            ForEach(reminders) { reminder in
                NavigationLink {
                    ReminderDetailView(reminder: reminder)
                } label: {
                    ReminderSummaryRow(reminder: reminder)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button(reminder.completed ? "Reopen" : "Complete") {
                        reminder.completed.toggle()
                        reminder.markUpdated()
                        saveLocalChanges(modelContext)
                    }
                    .tint(reminder.completed ? .orange : .green)
                }
            }
        }
        .navigationTitle("Reminders")
        .toolbar {
            Button("Add", systemImage: "plus") { showingEditor = true }
        }
        .sheet(isPresented: $showingEditor) {
            ReminderEditorView(reminder: nil, sourceCapture: nil)
        }
    }
}

struct ReminderDetailView: View {
    let reminder: ReminderRecord

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonRecord.fullName) private var people: [PersonRecord]
    @Query(sort: \GroupRecord.name) private var groups: [GroupRecord]
    @State private var showingEditor = false

    var body: some View {
        Form {
            Section("Reminder") {
                LabeledContent("Title", value: reminder.title)
                if let dueDate = reminder.dueDate {
                    LabeledContent("Due", value: dueDate.formatted(date: .abbreviated, time: .shortened))
                }
                Toggle("Completed", isOn: Binding(
                    get: { reminder.completed },
                    set: { value in
                        reminder.completed = value
                        reminder.markUpdated()
                        saveLocalChanges(modelContext)
                    }
                ))
                HStack {
                    Text("Status")
                    Spacer()
                    ConfidenceBadge(state: reminder.confidenceState)
                }
            }
            if let person = people.first(where: { $0.id == reminder.personID }) {
                Section("Person") {
                    NavigationLink(person.fullName) { PersonDetailView(person: person) }
                }
            }
            if let group = groups.first(where: { $0.id == reminder.groupID }) {
                Section("Group") {
                    NavigationLink(group.name) { GroupDetailView(group: group) }
                }
            }
            EvidenceSection(evidenceText: reminder.evidenceText, sourceID: reminder.sourceID)
        }
        .navigationTitle("Reminder")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit", systemImage: "pencil") { showingEditor = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                RecordLifecycleActions(
                    isArchived: reminder.archivedAt != nil,
                    archive: {
                        _ = RecordLifecycleService().archive(reminder, in: modelContext)
                    },
                    restore: {
                        _ = RecordLifecycleService().restore(reminder, in: modelContext)
                    },
                    delete: {
                        _ = RecordLifecycleService().softDelete(reminder, in: modelContext)
                    }
                )
            }
        }
        .sheet(isPresented: $showingEditor) {
            ReminderEditorView(reminder: reminder, sourceCapture: nil)
        }
    }
}

struct ReminderEditorView: View {
    let reminder: ReminderRecord?
    let sourceCapture: CaptureRecord?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonRecord.fullName) private var allPeople: [PersonRecord]
    @Query(sort: \GroupRecord.name) private var allGroups: [GroupRecord]
    @State private var title: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var personID: UUID?
    @State private var groupID: UUID?
    @State private var evidenceText: String

    init(reminder: ReminderRecord?, sourceCapture: CaptureRecord?, prefillText: String? = nil) {
        self.reminder = reminder
        self.sourceCapture = sourceCapture
        _title = State(initialValue: reminder?.title ?? prefillText ?? "")
        _hasDueDate = State(initialValue: reminder?.dueDate != nil)
        _dueDate = State(initialValue: reminder?.dueDate ?? .now)
        _personID = State(initialValue: reminder?.personID)
        _groupID = State(initialValue: reminder?.groupID)
        _evidenceText = State(initialValue: reminder?.evidenceText ?? prefillText ?? "")
    }

    private var people: [PersonRecord] { allPeople.filter(\.isVisibleInDefaultLists) }
    private var groups: [GroupRecord] { allGroups.filter(\.isVisibleInDefaultLists) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Follow-up") {
                    TextField("What needs attention?", text: $title, axis: .vertical)
                        .lineLimit(2...5)
                    Toggle("Set due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate)
                    }
                }
                Section("Link to") {
                    Picker("Person", selection: $personID) {
                        Text("None").tag(UUID?.none)
                        ForEach(people) { Text($0.fullName).tag($0.id as UUID?) }
                    }
                    Picker("Group", selection: $groupID) {
                        Text("None").tag(UUID?.none)
                        ForEach(groups) { Text($0.name).tag($0.id as UUID?) }
                    }
                }
                Section("Evidence") {
                    TextField("Why is this a follow-up?", text: $evidenceText, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(reminder == nil ? "New Reminder" : "Edit Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = reminder ?? ReminderRecord(title: value, dueDate: hasDueDate ? dueDate : nil)
        record.title = value
        record.dueDate = hasDueDate ? dueDate : nil
        record.personID = personID
        record.groupID = groupID
        record.sourceID = sourceCapture?.id ?? record.sourceID
        record.evidenceText = optional(evidenceText)
        record.confidenceState = "confirmed"
        record.markUpdated()
        if reminder == nil { modelContext.insert(record) }
        if let sourceCapture {
            sourceCapture.reviewState = CaptureReviewState.inProgress.rawValue
            sourceCapture.processed = false
            sourceCapture.markUpdated()
        }
        guard saveLocalChanges(modelContext) else { return }
        dismiss()
    }
}
