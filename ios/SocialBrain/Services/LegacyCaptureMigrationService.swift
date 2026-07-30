import Foundation
import SwiftData

struct LegacyCaptureMigrationResult: Equatable {
    var migratedCount = 0
    var skippedCount = 0
    var failedCount = 0
}

private enum LegacyCaptureMigrationSafetyError: Error {
    case unableToVerifyLegacyContent
}

/// Idempotently moves the short-lived plaintext fields used by early builds
/// into the device-key encrypted content store. Encryption is verified before
/// a reference is saved; plaintext is cleared only by a later successful save.
@MainActor
final class LegacyCaptureMigrationService {
    private let contentStore: LocalEncryptedContentStore
    private let fileManager: FileManager
    private let cleanupQueue: EncryptedContentCleanupQueue

    init(
        contentStore: LocalEncryptedContentStore = LocalEncryptedContentStore(),
        fileManager: FileManager = .default,
        cleanupQueue: EncryptedContentCleanupQueue = EncryptedContentCleanupQueue()
    ) {
        self.contentStore = contentStore
        self.fileManager = fileManager
        self.cleanupQueue = cleanupQueue
    }

    func migrateIfNeeded(in modelContext: ModelContext) -> LegacyCaptureMigrationResult {
        let captures: [CaptureRecord]
        do {
            captures = try modelContext.fetch(FetchDescriptor<CaptureRecord>())
        } catch {
            return LegacyCaptureMigrationResult(failedCount: 1)
        }

        var result = LegacyCaptureMigrationResult()
        for capture in captures where hasLegacyPayload(capture) {
            do {
                if try migrate(capture, in: modelContext) {
                    result.migratedCount += 1
                } else {
                    result.skippedCount += 1
                }
            } catch {
                result.failedCount += 1
            }
        }
        return result
    }

    /// Returns false when legacy content cannot safely be verified or read. The
    /// legacy fields are intentionally retained in that case for user recovery.
    private func migrate(_ capture: CaptureRecord, in modelContext: ModelContext) throws -> Bool {
        var staged: [LocalEncryptedContentReference] = []
        var legacyAttachmentURL: URL?
        var persistedEncryptedReferences = false
        do {
            if !capture.rawContent.isEmpty {
                let legacyData = Data(capture.rawContent.utf8)
                if let serializedReference = capture.encryptedContentReference {
                    // Do not clear plaintext merely because a reference exists:
                    // it must decrypt to exactly the legacy content first.
                    guard try matchesStoredContent(serializedReference, expected: legacyData) else {
                        throw LegacyCaptureMigrationSafetyError.unableToVerifyLegacyContent
                    }
                } else {
                    let reference = try storeAndVerify(
                        legacyData,
                        capture: capture,
                        purpose: .captureBody
                    )
                    capture.encryptedContentReference = try reference.serialized()
                    staged.append(reference)
                }
            }

            if let attachmentPath = capture.attachmentPath, !attachmentPath.isEmpty {
                let url = URL(fileURLWithPath: attachmentPath)
                legacyAttachmentURL = url
                guard fileManager.fileExists(atPath: url.path),
                      let data = try legacyAttachmentData(at: url)
                else { throw LegacyCaptureMigrationSafetyError.unableToVerifyLegacyContent }
                let metadata = try LocalAttachmentMetadata(
                    mimeType: mimeType(for: url),
                    fileExtension: url.pathExtension.isEmpty ? "bin" : url.pathExtension,
                    originalName: url.lastPathComponent,
                    byteCount: data.count,
                    captureKind: capture.type
                )
                if let serializedReference = capture.encryptedAttachmentReference {
                    guard try matchesStoredAttachment(
                        serializedReference,
                        expected: data,
                        metadata: metadata
                    ) else {
                        throw LegacyCaptureMigrationSafetyError.unableToVerifyLegacyContent
                    }
                } else {
                    let reference = try contentStore.store(
                        data,
                        recordID: capture.id,
                        recordType: .capture,
                        purpose: .captureAttachment,
                        attachmentMetadata: metadata
                    )
                    guard try contentStore.load(reference) == data else {
                        throw LocalEncryptedContentStoreError.tamperedContent
                    }
                    capture.encryptedAttachmentReference = try reference.serialized()
                    capture.attachmentMIMEType = metadata.mimeType
                    capture.attachmentFileExtension = metadata.fileExtension
                    capture.attachmentOriginalName = metadata.originalName
                    capture.attachmentByteCount = metadata.byteCount
                    staged.append(reference)
                }
            }

            if let analysis = capture.analyzedJSON, !analysis.isEmpty {
                let legacyData = Data(analysis.utf8)
                if let serializedReference = capture.encryptedAnalysisReference {
                    guard try matchesStoredContent(serializedReference, expected: legacyData) else {
                        throw LegacyCaptureMigrationSafetyError.unableToVerifyLegacyContent
                    }
                } else {
                    let reference = try storeAndVerify(
                        legacyData,
                        capture: capture,
                        purpose: .captureAnalysis
                    )
                    capture.encryptedAnalysisReference = try reference.serialized()
                    staged.append(reference)
                }
            }

            // Commit references first. If this fails no legacy plaintext is
            // cleared and staged encrypted content is rolled back below.
            try modelContext.save()
            persistedEncryptedReferences = true

            capture.rawContent = ""
            capture.analyzedJSON = nil
            capture.updatedAt = .now
            try modelContext.save()

            if let legacyAttachmentURL {
                if fileManager.fileExists(atPath: legacyAttachmentURL.path) {
                    try fileManager.removeItem(at: legacyAttachmentURL)
                }
                // Keep the legacy pointer until its plaintext file has been
                // removed. If this save fails, the next idempotent migration
                // sees the encrypted reference and safely retries the clear.
                capture.attachmentPath = nil
                capture.updatedAt = .now
                try modelContext.save()
            }
            return true
        } catch is LegacyCaptureMigrationSafetyError {
            // A prior stage may already have encrypted another field. Discard
            // those unreferenced files and rollback in-memory field changes
            // before reporting a recoverable skip.
            modelContext.rollback()
            if !persistedEncryptedReferences {
                for reference in staged {
                    do {
                        try contentStore.delete(reference)
                    } catch {
                        cleanupQueue.enqueue(reference)
                    }
                }
            }
            return false
        } catch {
            modelContext.rollback()
            if !persistedEncryptedReferences {
                for reference in staged {
                    do {
                        try contentStore.delete(reference)
                    } catch {
                        cleanupQueue.enqueue(reference)
                    }
                }
            }
            throw error
        }
    }

    private func storeAndVerify(
        _ data: Data,
        capture: CaptureRecord,
        purpose: LocalContentPurpose
    ) throws -> LocalEncryptedContentReference {
        let reference = try contentStore.store(
            data,
            recordID: capture.id,
            recordType: .capture,
            purpose: purpose
        )
        guard try contentStore.load(reference) == data else {
            throw LocalEncryptedContentStoreError.tamperedContent
        }
        return reference
    }

    private func matchesStoredContent(_ serializedReference: String, expected: Data) throws -> Bool {
        let reference = try LocalEncryptedContentReference.deserialize(serializedReference)
        return try contentStore.load(reference) == expected
    }

    private func matchesStoredAttachment(
        _ serializedReference: String,
        expected: Data,
        metadata: LocalAttachmentMetadata
    ) throws -> Bool {
        let reference = try LocalEncryptedContentReference.deserialize(serializedReference)
        let contentMatches = try contentStore.load(reference) == expected
        let storedMetadata = try contentStore.attachmentMetadata(for: reference)
        return contentMatches && storedMetadata == metadata
    }

    /// Legacy imports pre-date the streaming capture path. Bound them before
    /// mapping/loading to avoid a malformed old pointer exhausting memory at
    /// launch. Oversized content stays intact for explicit user recovery.
    private func legacyAttachmentData(at url: URL) throws -> Data? {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = values.fileSize,
              fileSize >= 0,
              fileSize <= CaptureImportLimits.maxAttachmentBytes
        else {
            return nil
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return data.count <= CaptureImportLimits.maxAttachmentBytes ? data : nil
    }

    private func hasLegacyPayload(_ capture: CaptureRecord) -> Bool {
        !capture.rawContent.isEmpty ||
            !(capture.attachmentPath?.isEmpty ?? true) ||
            !(capture.analyzedJSON?.isEmpty ?? true)
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic": return "image/heic"
        case "m4a": return "audio/m4a"
        case "wav": return "audio/wav"
        case "mp3": return "audio/mpeg"
        default: return "application/octet-stream"
        }
    }
}
