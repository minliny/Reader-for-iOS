// CoreBridge
//
// WebViewEvaluateJavaScriptHandler: host-side capability handler for
// `webview.evaluateJavaScript`.
//
// Mirrors the Rust Core contract in
// `crates/reader-contract/src/host.rs` (HostWebViewEvaluateJavaScriptRequest /
// HostWebViewEvaluateJavaScriptResponse, lines 679-820):
// - Input params: `{document: {kind: "html"|"url", body?, url?, baseUrl?},
//   javaScript: String, timeoutMillis?: u64, profileId?: String}`.
// - Result: `{value: Any, finalUrl?: String, title?: String}`.
//
// Proof tier (this file): handler/router. The handler parses the Core request,
// validates it (mirroring `HostWebViewDocument.validate` /
// `HostWebViewEvaluateJavaScriptRequest.validate`), delegates execution to a
// `WebViewExecutor`, and builds the response dict. Proof tests use
// `StubWebViewExecutor` — no real WKWebView is exercised.
//
// Device-headless/App tier (pending): real WKWebView execution (load HTML/URL,
// evaluate JS, capture finalUrl/title) requires device-tier proof (simulator /
// real device with a live WKWebView). The production `WKWebViewExecutor` below
// is a `notImplemented` stub until that tier lands.
//
// Mirrors Android `WebViewEvaluateJavaScriptHandler.kt` / HarmonyOS proof
// structure so iOS reaches the same handler/router proof level as the other
// two platforms.

import Foundation

/// Errors thrown by the WebView evaluate-JavaScript lane.
public enum WebViewExecutorError: Error, Equatable, LocalizedError {
    case invalidParams(String)
    case timeout(timeoutMillis: UInt64)
    case executionFailed(String)
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .invalidParams(let m): return "WebView invalid params: \(m)"
        case .timeout(let ms): return "WebView evaluation timed out after \(ms)ms"
        case .executionFailed(let m): return "WebView execution failed: \(m)"
        case .notImplemented(let m): return "WebView executor not implemented: \(m)"
        }
    }
}

/// Document input for `webview.evaluateJavaScript` (mirrors Core's
/// `HostWebViewDocument`).
///
/// `kind: "html"` treats `body` as the HTML document body and may include a
/// `baseUrl`. `kind: "url"` treats `url` as navigation input. Hosts must not
/// infer Legado rule meaning from either form.
public struct WebViewDocument: Sendable, Equatable {
    public enum Kind: String, Sendable, Equatable {
        case html
        case url
    }

    public let kind: Kind
    public let body: String?
    public let url: String?
    public let baseUrl: String?

    public init(kind: Kind, body: String? = nil, url: String? = nil, baseUrl: String? = nil) {
        self.kind = kind
        self.body = body
        self.url = url
        self.baseUrl = baseUrl
    }
}

/// Request handed to a `WebViewExecutor` (mirrors Core's
/// `HostWebViewEvaluateJavaScriptRequest` after parsing/validation).
public struct WebViewEvaluationRequest: Sendable, Equatable {
    public let document: WebViewDocument
    public let javaScript: String
    public let timeoutMillis: UInt64?
    public let profileId: String?

    public init(
        document: WebViewDocument,
        javaScript: String,
        timeoutMillis: UInt64? = nil,
        profileId: String? = nil
    ) {
        self.document = document
        self.javaScript = javaScript
        self.timeoutMillis = timeoutMillis
        self.profileId = profileId
    }
}

/// Result produced by a `WebViewExecutor` (mirrors Core's
/// `HostWebViewEvaluateJavaScriptResponse`).
///
/// `value` is any JSON-compatible value (String / Number / Bool / Array /
/// Dictionary / NSNull). Marked `@unchecked Sendable` because `Any` is not
/// statically Sendable, but the value is expected to be a JSON primitive
/// returned by WKWebView's `evaluateJavaScript` completion.
public struct WebViewEvaluationResult: @unchecked Sendable, Equatable {
    public static func == (lhs: WebViewEvaluationResult, rhs: WebViewEvaluationResult) -> Bool {
        // Best-effort equality for tests: compare finalUrl/title and the
        // value's String description (sufficient for stub-based proof).
        if lhs.finalUrl != rhs.finalUrl { return false }
        if lhs.title != rhs.title { return false }
        return String(describing: lhs.value) == String(describing: rhs.value)
    }

    public let value: Any
    public let finalUrl: String?
    public let title: String?

    public init(value: Any = NSNull(), finalUrl: String? = nil, title: String? = nil) {
        self.value = value
        self.finalUrl = finalUrl
        self.title = title
    }
}

/// Executor abstraction for the `webview.evaluateJavaScript` host capability.
/// Core produces the request descriptor; the Host executes the JS in a WebView
/// and returns the result. Core never touches a WebView directly (Core/Host
/// boundary, red line 4).
public protocol WebViewExecutor: Sendable {
    func evaluate(request: WebViewEvaluationRequest) async throws -> WebViewEvaluationResult
}

/// `webview.evaluateJavaScript` capability handler: parses the Core request,
/// validates it (mirroring `HostWebViewDocument.validate` /
/// `HostWebViewEvaluateJavaScriptRequest.validate`), delegates to a
/// `WebViewExecutor`, and builds the response dict.
///
/// JSON contract (aligned with Android `WebViewEvaluateJavaScriptHandler`):
/// - Request params: `{document: {kind, body?, url?, baseUrl?}, javaScript,
///   timeoutMillis?, profileId?}`.
/// - Result: `{value: Any, finalUrl?: String, title?: String}`.
public struct WebViewEvaluateJavaScriptHandler: Sendable {
    public static let capability = "webview.evaluateJavaScript"

    private let executor: WebViewExecutor

    public init(executor: WebViewExecutor) {
        self.executor = executor
    }

    /// Handle a `webview.evaluateJavaScript` request.
    /// - Parameter params: the `HostWebViewEvaluateJavaScriptRequest` JSON.
    /// - Returns: `{value, finalUrl?, title?}` on success.
    public func handle(params: [String: Any]) async throws -> [String: Any] {
        let document = try parseDocument(params)
        let javaScript = try parseJavaScript(params)
        let timeoutMillis = try parseTimeoutMillis(params)
        let profileId = try parseProfileId(params)

        let request = WebViewEvaluationRequest(
            document: document,
            javaScript: javaScript,
            timeoutMillis: timeoutMillis,
            profileId: profileId
        )

        let result = try await executor.evaluate(request: request)
        return Self.buildResultDict(result)
    }

    /// Build the `host.complete` result dict from an executor result.
    /// Exposed as internal so proof tests can verify the payload contract.
    internal static func buildResultDict(_ result: WebViewEvaluationResult) -> [String: Any] {
        var dict: [String: Any] = ["value": result.value]
        if let finalUrl = result.finalUrl, !finalUrl.isEmpty {
            dict["finalUrl"] = finalUrl
        }
        if let title = result.title, !title.isEmpty {
            dict["title"] = title
        }
        return dict
    }

    // MARK: - Parsing / validation (mirrors Core's validate())

    private func parseDocument(_ params: [String: Any]) throws -> WebViewDocument {
        guard let documentObj = params["document"] as? [String: Any] else {
            throw WebViewExecutorError.invalidParams(
                "webview.evaluateJavaScript requires document object"
            )
        }
        guard let kindStr = documentObj["kind"] as? String,
              let kind = WebViewDocument.Kind(rawValue: kindStr) else {
            throw WebViewExecutorError.invalidParams(
                "webview document requires kind ('html' or 'url')"
            )
        }
        let body = (documentObj["body"] as? String)
        let url = (documentObj["url"] as? String)
        let baseUrl = (documentObj["baseUrl"] as? String)

        switch kind {
        case .html:
            guard let body, !body.isEmpty else {
                throw WebViewExecutorError.invalidParams(
                    "webview html document requires non-blank body"
                )
            }
            if let baseUrl, baseUrl.isEmpty {
                throw WebViewExecutorError.invalidParams(
                    "webview document baseUrl must be non-blank"
                )
            }
            if url != nil {
                throw WebViewExecutorError.invalidParams(
                    "webview html document must not include url"
                )
            }
            return WebViewDocument(kind: .html, body: body, url: nil, baseUrl: baseUrl)
        case .url:
            guard let url, !url.isEmpty else {
                throw WebViewExecutorError.invalidParams(
                    "webview url document requires non-blank url"
                )
            }
            if body != nil || baseUrl != nil {
                throw WebViewExecutorError.invalidParams(
                    "webview url document must not include body or baseUrl"
                )
            }
            return WebViewDocument(kind: .url, body: nil, url: url, baseUrl: nil)
        }
    }

    private func parseJavaScript(_ params: [String: Any]) throws -> String {
        guard let javaScript = params["javaScript"] as? String, !javaScript.isEmpty else {
            throw WebViewExecutorError.invalidParams(
                "webview.evaluateJavaScript requires non-blank javaScript"
            )
        }
        return javaScript
    }

    private func parseTimeoutMillis(_ params: [String: Any]) throws -> UInt64? {
        guard let raw = params["timeoutMillis"] else { return nil }
        if let n = raw as? NSNumber {
            let value = n.uint64Value
            guard value > 0 else {
                throw WebViewExecutorError.invalidParams(
                    "webview.evaluateJavaScript timeoutMillis must be greater than 0"
                )
            }
            return value
        }
        if let n = raw as? Int {
            guard n > 0 else {
                throw WebViewExecutorError.invalidParams(
                    "webview.evaluateJavaScript timeoutMillis must be greater than 0"
                )
            }
            return UInt64(n)
        }
        if let n = raw as? UInt64 {
            guard n > 0 else {
                throw WebViewExecutorError.invalidParams(
                    "webview.evaluateJavaScript timeoutMillis must be greater than 0"
                )
            }
            return n
        }
        throw WebViewExecutorError.invalidParams(
            "webview.evaluateJavaScript timeoutMillis must be a positive integer"
        )
    }

    private func parseProfileId(_ params: [String: Any]) throws -> String? {
        guard let raw = params["profileId"] as? String else { return nil }
        guard !raw.isEmpty else {
            throw WebViewExecutorError.invalidParams(
                "webview.evaluateJavaScript profileId must be non-blank"
            )
        }
        return raw
    }
}

// MARK: - StubWebViewExecutor (test proof tier)

/// Stub `WebViewExecutor` for handler/router proof tests. Returns a canned
/// result or throws a canned error — no real WebView is exercised. Mirrors the
/// role of `LoginCookieURLProtocolStub` for the login_cookie lane.
public final class StubWebViewExecutor: WebViewExecutor, @unchecked Sendable {
    private let cannedResult: WebViewEvaluationResult?
    private let cannedError: WebViewExecutorError?

    /// Initialize with a canned result to return on every `evaluate` call.
    public init(result: WebViewEvaluationResult) {
        self.cannedResult = result
        self.cannedError = nil
    }

    /// Initialize with a canned error to throw on every `evaluate` call.
    public init(error: WebViewExecutorError) {
        self.cannedResult = nil
        self.cannedError = error
    }

    public func evaluate(request: WebViewEvaluationRequest) async throws -> WebViewEvaluationResult {
        if let error = cannedError {
            throw error
        }
        return cannedResult ?? WebViewEvaluationResult(value: NSNull())
    }
}

// MARK: - WKWebViewExecutor
//
// The real `WKWebViewExecutor` implementation lives in
// `WKWebViewExecutor.swift` (WKWebView load HTML/URL, evaluate JS, capture
// finalUrl/title, timeout via Task cancellation, security gate via
// `WebViewSecurityGate` + `ProductionWebViewAdapter`). It was extracted from
// this file so the handler/router proof (`StubWebViewExecutor`) and the
// production executor can evolve independently.
