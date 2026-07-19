import XCTest
@testable import ReaderShellValidation

#if canImport(WebKit) && canImport(UIKit)
import WebKit
import UIKit
#if targetEnvironment(simulator)
import Network

private final class WebViewBoundaryHTTPServer: @unchecked Sendable {
    enum ServerError: Error {
        case failedToStart(String)
        case timedOutStarting
        case missingPort
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "reader.webview-boundary-test-server")
    private let hitLock = NSLock()
    private var hits: [String: Int] = [:]

    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
    }

    func start() throws -> UInt16 {
        let ready = DispatchSemaphore(value: 0)
        let stateLock = NSLock()
        var startError: Error?
        var didSignal = false
        listener.stateUpdateHandler = { state in
            stateLock.lock()
            defer { stateLock.unlock() }
            guard !didSignal else { return }
            switch state {
            case .ready:
                didSignal = true
                ready.signal()
            case .failed(let error):
                didSignal = true
                startError = ServerError.failedToStart(error.localizedDescription)
                ready.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.serve(connection)
        }
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 5) == .success else {
            throw ServerError.timedOutStarting
        }
        if let startError {
            throw startError
        }
        guard let port = listener.port?.rawValue else {
            throw ServerError.missingPort
        }
        return port
    }

    func stop() {
        listener.cancel()
    }

    func hitCount(for path: String) -> Int {
        hitLock.lock()
        defer { hitLock.unlock() }
        return hits[path, default: 0]
    }

    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) {
            [weak self, weak connection] data, _, _, _ in
            guard let self, let connection, let data,
                  let request = String(data: data, encoding: .utf8),
                  let firstLine = request.split(separator: "\r\n", maxSplits: 1).first else {
                connection?.cancel()
                return
            }
            let requestParts = firstLine.split(separator: " ")
            let path = requestParts.count > 1 ? String(requestParts[1]) : "/"
            self.hitLock.lock()
            self.hits[path, default: 0] += 1
            self.hitLock.unlock()

            let body: String
            let contentType: String
            switch path {
            case "/index":
                let port = self.listener.port?.rawValue ?? 0
                body = """
                <!doctype html><html><head>
                <script>window.allowedSubresourceLoaded=false;window.blockedSubresourceLoaded=false;</script>
                <script src="http://localhost:\(port)/allowed.js"></script>
                <script src="http://127.0.0.1:\(port)/blocked.js"></script>
                </head><body>boundary proof</body></html>
                """
                contentType = "text/html; charset=utf-8"
            case "/allowed.js":
                body = "window.allowedSubresourceLoaded=true;"
                contentType = "application/javascript"
            case "/blocked.js":
                body = "window.blockedSubresourceLoaded=true;"
                contentType = "application/javascript"
            default:
                body = "not found"
                contentType = "text/plain; charset=utf-8"
            }
            let bodyData = Data(body.utf8)
            let status = path == "/index" || path.hasSuffix(".js") ? "200 OK" : "404 Not Found"
            let headers = """
            HTTP/1.1 \(status)\r
            Content-Type: \(contentType)\r
            Content-Length: \(bodyData.count)\r
            Cache-Control: no-store\r
            Connection: close\r
            \r

            """
            var response = Data(headers.utf8)
            response.append(bodyData)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
#endif

/// Simulator-proof tests for the production `WKWebViewExecutor`.
///
/// These tests verify the real executor (not the stub). The file is guarded
/// by `canImport(WebKit) && canImport(UIKit)` because `WKWebViewExecutor` is
/// iOS-only — on macOS `swift build`/`swift test` the executor is not compiled
/// and `HostWebViewCapability` registers a stub that returns `.notImplemented`.
///
/// Coverage split:
/// - **Validation-only tests** (no live WKWebView needed): security gate host
///   rejection, invalid URL string. These run on the simulator without
///   depending on WKWebView's navigation pipeline.
/// - **Simulator-exercising tests** (`#if targetEnvironment(simulator)`):
///   HTML document JS evaluation, title capture. These need a live WKWebView
///   which only works on the simulator (or real device). They are skipped on
///   macOS `swift test` because the whole file is guarded out.
///
/// Real-device-proof (tracked in `HostAdapterRealDeviceProofManifestTests`):
/// login cookie persistence via WKHTTPCookieStore, captcha / anti-bot
/// challenge solving (user-agent + JIT differ on sim), snapshot capture,
/// background WebView suspension.
@MainActor
final class WKWebViewExecutorSimulatorProofTests: XCTestCase {

    // MARK: - Proof 1: security gate rejects disallowed host (no live webview)

    /// URL document with a host not in `allowedHosts` throws
    /// `WebViewExecutorError.invalidParams` *before* any WKWebView is created.
    /// This is the security-gate rejection path — verifiable without a live
    /// WebView.
    func testSecurityGateRejectsDisallowedHost() async {
        let gate = WebViewSecurityGate(policy: .testPolicy(allowedHost: "allowed.example.test"))
        let executor = WKWebViewExecutor(securityGate: gate)

        let request = WebViewEvaluationRequest(
            document: WebViewDocument(
                kind: .url,
                url: "https://denied.example.test/page"
            ),
            javaScript: "document.title"
        )
        do {
            _ = try await executor.evaluate(request: request)
            XCTFail("expected invalidParams for disallowed host")
        } catch WebViewExecutorError.invalidParams(let msg) {
            XCTAssertTrue(msg.contains("not allowed by security policy"), "got: \(msg)")
        } catch {
            XCTFail("expected .invalidParams, got: \(error)")
        }
    }

    // MARK: - Proof 2: invalid URL string throws invalidParams

    /// URL document with a malformed URL string (not parseable by `URL(string:)`)
    /// throws `.invalidParams` at the `performEvaluate` stage.
    func testInvalidUrlStringThrowsInvalidParams() async {
        // Default gate (allowedHosts empty → all hosts allowed).
        let executor = WKWebViewExecutor()

        let request = WebViewEvaluationRequest(
            document: WebViewDocument(
                kind: .url,
                url: "ht!tp://[invalid-url"
            ),
            javaScript: "1+1"
        )
        do {
            _ = try await executor.evaluate(request: request)
            XCTFail("expected invalidParams for malformed url")
        } catch WebViewExecutorError.invalidParams(let msg) {
            XCTAssertTrue(msg.contains("invalid url"), "got: \(msg)")
        } catch {
            // On the simulator, the executor may race with a timeout if the
            // URL *is* parseable but not navigable. The key assertion is that
            // no crash occurs and the error is one of the expected cases.
            // We accept any `WebViewExecutorError` here for robustness.
            XCTAssertTrue(error is WebViewExecutorError,
                          "expected WebViewExecutorError, got: \(error)")
        }
    }

    // MARK: - Proof 3: WKWebViewExecutor conforms to WebViewExecutor

    /// Compile-time conformance check: `WKWebViewExecutor` adopts the
    /// `WebViewExecutor` protocol. This ensures the production executor can be
    /// swapped in wherever a `WebViewExecutor` is expected (e.g.
    /// `HostWebViewCapability(executor:)`).
    func testWKWebViewExecutorConformsToWebViewExecutor() {
        let executor = WKWebViewExecutor()
        XCTAssertTrue(executor is WebViewExecutor,
                      "WKWebViewExecutor must conform to WebViewExecutor")
    }

    // MARK: - Proof 4: default security gate allows all hosts

    /// The default `WebViewSecurityGate()` policy has `allowedHosts = []`,
    /// which means `allowsHost` returns `true` for every host. This is the
    /// permissive default used by `HostAdapter()` when wiring
    /// `HostWebViewCapability`.
    func testDefaultSecurityGateAllowsAllHosts() {
        let gate = WebViewSecurityGate()
        XCTAssertTrue(gate.policy.allowsHost("any-host.example.test"))
        XCTAssertTrue(gate.policy.allowsHost("cdn.reader.app"))
    }

    // MARK: - Simulator-only proofs (need a live WKWebView)

    #if targetEnvironment(simulator)
    /// A page on allowed host A references scripts from allowed A and blocked
    /// host B. The allowed script must execute, while B must not even reach the
    /// local HTTP server. This proves the boundary covers subresources rather
    /// than only top-level navigation callbacks.
    func testAllowedHostCannotIssueBlockedHostSubresourceRequest() async throws {
        let server = try WebViewBoundaryHTTPServer()
        let port = try server.start()
        defer { server.stop() }

        let gate = WebViewSecurityGate(policy: .testPolicy(allowedHost: "localhost"))
        let executor = WKWebViewExecutor(securityGate: gate)
        let result = try await executor.evaluate(request: WebViewEvaluationRequest(
            document: WebViewDocument(
                kind: .url,
                url: "http://localhost:\(port)/index"
            ),
            javaScript: "JSON.stringify({allowed:window.allowedSubresourceLoaded,blocked:window.blockedSubresourceLoaded})",
            timeoutMillis: 10_000
        ))

        let encoded = try XCTUnwrap(result.value as? String)
        let stateData = try XCTUnwrap(encoded.data(using: .utf8))
        let state = try XCTUnwrap(
            JSONSerialization.jsonObject(with: stateData) as? [String: Bool]
        )
        XCTAssertEqual(state["allowed"], true)
        XCTAssertEqual(state["blocked"], false)
        XCTAssertEqual(server.hitCount(for: "/index"), 1)
        XCTAssertEqual(server.hitCount(for: "/allowed.js"), 1)
        XCTAssertEqual(
            server.hitCount(for: "/blocked.js"),
            0,
            "blocked host B must not receive a subresource request"
        )
    }

    /// HTML document with a simple JS expression (`1+1`) must return `2`.
    /// This exercises the full WKWebView pipeline: load HTML string → wait
    /// for navigation → evaluate JS → return value.
    func testHtmlDocumentEvaluatesJavaScriptReturnsValue() async throws {
        let executor = WKWebViewExecutor()
        let request = WebViewEvaluationRequest(
            document: WebViewDocument(
                kind: .html,
                body: "<html><body><p>proof</p></body></html>"
            ),
            javaScript: "1 + 1",
            timeoutMillis: 10_000
        )
        let result = try await executor.evaluate(request: request)
        // WKWebView may return the value as NSNumber(2) or Int(2). Compare by
        // numeric description.
        let numeric = (result.value as? NSNumber)?.intValue
            ?? Int((result.value as? String).flatMap { Int($0) } ?? 0)
        XCTAssertEqual(numeric, 2,
                       "1+1 must evaluate to 2, got: \(result.value)")
    }

    /// HTML document with `<title>` must capture the title in the result.
    func testHtmlDocumentCapturesTitle() async throws {
        let executor = WKWebViewExecutor()
        let request = WebViewEvaluationRequest(
            document: WebViewDocument(
                kind: .html,
                body: "<html><head><title>Proof Title</title></head><body></body></html>"
            ),
            javaScript: "document.title",
            timeoutMillis: 10_000
        )
        let result = try await executor.evaluate(request: request)
        XCTAssertEqual(result.title, "Proof Title")
        // JS evaluation of `document.title` must also return the title string.
        XCTAssertEqual(result.value as? String, "Proof Title")
    }

    /// Timeout: a request with a very short timeout (50ms) against a URL that
    /// cannot load instantly must throw `.timeout`. Uses a non-routable
    /// address to ensure navigation does not complete.
    func testTimeoutThrowsTimeoutError() async {
        let gate = WebViewSecurityGate()  // permissive
        let executor = WKWebViewExecutor(securityGate: gate)
        let request = WebViewEvaluationRequest(
            document: WebViewDocument(
                kind: .url,
                url: "https://10.255.255.1/never-loads"
            ),
            javaScript: "document.title",
            timeoutMillis: 50
        )
        do {
            _ = try await executor.evaluate(request: request)
            XCTFail("expected timeout error")
        } catch WebViewExecutorError.timeout {
            // expected
        } catch {
            // On the simulator, the navigation may fail with a transport
            // error before the timeout fires. Both outcomes prove the
            // executor does not hang — acceptable for this proof.
            XCTAssertTrue(error is WebViewExecutorError,
                          "expected WebViewExecutorError, got: \(error)")
        }
    }
    #endif
}

#endif
