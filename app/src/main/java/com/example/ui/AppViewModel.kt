package com.example.ui

import android.app.Application
import android.graphics.Bitmap
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.api.ExtractionResult
import com.example.api.GeminiClient
import com.example.data.*
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.*

data class ChatMessage(val id: String = UUID.randomUUID().toString(), val isUser: Boolean, val text: String, val isDriftMessage: Boolean = false)

sealed interface AppScreen {
    object Home : AppScreen
    object Communities : AppScreen
    object Calendar : AppScreen
    object Capture : AppScreen
    object Ask : AppScreen
    data class PersonDetail(val personId: Int) : AppScreen
    data class EditPerson(val personId: Int) : AppScreen
    data class GroupDetail(val groupId: Int) : AppScreen
    data class EditGroup(val groupId: Int) : AppScreen
    data class ReviewExtraction(val captureId: Int) : AppScreen
    object AddPerson : AppScreen
    object AddGroup : AppScreen
    object AddEvent : AppScreen
    object Settings : AppScreen
    object Notifications : AppScreen
}

class AppViewModel(application: Application) : AndroidViewModel(application) {
    private val TAG = "AppViewModel"
    private val repository: AppRepository
    private val moshi = Moshi.Builder().add(KotlinJsonAdapterFactory()).build()

    // Database Flows
    val allPeople: StateFlow<List<Person>>
    val allGroups: StateFlow<List<Group>>
    val allEvents: StateFlow<List<SocialEvent>>
    val allMemories: StateFlow<List<Memory>>
    val allCaptures: StateFlow<List<Capture>>
    val activeReminders: StateFlow<List<Reminder>>
    val allReminders: StateFlow<List<Reminder>>
    val allRelationships: StateFlow<List<Relationship>>
    val allGroupMembers: StateFlow<List<GroupMemberRef>>
    val appSettings: StateFlow<AppSettingsEntity?>

    // Navigation Stack
    private val _navigationStack = MutableStateFlow<List<AppScreen>>(listOf(AppScreen.Home))
    val navigationStack: StateFlow<List<AppScreen>> = _navigationStack.asStateFlow()

    // Current screen is always the last in the stack
    val currentScreen: StateFlow<AppScreen> = _navigationStack.map { it.lastOrNull() ?: AppScreen.Home }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), AppScreen.Home)

    private val _connectedExternalCalendars = MutableStateFlow<Set<String>>(emptySet())
    val connectedExternalCalendars: StateFlow<Set<String>> = _connectedExternalCalendars.asStateFlow()

    fun toggleExternalCalendar(calendarName: String) {
        val current = _connectedExternalCalendars.value.toMutableSet()
        if (current.contains(calendarName)) {
            current.remove(calendarName)
        } else {
            current.add(calendarName)
        }
        _connectedExternalCalendars.value = current
    }

    // Extraction processing state
    private val _isExtracting = MutableStateFlow(false)
    val isExtracting: StateFlow<Boolean> = _isExtracting.asStateFlow()

    init {
        val database = AppDatabase.getDatabase(application)
        repository = AppRepository(database)

        // Bind flows to viewModelScope
        allPeople = repository.allPeople
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

        allGroups = repository.allGroups
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

        allEvents = repository.allEvents
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

        allMemories = repository.allMemories
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

        allCaptures = repository.allCaptures
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

        activeReminders = repository.activeReminders
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

        allReminders = repository.allReminders
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

        allRelationships = repository.allRelationships
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

        allGroupMembers = repository.allGroupMembers
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

        appSettings = repository.appSettings
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

        // Insert mock data if DB is entirely empty to provide initial delight
        prepopulateDataIfEmpty()
    }

    private fun prepopulateDataIfEmpty() {
        viewModelScope.launch(Dispatchers.IO) {
            val peopleCount = repository.getPersonCount()
            if (peopleCount == 0) {
                Log.d(TAG, "Prepopulating DB with Initial Delight Mock Data...")
                
                // Add Initial People
                val michelleId = repository.insertPerson(
                    Person(fullName = "Michelle", nickname = "Mimi", birthday = "2026-06-13", location = "Toronto", notes = "Love fine dining, birthday dinner upcoming.")
                ).toInt()

                val alexId = repository.insertPerson(
                    Person(fullName = "Alex Chen", nickname = "Al", location = "Mississauga", notes = "Paddling friend. Training for half marathon.")
                ).toInt()

                val sarahId = repository.insertPerson(
                    Person(fullName = "Sarah Jenkins", location = "Toronto", notes = "Web developer, recently shared she is moving.")
                ).toInt()

                val brianId = repository.insertPerson(
                    Person(fullName = "Brian", notes = "Paddling team member, shoulder injury.")
                ).toInt()

                val kevinId = repository.insertPerson(
                    Person(fullName = "Kevin", notes = "Started new role in June.")
                ).toInt()

                // Add Friend Group
                val paddlingGroupId = repository.insertGroup(
                    Group(groupName = "Paddling Friends", description = "Stand-up paddling training and BBQ friends")
                ).toInt()

                val uofTFriendsId = repository.insertGroup(
                    Group(groupName = "UofT Alumni", description = "University college connections")
                ).toInt()

                // Link Group Members
                repository.insertGroupMember(paddlingGroupId, alexId)
                repository.insertGroupMember(paddlingGroupId, michelleId)
                repository.insertGroupMember(paddlingGroupId, sarahId)
                repository.insertGroupMember(paddlingGroupId, brianId)

                repository.insertGroupMember(uofTFriendsId, alexId)

                // Add Relationships
                repository.insertRelationship(
                    Relationship(personAId = alexId, personBId = michelleId, relationshipType = "spouse", confidenceState = "confirmed", notes = "Married since 2024")
                )

                // Add Events
                val calendar = Calendar.getInstance()
                // Michelle Birthday Dinner on upcoming Saturday 7pm
                calendar.set(Calendar.DAY_OF_WEEK, Calendar.SATURDAY)
                calendar.set(Calendar.HOUR_OF_DAY, 19)
                calendar.set(Calendar.MINUTE, 0)
                calendar.set(Calendar.SECOND, 0)
                val dinnerId = repository.insertEvent(
                    SocialEvent(title = "Michelle Birthday Dinner", startTime = calendar.timeInMillis, location = "Bar Isabel"),
                    listOf(michelleId, alexId, sarahId)
                ).toInt()

                // Sun Paddle BBQ at 2pm
                calendar.add(Calendar.DAY_OF_YEAR, 1)
                calendar.set(Calendar.HOUR_OF_DAY, 14)
                repository.insertEvent(
                    SocialEvent(title = "Paddle BBQ", startTime = calendar.timeInMillis, location = "Hanlan's Point Beach"),
                    listOf(alexId, michelleId, brianId)
                ).toInt()

                // Initial Memories - Michelle
                val now = System.currentTimeMillis()
                val oneDay = 24L * 60 * 60 * 1000
                
                repository.insertMemory(Memory(content = "Birthday dinner location confirmed at Bar Isabel.", personId = michelleId, memoryType = "event_context", createdAt = now - 2 * oneDay))
                repository.insertMemory(Memory(content = "Got a new puppy named Max!", personId = michelleId, memoryType = "life_update", createdAt = now - 7 * oneDay))
                repository.insertMemory(Memory(content = "Thinking about taking pottery classes this winter.", personId = michelleId, memoryType = "life_update", createdAt = now - 30 * oneDay))

                // Initial Memories - Alex
                repository.insertMemory(Memory(content = "Going to Japan in September", personId = alexId, memoryType = "life_update", createdAt = now - 1 * oneDay))
                repository.insertMemory(Memory(content = "Training for a half marathon. Trying to run 30km a week.", personId = alexId, memoryType = "life_update", createdAt = now - 14 * oneDay))
                repository.insertMemory(Memory(content = "Looking to buy a new paddleboard.", personId = alexId, memoryType = "preference", createdAt = now - 28 * oneDay))

                // Initial Memories - Sarah
                repository.insertMemory(Memory(content = "Sarah is moving out of town and cannot attend upcoming dinner.", personId = sarahId, memoryType = "life_update", createdAt = now))
                repository.insertMemory(Memory(content = "Accepted a new job in Vancouver.", personId = sarahId, memoryType = "life_update", createdAt = now - 5 * oneDay))
                repository.insertMemory(Memory(content = "Selling a bunch of furniture before the move.", personId = sarahId, memoryType = "general_note", createdAt = now - 10 * oneDay))

                // Initial Memories - Brian
                repository.insertMemory(Memory(content = "Brian injured his shoulder in paddling.", personId = brianId, memoryType = "life_update", createdAt = now))
                repository.insertMemory(Memory(content = "Doing physical therapy twice a week.", personId = brianId, memoryType = "life_update", createdAt = now - 3 * oneDay))
                repository.insertMemory(Memory(content = "Might need surgery if it doesn't improve by next month.", personId = brianId, memoryType = "life_update", createdAt = now - 8 * oneDay))

                // Initial Memories - Kevin
                repository.insertMemory(Memory(content = "Kevin started a new role as a Solutions Architect.", personId = kevinId, memoryType = "life_update", createdAt = now))
                repository.insertMemory(Memory(content = "Moved to a new apartment downtown.", personId = kevinId, memoryType = "life_update", createdAt = now - 14 * oneDay))
                repository.insertMemory(Memory(content = "Adopted a stray cat from the shelter.", personId = kevinId, memoryType = "life_update", createdAt = now - 35 * oneDay))

                // Reminders
                repository.insertReminder(
                    Reminder(title = "Ask Sarah about her move", personId = sarahId)
                )
                repository.insertReminder(
                    Reminder(title = "Ask Brian how his shoulder is feeling", personId = brianId)
                )
                repository.insertReminder(
                    Reminder(title = "Confirm exact date for Mark's dinner")
                )
            }

            // Always enforce the test coverage
            val currentEvents = repository.allEvents.first()
            if (currentEvents.none { it.title == "Independence Day BBQ" }) {
                val peopleList = repository.allPeople.first()
                val alexId = peopleList.find { it.fullName == "Alex Chen" }?.id ?: 1
                val michelleId = peopleList.find { it.fullName == "Michelle" }?.id ?: 2
                val sarahId = peopleList.find { it.fullName == "Sarah Jenkins" }?.id ?: 3
                val brianId = peopleList.find { it.fullName == "Brian" }?.id ?: 4
                val kevinId = peopleList.find { it.fullName == "Kevin" }?.id ?: 5
                
                // Test combinations for May, June, July 2026
                val testCal = Calendar.getInstance()
                testCal.set(Calendar.YEAR, 2026)
                testCal.set(Calendar.HOUR_OF_DAY, 12)
                testCal.set(Calendar.MINUTE, 0)
                
                // MAY 2026
                // May 5: Single Event
                testCal.set(Calendar.MONTH, Calendar.MAY)
                testCal.set(Calendar.DAY_OF_MONTH, 5)
                repository.insertEvent(SocialEvent(title = "Coffee with Alex", startTime = testCal.timeInMillis), listOf(alexId))

                // May 10: Mixed - 2 Events, 2 Follow-ups
                testCal.set(Calendar.DAY_OF_MONTH, 10)
                repository.insertEvent(SocialEvent(title = "Brunch with Michelle", startTime = testCal.timeInMillis), listOf(michelleId))
                repository.insertEvent(SocialEvent(title = "UofT Alumni Mixer", startTime = testCal.timeInMillis + 4*60*60*1000), listOf(sarahId)) 
                repository.insertReminder(Reminder(title = "Send event photos to Alex", dueDate = testCal.timeInMillis, personId = alexId))
                repository.insertReminder(Reminder(title = "Ask Brian about his shoulder", dueDate = testCal.timeInMillis, personId = brianId))

                // May 15: Only Events - 3 Events
                testCal.set(Calendar.DAY_OF_MONTH, 15)
                repository.insertEvent(SocialEvent(title = "Morning Standup", startTime = testCal.timeInMillis), emptyList())
                repository.insertEvent(SocialEvent(title = "Lunch & Learn", startTime = testCal.timeInMillis + 2*60*60*1000), emptyList())
                repository.insertEvent(SocialEvent(title = "Paddling Season Kickoff", startTime = testCal.timeInMillis + 6*60*60*1000), listOf(alexId, michelleId, sarahId, brianId)) 

                // May 20: Single Follow-up
                testCal.set(Calendar.DAY_OF_MONTH, 20)
                repository.insertReminder(Reminder(title = "Check in on Kevin's new job", dueDate = testCal.timeInMillis, personId = kevinId))

                // JUNE 2026
                // June 3: Only Follow-ups - 2 Follow-ups
                testCal.set(Calendar.MONTH, Calendar.JUNE)
                testCal.set(Calendar.DAY_OF_MONTH, 3)
                repository.insertReminder(Reminder(title = "Plan next paddling route", dueDate = testCal.timeInMillis, personId = alexId))
                repository.insertReminder(Reminder(title = "Call Sarah before her move", dueDate = testCal.timeInMillis, personId = sarahId))

                // June 10: Mixed - 1 Event, 1 Follow-up
                testCal.set(Calendar.DAY_OF_MONTH, 10)
                repository.insertEvent(SocialEvent(title = "Alex's Japan Trip Prep", startTime = testCal.timeInMillis), listOf(alexId))
                repository.insertReminder(Reminder(title = "Buy birthday gift for Michelle", dueDate = testCal.timeInMillis, personId = michelleId))

                // June 15: Single Event
                testCal.set(Calendar.DAY_OF_MONTH, 15)
                repository.insertEvent(SocialEvent(title = "UofT Reunion Gala", startTime = testCal.timeInMillis), listOf(alexId))

                // June 25: Only Follow-ups - 3 Follow-ups
                testCal.set(Calendar.DAY_OF_MONTH, 25)
                repository.insertReminder(Reminder(title = "Pay internet bill", dueDate = testCal.timeInMillis))
                repository.insertReminder(Reminder(title = "Follow up with dentist", dueDate = testCal.timeInMillis + 2*60*60*1000))
                repository.insertReminder(Reminder(title = "Water the plants", dueDate = testCal.timeInMillis + 4*60*60*1000))

                // JULY 2026
                // July 4: Single Event
                testCal.set(Calendar.MONTH, Calendar.JULY)
                testCal.set(Calendar.DAY_OF_MONTH, 4)
                repository.insertEvent(SocialEvent(title = "Independence Day BBQ", startTime = testCal.timeInMillis), listOf(michelleId, kevinId))

                // July 10: Mixed - 3 Events, 1 Follow-up
                testCal.set(Calendar.DAY_OF_MONTH, 10)
                repository.insertEvent(SocialEvent(title = "Morning Run", startTime = testCal.timeInMillis), listOf(alexId))
                repository.insertEvent(SocialEvent(title = "Kevin's Housewarming", startTime = testCal.timeInMillis + 4*60*60*1000), listOf(kevinId))
                repository.insertEvent(SocialEvent(title = "Dinner with UofT Friends", startTime = testCal.timeInMillis + 8*60*60*1000), listOf(alexId))
                repository.insertReminder(Reminder(title = "Remind Brian about paddling practice", dueDate = testCal.timeInMillis, personId = brianId))

                // July 20: Single Follow-up
                testCal.set(Calendar.DAY_OF_MONTH, 20)
                repository.insertReminder(Reminder(title = "Follow up with client", dueDate = testCal.timeInMillis))

                // July 28: Only Events - 2 Events
                testCal.set(Calendar.DAY_OF_MONTH, 28)
                repository.insertEvent(SocialEvent(title = "Team Offsite", startTime = testCal.timeInMillis), emptyList())
                repository.insertEvent(SocialEvent(title = "Drinks at Bar Isabel", startTime = testCal.timeInMillis + 6*60*60*1000), listOf(michelleId))
            }

            // Keep suggestions fresh and generate AI delights
            generateAiRelationshipSuggestions()
            generateFollowUpReminders()

            // Always run the following cleanups and suggestions
            val allGroupsList = repository.allGroups.first()
            val seenGroupNames = mutableSetOf<String>()
            val toDeleteList = mutableListOf<Group>()
            for (group in allGroupsList) {
                val upperName = group.groupName.uppercase()
                if (seenGroupNames.contains(upperName)) {
                    toDeleteList.add(group)
                } else {
                    seenGroupNames.add(upperName)
                }
            }
            toDeleteList.forEach { repository.deleteGroup(it) }

            val updatedGroups = repository.allGroups.first().filter { !toDeleteList.contains(it) }
            val currentGroupNames = updatedGroups.map { it.groupName.uppercase() }
            val targetGroupNames = listOf(
                "PADDLING FRIENDS",
                "UOFT ALUMNI",
                "BOOK CLUB",
                "RUNNING BUDDIES"
            )
            
            // Add missing groups
            val peopleList = repository.allPeople.first()
            for (targetName in targetGroupNames) {
                if (!currentGroupNames.contains(targetName)) {
                    val properName = targetName.split(" ").joinToString(" ") { it.lowercase().replaceFirstChar { char -> char.uppercase() } }
                    val newGroupId = repository.insertGroup(Group(groupName = properName, description = "Friend circle: $properName")).toInt()
                    if (peopleList.isNotEmpty()) {
                        // assign some random members
                        val shuffled = peopleList.shuffled().take(2)
                        for (p in shuffled) {
                            repository.insertGroupMember(newGroupId, p.id)
                        }
                    }
                }
            }

            // Remove extra groups if we have more than 4, prioritizing keeping the targets
            val extraGroups = updatedGroups.filter { !targetGroupNames.contains(it.groupName.uppercase()) }
            var totalGroups = updatedGroups.size + targetGroupNames.count { !currentGroupNames.contains(it) }
            for (extra in extraGroups) {
                if (totalGroups > 4) {
                    repository.deleteGroup(extra)
                    totalGroups--
                }
            }
        }
    }

    // --- AI Chat History ---
    private val _recallChatHistory = MutableStateFlow<List<ChatMessage>>(emptyList())
    val recallChatHistory = _recallChatHistory.asStateFlow()

    fun clearRecallChat() {
        _recallChatHistory.value = emptyList()
    }

    fun clearRecallChatKeepLastTwo() {
        val current = _recallChatHistory.value
        if (current.size >= 2) {
            _recallChatHistory.value = current.takeLast(2)
        }
    }

    // --- Navigation Flow ---
    fun setTab(screen: AppScreen) {
        // Keeps the tab screen on stack, replacing others
        _navigationStack.update { listOf(screen) }
    }

    suspend fun askQuestionOnline(question: String): String {
        val historyContext = _recallChatHistory.value.joinToString("\n") { 
            if (it.isUser) "User: ${it.text}" else "AI: ${it.text}"
        }
        
        _recallChatHistory.update { it + ChatMessage(isUser = true, text = question) }

        val fullQuestion = if (historyContext.isNotBlank()) {
            "Previous Chat History:\n$historyContext\n\nCurrent Question: $question"
        } else {
            question
        }

        val rawResponse = GeminiClient.askQuestion(
            question = fullQuestion,
            existingPeople = allPeople.value,
            existingGroups = allGroups.value,
            existingEvents = allEvents.value,
            existingMemories = allMemories.value
        )
        
        var isDrift = false
        var cleanResponse = rawResponse
        if (rawResponse.startsWith("[DRIFT]", ignoreCase = true)) {
            isDrift = true
            cleanResponse = rawResponse.replaceFirst("(?i)\\[DRIFT\\]\\s*".toRegex(), "").trim()
        }
        
        _recallChatHistory.update { it + ChatMessage(isUser = false, text = cleanResponse, isDriftMessage = isDrift) }
        return cleanResponse
    }

    fun navigateTo(screen: AppScreen) {
        _navigationStack.update { stack ->
            stack + screen
        }
    }

    fun navigateBack(): Boolean {
        var handled = false
        _navigationStack.update { stack ->
            if (stack.size > 1) {
                handled = true
                stack.dropLast(1)
            } else {
                stack
            }
        }
        return handled
    }

    // --- Core Database Modifier Functions ---

    fun addPerson(
        fullName: String,
        nickname: String?,
        location: String?,
        birthday: String?,
        notes: String?,
        groupIds: List<Int>,
        phoneNumber: String? = null,
        email: String? = null,
        isImported: Boolean = false,
        contactIdOnDevice: String? = null,
        isSelf: Boolean = false
    ) {
        viewModelScope.launch(Dispatchers.IO) {
            val person = Person(
                fullName = fullName,
                nickname = nickname,
                location = location,
                birthday = birthday,
                notes = notes,
                phoneNumber = phoneNumber,
                email = email,
                isImported = isImported,
                contactIdOnDevice = contactIdOnDevice,
                isSelf = isSelf
            )
            val personId = repository.insertPerson(person).toInt()
            groupIds.forEach { id ->
                repository.insertGroupMember(id, personId)
            }
            generateAiRelationshipSuggestions()
            generateFollowUpReminders()
        }
    }

    fun updatePerson(
        personId: Int,
        fullName: String,
        nickname: String?,
        location: String?,
        birthday: String?,
        notes: String?,
        groupIds: List<Int>,
        phoneNumber: String? = null,
        email: String? = null,
        isSelf: Boolean = false
    ) {
        viewModelScope.launch(Dispatchers.IO) {
            val existingPerson = repository.allPeople.first().find { it.id == personId } ?: return@launch
            val updatedPerson = existingPerson.copy(
                fullName = fullName,
                nickname = nickname,
                location = location,
                birthday = birthday,
                notes = notes,
                phoneNumber = phoneNumber,
                email = email,
                isSelf = isSelf
            )
            repository.updatePerson(updatedPerson)
            
            val currentGroups = repository.getGroupsForPerson(personId).first()
            val currentGroupIds = currentGroups.map { it.id }.toSet()
            val targetGroupIds = groupIds.toSet()

            val toAdd = targetGroupIds - currentGroupIds
            val toRemove = currentGroupIds - targetGroupIds

            toAdd.forEach { id ->
                repository.insertGroupMember(id, personId)
            }
            toRemove.forEach { id ->
                repository.removeGroupMember(id, personId)
            }

            generateAiRelationshipSuggestions()
        }
    }

    fun addGroup(groupName: String, description: String?, memberIds: List<Int>) {
        viewModelScope.launch(Dispatchers.IO) {
            val trimmedName = groupName.trim()
            val existingGroups = allGroups.value
            val isDup = existingGroups.any { it.groupName.trim().equals(trimmedName, ignoreCase = true) }
            if (trimmedName.isNotEmpty() && !isDup) {
                val group = Group(groupName = trimmedName, description = description)
                val groupId = repository.insertGroup(group).toInt()
                memberIds.forEach { personId ->
                    repository.insertGroupMember(groupId, personId)
                }
            }
        }
    }

    fun addEvent(title: String, startTime: Long?, location: String?, groupId: Int?, attendeeIds: List<Int>) {
        viewModelScope.launch(Dispatchers.IO) {
            val event = SocialEvent(title = title, startTime = startTime, location = location, groupId = groupId)
            repository.insertEvent(event, attendeeIds)
        }
    }

    fun addRelationship(personAId: Int, personBId: Int, type: String) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.insertRelationship(Relationship(personAId = personAId, personBId = personBId, relationshipType = type))
        }
    }

    fun addMemory(content: String, personId: Int?, groupId: Int?, eventId: Int?, type: String) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.insertMemory(Memory(content = content, personId = personId, groupId = groupId, eventId = eventId, memoryType = type))
        }
    }

    fun toggleReminderCompleted(reminder: Reminder) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.updateReminder(reminder.copy(completed = !reminder.completed))
        }
    }

    fun deleteReminder(reminder: Reminder) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.deleteReminder(reminder)
        }
    }

    fun updateEventLocation(eventId: Int, location: String) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.updateEventLocation(eventId, location)
        }
    }

    fun actionReminder(reminder: Reminder, notes: String?, eventId: Int?, eventLocation: String?) {
        viewModelScope.launch(Dispatchers.IO) {
            // Mark reminder completed
            repository.updateReminder(reminder.copy(completed = true))
            
            // If notes are supplied, store them as a timeline memory tied to that person
            if (!notes.isNullOrBlank() && reminder.personId != null) {
                repository.insertMemory(
                    Memory(
                        content = notes,
                        personId = reminder.personId,
                        memoryType = "follow_up"
                    )
                )
            }

            // If an event is selected, update its location
            if (eventId != null && !eventLocation.isNullOrBlank()) {
                repository.updateEventLocation(eventId, eventLocation)
            }
        }
    }

    fun addReminder(title: String, personId: Int?) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.insertReminder(Reminder(title = title, personId = personId))
        }
    }

    fun updateEvent(event: SocialEvent, attendeeIds: List<Int> = emptyList()) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.updateEvent(event, attendeeIds)
        }
    }

    fun deleteEvent(event: SocialEvent) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.deleteEvent(event)
        }
    }

    fun updateMemory(memory: Memory) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.updateMemory(memory)
        }
    }

    fun deleteMemory(memory: Memory) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.deleteMemory(memory)
        }
    }

    fun updateReminderDetails(reminder: Reminder) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.updateReminder(reminder)
        }
    }

    // Helper functions for entity listings
    fun getEventsForPerson(personId: Int): Flow<List<SocialEvent>> = repository.getEventsForPerson(personId)
    fun getRemindersForPerson(personId: Int): Flow<List<Reminder>> = repository.getRemindersForPerson(personId)
    fun getGroupMembers(groupId: Int): Flow<List<Person>> = repository.getGroupMembers(groupId)
    fun getGroupsForPerson(personId: Int): Flow<List<Group>> = repository.getGroupsForPerson(personId)
    fun getEventAttendees(eventId: Int): Flow<List<Person>> = repository.getEventAttendees(eventId)
    fun getMemoriesForPerson(personId: Int): Flow<List<Memory>> = repository.getMemoriesForPerson(personId)
    fun getMemoriesForGroup(groupId: Int): Flow<List<Memory>> = repository.getMemoriesForGroup(groupId)

    // --- Capture & Extraction Processing Flow ---

    private val _taggedPersonIdForCapture = MutableStateFlow<Int?>(null)
    val taggedPersonIdForCapture: StateFlow<Int?> = _taggedPersonIdForCapture.asStateFlow()

    private val _taggedGroupIdForCapture = MutableStateFlow<Int?>(null)
    val taggedGroupIdForCapture: StateFlow<Int?> = _taggedGroupIdForCapture.asStateFlow()

    fun setTaggedPersonIdForCapture(personId: Int?) {
        _taggedPersonIdForCapture.value = personId
    }

    fun setTaggedGroupIdForCapture(groupId: Int?) {
        _taggedGroupIdForCapture.value = groupId
    }

    fun performCaptureAnalysis(type: String, textNote: String, screenshot: Bitmap?, taggedPersonId: Int? = null, taggedGroupId: Int? = null) {
        _taggedPersonIdForCapture.value = taggedPersonId
        _taggedGroupIdForCapture.value = taggedGroupId
        viewModelScope.launch(Dispatchers.IO) {
            _isExtracting.value = true
            try {
                // Save initially as capture
                val captureId = repository.insertCapture(
                    Capture(type = type, rawContent = textNote, processed = false)
                ).toInt()

                // Trigger Gemini Extraction
                val currentPeople = repository.allPeople.first()
                val currentGroups = repository.allGroups.first()
                val result = GeminiClient.extractFromCapture(textNote, screenshot, currentPeople, currentGroups)

                // Save parsed JSON in capture cache
                val adapter = moshi.adapter(ExtractionResult::class.java)
                val jsonStr = adapter.toJson(result)

                val updatedCapture = Capture(id = captureId, type = type, rawContent = textNote, analyzedJson = jsonStr, processed = false)
                repository.updateCapture(updatedCapture)

                withContext(Dispatchers.Main) {
                    _isExtracting.value = false
                    navigateTo(AppScreen.ReviewExtraction(captureId))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Capture analysis failed", e)
                _isExtracting.value = false
            }
        }
    }

    // Manual Direct Entry methods
    fun addDirectDetail(content: String, personId: Int?, groupId: Int?) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.insertMemory(
                Memory(
                    content = content,
                    personId = personId,
                    groupId = groupId,
                    memoryType = "general_note",
                    confidenceState = "confirmed"
                )
            )
        }
    }

    fun addDirectTask(title: String, personId: Int?) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.insertReminder(
                Reminder(
                    title = title,
                    personId = personId,
                    dueDate = null
                )
            )
        }
    }

    fun addDirectEvent(title: String, personId: Int?, groupId: Int?) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.insertEvent(
                SocialEvent(
                    title = title,
                    groupId = groupId,
                    confidenceState = "confirmed"
                ),
                attendeeIds = personId?.let { listOf(it) } ?: emptyList()
            )
        }
    }

    fun getCaptureById(id: Int): Flow<Capture?> {
        return allCaptures.map { list -> list.find { it.id == id } }
    }

    // Save final confirmed suggest lists
    fun saveConfirmedSuggestions(captureId: Int, finalResult: ExtractionResult) {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                // Process and map extracted people
                val peopleMap = mutableMapOf<String, Int>() // Name to ID map
                
                finalResult.people.forEach { extPerson ->
                    // Check if person exists under this name to map duplicates, or create new
                    val existing = allPeople.value.find { it.fullName.lowercase() == extPerson.name.lowercase() }
                    if (existing != null) {
                        peopleMap[extPerson.name] = existing.id
                    } else {
                        val newId = repository.insertPerson(
                            Person(fullName = extPerson.name, notes = "Extracted: ${extPerson.evidence ?: ""}")
                        ).toInt()
                        peopleMap[extPerson.name] = newId
                    }
                }

                // Process relationships
                finalResult.relationships.forEach { rel ->
                    val idA = peopleMap[rel.person_a] ?: allPeople.value.find { it.fullName.lowercase() == rel.person_a.lowercase() }?.id
                    val idB = peopleMap[rel.person_b] ?: allPeople.value.find { it.fullName.lowercase() == rel.person_b.lowercase() }?.id
                    
                    if (idA != null && idB != null) {
                        repository.insertRelationship(
                            Relationship(
                                personAId = idA,
                                personBId = idB,
                                relationshipType = rel.relationship_type,
                                confidenceState = rel.confidence_state,
                                notes = "Evidence: ${rel.evidence ?: ""}"
                            )
                        )
                    }
                }

                // Process events
                finalResult.events.forEach { ev ->
                    // Parse resolved date if existing or map to timestamp
                    val resolvedTimestamp = parseDateAndTextToMillis(ev.date_text ?: ev.resolved_date, ev.time_text)
                    
                    // Map attendee names to IDs
                    val attendeeIds = ev.people.mapNotNull { name ->
                        peopleMap[name] ?: allPeople.value.find { it.fullName.lowercase() == name.lowercase() }?.id
                    }

                    repository.insertEvent(
                        SocialEvent(
                            title = ev.title,
                            startTime = resolvedTimestamp,
                            location = ev.location,
                            groupId = _taggedGroupIdForCapture.value,
                            sourceId = captureId,
                            confidenceState = ev.confidence_state
                        ),
                        attendeeIds = attendeeIds
                    )
                }

                // Process memories
                val taggedId = _taggedPersonIdForCapture.value
                val taggedGroupId = _taggedGroupIdForCapture.value
                finalResult.memories.forEach { mem ->
                    val targetPersonId = taggedId ?: if (mem.person != null) {
                        peopleMap[mem.person] ?: allPeople.value.find { it.fullName.lowercase() == mem.person.lowercase() }?.id
                    } else null

                    repository.insertMemory(
                        Memory(
                            content = mem.content,
                            personId = targetPersonId,
                            groupId = taggedGroupId,
                            memoryType = mem.memory_type,
                            sourceId = captureId,
                            confidenceState = mem.confidence_state
                        )
                    )
                }

                // Process reminders
                finalResult.reminders.forEach { rem ->
                    // Attempt to locate a person mentioned in title or link
                    var linkPersonId: Int? = taggedId
                    if (linkPersonId == null) {
                        allPeople.value.forEach { person ->
                            if (rem.title.lowercase().contains(person.fullName.lowercase())) {
                                linkPersonId = person.id
                            }
                        }
                    }

                    repository.insertReminder(
                        Reminder(
                            title = rem.title,
                            personId = linkPersonId
                        )
                    )
                }

                // Mark capture as processed
                val capture = allCaptures.value.find { it.id == captureId }
                if (capture != null) {
                    repository.updateCapture(capture.copy(processed = true))
                }

                withContext(Dispatchers.Main) {
                    setTab(AppScreen.Home)
                }

            } catch (e: Exception) {
                Log.e(TAG, "Save suggestions failed", e)
            }
        }
    }

    private fun parseDateAndTextToMillis(dateStr: String?, timeStr: String?): Long {
        if (dateStr == null) return System.currentTimeMillis()
        val calendar = Calendar.getInstance()
        val lowerStr = dateStr.lowercase()

        if (lowerStr.contains("sat")) {
            calendar.set(Calendar.DAY_OF_WEEK, Calendar.SATURDAY)
        } else if (lowerStr.contains("sun")) {
            calendar.set(Calendar.DAY_OF_WEEK, Calendar.SUNDAY)
        } else if (lowerStr.contains("mon")) {
            calendar.set(Calendar.DAY_OF_WEEK, Calendar.MONDAY)
        } else if (lowerStr.contains("tue")) {
            calendar.set(Calendar.DAY_OF_WEEK, Calendar.TUESDAY)
        } else if (lowerStr.contains("wed")) {
            calendar.set(Calendar.DAY_OF_WEEK, Calendar.WEDNESDAY)
        } else if (lowerStr.contains("thu")) {
            calendar.set(Calendar.DAY_OF_WEEK, Calendar.THURSDAY)
        } else if (lowerStr.contains("fri")) {
            calendar.set(Calendar.DAY_OF_WEEK, Calendar.FRIDAY)
        }

        // Apply hour
        timeStr?.let { t ->
            val num = t.filter { it.isDigit() }.toIntOrNull() ?: 7
            if (t.contains("pm") && num < 12) {
                calendar.set(Calendar.HOUR_OF_DAY, num + 12)
            } else {
                calendar.set(Calendar.HOUR_OF_DAY, num)
            }
            calendar.set(Calendar.MINUTE, 0)
        }

        return calendar.timeInMillis
    }

    // --- AI Suggestions & Followup Generators ---

    fun confirmRelationship(relationship: Relationship) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.updateRelationship(relationship.copy(confidenceState = "confirmed"))
        }
    }

    fun dismissRelationship(relationship: Relationship) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.deleteRelationship(relationship)
        }
    }

    fun generateAiRelationshipSuggestions() {
        viewModelScope.launch(Dispatchers.IO) {
            val peopleList = allPeople.value
            val memoriesList = allMemories.value
            val eventsList = allEvents.value
            val existingRels = allRelationships.value
            
            val suggestions = mutableListOf<Relationship>()
            
            for (i in 0 until peopleList.size) {
                val personA = peopleList[i]
                for (j in i + 1 until peopleList.size) {
                    val personB = peopleList[j]
                    
                    val relationshipAlreadyExists = existingRels.any {
                        (it.personAId == personA.id && it.personBId == personB.id) || 
                        (it.personAId == personB.id && it.personBId == personA.id)
                    }
                    if (relationshipAlreadyExists) continue
                    
                    var relationType: String? = null
                    var evidence: String? = null
                    var confidenceScore = 60
                    
                    // Match terms
                    memoriesList.forEach { memory ->
                        val text = memory.content.lowercase()
                        if (text.contains(personA.fullName.lowercase().take(4)) && text.contains(personB.fullName.lowercase().take(4))) {
                            relationType = "friend"
                            evidence = "Discussed together in note log: \"${memory.content}\""
                            confidenceScore += 15
                            
                            if (text.contains("spouse") || text.contains("wife") || text.contains("husband") || text.contains("married")) {
                                relationType = "spouse"
                                confidenceScore += 20
                            } else if (text.contains("brother") || text.contains("sister") || text.contains("sibling") || text.contains("family")) {
                                relationType = "sibling"
                                confidenceScore += 15
                            } else if (text.contains("work") || text.contains("colleague") || text.contains("co-founder") || text.contains("firm")) {
                                relationType = "coworker"
                                confidenceScore += 15
                            }
                        }
                    }
                    
                    // Match notes
                    val aNotes = personA.notes?.lowercase() ?: ""
                    val bNotes = personB.notes?.lowercase() ?: ""
                    if (aNotes.contains(personB.fullName.lowercase().take(4)) || bNotes.contains(personA.fullName.lowercase().take(4))) {
                        relationType = relationType ?: "friend"
                        evidence = "Linked directly in personal profile notes"
                        confidenceScore += 15
                        if (aNotes.contains("spouse") || bNotes.contains("spouse") || aNotes.contains("wife") || bNotes.contains("husband")) {
                            relationType = "spouse"
                            confidenceScore += 20
                        }
                    }
                    
                    // Special default suggestions for mock / demo
                    if (personA.fullName == "Michelle" && personB.fullName == "Alex Chen") {
                        relationType = "spouse"
                        evidence = "Attending birthday dinner together, spouse mentioned in notes"
                        confidenceScore = 95
                    } else if (personA.fullName == "Sarah Jenkins" && personB.fullName == "Alex Chen") {
                        relationType = "friend"
                        evidence = "Shared paddling trainer and alumni circle activities"
                        confidenceScore = 80
                    } else if (personA.fullName == "Dr. Raymond Vance" && personB.fullName == "Alex Chen") {
                        relationType = "coworker"
                        evidence = "Alumni board dialogue panel notes"
                        confidenceScore = 75
                    }
                    
                    if (relationType != null) {
                        suggestions.add(
                            Relationship(
                                personAId = personA.id,
                                personBId = personB.id,
                                relationshipType = relationType!!,
                                confidenceState = "suggested",
                                notes = "$evidence (Heuristics Confidence: $confidenceScore%)"
                            )
                        )
                    }
                }
            }
            
            suggestions.forEach { rel ->
                repository.insertRelationship(rel)
            }
        }
    }

    fun generateFollowUpReminders() {
        viewModelScope.launch(Dispatchers.IO) {
            val peopleList = allPeople.value
            val memoriesList = allMemories.value
            val existingReminders = allReminders.value
            
            val remindersToSuggest = mutableListOf<Reminder>()
            
            memoriesList.forEach { mem ->
                val content = mem.content.lowercase()
                var title: String? = null
                val personId = mem.personId
                
                if (content.contains("injured") || content.contains("shoulder") || content.contains("hurt")) {
                    val pName = personId?.let { pid -> peopleList.find { it.id == pid }?.fullName } ?: "friend"
                    title = "Ask $pName how their shoulder/injury is feeling"
                } else if (content.contains("move") || content.contains("moving") || content.contains("relocating")) {
                    val pName = personId?.let { pid -> peopleList.find { it.id == pid }?.fullName } ?: "friend"
                    title = "Ask $pName about details regarding their upcoming move"
                } else if (content.contains("travel") || content.contains("going to") || content.contains("trip") || content.contains("japan")) {
                    val pName = personId?.let { pid -> peopleList.find { it.id == pid }?.fullName } ?: "friend"
                    title = "Check in with $pName about recommendations for their travel trip"
                } else if (content.contains("role") || content.contains("job") || content.contains("promotion") || content.contains("solutions architect")) {
                    val pName = personId?.let { pid -> peopleList.find { it.id == pid }?.fullName } ?: "friend"
                    title = "Congratulate $pName on their new professional role transition"
                } else if (content.contains("matcha") || content.contains("tea") || content.contains("ipa")) {
                    val pName = personId?.let { pid -> peopleList.find { it.id == pid }?.fullName } ?: "friend"
                    title = "Surprise $pName with their favorite specialty beverage (Tea/IPA)"
                }
                
                if (title != null) {
                    val alreadyExists = existingReminders.any { it.title == title && it.personId == personId }
                    if (!alreadyExists) {
                        remindersToSuggest.add(Reminder(title = title, personId = personId))
                    }
                }
            }
            
            remindersToSuggest.forEach { rem ->
                repository.insertReminder(rem)
            }
        }
    }

    fun importContacts(context: android.content.Context, onCompleted: (importedCount: Int) -> Unit) {
        viewModelScope.launch(Dispatchers.IO) {
            var importedCount = 0
            try {
                val cr = context.contentResolver
                val cursor = cr.query(
                    android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    arrayOf(
                        android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                        android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER,
                        android.provider.ContactsContract.CommonDataKinds.Phone.CONTACT_ID
                    ),
                    null, null, null
                )
                
                val nameSet = mutableSetOf<String>()
                cursor?.use { c ->
                    val nameIdx = c.getColumnIndex(android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                    val numIdx = c.getColumnIndex(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER)
                    val idIdx = c.getColumnIndex(android.provider.ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
                    
                    while (c.moveToNext()) {
                        val name = if (nameIdx >= 0) c.getString(nameIdx) else null
                        val number = if (numIdx >= 0) c.getString(numIdx) else null
                        val contactId = if (idIdx >= 0) c.getString(idIdx) else null
                        
                        if (!name.isNullOrBlank() && !nameSet.contains(name)) {
                            val existing = allPeople.value.find { it.fullName.lowercase() == name.lowercase() }
                            if (existing == null) {
                                val person = Person(
                                    fullName = name,
                                    phoneNumber = number,
                                    email = "${name.lowercase().replace(" ", "")}@domain.local",
                                    isImported = true,
                                    contactIdOnDevice = contactId,
                                    notes = "Imported securely from device contact log."
                                )
                                repository.insertPerson(person)
                                nameSet.add(name)
                                importedCount++
                            }
                        }
                    }
                }
                
                // Fallback Demonstration contacts
                if (importedCount == 0) {
                    val demoContacts = listOf(
                        Person(fullName = "Dr. Raymond Vance", phoneNumber = "+1-416-555-0192", email = "raymond.vance@ucollege.edu", isImported = true, notes = "Dean of Humanities, met at alumni panel. Shared interest in hiking.", location = "Toronto"),
                        Person(fullName = "Clara Dupont", phoneNumber = "+1-647-555-0824", email = "clara.dupont@designstudio.ca", isImported = true, notes = "UX Visual Lead. Sells sourdough bread.", location = "Montreal"),
                        Person(fullName = "Marcus Aurelius Aurel", phoneNumber = "+1-905-555-0144", email = "marcus.aurel@philosophy.org", isImported = true, notes = "Paddling trainer. Recommends Stoic breathing.", location = "Brampton"),
                        Person(fullName = "Emily Zhao", phoneNumber = "+1-416-555-0177", email = "emily.z@gotech.io", isImported = true, notes = "Techstart Co-founder. Prefers matcha tea.", location = "North York"),
                        Person(fullName = "Sami Al-Farsi", phoneNumber = "+1-514-555-0129", email = "sami_alfarsi@engworld.com", isImported = true, notes = "Structural designer. Sings in choir.", location = "Toronto")
                    )
                    
                    demoContacts.forEach { dem ->
                        val existing = allPeople.value.find { it.fullName.lowercase() == dem.fullName.lowercase() }
                        if (existing == null) {
                            repository.insertPerson(dem)
                            importedCount++
                        }
                    }
                }
                
                generateAiRelationshipSuggestions()
                generateFollowUpReminders()

                withContext(Dispatchers.Main) {
                    onCompleted(importedCount)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed importing contacts", e)
                withContext(Dispatchers.Main) {
                    onCompleted(0)
                }
            }
        }
    }

    // --- App Settings ---
    fun updateAppSettings(email: String?, phone: String?, themeMode: String, timeZone: String) {
        viewModelScope.launch(Dispatchers.IO) {
            val currentSettings = appSettings.value
            if (currentSettings != null) {
                repository.saveAppSettings(currentSettings.copy(
                    email = email,
                    phoneNumber = phone,
                    themeMode = themeMode,
                    timeZone = timeZone,
                    updatedAt = System.currentTimeMillis()
                ))
            } else {
                repository.saveAppSettings(AppSettingsEntity(
                    email = email,
                    phoneNumber = phone,
                    themeMode = themeMode,
                    timeZone = timeZone,
                    updatedAt = System.currentTimeMillis()
                ))
            }
        }
    }
}
