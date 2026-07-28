package com.example.api

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SecureAiGatewayTest {
    @Test
    fun `builds the callable payload with the canonical inline image fields`() {
        val payload = SecureAiGateway.buildPayload(
            AiGenerateRequest(
                prompt = "Extract this screenshot",
                responseMimeType = "application/json",
                image = SecureAiGateway.InlineImage("image/jpeg", "aW1hZ2U=")
            )
        )

        assertEquals("Extract this screenshot", payload["prompt"])
        assertEquals("application/json", payload["responseMimeType"])
        assertEquals(
            mapOf("mimeType" to "image/jpeg", "dataBase64" to "aW1hZ2U="),
            payload["image"]
        )
    }

    @Test
    fun `AI availability messages keep unauthenticated work disabled`() {
        assertFalse(AiAccessState.SIGN_IN_REQUIRED.canUseAi)
        assertFalse(AiAccessState.APP_CHECK_REQUIRED.canUseAi)
        assertTrue(AiAccessState.READY.canUseAi)
    }
}
