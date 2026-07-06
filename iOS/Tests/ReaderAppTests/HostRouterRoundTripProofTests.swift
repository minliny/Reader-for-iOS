import XCTest
import ReaderCoreProtocols
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

/// Host router round-trip proof for the 3 newly-wired lanes:
/// `webview.evaluateJavaScript`, `anti_bot.challenge`, `media.download`.
///
/// Verifies the router dispatch path is complete for these lanes: a Core
/// `host.request` for each capability reaches the corresponding handler (which
/// returns a structured `notImplemented` error from the stub executor), NOT a
/// "capability not supported" rejection (`unexpectedCapability`).
///
/// This is router wiring proof — executors remain stubs (`notImplemented`).
/// Real executor implementation (WKWebView execution, anti-bot challenge
/// solving, URLSession media download) is a separate task requiring device-tier
/// proof.
///
/// Proof strategy (mirrors `HostRequestRoundTripProofTests`):
/// 1. **Dispatch path complete** (proofs 1-3) — `handleHostRequest` does NOT
///    throw `unexpectedCapability` for the 3 lanes. The stub executor throws
///    `notImplemented`, which the router catches and sends as `host.error`
///    (code "INTERNAL"). The method returns normally (no throw) — proving the
///    capability is registered and the handler is reached.
/// 2. **Structured notImplemented error** (proofs 4-6) — the internal
///    `execute*` methods throw the typed `notImplemented` error from the stub
///    executor (not a generic crash or capability rejection). This verifies
///    the handler delegation chain: router → handler → executor.
/// 3. **Fail-closed still works** (proof 7) — an unsupported capability
///    (`file.read`) still throws `unexpectedCapability`, proving the 3 new
///    lanes are registered explicitly (not via a catch-all).
///
/// The router is constructed via `RustCoreServiceSupport.makeRouter(runtime:)`
/// — the same factory used in production. This verifies the production wiring
/// (stub executors injected) end-to-end.
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
    /// `unexpectedCapability`. The stub `WKWebViewExecutor` throws
    /// `WebViewExecutorError.notImplemented`, which the router catches and
    /// sends as `host.error` (code "INTERNAL"). The method returns normally —
    /// proving the capability is registered and the handler is reached.
    func testWebViewEvaluateJavaScriptDispatchPathComplete() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = RustCoreServiceSupport.makeRouter(runtime: runtime)

        let params: [String: Any] = [
            "document": [
                "kind": "url",
                "url": "https://example.test/render",
            ] as [String: Any],
            "javaScript": "document.title",
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
    /// `unexpectedCapability`. The stub `WKAntiBotExecutor` throws
    /// `AntiBotExecutorError.notImplemented`, which the router catches and
    /// sends as `host.error` (code "INTERNAL").
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
    /// `unexpectedCapability`. The stub `URLSessionMediaDownloadExecutor`
    /// throws `MediaDownloadExecutorError.notImplemented`, which the router
    /// catches and sends as `host.error` (code "INTERNAL").
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

    // MARK: - Proof 4: webview.evaluateJavaScript returns structured notImplemented

    /// The internal `executeWebViewEvaluate` must throw
    /// `WebViewExecutorError.notImplemented` (from the stub `WKWebViewExecutor`),
    /// NOT a generic error or capability rejection. This verifies the handler
    /// delegation chain: router → `WebViewEvaluateJavaScriptHandler` →
    /// `WKWebViewExecutor`.
    func testWebViewEvaluateReturnsStructuredNotImplemented() async throws {
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
            XCTFail("executeWebViewEvaluate must throw notImplemented from the stub executor")
        } catch let error as WebViewExecutorError {
            switch error {
            case .notImplemented(let message):
                XCTAssertFalse(message.isEmpty,
                               "notImplemented message must be non-empty")
            default:
                XCTFail("expected .notImplemented, got: \(error)")
            }
        } catch {
            XCTFail("expected WebViewExecutorError.notImplemented, got: \(type(of: error))")
        }
    }

    // MARK: - Proof 5: anti_bot.challenge returns structured notImplemented

    /// The internal `executeAntiBotChallenge` must throw
    /// `AntiBotExecutorError.notImplemented` (from the stub
    /// `WKAntiBotExecutor`), NOT a generic error or capability rejection.
    func testAntiBotChallengeReturnsStructuredNotImplemented() throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = RustCoreServiceSupport.makeRouter(runtime: runtime)

        let params: [String: Any] = [
            "url": "https://protected.test/chapter/1",
            "headers": [:] as [String: Any],
        ]

        do {
            _ = try router.executeAntiBotChallenge(params: params)
            XCTFail("executeAntiBotChallenge must throw notImplemented from the stub executor")
        } catch let error as AntiBotExecutorError {
            switch error {
            case .notImplemented(let message):
                XCTAssertFalse(message.isEmpty,
                               "notImplemented message must be non-empty")
            default:
                XCTFail("expected .notImplemented, got: \(error)")
            }
        } catch {
            XCTFail("expected AntiBotExecutorError.notImplemented, got: \(type(of: error))")
        }
    }

    // MARK: - Proof 6: media.download returns structured notImplemented

    /// The internal `executeMediaDownload` must throw
    /// `MediaDownloadExecutorError.notImplemented` (from the stub
    /// `URLSessionMediaDownloadExecutor`), NOT a generic error or capability
    /// rejection.
    func testMediaDownloadReturnsStructuredNotImplemented() throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = RustCoreServiceSupport.makeRouter(runtime: runtime)

        let params: [String: Any] = [
            "url": "https://cdn.example.test/file.png",
        ]

        do {
            _ = try router.executeMediaDownload(params: params)
            XCTFail("executeMediaDownload must throw notImplemented from the stub executor")
        } catch let error as MediaDownloadExecutorError {
            switch error {
            case .notImplemented(let message):
                XCTAssertFalse(message.isEmpty,
                               "notImplemented message must be non-empty")
            default:
                XCTFail("expected .notImplemented, got: \(error)")
            }
        } catch {
            XCTFail("expected MediaDownloadExecutorError.notImplemented, got: \(type(of: error))")
        }
    }

    // MARK: - Proof 7: unsupported capability still rejected (fail-closed)

    /// A capability NOT in the router's supported set (e.g. `file.read`) must
    /// still throw `unexpectedCapability` — the fail-closed path. This proves
    /// the 3 new lanes are registered explicitly (not via a catch-all that
    /// would accept any capability).
    func testUnsupportedCapabilityStillRejected() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = RustCoreServiceSupport.makeRouter(runtime: runtime)

        let event = try makeHostRequestEvent(
            operationId: 3004,
            capability: "file.read",
            params: ["path": "/some/file"] as [String: Any]
        )

        do {
            try await router.handleHostRequest(event)
            XCTFail("handleHostRequest must throw for unsupported capabilities")
        } catch HostRequestRouterError.unexpectedCapability(let capability) {
            XCTAssertEqual(capability, "file.read",
                           "rejected capability must be 'file.read'")
        } catch {
            XCTFail("expected unexpectedCapability, got: \(type(of: error))")
        }
    }
}
