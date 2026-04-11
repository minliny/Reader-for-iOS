import Foundation
import ReaderCoreModels

// MARK: - Cookie types (defined here so adapters need only ReaderCoreProtocols)

public struct Cookie: Sendable, Equatable {
    public var name: String
    public var value: String
    public var domain: String
    public var path: String
    public var expiresAt: Date?
    public var secure: Bool
    public var httpOnly: Bool

    public init(
        name: String,
        value: String,
        domain: String,
        path: String = "/",
        expiresAt: Date? = nil,
        secure: Bool = false,
        httpOnly: Bool = false
    ) {
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expiresAt = expiresAt
        self.secure = secure
        self.httpOnly = httpOnly
    }

    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    public func matches(domain targetDomain: String, path targetPath: String = "/") -> Bool {
        let normalizedDomain = domain.lowercased()
        let normalizedTarget = targetDomain.lowercased()

        let domainMatches: Bool
        if normalizedDomain.hasPrefix(".") {
            domainMatches = normalizedTarget.hasSuffix(normalizedDomain) || normalizedTarget == String(normalizedDomain.dropFirst())
        } else {
            domainMatches = normalizedTarget == normalizedDomain
        }

        guard domainMatches else { return false }
        return matches(path: targetPath)
    }

    public func matches(path targetPath: String) -> Bool {
        if path == "/" {
            return true
        }
        guard targetPath.hasPrefix(path) else {
            return false
        }
        if targetPath == path || path.hasSuffix("/") {
            return true
        }
        let boundaryIndex = targetPath.index(targetPath.startIndex, offsetBy: path.count)
        return boundaryIndex < targetPath.endIndex && targetPath[boundaryIndex] == "/"
    }
}

public protocol CookieJar: Sendable {
    func getCookies(for domain: String, path: String) async -> [Cookie]
    func setCookie(_ cookie: Cookie) async
    func setCookies(from headerValue: String, domain: String) async
    func clear() async
}

// MARK: - Cookie Jar Scope Key

/// Identifies a uniquely isolated cookie namespace.
///
/// Isolation contract:
///   - Same host, different sourceId   → different jar partition (no cross-source leakage)
///   - Same sourceId, different host   → different jar partition (no cross-host leakage)
///   - Same sourceId + host            → same jar partition (cookie sharing within a session)
public struct CookieJarScopeKey: Hashable, Codable, Sendable {
    public let sourceId: String
    public let host: String

    public init(sourceId: String, host: String) {
        self.sourceId = sourceId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.host     = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sentinel scope used by the unscoped `CookieJar` protocol methods
    /// for backwards-compatibility with code that does not supply a scope key.
    public static let `default` = CookieJarScopeKey(sourceId: "__default__", host: "*")
}

// MARK: - Scoped Cookie Jar

/// Extends `CookieJar` with per-scope operations.
/// `BasicCookieJar` conforms to this protocol; URLSessionHTTPClient uses it
/// when `HTTPRequest.cookieScopeKey` is set.
public protocol ScopedCookieJar: CookieJar {
    /// Read cookies for `domain`/`path` within `scopeKey` only.
    func getCookies(for domain: String, path: String, scopeKey: CookieJarScopeKey) async -> [Cookie]

    /// Write a single cookie into `scopeKey`.
    func setCookie(_ cookie: Cookie, scopeKey: CookieJarScopeKey) async

    /// Parse and write `Set-Cookie` header value into `scopeKey`.
    func setCookies(from headerValue: String, domain: String, scopeKey: CookieJarScopeKey) async

    /// Remove all cookies belonging to `scopeKey` without touching other scopes.
    func clear(scopeKey: CookieJarScopeKey) async

    /// Remove all cookies across every scope.
    func clearAll() async
}

/// Narrow adapter-side cookie scope access used by network bootstrap helpers.
/// Policy callers should depend on higher-level services instead of this protocol.
public protocol CookieScopeManaging: Sendable {
    func clearCookies(in scopeKey: CookieJarScopeKey) async
}

// MARK: - HTTP primitives

public struct HTTPRequest: Sendable, Equatable {
    public var url: String
    public var method: String
    public var headers: [String: String]
    public var requiredHeaders: [String]
    public var body: Data?
    public var timeout: TimeInterval
    public var useCookieJar: Bool
    public var requiresCookieJar: Bool
    /// When set, `URLSessionHTTPClient` reads and writes cookies exclusively in this
    /// scope partition.  `nil` falls back to the legacy unscoped jar behaviour.
    public var cookieScopeKey: CookieJarScopeKey?

    public init(
        url: String,
        method: String = "GET",
        headers: [String: String] = [:],
        requiredHeaders: [String] = [],
        body: Data? = nil,
        timeout: TimeInterval = 15,
        useCookieJar: Bool = false,
        requiresCookieJar: Bool = false,
        cookieScopeKey: CookieJarScopeKey? = nil
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.requiredHeaders = requiredHeaders
        self.body = body
        self.timeout = timeout
        self.useCookieJar = useCookieJar || requiresCookieJar
        self.requiresCookieJar = requiresCookieJar
        self.cookieScopeKey = cookieScopeKey
    }
}

public struct HTTPResponse: Sendable, Equatable {
    public var statusCode: Int
    public var headers: [String: String]
    public var data: Data

    public init(statusCode: Int, headers: [String: String], data: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }
}

public protocol HTTPClient: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public protocol RequestBuilder: Sendable {
    func makeSearchRequest(source: BookSource, query: SearchQuery) throws -> HTTPRequest
    func makeTOCRequest(source: BookSource, detailURL: String) throws -> HTTPRequest
    func makeContentRequest(source: BookSource, chapterURL: String) throws -> HTTPRequest
}
