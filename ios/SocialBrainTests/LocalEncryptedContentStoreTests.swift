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
