import SwiftData

/// Destructive local-only reset. This never calls Firebase and intentionally
/// removes the device-only key, making any residual encrypted file unreadable.
@MainActor
final class LocalDataResetService {
    private let encryptedContentStore: LocalEncryptedContentStore

    init(encryptedContentStore: LocalEncryptedContentStore = LocalEncryptedContentStore()) {
        self.encryptedContentStore = encryptedContentStore
    }

    func wipeAllLocalContent(in modelContext: ModelContext) throws {
        // Erase the key first so that a filesystem-cleanup failure does not
        // leave recoverable imported data behind.
        try encryptedContentStore.destroyAll()

        try deleteAll(PersonRecord.self, from: modelContext)
        try deleteAll(GroupRecord.self, from: modelContext)
        try deleteAll(GroupMembershipRecord.self, from: modelContext)
        try deleteAll(RelationshipRecord.self, from: modelContext)
        try deleteAll(SocialEventRecord.self, from: modelContext)
        try deleteAll(EventAttendeeRecord.self, from: modelContext)
        try deleteAll(MemoryRecord.self, from: modelContext)
        try deleteAll(CaptureRecord.self, from: modelContext)
        try deleteAll(ReminderRecord.self, from: modelContext)
        try deleteAll(AppSettingsRecord.self, from: modelContext)
        try modelContext.save()
    }

    private func deleteAll<Model: PersistentModel>(_ model: Model.Type, from modelContext: ModelContext) throws {
        let records = try modelContext.fetch(FetchDescriptor<Model>())
        for record in records {
            modelContext.delete(record)
        }
    }
}
