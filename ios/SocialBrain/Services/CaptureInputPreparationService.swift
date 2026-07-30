import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers

/// Limits are intentionally conservative: captures are reviewed locally, so
/// accepting unbounded pasted text or large files does not improve the feature.
enum CaptureInputLimits {
    static let maximumTextCharacters = 20_000
    static let maximumSourceLabelCharacters = 200
    static let maximumImageSourceBytes = 60_000_000
    /// The protected AI gateway rejects image bodies above this exact limit.
    static let maximumPreparedImageBytes = 5_000_000
    static let maximumAudioBytes = 25_000_000
    static let maximumVoiceRecordingDuration: TimeInterval = 5 * 60
    static let maximumImageDimension = 2_048
    static let maximumOriginalFilenameCharacters = 120
}

enum CaptureInputPreparationError: Error, Equatable, LocalizedError {
    case textTooLong(limit: Int)
    case sourceLabelTooLong(limit: Int)
    case unsupportedAttachment
    case attachmentTooLarge(limit: Int)
    case unreadableImage
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .textTooLong(let limit):
            return "Capture text must be \(limit.formatted()) characters or fewer."
        case .sourceLabelTooLong(let limit):
            return "Source labels must be \(limit.formatted()) characters or fewer."
        case .unsupportedAttachment:
            return "Choose a supported image or audio file."
        case .attachmentTooLarge(let limit):
            return "That attachment is larger than the \(ByteCountFormatter.string(fromByteCount: Int64(limit), countStyle: .file)) limit."
        case .unreadableImage:
            return "The selected image could not be prepared."
        case .unreadableFile:
            return "The selected file could not be read."
        }
    }
}

/// Attachment plus the non-sensitive metadata that is useful in the capture
/// list. The bytes themselves are encrypted by LocalCaptureService.
struct PreparedCaptureAttachment {
    let attachment: CaptureAttachment
    let originalFilename: String

    var byteCount: Int { attachment.data.count }
}

/// A narrow, fake-friendly boundary for converting user-selected input into
/// bounded payloads. It deliberately does not persist data.
protocol CaptureInputPreparing {
    func normalizedText(_ value: String?) throws -> String?
    func normalizedSourceLabel(_ value: String?) throws -> String?
    func prepareImage(data: Data, originalFilename: String?) throws -> PreparedCaptureAttachment
    func prepareAudio(data: Data, fileExtension: String, originalFilename: String?) throws -> PreparedCaptureAttachment
    func prepareAudioFile(at url: URL) throws -> PreparedCaptureAttachment
}

final class LocalCaptureInputPreparationService: CaptureInputPreparing {
    func normalizedText(_ value: String?) throws -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        guard normalized.count <= CaptureInputLimits.maximumTextCharacters else {
            throw CaptureInputPreparationError.textTooLong(limit: CaptureInputLimits.maximumTextCharacters)
        }
        return normalized
    }

    func normalizedSourceLabel(_ value: String?) throws -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        guard normalized.count <= CaptureInputLimits.maximumSourceLabelCharacters else {
            throw CaptureInputPreparationError.sourceLabelTooLong(limit: CaptureInputLimits.maximumSourceLabelCharacters)
        }
        return normalized
    }

    func prepareImage(data: Data, originalFilename: String?) throws -> PreparedCaptureAttachment {
        guard !data.isEmpty else { throw CaptureInputPreparationError.unreadableImage }
        guard data.count <= CaptureInputLimits.maximumImageSourceBytes else {
            throw CaptureInputPreparationError.attachmentTooLarge(limit: CaptureInputLimits.maximumImageSourceBytes)
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let typeIdentifier = CGImageSourceGetType(source) as String?,
              let imageType = UTType(identifier: typeIdentifier), imageType.conforms(to: .image)
        else {
            throw CaptureInputPreparationError.unsupportedAttachment
        }

        let thumbnailOptions: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: CaptureInputLimits.maximumImageDimension,
            kCGImageSourceShouldCacheImmediately: false
        ] as CFDictionary
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            throw CaptureInputPreparationError.unreadableImage
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw CaptureInputPreparationError.unreadableImage
        }
        CGImageDestinationAddImage(destination, thumbnail, [
            kCGImageDestinationLossyCompressionQuality: 0.85
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw CaptureInputPreparationError.unreadableImage
        }

        let preparedData = output as Data
        guard !preparedData.isEmpty else { throw CaptureInputPreparationError.unreadableImage }
        guard preparedData.count <= CaptureInputLimits.maximumPreparedImageBytes else {
            throw CaptureInputPreparationError.attachmentTooLarge(limit: CaptureInputLimits.maximumPreparedImageBytes)
        }
        let filename = sanitizedFilename(originalFilename, fallback: "image", fileExtension: "jpg")
        return PreparedCaptureAttachment(
            attachment: CaptureAttachment(
                data: preparedData,
                fileExtension: "jpg",
                mimeType: "image/jpeg",
                originalName: filename
            ),
            originalFilename: filename
        )
    }

    func prepareAudio(
        data: Data,
        fileExtension: String,
        originalFilename: String?
    ) throws -> PreparedCaptureAttachment {
        guard !data.isEmpty else { throw CaptureInputPreparationError.unreadableFile }
        guard data.count <= CaptureInputLimits.maximumAudioBytes else {
            throw CaptureInputPreparationError.attachmentTooLarge(limit: CaptureInputLimits.maximumAudioBytes)
        }
        let normalizedExtension = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        guard !normalizedExtension.isEmpty,
              let type = UTType(filenameExtension: normalizedExtension),
              type.conforms(to: .audio)
        else {
            throw CaptureInputPreparationError.unsupportedAttachment
        }
        let filename = sanitizedFilename(
            originalFilename,
            fallback: "voice-note",
            fileExtension: normalizedExtension
        )
        return PreparedCaptureAttachment(
            attachment: CaptureAttachment(
                data: data,
                fileExtension: normalizedExtension,
                mimeType: type.preferredMIMEType ?? "audio/*",
                originalName: filename
            ),
            originalFilename: filename
        )
    }

    func prepareAudioFile(at url: URL) throws -> PreparedCaptureAttachment {
        let didAccessSecurityScopedResource = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScopedResource {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            return try prepareAudio(
                data: data,
                fileExtension: url.pathExtension,
                originalFilename: url.lastPathComponent
            )
        } catch let error as CaptureInputPreparationError {
            throw error
        } catch {
            throw CaptureInputPreparationError.unreadableFile
        }
    }

    private func sanitizedFilename(_ proposed: String?, fallback: String, fileExtension: String) -> String {
        let baseName = proposed
            .flatMap { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent.nilIfEmpty }
            ?? fallback
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = String(baseName.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" })
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let safeBase = String((cleaned.nilIfEmpty ?? fallback).prefix(CaptureInputLimits.maximumOriginalFilenameCharacters))
        return "\(safeBase).\(fileExtension)"
    }
}

@MainActor
protocol CaptureImportCoordinating: AnyObject {
    func importCapture(
        kind: CaptureKind,
        text: String?,
        attachment: PreparedCaptureAttachment?,
        sourceLabel: String?,
        into modelContext: ModelContext
    ) throws -> CaptureRecord
}

/// Routes bounded input through the encrypted importer while retaining a small,
/// fake-friendly seam for the composer. The importer authenticates attachment
/// metadata (including originalName) alongside the encrypted attachment bytes.
@MainActor
final class LocalCaptureImportCoordinator: CaptureImportCoordinating {
    private let importer: any CaptureImporting

    init(importer: any CaptureImporting = LocalCaptureService()) {
        self.importer = importer
    }

    func importCapture(
        kind: CaptureKind,
        text: String?,
        attachment: PreparedCaptureAttachment?,
        sourceLabel: String?,
        into modelContext: ModelContext
    ) throws -> CaptureRecord {
        try importer.importCapture(
            CaptureImportRequest(
                kind: kind,
                text: text,
                attachment: attachment?.attachment,
                sourceLabel: sourceLabel
            ),
            into: modelContext
        )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
