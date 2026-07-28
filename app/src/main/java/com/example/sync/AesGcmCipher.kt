package com.example.sync

import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec

/**
 * Cross-platform AES-256-GCM primitive. Passphrase derivation and KeyStore wrapping
 * are deliberately separate concerns so ciphertext format remains stable on iOS.
 */
object AesGcmCipher {
    private const val KEY_BYTES = 32
    private const val NONCE_BYTES = 12
    private const val TAG_BITS = 128
    private val random = SecureRandom()

    data class Ciphertext(val nonceBase64: String, val ciphertextBase64: String)

    fun generateKey(): ByteArray = ByteArray(KEY_BYTES).also(random::nextBytes)

    fun encrypt(plaintext: ByteArray, key: ByteArray, authenticatedMetadata: ByteArray): Ciphertext {
        require(key.size == KEY_BYTES) { "AES-256 requires a 32-byte key" }
        val nonce = ByteArray(NONCE_BYTES).also(random::nextBytes)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, javax.crypto.spec.SecretKeySpec(key, "AES"), GCMParameterSpec(TAG_BITS, nonce))
        cipher.updateAAD(authenticatedMetadata)
        return Ciphertext(
            nonceBase64 = Base64.getEncoder().encodeToString(nonce),
            ciphertextBase64 = Base64.getEncoder().encodeToString(cipher.doFinal(plaintext))
        )
    }

    fun decrypt(ciphertext: Ciphertext, key: ByteArray, authenticatedMetadata: ByteArray): ByteArray {
        require(key.size == KEY_BYTES) { "AES-256 requires a 32-byte key" }
        val nonce = Base64.getDecoder().decode(ciphertext.nonceBase64)
        require(nonce.size == NONCE_BYTES) { "Invalid AES-GCM nonce" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, javax.crypto.spec.SecretKeySpec(key, "AES"), GCMParameterSpec(TAG_BITS, nonce))
        cipher.updateAAD(authenticatedMetadata)
        return cipher.doFinal(Base64.getDecoder().decode(ciphertext.ciphertextBase64))
    }
}
