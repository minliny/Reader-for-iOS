// CoreBridge
//
// HostCredentialCapability — UI/reducer-initiated `credential.get/set/delete`.
//
// Bridges the contract `HostRequest` to the iOS/macOS Keychain via the
// `Security` framework (SecItem). Credentials are addressed by
// `{ service, account }` — the same pattern used by `WebDAVKeychainStore`
// (service = "com.reader.ios.webdav", account = "webdav_credentials"), but
// generalized so any capability can store/retrieve a secret under its own
// service string.
//
// Tier: crossPlatform — `Security.framework` is available on macOS, iOS, and
// sim. Keychain access on the sim is per-process (no real Secure Enclave),
// but the API surface is identical to device. Real-device proof adds the
// device-unlock prompt (AccessControl) which the sim does not enforce.
//
// Payload contract:
// - `.credential_get`:    `{ service: String, account: String }`
//                        → `{ value: String?, found: Bool }`
// - `.credential_set`:    `{ service: String, account: String, value: String,
//                            accessible?: String }`
//                        → `{ stored: true }`
// - `.credential_delete`: `{ service: String, account: String }`
//                        → `{ deleted: true, existed: Bool }`
//
// `accessible` values: "whenUnlocked" (default), "whenUnlockedThisDeviceOnly",
// "afterFirstUnlock", "afterFirstUnlockThisDeviceOnly". Maps to
// `kSecAttrAccessible*`.

import Foundation
import Security
import ReaderUIContract

public struct HostCredentialCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [
        .credential_get, .credential_set, .credential_delete,
    ]
    public let tier: HostCapabilityTier = .crossPlatform

    public init() {}

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        switch request.type {
        case .credential_get:
            return handleGet(request.payload)
        case .credential_set:
            return handleSet(request.payload)
        case .credential_delete:
            return handleDelete(request.payload)
        default:
            return .failure(.notImplemented(request.type, "HostCredentialCapability does not handle \(request.type.rawValue)"))
        }
    }

    // MARK: - credential.get

    private func handleGet(_ payload: [String: AnyCodable]) -> HostCapabilityOutcome {
        guard let service = payload["service"]?.value as? String, !service.isEmpty else {
            return .failure(.invalidParams("credential.get requires non-empty `service`"))
        }
        guard let account = payload["account"]?.value as? String, !account.isEmpty else {
            return .failure(.invalidParams("credential.get requires non-empty `account`"))
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                return .failure(.underlying("credential.get: stored value is not valid UTF-8"))
            }
            return .success([
                "value": AnyCodable(value),
                "found": AnyCodable(true),
            ])
        case errSecItemNotFound:
            return .success([
                "value": AnyCodable(String?.none as String?),
                "found": AnyCodable(false),
            ])
        default:
            return .failure(.underlying("credential.get SecItemCopyMatching status \(status)"))
        }
    }

    // MARK: - credential.set

    private func handleSet(_ payload: [String: AnyCodable]) -> HostCapabilityOutcome {
        guard let service = payload["service"]?.value as? String, !service.isEmpty else {
            return .failure(.invalidParams("credential.set requires non-empty `service`"))
        }
        guard let account = payload["account"]?.value as? String, !account.isEmpty else {
            return .failure(.invalidParams("credential.set requires non-empty `account`"))
        }
        guard let value = payload["value"]?.value as? String else {
            return .failure(.invalidParams("credential.set requires `value` string"))
        }
        let accessibleString = (payload["accessible"]?.value as? String) ?? "whenUnlocked"
        guard let accessible = Self.accessibleAttr(for: accessibleString) else {
            return .failure(.invalidParams("credential.set `accessible` not recognized: \(accessibleString)"))
        }
        let data = Data(value.utf8)

        // Delete any existing item first (SecItemAdd fails on duplicate).
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: accessible,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            return .failure(.underlying("credential.set SecItemAdd status \(status)"))
        }
        return .success(["stored": AnyCodable(true)])
    }

    // MARK: - credential.delete

    private func handleDelete(_ payload: [String: AnyCodable]) -> HostCapabilityOutcome {
        guard let service = payload["service"]?.value as? String, !service.isEmpty else {
            return .failure(.invalidParams("credential.delete requires non-empty `service`"))
        }
        guard let account = payload["account"]?.value as? String, !account.isEmpty else {
            return .failure(.invalidParams("credential.delete requires non-empty `account`"))
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecSuccess:
            return .success(["deleted": AnyCodable(true), "existed": AnyCodable(true)])
        case errSecItemNotFound:
            return .success(["deleted": AnyCodable(true), "existed": AnyCodable(false)])
        default:
            return .failure(.underlying("credential.delete SecItemDelete status \(status)"))
        }
    }

    // MARK: - Helpers

    private static func accessibleAttr(for value: String) -> CFString? {
        switch value {
        case "whenUnlocked": return kSecAttrAccessibleWhenUnlocked
        case "whenUnlockedThisDeviceOnly": return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case "afterFirstUnlock": return kSecAttrAccessibleAfterFirstUnlock
        case "afterFirstUnlockThisDeviceOnly": return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case "whenPasscodeSetThisDeviceOnly": return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        default: return nil
        }
    }
}
