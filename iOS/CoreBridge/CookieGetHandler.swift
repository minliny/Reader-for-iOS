// CoreBridge
//
// CookieGetHandler: host-side capability handler for `cookie.get`.
//
// Mirrors Android `CookieGetHandler.kt` JSON contract:
// - Input params: `{url?, domain?, name?, sessionId?}`
// - Reads cookies for the URL/domain from `ScopedCookieJar`. A non-empty
//   `sessionId` is an opaque jar namespace; Host never parses its meaning.
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
    /// - Parameter params: `{url?, domain?, name?, sessionId?}`.
    /// - Returns: `{cookies: [{name, value, domain, path, ...}]}`.
    public func handle(params: [String: Any]) async throws -> [String: Any] {
        let parsedURL: URL? = {
            guard let raw = params["url"] as? String, !raw.isEmpty else { return nil }
            return URL(string: raw)
        }()
        let explicitDomain = (params["domain"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let host = parsedURL?.host ?? explicitDomain, !host.isEmpty else {
            throw CookieHandlerError.invalidParams("cookie.get requires url or domain on iOS")
        }
        let path = parsedURL?.path.isEmpty == false ? (parsedURL?.path ?? "/") : "/"
        let sessionID = (params["sessionId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if params["sessionId"] != nil, sessionID?.isEmpty != false {
            throw CookieHandlerError.invalidParams("cookie.get sessionId must be non-blank")
        }
        let cookies: [Cookie]
        if let sessionID {
            cookies = await cookieJar.getCookies(
                for: host,
                path: path,
                scopeKey: HostCookieSessionScope.key(for: sessionID)
            )
        } else {
            cookies = await cookieJar.getCookies(for: host, path: path)
        }
        let requestedName = (params["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if params["name"] != nil, requestedName?.isEmpty != false {
            throw CookieHandlerError.invalidParams("cookie.get name must be non-blank")
        }
        let filtered = requestedName.map { name in cookies.filter { $0.name == name } } ?? cookies
        let cookieArray: [[String: Any]] = filtered.map { cookie in
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
                // Core's frozen HostCookieRecord uses an RFC3339 string.
                dict["expiresAt"] = ISO8601DateFormatter().string(from: expiresAt)
            }
            return dict
        }
        return ["cookies": cookieArray]
    }
}
