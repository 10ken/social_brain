import Foundation
import SwiftData

enum LocalDataResetComponent: String, CaseIterable, Hashable {
    case deviceKey
    case encryptedFiles
    case swiftData

    var displayName: String {
        switch self {
        case .deviceKey: return "device encryption key"
        case .encryptedFiles: return "encrypted files"
        case .swiftData: return "local records"
        }
    }
}

/// Narrow reset seam so the destructive workflow can be tested without a
/// Keychain or filesystem. Capture reads and writes still use the concrete
/// encrypted store, while reset only needs these independently retryable
/// operations.
protocol LocalEncryptedContentResetting: AnyObject {
    func destroyKey() throws
    func deleteAllFiles() throws
}

extension LocalEncryptedContentStore: LocalEncryptedContentResetting {}

struct LocalDataResetError: LocalizedError, Equatable {
    let failedComponents: Set<LocalDataResetComponent>

    var errorDescription: String? {
        let names = failedComponents.map(\.displayName).sorted().joined(separator: ", ")
        return "Some local data could not be erased: \(names)."
    }
}

/// Destructive local-only reset. It never calls Firebase and attempts each data
/// domain independently so a Keychain or filesystem error cannot prevent the
/// SwiftData records from being removed.
@MainActor
final class LocalDataResetService {
    private let encryptedContentStore: any LocalEncryptedContentResetting
    private let cleanupQueue: EncryptedContentCleanupQueue

    init(
        encryptedContentStore: any LocalEncryptedContentResetting = LocalEncryptedContentStore(),
        cleanupQueue: EncryptedContentCleanupQueue = EncryptedContentCleanupQueue()
    ) {
        self.encryptedContentStore = encryptedContentStore
        self.cleanupQueue = cleanupQueue
    }

    /// When SwiftData cannot be opened, pass `nil` to still destroy the
    /// non-portable device key and encrypted files. The resulting error
    /// truthfully reports that record deletion could not be verified.
    func wipeAllLocalContent(in modelContext: ModelContext?) throws {
        var failures = Set<LocalDataResetComponent>()

        do {
            try encryptedContentStore.destroyKey()
        } catch {
            failures.insert(.deviceKey)
        }

        do {
            try encryptedContentStore.deleteAllFiles()
            cleanupQueue.removeAll()
        } catch {
            failures.insert(.encryptedFiles)
        }

        guard let modelContext else {
            failures.insert(.swiftData)
            throw LocalDataResetError(failedComponents: failures)
        }

        do {
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
        } catch {
            // A failed save can leave pending deletes visible in this context
            // even though they were not durably committed. Restore that state
            // so the recovery screen never presents an unverified clean slate.
            modelContext.rollback()
            failures.insert(.swiftData)
        }

        guard failures.isEmpty else {
            throw LocalDataResetError(failedComponents: failures)
        }
    }

    private func deleteAll<Model: PersistentModel>(_ model: Model.Type, from modelContext: ModelContext) throws {
        let records = try modelContext.fetch(FetchDescriptor<Model>())
        for record in records {
            modelContext.delete(record)
        }
    }
}
