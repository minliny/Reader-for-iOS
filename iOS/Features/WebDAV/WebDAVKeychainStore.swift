import Foundation
import Security

public struct WebDAVCredentials: Codable, Equatable {
    public var serverURL: String
    public var username: String
    public var password: String

    public init(serverURL: String = "", username: String = "", password: String = "") {
        self.serverURL = serverURL
        self.username = username
        self.password = password
    }
}

public final class WebDAVKeychainStore: Sendable {
    public static let shared = WebDAVKeychainStore()

    private let service = "com.reader.ios.webdav"
    private let account = "webdav_credentials"

    private init() {}

    public func save(_ credentials: WebDAVCredentials) throws {
        let data = try JSONEncoder().encode(credentials)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: Int(status))
        }
    }

    public func load() throws -> WebDAVCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.loadFailed(status: Int(status))
        }

        return try JSONDecoder().decode(WebDAVCredentials.self, from: data)
    }

    public func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: Int(status))
        }
    }
}

public enum KeychainError: Error, LocalizedError {
    case saveFailed(status: Int)
    case loadFailed(status: Int)
    case deleteFailed(status: Int)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let s): return "Keychain save failed (status: \(s))"
        case .loadFailed(let s): return "Keychain load failed (status: \(s))"
        case .deleteFailed(let s): return "Keychain delete failed (status: \(s))"
        }
    }
}
