import Foundation
#if !READER_IOS_SHELL_CI
import ReaderCoreNetwork
#endif
import ReaderCoreProtocols

/// Host factory that produces a strictly partitioned `ScopedCookieJar`, so
/// that iOS layers under the boundary gate
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
        HostStrictScopedCookieJar()
        #endif
    }
}

/// Maps an opaque contract session id into a Host-private cookie namespace.
/// The prefix makes every explicit session disjoint from Core's reserved
/// `.default` sentinel even when the caller legitimately uses `__default__`.
public enum HostCookieSessionScope {
    public static func key(for sessionID: String) -> CookieJarScopeKey {
        CookieJarScopeKey(
            sourceId: "__reader_host_session__:\(sessionID)",
            host: "*"
        )
    }
}

#if !READER_IOS_SHELL_CI
/// Core's compatibility jar intentionally falls back from an empty named
/// scope to `.default`. A Host `sessionId`, however, is an explicit isolation
/// boundary and must never inherit ambient/default cookies. Give each scope a
/// separate BasicCookieJar instance and use only its unscoped API internally;
/// an absent named jar therefore reads as empty, with no fallback possible.
private actor HostStrictCookieJarRegistry {
    private let defaultJar = BasicCookieJar()
    private var scopedJars: [CookieJarScopeKey: BasicCookieJar] = [:]

    func jarForRead(scopeKey: CookieJarScopeKey) -> BasicCookieJar? {
        scopeKey == .default ? defaultJar : scopedJars[scopeKey]
    }

    func jarForWrite(scopeKey: CookieJarScopeKey) -> BasicCookieJar {
        if scopeKey == .default { return defaultJar }
        if let existing = scopedJars[scopeKey] { return existing }
        let created = BasicCookieJar()
        scopedJars[scopeKey] = created
        return created
    }

    func remove(scopeKey: CookieJarScopeKey) -> BasicCookieJar? {
        scopeKey == .default ? defaultJar : scopedJars.removeValue(forKey: scopeKey)
    }

    func drain() -> [BasicCookieJar] {
        let jars = [defaultJar] + Array(scopedJars.values)
        scopedJars.removeAll()
        return jars
    }
}

private final class HostStrictScopedCookieJar: ScopedCookieJar, @unchecked Sendable {
    private let registry = HostStrictCookieJarRegistry()

    func getCookies(for domain: String, path: String, scopeKey: CookieJarScopeKey) async -> [Cookie] {
        guard let jar = await registry.jarForRead(scopeKey: scopeKey) else { return [] }
        return await jar.getCookies(for: domain, path: path)
    }

    func setCookie(_ cookie: Cookie, scopeKey: CookieJarScopeKey) async {
        let jar = await registry.jarForWrite(scopeKey: scopeKey)
        await jar.setCookie(cookie)
    }

    func setCookies(from headerValue: String, domain: String, scopeKey: CookieJarScopeKey) async {
        let jar = await registry.jarForWrite(scopeKey: scopeKey)
        await jar.setCookies(from: headerValue, domain: domain)
    }

    func setCookies(
        from headerValue: String,
        domain: String,
        fallbackPath: String,
        scopeKey: CookieJarScopeKey
    ) async {
        let jar = await registry.jarForWrite(scopeKey: scopeKey)
        await jar.setCookies(from: headerValue, domain: domain, fallbackPath: fallbackPath)
    }

    func clear(scopeKey: CookieJarScopeKey) async {
        guard let jar = await registry.remove(scopeKey: scopeKey) else { return }
        await jar.clear()
    }

    func clearAll() async {
        for jar in await registry.drain() {
            await jar.clear()
        }
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
        await setCookies(
            from: headerValue,
            domain: domain,
            fallbackPath: fallbackPath,
            scopeKey: .default
        )
    }

    func clear() async {
        await clear(scopeKey: .default)
    }
}
#endif

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
        await store.matchingCookies(domain: domain, path: path, scopeKey: scopeKey)
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
