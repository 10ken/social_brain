package com.example.sync

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class AesGcmCipherTest {
    @Test
    fun `round trips content while authenticating envelope metadata`() {
        val key = AesGcmCipher.generateKey()
        val plaintext = "Michelle's birthday is June 13".encodeToByteArray()
        val metadata = "person:record-1:1".encodeToByteArray()

        val encrypted = AesGcmCipher.encrypt(plaintext, key, metadata)

        assertNotEquals(String(plaintext), encrypted.ciphertextBase64)
        assertArrayEquals(plaintext, AesGcmCipher.decrypt(encrypted, key, metadata))
    }
}
