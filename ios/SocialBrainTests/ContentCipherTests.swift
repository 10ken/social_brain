import XCTest
@testable import SocialBrain

final class ContentCipherTests: XCTestCase {
    func testRoundTripAuthenticatesEnvelopeMetadata() throws {
        let key = try ContentCipher.generateKey()
        let metadata = Data("person:record-1:1".utf8)
        let value = Data("A private memory".utf8)
        let sealed = try ContentCipher.seal(value, key: key, authenticatedMetadata: metadata)
        XCTAssertEqual(try ContentCipher.open(nonce: sealed.nonce, ciphertext: sealed.ciphertext, key: key, authenticatedMetadata: metadata), value)
    }

    func testMetadataChangeCannotDecryptCiphertext() throws {
        let key = try ContentCipher.generateKey()
        let sealed = try ContentCipher.seal(
            Data("Private data".utf8),
            key: key,
            authenticatedMetadata: Data("record:1".utf8)
        )

        XCTAssertThrowsError(
            try ContentCipher.open(
                nonce: sealed.nonce,
                ciphertext: sealed.ciphertext,
                key: key,
                authenticatedMetadata: Data("record:2".utf8)
            )
        )
    }
}
