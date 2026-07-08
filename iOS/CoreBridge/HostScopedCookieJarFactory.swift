import Foundation
#if !READER_IOS_SHELL_CI
import ReaderCoreNetwork
#endif
import ReaderCoreProtocols

/// Host factory that produces a `ScopedCookieJar` backed by Core's
/// `BasicCookieJar`, so that iOS layers under the boundary gate
/// (`CoreIntegration`, `Features`, `Shell`, `Tests`, etc.) can obtain a
/// scoped cookie jar without directly importing `ReaderCoreNetwork`.
///
/// This file lives in `iOS/CoreBridge`, which is outside the boundary-gated
/// paths enforced by `scripts/check_ios_boundary.sh`, so it is the designated
/// seam where Core network imports are permitted on the iOS side.
public enum HostScopedCookieJarFactory {
    public static func makeBasicCookieJar() -> any ScopedCookieJar {
        #if READER_IOS_SHELL_CI
        ShellCIBasicCookieJar()
        #else
        BasicCookieJar()
        #endif
    }
}

#if READER_IOS_SHELL_CI
private actor ShellCICookieStore {
    private var scoped: [CookieJarScopeKey: [String: Cookie]] = [:]

    func matchingCookies(domain: String, path: String, scopeKey: CookieJarScopeKey) -> [Cookie] {
        (scoped[scopeKey] ?? [:]).values.filter { cookie in
            !cookie.isExpired && cookie.matches(domain: domain, path: path)
        }
    }

    func upsert(
        _ cookie: Cookie,
        key: String,
        deletionKeys: [String],
        scopeKey: CookieJarScopeKey
    ) {
        if cookie.isExpired {
            for deletionKey in deletionKeys {
                scoped[scopeKey]?.removeValue(forKey: deletionKey)
            }
            return
        }

        if scoped[scopeKey] == nil {
            scoped[scopeKey] = [:]
        }
        scoped[scopeKey]?[key] = cookie
    }

    func clear(scopeKey: CookieJarScopeKey) {
        scoped.removeValue(forKey: scopeKey)
    }

    func clearAll() {
        scoped.removeAll()
    }
}

/// Minimal shell-CI-only cookie jar used so `HostRequestRouter` can compile
/// without pulling ReaderCoreNetwork -> ReaderCoreParser into the shell gate.
private final class ShellCIBasicCookieJar: ScopedCookieJar, @unchecked Sendable {
    private let store = ShellCICookieStore()

    func getCookies(for domain: String, path: String, scopeKey: CookieJarScopeKey) async -> [Cookie] {
        let cookies = await store.matchingCookies(domain: domain, path: path, scopeKey: scopeKey)
        guard cookies.isEmpty, scopeKey != .default else { return cookies }
        return await store.matchingCookies(domain: domain, path: path, scopeKey: .default)
    }

    func setCookie(_ cookie: Cookie, scopeKey: CookieJarScopeKey) async {
        let key = cookieKey(for: cookie)
        await store.upsert(
            cookie,
            key: key,
            deletionKeys: cookieDeletionKeys(for: cookie),
            scopeKey: scopeKey
        )
    }

    func setCookies(from headerValue: String, domain: String, scopeKey: CookieJarScopeKey) async {
        guard let cookie = parseCookieHeader(headerValue, fallbackDomain: domain) else { return }
        await setCookie(cookie, scopeKey: scopeKey)
    }

    func setCookies(
        from headerValue: String,
        domain: String,
        fallbackPath: String,
        scopeKey: CookieJarScopeKey
    ) async {
        guard let cookie = parseCookieHeader(headerValue, fallbackDomain: domain, fallbackPath: fallbackPath) else { return }
        await setCookie(cookie, scopeKey: scopeKey)
    }

    func clear(scopeKey: CookieJarScopeKey) async {
        await store.clear(scopeKey: scopeKey)
    }

    func clearAll() async {
        await store.clearAll()
    }

    func getCookies(for domain: String, path: String) async -> [Cookie] {
        await getCookies(for: domain, path: path, scopeKey: .default)
    }

    func setCookie(_ cookie: Cookie) async {
        await setCookie(cookie, scopeKey: .default)
    }

    func setCookies(from headerValue: String, domain: String) async {
        await setCookies(from: headerValue, domain: domain, scopeKey: .default)
    }

    func setCookies(from headerValue: String, domain: String, fallbackPath: String) async {
        await setCookies(from: headerValue, domain: domain, fallbackPath: fallbackPath, scopeKey: .default)
    }

    func clear() async {
        await store.clear(scopeKey: .default)
    }

    private func cookieKey(for cookie: Cookie) -> String {
        "\(cookie.domain)|\(cookie.path)|\(cookie.name)"
    }

    private func cookieDeletionKeys(for cookie: Cookie) -> [String] {
        let primary = cookieKey(for: cookie)
        guard cookie.domain.hasPrefix(".") else { return [primary] }
        let exactDomain = String(cookie.domain.dropFirst())
        let legacyExact = "\(exactDomain)|\(cookie.path)|\(cookie.name)"
        return primary == legacyExact ? [primary] : [primary, legacyExact]
    }

    private func parseCookieHeader(
        _ headerValue: String,
        fallbackDomain: String,
        fallbackPath: String = "/"
    ) -> Cookie? {
        let parts = headerValue.components(separatedBy: ";")
        guard let first = parts.first,
              let eq = first.firstIndex(of: "=")
        else { return nil }

        let name = first[..<eq].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = first[first.index(after: eq)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        var domain = fallbackDomain.lowercased()
        var path = fallbackPath.isEmpty ? "/" : fallbackPath
        var secure = false
        var httpOnly = false
        var expiresAt: Date?

        for attribute in parts.dropFirst() {
            let trimmed = attribute.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()
            if lower == "secure" {
                secure = true
            } else if lower == "httponly" {
                httpOnly = true
            } else if lower.hasPrefix("domain=") {
                let rawDomain = String(trimmed.dropFirst("domain=".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !rawDomain.isEmpty {
                    domain = rawDomain.hasPrefix(".") ? rawDomain.lowercased() : ".\(rawDomain.lowercased())"
                }
            } else if lower.hasPrefix("path=") {
                let rawPath = String(trimmed.dropFirst("path=".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if rawPath.hasPrefix("/") {
                    path = rawPath
                }
            } else if lower.hasPrefix("max-age=") {
                let rawMaxAge = String(trimmed.dropFirst("max-age=".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if let seconds = TimeInterval(rawMaxAge) {
                    expiresAt = seconds <= 0 ? Date(timeIntervalSince1970: 0) : Date().addingTimeInterval(seconds)
                }
            }
        }

        return Cookie(
            name: String(name),
            value: String(value),
            domain: domain,
            path: path,
            expiresAt: expiresAt,
            secure: secure,
            httpOnly: httpOnly
        )
    }
}
#endif
