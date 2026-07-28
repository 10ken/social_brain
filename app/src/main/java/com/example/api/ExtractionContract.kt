package com.example.api

import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory

/**
 * Android-side guard for the shared v1 extraction contract. The Firebase
 * Function is authoritative, but this keeps cached or future alternate inputs
 * from silently introducing legacy field names or incomplete suggestions.
 */
object ExtractionContract {
    private val moshi = Moshi.Builder()
        .add(KotlinJsonAdapterFactory())
        .build()
    private val adapter = moshi.adapter(ExtractionResult::class.java).failOnUnknown()

    private val confidenceStates = setOf("suggested", "needs_review")
    private val memoryTypes = setOf(
        "life_update", "preference", "relationship", "event_context", "follow_up", "general_note"
    )
    private val relationshipTypes = setOf("spouse", "sibling", "coworker", "friend", "met_through")

    fun parse(json: String): ExtractionResult? = try {
        adapter.fromJson(json)?.takeIf(::isValid)
    } catch (_: Exception) {
        null
    }

    fun isValid(result: ExtractionResult): Boolean =
        result.people.size <= 100 && result.events.size <= 100 && result.memories.size <= 100 &&
            result.relationships.size <= 100 && result.reminders.size <= 100 &&
            result.people.all { it.name.isBounded(300) && it.hasValidSuggestionBase() } &&
            result.events.all {
                it.title.isBounded(500) && it.dateText.isOptionalBounded() &&
                    it.resolvedDate.isOptionalIsoDate() && it.timeText.isOptionalBounded() &&
                    it.location.isOptionalBounded() && it.people.size <= 100 &&
                    it.people.all { name -> name.isBounded(300) } && it.hasValidSuggestionBase()
            } &&
            result.memories.all {
                it.person.isOptionalBounded(300) && it.content.isBounded(10_000) &&
                    it.memoryType in memoryTypes && it.hasValidSuggestionBase()
            } &&
            result.relationships.all {
                it.personA.isBounded(300) && it.personB.isBounded(300) &&
                    it.relationshipType in relationshipTypes && it.hasValidSuggestionBase()
            } &&
            result.reminders.all {
                it.title.isBounded(500) && it.dueText.isOptionalBounded() && it.hasValidSuggestionBase()
            }

    private fun ExtractedPerson.hasValidSuggestionBase() =
        confidenceState in confidenceStates && evidence.isBounded(2_000)

    private fun ExtractedEvent.hasValidSuggestionBase() =
        confidenceState in confidenceStates && evidence.isBounded(2_000)

    private fun ExtractedMemory.hasValidSuggestionBase() =
        confidenceState in confidenceStates && evidence.isBounded(2_000)

    private fun ExtractedRelationship.hasValidSuggestionBase() =
        confidenceState in confidenceStates && evidence.isBounded(2_000)

    private fun ExtractedReminder.hasValidSuggestionBase() =
        confidenceState in confidenceStates && evidence.isBounded(2_000)

    private fun String.isBounded(maxLength: Int) = isNotBlank() && length <= maxLength

    private fun String?.isOptionalBounded(maxLength: Int = 2_000) = this == null || length <= maxLength

    private fun String?.isOptionalIsoDate(): Boolean {
        if (this == null) return true
        return matches(Regex("\\d{4}-\\d{2}-\\d{2}"))
    }
}
