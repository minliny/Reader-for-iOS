// CoreBridge
//
// CookieGetHandler: host-side capability handler for `cookie.get`.
//
// Mirrors Android `CookieGetHandler.kt` JSON contract:
// - Input params: `{url: String}`
// - Reads cookies for the URL's host/path from `ScopedCookieJar` (unscoped
//   `CookieJar.getCookies(for:path:)` — Core does not supply a scope key).
// - Returns `{cookies: [{name, value, domain, path, secure?, httpOnly?, expiresAt?}]}`.
//
// login_cookie lane: paired with `CookieSetHandler` for end-to-end cookie
// round-trip proof (set sid → get sid) aligned with Android's
// HostLoginCookieProofTest.cookieSetAndGetRoundTrip.

import Foundation
import ReaderCoreProtocols

/// Errors thrown by `CookieGetHandler`.
public enum CookieHandlerError: Error, LocalizedError {
    case invalidParams(String)

    public var errorDescription: String? {
        switch self {
        case .invalidParams(let m): return m
        }
    }
}

/// `cookie.get` capability handler: reads cookies from a `ScopedCookieJar`
/// for the URL's host/path and returns them as a JSON-compatible dict.
///
/// JSON contract (aligned with Android `CookieGetHandler`):
/// - Request params: `{url: String}`
/// - Result: `{cookies: [{name, value, domain, path, secure?, httpOnly?, expiresAt?}]}`
public struct CookieGetHandler: Sendable {
    public static let capability = "cookie.get"

    private let cookieJar: ScopedCookieJar

    public init(cookieJar: ScopedCookieJar) {
        self.cookieJar = cookieJar
    }

    /// Handle a `cookie.get` request.
    /// - Parameter params: `{url: String}` — the URL whose cookies to read.
    /// - Returns: `{cookies: [{name, value, domain, path, ...}]}`.
    public func handle(params: [String: Any]) async throws -> [String: Any] {
        guard let url = params["url"] as? String, !url.isEmpty else {
            throw CookieHandlerError.invalidParams("cookie.get requires non-empty url")
        }
        guard let parsed = URL(string: url), let host = parsed.host, !host.isEmpty else {
            throw CookieHandlerError.invalidParams("cookie.get invalid url: \(url)")
        }
        let path = parsed.path.isEmpty ? "/" : parsed.path

        let cookies = await cookieJar.getCookies(for: host, path: path)
        let cookieArray: [[String: Any]] = cookies.map { cookie in
            var dict: [String: Any] = [
                "name": cookie.name,
                "value": cookie.value,
                "domain": cookie.domain,
                "path": cookie.path,
            ]
            if cookie.secure {
                dict["secure"] = true
            }
            if cookie.httpOnly {
                dict["httpOnly"] = true
            }
            if let expiresAt = cookie.expiresAt {
                // Milliseconds since epoch, aligned with Android's Long expiresAt.
                dict["expiresAt"] = NSNumber(value: Int64(expiresAt.timeIntervalSince1970 * 1000))
            }
            return dict
        }
        return ["cookies": cookieArray]
    }
}
