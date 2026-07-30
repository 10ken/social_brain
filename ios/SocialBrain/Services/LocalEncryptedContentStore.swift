import Foundation

/// The local device key is deliberately marked `ThisDeviceOnly`: it is not
/// backed up, synced, or recoverable on another device.
protocol LocalContentKeyProviding: AnyObject {
    var keyVersion: Int { get }
    func loadOrCreateKey() throws -> Data
    func destroyKey() throws
}

final class LocalContentKeyManager: LocalContentKeyProviding {
    static let shared = LocalContentKeyManager()

    let keyVersion = 1
    private let keychainAccount = "local-content-key-v1"

    private init() {}

    func loadOrCreateKey() throws -> Data {
        if let key = try KeychainStore.load(account: keychainAccount) {
            guard key.count == ContentCipher.keyByteCount else {
                try destroyKey()
                throw LocalEncryptedContentStoreError.invalidStoredKey
            }
            return key
        }

        let key = try ContentCipher.generateKey()
        try KeychainStore.save(key, account: keychainAccount)
        return key
    }

    func destroyKey() throws {
        try KeychainStore.delete(account: keychainAccount)
    }
}

enum LocalContentPurpose: String, Codable, CaseIterable {
    case captureBody
    case captureAttachment
    case captureAnalysis
    case captureReview
    case recordNote
}

/// Attachment properties are persisted inside the authenticated envelope as
/// well as on the lightweight capture record. The envelope copy is the source
/// of truth when a decrypted attachment is opened.
struct LocalAttachmentMetadata: Codable, Equatable, Hashable {
    let mimeType: String
    let fileExtension: String
    let originalName: String?
    let byteCount: Int
    let captureKind: String

    init(
        mimeType: String,
        fileExtension: String,
        originalName: String? = nil,
        byteCount: Int,
        captureKind: String
    ) throws {
        let normalizedMIMEType = mimeType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedExtension = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedKind = captureKind.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedMIMEType.isEmpty,
              !normalizedExtension.isEmpty,
              !normalizedKind.isEmpty,
              byteCount >= 0,
              byteCount <= 25_000_000
        else {
            throw LocalEncryptedContentStoreError.invalidAttachmentMetadata
        }
        self.mimeType = normalizedMIMEType
        self.fileExtension = normalizedExtension
        self.originalName = originalName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.byteCount = byteCount
        self.captureKind = normalizedKind
    }

    fileprivate var authenticatedEncoding: String {
        [mimeType, fileExtension, originalName ?? "", String(byteCount), captureKind]
            .map { $0.replacingOccurrences(of: "|", with: "\\u{001F}") }
            .joined(separator: "|")
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

struct LocalEncryptedContentReference: Codable, Equatable, Hashable {
    let relativePath: String
    let recordID: UUID
    let recordType: RecordType
    let purpose: LocalContentPurpose
    let keyVersion: Int

    /// New writes that can replace an existing purpose (analysis and review)
    /// use an opaque file token. `nil` retains the deterministic filename used
    /// by schema-1/2 records, so existing references remain decodable.
    let fileToken: UUID?

    private enum CodingKeys: String, CodingKey {
        case relativePath
        case recordID
        case recordType
        case purpose
        case keyVersion
        case fileToken
    }

    init(
        relativePath: String,
        recordID: UUID,
        recordType: RecordType,
        purpose: LocalContentPurpose,
        keyVersion: Int,
        fileToken: UUID? = nil
    ) {
        self.relativePath = relativePath
        self.recordID = recordID
        self.recordType = recordType
        self.purpose = purpose
        self.keyVersion = keyVersion
        self.fileToken = fileToken
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        relativePath = try container.decode(String.self, forKey: .relativePath)
        recordID = try container.decode(UUID.self, forKey: .recordID)
        recordType = try container.decode(RecordType.self, forKey: .recordType)
        purpose = try container.decode(LocalContentPurpose.self, forKey: .purpose)
        keyVersion = try container.decode(Int.self, forKey: .keyVersion)
        fileToken = try container.decodeIfPresent(UUID.self, forKey: .fileToken)
    }

    func serialized() throws -> String {
        let data = try JSONEncoder().encode(self)
        guard let value = String(data: data, encoding: .utf8) else {
            throw LocalEncryptedContentStoreError.invalidReference
        }
        return value
    }

    static func deserialize(_ value: String) throws -> LocalEncryptedContentReference {
        guard let data = value.data(using: .utf8) else {
            throw LocalEncryptedContentStoreError.invalidReference
        }
        return try JSONDecoder().decode(LocalEncryptedContentReference.self, from: data)
    }
}

enum LocalEncryptedContentStoreError: Error, Equatable {
    case invalidStoredKey
    case invalidReference
    case unsupportedSchemaVersion
    case unsupportedKeyVersion
    case tamperedContent
    case missingContent
    case invalidAttachmentMetadata
}

private struct LocalEncryptedContentEnvelope: Codable {
    let schemaVersion: Int
    let recordID: UUID
    let recordType: RecordType
    let purpose: LocalContentPurpose
    let keyVersion: Int
    let nonce: Data
    let ciphertext: Data
    let attachmentMetadata: LocalAttachmentMetadata?
    /// Schema 3 binds an opaque versioned filename into authenticated data.
    /// Earlier envelopes deliberately omit it for backward compatibility.
    let relativePath: String?

    init(
        reference: LocalEncryptedContentReference,
        nonce: Data,
        ciphertext: Data,
        attachmentMetadata: LocalAttachmentMetadata? = nil
    ) {
        schemaVersion = reference.fileToken == nil ? (attachmentMetadata == nil ? 1 : 2) : 3
        recordID = reference.recordID
        recordType = reference.recordType
        purpose = reference.purpose
        keyVersion = reference.keyVersion
        self.nonce = nonce
        self.ciphertext = ciphertext
        self.attachmentMetadata = attachmentMetadata
        relativePath = schemaVersion == 3 ? reference.relativePath : nil
    }

    var authenticatedMetadata: Data {
        var components = [
            "local-content",
            String(schemaVersion),
            recordID.uuidString.lowercased(),
            recordType.rawValue,
            purpose.rawValue,
            String(keyVersion)
        ]
        if schemaVersion == 3 {
            components.append(relativePath ?? "")
        }
        if schemaVersion >= 2, let attachmentMetadata {
            components.append(attachmentMetadata.authenticatedEncoding)
        }
        return Data(components.joined(separator: "|").utf8)
    }
}

/// File-backed encrypted content for imported captures and future private record
/// fields. SwiftData only retains a non-sensitive reference to these files.
final class LocalEncryptedContentStore {
    static let directoryName = "EncryptedContent"

    private let keyProvider: any LocalContentKeyProviding
    private let fileManager: FileManager
    private let directoryURL: URL

    init(
        keyProvider: any LocalContentKeyProviding = LocalContentKeyManager.shared,
        fileManager: FileManager = .default,
        directoryURL: URL? = nil
    ) {
        self.keyProvider = keyProvider
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager)
    }

    func store(
        _ plaintext: Data,
        recordID: UUID,
        recordType: RecordType,
        purpose: LocalContentPurpose,
        attachmentMetadata: LocalAttachmentMetadata? = nil,
        uniqueFile: Bool = false
    ) throws -> LocalEncryptedContentReference {
        try ensureDirectoryExists()

        let fileToken = uniqueFile ? UUID() : nil
        let reference = LocalEncryptedContentReference(
            relativePath: fileName(recordID: recordID, purpose: purpose, fileToken: fileToken),
            recordID: recordID,
            recordType: recordType,
            purpose: purpose,
            keyVersion: keyProvider.keyVersion,
            fileToken: fileToken
        )
        let envelopeTemplate = LocalEncryptedContentEnvelope(
            reference: reference,
            nonce: Data(),
            ciphertext: Data(),
            attachmentMetadata: attachmentMetadata
        )
        let sealed = try ContentCipher.seal(
            plaintext,
            key: try keyProvider.loadOrCreateKey(),
            authenticatedMetadata: envelopeTemplate.authenticatedMetadata
        )
        let envelope = LocalEncryptedContentEnvelope(
            reference: reference,
            nonce: sealed.nonce,
            ciphertext: sealed.ciphertext,
            attachmentMetadata: attachmentMetadata
        )
        let encoded = try JSONEncoder().encode(envelope)
        let fileURL = try fileURL(for: reference)
        try encoded.write(to: fileURL, options: .atomic)
        protectFileIfSupported(fileURL)
        return reference
    }

    func load(_ reference: LocalEncryptedContentReference) throws -> Data {
        let envelope = try loadEnvelope(reference)
        return try decrypt(envelope)
    }

    /// Metadata is part of the AEAD additional authenticated data. Verify the
    /// tag before exposing it so a modified filename/MIME field cannot reach a
    /// preview or export UI independently of the attachment bytes.
    func attachmentMetadata(for reference: LocalEncryptedContentReference) throws -> LocalAttachmentMetadata? {
        let envelope = try loadEnvelope(reference)
        _ = try decrypt(envelope)
        return envelope.attachmentMetadata
    }

    private func decrypt(_ envelope: LocalEncryptedContentEnvelope) throws -> Data {
        do {
            return try ContentCipher.open(
                nonce: envelope.nonce,
                ciphertext: envelope.ciphertext,
                key: try keyProvider.loadOrCreateKey(),
                authenticatedMetadata: envelope.authenticatedMetadata
            )
        } catch {
            throw LocalEncryptedContentStoreError.tamperedContent
        }
    }

    private func loadEnvelope(_ reference: LocalEncryptedContentReference) throws -> LocalEncryptedContentEnvelope {
        guard reference.keyVersion == keyProvider.keyVersion else {
            throw LocalEncryptedContentStoreError.unsupportedKeyVersion
        }
        let fileURL = try fileURL(for: reference)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw LocalEncryptedContentStoreError.missingContent
        }

        let envelope: LocalEncryptedContentEnvelope
        do {
            envelope = try JSONDecoder().decode(LocalEncryptedContentEnvelope.self, from: Data(contentsOf: fileURL))
        } catch {
            throw LocalEncryptedContentStoreError.tamperedContent
        }
        guard envelope.schemaVersion == 1 || envelope.schemaVersion == 2 || envelope.schemaVersion == 3 else {
            throw LocalEncryptedContentStoreError.unsupportedSchemaVersion
        }
        let hasValidSchemaMetadata: Bool
        switch envelope.schemaVersion {
        case 1:
            hasValidSchemaMetadata = envelope.attachmentMetadata == nil &&
                envelope.relativePath == nil &&
                reference.fileToken == nil
        case 2:
            hasValidSchemaMetadata = envelope.attachmentMetadata != nil &&
                envelope.relativePath == nil &&
                reference.fileToken == nil
        case 3:
            hasValidSchemaMetadata = reference.fileToken != nil &&
                envelope.relativePath == reference.relativePath
        default:
            hasValidSchemaMetadata = false
        }
        guard envelope.recordID == reference.recordID,
              envelope.recordType == reference.recordType,
              envelope.purpose == reference.purpose,
              envelope.keyVersion == reference.keyVersion,
              envelope.nonce.count == ContentCipher.nonceByteCount,
              envelope.ciphertext.count >= ContentCipher.authenticationTagByteCount,
              hasValidSchemaMetadata
        else {
            throw LocalEncryptedContentStoreError.tamperedContent
        }
        return envelope
    }

    func delete(_ reference: LocalEncryptedContentReference) throws {
        let fileURL = try fileURL(for: reference)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    /// Kept for existing callers. Reset orchestration uses the independent
    /// operations below so one partial failure cannot skip another domain.
    func destroyAll() throws {
        try destroyKey()
        try deleteAllFiles()
    }

    func destroyKey() throws {
        try keyProvider.destroyKey()
    }

    func deleteAllFiles() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.removeItem(at: directoryURL)
    }

    var storageDirectoryURL: URL { directoryURL }

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport
            .appendingPathComponent("SocialBrain", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private func ensureDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        protectFileIfSupported(directoryURL)
    }

    private func fileURL(for reference: LocalEncryptedContentReference) throws -> URL {
        guard reference.relativePath == fileName(
            recordID: reference.recordID,
            purpose: reference.purpose,
            fileToken: reference.fileToken
        ) else {
            throw LocalEncryptedContentStoreError.invalidReference
        }
        return directoryURL.appendingPathComponent(reference.relativePath, isDirectory: false)
    }

    private func fileName(recordID: UUID, purpose: LocalContentPurpose, fileToken: UUID? = nil) -> String {
        let tokenSuffix = fileToken.map { "-\($0.uuidString.lowercased())" } ?? ""
        return "\(recordID.uuidString.lowercased())-\(purpose.rawValue)\(tokenSuffix).sbenc"
    }

    private func protectFileIfSupported(_ url: URL) {
#if os(iOS)
        try? fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
#endif
    }
}
