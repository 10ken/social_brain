import Foundation
import XCTest
@testable import SocialBrain

final class LocalEncryptedContentStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: temporaryDirectory.path) {
            try FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testRoundTripUsesDeviceKeyAndAuthenticatedReference() throws {
        let keys = InMemoryContentKeyProvider()
        let store = LocalEncryptedContentStore(keyProvider: keys, directoryURL: temporaryDirectory)
        let recordID = UUID()
        let reference = try store.store(
            Data("A private imported email".utf8),
            recordID: recordID,
            recordType: .capture,
            purpose: .captureBody
        )

        XCTAssertEqual(try store.load(reference), Data("A private imported email".utf8))
        XCTAssertEqual(try LocalEncryptedContentReference.deserialize(reference.serialized()), reference)
    }

    func testChangingReferenceMetadataIsRejected() throws {
        let keys = InMemoryContentKeyProvider()
        let store = LocalEncryptedContentStore(keyProvider: keys, directoryURL: temporaryDirectory)
        let reference = try store.store(
            Data("Private note".utf8),
            recordID: UUID(),
            recordType: .capture,
            purpose: .captureBody
        )
        let altered = LocalEncryptedContentReference(
            relativePath: reference.relativePath,
            recordID: reference.recordID,
            recordType: .capture,
            purpose: .captureAttachment,
            keyVersion: reference.keyVersion
        )

        XCTAssertThrowsError(try store.load(altered)) { error in
            XCTAssertEqual(error as? LocalEncryptedContentStoreError, .invalidReference)
        }
    }

    func testVersionedReferencesKeepReplacementCiphertextFailureAtomic() throws {
        let keys = InMemoryContentKeyProvider()
        let store = LocalEncryptedContentStore(keyProvider: keys, directoryURL: temporaryDirectory)
        let recordID = UUID()
        let first = try store.store(
            Data("first analysis".utf8),
            recordID: recordID,
            recordType: .capture,
            purpose: .captureAnalysis,
            uniqueFile: true
        )
        let second = try store.store(
            Data("replacement analysis".utf8),
            recordID: recordID,
            recordType: .capture,
            purpose: .captureAnalysis,
            uniqueFile: true
        )

        XCTAssertNotEqual(first.relativePath, second.relativePath)
        XCTAssertNotNil(first.fileToken)
        XCTAssertNotNil(second.fileToken)
        XCTAssertEqual(try store.load(first), Data("first analysis".utf8))
        XCTAssertEqual(try store.load(second), Data("replacement analysis".utf8))

        // Moving a valid envelope to another versioned reference must fail:
        // schema 3 authenticates the opaque filename as well as record fields.
        let firstURL = store.storageDirectoryURL.appendingPathComponent(first.relativePath)
        let secondURL = store.storageDirectoryURL.appendingPathComponent(second.relativePath)
        try FileManager.default.removeItem(at: secondURL)
        try FileManager.default.copyItem(at: firstURL, to: secondURL)
        XCTAssertThrowsError(try store.load(second)) { error in
            XCTAssertEqual(error as? LocalEncryptedContentStoreError, .tamperedContent)
        }
    }

    func testDestroyAllMakesContentUnreadableAndRemovesDirectory() throws {
        let keys = InMemoryContentKeyProvider()
        let store = LocalEncryptedContentStore(keyProvider: keys, directoryURL: temporaryDirectory)
        let reference = try store.store(
            Data("Cannot recover".utf8),
            recordID: UUID(),
            recordType: .capture,
            purpose: .captureBody
        )

        try store.destroyAll()

        XCTAssertFalse(keys.hasKey)
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryDirectory.path))
        XCTAssertThrowsError(try store.load(reference))
    }

    func testTamperedAttachmentEnvelopeIsRejected() throws {
        let keys = InMemoryContentKeyProvider()
        let store = LocalEncryptedContentStore(keyProvider: keys, directoryURL: temporaryDirectory)
        let metadata = try LocalAttachmentMetadata(
            mimeType: "image/png",
            fileExtension: "png",
            originalName: "screen.png",
            byteCount: 4,
            captureKind: "screenshot"
        )
        let reference = try store.store(
            Data([0x89, 0x50, 0x4E, 0x47]),
            recordID: UUID(),
            recordType: .capture,
            purpose: .captureAttachment,
            attachmentMetadata: metadata
        )
        let fileURL = store.storageDirectoryURL.appendingPathComponent(reference.relativePath)
        var encoded = try Data(contentsOf: fileURL)
        encoded[encoded.startIndex] ^= 0x01
        try encoded.write(to: fileURL, options: .atomic)

        XCTAssertThrowsError(try store.load(reference)) { error in
            XCTAssertEqual(error as? LocalEncryptedContentStoreError, .tamperedContent)
        }
    }

    func testAttachmentMetadataIsAuthenticatedBeforeItIsReturned() throws {
        let keys = InMemoryContentKeyProvider()
        let store = LocalEncryptedContentStore(keyProvider: keys, directoryURL: temporaryDirectory)
        let metadata = try LocalAttachmentMetadata(
            mimeType: "image/png",
            fileExtension: "png",
            originalName: "screen.png",
            byteCount: 4,
            captureKind: "screenshot"
        )
        let reference = try store.store(
            Data([0x89, 0x50, 0x4E, 0x47]),
            recordID: UUID(),
            recordType: .capture,
            purpose: .captureAttachment,
            attachmentMetadata: metadata
        )
        let fileURL = store.storageDirectoryURL.appendingPathComponent(reference.relativePath)
        var envelope = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        )
        var tamperedMetadata = try XCTUnwrap(envelope["attachmentMetadata"] as? [String: Any])
        tamperedMetadata["originalName"] = "other.png"
        envelope["attachmentMetadata"] = tamperedMetadata
        let tamperedData = try JSONSerialization.data(withJSONObject: envelope)
        try tamperedData.write(to: fileURL, options: .atomic)

        XCTAssertThrowsError(try store.attachmentMetadata(for: reference)) { error in
            XCTAssertEqual(error as? LocalEncryptedContentStoreError, .tamperedContent)
        }
    }
}

final class InMemoryContentKeyProvider: LocalContentKeyProviding {
    let keyVersion = 1
    private var key: Data?

    var hasKey: Bool { key != nil }

    func loadOrCreateKey() throws -> Data {
        if let key { return key }
        let newKey = try ContentCipher.generateKey()
        key = newKey
        return newKey
    }

    func destroyKey() throws {
        key = nil
    }
}
