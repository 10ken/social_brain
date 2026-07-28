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
        case .text: "Text capture"
        case .photo: "Photo capture"
        case .screenshot: "Screenshot capture"
        case .voice: "Voice capture"
        case .email: "Email capture"
        case .sharedText: "Shared text"
        }
    }
}

struct CaptureAttachment {
    let data: Data
    let fileExtension: String
    let mimeType: String

    init(data: Data, fileExtension: String, mimeType: String) {
        self.data = data
        self.fileExtension = fileExtension
        self.mimeType = mimeType
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
}

/// Captures are always created as unprocessed, review-required local records.
/// The service stores payloads in `LocalEncryptedContentStore`; SwiftData holds
/// only generic labels and opaque references.
@MainActor
protocol CaptureImporting: AnyObject {
    func importCapture(_ request: CaptureImportRequest, into modelContext: ModelContext) throws -> CaptureRecord
    func decryptedText(for capture: CaptureRecord) throws -> String?
    func decryptedAttachment(for capture: CaptureRecord) throws -> Data?
    func saveAnalysis(_ analysis: Data, for capture: CaptureRecord, in modelContext: ModelContext) throws
    func decryptedAnalysis(for capture: CaptureRecord) throws -> Data?
    func deleteCapture(_ capture: CaptureRecord, from modelContext: ModelContext) throws
}

@MainActor
final class LocalCaptureService: CaptureImporting {
    private let contentStore: LocalEncryptedContentStore

    init(contentStore: LocalEncryptedContentStore = LocalEncryptedContentStore()) {
        self.contentStore = contentStore
    }

    func importCapture(_ request: CaptureImportRequest, into modelContext: ModelContext) throws -> CaptureRecord {
        let normalizedText = request.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(normalizedText?.isEmpty ?? true)
        let hasAttachment = request.attachment != nil
        guard hasText || hasAttachment else { throw CaptureImportError.missingContent }
        if requiresAttachment(request.kind), !hasAttachment { throw CaptureImportError.attachmentRequired }
        if let attachment = request.attachment, attachment.data.isEmpty { throw CaptureImportError.invalidAttachment }

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
                let reference = try contentStore.store(
                    attachment.data,
                    recordID: capture.id,
                    recordType: .capture,
                    purpose: .captureAttachment
                )
                capture.encryptedAttachmentReference = try reference.serialized()
                storedReferences.append(reference)
            }

            capture.processed = false
            capture.updatedAt = .now
            modelContext.insert(capture)
            try modelContext.save()
            return capture
        } catch {
            modelContext.delete(capture)
            for reference in storedReferences {
                try? contentStore.delete(reference)
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

    func saveAnalysis(_ analysis: Data, for capture: CaptureRecord, in modelContext: ModelContext) throws {
        let newReference = try contentStore.store(
            analysis,
            recordID: capture.id,
            recordType: .capture,
            purpose: .captureAnalysis
        )
        do {
            capture.encryptedAnalysisReference = try newReference.serialized()
            capture.analyzedJSON = nil
            capture.processed = false // AI output always remains review-required.
            capture.updatedAt = .now
            try modelContext.save()
        } catch {
            throw error
        }
    }

    func decryptedAnalysis(for capture: CaptureRecord) throws -> Data? {
        guard let serializedReference = capture.encryptedAnalysisReference else { return nil }
        return try contentStore.load(LocalEncryptedContentReference.deserialize(serializedReference))
    }

    func deleteCapture(_ capture: CaptureRecord, from modelContext: ModelContext) throws {
        try deleteReference(capture.encryptedContentReference)
        try deleteReference(capture.encryptedAttachmentReference)
        try deleteReference(capture.encryptedAnalysisReference)
        modelContext.delete(capture)
        try modelContext.save()
    }

    private func deleteReference(_ serializedReference: String?) throws {
        guard let serializedReference else { return }
        try contentStore.delete(LocalEncryptedContentReference.deserialize(serializedReference))
    }

    private func requiresAttachment(_ kind: CaptureKind) -> Bool {
        switch kind {
        case .photo, .screenshot, .voice: true
        case .text, .email, .sharedText: false
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
