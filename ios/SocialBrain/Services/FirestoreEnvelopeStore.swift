import FirebaseAuth
import FirebaseFirestore
import Foundation

enum CloudSyncError: Error {
    case signedOut
    case malformedEnvelope
}

protocol EnvelopeStore {
    func upload(_ envelope: EncryptedRecordEnvelope) async throws
    func fetchAll() async throws -> [EncryptedRecordEnvelope]
}

final class FirestoreEnvelopeStore: EnvelopeStore {
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    func upload(_ envelope: EncryptedRecordEnvelope) async throws {
        let userID = try authenticatedUserID()
        try await firestore.collection("users").document(userID).collection("records")
            .document(envelope.id.uuidString.lowercased())
            .setData(documentData(for: envelope))
    }

    func fetchAll() async throws -> [EncryptedRecordEnvelope] {
        let userID = try authenticatedUserID()
        let snapshot = try await firestore.collection("users").document(userID).collection("records").getDocuments()
        return try snapshot.documents.map { try envelope(from: $0.data()) }
    }

    private func authenticatedUserID() throws -> String {
        guard let userID = Auth.auth().currentUser?.uid else { throw CloudSyncError.signedOut }
        return userID
    }

    private func documentData(for value: EncryptedRecordEnvelope) -> [String: Any] {
        [
            "id": value.id.uuidString.lowercased(), "recordType": value.recordType.rawValue,
            "schemaVersion": value.schemaVersion, "keyVersion": value.keyVersion,
            "revision": value.revision.encoded, "deviceId": value.deviceID.uuidString.lowercased(),
            "updatedAtMs": value.updatedAtMs, "deleted": value.deleted,
            "deletedAtMs": value.deletedAtMs as Any, "nonce": value.nonce.base64EncodedString(),
            "ciphertext": value.ciphertext.base64EncodedString()
        ]
    }

    private func envelope(from data: [String: Any]) throws -> EncryptedRecordEnvelope {
        guard let idText = data["id"] as? String, let id = UUID(uuidString: idText),
              let recordTypeText = data["recordType"] as? String, let recordType = RecordType(rawValue: recordTypeText),
              let schemaVersion = data["schemaVersion"] as? Int, schemaVersion == 1,
              let keyVersion = data["keyVersion"] as? Int,
              let revisionText = data["revision"] as? String,
              let separator = revisionText.firstIndex(of: ":"),
              let counter = Int64(revisionText[..<separator]),
              let deviceID = UUID(uuidString: String(revisionText[revisionText.index(after: separator)...])),
              let updatedAtMs = data["updatedAtMs"] as? Int64,
              let deleted = data["deleted"] as? Bool,
              let nonceText = data["nonce"] as? String, let nonce = Data(base64Encoded: nonceText),
              let ciphertextText = data["ciphertext"] as? String, let ciphertext = Data(base64Encoded: ciphertextText)
        else { throw CloudSyncError.malformedEnvelope }
        return EncryptedRecordEnvelope(
            id: id, recordType: recordType, keyVersion: keyVersion,
            revision: HybridRevision(counter: counter, deviceID: deviceID), deviceID: deviceID,
            updatedAtMs: updatedAtMs, deleted: deleted, deletedAtMs: data["deletedAtMs"] as? Int64,
            nonce: nonce, ciphertext: ciphertext
        )
    }
}
