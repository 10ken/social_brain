import Foundation
import SwiftData

/// The schema that was released before calendar-link and capture-review
/// metadata were added. Keep these model declarations independent from the
/// current app models: SwiftData compares each version's model layout when it
/// builds a migration plan. Reusing the current types here would make V1 and
/// V2 indistinguishable and would not describe an upgrade from an existing
/// local store.
///
/// The encrypted legacy-capture migration is intentionally handled by
/// `LegacyCaptureMigrationService`, because those old payloads live outside
/// SwiftData rather than in schema columns.
enum SocialBrainSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            PersonRecord.self,
            GroupRecord.self,
            GroupMembershipRecord.self,
            RelationshipRecord.self,
            SocialEventRecord.self,
            EventAttendeeRecord.self,
            MemoryRecord.self,
            CaptureRecord.self,
            ReminderRecord.self,
            AppSettingsRecord.self
        ]
    }

    @Model final class PersonRecord {
        @Attribute(.unique) var id: UUID
        var fullName: String; var nickname: String?; var birthday: String?; var location: String?; var notes: String?; var phoneNumber: String?; var email: String?; var isImported: Bool; var contactIdentifier: String?; var isSelf: Bool; var sourceID: UUID?; var evidenceText: String?; var createdAt: Date; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?

        init() {
            id = UUID(); fullName = ""; nickname = nil; birthday = nil; location = nil; notes = nil; phoneNumber = nil; email = nil; isImported = false; contactIdentifier = nil; isSelf = false; sourceID = nil; evidenceText = nil; createdAt = .now; updatedAt = .now; archivedAt = nil; deletedAt = nil
        }
    }

    @Model final class GroupRecord {
        @Attribute(.unique) var id: UUID
        var name: String; var groupDescription: String?; var createdAt: Date; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?

        init() {
            id = UUID(); name = ""; groupDescription = nil; createdAt = .now; updatedAt = .now; archivedAt = nil; deletedAt = nil
        }
    }

    @Model final class GroupMembershipRecord {
        @Attribute(.unique) var id: UUID
        var groupID: UUID; var personID: UUID; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?

        init() {
            id = UUID(); groupID = UUID(); personID = UUID(); updatedAt = .now; archivedAt = nil; deletedAt = nil
        }
    }

    @Model final class RelationshipRecord {
        @Attribute(.unique) var id: UUID
        var personAID: UUID; var personBID: UUID; var relationshipType: String; var confidenceState: String; var notes: String?; var sourceID: UUID?; var evidenceText: String?; var createdAt: Date; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?

        init() {
            id = UUID(); personAID = UUID(); personBID = UUID(); relationshipType = ""; confidenceState = "confirmed"; notes = nil; sourceID = nil; evidenceText = nil; createdAt = .now; updatedAt = .now; archivedAt = nil; deletedAt = nil
        }
    }

    @Model final class SocialEventRecord {
        @Attribute(.unique) var id: UUID
        var title: String; var startTime: Date?; var endTime: Date?; var location: String?; var groupID: UUID?; var sourceID: UUID?; var evidenceText: String?; var dateText: String?; var confidenceState: String; var createdAt: Date; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?

        init() {
            id = UUID(); title = ""; startTime = nil; endTime = nil; location = nil; groupID = nil; sourceID = nil; evidenceText = nil; dateText = nil; confidenceState = "confirmed"; createdAt = .now; updatedAt = .now; archivedAt = nil; deletedAt = nil
        }
    }

    @Model final class EventAttendeeRecord {
        @Attribute(.unique) var id: UUID
        var eventID: UUID; var personID: UUID; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?

        init() {
            id = UUID(); eventID = UUID(); personID = UUID(); updatedAt = .now; archivedAt = nil; deletedAt = nil
        }
    }

    @Model final class MemoryRecord {
        @Attribute(.unique) var id: UUID
        var content: String; var personID: UUID?; var groupID: UUID?; var eventID: UUID?; var memoryType: String; var sourceID: UUID?; var confidenceState: String; var evidenceText: String?; var createdAt: Date; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?

        init() {
            id = UUID(); content = ""; personID = nil; groupID = nil; eventID = nil; memoryType = ""; sourceID = nil; confidenceState = "confirmed"; evidenceText = nil; createdAt = .now; updatedAt = .now; archivedAt = nil; deletedAt = nil
        }
    }

    @Model final class CaptureRecord {
        @Attribute(.unique) var id: UUID
        var type: String; var rawContent: String; var attachmentPath: String?; var analyzedJSON: String?
        var encryptedContentReference: String?; var encryptedAttachmentReference: String?; var encryptedAnalysisReference: String?; var contentPreview: String?; var sourceLabel: String?
        var processed: Bool; var createdAt: Date; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?

        init() {
            id = UUID(); type = ""; rawContent = ""; attachmentPath = nil; analyzedJSON = nil
            encryptedContentReference = nil; encryptedAttachmentReference = nil; encryptedAnalysisReference = nil; contentPreview = nil; sourceLabel = nil
            processed = false; createdAt = .now; updatedAt = .now; archivedAt = nil; deletedAt = nil
        }
    }

    @Model final class ReminderRecord {
        @Attribute(.unique) var id: UUID
        var title: String; var dueDate: Date?; var completed: Bool; var personID: UUID?; var groupID: UUID?; var sourceID: UUID?; var evidenceText: String?; var confidenceState: String; var createdAt: Date; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?

        init() {
            id = UUID(); title = ""; dueDate = nil; completed = false; personID = nil; groupID = nil; sourceID = nil; evidenceText = nil; confidenceState = "confirmed"; createdAt = .now; updatedAt = .now; archivedAt = nil; deletedAt = nil
        }
    }

    @Model final class AppSettingsRecord {
        @Attribute(.unique) var id: UUID
        var email: String?; var phoneNumber: String?; var themeMode: String; var timeZoneIdentifier: String; var updatedAt: Date

        init() {
            id = UUID(); email = nil; phoneNumber = nil; themeMode = "DARK"; timeZoneIdentifier = TimeZone.current.identifier; updatedAt = .now
        }
    }
}

/// V2 adds person confidence, calendar-link, and encrypted-review/attachment
/// metadata fields. The optional storage (and the default person confidence)
/// makes the V1-to-V2 change lightweight.
enum SocialBrainSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        SocialBrainPersistenceModels.all
    }
}

enum SocialBrainMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SocialBrainSchemaV1.self, SocialBrainSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SocialBrainSchemaV1.self, toVersion: SocialBrainSchemaV2.self)]
    }
}

enum SocialBrainPersistenceModels {
    static let all: [any PersistentModel.Type] = [
        PersonRecord.self,
        GroupRecord.self,
        GroupMembershipRecord.self,
        RelationshipRecord.self,
        SocialEventRecord.self,
        EventAttendeeRecord.self,
        MemoryRecord.self,
        CaptureRecord.self,
        ReminderRecord.self,
        AppSettingsRecord.self
    ]
}

enum SocialBrainModelContainerFactory {
    static func make() throws -> ModelContainer {
        if ProcessInfo.processInfo.environment["SOCIAL_BRAIN_USE_IN_MEMORY_STORE"] == "YES" {
            return try makeInMemoryForTesting()
        }
        try ModelContainer(
            for: SocialBrainSchemaV2.self,
            migrationPlan: SocialBrainMigrationPlan.self
        )
    }

    static func makeInMemoryForTesting() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SocialBrainSchemaV2.self,
            migrationPlan: SocialBrainMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
