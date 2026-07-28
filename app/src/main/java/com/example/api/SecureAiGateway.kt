package com.example.api

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.functions.FirebaseFunctions
import kotlinx.coroutines.tasks.await

/**
 * Calls the authenticated Firebase Function that holds the Gemini credential.
 * Prompts are user initiated and never written to Android logs or Firestore.
 */
object SecureAiGateway {
    private const val FUNCTION_NAME = "generateAIContent"

    data class InlineImage(val mimeType: String, val base64Data: String)

    suspend fun generate(
        prompt: String,
        systemInstruction: String? = null,
        responseMimeType: String = "text/plain",
        image: InlineImage? = null
    ): String {
        check(FirebaseAuth.getInstance().currentUser != null) { "Sign in before using AI features." }
        val payload = buildMap<String, Any> {
            put("prompt", prompt)
            put("responseMimeType", responseMimeType)
            systemInstruction?.let { put("systemInstruction", it) }
            image?.let { put("image", mapOf("mimeType" to it.mimeType, "dataBase64" to it.base64Data)) }
        }
        val result = FirebaseFunctions.getInstance()
            .getHttpsCallable(FUNCTION_NAME)
            .call(payload)
            .await()
        val body = result.data as? Map<*, *> ?: error("Malformed AI response")
        return body["text"] as? String ?: error("AI response did not contain text")
    }
}
