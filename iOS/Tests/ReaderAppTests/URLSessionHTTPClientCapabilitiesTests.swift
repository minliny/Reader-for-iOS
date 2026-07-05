import XCTest
import ReaderCoreProtocols
import ReaderCoreNetwork
@testable import ReaderShellValidation

/// S4 host proof — verifies the three host-side HTTP capabilities implemented in
/// `URLSessionHTTPClient`: cookie jar (read/write/scope isolation), redirect
/// (follow + intercept + finalUrl), and URLAuthenticationChallenge (no-crash on
/// 401). Uses a `URLProtocol` stub (aligned with `WebDAVURLProtocolStub`) so no
/// real network is exercised.
final class URLSessionHTTPClientCapabilitiesTests: XCTestCase {

    // MARK: - Cookie jar

    func testCookieJarReadStampsRequestCookieHeader() async throws {
        let jar = BasicCookieJar()
        let scopeKey = CookieJarScopeKey(sourceId: "src-1", host: "cookie.example.test")
        await jar.setCookie(
            Cookie(name: "session", value: "abc123", domain: "cookie.example.test"),
            scopeKey: scopeKey
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CapabilitiesURLProtocolStub.self]
        defer { CapabilitiesURLProtocolStub.handler = nil }

        var capturedCookieHeader: String?
        CapabilitiesURLProtocolStub.handler = { request in
            capturedCookieHeader = request.value(forHTTPHeaderField: "Cookie")
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data("ok".utf8)
            )
        }

        let client = URLSessionHTTPClient(configuration: configuration, cookieJar: jar)
        let request = HTTPRequest(
            url: "https://cookie.example.test/",
            useCookieJar: true,
            cookieScopeKey: scopeKey
        )
        _ = try await client.send(request)

        XCTAssertEqual(capturedCookieHeader, "session=abc123")
    }

    func testCookieJarWriteStoresSetCookieResponse() async throws {
        let jar = BasicCookieJar()
        let scopeKey = CookieJarScopeKey(sourceId: "src-1", host: "cookie.example.test")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CapabilitiesURLProtocolStub.self]
        defer { CapabilitiesURLProtocolStub.handler = nil }

        CapabilitiesURLProtocolStub.handler = { _ in
            (
                HTTPURLResponse(
                    url: URL(string: "https://cookie.example.test/")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Set-Cookie": "token=xyz; Path=/; Domain=cookie.example.test"]
                )!,
                Data("ok".utf8)
            )
        }

        let client = URLSessionHTTPClient(configuration: configuration, cookieJar: jar)
        let request = HTTPRequest(
            url: "https://cookie.example.test/",
            useCookieJar: true,
            cookieScopeKey: scopeKey
        )
        _ = try await client.send(request)

        let cookies = await jar.getCookies(for: "cookie.example.test", path: "/", scopeKey: scopeKey)
        XCTAssertTrue(cookies.contains { $0.name == "token" && $0.value == "xyz" },
                     "expected token=xyz stored in jar, got: \(cookies)")
    }

    func testCookieJarScopeIsolationDoesNotLeakAcrossSources() async throws {
        let jar = BasicCookieJar()
        let scopeA = CookieJarScopeKey(sourceId: "src-a", host: "iso.example.test")
        let scopeB = CookieJarScopeKey(sourceId: "src-b", host: "iso.example.test")
        await jar.setCookie(
            Cookie(name: "session", value: "from-a", domain: "iso.example.test"),
            scopeKey: scopeA
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CapabilitiesURLProtocolStub.self]
        defer { CapabilitiesURLProtocolStub.handler = nil }

        var capturedCookieHeader: String?
        CapabilitiesURLProtocolStub.handler = { request in
            capturedCookieHeader = request.value(forHTTPHeaderField: "Cookie")
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data("ok".utf8)
            )
        }

        let client = URLSessionHTTPClient(configuration: configuration, cookieJar: jar)
        // Source B reads cookies — must NOT see source A's cookie.
        let request = HTTPRequest(
            url: "https://iso.example.test/",
            useCookieJar: true,
            cookieScopeKey: scopeB
        )
        _ = try await client.send(request)

        XCTAssertNil(capturedCookieHeader,
                      "scope B must not receive scope A's cookie; got: \(capturedCookieHeader ?? "nil")")
    }

    // MARK: - Redirect

    func testRedirectFollowRecordsFinalUrl() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CapabilitiesURLProtocolStub.self]
        defer { CapabilitiesURLProtocolStub.handler = nil }

        CapabilitiesURLProtocolStub.handler = { request in
            let path = request.url?.path ?? ""
            if path == "/start" {
                return (
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 302,
                        httpVersion: nil,
                        headerFields: ["Location": "https://redirect.example.test/dest"]
                    )!,
                    Data()
                )
            }
            // /dest
            return (
                HTTPURLResponse(
                    url: URL(string: "https://redirect.example.test/dest")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "text/plain"]
                )!,
                Data("arrived".utf8)
            )
        }

        let client = URLSessionHTTPClient(configuration: configuration)
        let request = HTTPRequest(url: "https://redirect.example.test/start")

        let response = try await client.send(request)

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.finalUrl, "https://redirect.example.test/dest")
        XCTAssertEqual(String(data: response.data, encoding: .utf8), "arrived")
    }

    func testRedirectInterceptReturns302WhenFollowDisabled() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CapabilitiesURLProtocolStub.self]
        defer { CapabilitiesURLProtocolStub.handler = nil }

        CapabilitiesURLProtocolStub.handler = { request in
            (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 302,
                    httpVersion: nil,
                    headerFields: ["Location": "https://redirect.example.test/dest"]
                )!,
                Data()
            )
        }

        let client = URLSessionHTTPClient(configuration: configuration)
        let request = HTTPRequest(
            url: "https://redirect.example.test/start",
            followRedirects: false
        )

        let response = try await client.send(request)

        XCTAssertEqual(response.statusCode, 302, "redirect must be intercepted, not followed")
        XCTAssertEqual(response.finalUrl, "https://redirect.example.test/start",
                       "finalUrl should be the original request URL when redirect is cancelled")
    }

    func testFinalUrlEqualsRequestUrlWhenNoRedirect() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CapabilitiesURLProtocolStub.self]
        defer { CapabilitiesURLProtocolStub.handler = nil }

        CapabilitiesURLProtocolStub.handler = { request in
            (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data("ok".utf8)
            )
        }

        let client = URLSessionHTTPClient(configuration: configuration)
        let request = HTTPRequest(url: "https://plain.example.test/page")
        let response = try await client.send(request)

        XCTAssertEqual(response.finalUrl, "https://plain.example.test/page")
    }

    // MARK: - URLAuthenticationChallenge

    /// The auth-challenge delegate path is implemented in `HTTPSessionDelegate`
    /// (basic/digest → `.performDefaultHandling` when no `Authorization: Basic`
    /// header is present, `.useCredential` with decoded credentials when it is).
    /// A `URLProtocol` stub cannot drive `URLSession`'s auth-challenge
    /// machinery end-to-end, so this test asserts the no-crash contract: a 401
    /// response is delivered without hanging or throwing.
    func testAuthChallengeDoesNotCrashOn401Response() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CapabilitiesURLProtocolStub.self]
        defer { CapabilitiesURLProtocolStub.handler = nil }

        CapabilitiesURLProtocolStub.handler = { request in
            (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["WWW-Authenticate": "Basic realm=\"protected\""]
                )!,
                Data()
            )
        }

        let client = URLSessionHTTPClient(configuration: configuration)
        let request = HTTPRequest(url: "https://auth.example.test/protected")

        // Use a timeout-bounded task so a hung delegate surfaces as a failure
        // rather than a stuck test.
        let response = try await withThrowingTaskGroup(of: HTTPResponse.self) { group in
            group.addTask { try await client.send(request) }
            group.addTask {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                throw URLError(.timedOut)
            }
            let result = try await group.next()
            group.cancelAll()
            return try XCTUnwrap(result)
        }

        XCTAssertEqual(response.statusCode, 401)
    }

    /// Verifies the basic-auth credential path is wired: a request carrying an
    /// `Authorization: Basic` header is delivered to the stub with the header
    /// intact (the delegate's `basicCredential(from:)` parses this same header
    /// to answer a 401 challenge in the real-device run).
    func testBasicAuthHeaderPreservedOnRequest() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CapabilitiesURLProtocolStub.self]
        defer { CapabilitiesURLProtocolStub.handler = nil }

        var capturedAuth: String?
        CapabilitiesURLProtocolStub.handler = { request in
            capturedAuth = request.value(forHTTPHeaderField: "Authorization")
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data("ok".utf8)
            )
        }

        let client = URLSessionHTTPClient(configuration: configuration)
        // "reader:secret" base64 → "cmVhZGVyOnNlY3JldA=="
        let request = HTTPRequest(
            url: "https://auth.example.test/protected",
            headers: ["Authorization": "Basic cmVhZGVyOnNlY3JldA=="]
        )
        _ = try await client.send(request)

        XCTAssertEqual(capturedAuth, "Basic cmVhZGVyOnNlY3JldA==")
    }
}

// MARK: - URLProtocol stub (aligned with WebDAVURLProtocolStub)

private final class CapabilitiesURLProtocolStub: URLProtocol {
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
                // Deliver the redirect response + finish so the task completes
                // when URLSession decides NOT to follow (delegate cancel). When
                // following, URLSession spawns a new task for the Location URL
                // (re-entering this stub) whose response overrides.
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
