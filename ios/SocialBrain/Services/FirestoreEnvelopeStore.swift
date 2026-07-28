import Foundation

/// Cross-device encrypted sync is deliberately unavailable. Both clients use
/// device-only keys, so sending envelopes to Firestore would create a false
/// expectation of recovery on another device. The codec remains here for a
/// future, explicitly approved shared-key design and is not wired to any UI.
enum CloudSyncAvailability {
    static let isEnabled = false
    static let unavailableReason = "Cross-device encrypted sync is unavailable because content keys are device-only."
}

enum CloudSyncError: Error, Equatable {
    case unavailable
    case malformedEnvelope
}

/// Firestore-compatible serialization only. This type contains no Firestore
/// client calls and must not be treated as an active transport implementation.
enum FirestoreEnvelopeCodec {
    static func documentData(for value: EncryptedRecordEnvelope) -> [String: Any] {
        var data: [String: Any] = [
            "id": value.id.uuidString.lowercased(),
            "recordType": value.recordType.rawValue,
            "schemaVersion": value.schemaVersion,
            "keyVersion": value.keyVersion,
            "revision": value.revision.encoded,
            "deviceId": value.deviceID.uuidString.lowercased(),
            "updatedAtMs": value.updatedAtMs,
            "deleted": value.deleted,
            "nonce": value.nonce.base64EncodedString(),
            "ciphertext": value.ciphertext.base64EncodedString()
        ]
        if let deletedAtMs = value.deletedAtMs {
            data["deletedAtMs"] = deletedAtMs
        }
        return data
    }

    static func envelope(from data: [String: Any]) throws -> EncryptedRecordEnvelope {
        guard let idText = data["id"] as? String,
              let id = UUID(uuidString: idText),
              let recordTypeText = data["recordType"] as? String,
              let recordType = RecordType(rawValue: recordTypeText),
              let schemaVersion = intValue(data["schemaVersion"]), schemaVersion == 1,
              let keyVersion = intValue(data["keyVersion"]), keyVersion > 0,
              let revisionText = data["revision"] as? String,
              let revision = revision(from: revisionText),
              let deviceIDText = data["deviceId"] as? String,
              let deviceID = UUID(uuidString: deviceIDText),
              deviceID == revision.deviceID,
              let updatedAtMs = int64Value(data["updatedAtMs"]), updatedAtMs >= 0,
              let deleted = data["deleted"] as? Bool,
              let nonceText = data["nonce"] as? String,
              let nonce = Data(base64Encoded: nonceText), nonce.count == 12,
              let ciphertextText = data["ciphertext"] as? String,
              let ciphertext = Data(base64Encoded: ciphertextText), ciphertext.count >= 16
        else {
            throw CloudSyncError.malformedEnvelope
        }

        let deletedAtMs = int64Value(data["deletedAtMs"])
        guard deleted == (deletedAtMs != nil) else {
            throw CloudSyncError.malformedEnvelope
        }

        return EncryptedRecordEnvelope(
            id: id,
            recordType: recordType,
            keyVersion: keyVersion,
            revision: revision,
            deviceID: deviceID,
            updatedAtMs: updatedAtMs,
            deleted: deleted,
            deletedAtMs: deletedAtMs,
            nonce: nonce,
            ciphertext: ciphertext
        )
    }

    private static func revision(from value: String) -> HybridRevision? {
        let components = value.split(separator: ":", omittingEmptySubsequences: false)
        guard components.count == 2,
              let counter = Int64(components[0]), counter >= 0,
              let deviceID = UUID(uuidString: String(components[1]))
        else {
            return nil
        }
        return HybridRevision(counter: counter, deviceID: deviceID)
    }

    private static func intValue(_ value: Any?) -> Int? {
        guard let int64 = int64Value(value), int64 >= 0, int64 <= Int64(Int.max) else { return nil }
        return Int(int64)
    }

    /// Firestore bridges integer fields as NSNumber on some SDK versions. Do
    /// not accept booleans or fractional values as integer envelope metadata.
    private static func int64Value(_ value: Any?) -> Int64? {
        guard let value, !(value is Bool) else { return nil }
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? Int32 { return Int64(value) }
        guard let number = value as? NSNumber else { return nil }
        let double = number.doubleValue
        guard double.isFinite,
              double.rounded(.towardZero) == double,
              double >= Double(Int64.min),
              double <= Double(Int64.max)
        else {
            return nil
        }
        return number.int64Value
    }
}

@available(*, unavailable, message: "Cross-device encrypted sync is intentionally disabled while keys are device-only.")
final class FirestoreEnvelopeStore {
    private init() {}
}
