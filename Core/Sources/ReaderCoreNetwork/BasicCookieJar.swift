import Foundation
import ReaderCoreProtocols

private actor CookieStore {
    private var cookies: [String: Cookie] = [:]

    func matchingCookies(domain: String, path: String) -> [Cookie] {
        cookies.values.filter { cookie in
            !cookie.isExpired && cookie.matches(domain: domain, path: path)
        }
    }

    func upsert(_ cookie: Cookie, key: String) {
        if cookie.isExpired {
            cookies.removeValue(forKey: key)
        } else {
            cookies[key] = cookie
        }
    }

    func clear() {
        cookies.removeAll()
    }
}

public final class BasicCookieJar: CookieJar, @unchecked Sendable {
    private let store = CookieStore()

    public init() {}

    private func key(for cookie: Cookie) -> String {
        "\(cookie.domain)|\(cookie.path)|\(cookie.name)"
    }

    public func getCookies(for domain: String, path: String) async -> [Cookie] {
        await store.matchingCookies(domain: domain, path: path)
    }

    public func setCookie(_ cookie: Cookie) async {
        await store.upsert(cookie, key: key(for: cookie))
    }

    public func setCookies(from headerValue: String, domain: String) async {
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
                name = k
                value = v
            } else {
                attributes[k.lowercased()] = v
            }
        }

        guard let n = name, let v = value else { return }

        let cookieDomain = attributes["domain"] ?? domain
        let path = attributes["path"] ?? "/"
        let secure = attributes.keys.contains("secure")
        let httpOnly = attributes.keys.contains("httponly")

        var expiresAt: Date?
        if let expiresStr = attributes["expires"] {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            expiresAt = formatter.date(from: expiresStr)
        }

        let cookie = Cookie(
            name: n,
            value: v,
            domain: cookieDomain,
            path: path,
            expiresAt: expiresAt,
            secure: secure,
            httpOnly: httpOnly
        )

        await setCookie(cookie)
    }

    public func clear() async {
        await store.clear()
    }
}
