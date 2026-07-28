import Foundation

enum RecordType: String, Codable, CaseIterable {
    case person, group, groupMembership, relationship, event, eventAttendee, memory, capture, reminder, settings
}

struct HybridRevision: Codable, Comparable, Hashable {
    let counter: Int64
    let deviceID: UUID
    static func < (lhs: HybridRevision, rhs: HybridRevision) -> Bool {
        lhs.counter == rhs.counter ? lhs.deviceID.uuidString < rhs.deviceID.uuidString : lhs.counter < rhs.counter
    }
    var encoded: String { "\(counter):\(deviceID.uuidString.lowercased())" }
}

struct EncryptedRecordEnvelope: Codable, Identifiable, Equatable {
    let id: UUID
    let recordType: RecordType
    let schemaVersion: Int
    let keyVersion: Int
    let revision: HybridRevision
    let deviceID: UUID
    let updatedAtMs: Int64
    let deleted: Bool
    let deletedAtMs: Int64?
    let nonce: Data
    let ciphertext: Data

    init(id: UUID, recordType: RecordType, keyVersion: Int, revision: HybridRevision, deviceID: UUID, updatedAtMs: Int64, deleted: Bool = false, deletedAtMs: Int64? = nil, nonce: Data, ciphertext: Data) {
        precondition(keyVersion > 0)
        precondition(!deleted || deletedAtMs != nil)
        self.id = id; self.recordType = recordType; schemaVersion = 1; self.keyVersion = keyVersion
        self.revision = revision; self.deviceID = deviceID; self.updatedAtMs = updatedAtMs
        self.deleted = deleted; self.deletedAtMs = deletedAtMs; self.nonce = nonce; self.ciphertext = ciphertext
    }

    var authenticatedMetadata: Data {
        Data("\(id.uuidString.lowercased())|\(recordType.rawValue)|\(schemaVersion)|\(keyVersion)|\(revision.encoded)|\(deleted)".utf8)
    }
}
