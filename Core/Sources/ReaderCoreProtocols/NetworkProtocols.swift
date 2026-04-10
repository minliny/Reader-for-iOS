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

// MARK: - HTTP primitives

public struct HTTPRequest: Sendable, Equatable {
    public var url: String
    public var method: String
    public var headers: [String: String]
    public var body: Data?
    public var timeout: TimeInterval
    public var useCookieJar: Bool

    public init(
        url: String,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 15,
        useCookieJar: Bool = false
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.useCookieJar = useCookieJar
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
