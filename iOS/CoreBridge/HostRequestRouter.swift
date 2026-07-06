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
// host requests to the corresponding handlers. Executors are injected as
// stubs (notImplemented) until device-tier proof lands; the dispatch path is
// complete so a Core host.request for these lanes reaches the handler (which
// returns a structured notImplemented error), not a "capability not supported"
// rejection.

import Foundation
import ReaderCoreProtocols
import ReaderCoreNativeAdapter

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
        case .unexpectedCapability(let c): return "expected http.execute/cookie.get/cookie.set/webview.evaluateJavaScript/anti_bot.challenge/media.download, got \(c)"
        case .hostHTTPFailed(let m): return "Host HTTP failed: \(m)"
        case .cookieJarNotConfigured: return "cookie.get/cookie.set requires a ScopedCookieJar"
        case .webViewExecutorNotConfigured: return "webview.evaluateJavaScript requires a WebViewExecutor"
        case .antiBotExecutorNotConfigured: return "anti_bot.challenge requires an AntiBotExecutor"
        case .mediaDownloadExecutorNotConfigured: return "media.download requires a MediaDownloadExecutor"
        }
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

    public init(
        httpClient: HTTPClient,
        runtime: ReaderCoreNativeRuntime,
        cookieJar: ScopedCookieJar? = nil,
        webViewExecutor: WebViewExecutor? = nil,
        antiBotExecutor: AntiBotExecutor? = nil,
        mediaDownloadExecutor: MediaDownloadExecutor? = nil
    ) {
        self.httpClient = httpClient
        self.runtime = runtime
        self.cookieJar = cookieJar
        self.webViewExecutor = webViewExecutor
        self.antiBotExecutor = antiBotExecutor
        self.mediaDownloadExecutor = mediaDownloadExecutor
    }

    /// Handle a single `host.request` event for `http.execute` / `cookie.get` /
    /// `cookie.set` / `webview.evaluateJavaScript` / `anti_bot.challenge` /
    /// `media.download`:
    /// 1. Dispatch on `capability` to the right host executor.
    /// 2. Send `host.complete` (with the executor's result) or `host.error`.
    public func handleHostRequest(_ event: ReaderCoreNativeEvent) async throws {
        guard event.type == "host.request" else {
            throw HostRequestRouterError.unexpectedHostRequestType(event.type)
        }
        let capability = event.capability ?? ""
        guard Self.supportedCapabilities.contains(capability) else {
            throw HostRequestRouterError.unexpectedCapability(capability)
        }
        guard let operationId = event.operationId else {
            throw HostRequestRouterError.missingOperationId
        }
        guard let params = event.hostParams else {
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
            case "http.execute":
                result = try await executeHTTP(params: params)
            case "cookie.get":
                result = try await executeCookieGet(params: params)
            case "cookie.set":
                result = try await executeCookieSet(params: params)
            case "webview.evaluateJavaScript":
                result = try await executeWebViewEvaluate(params: params)
            case "anti_bot.challenge":
                result = try executeAntiBotChallenge(params: params)
            case "media.download":
                result = try executeMediaDownload(params: params)
            default:
                throw HostRequestRouterError.unexpectedCapability(capability)
            }
            try sendHostComplete(operationId: operationId, result: result)
        } catch let challengeError as AntiBotChallengeRequiredError {
            // anti_bot challenge detection: send host.error with the
            // CHALLENGE_REQUIRED code + diagnostics details so Core can route
            // the source into its host_required channel (fail-closed, no retry).
            let diagnostics = challengeError.diagnostics
            let code = diagnostics["code"] as? String ?? "CHALLENGE_REQUIRED"
            let message = diagnostics["message"] as? String ?? "anti-bot challenge required"
            let details = diagnostics["details"] as? [String: Any] ?? [:]
            try sendHostError(
                operationId: operationId,
                code: code,
                message: message,
                details: details
            )
        } catch {
            try sendHostError(
                operationId: operationId,
                code: "INTERNAL",
                message: error.localizedDescription
            )
        }
    }

    /// Supported capability names routed by this router.
    private static let supportedCapabilities: Set<String> = [
        "http.execute", "cookie.get", "cookie.set", "webview.evaluateJavaScript",
        "anti_bot.challenge", "media.download",
    ]

    // MARK: - http.execute

    /// Execute an `http.execute` request via `HTTPClient.send` and build the
    /// `host.complete` result dict. Exposed as internal so proof tests can
    /// verify the `finalUrl` / `cookies` payload contract without a live runtime.
    internal func executeHTTP(params: [String: Any]) async throws -> [String: Any] {
        let url = (params["url"] as? String) ?? ""
        let method = (params["method"] as? String) ?? "GET"
        let headersDict = (params["headers"] as? [String: Any]) ?? [:]
        let headers = headersDict.reduce(into: [String: String]()) { acc, kv in
            if let s = kv.value as? String { acc[kv.key] = s }
        }
        let bodyString = params["body"] as? String
        let body = bodyString?.data(using: .utf8)

        guard !url.isEmpty else {
            throw HostRequestRouterError.hostHTTPFailed("http.execute url is empty")
        }

        let request = HTTPRequest(
            url: url,
            method: method,
            headers: headers,
            body: body
        )

        let response = try await httpClient.send(request)
        return Self.buildHTTPExecuteResult(response: response)
    }

    /// Build the `result` dict for an `http.execute` `host.complete` payload.
    ///
    /// Mirrors Android `HttpExecuteHandler.buildResultJson` / `extractCookies`:
    /// - `status`, `headers`, `body` always present.
    /// - `finalUrl` present when the host captured the post-redirect URL.
    /// - `cookies` present when the response carried a `Set-Cookie` header;
    ///   parsed best-effort (name=value from each Set-Cookie fragment).
    internal static func buildHTTPExecuteResult(response: HTTPResponse) -> [String: Any] {
        let bodyString = response.data.isEmpty
            ? ""
            : (String(data: response.data, encoding: .utf8) ?? "")

        var result: [String: Any] = [
            "status": response.statusCode,
            "headers": response.headers.isEmpty ? [:] : response.headers,
            "body": bodyString,
        ]
        if let finalUrl = response.finalUrl {
            result["finalUrl"] = finalUrl
        }
        let cookies = Self.extractCookies(from: response.headers)
        if !cookies.isEmpty {
            result["cookies"] = cookies
        }
        return result
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
    internal func executeAntiBotChallenge(params: [String: Any]) throws -> [String: Any] {
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
        let handleResult = try handler.handle(
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
    internal func executeMediaDownload(params: [String: Any]) throws -> [String: Any] {
        guard let executor = mediaDownloadExecutor else {
            throw HostRequestRouterError.mediaDownloadExecutorNotConfigured
        }
        return try MediaDownloadHandler(executor: executor).handle(params: params)
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
}
