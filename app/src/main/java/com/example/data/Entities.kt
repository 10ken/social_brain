package com.example.data

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.UUID

@Entity(tableName = "people")
data class Person(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val fullName: String,
    val nickname: String? = null,
    val birthday: String? = null, // Store as string "YYYY-MM-DD" or similar
    val location: String? = null,
    val notes: String? = null,
    val phoneNumber: String? = null,
    val email: String? = null,
    val isImported: Boolean = false,
    val contactIdOnDevice: String? = null,
    val isSelf: Boolean = false,
    val sourceId: Int? = null,
    val evidenceText: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val archivedAt: Long? = null,
    val deletedAt: Long? = null,
    val syncId: String = UUID.randomUUID().toString()
)

@Entity(tableName = "groups")
data class Group(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val groupName: String,
    val description: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val archivedAt: Long? = null,
    val deletedAt: Long? = null,
    val syncId: String = UUID.randomUUID().toString()
)

// Many-to-many relationship mapping because multiple people belong to multiple groups
@Entity(tableName = "group_members", primaryKeys = ["groupId", "personId"])
data class GroupMemberRef(
    val groupId: Int,
    val personId: Int,
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val syncId: String = UUID.randomUUID().toString()
)

@Entity(tableName = "relationships")
data class Relationship(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val personAId: Int,
    val personBId: Int,
    val relationshipType: String, // e.g. "spouse", "sibling", "coworker", "friend", "met_through"
    val confidenceState: String = "confirmed", // "confirmed", "suggested", "needs_review"
    val notes: String? = null,
    val sourceId: Int? = null,
    val evidenceText: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val archivedAt: Long? = null,
    val deletedAt: Long? = null,
    val syncId: String = UUID.randomUUID().toString()
)

@Entity(tableName = "social_events")
data class SocialEvent(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val title: String,
    val startTime: Long? = null, // milliseconds epoch
    val endTime: Long? = null, // milliseconds epoch
    val location: String? = null,
    val groupId: Int? = null, // Optional group associated with
    val sourceId: Int? = null, // Optional capture source id
    val evidenceText: String? = null,
    val dateText: String? = null,
    val confidenceState: String = "confirmed", // "confirmed", "suggested", "needs_review"
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val archivedAt: Long? = null,
    val deletedAt: Long? = null,
    val syncId: String = UUID.randomUUID().toString()
)

@Entity(tableName = "event_attendees", primaryKeys = ["eventId", "personId"])
data class EventAttendeeRef(
    val eventId: Int,
    val personId: Int,
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val syncId: String = UUID.randomUUID().toString()
)

@Entity(tableName = "memories")
data class Memory(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val content: String,
    val personId: Int? = null,
    val groupId: Int? = null,
    val eventId: Int? = null,
    val memoryType: String, // "life_update", "preference", "relationship", "event_context", "follow_up", "general_note"
    val sourceId: Int? = null, // Linked capture source id
    val confidenceState: String = "confirmed", // "confirmed", "suggested", "needs_review"
    val evidenceText: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val archivedAt: Long? = null,
    val deletedAt: Long? = null,
    val syncId: String = UUID.randomUUID().toString()
)

@Entity(tableName = "captures")
data class Capture(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val type: String, // "text", "screenshot", "voice"
    val rawContent: String, // original text or OCR text or speech text
    val imageUrl: String? = null, // If screenshot, local path or resource
    val analyzedJson: String? = null, // Extracted parsed suggestions cache (Moshi stringified)
    val processed: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val syncId: String = UUID.randomUUID().toString()
)

@Entity(tableName = "reminders")
data class Reminder(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val title: String,
    val dueDate: Long? = null,
    val completed: Boolean = false,
    val personId: Int? = null,
    val groupId: Int? = null,
    val sourceId: Int? = null,
    val evidenceText: String? = null,
    val confidenceState: String = "confirmed",
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val archivedAt: Long? = null,
    val deletedAt: Long? = null,
    val syncId: String = UUID.randomUUID().toString()
)

@Entity(tableName = "app_settings")
data class AppSettingsEntity(
    @PrimaryKey val id: Int = 1,
    val email: String? = null,
    val phoneNumber: String? = null,
    val themeMode: String = "DARK",
    val timeZone: String = "EST",
    val updatedAt: Long = System.currentTimeMillis(),
    val syncId: String = UUID.randomUUID().toString()
)
