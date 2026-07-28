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
    case recordNote
}

struct LocalEncryptedContentReference: Codable, Equatable, Hashable {
    let relativePath: String
    let recordID: UUID
    let recordType: RecordType
    let purpose: LocalContentPurpose
    let keyVersion: Int

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
}

private struct LocalEncryptedContentEnvelope: Codable {
    let schemaVersion: Int
    let recordID: UUID
    let recordType: RecordType
    let purpose: LocalContentPurpose
    let keyVersion: Int
    let nonce: Data
    let ciphertext: Data

    init(reference: LocalEncryptedContentReference, nonce: Data, ciphertext: Data) {
        schemaVersion = 1
        recordID = reference.recordID
        recordType = reference.recordType
        purpose = reference.purpose
        keyVersion = reference.keyVersion
        self.nonce = nonce
        self.ciphertext = ciphertext
    }

    var authenticatedMetadata: Data {
        Data("local-content|\(schemaVersion)|\(recordID.uuidString.lowercased())|\(recordType.rawValue)|\(purpose.rawValue)|\(keyVersion)".utf8)
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
        purpose: LocalContentPurpose
    ) throws -> LocalEncryptedContentReference {
        try ensureDirectoryExists()

        let reference = LocalEncryptedContentReference(
            relativePath: fileName(recordID: recordID, purpose: purpose),
            recordID: recordID,
            recordType: recordType,
            purpose: purpose,
            keyVersion: keyProvider.keyVersion
        )
        let envelopeTemplate = LocalEncryptedContentEnvelope(reference: reference, nonce: Data(), ciphertext: Data())
        let sealed = try ContentCipher.seal(
            plaintext,
            key: try keyProvider.loadOrCreateKey(),
            authenticatedMetadata: envelopeTemplate.authenticatedMetadata
        )
        let envelope = LocalEncryptedContentEnvelope(reference: reference, nonce: sealed.nonce, ciphertext: sealed.ciphertext)
        let encoded = try JSONEncoder().encode(envelope)
        let fileURL = try fileURL(for: reference)
        try encoded.write(to: fileURL, options: .atomic)
        protectFileIfSupported(fileURL)
        return reference
    }

    func load(_ reference: LocalEncryptedContentReference) throws -> Data {
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
        guard envelope.schemaVersion == 1 else {
            throw LocalEncryptedContentStoreError.unsupportedSchemaVersion
        }
        guard envelope.recordID == reference.recordID,
              envelope.recordType == reference.recordType,
              envelope.purpose == reference.purpose,
              envelope.keyVersion == reference.keyVersion,
              envelope.nonce.count == 12,
              envelope.ciphertext.count >= 16
        else {
            throw LocalEncryptedContentStoreError.tamperedContent
        }

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

    func delete(_ reference: LocalEncryptedContentReference) throws {
        let fileURL = try fileURL(for: reference)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    /// Deletes the device-only key before attempting filesystem cleanup. If a
    /// file cannot be removed, it remains cryptographically unreadable.
    func destroyAll() throws {
        try keyProvider.destroyKey()
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
        guard reference.relativePath == fileName(recordID: reference.recordID, purpose: reference.purpose) else {
            throw LocalEncryptedContentStoreError.invalidReference
        }
        return directoryURL.appendingPathComponent(reference.relativePath, isDirectory: false)
    }

    private func fileName(recordID: UUID, purpose: LocalContentPurpose) -> String {
        "\(recordID.uuidString.lowercased())-\(purpose.rawValue).sbenc"
    }

    private func protectFileIfSupported(_ url: URL) {
#if os(iOS)
        try? fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
#endif
    }
}
