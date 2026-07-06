// CoreBridge
//
// CookieSetHandler: host-side capability handler for `cookie.set`.
//
// Mirrors Android `CookieSetHandler.kt` JSON contract:
// - Input params: `{url: String, cookie: {name, value, domain?, path?, secure?, httpOnly?, expiresAt?}}`
// - Writes the cookie into `ScopedCookieJar` (unscoped `CookieJar.setCookie(_:)` —
//   Core does not supply a scope key).
// - Returns `{stored: true}`.
//
// login_cookie lane: paired with `CookieGetHandler` for end-to-end cookie
// round-trip proof (set sid → get sid) aligned with Android's
// HostLoginCookieProofTest.cookieSetAndGetRoundTrip.

import Foundation
import ReaderCoreProtocols

/// `cookie.set` capability handler: writes a cookie into a `ScopedCookieJar`.
///
/// JSON contract (aligned with Android `CookieSetHandler`):
/// - Request params: `{url: String, cookie: {name, value, domain?, path?, secure?, httpOnly?, expiresAt?}}`
/// - Result: `{stored: true}`
public struct CookieSetHandler: Sendable {
    public static let capability = "cookie.set"

    private let cookieJar: ScopedCookieJar

    public init(cookieJar: ScopedCookieJar) {
        self.cookieJar = cookieJar
    }

    /// Handle a `cookie.set` request.
    /// - Parameter params: `{url, cookie: {name, value, domain?, path?, ...}}`.
    /// - Returns: `{stored: true}` on success.
    public func handle(params: [String: Any]) async throws -> [String: Any] {
        guard let url = params["url"] as? String, !url.isEmpty else {
            throw CookieHandlerError.invalidParams("cookie.set requires non-empty url")
        }
        guard let cookieObj = params["cookie"] as? [String: Any] else {
            throw CookieHandlerError.invalidParams("cookie.set requires cookie object")
        }
        let name = (cookieObj["name"] as? String) ?? ""
        let value = (cookieObj["value"] as? String) ?? ""
        guard !name.isEmpty else {
            throw CookieHandlerError.invalidParams("cookie.set requires non-empty cookie name")
        }

        // Derive a fallback domain from the URL when the cookie object omits
        // `domain` (matches Android's optString("domain", "") — empty domain
        // falls through to the jar's default handling).
        let urlHost = URL(string: url)?.host ?? ""
        let domain = (cookieObj["domain"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? urlHost
        let path = (cookieObj["path"] as? String) ?? "/"
        let secure = (cookieObj["secure"] as? Bool) ?? false
        let httpOnly = (cookieObj["httpOnly"] as? Bool) ?? false

        var expiresAt: Date?
        if let expiresAtMs = cookieObj["expiresAt"] as? NSNumber {
            expiresAt = Date(timeIntervalSince1970: expiresAtMs.doubleValue / 1000.0)
        } else if let expiresAtSec = cookieObj["expiresAt"] as? Double {
            // Tolerate seconds-since-epoch input (some senders use seconds).
            expiresAt = Date(timeIntervalSince1970: expiresAtSec)
        }

        let cookie = Cookie(
            name: name,
            value: value,
            domain: domain,
            path: path,
            expiresAt: expiresAt,
            secure: secure,
            httpOnly: httpOnly
        )
        await cookieJar.setCookie(cookie)
        return ["stored": true]
    }
}
