import Foundation
import SwiftData

protocol SyncableRecord: AnyObject {
    var id: UUID { get }
    var updatedAt: Date { get set }
    var archivedAt: Date? { get set }
    var deletedAt: Date? { get set }
}

/// The stored raw value keeps SwiftData migrations lightweight while callers use
/// this type to avoid inventing link semantics at each calendar call site.
enum CalendarLinkMode: String, Codable, CaseIterable {
    case imported
    case exported
}

/// Review is deliberately separate from whether a record was manually created
/// from a capture. A capture is only complete after every AI suggestion has a
/// decision, or the person explicitly finishes review.
enum CaptureReviewState: String, Codable, CaseIterable {
    case pending
    case inProgress
    case completed
}

@Model final class PersonRecord: Identifiable, SyncableRecord {
    @Attribute(.unique) var id: UUID
    var fullName: String; var nickname: String?; var birthday: String?; var location: String?; var notes: String?; var phoneNumber: String?; var email: String?; var isImported: Bool; var contactIdentifier: String?; var isSelf: Bool; var sourceID: UUID?; var confidenceState: String = "confirmed"; var evidenceText: String?; var createdAt: Date; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?
    init(fullName: String, email: String? = nil) { id = UUID(); self.fullName = fullName; nickname = nil; birthday = nil; location = nil; notes = nil; phoneNumber = nil; self.email = email; isImported = false; contactIdentifier = nil; isSelf = false; sourceID = nil; confidenceState = "confirmed"; evidenceText = nil; createdAt = .now; updatedAt = .now; archivedAt = nil; deletedAt = nil }
}

@Model final class GroupRecord: Identifiable, SyncableRecord {
    @Attribute(.unique) var id: UUID
    var name: String; var groupDescription: String?; var createdAt: Date; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?
    init(name: String, groupDescription: String? = nil) { id = UUID(); self.name = name; self.groupDescription = groupDescription; createdAt = .now; updatedAt = .now; archivedAt = nil; deletedAt = nil }
}

@Model final class GroupMembershipRecord: Identifiable, SyncableRecord {
    @Attribute(.unique) var id: UUID
    var groupID: UUID; var personID: UUID; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?
    init(groupID: UUID, personID: UUID) { id = UUID(); self.groupID = groupID; self.personID = personID; updatedAt = .now; archivedAt = nil; deletedAt = nil }
}

@Model final class RelationshipRecord: Identifiable, SyncableRecord {
    @Attribute(.unique) var id: UUID
    var personAID: UUID; var personBID: UUID; var relationshipType: String; var confidenceState: String; var notes: String?; var sourceID: UUID?; var evidenceText: String?; var createdAt: Date; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?
    init(personAID: UUID, personBID: UUID, relationshipType: String) { id = UUID(); self.personAID = personAID; self.personBID = personBID; self.relationshipType = relationshipType; confidenceState = "confirmed"; notes = nil; sourceID = nil; evidenceText = nil; createdAt = .now; updatedAt = .now; archivedAt = nil; deletedAt = nil }
}

@Model final class SocialEventRecord: Identifiable, SyncableRecord {
    @Attribute(.unique) var id: UUID
    var title: String; var startTime: Date?; var endTime: Date?; var location: String?; var groupID: UUID?; var sourceID: UUID?; var evidenceText: String?; var dateText: String?; var confidenceState: String; var externalCalendarIdentifier: String?; var externalEventIdentifier: String?; var calendarLinkMode: String?; var createdAt: Date; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?
    init(title: String, startTime: Date? = nil) { id = UUID(); self.title = title; self.startTime = startTime; endTime = nil; location = nil; groupID = nil; sourceID = nil; evidenceText = nil; dateText = nil; confidenceState = "confirmed"; externalCalendarIdentifier = nil; externalEventIdentifier = nil; calendarLinkMode = nil; createdAt = .now; updatedAt = .now; archivedAt = nil; deletedAt = nil }

    var externalCalendarLinkMode: CalendarLinkMode? {
        guard let calendarLinkMode else { return nil }
        return CalendarLinkMode(rawValue: calendarLinkMode)
    }
}

@Model final class EventAttendeeRecord: Identifiable, SyncableRecord {
    @Attribute(.unique) var id: UUID
    var eventID: UUID; var personID: UUID; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?
    init(eventID: UUID, personID: UUID) { id = UUID(); self.eventID = eventID; self.personID = personID; updatedAt = .now; archivedAt = nil; deletedAt = nil }
}

@Model final class MemoryRecord: Identifiable, SyncableRecord {
    @Attribute(.unique) var id: UUID
    var content: String; var personID: UUID?; var groupID: UUID?; var eventID: UUID?; var memoryType: String; var sourceID: UUID?; var confidenceState: String; var evidenceText: String?; var createdAt: Date; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?
    init(content: String, memoryType: String) { id = UUID(); self.content = content; personID = nil; groupID = nil; eventID = nil; self.memoryType = memoryType; sourceID = nil; confidenceState = "confirmed"; evidenceText = nil; createdAt = .now; updatedAt = .now; archivedAt = nil; deletedAt = nil }
}

@Model final class CaptureRecord: Identifiable, SyncableRecord {
    @Attribute(.unique) var id: UUID
    // `rawContent`, `attachmentPath`, and `analyzedJSON` remain only for a
    // one-time local migration path. New captures use the encrypted-reference
    // fields below and leave these legacy fields empty.
    var type: String; var rawContent: String; var attachmentPath: String?; var analyzedJSON: String?
    var encryptedContentReference: String?; var encryptedAttachmentReference: String?; var encryptedAnalysisReference: String?; var encryptedReviewReference: String?; var contentPreview: String?; var sourceLabel: String?
    var attachmentMIMEType: String?; var attachmentFileExtension: String?; var attachmentOriginalName: String?; var attachmentByteCount: Int?
    var reviewState: String; var reviewSuggestionCount: Int; var reviewResolvedCount: Int
    var processed: Bool; var createdAt: Date; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?
    init(type: String, rawContent: String = "") {
        id = UUID(); self.type = type; self.rawContent = rawContent; attachmentPath = nil; analyzedJSON = nil
        encryptedContentReference = nil; encryptedAttachmentReference = nil; encryptedAnalysisReference = nil; encryptedReviewReference = nil; contentPreview = nil; sourceLabel = nil
        attachmentMIMEType = nil; attachmentFileExtension = nil; attachmentOriginalName = nil; attachmentByteCount = nil
        reviewState = CaptureReviewState.pending.rawValue; reviewSuggestionCount = 0; reviewResolvedCount = 0
        processed = false; createdAt = .now; updatedAt = .now; archivedAt = nil; deletedAt = nil
    }

    var currentReviewState: CaptureReviewState {
        CaptureReviewState(rawValue: reviewState) ?? .pending
    }
}

@Model final class ReminderRecord: Identifiable, SyncableRecord {
    @Attribute(.unique) var id: UUID
    var title: String; var dueDate: Date?; var completed: Bool; var personID: UUID?; var groupID: UUID?; var sourceID: UUID?; var evidenceText: String?; var confidenceState: String; var createdAt: Date; var updatedAt: Date; var archivedAt: Date?; var deletedAt: Date?
    init(title: String, dueDate: Date? = nil) { id = UUID(); self.title = title; self.dueDate = dueDate; completed = false; personID = nil; groupID = nil; sourceID = nil; evidenceText = nil; confidenceState = "confirmed"; createdAt = .now; updatedAt = .now; archivedAt = nil; deletedAt = nil }
}

@Model final class AppSettingsRecord: Identifiable {
    @Attribute(.unique) var id: UUID
    var email: String?; var phoneNumber: String?; var themeMode: String; var timeZoneIdentifier: String; var updatedAt: Date
    init() { id = UUID(); email = nil; phoneNumber = nil; themeMode = "DARK"; timeZoneIdentifier = TimeZone.current.identifier; updatedAt = .now }
}
