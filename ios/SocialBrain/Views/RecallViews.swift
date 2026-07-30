import SwiftData
import SwiftUI

private struct RecallContextRecord: Identifiable, Equatable {
    let id: String
    let type: String
    let title: String
    let summary: String
}

/// Local search never decrypts a capture just to index it. Protected AI recall
/// receives only the explicitly displayed structured-record summaries after a
/// second confirmation; raw capture bodies and attachments are excluded.
@MainActor
struct RecallWorkspaceView: View {
    @Query(sort: \PersonRecord.fullName) private var allPeople: [PersonRecord]
    @Query(sort: \GroupRecord.name) private var allGroups: [GroupRecord]
    @Query(sort: \RelationshipRecord.updatedAt, order: .reverse) private var allRelationships: [RelationshipRecord]
    @Query(sort: \SocialEventRecord.startTime) private var allEvents: [SocialEventRecord]
    @Query(sort: \MemoryRecord.updatedAt, order: .reverse) private var allMemories: [MemoryRecord]
    @Query(sort: \ReminderRecord.dueDate) private var allReminders: [ReminderRecord]
    @Query(sort: \CaptureRecord.createdAt, order: .reverse) private var allCaptures: [CaptureRecord]
    @EnvironmentObject private var environment: AppEnvironment
    @State private var query = ""
    @State private var showingAIConsent = false
    @State private var aiAnswer: String?
    @State private var aiError: String?

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var people: [PersonRecord] {
        allPeople.filter { record in
            record.isVisibleInDefaultLists && matches([
                record.fullName, record.nickname, record.email, record.phoneNumber,
                record.location, record.notes, record.evidenceText
            ])
        }
    }

    private var groups: [GroupRecord] {
        allGroups.filter { $0.isVisibleInDefaultLists && matches([$0.name, $0.groupDescription]) }
    }

    private var relationships: [RelationshipRecord] {
        allRelationships.filter { record in
            record.isVisibleInDefaultLists && matches([
                name(for: record.personAID), name(for: record.personBID), record.relationshipType,
                record.notes, record.evidenceText
            ])
        }
    }

    private var events: [SocialEventRecord] {
        allEvents.filter { record in
            record.isVisibleInDefaultLists && matches([
                record.title, record.location, record.dateText, record.evidenceText
            ])
        }
    }

    private var memories: [MemoryRecord] {
        allMemories.filter { record in
            record.isVisibleInDefaultLists && matches([
                record.content, record.memoryType, record.evidenceText
            ])
        }
    }

    private var reminders: [ReminderRecord] {
        allReminders.filter { record in
            record.isVisibleInDefaultLists && matches([
                record.title, record.evidenceText
            ])
        }
    }

    private var captures: [CaptureRecord] {
        allCaptures.filter { record in
            record.isVisibleInDefaultLists && matches([
                record.contentPreview, record.sourceLabel, record.type
            ])
        }
    }

    private var reviewedContext: [RecallContextRecord] {
        var records: [RecallContextRecord] = []
        records += people.map { .init(id: "person:\($0.id.uuidString)", type: "person", title: $0.fullName, summary: compact([$0.nickname, $0.location, $0.notes, $0.evidenceText])) }
        records += groups.map { .init(id: "group:\($0.id.uuidString)", type: "group", title: $0.name, summary: compact([$0.groupDescription])) }
        records += relationships.map { .init(id: "relationship:\($0.id.uuidString)", type: "relationship", title: "\(name(for: $0.personAID) ?? "Unknown") · \($0.relationshipType) · \(name(for: $0.personBID) ?? "Unknown")", summary: compact([$0.notes, $0.evidenceText])) }
        records += events.map { .init(id: "event:\($0.id.uuidString)", type: "event", title: $0.title, summary: compact([$0.dateText, $0.location, $0.evidenceText])) }
        records += memories.map { .init(id: "memory:\($0.id.uuidString)", type: "memory", title: String($0.content.prefix(240)), summary: compact([$0.memoryType, $0.evidenceText])) }
        records += reminders.map { .init(id: "reminder:\($0.id.uuidString)", type: "reminder", title: $0.title, summary: compact([$0.evidenceText])) }
        return records
    }

    private var aiAvailability: ProtectedFeatureAvailability {
        ProtectedFeatureAvailability.aiAccess(
            authentication: environment.authentication.state,
            appCheck: environment.appCheck.state
        )
    }

    var body: some View {
        NavigationStack {
            List {
                aiSection

                if normalizedQuery.isEmpty {
                    Section("Search your reviewed records") {
                        Text("Search people, groups, relationships, events, memories, reminders, and safe capture previews. Capture bodies and attachments stay encrypted until you open a capture.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    recallResults
                }

                if let aiAnswer {
                    Section("AI answer") {
                        Text(aiAnswer).textSelection(.enabled)
                    }
                }
                if let aiError {
                    Section {
                        Label(aiError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Recall")
            .searchable(text: $query, prompt: "Search your local social memory")
            .sheet(isPresented: $showingAIConsent) {
                AIRecallConsentView(
                    question: query,
                    records: reviewedContext,
                    send: askProtectedAI
                )
            }
        }
    }

    @ViewBuilder
    private var aiSection: some View {
        Section("Protected AI recall") {
            switch aiAvailability {
            case .available:
                Button("Ask AI About These Results", systemImage: "sparkles") {
                    showingAIConsent = true
                }
                .disabled(normalizedQuery.isEmpty || reviewedContext.isEmpty)
                Text("Before sending, you will see the exact structured records included. Raw capture text, images, and audio are never added automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .unavailable(let reason):
                Label("AI recall is unavailable", systemImage: "lock.trianglebadge.exclamationmark")
                    .foregroundStyle(.secondary)
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                NavigationLink("Open Account & AI") { AuthenticationAndAIStatusView() }
            }
        }
    }

    @ViewBuilder
    private var recallResults: some View {
        if people.isEmpty && groups.isEmpty && relationships.isEmpty && events.isEmpty && memories.isEmpty && reminders.isEmpty && captures.isEmpty {
            Section("Results") {
                ContentUnavailableView("No matching local records", systemImage: "magnifyingglass")
            }
        }

        if !people.isEmpty {
            Section("People") {
                ForEach(people) { person in NavigationLink(person.fullName) { PersonDetailView(person: person) } }
            }
        }
        if !groups.isEmpty {
            Section("Groups") {
                ForEach(groups) { group in NavigationLink(group.name) { GroupDetailView(group: group) } }
            }
        }
        if !relationships.isEmpty {
            Section("Relationships") {
                ForEach(relationships) { relationship in
                    NavigationLink {
                        RelationshipDetailView(relationship: relationship)
                    } label: {
                        Text("\(name(for: relationship.personAID) ?? "Unknown") · \(relationship.relationshipType) · \(name(for: relationship.personBID) ?? "Unknown")")
                    }
                }
            }
        }
        if !events.isEmpty {
            Section("Events") {
                ForEach(events) { event in NavigationLink { SocialEventDetailView(event: event) } label: { EventSummaryRow(event: event) } }
            }
        }
        if !memories.isEmpty {
            Section("Memories") {
                ForEach(memories) { memory in NavigationLink { MemoryDetailView(memory: memory) } label: { Text(memory.content).lineLimit(2) } }
            }
        }
        if !reminders.isEmpty {
            Section("Reminders") {
                ForEach(reminders) { reminder in NavigationLink { ReminderDetailView(reminder: reminder) } label: { ReminderSummaryRow(reminder: reminder) } }
            }
        }
        if !captures.isEmpty {
            Section("Capture previews") {
                ForEach(captures) { capture in
                    NavigationLink { CaptureDetailView(capture: capture) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(capture.contentPreview ?? CaptureKind(rawValue: capture.type)?.displayName ?? "Capture")
                            Text(capture.sourceLabel ?? capture.type.capitalized)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func matches(_ values: [String?]) -> Bool {
        guard !normalizedQuery.isEmpty else { return false }
        return values.compactMap { $0?.lowercased() }.contains { $0.localizedStandardContains(normalizedQuery) }
    }

    private func name(for id: UUID) -> String? {
        allPeople.first { $0.id == id }?.fullName
    }

    private func compact(_ values: [String?]) -> String {
        values.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .joined(separator: " · ")
    }

    private func askProtectedAI(_ selected: [RecallContextRecord]) async -> Result<String, AIClientError> {
        do {
            let records = selected.map { "[\($0.type)] \($0.title)\n\($0.summary)" }.joined(separator: "\n\n")
            let request = try AIExtractionRequest(
                prompt: "Answer this question using only the reviewed records below. If they do not answer it, say so.\n\nQuestion: \(query)\n\nRecords:\n\(records)",
                systemInstruction: "Use only the supplied structured records. Do not infer private attachment content or invent facts.",
                responseMimeType: .text
            )
            let answer = try await environment.aiGateway.recall(request)
            aiAnswer = answer
            aiError = nil
            return .success(answer)
        } catch let error as AIClientError {
            aiError = error.localizedDescription
            return .failure(error)
        } catch {
            aiError = "AI recall could not be completed."
            return .failure(.unavailable)
        }
    }
}

@MainActor
private struct AIRecallConsentView: View {
    @Environment(\.dismiss) private var dismiss
    let question: String
    let records: [RecallContextRecord]
    let send: ([RecallContextRecord]) async -> Result<String, AIClientError>
    @State private var selectedIDs: Set<String>
    @State private var isSending = false
    @State private var error: String?

    init(
        question: String,
        records: [RecallContextRecord],
        send: @escaping ([RecallContextRecord]) async -> Result<String, AIClientError>
    ) {
        self.question = question
        self.records = records
        self.send = send
        _selectedIDs = State(initialValue: Set(records.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Question") { Text(question) }
                Section("Records that will be sent") {
                    Text("Only these structured summaries are sent. Raw capture text, images, and audio are excluded.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(records) { record in
                        Toggle(isOn: binding(for: record)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.title).lineLimit(2)
                                Text(record.type.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
                }
            }
            .navigationTitle("Confirm AI Recall")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSending ? "Sending…" : "Send") { sendSelected() }
                        .disabled(isSending || selectedIDs.isEmpty)
                }
            }
        }
    }

    private func binding(for record: RecallContextRecord) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(record.id) },
            set: { selected in
                if selected { selectedIDs.insert(record.id) } else { selectedIDs.remove(record.id) }
            }
        )
    }

    private func sendSelected() {
        isSending = true
        let selected = records.filter { selectedIDs.contains($0.id) }
        Task {
            switch await send(selected) {
            case .success:
                dismiss()
            case .failure(let clientError):
                error = clientError.localizedDescription
            }
            isSending = false
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
