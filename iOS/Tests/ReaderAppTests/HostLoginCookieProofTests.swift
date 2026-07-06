import XCTest
import ReaderCoreProtocols
@testable import ReaderShellValidation

/// iOS Host-side proof for the `login_cookie` lane — mirrors Android's
/// `HostLoginCookieProofTest.kt` (3 cases) so iOS reaches the same proof level.
///
/// Verifies the three capability contracts wired in `HostRequestRouter`:
/// 1. `http.execute` returns `finalUrl` (the post-redirect URL) in the
///    `host.complete` result.
/// 2. `http.execute` captures `Set-Cookie` headers into `result.cookies`.
/// 3. `cookie.set` + `cookie.get` round-trip through the same
///    `ScopedCookieJar`.
///
/// Uses a `URLProtocol` stub (aligned with `CapabilitiesURLProtocolStub` in
/// `URLSessionHTTPClientCapabilitiesTests`) so no real network is exercised.
/// The router's `buildHTTPExecuteResult` is invoked directly to verify the
/// `host.complete` result payload contract without requiring a live Rust Core
/// runtime (the C ABI is not needed for handler-layer proof).
final class HostLoginCookieProofTests: XCTestCase {

    // MARK: - Proof 1: http.execute returns finalUrl after redirect

    /// Mirrors Android `httpExecuteReturnsFinalUrlAfterRedirect`:
    /// mock 302 → /final → 200 "final page"; the `host.complete` result must
    /// carry `finalUrl` ending in `/final`, status 200, and the final body.
    func testHttpExecuteReturnsFinalUrlAfterRedirect() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LoginCookieURLProtocolStub.self]
        defer { LoginCookieURLProtocolStub.handler = nil }

        LoginCookieURLProtocolStub.handler = { request in
            let path = request.url?.path ?? ""
            if path == "/redirect" {
                return (
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 302,
                        httpVersion: nil,
                        headerFields: ["Location": "https://login.example.test/final"]
                    )!,
                    Data()
                )
            }
            // /final
            return (
                HTTPURLResponse(
                    url: URL(string: "https://login.example.test/final")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "text/plain"]
                )!,
                Data("final page".utf8)
            )
        }

        let client = URLSessionHTTPClient(configuration: configuration)
        let request = HTTPRequest(url: "https://login.example.test/redirect")
        let response = try await client.send(request)

        // Build the host.complete result dict the same way the router does.
        let result = HostRequestRouter.buildHTTPExecuteResult(response: response)

        XCTAssertEqual(response.statusCode, 200, "status must be 200 after following redirect")
        guard let finalUrl = result["finalUrl"] as? String else {
            XCTFail("result must have finalUrl, got keys: \(result.keys.sorted())")
            return
        }
        XCTAssertTrue(finalUrl.hasSuffix("/final"),
                      "finalUrl must end with /final, got: \(finalUrl)")
        XCTAssertEqual(result["status"] as? Int, 200, "result.status must be 200")
        XCTAssertEqual(result["body"] as? String, "final page",
                       "result.body must be the final page body")
    }

    // MARK: - Proof 2: http.execute captures Set-Cookie header

    /// Mirrors Android `httpExecuteCapturesSetCookieHeader`:
    /// mock 200 + `Set-Cookie: session=abc123; Path=/; HttpOnly`; the
    /// `host.complete` result must contain a parsed cookie with
    /// `{name: "session", value: "abc123"}`.
    func testHttpExecuteCapturesSetCookieHeader() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LoginCookieURLProtocolStub.self]
        defer { LoginCookieURLProtocolStub.handler = nil }

        LoginCookieURLProtocolStub.handler = { _ in
            (
                HTTPURLResponse(
                    url: URL(string: "https://login.example.test/")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Set-Cookie": "session=abc123; Path=/; HttpOnly"]
                )!,
                Data("ok".utf8)
            )
        }

        let client = URLSessionHTTPClient(configuration: configuration)
        let request = HTTPRequest(url: "https://login.example.test/")
        let response = try await client.send(request)

        let result = HostRequestRouter.buildHTTPExecuteResult(response: response)

        guard let cookies = result["cookies"] as? [[String: Any]] else {
            XCTFail("result must have cookies array, got keys: \(result.keys.sorted())")
            return
        }
        XCTAssertEqual(cookies.count, 1, "must capture exactly 1 cookie")
        let cookie = try XCTUnwrap(cookies.first)
        XCTAssertEqual(cookie["name"] as? String, "session", "cookie name must be session")
        XCTAssertEqual(cookie["value"] as? String, "abc123", "cookie value must be abc123")
    }

    // MARK: - Proof 3: cookie.set + cookie.get round-trip

    /// Mirrors Android `cookieSetAndGetRoundTrip`:
    /// set a cookie via `cookie.set`, then read it back via `cookie.get` for
    /// the same URL; the returned cookie must match.
    func testCookieSetAndGetRoundTrip() async throws {
        let jar = HostScopedCookieJarFactory.makeBasicCookieJar()

        // 1. cookie.set
        let setHandler = CookieSetHandler(cookieJar: jar)
        let setParams: [String: Any] = [
            "url": "https://example.test/login",
            "cookie": [
                "name": "sid",
                "value": "session-token-xyz",
                "domain": "example.test",
                "path": "/",
                "secure": true,
                "httpOnly": true,
            ] as [String: Any],
        ]
        let setResult = try await setHandler.handle(params: setParams)
        XCTAssertEqual(setResult["stored"] as? Bool, true,
                       "cookie.set must return stored=true, got: \(setResult)")

        // 2. cookie.get — read back for the same URL
        let getHandler = CookieGetHandler(cookieJar: jar)
        let getParams: [String: Any] = [
            "url": "https://example.test/login",
        ]
        let getResult = try await getHandler.handle(params: getParams)
        guard let cookies = getResult["cookies"] as? [[String: Any]] else {
            XCTFail("cookie.get must return cookies array, got: \(getResult)")
            return
        }
        XCTAssertFalse(cookies.isEmpty, "cookie.get must return at least 1 cookie")

        var foundSid: [String: Any]?
        for c in cookies {
            if c["name"] as? String == "sid" {
                foundSid = c
                break
            }
        }
        let sid = try XCTUnwrap(foundSid,
                                "cookie.get must return the sid cookie set by cookie.set")
        XCTAssertEqual(sid["value"] as? String, "session-token-xyz",
                       "sid value must match")
        XCTAssertEqual(sid["domain"] as? String, "example.test",
                       "sid domain must match")
        XCTAssertEqual(sid["path"] as? String, "/", "sid path must match")
        XCTAssertEqual(sid["secure"] as? Bool, true, "sid secure must match")
        XCTAssertEqual(sid["httpOnly"] as? Bool, true, "sid httpOnly must match")
    }
}

// MARK: - URLProtocol stub (aligned with CapabilitiesURLProtocolStub)

private final class LoginCookieURLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: StubError.missingHandler)
            return
        }
        do {
            let (response, data) = try handler(request)
            // For 3xx redirect responses, notify URLSession of the redirect so
            // its `willPerformHTTPRedirection` delegate is invoked (matching real
            // HTTP transport behavior). URLSession then creates a new task for
            // the Location URL — which re-enters this stub — if the delegate
            // allows the redirect.
            if (300...399).contains(response.statusCode),
               let location = response.value(forHTTPHeaderField: "Location"),
               let redirectURL = URL(string: location) {
                let redirectRequest = URLRequest(url: redirectURL)
                client?.urlProtocol(self, wasRedirectedTo: redirectRequest, redirectResponse: response)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private enum StubError: Error {
    case missingHandler
}
