package com.example.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface PersonDao {
    @Query("SELECT * FROM people ORDER BY fullName ASC")
    fun getAllPeople(): Flow<List<Person>>

    @Query("SELECT * FROM people WHERE id = :id")
    fun getPersonById(id: Int): Flow<Person?>

    @Query("SELECT * FROM people WHERE id = :id")
    suspend fun getPersonByIdSuspend(id: Int): Person?

    @Query("SELECT * FROM people WHERE fullName LIKE '%' || :query || '%' OR nickname LIKE '%' || :query || '%'")
    fun searchPeople(query: String): Flow<List<Person>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPerson(person: Person): Long

    @Update
    suspend fun updatePerson(person: Person)

    @Delete
    suspend fun deletePerson(person: Person)

    @Query("SELECT COUNT(*) FROM people")
    suspend fun getPersonCount(): Int

    @Query("SELECT * FROM people WHERE id IN (:ids)")
    suspend fun getPeopleByIds(ids: List<Int>): List<Person>
}

@Dao
interface GroupDao {
    @Query("SELECT * FROM groups ORDER BY groupName ASC")
    fun getAllGroups(): Flow<List<Group>>

    @Query("SELECT * FROM groups WHERE id = :id")
    fun getGroupById(id: Int): Flow<Group?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertGroup(group: Group): Long

    @Update
    suspend fun updateGroup(group: Group)

    @Delete
    suspend fun deleteGroup(group: Group)

    // Group Members Join Table Operations
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertGroupMember(member: GroupMemberRef)

    @Query("DELETE FROM group_members WHERE groupId = :groupId AND personId = :personId")
    suspend fun deleteGroupMember(groupId: Int, personId: Int)

    @Query("DELETE FROM group_members WHERE groupId = :groupId")
    suspend fun deleteMembersByGroupId(groupId: Int)

    @RewriteQueriesToDropUnusedColumns
    @Query("SELECT * FROM people INNER JOIN group_members ON people.id = group_members.personId WHERE group_members.groupId = :groupId")
    fun getGroupMembers(groupId: Int): Flow<List<Person>>

    @RewriteQueriesToDropUnusedColumns
    @Query("SELECT * FROM groups INNER JOIN group_members ON groups.id = group_members.groupId WHERE group_members.personId = :personId")
    fun getGroupsForPerson(personId: Int): Flow<List<Group>>

    @Query("SELECT * FROM group_members")
    fun getAllGroupMembers(): Flow<List<GroupMemberRef>>
}

@Dao
interface RelationshipDao {
    @Query("SELECT * FROM relationships ORDER BY createdAt DESC")
    fun getAllRelationships(): Flow<List<Relationship>>

    @Query("SELECT * FROM relationships WHERE personAId = :personId OR personBId = :personId")
    fun getRelationshipsForPerson(personId: Int): Flow<List<Relationship>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertRelationship(relationship: Relationship): Long

    @Update
    suspend fun updateRelationship(relationship: Relationship)

    @Delete
    suspend fun deleteRelationship(relationship: Relationship)
}

@Dao
interface SocialEventDao {
    @Query("SELECT * FROM social_events ORDER BY startTime ASC")
    fun getAllEvents(): Flow<List<SocialEvent>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertEvent(event: SocialEvent): Long

    @Update
    suspend fun updateEvent(event: SocialEvent)

    @Query("UPDATE social_events SET location = :location WHERE id = :eventId")
    suspend fun updateEventLocation(eventId: Int, location: String)

    @Delete
    suspend fun deleteEvent(event: SocialEvent)

    // Event Attendees Join Table Operations
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertEventAttendee(ref: EventAttendeeRef)

    @Query("DELETE FROM event_attendees WHERE eventId = :eventId")
    suspend fun deleteEventAttendees(eventId: Int)

    @RewriteQueriesToDropUnusedColumns
    @Query("SELECT * FROM people INNER JOIN event_attendees ON people.id = event_attendees.personId WHERE event_attendees.eventId = :eventId")
    fun getEventAttendees(eventId: Int): Flow<List<Person>>

    @RewriteQueriesToDropUnusedColumns
    @Query("SELECT * FROM social_events INNER JOIN event_attendees ON social_events.id = event_attendees.eventId WHERE event_attendees.personId = :personId")
    fun getEventsForPerson(personId: Int): Flow<List<SocialEvent>>
}

@Dao
interface MemoryDao {
    @Query("SELECT * FROM memories ORDER BY createdAt DESC")
    fun getAllMemories(): Flow<List<Memory>>

    @Query("SELECT * FROM memories WHERE personId = :personId ORDER BY createdAt DESC")
    fun getMemoriesForPerson(personId: Int): Flow<List<Memory>>

    @Query("SELECT * FROM memories WHERE groupId = :groupId ORDER BY createdAt DESC")
    fun getMemoriesForGroup(groupId: Int): Flow<List<Memory>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMemory(memory: Memory): Long

    @Update
    suspend fun updateMemory(memory: Memory)

    @Delete
    suspend fun deleteMemory(memory: Memory)
}

@Dao
interface CaptureDao {
    @Query("SELECT * FROM captures ORDER BY createdAt DESC")
    fun getAllCaptures(): Flow<List<Capture>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCapture(capture: Capture): Long

    @Update
    suspend fun updateCapture(capture: Capture)

    @Delete
    suspend fun deleteCapture(capture: Capture)
}

@Dao
interface ReminderDao {
    @Query("SELECT * FROM reminders WHERE completed = 0 ORDER BY dueDate ASC")
    fun getActiveReminders(): Flow<List<Reminder>>

    @Query("SELECT * FROM reminders ORDER BY createdAt DESC")
    fun getAllReminders(): Flow<List<Reminder>>

    @Query("SELECT * FROM reminders WHERE personId = :personId ORDER BY createdAt DESC")
    fun getRemindersForPerson(personId: Int): Flow<List<Reminder>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertReminder(reminder: Reminder): Long

    @Update
    suspend fun updateReminder(reminder: Reminder)

    @Delete
    suspend fun deleteReminder(reminder: Reminder)
}

@Dao
interface AppSettingsDao {
    @Query("SELECT * FROM app_settings WHERE id = 1")
    fun getSettings(): Flow<AppSettingsEntity?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSettings(settings: AppSettingsEntity)
}
