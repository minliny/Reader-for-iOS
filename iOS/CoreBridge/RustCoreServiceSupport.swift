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
import ReaderCoreNetwork
import ReaderCoreNativeAdapter

/// Shared support for Rust Core service adapters.
public enum RustCoreServiceSupport {

    /// Shared scoped cookie jar for all host HTTP clients. Partitioned by
    /// `CookieJarScopeKey` (sourceId + host) so cookies never leak across
    /// sources or hosts. Injected into every `URLSessionHTTPClient` so cookies
    /// set in one service are visible to the others within the same scope.
    ///
    /// Also injected into `HostRequestRouter` so the router can serve
    /// `cookie.get` / `cookie.set` host requests through the same jar
    /// (login_cookie lane parity with Android).
    public static let sharedCookieJar: ScopedCookieJar = BasicCookieJar()

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
    public static func makeRouter(runtime: ReaderCoreNativeRuntime) -> HostRequestRouter {
        HostRequestRouter(
            httpClient: URLSessionHTTPClient(cookieJar: sharedCookieJar),
            runtime: runtime,
            cookieJar: sharedCookieJar
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
    public static func serializeSource(_ source: BookSource) -> [String: Any] {
        let sourceId = source.id?.isEmpty == false ? source.id! : UUID().uuidString
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
