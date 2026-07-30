import SwiftData
import SwiftUI

/// A single recovery surface for every soft-archivable record class. Archive
/// preserves links; permanent removal remains exclusive to Start Clean.
@MainActor
struct ArchivedRecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var people: [PersonRecord]
    @Query private var groups: [GroupRecord]
    @Query private var relationships: [RelationshipRecord]
    @Query private var events: [SocialEventRecord]
    @Query private var memories: [MemoryRecord]
    @Query private var reminders: [ReminderRecord]

    private var archivedPeople: [PersonRecord] { people.filter(isArchived) }
    private var archivedGroups: [GroupRecord] { groups.filter(isArchived) }
    private var archivedRelationships: [RelationshipRecord] { relationships.filter(isArchived) }
    private var archivedEvents: [SocialEventRecord] { events.filter(isArchived) }
    private var archivedMemories: [MemoryRecord] { memories.filter(isArchived) }
    private var archivedReminders: [ReminderRecord] { reminders.filter(isArchived) }

    var body: some View {
        List {
            archivedSection("People", records: archivedPeople, label: \PersonRecord.fullName)
            archivedSection("Groups", records: archivedGroups, label: \GroupRecord.name)
            archivedSection("Relationships", records: archivedRelationships) { "\($0.personAID.uuidString.prefix(6)) · \($0.relationshipType)" }
            archivedSection("Events", records: archivedEvents, label: \SocialEventRecord.title)
            archivedSection("Memories", records: archivedMemories) { String($0.content.prefix(80)) }
            archivedSection("Reminders", records: archivedReminders, label: \ReminderRecord.title)
        }
        .navigationTitle("Archived Records")
        .overlay {
            if isEmpty {
                ContentUnavailableView(
                    "No archived records",
                    systemImage: "archivebox",
                    description: Text("Archived records can be restored here without losing their links.")
                )
            }
        }
    }

    private var isEmpty: Bool {
        archivedPeople.isEmpty && archivedGroups.isEmpty && archivedRelationships.isEmpty &&
            archivedEvents.isEmpty && archivedMemories.isEmpty && archivedReminders.isEmpty
    }

    @ViewBuilder
    private func archivedSection<Record: SyncableRecord>(
        _ title: String,
        records: [Record],
        label: @escaping (Record) -> String
    ) -> some View {
        if !records.isEmpty {
            Section(title) {
                ForEach(records, id: \.id) { record in
                    HStack {
                        Text(label(record)).lineLimit(1)
                        Spacer()
                        Button("Restore") { restore(record) }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("archived.restore.\(record.id.uuidString)")
                    }
                }
            }
        }
    }

    private func isArchived(_ record: some SyncableRecord) -> Bool {
        record.archivedAt != nil && record.deletedAt == nil
    }

    private func restore(_ record: some SyncableRecord) {
        _ = RecordLifecycleService().restore(record, in: modelContext)
    }
}
