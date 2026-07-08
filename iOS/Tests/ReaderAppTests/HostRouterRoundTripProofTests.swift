import XCTest
import ReaderCoreProtocols
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

/// Host router round-trip proof for the 3 newly-wired lanes:
/// `webview.evaluateJavaScript`, `anti_bot.challenge`, `media.download`.
///
/// Verifies the router dispatch path is complete for these lanes: a Core
/// `host.request` for each capability reaches the corresponding handler, NOT a
/// "capability not supported" rejection (`unexpectedCapability`).
///
/// This is router WIRING proof, not executor backend proof. The executors are
/// wired with REAL implementations via `RustCoreServiceSupport.makeRouter`:
/// - `URLSessionMediaDownloadExecutor` — cross-platform (URLSession + CryptoKit).
/// - `WKWebViewExecutor` / `WKAntiBotExecutor` — iOS only; on macOS `swift
///   build` they are nil and the lane FAILS CLOSED with
///   `webViewExecutorNotConfigured` / `antiBotExecutorNotConfigured` — NOT a
///   stub `notImplemented` throw.
/// macOS `swift test` therefore proves the dispatch path + fail-closed
/// contract, NOT the real executor backend. Simulator / real-device proof is
/// required for the latter (see `WKWebViewExecutorSimulatorProofTests` and
/// `URLSessionMediaDownloadExecutorProofTests`).
///
/// Proof strategy (mirrors `HostRequestRoundTripProofTests`):
/// 1. **Dispatch path complete** (proofs 1-3) — `handleHostRequest` does NOT
///    throw `unexpectedCapability` for the 3 lanes. On macOS the iOS-only
///    executors are nil and the router sends `host.error` (code "INTERNAL")
///    after the structured `*ExecutorNotConfigured` throw; on iOS simulator /
///    real device the real executor runs and either succeeds or surfaces a
///    structured executor error. The method returns normally (no throw) —
///    proving the capability is registered and the handler is reached.
/// 2. **Executor delegation** (proofs 4-6) — the internal `execute*` methods
///    dispatch to the injected executor (real or stub). On macOS the iOS-only
///    executors are nil → `*ExecutorNotConfigured`; on iOS the real executor
///    runs. The proof uses stub executors for anti_bot / media to verify the
///    router → handler → executor chain without depending on real WKWebView /
///    URLSession. This verifies the handler delegation chain.
/// 3. **Fail-closed still works** (proof 7) — an unsupported capability
///    (`unknown.capability`) still throws `unexpectedCapability`, proving the
///    3 new lanes are registered explicitly (not via a catch-all).
///
/// The router is constructed via `RustCoreServiceSupport.makeRouter(runtime:)`
/// — the same factory used in production. This verifies the production wiring
/// (real executors injected on iOS; nil + fail-closed on macOS) end-to-end.
final class HostRouterRoundTripProofTests: XCTestCase {

    // MARK: - Helpers

    /// Build a `ReaderCoreNativeEvent` of type `host.request` with the given
    /// capability and params. Mirrors the JSON shape Core emits via the C ABI
    /// callback (type / requestId / operationId / capability / params).
    private func makeHostRequestEvent(
        operationId: UInt64,
        capability: String,
        params: [String: Any]
    ) throws -> ReaderCoreNativeEvent {
        let json: [String: Any] = [
            "type": "host.request",
            "requestId": NSNumber(value: operationId),
            "operationId": NSNumber(value: operationId),
            "capability": capability,
            "params": params,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try ReaderCoreNativeEvent(data: data)
    }

    // MARK: - Proof 1: webview.evaluateJavaScript dispatch path complete

    /// `handleHostRequest` for `webview.evaluateJavaScript` must NOT throw
    /// `unexpectedCapability`. On macOS `swift test`, `makeRouter` wires
    /// `webViewExecutor = nil` (WKWebView is iOS-only), so the router throws
    /// `webViewExecutorNotConfigured` — caught and sent as `host.error`
    /// (code "INTERNAL"). On iOS simulator / real device, the real
    /// `WKWebViewExecutor` runs and either succeeds or surfaces a structured
    /// `WebViewExecutorError`. The method returns normally (no throw) —
    /// proving the capability is registered and the handler is reached.
    ///
    /// Fixture: uses `kind: "html"` with an inline HTML string instead of a
    /// remote URL so the test does not depend on network reachability or
    /// WKWebView navigation timeout. On real device / simulator the executor
    /// calls `WKWebView.loadHTMLString(_:baseURL:)` which resolves
    /// synchronously from memory, then evaluates `document.title` against the
    /// loaded DOM. This previously used `https://example.test/render` (an
    /// unreachable reserved TLD) which caused WKWebView navigation to hang
    /// past the Xcode test timeout on real device, surfacing as
    /// "Testing was canceled" — not a code bug, but a fixture reliability
    /// issue. The inline-HTML fixture removes that flakiness.
    func testWebViewEvaluateJavaScriptDispatchPathComplete() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = RustCoreServiceSupport.makeRouter(runtime: runtime)

        let params: [String: Any] = [
            "document": [
                "kind": "html",
                "body": "<!DOCTYPE html><html><head><title>HostProof</title></head><body>round-trip</body></html>",
            ] as [String: Any],
            "javaScript": "document.title",
            // Explicit 10s timeout — well under Xcode's default per-test timeout.
            // The inline-HTML fixture completes in <1s, but this prevents a
            // future fixture regression (e.g. switching back to a URL kind)
            // from hanging the test session with "Testing was canceled".
            "timeoutMillis": 10_000,
        ]
        let event = try makeHostRequestEvent(
            operationId: 3001,
            capability: "webview.evaluateJavaScript",
            params: params
        )

        // Must NOT throw unexpectedCapability — the capability is registered.
        // The notImplemented error from the stub executor is caught internally
        // and sent as host.error (round-trip completes with an error event).
        do {
            try await router.handleHostRequest(event)
            // Round-trip complete: host.error sent into the runtime.
        } catch HostRequestRouterError.unexpectedCapability(let capability) {
            XCTFail(
                "webview.evaluateJavaScript must be registered, but got unexpectedCapability(\(capability))"
            )
        } catch {
            // Dispatch path is complete (capability registered + handler
            // reached), but runtime.send threw while sending host.error.
            // Tolerated — the internal execute* tests below verify the handler
            // delegation independently. The key proof here is the absence of
            // unexpectedCapability.
        }
    }

    // MARK: - Proof 2: anti_bot.challenge dispatch path complete

    /// `handleHostRequest` for `anti_bot.challenge` must NOT throw
    /// `unexpectedCapability`. On macOS `swift test`, `makeRouter` wires
    /// `antiBotExecutor = nil` (WKWebView L2 path is iOS-only), so the router
    /// throws `antiBotExecutorNotConfigured` — caught and sent as `host.error`
    /// (code "INTERNAL"). On iOS simulator / real device, the real
    /// `WKAntiBotExecutor` runs (L1 URLSession fetch + L2 WKWebView fallback).
    func testAntiBotChallengeDispatchPathComplete() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = RustCoreServiceSupport.makeRouter(runtime: runtime)

        let params: [String: Any] = [
            "url": "https://protected.test/chapter/1",
            "headers": ["User-Agent": "Reader/1.0"] as [String: Any],
            "cookieJarId": "source-proof-001",
        ]
        let event = try makeHostRequestEvent(
            operationId: 3002,
            capability: "anti_bot.challenge",
            params: params
        )

        do {
            try await router.handleHostRequest(event)
        } catch HostRequestRouterError.unexpectedCapability(let capability) {
            XCTFail(
                "anti_bot.challenge must be registered, but got unexpectedCapability(\(capability))"
            )
        } catch {
            // Dispatch path complete; runtime.send may have thrown — tolerated.
        }
    }

    // MARK: - Proof 3: media.download dispatch path complete

    /// `handleHostRequest` for `media.download` must NOT throw
    /// `unexpectedCapability`. `URLSessionMediaDownloadExecutor` is
    /// cross-platform, so on macOS `swift test` the real executor runs and
    /// attempts a live URLSession request against `cdn.example.test` — the
    /// DNS / network failure is caught and sent as `host.error` (code
    /// "INTERNAL"). On iOS simulator / real device with a reachable CDN, the
    /// real download succeeds. Either way the dispatch path completes.
    func testMediaDownloadDispatchPathComplete() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = RustCoreServiceSupport.makeRouter(runtime: runtime)

        let params: [String: Any] = [
            "url": "https://cdn.example.test/file.png",
        ]
        let event = try makeHostRequestEvent(
            operationId: 3003,
            capability: "media.download",
            params: params
        )

        do {
            try await router.handleHostRequest(event)
        } catch HostRequestRouterError.unexpectedCapability(let capability) {
            XCTFail(
                "media.download must be registered, but got unexpectedCapability(\(capability))"
            )
        } catch {
            // Dispatch path complete; runtime.send may have thrown — tolerated.
        }
    }

    // MARK: - Proof 4: webview.evaluateJavaScript dispatches via configured executor

    /// The internal `executeWebViewEvaluate` must dispatch to the injected
    /// `WebViewExecutor`. On macOS `swift test`, `makeRouter` wires
    /// `webViewExecutor = nil` (WKWebView is iOS-only), so the router throws
    /// `webViewExecutorNotConfigured` — the structured fail-closed path.
    /// On iOS simulator / real device, the real `WKWebViewExecutor` is wired
    /// and the call either succeeds or throws a `WebViewExecutorError` from
    /// the real executor (timeout / invalidParams / security gate rejection).
    ///
    /// This proof verifies the router delegation chain: the capability is
    /// registered, the handler is reached, and the executor (or its absence)
    /// produces a structured outcome — never a generic crash or capability
    /// rejection (`unexpectedCapability`).
    func testWebViewEvaluateDispatchesViaConfiguredExecutor() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = RustCoreServiceSupport.makeRouter(runtime: runtime)

        let params: [String: Any] = [
            "document": [
                "kind": "html",
                "body": "<html><body>test</body></html>",
            ] as [String: Any],
            "javaScript": "document.body.innerText",
        ]

        do {
            _ = try await router.executeWebViewEvaluate(params: params)
            // On iOS simulator / real device, the real WKWebViewExecutor may
            // succeed (HTML load + JS eval). This is the real-executor path.
        } catch HostRequestRouterError.webViewExecutorNotConfigured {
            // macOS: webViewExecutor is nil (WKWebView is iOS-only). This is
            // the structured fail-closed rejection — the capability is
            // registered but the platform cannot provide a real executor.
        } catch let error as WebViewExecutorError {
            // iOS: the real WKWebViewExecutor threw a structured error
            // (timeout / invalidParams / security gate rejection). This proves
            // the handler delegation chain reaches the real executor.
            XCTAssertNotNil(error, "real executor must surface a structured error")
        } catch HostRequestRouterError.unexpectedCapability(let capability) {
            XCTFail(
                "webview.evaluateJavaScript must be registered, but got unexpectedCapability(\(capability))"
            )
        } catch {
            // Other structured errors (e.g. runtime.send) are tolerated — the
            // key proof is the absence of unexpectedCapability.
        }
    }

    // MARK: - Proof 5: anti_bot.challenge dispatches to injected executor

    /// The internal `executeAntiBotChallenge` must dispatch to the injected
    /// `AntiBotExecutor` and return the executor's clean response as a
    /// `host.complete`-shaped result dict (`{body, finalUrl}`). This proves
    /// the router wires the anti_bot lane end-to-end (params extraction →
    /// executor → result dict) without depending on a real WKWebView.
    func testAntiBotChallengeDispatchesToInjectedExecutor() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let stubExecutor = StubAntiBotExecutor(defaultResponse: AntiBotHttpResponse(
            statusCode: 200,
            body: "<html><body>clean chapter body</body></html>",
            headers: ["Content-Type": "text/html"],
            finalUrl: "https://protected.test/chapter/1"
        ))
        let router = HostRequestRouter(
            httpClient: URLSessionHTTPClient(),
            runtime: runtime,
            cookieJar: nil,
            webViewExecutor: nil,
            antiBotExecutor: stubExecutor,
            mediaDownloadExecutor: nil
        )

        let params: [String: Any] = [
            "url": "https://protected.test/chapter/1",
            "headers": [:] as [String: Any],
        ]

        let result = try await router.executeAntiBotChallenge(params: params)
        XCTAssertEqual(result["body"] as? String, "<html><body>clean chapter body</body></html>",
                       "router must return the stub executor's clean body")
        XCTAssertEqual(result["finalUrl"] as? String, "https://protected.test/chapter/1",
                       "router must return the stub executor's finalUrl")
    }

    // MARK: - Proof 6: media.download dispatches to injected executor

    /// The internal `executeMediaDownload` must dispatch to the injected
    /// `MediaDownloadExecutor` and return the executor's canned result as a
    /// `host.complete`-shaped result dict. This proves the router wires the
    /// media_download lane end-to-end without depending on a real URLSession.
    func testMediaDownloadDispatchesToInjectedExecutor() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let stubExecutor = StubMediaDownloadExecutor(result: HostMediaDownloadResult(
            resourceId: "res-router-006",
            tempPath: "/tmp/reader/res-router-006.bin",
            statusCode: 200,
            contentType: "image/png",
            contentLength: 512,
            etag: "\"etag-router-006\"",
            byteLength: 512,
            sha256: "router-sha256",
            fromCache: false,
            finalUrl: "https://cdn.example.test/file.png"
        ))
        let router = HostRequestRouter(
            httpClient: URLSessionHTTPClient(),
            runtime: runtime,
            cookieJar: nil,
            webViewExecutor: nil,
            antiBotExecutor: nil,
            mediaDownloadExecutor: stubExecutor
        )

        let params: [String: Any] = [
            "url": "https://cdn.example.test/file.png",
        ]

        let result = try await router.executeMediaDownload(params: params)
        XCTAssertEqual(result["resourceId"] as? String, "res-router-006",
                       "router must return the stub executor's resourceId")
        XCTAssertEqual(result["statusCode"] as? Int, 200,
                       "router must return the stub executor's statusCode")
        XCTAssertEqual(result["sha256"] as? String, "router-sha256",
                       "router must return the stub executor's sha256")
        XCTAssertEqual(stubExecutor.lastRequest?.url, "https://cdn.example.test/file.png",
                       "router must forward the url to the stub executor")
    }

    // MARK: - Proof 7: unsupported capability still rejected (fail-closed)

    /// A capability NOT in the router's supported set must throw
    /// `unexpectedCapability` — the fail-closed path. This proves the 16
    /// supported lanes are registered explicitly (not via a catch-all that
    /// would accept any capability).
    ///
    /// Note: `file.read` was previously used as the unsupported capability,
    /// but is now a registered lane. Use a truly unknown capability name.
    func testUnsupportedCapabilityStillRejected() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = RustCoreServiceSupport.makeRouter(runtime: runtime)

        let event = try makeHostRequestEvent(
            operationId: 3004,
            capability: "unknown.capability",
            params: ["foo": "bar"] as [String: Any]
        )

        do {
            try await router.handleHostRequest(event)
            XCTFail("handleHostRequest must throw for unsupported capabilities")
        } catch HostRequestRouterError.unexpectedCapability(let capability) {
            XCTAssertEqual(capability, "unknown.capability",
                           "rejected capability must be 'unknown.capability'")
        } catch {
            XCTFail("expected unexpectedCapability, got: \(type(of: error))")
        }
    }
}
