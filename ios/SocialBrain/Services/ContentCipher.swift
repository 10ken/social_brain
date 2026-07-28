import CryptoKit
import Foundation
import Security

enum ContentCipherError: Error {
    case invalidKeyLength
    case invalidCombinedCiphertext
    case keychain(OSStatus)
}

enum ContentCipher {
    static let keyByteCount = 32

    static func generateKey() -> Data {
        var bytes = Data(count: keyByteCount)
        _ = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, keyByteCount, $0.baseAddress!) }
        return bytes
    }

    static func seal(_ plaintext: Data, key: Data, authenticatedMetadata: Data) throws -> (nonce: Data, ciphertext: Data) {
        guard key.count == keyByteCount else { throw ContentCipherError.invalidKeyLength }
        let sealed = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key), authenticating: authenticatedMetadata)
        guard let combined = sealed.combined, combined.count > AES.GCM.nonceByteCount else { throw ContentCipherError.invalidCombinedCiphertext }
        return (Data(combined.prefix(AES.GCM.nonceByteCount)), Data(combined.dropFirst(AES.GCM.nonceByteCount)))
    }

    static func open(nonce: Data, ciphertext: Data, key: Data, authenticatedMetadata: Data) throws -> Data {
        guard key.count == keyByteCount else { throw ContentCipherError.invalidKeyLength }
        let sealed = try AES.GCM.SealedBox(combined: nonce + ciphertext)
        return try AES.GCM.open(sealed, using: SymmetricKey(data: key), authenticating: authenticatedMetadata)
    }
}

enum KeychainStore {
    static func save(_ data: Data, account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw ContentCipherError.keychain(status) }
    }

    static func load(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw ContentCipherError.keychain(status) }
        return data
    }

    static func delete(account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw ContentCipherError.keychain(status) }
    }
}

/// Implement this using the same audited Argon2id library and versioned parameters on iOS and Android.
/// The passphrase itself must never enter Firebase, Keychain, or Android Keystore.
protocol PassphraseKeyWrapping {
    func wrap(contentKey: Data, passphrase: String) throws -> Data
    func unwrap(wrappedKey: Data, passphrase: String) throws -> Data
}
