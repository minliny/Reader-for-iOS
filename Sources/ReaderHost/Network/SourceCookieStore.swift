import CryptoKit
import Foundation
import ReaderCoreBridge
import WebKit

@MainActor
final class SourceCookieStore {
    @MainActor
    final class Profile: NSObject, WKHTTPCookieStoreObserver {
        let jar: HTTPCookieStorage
        let file: URL
        private(set) var site: WKWebsiteDataStore?
        private var sitePreparation: Task<WKWebsiteDataStore, any Error>?
        private var webState: [CookieKey: HTTPCookie] = [:]
        private var revision = 0
        private var updatingWeb = 0
        private var retired = false

        init(file: URL) throws {
            // Foundation provides an independent jar for every ephemeral configuration.
            guard let jar = URLSessionConfiguration.ephemeral.httpCookieStorage else {
                throw NetworkHostFailure(code: .internal, phase: .storage, message: "Cookie storage unavailable")
            }
            self.jar = jar
            self.file = file
            super.init()
            jar.cookieAcceptPolicy = .always
            if FileManager.default.fileExists(atPath: file.path) {
                let bytes = try Data(contentsOf: file)
                guard let records = try PropertyListSerialization.propertyList(from: bytes, format: nil)
                    as? [[String: Any]] else {
                    throw NetworkHostFailure(code: .internal, phase: .storage, message: "Invalid cookie storage")
                }
                for record in records {
                    let props = Dictionary(uniqueKeysWithValues: record.map { (HTTPCookiePropertyKey(rawValue: $0.key), $0.value) })
                    if let cookie = HTTPCookie(properties: props) { jar.setCookie(cookie) }
                }
            }
        }

        func beginWebSession() async throws -> WKWebsiteDataStore {
            if let sitePreparation { return try await sitePreparation.value }
            if let site { return site }
            let store = WKWebsiteDataStore.nonPersistent()
            site = store
            let preparation = Task {
                updatingWeb += 1
                defer { updatingWeb -= 1 }
                for cookie in jar.cookies ?? [] {
                    try Task.checkCancellation()
                    await store.httpCookieStore.setCookie(cookie)
                    webState[CookieKey(cookie)] = cookie
                }
                try Task.checkCancellation()
                guard !retired else { throw CancellationError() }
                store.httpCookieStore.add(self)
                return store
            }
            sitePreparation = preparation
            defer { sitePreparation = nil }
            return try await preparation.value
        }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            Task { [weak self] in
                do { try await self?.pullFromWeb() } catch {
                    // The next explicit synchronization or cookie request surfaces storage failures.
                }
            }
        }

        func pullFromWeb() async throws {
            guard !retired, updatingWeb == 0, let store = site?.httpCookieStore else { return }
            let observedRevision = revision
            let cookies = await store.allCookies()
            guard !retired, observedRevision == revision, updatingWeb == 0 else { return }
            try Task.checkCancellation()
            let current = Dictionary(cookies.map { (CookieKey($0), $0) }, uniquingKeysWith: { _, newest in newest })
            let removed = webState.filter { current[$0.key] == nil }
            let changed = current.filter { webState[$0.key] != $0.value }
            guard !removed.isEmpty || !changed.isEmpty else { return }
            for cookie in removed.values { jar.deleteCookie(cookie) }
            for cookie in changed.values { jar.setCookie(cookie) }
            revision += 1
            webState = current
            try persist()
        }

        func write(_ cookie: HTTPCookie) async throws {
            guard !retired else { throw CancellationError() }
            revision += 1
            let expired = cookie.expiresDate.map { $0 <= Date() } ?? false
            if expired {
                // Compare the actual jar identity before removing an expiry marker.
                for previous in (jar.cookies ?? []) where CookieKey(previous) == CookieKey(cookie) {
                    jar.deleteCookie(previous)
                }
            } else {
                jar.setCookie(cookie)
            }
            try persist()
            guard let store = site?.httpCookieStore else { return }
            updatingWeb += 1
            defer {
                updatingWeb -= 1
                revision += 1
            }
            let key = CookieKey(cookie)
            if expired {
                await store.deleteCookie(webState.removeValue(forKey: key) ?? cookie)
            } else {
                webState[key] = cookie
                await store.setCookie(cookie)
            }
            guard !retired else { throw CancellationError() }
        }

        func persist() throws {
            guard !retired else { throw CancellationError() }
            let records = (jar.cookies ?? []).compactMap { cookie in
                cookie.properties?.reduce(into: [String: Any]()) { record, property in
                    if let url = property.value as? URL {
                        record[property.key.rawValue] = url.absoluteString
                    } else {
                        record[property.key.rawValue] = property.value
                    }
                }
            }
            let data = try PropertyListSerialization.data(fromPropertyList: records, format: .binary, options: 0)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }

        func clear() async throws {
            retired = true
            sitePreparation?.cancel()
            site?.httpCookieStore.remove(self)
            for cookie in jar.cookies ?? [] { jar.deleteCookie(cookie) }
            if FileManager.default.fileExists(atPath: file.path) {
                try FileManager.default.removeItem(at: file)
            }
            if let site {
                _ = await sitePreparation?.result
                await site.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
            }
            site = nil
        }
    }

    private let directory: URL
    private var profiles: [String: Profile] = [:]

    init(directory: URL) { self.directory = directory }

    func profile(session: String?, url: URL? = nil, domain: String? = nil) throws -> Profile {
        let key: String
        if let session, !session.isEmpty {
            key = "source:\(session)"
        } else if let host = (url?.host() ?? domain).map(Self.normalizedDomain), !host.isEmpty {
            key = "domain:\(host)"
        } else {
            throw NetworkHostFailure(code: .invalidResponse, phase: .request, message: "Cookie scope is required")
        }
        if let existing = profiles[key] { return existing }
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        let value = try Profile(file: directory.appendingPathComponent(hash + ".plist"))
        profiles[key] = value
        return value
    }

    func clear(sourceId: String) async throws {
        let profile = try profile(session: sourceId)
        profiles.removeValue(forKey: "source:\(sourceId)")
        try await profile.clear()
    }

    func get(_ request: M2HostCookieGetRequest) async throws -> M2HostCookieGetResponse {
        let url = try request.url.map(hostHTTPURL)
        let profile = try profile(session: request.sessionId, url: url, domain: request.domain)
        try await profile.pullFromWeb()
        let cookies = url.map { profile.jar.cookies(for: $0) ?? [] } ?? profile.jar.cookies ?? []
        return .init(cookies: cookies
            .filter { request.name == nil || request.name == $0.name }
            .filter { cookie in
                guard let domain = request.domain else { return true }
                return Self.domain(cookie.domain, allows: domain)
            }.map(Self.record))
    }

    func set(_ request: M2HostCookieSetRequest) async throws -> M2HostCookieSetResponse {
        let value = request.cookie
        let url = try request.url.map(hostHTTPURL)
        guard let domain = value.domain ?? url?.host(), !domain.isEmpty,
              value.domain == nil || url == nil || Self.domain(domain, allows: url?.host() ?? "") else {
            throw NetworkHostFailure(code: .permissionDenied, phase: .request, message: "Cookie domain does not match URL")
        }
        var props: [HTTPCookiePropertyKey: Any] = [
            .name: value.name, .value: value.value ?? "", .domain: domain, .path: value.path ?? "/",
        ]
        if let url { props[.originURL] = url }
        if value.secure == true { props[.secure] = "TRUE" }
        if value.httpOnly == true { props[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
        if let policy = value.sameSite { props[HTTPCookiePropertyKey("SameSite")] = policy }
        if let expiresAt = value.expiresAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let expiry = formatter.date(from: expiresAt) ?? ISO8601DateFormatter().date(from: expiresAt) else {
                throw NetworkHostFailure(code: .invalidResponse, phase: .request, message: "Invalid cookie expiry")
            }
            props[.expires] = expiry
        }
        guard let cookie = HTTPCookie(properties: props) else {
            throw NetworkHostFailure(code: .invalidResponse, phase: .request, message: "Invalid cookie")
        }
        try await profile(session: request.sessionId, url: url, domain: domain).write(cookie)
        return .init(stored: true)
    }

    private static func record(_ value: HTTPCookie) -> M2HostCookieRecord {
        .init(name: value.name, value: value.value, domain: value.domain, path: value.path,
              expiresAt: value.expiresDate?.ISO8601Format(), httpOnly: value.isHTTPOnly,
              secure: value.isSecure, sameSite: value.sameSitePolicy?.rawValue)
    }

    private static func domain(_ domain: String, allows candidate: String) -> Bool {
        let base = normalizedDomain(domain)
        let host = normalizedDomain(candidate)
        return host == base || host.hasSuffix("." + base)
    }

    private static func normalizedDomain(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}

private struct CookieKey: Hashable {
    let name: String
    let domain: String
    let path: String

    init(_ cookie: HTTPCookie) {
        (name, domain, path) = (cookie.name, cookie.domain, cookie.path)
    }
}
