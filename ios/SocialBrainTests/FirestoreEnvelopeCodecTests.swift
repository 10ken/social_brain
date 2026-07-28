import Foundation
import XCTest
@testable import SocialBrain

final class FirestoreEnvelopeCodecTests: XCTestCase {
    func testRoundTripAcceptsNSNumberMetadataAndOmitsNilTombstoneDate() throws {
        let envelope = makeEnvelope()
        var document = FirestoreEnvelopeCodec.documentData(for: envelope)
        document["schemaVersion"] = NSNumber(value: 1)
        document["keyVersion"] = NSNumber(value: 1)
        document["updatedAtMs"] = NSNumber(value: 1_700_000_000_000 as Int64)

        XCTAssertNil(document["deletedAtMs"])
        XCTAssertEqual(try FirestoreEnvelopeCodec.envelope(from: document), envelope)
    }

    func testMalformedRevisionIsRejected() {
        var document = FirestoreEnvelopeCodec.documentData(for: makeEnvelope())
        document["revision"] = "7:not-a-uuid:extra"

        XCTAssertThrowsError(try FirestoreEnvelopeCodec.envelope(from: document)) { error in
            XCTAssertEqual(error as? CloudSyncError, .malformedEnvelope)
        }
    }

    func testDeletedEnvelopeRequiresDeletedAt() {
        var document = FirestoreEnvelopeCodec.documentData(for: makeEnvelope())
        document["deleted"] = true

        XCTAssertThrowsError(try FirestoreEnvelopeCodec.envelope(from: document)) { error in
            XCTAssertEqual(error as? CloudSyncError, .malformedEnvelope)
        }
    }

    private func makeEnvelope() -> EncryptedRecordEnvelope {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
        let deviceID = UUID(uuidString: "00000000-0000-0000-0000-000000000022")!
        return EncryptedRecordEnvelope(
            id: id,
            recordType: .memory,
            keyVersion: 1,
            revision: HybridRevision(counter: 7, deviceID: deviceID),
            deviceID: deviceID,
            updatedAtMs: 1_700_000_000_000,
            nonce: Data(repeating: 1, count: 12),
            ciphertext: Data(repeating: 2, count: 16)
        )
    }
}
