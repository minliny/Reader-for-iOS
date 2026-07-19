// CoreBridge
//
// HostRequestRouter: routes Rust Core `host.request` events (capability=http.execute,
// cookie.get, cookie.set, webview.evaluateJavaScript, anti_bot.challenge,
// media.download) to the iOS Host's executors, then sends `host.complete` or
// `host.error` back to Core.
//
// This is the Core/Host boundary wiring: Core produces request descriptors,
// Host executes real HTTP via URLSession, manages cookies via the scoped jar,
// renders via WKWebView, runs anti-bot detection, and downloads media. Core
// never opens a socket, touches the cookie store, or drives a WebView directly.
//
// S6.1: This router is the single HTTP execution path for Rust Core's
// http.execute capability. It is shared by all RustCore*Service adapters.
//
// login_cookie lane: the router also handles cookie.get / cookie.set so Core
// can read and write host-side cookies through the same boundary contract as
// Android (cookie.get → {cookies:[...]}, cookie.set → {stored:true}).
//
// webview_render / anti_bot / media_download lanes: the router dispatches
// `webview.evaluateJavaScript`, `anti_bot.challenge`, and `media.download`
// host requests to the corresponding handlers. Executors are wired with REAL
// implementations via `RustCoreServiceSupport.makeRouter`:
// - `media.download` → `URLSessionMediaDownloadExecutor` (cross-platform:
//   URLSession + CryptoKit sha256 + range / ETag / 304 + temp-file cache).
// - `webview.evaluateJavaScript` → `WKWebViewExecutor` (iOS only; macOS
//   `swift build` leaves it nil — the lane FAILS CLOSED with
//   `webViewExecutorNotConfigured`, it is NOT a stub executor that returns
//   `notImplemented`).
// - `anti_bot.challenge` → `WKAntiBotExecutor` (iOS only for the L2 WKWebView
//   fallback; L1 URLSession HTTP fetch is cross-platform, but the executor
//   type is iOS-only because it imports WebKit for the L2 path).
//
// On macOS `swift build`, the iOS-only executors are nil and the router throws
// a structured `*ExecutorNotConfigured` error — NOT a generic stub throw. The
// dispatch path is complete so a Core `host.request` for these lanes reaches
// the handler on every platform, never a "capability not supported" rejection.
//
// Tier caveat (do NOT conflate with "backend ready"): real-executor proof
// still has device-tier gaps — WKWebView login-cookie persistence across
// `WKWebsiteDataStore`, `cookieJarId` binding for `WKAntiBotExecutor`, slider
// / reCAPTCHA human-verifier delegation, background URLSession for large media
// downloads, and real-device user-agent / JIT differences for anti-bot JS
// challenge solving. macOS `swift build` proving the dispatch path is NOT the
// same as the host backend being release-ready; simulator / real-device proof
// is required per the `HostCapabilityTier` manifest.

import CoreFoundation
import CryptoKit
import Foundation
import Security
import ReaderCoreProtocols
import ReaderCoreNativeAdapter
#if canImport(UIKit)
import UIKit
#endif

/// Errors thrown by `HostRequestRouter`.
public enum HostRequestRouterError: Error, Equatable, LocalizedError {
    case runtimeNotBooted
    case missingOperationId
    case unexpectedHostRequestType(String)
    case unexpectedCapability(String)
    case hostHTTPFailed(String)
    case cookieJarNotConfigured
    case webViewExecutorNotConfigured
    case antiBotExecutorNotConfigured
    case mediaDownloadExecutorNotConfigured

    public var errorDescription: String? {
        switch self {
        case .runtimeNotBooted: return "Rust Core runtime is not booted"
        case .missingOperationId: return "host.request missing operationId"
        case .unexpectedHostRequestType(let t): return "expected host.request, got \(t)"
        case .unexpectedCapability(let c): return "unsupported host.request capability: \(c)"
        case .hostHTTPFailed(let m): return "Host HTTP failed: \(m)"
        case .cookieJarNotConfigured: return "cookie.get/cookie.set requires a ScopedCookieJar"
        case .webViewExecutorNotConfigured: return "webview.evaluateJavaScript requires a WebViewExecutor"
        case .antiBotExecutorNotConfigured: return "anti_bot.challenge requires an AntiBotExecutor"
        case .mediaDownloadExecutorNotConfigured: return "media.download requires a MediaDownloadExecutor"
        }
    }
}

/// Host-side provider for Legado-compatible `source.getLoginHeaderMap`.
///
/// The production implementation is Keychain-backed. Keeping this behind a
/// provider lets tests inject deterministic stubs without persisting secrets.
public protocol SourceLoginHeaderMapProvider: Sendable {
    func loginHeaderMap(sourceId: String?, url: String?, host: String?) async throws -> [String: String]?
}

/// Empty provider retained for tests / explicit opt-out. Returns an empty
/// map for every source. The production default is
/// `KeychainSourceLoginHeaderStore.shared`.
public struct EmptySourceLoginHeaderMapProvider: SourceLoginHeaderMapProvider {
    public init() {}

    public func loginHeaderMap(sourceId: String?, url: String?, host: String?) async throws -> [String: String]? {
        [:]
    }
}

/// Internal error used to signal that the anti_bot lane detected a challenge
/// (CHALLENGE_REQUIRED). The router catches this in `handleHostRequest` and
/// sends `host.error` with the CHALLENGE_REQUIRED code and the diagnostics
/// details, so Core can route the source into its `host_required` channel
/// (fail-closed, no retry). Internal because this is an implementation detail
/// of the router's dispatch; callers only see the `host.error` event sent into
/// the runtime.
internal struct AntiBotChallengeRequiredError: Error {
    let diagnostics: [String: Any]
}

/// Routes Core `host.request` events to host-side executors and replies with
/// `host.complete` / `host.error`.
///
/// Supported capabilities:
/// - `http.execute`: delegates to `HTTPClient.send`, returns
///   `{status, headers, body, finalUrl?, cookies?}`.
/// - `cookie.get`: reads cookies from `ScopedCookieJar` for the URL's host/path,
///   returns `{cookies: [{name, value, domain, path, secure?, httpOnly?, expiresAt?}]}`.
/// - `cookie.set`: writes a cookie into `ScopedCookieJar`, returns `{stored: true}`.
/// - `webview.evaluateJavaScript`: delegates to `WebViewExecutor`, returns
///   `{value: Any, finalUrl?, title?}`. Throws `webViewExecutorNotConfigured`
///   if no executor is wired.
/// - `anti_bot.challenge`: delegates to `AntiBotChallengeHandler`, returns
///   `{body, finalUrl}` on clean response or sends `host.error` with code
///   `CHALLENGE_REQUIRED` on challenge detection. Throws
///   `antiBotExecutorNotConfigured` if no executor is wired.
/// - `media.download`: delegates to `MediaDownloadHandler`, returns
///   `{resourceId, tempPath?, statusCode, contentType?, contentLength?, etag?,
///   byteLength, sha256?, fromCache, finalUrl?}`. Throws
///   `mediaDownloadExecutorNotConfigured` if no executor is wired.
/// - `source.getLoginHeaderMap`: delegates to `SourceLoginHeaderMapProvider`
///   (default `KeychainSourceLoginHeaderStore`), returns `{headers, headerMap}`.
/// - `credential.get`: reads a Keychain item by `{service, account}`,
///   returns `{value, found}`.
/// - `credential.set`: writes a Keychain item, returns `{stored: true}`.
/// - `credential.delete`: deletes a Keychain item, returns
///   `{deleted: true, existed: Bool}`.
/// - `credential.resolve`: resolves a credential by logical `key` (deriving
///   `service` from `sourceUrl` / `sourceId`), returns `{value, found}`.
///
/// The router is a stateless helper: each call handles exactly one
/// `host.request` event for one `requestId`. Callers (RustCore*Service)
/// poll the runtime for the host.request, then invoke `handleHostRequest`
/// with the event + original requestId.
public struct HostRequestRouter: Sendable {
    private let httpClient: HTTPClient
    private let runtime: ReaderCoreNativeRuntime
    private let cookieJar: ScopedCookieJar?
    private let webViewExecutor: WebViewExecutor?
    private let antiBotExecutor: AntiBotExecutor?
    private let mediaDownloadExecutor: MediaDownloadExecutor?
    private let sourceLoginHeaderMapProvider: any SourceLoginHeaderMapProvider
    private let allowedCapabilities: Set<String>

    public init(
        httpClient: HTTPClient,
        runtime: ReaderCoreNativeRuntime,
        cookieJar: ScopedCookieJar? = nil,
        webViewExecutor: WebViewExecutor? = nil,
        antiBotExecutor: AntiBotExecutor? = nil,
        mediaDownloadExecutor: MediaDownloadExecutor? = nil,
        sourceLoginHeaderMapProvider: any SourceLoginHeaderMapProvider = KeychainSourceLoginHeaderStore.shared,
        allowedCapabilities: Set<String> = Set(ReaderSlice11HostManifest.capabilities)
    ) {
        self.httpClient = httpClient
        self.runtime = runtime
        self.cookieJar = cookieJar
        self.webViewExecutor = webViewExecutor
        self.antiBotExecutor = antiBotExecutor
        self.mediaDownloadExecutor = mediaDownloadExecutor
        self.sourceLoginHeaderMapProvider = sourceLoginHeaderMapProvider
        self.allowedCapabilities = allowedCapabilities
    }

    /// Handle a single `host.request` event for `http.execute` / `cookie.get` /
    /// `cookie.set` / `webview.evaluateJavaScript` / `anti_bot.challenge` /
    /// `media.download`:
    /// 1. Dispatch on `capability` to the right host executor.
    /// 2. Send `host.complete` (with the executor's result) or `host.error`.
    public func handleHostRequest(
        _ event: ReaderCoreNativeEvent,
        transportRequestID: String? = nil,
        shouldDiscard: @escaping @Sendable () -> Bool = { false }
    ) async throws {
        // A request-scoped Core cancellation may race a host callback. Do not
        // begin a new host operation or send a late host.complete/error once
        // the owning transaction has been invalidated.
        guard !shouldDiscard() else { return }
        guard event.type == "host.request" else {
            throw HostRequestRouterError.unexpectedHostRequestType(event.type)
        }
        let capability = event.capability ?? ""
        // A handler being implemented is not sufficient authority to expose
        // it to Core. The instance allowlist defaults to the exact platform
        // manifest advertised during runtime boot, preventing private helper
        // lanes from remaining reachable through a forged host.request.
        guard Self.supportedCapabilities.contains(capability),
              allowedCapabilities.contains(capability) else {
            throw HostRequestRouterError.unexpectedCapability(capability)
        }
        guard let operationId = event.operationId else {
            throw HostRequestRouterError.missingOperationId
        }
        let params: [String: Any]
        if let hostParams = event.hostParams {
            params = hostParams
        } else if capability == "source.getLoginHeaderMap" {
            params = [:]
        } else {
            try sendHostError(
                operationId: operationId,
                code: "INTERNAL",
                message: "host.request missing params"
            )
            return
        }

        do {
            let result: [String: Any]
            switch capability {
            case "host.smoke.echo":
                result = try executeHostSmokeEcho(params: params)
            case "http.execute":
                result = try await executeHTTP(
                    params: params,
                    transportRequestID: transportRequestID
                )
            case "cookie.get":
                result = try await executeCookieGet(params: params)
            case "cookie.set":
                result = try await executeCookieSet(params: params)
            case "webview.evaluateJavaScript":
                result = try await executeWebViewEvaluate(params: params)
            case "file.read":
                result = try executeFileRead(params: params)
            case "file.write":
                result = try executeFileWrite(params: params)
            case "cache.get":
                result = try HostCacheStore.shared.get(params: params)
            case "cache.put":
                result = try HostCacheStore.shared.put(params: params)
            case "log.emit":
                result = try executeLogEmit(params: params)
            case "time.now":
                result = try executeTimeNow(params: params)
            case "system.info":
                result = try executeSystemInfo(params: params)
            case "persistence.get":
                result = try HostPersistenceStore.shared.get(params: params)
            case "persistence.put":
                result = try HostPersistenceStore.shared.put(params: params)
            case "media.download":
                result = try await executeMediaDownload(params: params)
            case "source.getLoginHeaderMap":
                result = try await executeSourceGetLoginHeaderMap(params: params)
            case "credential.get":
                result = try HostCredentialStore.shared.get(params: params)
            case "credential.set":
                result = try HostCredentialStore.shared.set(params: params)
            case "credential.delete":
                result = try HostCredentialStore.shared.delete(params: params)
            case "credential.resolve":
                result = try HostCredentialStore.shared.resolve(params: params)
            case "anti_bot.challenge":
                result = try await executeAntiBotChallenge(params: params)
            default:
                throw HostRequestRouterError.unexpectedCapability(capability)
            }
            guard !shouldDiscard() else { return }
            try sendHostComplete(operationId: operationId, result: result)
        } catch let challengeError as AntiBotChallengeRequiredError {
            // anti_bot challenge detection: send host.error with the
            // CHALLENGE_REQUIRED code + diagnostics details so Core can route
            // the source into its host_required channel (fail-closed, no retry).
            let diagnostics = challengeError.diagnostics
            let code = diagnostics["code"] as? String ?? "CHALLENGE_REQUIRED"
            let message = diagnostics["message"] as? String ?? "anti-bot challenge required"
            let details = diagnostics["details"] as? [String: Any] ?? [:]
            guard !shouldDiscard() else { return }
            try sendHostError(
                operationId: operationId,
                code: code,
                message: message,
                details: details
            )
        } catch {
            guard !shouldDiscard() else { return }
            try sendHostError(
                operationId: operationId,
                code: "INTERNAL",
                message: error.localizedDescription
            )
        }
    }

    /// Supported capability names routed by this router.
    /// Covers all 15 Core `HostCapability` variants (host.rs enum), the
    /// Legado compatibility `source.getLoginHeaderMap` shim, plus the iOS-side
    /// `anti_bot.challenge` lane (which aggregates http.execute + cookie.get/set
    /// + webview.evaluateJavaScript via `WKAntiBotExecutor`).
    private static let supportedCapabilities: Set<String> = [
        // Core 15 HostCapability variants (host.rs)
        "host.smoke.echo",
        "http.execute",
        "cookie.get",
        "cookie.set",
        "webview.evaluateJavaScript",
        "file.read",
        "file.write",
        "cache.get",
        "cache.put",
        "log.emit",
        "time.now",
        "system.info",
        "persistence.get",
        "persistence.put",
        "media.download",
        // Legado AnalyzeUrl compatibility shim. Backed by `LoginHeaderStore`
        // (UserDefaults JSON map) so Core can read per-source login headers
        // through the same boundary contract as Android.
        "source.getLoginHeaderMap",
        // Credential lane (Keychain-backed). `credential.resolve` is a
        // Core-side convenience that resolves a credential by logical key
        // (deriving service from `sourceUrl` / `sourceId` when provided).
        "credential.get",
        "credential.set",
        "credential.delete",
        "credential.resolve",
        // iOS-side lane aggregation (not a Core HostCapability variant)
        "anti_bot.challenge",
    ]

    // MARK: - http.execute

    /// Execute an `http.execute` request via `HTTPClient.send` and build the
    /// `host.complete` result dict. Exposed as internal so proof tests can
    /// verify the `finalUrl` / `cookies` payload contract without a live runtime.
    internal func executeHTTP(
        params: [String: Any],
        transportRequestID: String? = nil
    ) async throws -> [String: Any] {
        let url = (params["url"] as? String) ?? ""
        let method = (params["method"] as? String) ?? "GET"
        let headersDict = (params["headers"] as? [String: Any]) ?? [:]
        let headers = headersDict.reduce(into: [String: String]()) { acc, kv in
            if let s = kv.value as? String { acc[kv.key] = s }
        }
        guard let parsedURL = URL(string: url),
              let scheme = parsedURL.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              parsedURL.host?.isEmpty == false else {
            throw HostRequestRouterError.hostHTTPFailed("http.execute url must be absolute HTTP(S)")
        }
        let charset = (params["charset"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = try Self.encodeHTTPBody(params["body"], charset: charset)
        let followsRedirects = params["followRedirects"] as? Bool
        // Frozen Core schema permits zero to mean "do not follow redirects".
        let maxRedirects: Int? = try Self.nonNegativeInteger(params["maxRedirects"], field: "maxRedirects")
        let retry = try Self.parseRetryPolicy(params["retry"])
        let usesCookieJar = (params["usePlatformCookieJar"] as? Bool) ?? false
        let sessionObject = params["session"] as? [String: Any]
        let sessionID = (sessionObject?["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if params["session"] != nil, sessionID?.isEmpty != false {
            throw HostRequestRouterError.hostHTTPFailed("http.execute session.id must be non-blank")
        }
        if sessionID != nil, cookieJar == nil {
            throw HostRequestRouterError.cookieJarNotConfigured
        }

        let request = HTTPRequest(
            url: url,
            method: method,
            headers: headers,
            body: body,
            useCookieJar: usesCookieJar || sessionID != nil,
            requiresCookieJar: sessionID != nil,
            cookieScopeKey: sessionID.map(HostCookieSessionScope.key),
            retryCount: max(0, retry.maximumAttempts - 1),
            followRedirects: followsRedirects
        )

        var lastError: Error?
        var response: HTTPResponse?
        for attempt in 1...retry.maximumAttempts {
            do {
                if let configuredClient = httpClient as? any HostConfiguredHTTPClient {
                    response = try await configuredClient.send(
                        request,
                        requestId: transportRequestID?.isEmpty == false ? transportRequestID : nil,
                        maxRedirects: maxRedirects
                    )
                } else if maxRedirects != nil {
                    throw HostRequestRouterError.hostHTTPFailed(
                        "http.execute maxRedirects requires a HostConfiguredHTTPClient"
                    )
                } else if let transportRequestID,
                          !transportRequestID.isEmpty,
                          let requestScopedClient = httpClient as? any RequestScopedHTTPClient {
                    response = try await requestScopedClient.send(request, requestId: transportRequestID)
                } else {
                    response = try await httpClient.send(request)
                }
                break
            } catch {
                lastError = error
                guard attempt < retry.maximumAttempts else { break }
                if retry.backoffMilliseconds > 0 {
                    try await Task.sleep(
                        nanoseconds: UInt64(retry.backoffMilliseconds) * 1_000_000
                    )
                }
            }
        }
        guard let response else { throw lastError ?? HostRequestRouterError.hostHTTPFailed("http.execute failed") }
        return Self.buildHTTPExecuteResult(
            response: response,
            sessionID: sessionID,
            preferredCharset: charset
        )
    }

    /// Cancel the concrete URLSession task currently associated with a Core
    /// command. Returning false is normal when the request completed before a
    /// cancellation race or when a non-request-scoped test client is injected.
    @discardableResult
    public func cancelHTTPTransport(requestID: String) -> Bool {
        guard !requestID.isEmpty,
              let requestScopedClient = httpClient as? any RequestScopedHTTPClient else {
            return false
        }
        return requestScopedClient.cancel(requestId: requestID)
    }

    /// Build the `result` dict for an `http.execute` `host.complete` payload.
    ///
    /// Mirrors Android `HttpExecuteHandler.buildResultJson` / `extractCookies`:
    /// - `status`, `headers`, `body` always present.
    /// - `finalUrl` present when the host captured the post-redirect URL.
    /// - `cookies` present when the response carried a `Set-Cookie` header;
    ///   parsed best-effort (name=value from each Set-Cookie fragment).
    internal static func buildHTTPExecuteResult(
        response: HTTPResponse,
        sessionID: String? = nil,
        preferredCharset: String? = nil
    ) -> [String: Any] {
        let bodyString = decodeHTTPBody(
            response.data,
            headers: response.headers,
            preferredCharset: preferredCharset
        )

        var result: [String: Any] = [
            "status": response.statusCode,
            "headers": response.headers.isEmpty ? [:] : response.headers,
            "body": bodyString,
        ]
        #if !READER_IOS_SHELL_CI
        if let finalUrl = response.finalUrl {
            result["finalUrl"] = finalUrl
        }
        #endif
        let cookies = Self.extractCookies(from: response.headers)
        if !cookies.isEmpty {
            result["cookies"] = cookies
        }
        if let sessionID {
            result["session"] = ["id": sessionID]
        }
        return result
    }

    private struct RetryPolicy {
        let maximumAttempts: Int
        let backoffMilliseconds: Int
    }

    private static func parseRetryPolicy(_ raw: Any?) throws -> RetryPolicy {
        guard let raw else { return RetryPolicy(maximumAttempts: 1, backoffMilliseconds: 0) }
        guard let object = raw as? [String: Any],
              let maximumAttempts = try positiveInteger(object["maxAttempts"], field: "retry.maxAttempts") else {
            throw HostRequestRouterError.hostHTTPFailed("http.execute retry must contain maxAttempts")
        }
        let backoff = try nonNegativeInteger(object["backoffMillis"], field: "retry.backoffMillis") ?? 0
        guard maximumAttempts <= 5, backoff <= 60_000 else {
            throw HostRequestRouterError.hostHTTPFailed("http.execute retry exceeds iOS safety bounds")
        }
        return RetryPolicy(maximumAttempts: maximumAttempts, backoffMilliseconds: backoff)
    }

    private static func positiveInteger(_ raw: Any?, field: String) throws -> Int? {
        guard let raw else { return nil }
        guard let number = raw as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              !CFNumberIsFloatType(number),
              let value = Int(number.stringValue),
              value > 0 else {
            throw HostRequestRouterError.hostHTTPFailed("http.execute \(field) must be a positive integer")
        }
        return value
    }

    private static func nonNegativeInteger(_ raw: Any?, field: String) throws -> Int? {
        guard let raw else { return nil }
        guard let number = raw as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              !CFNumberIsFloatType(number),
              let value = Int(number.stringValue),
              value >= 0 else {
            throw HostRequestRouterError.hostHTTPFailed("http.execute \(field) must be a non-negative integer")
        }
        return value
    }

    private static func encodeHTTPBody(_ raw: Any?, charset: String?) throws -> Data? {
        guard let raw, !(raw is NSNull) else { return nil }
        let encoding = try stringEncoding(charset)
        if let string = raw as? String {
            guard let data = string.data(using: encoding) else {
                throw HostRequestRouterError.hostHTTPFailed("http.execute body cannot be encoded with \(charset ?? "utf-8")")
            }
            return data
        }
        guard let object = raw as? [String: Any] else {
            throw HostRequestRouterError.hostHTTPFailed("http.execute body must be a string or structured form")
        }
        if object["files"] != nil {
            throw HostRequestRouterError.hostHTTPFailed(
                "http.execute multipart file bodies require a frozen sandbox file-grant contract"
            )
        }
        guard let fields = object["fields"] as? [[Any]] else {
            throw HostRequestRouterError.hostHTTPFailed("http.execute form body requires fields pairs")
        }
        var components = URLComponents()
        components.queryItems = try fields.map { pair in
            guard pair.count == 2,
                  let name = pair[0] as? String,
                  let value = pair[1] as? String else {
                throw HostRequestRouterError.hostHTTPFailed("http.execute form fields must be [name, value] pairs")
            }
            return URLQueryItem(name: name, value: value)
        }
        let form = (components.percentEncodedQuery ?? "").replacingOccurrences(of: "%20", with: "+")
        guard let data = form.data(using: encoding) else {
            throw HostRequestRouterError.hostHTTPFailed("http.execute form cannot be encoded")
        }
        return data
    }

    private static func stringEncoding(_ charset: String?) throws -> String.Encoding {
        switch charset?.lowercased().replacingOccurrences(of: "_", with: "-") {
        case nil, "", "utf-8", "utf8": return .utf8
        case "utf-16", "utf16": return .utf16
        case "iso-8859-1", "latin1": return .isoLatin1
        case "us-ascii", "ascii": return .ascii
        default:
            throw HostRequestRouterError.hostHTTPFailed(
                "http.execute charset \(charset ?? "") is unsupported by the iOS adapter"
            )
        }
    }

    private static func decodeHTTPBody(
        _ data: Data,
        headers: [String: String],
        preferredCharset: String?
    ) -> String {
        guard !data.isEmpty else { return "" }
        let contentType = headers.first { $0.key.lowercased() == "content-type" }?.value
        let headerCharset = contentType?
            .components(separatedBy: ";")
            .dropFirst()
            .first(where: { $0.lowercased().contains("charset=") })?
            .components(separatedBy: "=")
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = [headerCharset, preferredCharset, "utf-8"].compactMap { $0 }
        for candidate in candidates {
            if let encoding = try? stringEncoding(candidate),
               let value = String(data: data, encoding: encoding) {
                return value
            }
        }
        return ""
    }

    /// Parse `Set-Cookie` header(s) from a response's header dict into a list
    /// of `{name, value}` JSON objects.
    ///
    /// Case-insensitive header lookup (URLSession may return "set-cookie" or
    /// "Set-Cookie"). Multiple Set-Cookie headers may be comma-joined by the
    /// HTTP layer; this is a best-effort parse aligned with Android's
    /// `HttpExecuteHandler.extractCookies` — sufficient for the login_cookie
    /// lane proof (Core re-parses via its own cookie store on the
    /// host.complete round-trip).
    internal static func extractCookies(from headers: [String: String]) -> [[String: Any]] {
        var setCookieValues: [String] = []
        for (key, value) in headers {
            if key.lowercased() == "set-cookie" {
                setCookieValues.append(value)
            }
        }
        guard !setCookieValues.isEmpty else { return [] }

        var cookies: [[String: Any]] = []
        for raw in setCookieValues {
            // OkHttp/URLSession may merge multiple Set-Cookie headers with ", ".
            // A cookie's Expires date also contains a comma, so split on ", "
            // and keep the name=value segment of each fragment (best-effort,
            // matches Android HttpExecuteHandler.extractCookies).
            for fragment in raw.split(separator: ",") {
                let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let semi = trimmed.firstIndex(of: ";") else {
                    if let cookie = parseCookieNameValue(trimmed) {
                        cookies.append(cookie)
                    }
                    continue
                }
                let nameValue = String(trimmed[..<semi]).trimmingCharacters(in: .whitespacesAndNewlines)
                if let cookie = parseCookieNameValue(nameValue) {
                    cookies.append(cookie)
                }
            }
        }
        return cookies
    }

    private static func parseCookieNameValue(_ nameValue: String) -> [String: Any]? {
        guard let eqIndex = nameValue.firstIndex(of: "=") else { return nil }
        let name = String(nameValue[..<eqIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let value = String(nameValue[nameValue.index(after: eqIndex)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return ["name": name, "value": value]
    }

    // MARK: - cookie.get / cookie.set

    /// Route `cookie.get` to `CookieGetHandler`. Throws if no cookie jar is
    /// configured on this router.
    internal func executeCookieGet(params: [String: Any]) async throws -> [String: Any] {
        guard let jar = cookieJar else {
            throw HostRequestRouterError.cookieJarNotConfigured
        }
        return try await CookieGetHandler(cookieJar: jar).handle(params: params)
    }

    /// Route `cookie.set` to `CookieSetHandler`. Throws if no cookie jar is
    /// configured on this router.
    internal func executeCookieSet(params: [String: Any]) async throws -> [String: Any] {
        guard let jar = cookieJar else {
            throw HostRequestRouterError.cookieJarNotConfigured
        }
        return try await CookieSetHandler(cookieJar: jar).handle(params: params)
    }

    // MARK: - webview.evaluateJavaScript

    /// Route `webview.evaluateJavaScript` to `WebViewEvaluateJavaScriptHandler`.
    /// Throws if no WebView executor is configured on this router.
    internal func executeWebViewEvaluate(params: [String: Any]) async throws -> [String: Any] {
        guard let executor = webViewExecutor else {
            throw HostRequestRouterError.webViewExecutorNotConfigured
        }
        return try await WebViewEvaluateJavaScriptHandler(executor: executor).handle(params: params)
    }

    // MARK: - anti_bot.challenge

    /// Route `anti_bot.challenge` to `AntiBotChallengeHandler`. Throws if no
    /// anti-bot executor is configured. On challenge detection, throws
    /// `AntiBotChallengeRequiredError` (caught by `handleHostRequest` and
    /// forwarded as `host.error` with code `CHALLENGE_REQUIRED`).
    ///
    /// The handler is a lane coordinator (not a single-shot CapabilityHandler):
    /// it takes `url` / `headers` / `cookieJarId` rather than a params dict.
    /// This method extracts those fields from the Core `host.request` params
    /// (mirroring the `http.execute` field extraction) and adapts the
    /// `AntiBotHandleResult` enum into a `host.complete` result dict
    /// (`.completed`) or a `host.error` event (`.challengeRequired`).
    internal func executeAntiBotChallenge(params: [String: Any]) async throws -> [String: Any] {
        guard let executor = antiBotExecutor else {
            throw HostRequestRouterError.antiBotExecutorNotConfigured
        }
        let url = (params["url"] as? String) ?? ""
        let headersDict = (params["headers"] as? [String: Any]) ?? [:]
        let headers = headersDict.reduce(into: [String: String]()) { acc, kv in
            if let s = kv.value as? String { acc[kv.key] = s }
        }
        let cookieJarId = params["cookieJarId"] as? String

        let handler = AntiBotChallengeHandler(executor: executor)
        let handleResult = try await handler.handle(
            url: url,
            headers: headers,
            cookieJarId: cookieJarId
        )

        switch handleResult {
        case .completed(let body, let finalUrl):
            return [
                "body": body,
                "finalUrl": finalUrl,
            ]
        case .challengeRequired(let diagnostics):
            // Throwing here lets `handleHostRequest`'s catch block send
            // `host.error` with the CHALLENGE_REQUIRED code + details, so Core
            // routes the source into its `host_required` channel.
            throw AntiBotChallengeRequiredError(diagnostics: diagnostics)
        }
    }

    // MARK: - media.download

    /// Route `media.download` to `MediaDownloadHandler`. Throws if no media
    /// download executor is configured.
    internal func executeMediaDownload(params: [String: Any]) async throws -> [String: Any] {
        guard let executor = mediaDownloadExecutor else {
            throw HostRequestRouterError.mediaDownloadExecutorNotConfigured
        }
        return try await MediaDownloadHandler(executor: executor).handle(params: params)
    }

    // MARK: - source.getLoginHeaderMap

    /// Route Legado-compatible `source.getLoginHeaderMap` calls to the
    /// host-side login-header provider. When no store is wired, return an empty
    /// map so AnalyzeUrl compatibility code sees "no login headers" rather
    /// than an unsupported host capability.
    internal func executeSourceGetLoginHeaderMap(params: [String: Any]) async throws -> [String: Any] {
        let source = params["source"] as? [String: Any]
        let sourceId = (params["sourceId"] as? String)
            ?? (source?["sourceId"] as? String)
            ?? (source?["id"] as? String)
        let url = (params["url"] as? String)
            ?? (params["baseUrl"] as? String)
            ?? (source?["baseUrl"] as? String)
            ?? (source?["bookSourceUrl"] as? String)
        let host = (params["host"] as? String)
            ?? url.flatMap { URL(string: $0)?.host }

        let headers = try await sourceLoginHeaderMapProvider.loginHeaderMap(
            sourceId: sourceId,
            url: url,
            host: host
        ) ?? [:]

        return [
            "headers": headers,
            "headerMap": headers,
        ]
    }

    // MARK: - host.complete / host.error

    /// Send `host.complete` for the given operationId with a pre-built result
    /// dict. Uses a fresh requestId derived from operationId to avoid collision
    /// with the original request.
    private func sendHostComplete(
        operationId: UInt64,
        result: [String: Any]
    ) throws {
        let completeRequestId: UInt64 = 9_000_000_000 + operationId
        let payload: [String: Any] = [
            "protocolVersion": 1,
            "requestId": NSNumber(value: completeRequestId),
            "method": "host.complete",
            "params": [
                "operationId": NSNumber(value: operationId),
                "result": result,
            ] as [String: Any],
        ]
        let json = try JSONSerialization.data(withJSONObject: payload)
        try runtime.send(json: json)
    }

    /// Send `host.error` for the given operationId. The optional `details`
    /// dict is included in the error payload when present (e.g. anti-bot
    /// challenge diagnostics carry `lane` / `challengeType` / `url` /
    /// `autoRetryable` / `cookieJarId` for Core's `host_required` routing).
    private func sendHostError(
        operationId: UInt64,
        code: String,
        message: String,
        details: [String: Any]? = nil
    ) throws {
        let errorRequestId: UInt64 = 9_100_000_000 + operationId
        var errorDict: [String: Any] = [
            "code": code,
            "message": message,
            "retryable": false,
        ]
        if let details = details {
            errorDict["details"] = details
        }
        let payload: [String: Any] = [
            "protocolVersion": 1,
            "requestId": NSNumber(value: errorRequestId),
            "method": "host.error",
            "params": [
                "operationId": NSNumber(value: operationId),
                "error": errorDict,
            ] as [String: Any],
        ]
        let json = try JSONSerialization.data(withJSONObject: payload)
        try runtime.send(json: json)
    }

    // MARK: - host.smoke.echo

    /// `host.smoke.echo` — Core host-bus self-check. Echoes the incoming
    /// `params` back as `{echoed: params}` so Core can verify the
    /// `host.request` → `host.complete` round-trip without depending on any
    /// business capability.
    private func executeHostSmokeEcho(params: [String: Any]) throws -> [String: Any] {
        return ["echoed": params]
    }

    // MARK: - file.read

    /// `file.read` — read a file from the Host sandbox.
    /// Supports `encoding` (utf8/base64), `byteOffset`, `maxBytes`.
    private func executeFileRead(params: [String: Any]) throws -> [String: Any] {
        guard let path = params["path"] as? String, !path.isEmpty else {
            throw HostRequestRouterError.hostHTTPFailed("file.read requires non-empty `path`")
        }
        let url = try Self.resolveSandboxURL(path: path, access: .read)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw HostRequestRouterError.hostHTTPFailed("file.read: file not found at \(url.path)")
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw HostRequestRouterError.hostHTTPFailed("file.read failed: \(error.localizedDescription)")
        }
        let offset = (params["byteOffset"] as? UInt64) ?? 0
        let maxBytes = params["maxBytes"] as? UInt64
        let sliced: Data
        if offset > 0 || maxBytes != nil {
            let start = data.startIndex.advanced(by: Int(min(offset, UInt64(data.count))))
            let end: Data.Index
            if let max = maxBytes {
                end = data.startIndex.advanced(by: min(Int(offset) + Int(max), data.count))
            } else {
                end = data.endIndex
            }
            sliced = start < end ? data.subdata(in: start..<end) : Data()
        } else {
            sliced = data
        }
        let encoding = (params["encoding"] as? String) ?? "utf8"
        var result: [String: Any] = ["byteLength": sliced.count]
        if encoding == "base64" {
            result["contentBase64"] = sliced.base64EncodedString()
        } else {
            result["content"] = String(data: sliced, encoding: .utf8) ?? ""
            result["encoding"] = "utf8"
        }
        return result
    }

    // MARK: - file.write

    /// `file.write` — write a file to the Host sandbox.
    /// Supports `createDirectories`, `append`, `content`/`contentBase64`.
    private func executeFileWrite(params: [String: Any]) throws -> [String: Any] {
        guard let path = params["path"] as? String, !path.isEmpty else {
            throw HostRequestRouterError.hostHTTPFailed("file.write requires non-empty `path`")
        }
        let url = try Self.resolveSandboxURL(path: path, access: .write)
        let createDirs = (params["createDirectories"] as? Bool) ?? false
        if createDirs {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
        }
        let content = params["content"] as? String
        let contentBase64 = params["contentBase64"] as? String
        let data: Data
        if let base64 = contentBase64 {
            guard let decoded = Data(base64Encoded: base64) else {
                throw HostRequestRouterError.hostHTTPFailed("file.write: invalid base64 content")
            }
            data = decoded
        } else if let text = content {
            data = Data(text.utf8)
        } else {
            throw HostRequestRouterError.hostHTTPFailed("file.write requires `content` or `contentBase64`")
        }
        let append = (params["append"] as? Bool) ?? false
        if append && FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try data.write(to: url, options: .atomic)
            }
        } else {
            try data.write(to: url, options: .atomic)
        }
        return ["written": true, "byteLength": data.count]
    }

    // MARK: - log.emit

    /// `log.emit` — forward Core log events to the Host log system.
    private func executeLogEmit(params: [String: Any]) throws -> [String: Any] {
        let level = (params["level"] as? String) ?? "info"
        let message = (params["message"] as? String) ?? ""
        let target = (params["target"] as? String) ?? "ReaderCore"
        HostLogForwarder.shared.emit(level: level, message: message, target: target)
        return ["emitted": true]
    }

    // MARK: - time.now

    /// `time.now` — return current Host time.
    private func executeTimeNow(params: [String: Any]) throws -> [String: Any] {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let iso8601 = formatter.string(from: now)
        let unixMillis = UInt64(now.timeIntervalSince1970 * 1000)
        var result: [String: Any] = [
            "unixMillis": unixMillis,
            "iso8601": iso8601,
        ]
        if let tz = params["timezone"] as? String, !tz.isEmpty {
            result["timezone"] = tz
        }
        return result
    }

    // MARK: - system.info

    /// `system.info` — return Host system info.
    private func executeSystemInfo(params: [String: Any]) throws -> [String: Any] {
        let info = HostSystemInfoProvider.shared.collectInfo()
        if let keys = params["keys"] as? [String], !keys.isEmpty {
            let allowed = Set(keys)
            return ["info": info.filter { allowed.contains($0.key) }]
        }
        return ["info": info]
    }

    // MARK: - Sandbox path resolution

    internal enum SandboxFileAccess: Equatable {
        case read
        case write
    }

    internal struct SandboxRoots {
        let documents: URL
        let caches: URL
        let applicationSupport: URL
        let temporary: URL

        static var live: SandboxRoots {
            let fm = FileManager.default
            return SandboxRoots(
                documents: fm.urls(for: .documentDirectory, in: .userDomainMask)[0],
                caches: fm.urls(for: .cachesDirectory, in: .userDomainMask)[0],
                applicationSupport: fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0],
                temporary: fm.temporaryDirectory
            )
        }
    }

    /// Resolve a Core file path within one frozen sandbox root. The scheme
    /// slash in paths such as `temp:/chapter.txt` is root-relative; a bare
    /// leading slash, `..`, or a symlink that resolves outside its selected
    /// root is rejected. The same resolver is used before both reads and
    /// writes so neither operation can escape through an existing ancestor.
    internal static func resolveSandboxURL(
        path: String,
        access: SandboxFileAccess,
        roots: SandboxRoots = .live,
        fileManager fm: FileManager = .default
    ) throws -> URL {
        let selected: (root: URL, relative: String)
        if path.hasPrefix("documents:") {
            selected = (roots.documents, String(path.dropFirst("documents:".count)))
        } else if path.hasPrefix("caches:") {
            selected = (roots.caches, String(path.dropFirst("caches:".count)))
        } else if path.hasPrefix("cache:") {
            // Retain the historical spelling as an alias while emitting the
            // same canonical caches-root URL as the frozen `caches:` prefix.
            selected = (roots.caches, String(path.dropFirst("cache:".count)))
        } else if path.hasPrefix("applicationSupport:") {
            selected = (
                roots.applicationSupport,
                String(path.dropFirst("applicationSupport:".count))
            )
        } else if path.hasPrefix("temp:") {
            selected = (roots.temporary, String(path.dropFirst("temp:".count)))
        } else {
            guard !(path as NSString).isAbsolutePath else {
                throw sandboxPathError(path: path, access: access, reason: "absolute paths are not allowed")
            }
            selected = (roots.documents, path)
        }

        var relative = selected.relative
        if relative.hasPrefix("//") {
            throw sandboxPathError(path: path, access: access, reason: "absolute root escape is not allowed")
        }
        if relative.hasPrefix("/") {
            relative.removeFirst()
        }
        let components = relative
            .components(separatedBy: "/")
            .filter { !$0.isEmpty && $0 != "." }
        guard !components.isEmpty else {
            throw sandboxPathError(path: path, access: access, reason: "path must identify a file below its root")
        }
        guard !components.contains("..") else {
            throw sandboxPathError(path: path, access: access, reason: "parent traversal is not allowed")
        }

        let root = selected.root.standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL
        var resolved = root
        for component in components {
            let candidate = resolved.appendingPathComponent(component).standardizedFileURL
            try requireDescendant(candidate, of: root, path: path, access: access)

            if let destination = try? fm.destinationOfSymbolicLink(atPath: candidate.path) {
                let destinationURL: URL
                if (destination as NSString).isAbsolutePath {
                    destinationURL = URL(fileURLWithPath: destination)
                } else {
                    destinationURL = candidate.deletingLastPathComponent()
                        .appendingPathComponent(destination)
                }
                resolved = destinationURL.standardizedFileURL
                    .resolvingSymlinksInPath()
                    .standardizedFileURL
                try requireDescendant(resolved, of: root, path: path, access: access)
            } else {
                resolved = candidate
            }
        }
        return resolved
    }

    private static func requireDescendant(
        _ candidate: URL,
        of root: URL,
        path: String,
        access: SandboxFileAccess
    ) throws {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(rootPath) else {
            throw sandboxPathError(path: path, access: access, reason: "resolved path leaves its sandbox root")
        }
    }

    private static func sandboxPathError(
        path: String,
        access: SandboxFileAccess,
        reason: String
    ) -> HostRequestRouterError {
        HostRequestRouterError.hostHTTPFailed(
            "file.\(access == .read ? "read" : "write") rejected sandbox path `\(path)`: \(reason)"
        )
    }
}

// MARK: - HostCacheStore

/// In-memory cache store for `cache.get` / `cache.put` host requests.
/// Entries carry a TTL (expires_at); reads past expiry return a miss.
final class HostCacheStore: @unchecked Sendable {
    static let shared = HostCacheStore()

    private struct CacheKey: Hashable {
        let namespace: String
        let key: String
    }

    private enum Payload {
        case value(String)
        case valueBase64(String)
    }

    private struct Entry {
        let payload: Payload
        let expiresAt: Date?
    }

    private var entries: [CacheKey: Entry] = [:]
    private let lock = NSLock()

    func get(params: [String: Any]) throws -> [String: Any] {
        guard let ns = params["namespace"] as? String, !ns.isEmpty,
              let key = params["key"] as? String, !key.isEmpty else {
            throw HostRequestRouterError.hostHTTPFailed("cache.get requires `namespace` and `key`")
        }
        let compositeKey = CacheKey(namespace: ns, key: key)
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[compositeKey] else {
            return ["hit": false]
        }
        if let expiresAt = entry.expiresAt, expiresAt < Date() {
            entries.removeValue(forKey: compositeKey)
            return ["hit": false]
        }
        var result: [String: Any] = ["hit": true]
        switch entry.payload {
        case .value(let value):
            result["value"] = value
        case .valueBase64(let valueBase64):
            result["valueBase64"] = valueBase64
        }
        if let expiresAt = entry.expiresAt {
            let formatter = ISO8601DateFormatter()
            result["expiresAt"] = formatter.string(from: expiresAt)
        }
        return result
    }

    func put(params: [String: Any]) throws -> [String: Any] {
        guard let ns = params["namespace"] as? String, !ns.isEmpty,
              let key = params["key"] as? String, !key.isEmpty else {
            throw HostRequestRouterError.hostHTTPFailed("cache.put requires `namespace` and `key`")
        }
        let value = params["value"] as? String
        let valueBase64 = params["valueBase64"] as? String
        guard (value != nil) != (valueBase64 != nil) else {
            throw HostRequestRouterError.hostHTTPFailed(
                "cache.put requires exactly one of `value` or `valueBase64`"
            )
        }
        let payload: Payload
        if let value {
            payload = .value(value)
        } else if let valueBase64 {
            payload = .valueBase64(valueBase64)
        } else {
            throw HostRequestRouterError.hostHTTPFailed("cache.put payload is missing")
        }
        let ttlMillis = params["ttlMillis"] as? UInt64
        let expiresAt: Date? = ttlMillis.map { Date().addingTimeInterval(Double($0) / 1000.0) }
        let compositeKey = CacheKey(namespace: ns, key: key)
        lock.lock()
        defer { lock.unlock() }
        entries[compositeKey] = Entry(
            payload: payload,
            expiresAt: expiresAt
        )
        var result: [String: Any] = ["stored": true]
        if let expiresAt = expiresAt {
            let formatter = ISO8601DateFormatter()
            result["expiresAt"] = formatter.string(from: expiresAt)
        }
        return result
    }
}

// MARK: - HostPersistenceStore

/// Persistence store backed by `UserDefaults` for `persistence.get` /
/// `persistence.put` host requests. Supports `expected_revision` optimistic
/// locking.
final class HostPersistenceStore: @unchecked Sendable {
    static let shared = HostPersistenceStore()

    private enum Payload {
        case value(String)
        case valueBase64(String)

        var record: [String: String] {
            switch self {
            case .value(let value):
                return ["kind": "value", "payload": value]
            case .valueBase64(let valueBase64):
                return ["kind": "valueBase64", "payload": valueBase64]
            }
        }

        init(record: [String: Any]) throws {
            guard let kind = record["kind"] as? String,
                  let payload = record["payload"] as? String else {
                throw HostRequestRouterError.hostHTTPFailed("persistence.get stored payload is corrupt")
            }
            switch kind {
            case "value": self = .value(payload)
            case "valueBase64": self = .valueBase64(payload)
            default:
                throw HostRequestRouterError.hostHTTPFailed("persistence.get stored payload kind is corrupt")
            }
        }
    }

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func storageKey(namespace: String, key: String) -> String {
        "host.persistence.v2.value.\(Self.encodedTuple(namespace: namespace, key: key))"
    }

    private func revisionKey(namespace: String, key: String) -> String {
        "host.persistence.v2.revision.\(Self.encodedTuple(namespace: namespace, key: key))"
    }

    private static func encodedTuple(namespace: String, key: String) -> String {
        // Length-prefix the UTF-8 tuple before base64url encoding. This keeps
        // opaque namespaces/keys out of UserDefaults keys and makes pairs such
        // as ("a.b", "c") and ("a", "b.c") provably distinct.
        let tuple = "\(namespace.utf8.count):\(namespace)\(key.utf8.count):\(key)"
        return Data(tuple.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    func get(params: [String: Any]) throws -> [String: Any] {
        guard let ns = params["namespace"] as? String, !ns.isEmpty,
              let key = params["key"] as? String, !key.isEmpty else {
            throw HostRequestRouterError.hostHTTPFailed("persistence.get requires `namespace` and `key`")
        }
        let sKey = storageKey(namespace: ns, key: key)
        let rKey = revisionKey(namespace: ns, key: key)
        lock.lock()
        defer { lock.unlock() }
        if let record = defaults.dictionary(forKey: sKey) {
            let payload = try Payload(record: record)
            let revision = defaults.string(forKey: rKey) ?? "0"
            var result: [String: Any] = ["found": true, "revision": revision]
            switch payload {
            case .value(let value):
                result["value"] = value
            case .valueBase64(let valueBase64):
                result["valueBase64"] = valueBase64
            }
            return result
        }
        return ["found": false]
    }

    func put(params: [String: Any]) throws -> [String: Any] {
        guard let ns = params["namespace"] as? String, !ns.isEmpty,
              let key = params["key"] as? String, !key.isEmpty else {
            throw HostRequestRouterError.hostHTTPFailed("persistence.put requires `namespace` and `key`")
        }
        let value = params["value"] as? String
        let valueBase64 = params["valueBase64"] as? String
        guard (value != nil) != (valueBase64 != nil) else {
            throw HostRequestRouterError.hostHTTPFailed(
                "persistence.put requires exactly one of `value` or `valueBase64`"
            )
        }
        let payload: Payload
        if let value {
            payload = .value(value)
        } else if let valueBase64 {
            payload = .valueBase64(valueBase64)
        } else {
            throw HostRequestRouterError.hostHTTPFailed("persistence.put payload is missing")
        }
        let sKey = storageKey(namespace: ns, key: key)
        let rKey = revisionKey(namespace: ns, key: key)
        let expectedRevision = params["expectedRevision"] as? String

        lock.lock()
        defer { lock.unlock() }

        // Optimistic lock: if expectedRevision is provided, it must match the
        // current revision (or be "0" for a new entry).
        let currentRevision = defaults.string(forKey: rKey)
        if let expected = expectedRevision {
            if expected != (currentRevision ?? "0") {
                throw HostRequestRouterError.hostHTTPFailed(
                    "persistence.put revision mismatch: expected \(expected), got \(currentRevision ?? "0")"
                )
            }
        }
        guard let revision = UInt64(currentRevision ?? "0"), revision < UInt64.max else {
            throw HostRequestRouterError.hostHTTPFailed(
                "persistence.put stored revision is corrupt or exhausted"
            )
        }
        let newRevision = String(revision + 1)
        // Store the value and its revision while holding the same lock used by
        // get(). This makes the process-local CAS linearizable: a reader can
        // never observe a new value paired with the previous revision.
        defaults.set(payload.record, forKey: sKey)
        defaults.set(newRevision, forKey: rKey)
        return ["stored": true, "revision": newRevision]
    }
}

// MARK: - HostLogForwarder

/// Forwards Core log events to `os.Logger` so they appear in the unified
/// log system. Singleton; thread-safe via a serial queue.
final class HostLogForwarder: @unchecked Sendable {
    static let shared = HostLogForwarder()

    private let queue = DispatchQueue(label: "host.log-forwarder")

    func emit(level: String, message: String, target: String) {
        queue.async {
            let prefix = "[\(target)]"
            switch level.lowercased() {
            case "trace", "debug":
                print("\(prefix) DEBUG: \(message)")
            case "info":
                print("\(prefix) INFO: \(message)")
            case "warn":
                print("\(prefix) WARN: \(message)")
            case "error":
                print("\(prefix) ERROR: \(message)")
            default:
                print("\(prefix) \(level.uppercased()): \(message)")
            }
        }
    }
}

// MARK: - HostSystemInfoProvider

/// Collects Host system info for `system.info` host requests.
final class HostSystemInfoProvider: @unchecked Sendable {
    static let shared = HostSystemInfoProvider()

    func collectInfo() -> [String: String] {
        var info: [String: String] = [:]
        info["platform"] = "ios"
        info["swiftVersion"] = SwiftCompilerVersion.current
        #if canImport(UIKit)
        info["deviceModel"] = UIDevice.current.model
        info["systemName"] = UIDevice.current.systemName
        info["systemVersion"] = UIDevice.current.systemVersion
        #endif
        if let bundleId = Bundle.main.bundleIdentifier {
            info["bundleId"] = bundleId
        }
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            info["appVersion"] = version
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            info["buildNumber"] = build
        }
        info["locale"] = Locale.current.identifier
        info["timezone"] = TimeZone.current.identifier
        return info
    }
}

// MARK: - Swift compiler version helper

private enum SwiftCompilerVersion {
    static var current: String {
        #if swift(>=6.0)
        return "Swift 6.0"
        #elseif swift(>=5.10)
        return "Swift 5.10"
        #elseif swift(>=5.9)
        return "Swift 5.9"
        #else
        return "Swift 5.x"
        #endif
    }
}

// MARK: - Source login header Keychain store

/// Keychain-backed source login-header store. Header maps may contain Cookie
/// or Authorization values, so production never writes them to UserDefaults or
/// Core source JSON. The source/url/host identity is SHA-256-addressed inside a
/// fixed app service namespace to avoid granting arbitrary Keychain service
/// access to Core-provided strings.
public final class KeychainSourceLoginHeaderStore: SourceLoginHeaderMapProvider, @unchecked Sendable {
    public static let shared = KeychainSourceLoginHeaderStore()

    private static let service = "com.reader.ios.source-login-headers"

    public init() {}

    public func loginHeaderMap(
        sourceId: String?,
        url: String?,
        host: String?
    ) async throws -> [String: String]? {
        guard let account = Self.account(sourceId: sourceId, url: url, host: host) else { return [:] }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var item: AnyObject?
        switch SecItemCopyMatching(query as CFDictionary, &item) {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw HostRequestRouterError.hostHTTPFailed("source login headers are not Data")
            }
            return try JSONDecoder().decode([String: String].self, from: data)
        case errSecItemNotFound:
            return [:]
        case let status:
            throw HostRequestRouterError.hostHTTPFailed(
                "source login header Keychain read failed with status \(status)"
            )
        }
    }

    public func set(
        _ headers: [String: String],
        sourceId: String?,
        url: String?,
        host: String?
    ) throws {
        guard let account = Self.account(sourceId: sourceId, url: url, host: host) else {
            throw HostRequestRouterError.hostHTTPFailed("source login headers require sourceId, url, or host")
        }
        let data = try JSONEncoder().encode(headers)
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
        let protectedValue: [String: Any] = [
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        let updateStatus = SecItemUpdate(identity as CFDictionary, protectedValue as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw HostRequestRouterError.hostHTTPFailed(
                "source login header Keychain update failed with status \(updateStatus)"
            )
        }
        var item = identity
        protectedValue.forEach { item[$0.key] = $0.value }
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw HostRequestRouterError.hostHTTPFailed(
                "source login header Keychain write failed with status \(status)"
            )
        }
    }

    public func clear(sourceId: String?, url: String?, host: String?) throws {
        guard let account = Self.account(sourceId: sourceId, url: url, host: host) else {
            throw HostRequestRouterError.hostHTTPFailed("source login header clear requires sourceId, url, or host")
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw HostRequestRouterError.hostHTTPFailed(
                "source login header Keychain delete failed with status \(status)"
            )
        }
    }

    private static func account(sourceId: String?, url: String?, host: String?) -> String? {
        let identity = [sourceId, url, host]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let identity else { return nil }
        return SHA256.hash(data: Data(identity.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - HostCredentialStore

/// Keychain-backed credential store for Core-initiated `credential.get` /
/// `credential.set` / `credential.delete` / `credential.resolve` host
/// requests.
///
/// This is the Core-side credential lane: Core produces `host.request`
/// events with capability `credential.*`, and this store executes the real
/// Keychain `SecItem` operations. It mirrors `HostCredentialCapability`
/// (which serves the UI/reducer `HostRequest` path) but works with
/// `[String: Any]` params so it can be routed by `HostRequestRouter`
/// without depending on `ReaderUIContract` (which is excluded in shell CI
/// mode).
///
/// Payload contract (mirrors `HostCredentialCapability`):
/// - `credential.get`:    `{ service: String, account: String }`
///                        → `{ value: String?, found: Bool }`
/// - `credential.set`:    `{ service: String, account: String, value: String,
///                           accessible?: String }`
///                        → `{ stored: true }`
/// - `credential.delete`: `{ service: String, account: String }`
///                        → `{ deleted: true, existed: Bool }`
/// - `credential.resolve`:`{ key: String, sourceUrl?: String, sourceId?: String,
///                           service?: String }`
///                        → `{ value: String?, found: Bool }`
///
/// `credential.resolve` derives the Keychain `service` from `service` →
/// `sourceUrl` host → `sourceId` → a default namespace, and uses `key` as
/// the account. This lets Core resolve a credential by logical key without
/// knowing the Keychain service/account convention.
final class HostCredentialStore: @unchecked Sendable {
    static let shared = HostCredentialStore()

    private static let defaultResolveService = "com.reader.ios.credentials"
    private static let canonicalService = "com.reader.ios.core-credentials"

    func get(params: [String: Any]) throws -> [String: Any] {
        guard let service = params["service"] as? String, !service.isEmpty else {
            throw HostRequestRouterError.hostHTTPFailed("credential.get requires non-empty `service`")
        }
        guard let account = params["account"] as? String, !account.isEmpty else {
            throw HostRequestRouterError.hostHTTPFailed("credential.get requires non-empty `account`")
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.canonicalService,
            kSecAttrAccount as String: Self.scopedAccount(service: service, account: account),
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                throw HostRequestRouterError.hostHTTPFailed("credential.get: stored value is not valid UTF-8")
            }
            return ["value": value, "found": true]
        case errSecItemNotFound:
            return ["value": NSNull(), "found": false]
        default:
            throw HostRequestRouterError.hostHTTPFailed("credential.get SecItemCopyMatching status \(status)")
        }
    }

    func set(params: [String: Any]) throws -> [String: Any] {
        guard let service = params["service"] as? String, !service.isEmpty else {
            throw HostRequestRouterError.hostHTTPFailed("credential.set requires non-empty `service`")
        }
        guard let account = params["account"] as? String, !account.isEmpty else {
            throw HostRequestRouterError.hostHTTPFailed("credential.set requires non-empty `account`")
        }
        guard let value = params["value"] as? String else {
            throw HostRequestRouterError.hostHTTPFailed("credential.set requires `value` string")
        }
        let accessibleString = (params["accessible"] as? String) ?? "whenUnlockedThisDeviceOnly"
        guard let accessible = Self.accessibleAttr(for: accessibleString) else {
            throw HostRequestRouterError.hostHTTPFailed(
                "credential.set `accessible` must be a ThisDeviceOnly protection class: \(accessibleString)"
            )
        }
        let data = Data(value.utf8)

        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.canonicalService,
            kSecAttrAccount as String: Self.scopedAccount(service: service, account: account),
        ]
        let protectedValue: [String: Any] = [
            kSecAttrAccessible as String: accessible,
            kSecValueData as String: data,
        ]
        let updateStatus = SecItemUpdate(identity as CFDictionary, protectedValue as CFDictionary)
        if updateStatus == errSecSuccess { return ["stored": true] }
        guard updateStatus == errSecItemNotFound else {
            throw HostRequestRouterError.hostHTTPFailed(
                "credential.set SecItemUpdate status \(updateStatus)"
            )
        }
        var addQuery = identity
        protectedValue.forEach { addQuery[$0.key] = $0.value }
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw HostRequestRouterError.hostHTTPFailed("credential.set SecItemAdd status \(status)")
        }
        return ["stored": true]
    }

    func delete(params: [String: Any]) throws -> [String: Any] {
        guard let service = params["service"] as? String, !service.isEmpty else {
            throw HostRequestRouterError.hostHTTPFailed("credential.delete requires non-empty `service`")
        }
        guard let account = params["account"] as? String, !account.isEmpty else {
            throw HostRequestRouterError.hostHTTPFailed("credential.delete requires non-empty `account`")
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.canonicalService,
            kSecAttrAccount as String: Self.scopedAccount(service: service, account: account),
        ]
        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecSuccess:
            return ["deleted": true, "existed": true]
        case errSecItemNotFound:
            return ["deleted": true, "existed": false]
        default:
            throw HostRequestRouterError.hostHTTPFailed("credential.delete SecItemDelete status \(status)")
        }
    }

    /// Resolve a credential by logical key. Derives the Keychain `service`
    /// from `service` → `sourceUrl` host → `sourceId` → a default namespace,
    /// and uses `key` as the account. Returns `{ value, found }` like
    /// `credential.get`.
    func resolve(params: [String: Any]) throws -> [String: Any] {
        guard let key = params["key"] as? String, !key.isEmpty else {
            throw HostRequestRouterError.hostHTTPFailed("credential.resolve requires non-empty `key`")
        }
        let service = Self.resolveService(
            params: params,
            default: Self.defaultResolveService
        )
        return try get(params: [
            "service": service,
            "account": key,
        ])
    }

    // MARK: - Helpers

    private static func accessibleAttr(for value: String) -> CFString? {
        switch value {
        case "whenUnlockedThisDeviceOnly": return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case "afterFirstUnlockThisDeviceOnly": return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case "whenPasscodeSetThisDeviceOnly": return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        default: return nil
        }
    }

    private static func scopedAccount(service: String, account: String) -> String {
        let value = service + "\u{0}" + account
        return SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// Derive the Keychain service for `credential.resolve` from the params:
    /// explicit `service` → `sourceUrl` host → `sourceId` → default.
    private static func resolveService(params: [String: Any], default fallback: String) -> String {
        if let service = params["service"] as? String, !service.isEmpty {
            return service
        }
        if let sourceUrl = params["sourceUrl"] as? String,
           let host = URL(string: sourceUrl)?.host, !host.isEmpty {
            return "com.reader.ios.source.\(host)"
        }
        if let sourceId = params["sourceId"] as? String, !sourceId.isEmpty {
            return "com.reader.ios.source.\(sourceId)"
        }
        return fallback
    }
}

// MARK: - LoginHeaderStore

/// Source-compatible legacy name retained for callers compiled against the old
/// API. Storage now delegates to Keychain; no new header map is written to
/// UserDefaults.
public final class LoginHeaderStore: SourceLoginHeaderMapProvider, @unchecked Sendable {
    public static let shared = LoginHeaderStore()

    private let keychain: KeychainSourceLoginHeaderStore

    public init(keychain: KeychainSourceLoginHeaderStore = .shared) {
        self.keychain = keychain
    }

    public func loginHeaderMap(sourceId: String?, url: String?, host: String?) async throws -> [String: String]? {
        try await keychain.loginHeaderMap(sourceId: sourceId, url: url, host: host)
    }

    public func set(_ headers: [String: String], sourceId: String?, url: String?, host: String?) throws {
        try keychain.set(headers, sourceId: sourceId, url: url, host: host)
    }

    public func clear(sourceId: String?, url: String?, host: String?) throws {
        try keychain.clear(sourceId: sourceId, url: url, host: host)
    }
}
