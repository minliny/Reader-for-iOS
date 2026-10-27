import Foundation

/// One operation's native cookie store. URLSession/WebKit may change this
/// candidate, but readers cannot observe it until the durable commit succeeds.
final class ReaderSourceCookieOperation: @unchecked Sendable {
    let sourceID: String
    let originalCookies: [HTTPCookie]
    let jar: HTTPCookieStorage
    private let lock = NSLock()
    private enum State { case pending, cancelled, committing, finished }
    private var state = State.pending

    fileprivate init(sourceID: String, cookies: [HTTPCookie]) {
        self.sourceID = sourceID
        self.originalCookies = cookies
        self.jar = ReaderSourceCookieStore.makeJar(cookies)
    }

    func replaceCookies(_ cookies: [HTTPCookie]) {
        for cookie in jar.cookies ?? [] { jar.deleteCookie(cookie) }
        for cookie in cookies { jar.setCookie(cookie) }
    }

    /// `cookie.set` omits HttpOnly when it only intends to change a value.
    /// Keep an existing protection unless the record explicitly supplies it.
    /// Foundation can silently reject a non-HTTP overwrite of an HttpOnly
    /// cookie, so only acknowledge the write after observing the native result.
    func storeCookie(_ requested: HTTPCookie, preservingHTTPOnly: Bool) -> Bool {
        var cookie = requested
        let existing = (jar.cookies ?? []).first { ReaderSourceCookieStore.identity($0) == ReaderSourceCookieStore.identity(cookie) }
        if preservingHTTPOnly, existing?.isHTTPOnly == true, !cookie.isHTTPOnly {
            guard var properties = cookie.properties else { return false }
            properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE"
            guard let protected = HTTPCookie(properties: properties) else { return false }
            cookie = protected
        }
        jar.setCookie(cookie)
        let stored = (jar.cookies ?? []).first { ReaderSourceCookieStore.identity($0) == ReaderSourceCookieStore.identity(cookie) }
        if let expiry = cookie.expiresDate, expiry <= Date() { return stored == nil }
        guard let stored else { return false }
        return stored.value == cookie.value && stored.isSecure == cookie.isSecure && stored.isHTTPOnly == cookie.isHTTPOnly
            && stored.expiresDate == cookie.expiresDate
            && (stored.properties?[HTTPCookiePropertyKey("SameSite")] as? String) == (cookie.properties?[HTTPCookiePropertyKey("SameSite")] as? String)
    }

    func cancel() { lock.withLock { if state == .pending { state = .cancelled } } }

    /// Called under the source store's commit lock and the transport owner lock.
    /// Cancellation after this point cannot revoke an accepted durable write.
    fileprivate func admitCommit(authorize: () -> Bool) -> Bool {
        lock.withLock {
            guard state == .pending else { return false }
            guard authorize() else { state = .cancelled; return false }
            state = .committing
            return true
        }
    }

    fileprivate func finish() { lock.withLock { state = .finished } }
}

/// Native Cookie algorithms stay in Foundation. This owner only coordinates
/// Reader operation deltas and a whole-source durable snapshot.
final class ReaderSourceCookieStore: @unchecked Sendable {
    typealias Load = (String) throws -> [HTTPCookie]
    typealias Save = (String, [HTTPCookie]) throws -> Void
    private let lock = NSLock()
    private let load: Load
    private let save: Save
    // Core source identity and Keychain accounts preserve original UTF-8.
    // String keys would merge canonically equivalent, byte-distinct sources.
    private var jars: [Data: HTTPCookieStorage] = [:]

    private final class WeakStore {
        weak var value: ReaderSourceCookieStore?
        init(_ value: ReaderSourceCookieStore) { self.value = value }
    }
    private static let registryLock = NSLock()
    private static var stores: [String: WeakStore] = [:]

    /// Coordinates live transports in this process. Keychain has no compare and
    /// swap for this blob, so sharing it with another process remains unsupported.
    static func shared(namespace: String, load: @escaping Load, save: @escaping Save) -> ReaderSourceCookieStore {
        registryLock.withLock {
            if let existing = stores[namespace]?.value { return existing }
            let store = ReaderSourceCookieStore(load: load, save: save)
            stores[namespace] = WeakStore(store)
            return store
        }
    }

    init(load: @escaping Load, save: @escaping Save) { self.load = load; self.save = save }

    fileprivate static func makeJar(_ cookies: [HTTPCookie]) -> HTTPCookieStorage {
        let jar = URLSessionConfiguration.ephemeral.httpCookieStorage!
        for cookie in cookies { jar.setCookie(cookie) }
        return jar
    }

    private func canonicalJar(sourceID: String) throws -> HTTPCookieStorage {
        let sourceKey = Data(sourceID.utf8)
        if let jar = jars[sourceKey] { return jar }
        // A failed load must not become a cached empty jar and later overwrite
        // credentials that were merely unavailable while Keychain was locked.
        let jar = Self.makeJar(try load(sourceID))
        jars[sourceKey] = jar
        return jar
    }

    func snapshot(sourceID: String) throws -> [HTTPCookie] {
        try lock.withLock { try canonicalJar(sourceID: sourceID).cookies ?? [] }
    }

    func cookies(sourceID: String, for url: URL?) throws -> [HTTPCookie] {
        try lock.withLock {
            let jar = try canonicalJar(sourceID: sourceID)
            return url.map { jar.cookies(for: $0) ?? [] } ?? jar.cookies ?? []
        }
    }

    func begin(sourceID: String, originalCookies: [HTTPCookie]? = nil) throws -> ReaderSourceCookieOperation {
        let cookies = try originalCookies ?? snapshot(sourceID: sourceID)
        return ReaderSourceCookieOperation(sourceID: sourceID, cookies: cookies)
    }

    /// An HTTP status (including 4xx/5xx) and a non-cancel failure can carry
    /// accepted response cookies. Preserve those deltas before returning the
    /// original result; explicit cancellation never publishes its candidate.
    func complete<T>(_ operation: ReaderSourceCookieOperation, result: Result<T, Error>,
                     authorizeCommit: () -> Bool = { true }) throws -> T {
        if case .failure(let error) = result, Self.isCancellation(error) {
            operation.cancel()
            throw error
        }
        try lock.withLock {
            // The callback checks the live request owner while holding its lock;
            // admitCommit shares the operation state with direct cancellation.
            guard operation.admitCommit(authorize: authorizeCommit) else { throw URLError(.cancelled) }
            defer { operation.finish() }
            let current = try canonicalJar(sourceID: operation.sourceID)
            let candidate = Self.makeJar(current.cookies ?? [])
            Self.mergeCookieChanges(original: operation.originalCookies, updated: operation.jar.cookies ?? [], into: candidate)
            let cookies = candidate.cookies ?? []
            if Self.equalCookies(current.cookies ?? [], cookies) { return }
            try save(operation.sourceID, cookies)
            // Readers and all other writers use this same lock. No canonical
            // mutable reference escapes, and a failed save publishes nothing.
            jars[Data(operation.sourceID.utf8)] = candidate
        }
        return try result.get()
    }

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let platform = error as NSError
        return platform.domain == NSURLErrorDomain && platform.code == URLError.cancelled.rawValue
    }

    fileprivate static func identity(_ cookie: HTTPCookie) -> String {
        cookie.domain + "\u{0}" + cookie.path + "\u{0}" + cookie.name
    }
    private static func records(_ cookies: [HTTPCookie]) -> [String: HTTPCookie] {
        Dictionary(cookies.map { (identity($0), $0) }, uniquingKeysWith: { _, last in last })
    }
    private static func equalCookies(_ lhs: [HTTPCookie], _ rhs: [HTTPCookie]) -> Bool {
        let left = records(lhs), right = records(rhs)
        return left.count == right.count && left.allSatisfy { key, cookie in
            right[key].map { NSDictionary(dictionary: cookie.properties ?? [:]).isEqual(to: $0.properties ?? [:]) } ?? false
        }
    }
    static func mergeCookieChanges(original: [HTTPCookie], updated: [HTTPCookie], into jar: HTTPCookieStorage) {
        let before = records(original), after = records(updated)
        let current = records(jar.cookies ?? [])
        // Unchanged snapshot entries do not erase concurrent operation changes.
        // For the same identity, the last admitted durable commit wins.
        for key in before.keys where after[key] == nil {
            if let cookie = current[key] { jar.deleteCookie(cookie) }
        }
        for (key, cookie) in after {
            if let old = before[key], NSDictionary(dictionary: old.properties ?? [:]).isEqual(to: cookie.properties ?? [:]) { continue }
            // This private candidate replays a snapshot already accepted by the
            // operation's native jar/WebKit. setCookie alone would reapply the
            // non-HTTP HttpOnly overwrite restriction and silently lose it.
            if let old = current[key] { jar.deleteCookie(old) }
            jar.setCookie(cookie)
        }
    }
}
