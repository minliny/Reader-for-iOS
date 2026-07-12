// CoreBridge
//
// HostCookieCapability — UI/reducer-initiated `cookie.get/set/clear` requests.
//
// Bridges the contract `HostRequest` (type `.cookie_get/.cookie_set/.cookie_clear`)
// to the existing `ScopedCookieJar`. This is the UI-side mirror of the Core-side
// `cookie.get` / `cookie.set` lanes already routed by `HostRequestRouter`.
//
// Tier: crossPlatform — `BasicCookieJar` is pure Swift (no UIKit), so this
// handler can be exercised on macOS `swift build` / `swift test` as well as
// on the iOS simulator and real devices.
//
// Payload contract (mirrors Core `cookie.get/set` params):
// - `.cookie_get`:  `{ url: String, scopeKey?: { sourceId: String, host: String } }`
//                    → `{ cookies: [{ name, value, domain, path, secure, httpOnly, expiresAt? }] }`
// - `.cookie_set`:  `{ url: String, cookie: { name, value, domain, path?, secure?, httpOnly?, expiresAt? }, scopeKey? }`
//                    → `{ stored: true }`
// - `.cookie_clear`:`{ scopeKey?: { sourceId, host } }` (clear one scope) or `{}` (clearAll)
//                    → `{ cleared: true }`

import Foundation
import ReaderCoreProtocols
import ReaderCoreNetwork  // Designated seam (check_ios_boundary.sh whitelist): CoreBridge is the sole permitted import site.
import ReaderUIContract

public struct HostCookieCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [.cookie_get, .cookie_set, .cookie_clear]
    public let tier: HostCapabilityTier = .crossPlatform

    private let cookieJar: ScopedCookieJar

    public init(cookieJar: ScopedCookieJar) {
        self.cookieJar = cookieJar
    }

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        switch request.type {
        case .cookie_get:
            return try await handleGet(request.payload)
        case .cookie_set:
            return try await handleSet(request.payload)
        case .cookie_clear:
            return try await handleClear(request.payload)
        default:
            return .failure(.notImplemented(request.type, "HostCookieCapability does not handle \(request.type.rawValue)"))
        }
    }

    // MARK: - cookie.get

    private func handleGet(_ payload: [String: AnyCodable]) async throws -> HostCapabilityOutcome {
        guard let urlString = payload["url"]?.value as? String, !urlString.isEmpty else {
            return .failure(.invalidParams("cookie.get requires non-empty `url`"))
        }
        guard let url = URL(string: urlString), let host = url.host else {
            return .failure(.invalidParams("cookie.get `url` must have a host: \(urlString)"))
        }
        let path = url.path.isEmpty ? "/" : url.path
        let scopeKey = extractScopeKey(payload)

        let cookies: [Cookie]
        if let scopeKey = scopeKey {
            cookies = await cookieJar.getCookies(for: host, path: path, scopeKey: scopeKey)
        } else {
            cookies = await cookieJar.getCookies(for: host, path: path)
        }

        let cookieDicts: [[String: AnyCodable]] = cookies.map { c in
            var dict: [String: AnyCodable] = [
                "name": AnyCodable(c.name),
                "value": AnyCodable(c.value),
                "domain": AnyCodable(c.domain),
                "path": AnyCodable(c.path),
                "secure": AnyCodable(c.secure),
                "httpOnly": AnyCodable(c.httpOnly),
            ]
            if let expiresAt = c.expiresAt {
                dict["expiresAt"] = AnyCodable(expiresAt.timeIntervalSince1970)
            }
            return dict
        }
        return .success(["cookies": AnyCodable(cookieDicts.map { AnyCodable($0) })])
    }

    // MARK: - cookie.set

    private func handleSet(_ payload: [String: AnyCodable]) async throws -> HostCapabilityOutcome {
        guard let urlString = payload["url"]?.value as? String, !urlString.isEmpty else {
            return .failure(.invalidParams("cookie.set requires non-empty `url`"))
        }
        guard let url = URL(string: urlString), let host = url.host else {
            return .failure(.invalidParams("cookie.set `url` must have a host: \(urlString)"))
        }
        guard let cookieDict = Self.dictionary(payload["cookie"]?.value),
              let name = cookieDict["name"]?.value as? String,
              let value = cookieDict["value"]?.value as? String else {
            return .failure(.invalidParams("cookie.set requires `cookie.name` and `cookie.value`"))
        }
        let path = (cookieDict["path"]?.value as? String) ?? "/"
        let secure = (cookieDict["secure"]?.value as? Bool) ?? false
        let httpOnly = (cookieDict["httpOnly"]?.value as? Bool) ?? false
        let domain = (cookieDict["domain"]?.value as? String) ?? host
        let expiresAt: Date? = {
            if let ts = cookieDict["expiresAt"]?.value as? Double { return Date(timeIntervalSince1970: ts) }
            return nil
        }()

        let cookie = Cookie(
            name: name, value: value, domain: domain, path: path,
            expiresAt: expiresAt, secure: secure, httpOnly: httpOnly
        )
        let scopeKey = extractScopeKey(payload)
        if let scopeKey = scopeKey {
            await cookieJar.setCookie(cookie, scopeKey: scopeKey)
        } else {
            await cookieJar.setCookie(cookie)
        }
        return .success(["stored": AnyCodable(true)])
    }

    // MARK: - cookie.clear

    private func handleClear(_ payload: [String: AnyCodable]) async throws -> HostCapabilityOutcome {
        if let scopeKey = extractScopeKey(payload) {
            await cookieJar.clear(scopeKey: scopeKey)
        } else {
            await cookieJar.clearAll()
        }
        return .success(["cleared": AnyCodable(true)])
    }

    // MARK: - Helpers

    private func extractScopeKey(_ payload: [String: AnyCodable]) -> CookieJarScopeKey? {
        guard let scopeDict = Self.dictionary(payload["scopeKey"]?.value),
              let sourceId = scopeDict["sourceId"]?.value as? String,
              let host = scopeDict["host"]?.value as? String else {
            return nil
        }
        return CookieJarScopeKey(sourceId: sourceId, host: host)
    }

    private static func dictionary(_ raw: (any Sendable)?) -> [String: AnyCodable]? {
        if let value = raw as? [String: AnyCodable] { return value }
        if let value = raw as? [String: Any] { return value.mapValues(AnyCodable.init) }
        return nil
    }
}
