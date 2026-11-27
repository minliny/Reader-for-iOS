import Foundation
import Security

/// Keeps HttpTTS secrets on this installation. Core receives only the bound alias.
public enum SpeechCredentialVault {
    private static let service = "io.reader.minliny.speech.credentials"

    public static func read(_ reference: String) throws -> String? {
        var query = address(reference)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let bytes = result as? Data,
              let secret = String(data: bytes, encoding: .utf8) else {
            throw SpeechPhysicalFailure.credentialsUnavailable
        }
        return secret
    }

    public static func store(_ secret: String, reference: String) throws {
        var item = address(reference)
        item[kSecValueData as String] = Data(secret.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
            throw SpeechPhysicalFailure.credentialsUnavailable
        }
    }

    public static func remove(_ reference: String) throws {
        let status = SecItemDelete(address(reference) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SpeechPhysicalFailure.credentialsUnavailable
        }
    }

    private static func address(_ reference: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: reference]
    }
}
