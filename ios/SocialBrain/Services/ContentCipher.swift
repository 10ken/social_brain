import CryptoKit
import Foundation
import Security

enum ContentCipherError: Error {
    case invalidKeyLength
    case invalidNonceLength
    case invalidCombinedCiphertext
    case randomGenerationFailed(OSStatus)
    case keychain(OSStatus)
}

enum ContentCipher {
    static let keyByteCount = 32
    /// AES-GCM always uses a 96-bit nonce. Keeping this explicit avoids relying
    /// on an SDK-only convenience constant and documents the on-disk envelope
    /// format shared with previously written content.
    static let nonceByteCount = 12
    static let authenticationTagByteCount = 16

    static func generateKey() throws -> Data {
        var bytes = Data(count: keyByteCount)
        let status = bytes.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, keyByteCount, $0.baseAddress!)
        }
        guard status == errSecSuccess else { throw ContentCipherError.randomGenerationFailed(status) }
        return bytes
    }

    static func seal(_ plaintext: Data, key: Data, authenticatedMetadata: Data) throws -> (nonce: Data, ciphertext: Data) {
        guard key.count == keyByteCount else { throw ContentCipherError.invalidKeyLength }
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(
            plaintext,
            using: SymmetricKey(data: key),
            nonce: nonce,
            authenticating: authenticatedMetadata
        )
        let nonceData = Data(nonce)
        guard nonceData.count == nonceByteCount, sealed.tag.count == authenticationTagByteCount else {
            throw ContentCipherError.invalidCombinedCiphertext
        }

        // Existing envelopes stored the combined form without its leading
        // nonce: `ciphertext || tag`. Continue writing exactly that layout.
        return (nonceData, sealed.ciphertext + sealed.tag)
    }

    static func open(nonce: Data, ciphertext: Data, key: Data, authenticatedMetadata: Data) throws -> Data {
        guard key.count == keyByteCount else { throw ContentCipherError.invalidKeyLength }
        guard nonce.count == nonceByteCount else { throw ContentCipherError.invalidNonceLength }
        guard ciphertext.count >= authenticationTagByteCount else { throw ContentCipherError.invalidCombinedCiphertext }
        let nonceValue = try AES.GCM.Nonce(data: nonce)
        let messageEnd = ciphertext.count - authenticationTagByteCount
        let sealed = try AES.GCM.SealedBox(
            nonce: nonceValue,
            ciphertext: Data(ciphertext.prefix(messageEnd)),
            tag: Data(ciphertext.suffix(authenticationTagByteCount))
        )
        return try AES.GCM.open(sealed, using: SymmetricKey(data: key), authenticating: authenticatedMetadata)
    }
}

enum KeychainStore {
    static let defaultService = "com.aistudio.socialbrain"

    static func save(_ data: Data, account: String, service: String = defaultService) throws {
        let query = baseQuery(account: account, service: service)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard updateStatus == errSecSuccess else { throw ContentCipherError.keychain(updateStatus) }
        } else {
            guard status == errSecSuccess else { throw ContentCipherError.keychain(status) }
        }
    }

    static func load(account: String, service: String = defaultService) throws -> Data? {
        var query = baseQuery(account: account, service: service)
        query.merge([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw ContentCipherError.keychain(status) }
        return data
    }

    static func delete(account: String, service: String = defaultService) throws {
        let query = baseQuery(account: account, service: service)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw ContentCipherError.keychain(status) }
    }

    private static func baseQuery(account: String, service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }
}
