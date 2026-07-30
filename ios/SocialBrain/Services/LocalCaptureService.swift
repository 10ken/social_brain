import Foundation
import SwiftData

enum CaptureKind: String, Codable, CaseIterable {
    case text
    case photo
    case screenshot
    case voice
    case email
    case sharedText

    var displayName: String {
        switch self {
        case .text: return "Text capture"
        case .photo: return "Photo capture"
        case .screenshot: return "Screenshot capture"
        case .voice: return "Voice capture"
        case .email: return "Email capture"
        case .sharedText: return "Pasted shared text"
        }
    }
}

enum CaptureImportLimits {
    static let maxTextBytes = 250_000
    static let maxImageBytesForAI = 5_000_000
    static let maxVoiceBytes = 25_000_000
    static let maxAttachmentBytes = 25_000_000
}

struct CaptureAttachment {
    let data: Data
    let fileExtension: String
    let mimeType: String
    let originalName: String?

    init(data: Data, fileExtension: String, mimeType: String, originalName: String? = nil) {
        self.data = data
        self.fileExtension = fileExtension
        self.mimeType = mimeType
        self.originalName = originalName
    }
}

struct CaptureImportRequest {
    let kind: CaptureKind
    let text: String?
    let attachment: CaptureAttachment?
    let sourceLabel: String?

    init(kind: CaptureKind, text: String? = nil, attachment: CaptureAttachment? = nil, sourceLabel: String? = nil) {
        self.kind = kind
        self.text = text
        self.attachment = attachment
        self.sourceLabel = sourceLabel
    }
}

enum CaptureImportError: Error, Equatable {
    case missingContent
    case attachmentRequired
    case invalidAttachment
    case missingEncryptedReference
    case textTooLarge
    case attachmentTooLarge
    case voiceTooLarge
}

/// Captures are always created as unprocessed, review-required local records.
/// The service stores payloads in `LocalEncryptedContentStore`; SwiftData holds
/// only generic labels and opaque references.
@MainActor
protocol CaptureImporting: AnyObject {
    func importCapture(_ request: CaptureImportRequest, into modelContext: ModelContext) throws -> CaptureRecord
    func decryptedText(for capture: CaptureRecord) throws -> String?
    func decryptedAttachment(for capture: CaptureRecord) throws -> Data?
    func decryptedAttachmentMetadata(for capture: CaptureRecord) throws -> LocalAttachmentMetadata?
    func saveAnalysis(_ analysis: Data, for capture: CaptureRecord, in modelContext: ModelContext) throws
    func decryptedAnalysis(for capture: CaptureRecord) throws -> Data?
    func deleteCapture(_ capture: CaptureRecord, from modelContext: ModelContext) throws
}

@MainActor
final class LocalCaptureService: CaptureImporting {
    private let contentStore: LocalEncryptedContentStore
    private let cleanupQueue: EncryptedContentCleanupQueue

    init(
        contentStore: LocalEncryptedContentStore = LocalEncryptedContentStore(),
        cleanupQueue: EncryptedContentCleanupQueue = EncryptedContentCleanupQueue()
    ) {
        self.contentStore = contentStore
        self.cleanupQueue = cleanupQueue
        cleanupQueue.drain(using: contentStore)
    }

    func importCapture(_ request: CaptureImportRequest, into modelContext: ModelContext) throws -> CaptureRecord {
        let normalizedText = request.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(normalizedText?.isEmpty ?? true)
        let hasAttachment = request.attachment != nil
        guard hasText || hasAttachment else { throw CaptureImportError.missingContent }
        if requiresAttachment(request.kind), !hasAttachment { throw CaptureImportError.attachmentRequired }
        if let attachment = request.attachment, attachment.data.isEmpty { throw CaptureImportError.invalidAttachment }
        if let normalizedText, normalizedText.lengthOfBytes(using: .utf8) > CaptureImportLimits.maxTextBytes {
            throw CaptureImportError.textTooLarge
        }
        if let attachment = request.attachment, attachment.data.count > CaptureImportLimits.maxAttachmentBytes {
            throw CaptureImportError.attachmentTooLarge
        }
        if request.kind == .voice, let attachment = request.attachment,
           attachment.data.count > CaptureImportLimits.maxVoiceBytes {
            throw CaptureImportError.voiceTooLarge
        }

        let capture = CaptureRecord(type: request.kind.rawValue)
        capture.contentPreview = request.kind.displayName
        capture.sourceLabel = nonEmpty(request.sourceLabel)

        var storedReferences: [LocalEncryptedContentReference] = []
        do {
            if let normalizedText, !normalizedText.isEmpty {
                let reference = try contentStore.store(
                    Data(normalizedText.utf8),
                    recordID: capture.id,
                    recordType: .capture,
                    purpose: .captureBody
                )
                capture.encryptedContentReference = try reference.serialized()
                storedReferences.append(reference)
            }

            if let attachment = request.attachment {
                let metadata = try LocalAttachmentMetadata(
                    mimeType: attachment.mimeType,
                    fileExtension: attachment.fileExtension,
                    originalName: attachment.originalName,
                    byteCount: attachment.data.count,
                    captureKind: request.kind.rawValue
                )
                let reference = try contentStore.store(
                    attachment.data,
                    recordID: capture.id,
                    recordType: .capture,
                    purpose: .captureAttachment,
                    attachmentMetadata: metadata
                )
                capture.encryptedAttachmentReference = try reference.serialized()
                capture.attachmentMIMEType = metadata.mimeType
                capture.attachmentFileExtension = metadata.fileExtension
                capture.attachmentOriginalName = metadata.originalName
                capture.attachmentByteCount = metadata.byteCount
                storedReferences.append(reference)
            }

            capture.processed = false
            capture.updatedAt = .now
            modelContext.insert(capture)
            try modelContext.save()
            return capture
        } catch {
            modelContext.delete(capture)
            modelContext.rollback()
            for reference in storedReferences {
                do {
                    try contentStore.delete(reference)
                } catch {
                    cleanupQueue.enqueue(reference)
                }
            }
            throw error
        }
    }

    func decryptedText(for capture: CaptureRecord) throws -> String? {
        guard let serializedReference = capture.encryptedContentReference else { return nil }
        let reference = try LocalEncryptedContentReference.deserialize(serializedReference)
        let data = try contentStore.load(reference)
        guard let text = String(data: data, encoding: .utf8) else {
            throw LocalEncryptedContentStoreError.tamperedContent
        }
        return text
    }

    func decryptedAttachment(for capture: CaptureRecord) throws -> Data? {
        guard let serializedReference = capture.encryptedAttachmentReference else { return nil }
        return try contentStore.load(LocalEncryptedContentReference.deserialize(serializedReference))
    }

    func decryptedAttachmentMetadata(for capture: CaptureRecord) throws -> LocalAttachmentMetadata? {
        guard let serializedReference = capture.encryptedAttachmentReference else { return nil }
        return try contentStore.attachmentMetadata(
            for: LocalEncryptedContentReference.deserialize(serializedReference)
        )
    }

    func saveAnalysis(_ analysis: Data, for capture: CaptureRecord, in modelContext: ModelContext) throws {
        let newReference = try contentStore.store(
            analysis,
            recordID: capture.id,
            recordType: .capture,
            purpose: .captureAnalysis,
            // A replacement must not overwrite the currently referenced
            // ciphertext before SwiftData has committed the new reference.
            uniqueFile: true
        )
        let previousReference = capture.encryptedAnalysisReference
        let previousUpdatedAt = capture.updatedAt
        do {
            capture.encryptedAnalysisReference = try newReference.serialized()
            capture.analyzedJSON = nil
            capture.processed = false // AI output always remains review-required.
            capture.reviewState = CaptureReviewState.pending.rawValue
            capture.reviewSuggestionCount = 0
            capture.reviewResolvedCount = 0
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
            capture.encryptedAnalysisReference = previousReference
            capture.updatedAt = previousUpdatedAt
            modelContext.rollback()
            do {
                try contentStore.delete(newReference)
            } catch {
                cleanupQueue.enqueue(newReference)
            }
            throw error
        }
    }

    func decryptedAnalysis(for capture: CaptureRecord) throws -> Data? {
        guard let serializedReference = capture.encryptedAnalysisReference else { return nil }
        return try contentStore.load(LocalEncryptedContentReference.deserialize(serializedReference))
    }

    func deleteCapture(_ capture: CaptureRecord, from modelContext: ModelContext) throws {
        let references = try [
            capture.encryptedContentReference,
            capture.encryptedAttachmentReference,
            capture.encryptedAnalysisReference,
            capture.encryptedReviewReference
        ].compactMap { serialized -> LocalEncryptedContentReference? in
            guard let serialized else { return nil }
            return try LocalEncryptedContentReference.deserialize(serialized)
        }
        modelContext.delete(capture)
        try modelContext.save()
        for reference in references {
            do {
                try contentStore.delete(reference)
            } catch {
                // The record is already gone. Persist the safe opaque reference
                // for retry at the next capture operation rather than rolling
                // back the committed SwiftData deletion.
                cleanupQueue.enqueue(reference)
            }
        }
    }

    private func requiresAttachment(_ kind: CaptureKind) -> Bool {
        switch kind {
        case .photo, .screenshot, .voice: return true
        case .text, .email, .sharedText: return false
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
