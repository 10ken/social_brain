package com.example.data

import kotlinx.coroutines.flow.Flow

class AppRepository(private val db: AppDatabase) {
    private val personDao = db.personDao()
    private val groupDao = db.groupDao()
    private val relationshipDao = db.relationshipDao()
    private val socialEventDao = db.socialEventDao()
    private val memoryDao = db.memoryDao()
    private val captureDao = db.captureDao()
    private val reminderDao = db.reminderDao()
    private val appSettingsDao = db.appSettingsDao()

    // --- App Settings ---
    val appSettings: Flow<AppSettingsEntity?> = appSettingsDao.getSettings()
    suspend fun saveAppSettings(settings: AppSettingsEntity) = appSettingsDao.insertSettings(settings)

    // --- People ---
    val allPeople: Flow<List<Person>> = personDao.getAllPeople()
    fun getPersonById(id: Int): Flow<Person?> = personDao.getPersonById(id)
    suspend fun getPersonByIdSuspend(id: Int): Person? = personDao.getPersonByIdSuspend(id)
    fun searchPeople(query: String): Flow<List<Person>> = personDao.searchPeople(query)
    suspend fun insertPerson(person: Person): Long = personDao.insertPerson(person)
    suspend fun updatePerson(person: Person) = personDao.updatePerson(person)
    suspend fun deletePerson(person: Person) = personDao.deletePerson(person)
    suspend fun getPersonCount(): Int = personDao.getPersonCount()
    suspend fun getPeopleByIds(ids: List<Int>): List<Person> = personDao.getPeopleByIds(ids)

    // --- Groups ---
    val allGroups: Flow<List<Group>> = groupDao.getAllGroups()
    fun getGroupById(id: Int): Flow<Group?> = groupDao.getGroupById(id)
    suspend fun insertGroup(group: Group): Long = groupDao.insertGroup(group)
    suspend fun updateGroup(group: Group) = groupDao.updateGroup(group)
    suspend fun deleteGroup(group: Group) = groupDao.deleteGroup(group)

    // Group Members
    val allGroupMembers: Flow<List<GroupMemberRef>> = groupDao.getAllGroupMembers()
    fun getGroupMembers(groupId: Int): Flow<List<Person>> = groupDao.getGroupMembers(groupId)
    fun getGroupsForPerson(personId: Int): Flow<List<Group>> = groupDao.getGroupsForPerson(personId)
    suspend fun insertGroupMember(groupId: Int, personId: Int) {
        groupDao.insertGroupMember(GroupMemberRef(groupId, personId))
    }
    suspend fun removeGroupMember(groupId: Int, personId: Int) {
        groupDao.deleteGroupMember(groupId, personId)
    }
    suspend fun deleteMembersByGroupId(groupId: Int) {
        groupDao.deleteMembersByGroupId(groupId)
    }

    // --- Relationships ---
    val allRelationships: Flow<List<Relationship>> = relationshipDao.getAllRelationships()
    fun getRelationshipsForPerson(personId: Int): Flow<List<Relationship>> = relationshipDao.getRelationshipsForPerson(personId)
    suspend fun insertRelationship(relationship: Relationship): Long = relationshipDao.insertRelationship(relationship)
    suspend fun updateRelationship(relationship: Relationship) = relationshipDao.updateRelationship(relationship)
    suspend fun deleteRelationship(relationship: Relationship) = relationshipDao.deleteRelationship(relationship)

    // --- Events ---
    val allEvents: Flow<List<SocialEvent>> = socialEventDao.getAllEvents()
    suspend fun insertEvent(event: SocialEvent, attendeeIds: List<Int> = emptyList()): Long {
        val eventId = socialEventDao.insertEvent(event).toInt()
        attendeeIds.forEach { personId ->
            socialEventDao.insertEventAttendee(EventAttendeeRef(eventId, personId))
        }
        return eventId.toLong()
    }
    suspend fun updateEvent(event: SocialEvent, attendeeIds: List<Int> = emptyList()) {
        socialEventDao.updateEvent(event)
        socialEventDao.deleteEventAttendees(event.id)
        attendeeIds.forEach { personId ->
            socialEventDao.insertEventAttendee(EventAttendeeRef(event.id, personId))
        }
    }
    suspend fun updateEventLocation(eventId: Int, location: String) {
        socialEventDao.updateEventLocation(eventId, location)
    }
    suspend fun deleteEvent(event: SocialEvent) {
        socialEventDao.deleteEventAttendees(event.id)
        socialEventDao.deleteEvent(event)
    }
    fun getEventAttendees(eventId: Int): Flow<List<Person>> = socialEventDao.getEventAttendees(eventId)
    fun getEventsForPerson(personId: Int): Flow<List<SocialEvent>> = socialEventDao.getEventsForPerson(personId)

    // --- Memories ---
    val allMemories: Flow<List<Memory>> = memoryDao.getAllMemories()
    fun getMemoriesForPerson(personId: Int): Flow<List<Memory>> = memoryDao.getMemoriesForPerson(personId)
    fun getMemoriesForGroup(groupId: Int): Flow<List<Memory>> = memoryDao.getMemoriesForGroup(groupId)
    suspend fun insertMemory(memory: Memory): Long = memoryDao.insertMemory(memory)
    suspend fun updateMemory(memory: Memory) = memoryDao.updateMemory(memory)
    suspend fun deleteMemory(memory: Memory) = memoryDao.deleteMemory(memory)

    // --- Captures ---
    val allCaptures: Flow<List<Capture>> = captureDao.getAllCaptures()
    suspend fun insertCapture(capture: Capture): Long = captureDao.insertCapture(capture)
    suspend fun updateCapture(capture: Capture) = captureDao.updateCapture(capture)
    suspend fun deleteCapture(capture: Capture) = captureDao.deleteCapture(capture)

    // --- Reminders ---
    val activeReminders: Flow<List<Reminder>> = reminderDao.getActiveReminders()
    val allReminders: Flow<List<Reminder>> = reminderDao.getAllReminders()
    fun getRemindersForPerson(personId: Int): Flow<List<Reminder>> = reminderDao.getRemindersForPerson(personId)
    suspend fun insertReminder(reminder: Reminder): Long = reminderDao.insertReminder(reminder)
    suspend fun updateReminder(reminder: Reminder) = reminderDao.updateReminder(reminder)
    suspend fun deleteReminder(reminder: Reminder) = reminderDao.deleteReminder(reminder)
}
