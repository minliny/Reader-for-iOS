import Foundation
import ReaderCoreProtocols

// MARK: - Scoped internal store

private actor CookieStore {
    /// Two-level dictionary: scope → cookie-key → Cookie.
    private var scoped: [CookieJarScopeKey: [String: Cookie]] = [:]

    // MARK: Scoped access

    func matchingCookies(domain: String, path: String, scopeKey: CookieJarScopeKey) -> [Cookie] {
        (scoped[scopeKey] ?? [:]).values.filter { cookie in
            !cookie.isExpired && cookie.matches(domain: domain, path: path)
        }
    }

    func upsert(_ cookie: Cookie, key: String, scopeKey: CookieJarScopeKey) {
        if cookie.isExpired {
            scoped[scopeKey]?.removeValue(forKey: key)
        } else {
            if scoped[scopeKey] == nil { scoped[scopeKey] = [:] }
            scoped[scopeKey]![key] = cookie
        }
    }

    func clear(scopeKey: CookieJarScopeKey) {
        scoped.removeValue(forKey: scopeKey)
    }

    func clearAll() {
        scoped.removeAll()
    }

    // MARK: Legacy unscoped (default scope)

    func matchingCookies(domain: String, path: String) -> [Cookie] {
        matchingCookies(domain: domain, path: path, scopeKey: .default)
    }

    func upsert(_ cookie: Cookie, key: String) {
        upsert(cookie, key: key, scopeKey: .default)
    }

    func clear() {
        clear(scopeKey: .default)
    }
}

// MARK: - BasicCookieJar

public final class BasicCookieJar: ScopedCookieJar, @unchecked Sendable {
    private let store = CookieStore()

    public init() {}

    // MARK: Cookie key

    private func cookieKey(for cookie: Cookie) -> String {
        "\(cookie.domain)|\(cookie.path)|\(cookie.name)"
    }

    // MARK: - ScopedCookieJar (scoped operations)

    public func getCookies(for domain: String, path: String, scopeKey: CookieJarScopeKey) async -> [Cookie] {
        await store.matchingCookies(domain: domain, path: path, scopeKey: scopeKey)
    }

    public func setCookie(_ cookie: Cookie, scopeKey: CookieJarScopeKey) async {
        await store.upsert(cookie, key: cookieKey(for: cookie), scopeKey: scopeKey)
    }

    public func setCookies(from headerValue: String, domain: String, scopeKey: CookieJarScopeKey) async {
        guard let cookie = parseCookieHeader(headerValue, fallbackDomain: domain) else { return }
        await setCookie(cookie, scopeKey: scopeKey)
    }

    public func clear(scopeKey: CookieJarScopeKey) async {
        await store.clear(scopeKey: scopeKey)
    }

    public func clearAll() async {
        await store.clearAll()
    }

    // MARK: - CookieJar (legacy unscoped — routed through .default scope)

    public func getCookies(for domain: String, path: String) async -> [Cookie] {
        await store.matchingCookies(domain: domain, path: path)
    }

    public func setCookie(_ cookie: Cookie) async {
        await store.upsert(cookie, key: cookieKey(for: cookie))
    }

    public func setCookies(from headerValue: String, domain: String) async {
        guard let cookie = parseCookieHeader(headerValue, fallbackDomain: domain) else { return }
        await setCookie(cookie)
    }

    public func clear() async {
        await store.clear()
    }

    // MARK: - Set-Cookie header parser (shared)

    private func parseCookieHeader(_ headerValue: String, fallbackDomain: String) -> Cookie? {
        let pairs = headerValue.components(separatedBy: ";")
        var name: String?
        var value: String?
        var attributes: [String: String] = [:]

        for (index, pair) in pairs.enumerated() {
            let trimmed = pair.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let eqIndex = trimmed.firstIndex(of: "=") else {
                if index > 0 {
                    attributes[trimmed.lowercased()] = ""
                }
                continue
            }

            let k = String(trimmed[..<eqIndex]).trimmingCharacters(in: .whitespaces)
            let v = String(trimmed[trimmed.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)

            if index == 0 {
                name  = k
                value = v
            } else {
                attributes[k.lowercased()] = v
            }
        }

        guard let n = name, let v = value else { return nil }

        let cookieDomain = attributes["domain"] ?? fallbackDomain
        let path         = attributes["path"]   ?? "/"
        let secure       = attributes.keys.contains("secure")
        let httpOnly     = attributes.keys.contains("httponly")

        var expiresAt: Date?
        if let expiresStr = attributes["expires"] {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            expiresAt = formatter.date(from: expiresStr)
        }

        return Cookie(
            name: n, value: v,
            domain: cookieDomain, path: path,
            expiresAt: expiresAt,
            secure: secure, httpOnly: httpOnly
        )
    }
}
