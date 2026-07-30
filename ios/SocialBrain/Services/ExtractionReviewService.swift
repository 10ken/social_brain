import Foundation
import SwiftData

enum ExtractionSuggestionKind: String, Codable, CaseIterable {
    case person
    case event
    case memory
    case relationship
    case reminder
}

enum SuggestionDecision: String, Codable, CaseIterable {
    case pending
    case confirmed
    case edited
    case rejected

    var isResolved: Bool { self != .pending }
}

struct StoredExtractionSuggestion: Codable, Identifiable, Equatable {
    let id: UUID
    let kind: ExtractionSuggestionKind
    var title: String
    var detail: String?
    let evidence: String
    let payload: Data
    var decision: SuggestionDecision

    init(
        id: UUID = UUID(),
        kind: ExtractionSuggestionKind,
        title: String,
        detail: String? = nil,
        evidence: String,
        payload: Data,
        decision: SuggestionDecision = .pending
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.evidence = evidence
        self.payload = payload
        self.decision = decision
    }
}

struct StoredExtractionReview: Codable, Equatable {
    let id: UUID
    let captureID: UUID
    let createdAt: Date
    var suggestions: [StoredExtractionSuggestion]
    var explicitlyFinished: Bool

    init(captureID: UUID, suggestions: [StoredExtractionSuggestion]) {
        id = UUID()
        self.captureID = captureID
        createdAt = .now
        self.suggestions = suggestions
        explicitlyFinished = false
    }

    var resolvedCount: Int { suggestions.filter { $0.decision.isResolved }.count }
    var isComplete: Bool { explicitlyFinished || suggestions.allSatisfy { $0.decision.isResolved } }
}

@MainActor
final class ExtractionReviewService {
    private let contentStore: LocalEncryptedContentStore
    private let cleanupQueue: EncryptedContentCleanupQueue

    init(
        contentStore: LocalEncryptedContentStore = LocalEncryptedContentStore(),
        cleanupQueue: EncryptedContentCleanupQueue = EncryptedContentCleanupQueue()
    ) {
        self.contentStore = contentStore
        self.cleanupQueue = cleanupQueue
    }

    func start(
        result: AIExtractionResult,
        for capture: CaptureRecord,
        in modelContext: ModelContext
    ) throws -> StoredExtractionReview {
        let review = StoredExtractionReview(captureID: capture.id, suggestions: try flattened(result))
        try persist(review, for: capture, in: modelContext)
        return review
    }

    func load(for capture: CaptureRecord) throws -> StoredExtractionReview? {
        guard let serializedReference = capture.encryptedReviewReference else { return nil }
        let reference = try LocalEncryptedContentReference.deserialize(serializedReference)
        let data = try contentStore.load(reference)
        let review = try JSONDecoder().decode(StoredExtractionReview.self, from: data)
        guard review.captureID == capture.id else { throw LocalEncryptedContentStoreError.tamperedContent }
        return review
    }

    func reject(
        suggestionID: UUID,
        in review: StoredExtractionReview,
        for capture: CaptureRecord,
        in modelContext: ModelContext
    ) throws -> StoredExtractionReview {
        var updated = review
        guard let index = updated.suggestions.firstIndex(where: { $0.id == suggestionID }) else {
            throw AIClientError.invalidContract
        }
        updated.suggestions[index].decision = .rejected
        try persist(updated, for: capture, in: modelContext)
        return updated
    }

    func confirm(
        suggestionID: UUID,
        title: String,
        detail: String?,
        in review: StoredExtractionReview,
        for capture: CaptureRecord,
        in modelContext: ModelContext
    ) throws -> StoredExtractionReview {
        var updated = review
        guard let index = updated.suggestions.firstIndex(where: { $0.id == suggestionID }) else {
            throw AIClientError.invalidContract
        }
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty, normalizedTitle.lengthOfBytes(using: .utf8) <= 10_000 else {
            throw AIClientError.invalidContract
        }
        updated.suggestions[index].title = normalizedTitle
        updated.suggestions[index].detail = detail?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        updated.suggestions[index].decision = normalizedTitle == review.suggestions[index].title &&
            updated.suggestions[index].detail == review.suggestions[index].detail ? .confirmed : .edited

        try persist(updated, for: capture, in: modelContext) { [self] in
            try createConfirmedRecord(from: updated.suggestions[index], capture: capture, in: modelContext)
        }
        return updated
    }

    func finish(
        review: StoredExtractionReview,
        for capture: CaptureRecord,
        in modelContext: ModelContext
    ) throws -> StoredExtractionReview {
        var updated = review
        updated.explicitlyFinished = true
        try persist(updated, for: capture, in: modelContext)
        return updated
    }

    private func persist(
        _ review: StoredExtractionReview,
        for capture: CaptureRecord,
        in modelContext: ModelContext,
        additionalChanges: () throws -> Void = {}
    ) throws {
        let encoded = try JSONEncoder().encode(review)
        let reference = try contentStore.store(
            encoded,
            recordID: capture.id,
            recordType: .capture,
            purpose: .captureReview,
            // Review decisions are updated repeatedly. Stage each revision in
            // a distinct authenticated envelope so a failed SwiftData save can
            // never erase the previously reviewable decision set.
            uniqueFile: true
        )
        let previousReference = capture.encryptedReviewReference
        let priorState = capture.reviewState
        let priorCount = capture.reviewSuggestionCount
        let priorResolved = capture.reviewResolvedCount
        let priorProcessed = capture.processed
        do {
            try additionalChanges()
            capture.encryptedReviewReference = try reference.serialized()
            capture.reviewSuggestionCount = review.suggestions.count
            capture.reviewResolvedCount = review.resolvedCount
            capture.reviewState = review.isComplete ? CaptureReviewState.completed.rawValue : CaptureReviewState.inProgress.rawValue
            capture.processed = review.isComplete
            capture.updatedAt = .now
            try modelContext.save()
            if let previousReference {
                let previous = try LocalEncryptedContentReference.deserialize(previousReference)
                do {
                    try contentStore.delete(previous)
                } catch {
                    cleanupQueue.enqueue(previous)
                }
            }
        } catch {
            capture.encryptedReviewReference = previousReference
            capture.reviewState = priorState
            capture.reviewSuggestionCount = priorCount
            capture.reviewResolvedCount = priorResolved
            capture.processed = priorProcessed
            modelContext.rollback()
            do {
                try contentStore.delete(reference)
            } catch {
                cleanupQueue.enqueue(reference)
            }
            throw error
        }
    }

    private func flattened(_ result: AIExtractionResult) throws -> [StoredExtractionSuggestion] {
        var suggestions: [StoredExtractionSuggestion] = []
        for person in result.people {
            suggestions.append(try suggestion(.person, title: person.name, evidence: person.evidence, payload: person))
        }
        for event in result.events {
            suggestions.append(try suggestion(.event, title: event.title, detail: event.dateText, evidence: event.evidence, payload: event))
        }
        for memory in result.memories {
            suggestions.append(try suggestion(.memory, title: memory.content, detail: memory.person, evidence: memory.evidence, payload: memory))
        }
        for relationship in result.relationships {
            let title = "\(relationship.personA) · \(relationship.relationshipType.rawValue.replacingOccurrences(of: "_", with: " ")) · \(relationship.personB)"
            suggestions.append(try suggestion(.relationship, title: title, evidence: relationship.evidence, payload: relationship))
        }
        for reminder in result.reminders {
            suggestions.append(try suggestion(.reminder, title: reminder.title, detail: reminder.dueText, evidence: reminder.evidence, payload: reminder))
        }
        return suggestions
    }

    private func suggestion<Payload: Encodable>(
        _ kind: ExtractionSuggestionKind,
        title: String,
        detail: String? = nil,
        evidence: String,
        payload: Payload
    ) throws -> StoredExtractionSuggestion {
        StoredExtractionSuggestion(
            kind: kind,
            title: title,
            detail: detail,
            evidence: evidence,
            payload: try JSONEncoder().encode(payload)
        )
    }

    private func createConfirmedRecord(
        from suggestion: StoredExtractionSuggestion,
        capture: CaptureRecord,
        in context: ModelContext
    ) throws {
        switch suggestion.kind {
        case .person:
            let payload = try JSONDecoder().decode(AIExtractedPerson.self, from: suggestion.payload)
            if !(try context.fetch(FetchDescriptor<PersonRecord>())).contains(where: {
                $0.isVisibleInDefaultLists && $0.fullName.caseInsensitiveCompare(suggestion.title) == .orderedSame
            }) {
                let person = PersonRecord(fullName: suggestion.title)
                person.sourceID = capture.id; person.evidenceText = payload.evidence; person.confidenceState = payload.confidenceState.rawValue
                context.insert(person)
            }
        case .event:
            let payload = try JSONDecoder().decode(AIExtractedEvent.self, from: suggestion.payload)
            if !(try context.fetch(FetchDescriptor<SocialEventRecord>())).contains(where: {
                $0.isVisibleInDefaultLists && $0.title.caseInsensitiveCompare(suggestion.title) == .orderedSame
            }) {
                let event = SocialEventRecord(title: suggestion.title, startTime: date(from: payload.resolvedDate))
                event.dateText = suggestion.detail ?? payload.dateText
                event.location = payload.location; event.sourceID = capture.id; event.evidenceText = payload.evidence
                event.confidenceState = payload.confidenceState.rawValue
                context.insert(event)
            }
        case .memory:
            let payload = try JSONDecoder().decode(AIExtractedMemory.self, from: suggestion.payload)
            if !(try context.fetch(FetchDescriptor<MemoryRecord>())).contains(where: {
                $0.isVisibleInDefaultLists && $0.content == suggestion.title
            }) {
                let memory = MemoryRecord(content: suggestion.title, memoryType: payload.memoryType.rawValue)
                memory.sourceID = capture.id; memory.evidenceText = payload.evidence; memory.confidenceState = payload.confidenceState.rawValue
                memory.personID = try personID(named: suggestion.detail ?? payload.person, in: context)
                context.insert(memory)
            }
        case .relationship:
            let payload = try JSONDecoder().decode(AIExtractedRelationship.self, from: suggestion.payload)
            let personA = try existingOrConfirmedPerson(named: payload.personA, capture: capture, evidence: payload.evidence, in: context)
            let personB = try existingOrConfirmedPerson(named: payload.personB, capture: capture, evidence: payload.evidence, in: context)
            if !(try context.fetch(FetchDescriptor<RelationshipRecord>())).contains(where: {
                $0.isVisibleInDefaultLists &&
                    (($0.personAID == personA.id && $0.personBID == personB.id) || ($0.personAID == personB.id && $0.personBID == personA.id)) &&
                    $0.relationshipType == payload.relationshipType.rawValue
            }) {
                let relationship = RelationshipRecord(personAID: personA.id, personBID: personB.id, relationshipType: payload.relationshipType.rawValue)
                relationship.sourceID = capture.id; relationship.evidenceText = payload.evidence; relationship.confidenceState = payload.confidenceState.rawValue
                context.insert(relationship)
            }
        case .reminder:
            let payload = try JSONDecoder().decode(AIExtractedReminder.self, from: suggestion.payload)
            if !(try context.fetch(FetchDescriptor<ReminderRecord>())).contains(where: {
                $0.isVisibleInDefaultLists && $0.title.caseInsensitiveCompare(suggestion.title) == .orderedSame
            }) {
                let reminder = ReminderRecord(title: suggestion.title)
                reminder.sourceID = capture.id; reminder.evidenceText = payload.evidence; reminder.confidenceState = payload.confidenceState.rawValue
                context.insert(reminder)
            }
        }
    }

    private func personID(named name: String?, in context: ModelContext) throws -> UUID? {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        return try context.fetch(FetchDescriptor<PersonRecord>()).first(where: {
            $0.isVisibleInDefaultLists && $0.fullName.caseInsensitiveCompare(name) == .orderedSame
        })?.id
    }

    private func existingOrConfirmedPerson(
        named name: String,
        capture: CaptureRecord,
        evidence: String,
        in context: ModelContext
    ) throws -> PersonRecord {
        if let existing = try context.fetch(FetchDescriptor<PersonRecord>()).first(where: {
            $0.isVisibleInDefaultLists && $0.fullName.caseInsensitiveCompare(name) == .orderedSame
        }) {
            return existing
        }
        let person = PersonRecord(fullName: name)
        person.sourceID = capture.id; person.evidenceText = evidence; person.confidenceState = AIConfidenceState.needsReview.rawValue
        context.insert(person)
        return person
    }

    private func date(from value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
