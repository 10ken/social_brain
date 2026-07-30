import Foundation

enum AIRequestLimits {
    static let maxPromptBytes = 250_000
    static let maxSystemInstructionBytes = 32_000
    static let maxCombinedTextBytes = 280_000
    static let maxImageBytes = 5_000_000
    static let maxResponseBytes = 1_000_000
    static let maxSuggestionsPerType = 100
}

enum AIResponseMimeType: String, Codable, CaseIterable {
    case json = "application/json"
    case text = "text/plain"
}

struct AIImagePayload: Codable, Equatable {
    let mimeType: String
    let dataBase64: String

    init(mimeType: String, data: Data) throws {
        let normalizedMIMEType = mimeType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedMIMEType.hasPrefix("image/"), !data.isEmpty, data.count <= AIRequestLimits.maxImageBytes else {
            throw AIClientError.invalidRequest
        }
        self.mimeType = normalizedMIMEType
        dataBase64 = data.base64EncodedString()
    }

    var decodedByteCount: Int? {
        Data(base64Encoded: dataBase64)?.count
    }
}

struct AIExtractionRequest: Codable, Equatable {
    let prompt: String
    let systemInstruction: String?
    let responseMimeType: AIResponseMimeType
    let image: AIImagePayload?

    init(
        prompt: String,
        systemInstruction: String? = nil,
        responseMimeType: AIResponseMimeType = .json,
        image: AIImagePayload? = nil
    ) throws {
        self.prompt = prompt
        self.systemInstruction = systemInstruction
        self.responseMimeType = responseMimeType
        self.image = image
        try validate()
    }

    func validate() throws {
        let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let promptBytes = prompt.lengthOfBytes(using: .utf8)
        let instructionBytes = systemInstruction?.lengthOfBytes(using: .utf8) ?? 0
        guard !normalizedPrompt.isEmpty,
              promptBytes <= AIRequestLimits.maxPromptBytes,
              instructionBytes <= AIRequestLimits.maxSystemInstructionBytes,
              promptBytes + instructionBytes <= AIRequestLimits.maxCombinedTextBytes
        else {
            throw AIClientError.invalidRequest
        }
        if let image {
            guard image.mimeType.hasPrefix("image/"),
                  let imageBytes = image.decodedByteCount,
                  imageBytes > 0,
                  imageBytes <= AIRequestLimits.maxImageBytes
            else {
                throw AIClientError.invalidRequest
            }
        }
    }

    var callablePayload: [String: Any] {
        var payload: [String: Any] = [
            "prompt": prompt,
            "responseMimeType": responseMimeType.rawValue
        ]
        if let systemInstruction { payload["systemInstruction"] = systemInstruction }
        if let image {
            payload["image"] = ["mimeType": image.mimeType, "dataBase64": image.dataBase64]
        }
        return payload
    }
}

struct AIExtractionResponse: Codable, Equatable {
    let text: String
}

enum AIConfidenceState: String, Codable, CaseIterable {
    case suggested
    case needsReview = "needs_review"
}

enum AIMemoryType: String, Codable, CaseIterable {
    case lifeUpdate = "life_update"
    case preference
    case relationship
    case eventContext = "event_context"
    case followUp = "follow_up"
    case generalNote = "general_note"
}

enum AIRelationshipType: String, Codable, CaseIterable {
    case spouse
    case sibling
    case coworker
    case friend
    case metThrough = "met_through"
}

struct AIExtractedPerson: Codable, Equatable {
    let name: String
    let confidenceState: AIConfidenceState
    let evidence: String

    init(from decoder: Decoder) throws {
        let object = try StrictJSON.object(from: decoder, allowed: ["name", "confidenceState", "evidence"])
        name = try object.requiredString("name", maxBytes: 300)
        confidenceState = try object.requiredEnum("confidenceState", as: AIConfidenceState.self)
        evidence = try object.requiredString("evidence", maxBytes: 2_000)
    }
}

struct AIExtractedEvent: Codable, Equatable {
    let title: String
    let dateText: String?
    let resolvedDate: String?
    let timeText: String?
    let location: String?
    let people: [String]
    let confidenceState: AIConfidenceState
    let evidence: String

    init(from decoder: Decoder) throws {
        let object = try StrictJSON.object(
            from: decoder,
            allowed: ["title", "dateText", "resolvedDate", "timeText", "location", "people", "confidenceState", "evidence"]
        )
        title = try object.requiredString("title", maxBytes: 500)
        dateText = try object.optionalString("dateText", maxBytes: 2_000)
        resolvedDate = try object.optionalDate("resolvedDate")
        timeText = try object.optionalString("timeText", maxBytes: 2_000)
        location = try object.optionalString("location", maxBytes: 2_000)
        people = try object.optionalStringArray("people", maxItems: AIRequestLimits.maxSuggestionsPerType, maxBytesPerItem: 300)
        confidenceState = try object.requiredEnum("confidenceState", as: AIConfidenceState.self)
        evidence = try object.requiredString("evidence", maxBytes: 2_000)
    }
}

struct AIExtractedMemory: Codable, Equatable {
    let person: String?
    let content: String
    let memoryType: AIMemoryType
    let confidenceState: AIConfidenceState
    let evidence: String

    init(from decoder: Decoder) throws {
        let object = try StrictJSON.object(from: decoder, allowed: ["person", "content", "memoryType", "confidenceState", "evidence"])
        person = try object.optionalString("person", maxBytes: 300)
        content = try object.requiredString("content", maxBytes: 10_000)
        memoryType = try object.requiredEnum("memoryType", as: AIMemoryType.self)
        confidenceState = try object.requiredEnum("confidenceState", as: AIConfidenceState.self)
        evidence = try object.requiredString("evidence", maxBytes: 2_000)
    }
}

struct AIExtractedRelationship: Codable, Equatable {
    let personA: String
    let personB: String
    let relationshipType: AIRelationshipType
    let confidenceState: AIConfidenceState
    let evidence: String

    init(from decoder: Decoder) throws {
        let object = try StrictJSON.object(from: decoder, allowed: ["personA", "personB", "relationshipType", "confidenceState", "evidence"])
        personA = try object.requiredString("personA", maxBytes: 300)
        personB = try object.requiredString("personB", maxBytes: 300)
        relationshipType = try object.requiredEnum("relationshipType", as: AIRelationshipType.self)
        confidenceState = try object.requiredEnum("confidenceState", as: AIConfidenceState.self)
        evidence = try object.requiredString("evidence", maxBytes: 2_000)
    }
}

struct AIExtractedReminder: Codable, Equatable {
    let title: String
    let dueText: String?
    let confidenceState: AIConfidenceState
    let evidence: String

    init(from decoder: Decoder) throws {
        let object = try StrictJSON.object(from: decoder, allowed: ["title", "dueText", "confidenceState", "evidence"])
        title = try object.requiredString("title", maxBytes: 500)
        dueText = try object.optionalString("dueText", maxBytes: 2_000)
        confidenceState = try object.requiredEnum("confidenceState", as: AIConfidenceState.self)
        evidence = try object.requiredString("evidence", maxBytes: 2_000)
    }
}

struct AIExtractionResult: Codable, Equatable {
    let people: [AIExtractedPerson]
    let events: [AIExtractedEvent]
    let memories: [AIExtractedMemory]
    let relationships: [AIExtractedRelationship]
    let reminders: [AIExtractedReminder]

    init(from decoder: Decoder) throws {
        let object = try StrictJSON.object(
            from: decoder,
            allowed: ["people", "events", "memories", "relationships", "reminders"]
        )
        people = try object.requiredArray("people", maxItems: AIRequestLimits.maxSuggestionsPerType)
        events = try object.requiredArray("events", maxItems: AIRequestLimits.maxSuggestionsPerType)
        memories = try object.requiredArray("memories", maxItems: AIRequestLimits.maxSuggestionsPerType)
        relationships = try object.requiredArray("relationships", maxItems: AIRequestLimits.maxSuggestionsPerType)
        reminders = try object.requiredArray("reminders", maxItems: AIRequestLimits.maxSuggestionsPerType)
    }

    static func decodeStrict(from text: String) throws -> AIExtractionResult {
        let data = Data(text.utf8)
        guard data.count <= AIRequestLimits.maxResponseBytes else { throw AIClientError.responseTooLarge }
        do {
            return try JSONDecoder().decode(AIExtractionResult.self, from: data)
        } catch let error as AIClientError {
            throw error
        } catch {
            throw AIClientError.invalidContract
        }
    }
}

enum AIClientError: LocalizedError, Equatable {
    case disabled
    case invalidRequest
    case responseTooLarge
    case invalidContract
    case unauthenticated
    case appCheck
    case rateLimited
    case unavailable
    case accountDeletionRequiresRecentSignIn

    var errorDescription: String? {
        switch self {
        case .disabled: return "AI is unavailable until Firebase authentication and App Check are ready."
        case .invalidRequest: return "This content cannot be sent to AI because it exceeds a safety limit or is incomplete."
        case .responseTooLarge: return "AI returned more content than this app can safely review."
        case .invalidContract: return "AI returned a result that could not be safely reviewed."
        case .unauthenticated: return "Sign in again before using this protected action."
        case .appCheck: return "This build could not verify App Check for the protected action."
        case .rateLimited: return "Too many AI requests were made. Please try again shortly."
        case .unavailable: return "The protected AI service is temporarily unavailable."
        case .accountDeletionRequiresRecentSignIn: return "Sign in again recently before deleting your account."
        }
    }
}

private struct DynamicJSONKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private struct StrictJSONObject {
    private let container: KeyedDecodingContainer<DynamicJSONKey>

    init(_ container: KeyedDecodingContainer<DynamicJSONKey>) {
        self.container = container
    }

    func requiredString(_ key: String, maxBytes: Int) throws -> String {
        let codingKey = try keyValue(key)
        let value = try container.decode(String.self, forKey: codingKey)
        guard !value.isEmpty, value.lengthOfBytes(using: .utf8) <= maxBytes else { throw AIClientError.invalidContract }
        return value
    }

    func optionalString(_ key: String, maxBytes: Int) throws -> String? {
        let codingKey = try keyValue(key)
        guard container.contains(codingKey) else { return nil }
        let isNil = try container.decodeNil(forKey: codingKey)
        guard !isNil else { return nil }
        let value = try container.decode(String.self, forKey: codingKey)
        guard value.lengthOfBytes(using: .utf8) <= maxBytes else { throw AIClientError.invalidContract }
        return value
    }

    func optionalDate(_ key: String) throws -> String? {
        guard let value = try optionalString(key, maxBytes: 10) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
            throw AIClientError.invalidContract
        }
        return value
    }

    func optionalStringArray(_ key: String, maxItems: Int, maxBytesPerItem: Int) throws -> [String] {
        let codingKey = try keyValue(key)
        guard container.contains(codingKey) else { return [] }
        let isNil = try container.decodeNil(forKey: codingKey)
        guard !isNil else { return [] }
        let values = try container.decode([String].self, forKey: codingKey)
        guard values.count <= maxItems,
              values.allSatisfy({ !$0.isEmpty && $0.lengthOfBytes(using: .utf8) <= maxBytesPerItem })
        else { throw AIClientError.invalidContract }
        return values
    }

    func requiredEnum<T: RawRepresentable>(_ key: String, as type: T.Type) throws -> T where T.RawValue == String {
        let rawValue = try requiredString(key, maxBytes: 100)
        guard let value = T(rawValue: rawValue) else { throw AIClientError.invalidContract }
        return value
    }

    func requiredArray<T: Decodable>(_ key: String, maxItems: Int) throws -> [T] {
        let codingKey = try keyValue(key)
        let values = try container.decode([T].self, forKey: codingKey)
        guard values.count <= maxItems else { throw AIClientError.invalidContract }
        return values
    }

    private func keyValue(_ key: String) throws -> DynamicJSONKey {
        guard let codingKey = DynamicJSONKey(stringValue: key) else { throw AIClientError.invalidContract }
        return codingKey
    }
}

private enum StrictJSON {
    static func object(from decoder: Decoder, allowed: Set<String>) throws -> StrictJSONObject {
        let container = try decoder.container(keyedBy: DynamicJSONKey.self)
        guard Set(container.allKeys.map(\.stringValue)).isSubset(of: allowed) else {
            throw AIClientError.invalidContract
        }
        return StrictJSONObject(container)
    }
}
