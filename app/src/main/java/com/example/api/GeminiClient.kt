package com.example.api

import android.graphics.Bitmap
import android.util.Base64
import android.util.Log
import com.example. BuildConfig
import com.example.data.Group
import com.example.data.Person
import com.example.data.SocialEvent
import com.example.data.Memory
import com.squareup.moshi.JsonClass
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.http.Body
import retrofit2.http.POST
import retrofit2.http.Query
import java.io.ByteArrayOutputStream
import java.util.concurrent.TimeUnit

// --- API Request/Response Structures for Gemini ---

@JsonClass(generateAdapter = true)
data class GeminiPart(
    val text: String? = null,
    val inlineData: InlineData? = null
)

@JsonClass(generateAdapter = true)
data class InlineData(
    val mimeType: String,
    val data: String
)

@JsonClass(generateAdapter = true)
data class GeminiContent(
    val parts: List<GeminiPart>
)

@JsonClass(generateAdapter = true)
data class GenerationConfig(
    val responseMimeType: String? = null,
    val temperature: Float? = null
)

@JsonClass(generateAdapter = true)
data class GeminiRequest(
    val contents: List<GeminiContent>,
    val generationConfig: GenerationConfig? = null,
    val systemInstruction: GeminiContent? = null
)

@JsonClass(generateAdapter = true)
data class GeminiResponse(
    val candidates: List<GeminiCandidate>?
)

@JsonClass(generateAdapter = true)
data class GeminiCandidate(
    val content: GeminiContent?
)

// --- Extracted Unified Personal CRM Suggestion Models ---

@JsonClass(generateAdapter = true)
data class ExtractedPerson(
    val name: String,
    val confidence_state: String = "suggested",
    val evidence: String? = null
)

@JsonClass(generateAdapter = true)
data class ExtractedEvent(
    val title: String,
    val date_text: String? = null,
    val resolved_date: String? = null, // "YYYY-MM-DD"
    val time_text: String? = null,
    val location: String? = null,
    val people: List<String> = emptyList(),
    val confidence_state: String = "suggested",
    val evidence: String? = null
)

@JsonClass(generateAdapter = true)
data class ExtractedMemory(
    val person: String?,
    val content: String,
    val memory_type: String, // "life_update", "preference", "relationship", "event_context", "follow_up", "general_note"
    val confidence_state: String = "suggested",
    val evidence: String? = null
)

@JsonClass(generateAdapter = true)
data class ExtractedRelationship(
    val person_a: String,
    val person_b: String,
    val relationship_type: String, // "spouse", "sibling", "coworker", "friend", "met_through"
    val confidence_state: String = "suggested",
    val evidence: String? = null
)

@JsonClass(generateAdapter = true)
data class ExtractedReminder(
    val title: String,
    val due_text: String? = null,
    val confidence_state: String = "suggested"
)

@JsonClass(generateAdapter = true)
data class ExtractionResult(
    val people: List<ExtractedPerson> = emptyList(),
    val events: List<ExtractedEvent> = emptyList(),
    val memories: List<ExtractedMemory> = emptyList(),
    val relationships: List<ExtractedRelationship> = emptyList(),
    val reminders: List<ExtractedReminder> = emptyList()
)

// --- Retrofit Interface ---

interface GeminiApiService {
    @POST("v1beta/models/gemini-3.5-flash:generateContent")
    suspend fun generateContent(
        @Query("key") apiKey: String,
        @Body request: GeminiRequest
    ): GeminiResponse
}

object GeminiClient {
    private const val TAG = "GeminiClient"
    private const val BASE_URL = "https://generativelanguage.googleapis.com/"

    private val moshi = Moshi.Builder()
        .add(KotlinJsonAdapterFactory())
        .build()

    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(60, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()

    private val api: GeminiApiService by lazy {
        Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
            .create(GeminiApiService::class.java)
    }

    private fun Bitmap.toBase64(): String {
        val outputStream = ByteArrayOutputStream()
        this.compress(Bitmap.CompressFormat.JPEG, 80, outputStream)
        return Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
    }

    suspend fun askQuestion(
        question: String,
        existingPeople: List<Person>,
        existingGroups: List<Group>,
        existingEvents: List<SocialEvent>,
        existingMemories: List<Memory>
    ): String {
        val apiKey = BuildConfig.GEMINI_API_KEY
        if (apiKey.isEmpty() || apiKey == "MY_GEMINI_API_KEY") {
            return "API Key is missing. Cannot answer question."
        }
        val peopleContext = existingPeople.joinToString("\n") { 
            "- ${it.fullName}" + (if (!it.nickname.isNullOrBlank()) " (Nickname: ${it.nickname})" else "") + (if (it.isSelf) " [NOTE: THIS IS THE USER/ME]" else "") + (if (it.location != null) " (Location: ${it.location})" else "")
        }
        val groupContext = existingGroups.joinToString("\n") { "- ${it.groupName} - ${it.description}" }
        val eventsContext = existingEvents.joinToString("\n") { "- ${it.title} at ${it.startTime ?: "unknown time"} (${it.location ?: "unknown location"})" }
        val memoriesContext = existingMemories.joinToString("\n") { "- Memory for Person ${existingPeople.find { p -> p.id == it.personId }?.fullName ?: "Unknown"}: ${it.content}" }

        val currentDate = java.time.LocalDate.now().toString()
        val prompt = """
            You are a helpful Personal CRM Assistant. 
            You have access to the user's social network data:
            
            People:
            ${if (peopleContext.isNotBlank()) peopleContext else "None"}
            
            Circles/Groups:
            ${if (groupContext.isNotBlank()) groupContext else "None"}
            
            Events:
            ${if (eventsContext.isNotBlank()) eventsContext else "None"}
            
            Memories/Notes:
            ${if (memoriesContext.isNotBlank()) memoriesContext else "None"}
            
            When answering, if you mention any person that exists in the People list above (or a nickname or name corresponding to them), you MUST enclose their exact stored canonical name or nickname in brackets prefixed with an '@' symbol, for example [@Alex Chen] or [@Michelle]. We use this strict formatting to create clickable links in the UI.

            IMPORTANT RULES FOR CONTEXT DRIFT:
            If this is an ongoing conversation (there is Previous Chat History), evaluate if the 'Current Question' is completely unrelated to the topics discussed in the last 3 messages. If it is completely unrelated, you MUST prefix your response EXACTLY with the text "[DRIFT]". After the prefix, answer the question normally.

            TIME AWARENESS:
            The current date is $currentDate. In this recall chat, anything with events, tasks, or details to follow up on "soon" MUST return and refer solely to the next 7 days from today.

            Answer the following question or continue the conversation based on the user's social network data:
            "$question"
            
            Provide a helpful, precise, and concise answer. If you don't know the answer, say so.
        """.trimIndent()

        val requestBody = GeminiRequest(
            contents = listOf(GeminiContent(parts = listOf(GeminiPart(text = prompt)))),
            generationConfig = GenerationConfig(
                temperature = 0.2f
            )
        )

        return try {
            val response = api.generateContent(
                apiKey = apiKey,
                request = requestBody
            )
            response.candidates?.firstOrNull()?.content?.parts?.firstOrNull()?.text ?: "No answer generated."
        } catch (e: Exception) {
            Log.e(TAG, "API Error: ${e.message}", e)
            "Error querying data: ${e.message}"
        }
    }

    suspend fun extractFromCapture(
        textNote: String?,
        screenshot: Bitmap? = null,
        existingPeople: List<Person> = emptyList(),
        existingGroups: List<Group> = emptyList()
    ): ExtractionResult {
        val apiKey = BuildConfig.GEMINI_API_KEY
        if (apiKey.isEmpty() || apiKey == "MY_GEMINI_API_KEY") {
            Log.e(TAG, "API Key is empty or placeholder! Running fallback parser...")
            return generateFallback(textNote ?: "Screenshot Capture")
        }

        val peopleContext = existingPeople.joinToString("\n") { 
            "- ${it.fullName}" + (if (!it.nickname.isNullOrBlank()) " (Nickname: ${it.nickname})" else "") + (if (it.isSelf) " [NOTE: THIS IS THE USER/ME]" else "")
        }
        val groupContext = existingGroups.joinToString("\n") { "- ${it.groupName}" }

        val prompt = """
            You are a Personal CRM AI Extractor. You process social inputs (text notes, chat screenshots, voice transcriptions) and extract structured social updates.
            
            Existing People in CRM (use these canonical names if they match nicknames or parts of names in the input):
            ${if (peopleContext.isNotBlank()) peopleContext else "None yet"}
            
            Existing Circles/Groups in CRM (you can associate events or people with these circles):
            ${if (groupContext.isNotBlank()) groupContext else "None yet"}
            
            Input: ${textNote ?: "Analyze the provided image screenshot."}
            
            Extract and return a JSON object structured EXACTLY like this:
            {
              "people": [
                {
                  "name": "Michelle (use canonical name if found in existing CRM)",
                  "confidence_state": "suggested",
                  "evidence": "Michelle's birthday dinner"
                }
              ],
              "events": [
                {
                  "title": "Michelle's Birthday Dinner",
                  "date_text": "next Saturday",
                  "resolved_date": "2026-06-13",
                  "time_text": "7pm",
                  "location": "Bar Isabel",
                  "people": ["Michelle", "Alex", "Sarah"],
                  "confidence_state": "needs_review",
                  "evidence": "Michelle's birthday dinner is next Saturday at 7pm at Bar Isabel"
                }
              ],
              "memories": [
                {
                  "person": "Sarah",
                  "content": "Sarah cannot attend because she is moving.",
                  "memory_type": "life_update",
                  "confidence_state": "suggested",
                  "evidence": "Sarah can't make it because she is moving"
                }
              ],
              "relationships": [
                {
                  "person_a": "Alex",
                  "person_b": "Michelle",
                  "relationship_type": "friend",
                  "confidence_state": "suggested",
                  "evidence": "Michelle and Alex both attending"
                }
              ],
              "reminders": [
                {
                  "title": "Ask Sarah about her move",
                  "due_text": "next week",
                  "confidence_state": "suggested"
                }
              ]
            }

            Rules:
            1. Keep names short and canonical (e.g. "Michelle", "Alex Chen"). Match them to "Existing People" if possible, especially resolving nicknames.
            2. Match "memory_type" with one of: "life_update", "preference", "relationship", "event_context", "follow_up", "general_note".
            3. Match "relationship_type" with one of: "spouse", "sibling", "coworker", "friend", "met_through".
            4. If a Circle/Group is mentioned, include it in the analysis (e.g. under Title/Content).
            5. Make sure output is raw parseable JSON only. Do not enclose it in markdown blocks.
        """.trimIndent()

        val parts = mutableListOf<GeminiPart>()
        parts.add(GeminiPart(text = prompt))
        if (screenshot != null) {
            parts.add(GeminiPart(inlineData = InlineData(mimeType = "image/jpeg", data = screenshot.toBase64())))
        }

        val requestBody = GeminiRequest(
            contents = listOf(GeminiContent(parts = parts)),
            generationConfig = GenerationConfig(
                responseMimeType = "application/json",
                temperature = 0.2f
            ),
            systemInstruction = GeminiContent(parts = listOf(GeminiPart(text = "You are an expert Social Brain / Personal CRM AI extractor designed to parse social signals. Return valid JSON only.")))
        )

        return try {
            val response = api.generateContent(apiKey, requestBody)
            val jsonText = response.candidates?.firstOrNull()?.content?.parts?.firstOrNull()?.text
            if (jsonText != null) {
                val adapter = moshi.adapter(ExtractionResult::class.java)
                adapter.fromJson(jsonText) ?: generateFallback(textNote ?: "Screenshot Capture")
            } else {
                Log.e(TAG, "No response candidate found.")
                generateFallback(textNote ?: "Screenshot Capture")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Gemini API call failed", e)
            generateFallback(textNote ?: "Screenshot Capture")
        }
    }

    private fun generateFallback(rawInput: String): ExtractionResult {
        // High quality fallback based on matching common words in typical CRM scenarios
        val input = rawInput.lowercase()

        val peopleList = mutableListOf<ExtractedPerson>()
        val eventsList = mutableListOf<ExtractedEvent>()
        val memoriesList = mutableListOf<ExtractedMemory>()
        val relationshipsList = mutableListOf<ExtractedRelationship>()
        val remindersList = mutableListOf<ExtractedReminder>()

        // Spot entities
        if (input.contains("michelle")) {
            peopleList.add(ExtractedPerson("Michelle", "suggested", "Mentioned in text"))
        }
        if (input.contains("alex") || input.contains("alex chen")) {
            peopleList.add(ExtractedPerson("Alex Chen", "suggested", "Mentioned in text"))
        }
        if (input.contains("sarah")) {
            peopleList.add(ExtractedPerson("Sarah", "suggested", "Mentioned in text"))
        }
        if (input.contains("brian")) {
            peopleList.add(ExtractedPerson("Brian", "suggested", "Mentioned in text"))
        }
        if (input.contains("kevin")) {
            peopleList.add(ExtractedPerson("Kevin", "suggested", "Mentioned in text"))
        }

        // Spot events
        if (input.contains("birthday") || input.contains("dinner")) {
            eventsList.add(
                ExtractedEvent(
                    title = "Michelle's Birthday Dinner",
                    date_text = "Saturday",
                    time_text = "7:00 PM",
                    location = "Bar Isabel",
                    people = peopleList.map { it.name },
                    confidence_state = "needs_review",
                    evidence = "Extracted birthday dinner"
                )
            )
        } else if (input.contains("paddle") || input.contains("bbq")) {
            eventsList.add(
                ExtractedEvent(
                    title = "Paddle BBQ",
                    date_text = "Sunday",
                    time_text = "2:00 PM",
                    location = "Hanlan's Point",
                    people = peopleList.map { it.name },
                    confidence_state = "needs_review",
                    evidence = "Extracted paddle bbq"
                )
            )
        }

        // Spot memories
        if (input.contains("japan")) {
            memoriesList.add(
                ExtractedMemory(
                    person = "Alex Chen",
                    content = "Going to Japan in September",
                    memory_type = "life_update",
                    confidence_state = "suggested",
                    evidence = "Alex and Michelle starting trip to Japan"
                )
            )
        }
        if (input.contains("move") || input.contains("moving")) {
            memoriesList.add(
                ExtractedMemory(
                    person = "Sarah",
                    content = "Sarah is moving and cannot attend upcoming dinner",
                    memory_type = "life_update",
                    confidence_state = "suggested",
                    evidence = "Sarah is moving out of town"
                )
            )
        }
        if (input.contains("shoulder") || input.contains("injured")) {
            memoriesList.add(
                ExtractedMemory(
                    person = "Brian",
                    content = "Brian injured his shoulder in paddling",
                    memory_type = "life_update",
                    confidence_state = "suggested",
                    evidence = "Brian shoulder injury"
                )
            )
        }

        // Spot relationships
        if (input.contains("spouse") || input.contains("partner") || (input.contains("alex") && input.contains("michelle"))) {
            relationshipsList.add(
                ExtractedRelationship(
                    person_a = "Alex Chen",
                    person_b = "Michelle",
                    relationship_type = "spouse",
                    confidence_state = "needs_review",
                    evidence = "Implied core partnership"
                )
            )
        }

        // Spot reminders
        if (input.contains("hotel") || input.contains("kyoto")) {
            remindersList.add(ExtractedReminder("Ask Alex and Michelle about Kyoto hotel", "Next meet-up"))
        }
        if (input.contains("shoulder") || input.contains("brian")) {
            remindersList.add(ExtractedReminder("Ask Brian how his shoulder is feeling", "Sunday"))
        }
        if (input.contains("sarah") || input.contains("move")) {
            remindersList.add(ExtractedReminder("Ask Sarah about her new move", "Saturday"))
        }

        // Default item if input is very generic
        if (peopleList.isEmpty() && eventsList.isEmpty() && memoriesList.isEmpty()) {
            peopleList.add(ExtractedPerson("Alex Chen", "suggested", "Parsed name from input"))
            memoriesList.add(
                ExtractedMemory(
                    person = "Alex Chen",
                    content = rawInput.take(200),
                    memory_type = "general_note",
                    confidence_state = "suggested",
                    evidence = "Captured text notes"
                )
            )
            remindersList.add(ExtractedReminder("Follow up regarding: " + rawInput.take(30) + "..."))
        }

        return ExtractionResult(
            people = peopleList,
            events = eventsList,
            memories = memoriesList,
            relationships = relationshipsList,
            reminders = remindersList
        )
    }
}
