package com.example.sync

import java.util.UUID

/** Metadata is intentionally the only data sent to Firestore in plaintext. */
enum class RecordType {
    PERSON, GROUP, GROUP_MEMBERSHIP, RELATIONSHIP, EVENT, EVENT_ATTENDEE,
    MEMORY, CAPTURE, REMINDER, SETTINGS
}

data class HybridRevision(
    val counter: Long,
    val deviceId: String
) : Comparable<HybridRevision> {
    init {
        require(counter >= 0) { "Revision counter must be non-negative" }
        require(runCatching { UUID.fromString(deviceId) }.isSuccess) { "deviceId must be a UUID" }
    }

    override fun compareTo(other: HybridRevision): Int =
        compareValuesBy(this, other, HybridRevision::counter, HybridRevision::deviceId)

    override fun toString(): String = "$counter:$deviceId"

    companion object {
        fun parse(value: String): HybridRevision {
            val separator = value.indexOf(':')
            require(separator > 0) { "Invalid revision" }
            return HybridRevision(value.substring(0, separator).toLong(), value.substring(separator + 1))
        }
    }
}

data class EncryptedRecordEnvelope(
    val id: String,
    val recordType: RecordType,
    val schemaVersion: Int = 1,
    val keyVersion: Int,
    val revision: HybridRevision,
    val deviceId: String,
    val updatedAtMs: Long,
    val deleted: Boolean,
    val deletedAtMs: Long? = null,
    val nonceBase64: String,
    val ciphertextBase64: String
) {
    init {
        require(runCatching { UUID.fromString(id) }.isSuccess) { "id must be a UUID" }
        require(schemaVersion == 1) { "Unsupported envelope schema" }
        require(keyVersion > 0) { "keyVersion must be positive" }
        require(updatedAtMs >= 0) { "updatedAtMs must be non-negative" }
        require(!deleted || deletedAtMs != null) { "Tombstones require a deletion timestamp" }
    }
}
