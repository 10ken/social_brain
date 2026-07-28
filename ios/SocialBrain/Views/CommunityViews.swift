import SwiftData
import SwiftUI

private enum CommunitySection: String, CaseIterable, Identifiable {
    case people = "People"
    case groups = "Groups"
    case relationships = "Relationships"

    var id: Self { self }
}

struct CommunitiesWorkspaceView: View {
    @State private var section: CommunitySection = .people
    @State private var showingPersonEditor = false
    @State private var showingGroupEditor = false
    @State private var showingRelationshipEditor = false

    var body: some View {
        NavigationStack {
            Group {
                switch section {
                case .people:
                    PeopleListView()
                case .groups:
                    GroupsListView()
                case .relationships:
                    RelationshipsListView()
                }
            }
            .navigationTitle("Communities")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Show", selection: $section) {
                            ForEach(CommunitySection.allCases) { section in
                                Text(section.rawValue).tag(section)
                            }
                        }
                    } label: {
                        Label(section.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New Person", systemImage: "person.badge.plus") {
                            showingPersonEditor = true
                        }
                        Button("New Group", systemImage: "person.3") {
                            showingGroupEditor = true
                        }
                        Button("New Relationship", systemImage: "arrow.left.arrow.right") {
                            showingRelationshipEditor = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingPersonEditor) {
                PersonEditorView(person: nil)
            }
            .sheet(isPresented: $showingGroupEditor) {
                GroupEditorView(group: nil)
            }
            .sheet(isPresented: $showingRelationshipEditor) {
                RelationshipEditorView(relationship: nil)
            }
        }
    }
}

private struct PeopleListView: View {
    @Query(sort: \PersonRecord.fullName) private var allPeople: [PersonRecord]

    private var people: [PersonRecord] {
        allPeople.filter(\.isVisibleInDefaultLists)
    }

    private var archivedPeople: [PersonRecord] {
        allPeople.filter { $0.archivedAt != nil && $0.deletedAt == nil }
    }

    var body: some View {
        List {
            if people.isEmpty {
                ContentUnavailableView(
                    "No people yet",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("Add someone manually or confirm them from a capture.")
                )
            } else {
                ForEach(people) { person in
                    NavigationLink {
                        PersonDetailView(person: person)
                    } label: {
                        PersonRow(person: person)
                    }
                }
            }

            if !archivedPeople.isEmpty {
                Section("Archived") {
                    ForEach(archivedPeople) { person in
                        NavigationLink {
                            PersonDetailView(person: person)
                        } label: {
                            PersonRow(person: person)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

private struct PersonRow: View {
    let person: PersonRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(person.fullName)
                .font(.headline)
            if let nickname = person.nickname, !nickname.isEmpty {
                Text(nickname)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let email = person.email, !email.isEmpty {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PersonDetailView: View {
    let person: PersonRecord

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroupRecord.name) private var groups: [GroupRecord]
    @Query private var memberships: [GroupMembershipRecord]
    @Query private var relationships: [RelationshipRecord]
    @Query(sort: \PersonRecord.fullName) private var people: [PersonRecord]
    @State private var showingEditor = false

    private var personGroups: [GroupRecord] {
        let groupIDs = Set(memberships.filter {
            $0.personID == person.id && $0.isVisibleInDefaultLists
        }.map(\.groupID))
        return groups.filter { groupIDs.contains($0.id) && $0.isVisibleInDefaultLists }
    }

    private var personRelationships: [RelationshipRecord] {
        relationships.filter {
            ($0.personAID == person.id || $0.personBID == person.id) && $0.isVisibleInDefaultLists
        }
    }

    var body: some View {
        Form {
            Section("Person") {
                LabeledContent("Name", value: person.fullName)
                if let nickname = person.nickname, !nickname.isEmpty {
                    LabeledContent("Nickname", value: nickname)
                }
                if let email = person.email, !email.isEmpty {
                    LabeledContent("Email", value: email)
                }
                if let phone = person.phoneNumber, !phone.isEmpty {
                    LabeledContent("Phone", value: phone)
                }
                if let birthday = person.birthday, !birthday.isEmpty {
                    LabeledContent("Birthday", value: birthday)
                }
                if let location = person.location, !location.isEmpty {
                    LabeledContent("Location", value: location)
                }
                if person.isSelf {
                    Label("This is me", systemImage: "person.crop.circle.fill")
                }
            }

            if let notes = person.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .textSelection(.enabled)
                }
            }

            if !personGroups.isEmpty {
                Section("Groups") {
                    ForEach(personGroups) { group in
                        NavigationLink(group.name) {
                            GroupDetailView(group: group)
                        }
                    }
                }
            }

            if !personRelationships.isEmpty {
                Section("Relationships") {
                    ForEach(personRelationships) { relationship in
                        NavigationLink {
                            RelationshipDetailView(relationship: relationship)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(otherPersonName(for: relationship))
                                Text(relationship.relationshipType.capitalized)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            EvidenceSection(evidenceText: person.evidenceText, sourceID: person.sourceID)
        }
        .navigationTitle(person.fullName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit", systemImage: "pencil") {
                    showingEditor = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                RecordLifecycleActions(
                    isArchived: person.archivedAt != nil,
                    archive: {
                        person.archivedAt = .now
                        person.markUpdated()
                        saveLocalChanges(modelContext)
                    },
                    restore: {
                        person.archivedAt = nil
                        person.markUpdated()
                        saveLocalChanges(modelContext)
                    },
                    delete: {
                        person.deletedAt = .now
                        person.markUpdated()
                        saveLocalChanges(modelContext)
                    }
                )
            }
        }
        .sheet(isPresented: $showingEditor) {
            PersonEditorView(person: person)
        }
    }

    private func otherPersonName(for relationship: RelationshipRecord) -> String {
        let otherID = relationship.personAID == person.id ? relationship.personBID : relationship.personAID
        return people.first(where: { $0.id == otherID })?.fullName ?? "Unknown person"
    }
}

struct PersonEditorView: View {
    let person: PersonRecord?
    let sourceCapture: CaptureRecord?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var fullName: String
    @State private var nickname: String
    @State private var email: String
    @State private var phoneNumber: String
    @State private var birthday: String
    @State private var location: String
    @State private var notes: String
    @State private var isSelf: Bool
    @State private var evidenceText: String

    init(person: PersonRecord?, sourceCapture: CaptureRecord? = nil, prefillText: String? = nil) {
        self.person = person
        self.sourceCapture = sourceCapture
        _fullName = State(initialValue: person?.fullName ?? "")
        _nickname = State(initialValue: person?.nickname ?? "")
        _email = State(initialValue: person?.email ?? "")
        _phoneNumber = State(initialValue: person?.phoneNumber ?? "")
        _birthday = State(initialValue: person?.birthday ?? "")
        _location = State(initialValue: person?.location ?? "")
        _notes = State(initialValue: person?.notes ?? "")
        _isSelf = State(initialValue: person?.isSelf ?? false)
        _evidenceText = State(initialValue: person?.evidenceText ?? prefillText ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Full name", text: $fullName)
                    TextField("Nickname", text: $nickname)
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    Toggle("This is me", isOn: $isSelf)
                }
                Section("Context") {
                    TextField("Birthday", text: $birthday)
                    TextField("Location", text: $location)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section("Evidence") {
                    TextField("How do you know this?", text: $evidenceText, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(person == nil ? "New Person" : "Edit Person")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = person ?? PersonRecord(fullName: name)
        record.fullName = name
        record.nickname = optional(nickname)
        record.email = optional(email)
        record.phoneNumber = optional(phoneNumber)
        record.birthday = optional(birthday)
        record.location = optional(location)
        record.notes = optional(notes)
        record.evidenceText = optional(evidenceText)
        record.isSelf = isSelf
        record.sourceID = sourceCapture?.id ?? record.sourceID
        record.markUpdated()
        if person == nil { modelContext.insert(record) }
        if let sourceCapture {
            sourceCapture.processed = true
            sourceCapture.markUpdated()
        }
        saveLocalChanges(modelContext)
        dismiss()
    }
}

private struct GroupsListView: View {
    @Query(sort: \GroupRecord.name) private var allGroups: [GroupRecord]

    private var groups: [GroupRecord] { allGroups.filter(\.isVisibleInDefaultLists) }
    private var archivedGroups: [GroupRecord] {
        allGroups.filter { $0.archivedAt != nil && $0.deletedAt == nil }
    }

    var body: some View {
        List {
            if groups.isEmpty {
                ContentUnavailableView(
                    "No groups yet",
                    systemImage: "person.3",
                    description: Text("Create a group for a community, team, family, or friend circle.")
                )
            } else {
                ForEach(groups) { group in
                    NavigationLink {
                        GroupDetailView(group: group)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(group.name).font(.headline)
                            if let description = group.groupDescription, !description.isEmpty {
                                Text(description).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !archivedGroups.isEmpty {
                Section("Archived") {
                    ForEach(archivedGroups) { group in
                        NavigationLink(group.name) {
                            GroupDetailView(group: group)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct GroupDetailView: View {
    let group: GroupRecord

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonRecord.fullName) private var people: [PersonRecord]
    @Query private var memberships: [GroupMembershipRecord]
    @State private var showingEditor = false
    @State private var showingMemberPicker = false

    private var groupMemberships: [GroupMembershipRecord] {
        memberships.filter { $0.groupID == group.id && $0.isVisibleInDefaultLists }
    }

    private var members: [(membership: GroupMembershipRecord, person: PersonRecord)] {
        groupMemberships.compactMap { membership in
            guard let person = people.first(where: { $0.id == membership.personID && $0.isVisibleInDefaultLists }) else {
                return nil
            }
            return (membership, person)
        }
    }

    var body: some View {
        Form {
            if let description = group.groupDescription, !description.isEmpty {
                Section("About") {
                    Text(description)
                        .textSelection(.enabled)
                }
            }

            Section("Members") {
                if members.isEmpty {
                    Text("No members yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(members, id: \.membership.id) { item in
                    NavigationLink(item.person.fullName) {
                        PersonDetailView(person: item.person)
                    }
                    .swipeActions {
                        Button("Remove", role: .destructive) {
                            item.membership.deletedAt = .now
                            item.membership.markUpdated()
                            saveLocalChanges(modelContext)
                        }
                    }
                }
                Button("Add Member", systemImage: "person.badge.plus") {
                    showingMemberPicker = true
                }
            }
        }
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit", systemImage: "pencil") { showingEditor = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                RecordLifecycleActions(
                    isArchived: group.archivedAt != nil,
                    archive: {
                        group.archivedAt = .now
                        group.markUpdated()
                        saveLocalChanges(modelContext)
                    },
                    restore: {
                        group.archivedAt = nil
                        group.markUpdated()
                        saveLocalChanges(modelContext)
                    },
                    delete: {
                        group.deletedAt = .now
                        group.markUpdated()
                        saveLocalChanges(modelContext)
                    }
                )
            }
        }
        .sheet(isPresented: $showingEditor) {
            GroupEditorView(group: group)
        }
        .sheet(isPresented: $showingMemberPicker) {
            GroupMemberPickerView(group: group, memberIDs: Set(groupMemberships.map(\.personID)))
        }
    }
}

struct GroupEditorView: View {
    let group: GroupRecord?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name: String
    @State private var groupDescription: String

    init(group: GroupRecord?) {
        self.group = group
        _name = State(initialValue: group?.name ?? "")
        _groupDescription = State(initialValue: group?.groupDescription ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $groupDescription, axis: .vertical)
                    .lineLimit(3...8)
            }
            .navigationTitle(group == nil ? "New Group" : "Edit Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = group ?? GroupRecord(name: value)
        record.name = value
        record.groupDescription = optional(groupDescription)
        record.markUpdated()
        if group == nil { modelContext.insert(record) }
        saveLocalChanges(modelContext)
        dismiss()
    }
}

private struct GroupMemberPickerView: View {
    let group: GroupRecord
    let memberIDs: Set<UUID>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonRecord.fullName) private var allPeople: [PersonRecord]

    private var availablePeople: [PersonRecord] {
        allPeople.filter { $0.isVisibleInDefaultLists && !memberIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List(availablePeople) { person in
                Button {
                    modelContext.insert(GroupMembershipRecord(groupID: group.id, personID: person.id))
                    saveLocalChanges(modelContext)
                    dismiss()
                } label: {
                    Label(person.fullName, systemImage: "person.badge.plus")
                }
            }
            .overlay {
                if availablePeople.isEmpty {
                    ContentUnavailableView("No available people", systemImage: "person.crop.circle.badge.checkmark")
                }
            }
            .navigationTitle("Add Member")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct RelationshipsListView: View {
    @Query private var allRelationships: [RelationshipRecord]
    @Query(sort: \PersonRecord.fullName) private var people: [PersonRecord]

    private var relationships: [RelationshipRecord] {
        allRelationships.filter(\.isVisibleInDefaultLists)
    }

    var body: some View {
        List {
            if relationships.isEmpty {
                ContentUnavailableView(
                    "No relationships yet",
                    systemImage: "arrow.left.arrow.right",
                    description: Text("Connect two people and describe how they know each other.")
                )
            } else {
                ForEach(relationships) { relationship in
                    NavigationLink {
                        RelationshipDetailView(relationship: relationship)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(name(for: relationship.personAID)) ↔ \(name(for: relationship.personBID))")
                                .font(.headline)
                            HStack {
                                Text(relationship.relationshipType.capitalized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                ConfidenceBadge(state: relationship.confidenceState)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func name(for id: UUID) -> String {
        people.first(where: { $0.id == id })?.fullName ?? "Unknown person"
    }
}

struct RelationshipDetailView: View {
    let relationship: RelationshipRecord

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonRecord.fullName) private var people: [PersonRecord]
    @State private var showingEditor = false

    var body: some View {
        Form {
            Section("People") {
                if let personA = people.first(where: { $0.id == relationship.personAID }) {
                    NavigationLink(personA.fullName) { PersonDetailView(person: personA) }
                } else {
                    LabeledContent("Person", value: "Unavailable")
                }
                if let personB = people.first(where: { $0.id == relationship.personBID }) {
                    NavigationLink(personB.fullName) { PersonDetailView(person: personB) }
                } else {
                    LabeledContent("Person", value: "Unavailable")
                }
            }

            Section("Relationship") {
                LabeledContent("Type", value: relationship.relationshipType.capitalized)
                HStack {
                    Text("Status")
                    Spacer()
                    ConfidenceBadge(state: relationship.confidenceState)
                }
                if let notes = relationship.notes, !notes.isEmpty {
                    Text(notes)
                        .textSelection(.enabled)
                }
            }

            EvidenceSection(evidenceText: relationship.evidenceText, sourceID: relationship.sourceID)
        }
        .navigationTitle("Relationship")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit", systemImage: "pencil") { showingEditor = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                RecordLifecycleActions(
                    isArchived: relationship.archivedAt != nil,
                    archive: {
                        relationship.archivedAt = .now
                        relationship.markUpdated()
                        saveLocalChanges(modelContext)
                    },
                    restore: {
                        relationship.archivedAt = nil
                        relationship.markUpdated()
                        saveLocalChanges(modelContext)
                    },
                    delete: {
                        relationship.deletedAt = .now
                        relationship.markUpdated()
                        saveLocalChanges(modelContext)
                    }
                )
            }
        }
        .sheet(isPresented: $showingEditor) {
            RelationshipEditorView(relationship: relationship)
        }
    }
}

struct RelationshipEditorView: View {
    let relationship: RelationshipRecord?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonRecord.fullName) private var allPeople: [PersonRecord]
    @State private var personAID: UUID?
    @State private var personBID: UUID?
    @State private var relationshipType: String
    @State private var notes: String
    @State private var evidenceText: String

    private let relationshipTypes = ["friend", "family", "coworker", "partner", "mentor", "other"]

    init(relationship: RelationshipRecord?) {
        self.relationship = relationship
        _personAID = State(initialValue: relationship?.personAID)
        _personBID = State(initialValue: relationship?.personBID)
        _relationshipType = State(initialValue: relationship?.relationshipType ?? "friend")
        _notes = State(initialValue: relationship?.notes ?? "")
        _evidenceText = State(initialValue: relationship?.evidenceText ?? "")
    }

    private var people: [PersonRecord] { allPeople.filter(\.isVisibleInDefaultLists) }

    var body: some View {
        NavigationStack {
            Form {
                Section("People") {
                    Picker("First person", selection: $personAID) {
                        Text("Choose a person").tag(UUID?.none)
                        ForEach(people) { person in
                            Text(person.fullName).tag(person.id as UUID?)
                        }
                    }
                    Picker("Second person", selection: $personBID) {
                        Text("Choose a person").tag(UUID?.none)
                        ForEach(people) { person in
                            Text(person.fullName).tag(person.id as UUID?)
                        }
                    }
                }
                Section("Relationship") {
                    Picker("Type", selection: $relationshipType) {
                        ForEach(relationshipTypes, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section("Evidence") {
                    TextField("How do you know this?", text: $evidenceText, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(relationship == nil ? "New Relationship" : "Edit Relationship")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: selectInitialPeopleIfNeeded)
        }
    }

    private var canSave: Bool {
        guard let personAID, let personBID else { return false }
        return personAID != personBID
    }

    private func selectInitialPeopleIfNeeded() {
        if personAID == nil { personAID = people.first?.id }
        if personBID == nil { personBID = people.dropFirst().first?.id }
    }

    private func save() {
        guard let personAID, let personBID, personAID != personBID else { return }
        let record = relationship ?? RelationshipRecord(
            personAID: personAID,
            personBID: personBID,
            relationshipType: relationshipType
        )
        record.personAID = personAID
        record.personBID = personBID
        record.relationshipType = relationshipType
        record.notes = optional(notes)
        record.evidenceText = optional(evidenceText)
        record.markUpdated()
        if relationship == nil { modelContext.insert(record) }
        saveLocalChanges(modelContext)
        dismiss()
    }
}

func optional(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
