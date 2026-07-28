import SwiftData
import SwiftUI

struct RecallWorkspaceView: View {
    @Query(sort: \PersonRecord.fullName) private var allPeople: [PersonRecord]
    @Query(sort: \SocialEventRecord.startTime) private var allEvents: [SocialEventRecord]
    @Query(sort: \MemoryRecord.updatedAt, order: .reverse) private var allMemories: [MemoryRecord]
    @Query(sort: \ReminderRecord.dueDate) private var allReminders: [ReminderRecord]
    @State private var query = ""

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

    var body: some View {
        NavigationStack {
            List {
                Section("AI answer") {
                    Label("AI recall is unavailable", systemImage: "lock.trianglebadge.exclamationmark")
                        .foregroundStyle(.secondary)
                    Text("Sign in and configure App Check in Account & AI before asking the protected AI service. Search below always stays on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    NavigationLink("Open Account & AI") {
                        AuthenticationAndAIStatusView()
                    }
                }

                if normalizedQuery.isEmpty {
                    Section("Search your reviewed records") {
                        Text("Search people, events, memories, and reminders by their saved details or evidence.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    recallResults
                }
            }
            .navigationTitle("Recall")
            .searchable(text: $query, prompt: "Search your local social memory")
        }
    }

    @ViewBuilder
    private var recallResults: some View {
        if people.isEmpty && events.isEmpty && memories.isEmpty && reminders.isEmpty {
            Section("Results") {
                ContentUnavailableView("No matching local records", systemImage: "magnifyingglass")
            }
        }

        if !people.isEmpty {
            Section("People") {
                ForEach(people) { person in
                    NavigationLink(person.fullName) { PersonDetailView(person: person) }
                }
            }
        }
        if !events.isEmpty {
            Section("Events") {
                ForEach(events) { event in
                    NavigationLink { SocialEventDetailView(event: event) } label: {
                        EventSummaryRow(event: event)
                    }
                }
            }
        }
        if !memories.isEmpty {
            Section("Memories") {
                ForEach(memories) { memory in
                    NavigationLink { MemoryDetailView(memory: memory) } label: {
                        Text(memory.content).lineLimit(2)
                    }
                }
            }
        }
        if !reminders.isEmpty {
            Section("Reminders") {
                ForEach(reminders) { reminder in
                    NavigationLink { ReminderDetailView(reminder: reminder) } label: {
                        ReminderSummaryRow(reminder: reminder)
                    }
                }
            }
        }
    }

    private func matches(_ values: [String?]) -> Bool {
        guard !normalizedQuery.isEmpty else { return false }
        return values.compactMap { $0?.lowercased() }.contains { $0.localizedStandardContains(normalizedQuery) }
    }
}
