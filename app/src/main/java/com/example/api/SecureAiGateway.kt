package com.example.api

import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.functions.FirebaseFunctionsException
import kotlinx.coroutines.tasks.await

enum class AiAccessState(val canUseAi: Boolean, val userMessage: String) {
    READY(true, "AI features are ready."),
    FIREBASE_NOT_CONFIGURED(false, "Add the Firebase Android configuration before using AI features."),
    SIGN_IN_REQUIRED(false, "Sign in with a configured provider before using AI features."),
    APP_CHECK_REQUIRED(false, "App Check could not verify this device. Check the Firebase App Check setup."),
    RATE_LIMITED(false, "Too many AI requests. Please try again shortly."),
    SERVICE_UNAVAILABLE(false, "AI is temporarily unavailable. Please try again shortly.")
}

class AiAccessException(
    val state: AiAccessState,
    cause: Throwable? = null
) : IllegalStateException(state.userMessage, cause)

data class AiGenerateRequest(
    val prompt: String,
    val systemInstruction: String? = null,
    val responseMimeType: String = "text/plain",
    val image: SecureAiGateway.InlineImage? = null
)

/**
 * Calls the authenticated Firebase Function that holds the Gemini credential.
 * Prompts are user initiated and never written to Android logs or Firestore.
 */
object SecureAiGateway {
    private const val FUNCTION_NAME = "generateAIContent"

    data class InlineImage(val mimeType: String, val base64Data: String)

    /** Safe to call before Firebase configuration is supplied. */
    fun currentAccessState(): AiAccessState = try {
        if (FirebaseAuth.getInstance().currentUser == null) {
            AiAccessState.SIGN_IN_REQUIRED
        } else {
            AiAccessState.READY
        }
    } catch (_: IllegalStateException) {
        AiAccessState.FIREBASE_NOT_CONFIGURED
    }

    /** Installs the production provider when Firebase configuration is present. */
    fun initializeAppCheck() {
        try {
            FirebaseAppCheck.getInstance().installAppCheckProviderFactory(
                PlayIntegrityAppCheckProviderFactory.getInstance()
            )
        } catch (_: IllegalStateException) {
            // The UI reports FIREBASE_NOT_CONFIGURED until google-services.json is supplied.
        }
    }

    /** Kept pure so request wire-shape tests do not need Firebase or an emulator. */
    fun buildPayload(request: AiGenerateRequest): Map<String, Any> = buildMap {
        put("prompt", request.prompt)
        put("responseMimeType", request.responseMimeType)
        request.systemInstruction?.let { put("systemInstruction", it) }
        request.image?.let { put("image", mapOf("mimeType" to it.mimeType, "dataBase64" to it.base64Data)) }
    }

    suspend fun generate(
        prompt: String,
        systemInstruction: String? = null,
        responseMimeType: String = "text/plain",
        image: InlineImage? = null
    ): String = generate(
        AiGenerateRequest(
            prompt = prompt,
            systemInstruction = systemInstruction,
            responseMimeType = responseMimeType,
            image = image
        )
    )

    suspend fun generate(request: AiGenerateRequest): String {
        when (val access = currentAccessState()) {
            AiAccessState.READY -> Unit
            else -> throw AiAccessException(access)
        }

        try {
            // The callable enforces App Check. Fetching a token first turns a vague
            // callable failure into a specific, actionable state for the UI.
            FirebaseAppCheck.getInstance().getAppCheckToken(false).await()
        } catch (error: Exception) {
            throw AiAccessException(AiAccessState.APP_CHECK_REQUIRED, error)
        }

        try {
            val result = FirebaseFunctions.getInstance()
                .getHttpsCallable(FUNCTION_NAME)
                .call(buildPayload(request))
                .await()
            val body = result.data as? Map<*, *> ?: throw AiAccessException(AiAccessState.SERVICE_UNAVAILABLE)
            return body["text"] as? String ?: throw AiAccessException(AiAccessState.SERVICE_UNAVAILABLE)
        } catch (error: FirebaseFunctionsException) {
            throw AiAccessException(
                when (error.code) {
                    FirebaseFunctionsException.Code.UNAUTHENTICATED -> AiAccessState.SIGN_IN_REQUIRED
                    FirebaseFunctionsException.Code.RESOURCE_EXHAUSTED -> AiAccessState.RATE_LIMITED
                    FirebaseFunctionsException.Code.UNAVAILABLE -> AiAccessState.SERVICE_UNAVAILABLE
                    else -> AiAccessState.SERVICE_UNAVAILABLE
                },
                error
            )
        }
    }
}
