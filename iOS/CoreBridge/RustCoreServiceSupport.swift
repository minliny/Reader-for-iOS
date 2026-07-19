// CoreBridge
//
// Shared support for RustCore*Service adapters: runtime access, host request
// polling, result polling, BookSource → source JSON serialization, and CoreError
// → AppReaderError mapping.
//
// S6.1: This is the common plumbing that lets RustCoreSearchService,
// RustCoreTOCService, and RustCoreContentService share the same Core/Host
// boundary wiring without duplicating JSON protocol logic.

import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreNativeAdapter

/// Shared support for Rust Core service adapters.
public enum RustCoreServiceSupport {

    private static let requestIDLock = NSLock()
    private static var nextRequestID: UInt64 = 4_000_000_000

    /// Shared scoped cookie jar for all host HTTP clients. Partitioned by
    /// `CookieJarScopeKey` (sourceId + host) so cookies never leak across
    /// sources or hosts. Injected into every `URLSessionHTTPClient` so cookies
    /// set in one service are visible to the others within the same scope.
    ///
    /// Also injected into `HostRequestRouter` so the router can serve
    /// `cookie.get` / `cookie.set` host requests through the same jar
    /// (login_cookie lane parity with Android).
    public static let sharedCookieJar: ScopedCookieJar = HostScopedCookieJarFactory.makeBasicCookieJar()

    /// Allocates a process-local numeric Core request id. The previous
    /// timestamp-modulo ids could collide when two book-open stages began in
    /// the same millisecond, which makes correlation-scoped cancellation
    /// unsafe. Core only requires a non-zero numeric id.
    public static func allocateRequestID() -> UInt64 {
        requestIDLock.lock()
        defer { requestIDLock.unlock() }
        let allocated = nextRequestID
        nextRequestID = nextRequestID == UInt64.max ? 1 : nextRequestID + 1
        return allocated
    }

    /// URLSession task ids are Host-local, so include the optional UI
    /// correlation alongside the Core numeric id. This is the association used
    /// by request-scoped cancellation and late callback discard.
    public static func transportRequestID(
        correlationID: String?,
        requestID: UInt64
    ) -> String {
        let scope = correlationID?.trimmingCharacters(in: .whitespacesAndNewlines)
        return "core:\(scope?.isEmpty == false ? scope! : "unscoped"):\(requestID)"
    }

    /// Returns the booted runtime, or throws if not booted.
    @MainActor
    public static func requireRuntime() throws -> ReaderCoreNativeRuntime {
        guard let rt = RustCoreRuntimeHolder.shared.current else {
            throw HostRequestRouterError.runtimeNotBooted
        }
        return rt
    }

    /// Build a `HostRequestRouter` wired to `URLSessionHTTPClient` + the shared
    /// runtime + the shared scoped cookie jar. The jar is injected so the router
    /// can serve `cookie.get` / `cookie.set` requests through the same boundary
    /// contract as `http.execute` (login_cookie lane parity with Android).
    ///
    /// The router is wired with the production executors for the `webview`,
    /// `anti_bot`, and `media_download` lanes:
    /// - `media.download` → `URLSessionMediaDownloadExecutor` (cross-platform,
    ///   URLSession + CryptoKit sha256 + range/ETag/304).
    /// - `webview.evaluateJavaScript` → `WKWebViewExecutor` (iOS only; macOS
    ///   `swift build` leaves it nil — webview lane fails closed with
    ///   `webViewExecutorNotConfigured` on macOS CI, which is the intended
    ///   behavior since WKWebView execution requires UIKit).
    /// - `anti_bot.challenge` → `WKAntiBotExecutor` (iOS only for the L2
    ///   WKWebView fallback; L1 URLSession HTTP fetch is cross-platform but
    ///   the executor type itself is iOS-only because it imports WebKit for
    ///   the L2 path).
    ///
    /// On macOS `swift build` / macOS CI, `webViewExecutor` and
    /// `antiBotExecutor` are nil. `host.request` for those lanes then throws
    /// `webViewExecutorNotConfigured` / `antiBotExecutorNotConfigured` — a
    /// structured fail-closed rejection, not a crash. Simulator/real-device
    /// iOS runs get the real executors.
    public static func makeRouter(runtime: ReaderCoreNativeRuntime) -> HostRequestRouter {
        var webViewExecutor: WebViewExecutor? = nil
        var antiBotExecutor: AntiBotExecutor? = nil
        #if canImport(WebKit) && canImport(UIKit)
        webViewExecutor = WKWebViewExecutor()
        antiBotExecutor = WKAntiBotExecutor()
        #endif
        return HostRequestRouter(
            httpClient: URLSessionHTTPClient(cookieJar: sharedCookieJar),
            runtime: runtime,
            cookieJar: sharedCookieJar,
            webViewExecutor: webViewExecutor,
            antiBotExecutor: antiBotExecutor,
            mediaDownloadExecutor: URLSessionMediaDownloadExecutor(
                cookieJar: sharedCookieJar
            )
        )
    }

    /// Poll the runtime for the next event for `requestId`, with timeout.
    public static func pollEvent(
        runtime: ReaderCoreNativeRuntime,
        requestId: UInt64,
        timeout: TimeInterval = 10
    ) throws -> ReaderCoreNativeEvent {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let event = runtime.pollEvent(requestId: requestId) {
                return event
            }
            Thread.sleep(forTimeInterval: 0.005)
        }
        throw ReaderCoreNativeError.requestTimedOut(requestId)
    }

    /// Map a `ReaderCoreNativeError` to `AppReaderError`.
    public static func mapCoreError(_ error: Error) -> AppReaderError {
        if let coreError = error as? ReaderCoreNativeError {
            switch coreError {
            case .coreError(let code, let message):
                return AppReaderError(code: .unknown, message: "[RustCore:\(code)] \(message)", stage: "RUSTCORE")
            case .requestTimedOut(let id):
                return AppReaderError(code: .network, message: "[RustCore] request \(id) timed out", stage: "RUSTCORE")
            case .runtimeDestroyed:
                return AppReaderError(code: .unknown, message: "[RustCore] runtime destroyed", stage: "RUSTCORE")
            default:
                return AppReaderError(code: .unknown, message: "[RustCore] \(coreError)", stage: "RUSTCORE")
            }
        }
        if let routerError = error as? HostRequestRouterError {
            return AppReaderError(code: .network, message: "[HostRouter] \(routerError.localizedDescription)", stage: "RUSTCORE")
        }
        return AppReaderError(code: .unknown, message: error.localizedDescription, stage: "RUSTCORE")
    }

    /// Serialize an iOS `BookSource` into the Rust Core `source` inline object.
    ///
    /// The `source` object has:
    /// - `sourceId`: BookSource.id (or a generated UUID if nil)
    /// - `name`: BookSource.bookSourceName
    /// - `baseUrl`: BookSource.bookSourceUrl
    /// - `bookSource`: the full Legado BookSource JSON (for DSL parsing)
    /// - `rules`: null (Core uses Legado DSL from bookSource)
    public static func serializeSource(
        _ source: BookSource,
        sourceID: String? = nil
    ) -> [String: Any] {
        // A command and its inline source must use the same identity. In
        // particular, an id-less source gets one generated id per command,
        // rather than two unrelated UUIDs at the bridge boundary.
        let sourceId = sourceID
            ?? (source.id?.isEmpty == false ? source.id! : UUID().uuidString)
        var bookSourceJSON: [String: Any] = [:]
        if let data = try? JSONEncoder().encode(source),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            bookSourceJSON = object
        }
        return [
            "sourceId": sourceId,
            "name": source.bookSourceName,
            "baseUrl": source.bookSourceUrl ?? "",
            "bookSource": bookSourceJSON,
            "rules": NSNull(),
        ] as [String: Any]
    }

    /// Build a minimal `HostHttpRequest` params dict from a URL + headers.
    public static func makeRequestParams(
        url: String,
        method: String = "GET",
        headers: [String: String] = [:]
    ) -> [String: Any] {
        var params: [String: Any] = [
            "url": url,
            "method": method,
            "headers": headers,
        ]
        if headers.isEmpty {
            params["headers"] = [:]
        }
        return params
    }
}
