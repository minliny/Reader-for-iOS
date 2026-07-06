import XCTest
import ReaderCoreProtocols
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

/// Stage 3.5: Host request round-trip proof.
///
/// Covers 4 path types: success, failure, capability missing, timeout.
///
/// Verifies `HostRequestRouter`'s behavior for each of the 4 required path types
/// in the host request round-trip (Core `host.request` → router → handler →
/// `host.complete` / `host.error`). Uses stubbed HTTP clients (no real network)
/// and a real `ReaderCoreNativeRuntime` (required for router construction; the
/// C ABI binary is linked transitively via `ReaderShellValidation`).
///
/// Path coverage:
/// 1. **Success** — `executeHTTP` returns the correct result dict (the
///    `host.complete` `params.result` payload: status/headers/body/finalUrl).
/// 2. **Failure** — `executeHTTP` throws when the HTTP client fails (the router
///    catches this and sends `host.error` with code "INTERNAL").
/// 3. **Capability missing** — `handleHostRequest` throws
///    `HostRequestRouterError.unexpectedCapability` for unsupported capabilities
///    (fail-closed path; throws before the runtime is touched).
/// 4. **Timeout** — `executeHTTP` throws a transport error after a stubbed
///    delay (the router would send `host.error` with the timeout message).
///
/// The router's `sendHostComplete` / `sendHostError` are private and send JSON
/// into the live runtime; verifying the in-process result/error structure (via
/// the router's `internal` methods) is the closest observable proof without
/// intercepting `runtime.send`. This mirrors the existing
/// `HostLoginCookieProofTests` pattern (which tests `buildHTTPExecuteResult`
/// directly).
final class HostRequestRoundTripProofTests: XCTestCase {

    // MARK: - Stub HTTP Client

    /// Stub `HTTPClient` for testing: returns a canned response, throws an
    /// error, or delays then throws (simulating timeout). All fields are
    /// immutable (`let`), so `@unchecked Sendable` is safe.
    private final class StubHTTPClient: HTTPClient, @unchecked Sendable {
        private let response: HTTPResponse?
        private let error: Error?
        private let delaySeconds: TimeInterval

        init(response: HTTPResponse) {
            self.response = response
            self.error = nil
            self.delaySeconds = 0
        }

        init(error: Error) {
            self.response = nil
            self.error = error
            self.delaySeconds = 0
        }

        /// After `seconds`, throw `HTTPClientError.transport` simulating a
        /// timeout (mirrors what `URLSessionHTTPClient` throws when
        /// `URLRequest.timeoutInterval` elapses).
        init(timeoutAfter seconds: TimeInterval) {
            self.response = nil
            self.error = HTTPClientError.transport("The request timed out.")
            self.delaySeconds = seconds
        }

        func send(_ request: HTTPRequest) async throws -> HTTPResponse {
            if delaySeconds > 0 {
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
            if let error = error {
                throw error
            }
            return response!
        }
    }

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

    // MARK: - Test 1: Success path

    /// Router receives a valid `host.request` for `http.execute`, dispatches to
    /// the HTTP handler, handler returns success. Verify the `host.complete`
    /// result dict has the correct structure (status / headers / body /
    /// finalUrl).
    ///
    /// `executeHTTP` is the router's internal entry point that builds the
    /// `host.complete` `params.result` dict. Calling it directly verifies the
    /// payload contract without sending an unsolicited `host.complete` into the
    /// live runtime (which has no pending operation to resolve).
    func testHostRequestSuccessPath() async throws {
        let stubResponse = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "text/html; charset=utf-8"],
            data: Data("<html><body>chapter content</body></html>".utf8),
            finalUrl: "https://example.test/chapter/1"
        )
        let client = StubHTTPClient(response: stubResponse)

        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = HostRequestRouter(httpClient: client, runtime: runtime)

        let params: [String: Any] = [
            "url": "https://example.test/chapter/1",
            "method": "GET",
            "headers": ["Accept": "text/html"] as [String: Any],
        ]
        let event = try makeHostRequestEvent(
            operationId: 2001,
            capability: "http.execute",
            params: params
        )
        XCTAssertEqual(event.type, "host.request", "event type must be host.request")
        XCTAssertEqual(event.capability, "http.execute", "event capability must be http.execute")

        // executeHTTP returns the result dict that sendHostComplete wraps into
        // host.complete.params.result.
        let result = try await router.executeHTTP(params: event.hostParams!)

        XCTAssertEqual(result["status"] as? Int, 200,
                       "host.complete result.status must be 200")
        XCTAssertEqual(result["body"] as? String, "<html><body>chapter content</body></html>",
                       "host.complete result.body must match the stubbed response body")
        XCTAssertEqual(result["finalUrl"] as? String, "https://example.test/chapter/1",
                       "host.complete result.finalUrl must match the stubbed finalUrl")
        let headers = result["headers"] as? [String: String]
        XCTAssertNotNil(headers, "host.complete result.headers must be present")
        XCTAssertEqual(headers?["Content-Type"], "text/html; charset=utf-8",
                       "host.complete result.headers[Content-Type] must match")
    }

    // MARK: - Test 2: Failure path

    /// Router receives a `host.request` for `http.execute`, but the handler
    /// fails (network error). `executeHTTP` throws; the router catches this in
    /// `handleHostRequest` and sends `host.error` with code "INTERNAL" and the
    /// error's `localizedDescription`.
    func testHostRequestFailurePath() async throws {
        let client = StubHTTPClient(error: HTTPClientError.transport("Connection refused"))

        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = HostRequestRouter(httpClient: client, runtime: runtime)

        let params: [String: Any] = [
            "url": "https://unreachable.test/chapter/1",
            "method": "GET",
            "headers": [:] as [String: Any],
        ]
        let event = try makeHostRequestEvent(
            operationId: 2002,
            capability: "http.execute",
            params: params
        )

        // executeHTTP must throw — the router's handleHostRequest catches this
        // and sends host.error with code "INTERNAL" + error.localizedDescription.
        do {
            _ = try await router.executeHTTP(params: event.hostParams!)
            XCTFail("executeHTTP must throw when the HTTP client fails")
        } catch let error as HTTPClientError {
            // Verify the error is propagated faithfully (the router would put
            // this into host.error.params.error.message).
            XCTAssertNotNil(error.errorDescription,
                            "host.error message must carry the transport error description")
        } catch {
            XCTFail("expected HTTPClientError, got: \(type(of: error))")
        }
    }

    // MARK: - Test 3: Capability missing path

    /// Router receives a `host.request` for a capability it doesn't support
    /// (`file.read`). `handleHostRequest` throws
    /// `HostRequestRouterError.unexpectedCapability` — the fail-closed path.
    /// This throws before the runtime is touched, so no `host.error` is sent;
    /// the caller (RustCore*Service) is responsible for surfacing the error.
    func testHostRequestCapabilityMissingPath() async throws {
        let client = StubHTTPClient(response: HTTPResponse(
            statusCode: 200, headers: [:], data: Data()
        ))

        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = HostRequestRouter(httpClient: client, runtime: runtime)

        // Build a host.request for an unsupported capability ("file.read").
        let event = try makeHostRequestEvent(
            operationId: 2003,
            capability: "file.read",
            params: ["path": "/some/file"] as [String: Any]
        )

        // handleHostRequest must throw unexpectedCapability — this is the
        // fail-closed path. The router rejects unsupported capabilities before
        // dispatching to any handler.
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

    // MARK: - Test 4: Timeout path

    /// Router receives a `host.request` for `http.execute`, but the handler
    /// times out. `executeHTTP` throws a transport error after the stubbed
    /// delay; the router would catch this and send `host.error` with the
    /// timeout message.
    func testHostRequestTimeoutPath() async throws {
        // Stubbed client delays 0.3s then throws a transport error simulating
        // timeout (mirrors URLSessionHTTPClient's behavior when
        // URLRequest.timeoutInterval elapses).
        let client = StubHTTPClient(timeoutAfter: 0.3)

        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = HostRequestRouter(httpClient: client, runtime: runtime)

        let params: [String: Any] = [
            "url": "https://slow.test/chapter/1",
            "method": "GET",
            "headers": [:] as [String: Any],
        ]
        let event = try makeHostRequestEvent(
            operationId: 2004,
            capability: "http.execute",
            params: params
        )

        // executeHTTP must throw a transport error after the delay — the router
        // would catch this and send host.error with code "INTERNAL" and the
        // timeout message.
        let start = Date()
        do {
            _ = try await router.executeHTTP(params: event.hostParams!)
            XCTFail("executeHTTP must throw on timeout")
        } catch let error as HTTPClientError {
            let elapsed = Date().timeIntervalSince(start)
            // Verify the error arrived after the stubbed delay (not instant),
            // proving the timeout path actually waited.
            XCTAssertGreaterThan(elapsed, 0.2,
                                 "timeout error must arrive after the stubbed delay, got \(elapsed)s")
            XCTAssertLessThan(elapsed, 5.0,
                              "timeout error must arrive within reasonable time, got \(elapsed)s")
            XCTAssertNotNil(error.errorDescription,
                            "host.error message must carry the timeout description")
        } catch {
            XCTFail("expected HTTPClientError, got: \(type(of: error))")
        }
    }
}
