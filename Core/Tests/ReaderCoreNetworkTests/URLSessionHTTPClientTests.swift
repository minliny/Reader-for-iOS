import XCTest
import ReaderCoreNetwork
import ReaderCoreProtocols
import ReaderCoreModels
@testable import ReaderPlatformAdapters

final class URLSessionHTTPClientTests: XCTestCase {
    var client: URLSessionHTTPClient!
    var jar: BasicCookieJar!

    override func setUp() {
        super.setUp()
        jar = BasicCookieJar()
        client = URLSessionHTTPClient(cookieJar: jar)
    }

    override func tearDown() {
        client = nil
        jar = nil
        super.tearDown()
    }

    func testInvalidURLThrows() async throws {
        let request = HTTPRequest(url: "not-a-url", method: "GET")
        do {
            _ = try await client.send(request)
            XCTFail("Expected error")
        } catch let error as ReaderError {
            XCTAssertEqual(error.code, .invalidInput)
            XCTAssertEqual(error.failure?.type, .RULE_INVALID)
        }
    }

    // MARK: - Header capability tests

    func testDefaultHeadersTransmittedInRequest() async throws {
        let mock = CookieContractURLProtocol.Mock()
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "ok",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-Default"), "default-value")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Language"), "zh-CN")
            }
        )

        client = makeClient(mock: mock, defaultHeaders: [
            "X-Default": "default-value",
            "Accept-Language": "zh-CN"
        ])

        let response = try await client.send(HTTPRequest(
            url: "https://fixture.local/header/test"
        ))

        XCTAssertEqual(response.statusCode, 200)
        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testMissingRequiredHeaderThrowsHeaderRequired() async throws {
        let mock = CookieContractURLProtocol.Mock()
        client = makeClient(mock: mock)

        do {
            _ = try await client.send(HTTPRequest(
                url: "https://fixture.local/header/required",
                requiredHeaders: ["X-Required-Token"]
            ))
            XCTFail("Expected HEADER_REQUIRED")
        } catch let error as MappedReaderError {
            XCTAssertEqual(error.code, .HEADER_REQUIRED)
            XCTAssertEqual(error.stage, .request_build)
            XCTAssertEqual(error.context.details["headerName"], "X-Required-Token")
        }

        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testRequestHeadersOverrideSameNameDefaultHeaders() async throws {
        let mock = CookieContractURLProtocol.Mock()
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "ok",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json",
                               "Per-request header must override defaultHeader with same name")
            }
        )

        client = makeClient(mock: mock, defaultHeaders: [
            "Accept": "text/html"
        ])

        let response = try await client.send(HTTPRequest(
            url: "https://fixture.local/header/override",
            headers: ["Accept": "application/json"]
        ))

        XCTAssertEqual(response.statusCode, 200)
        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testCustomHeadersTransmittedInRequest() async throws {
        let mock = CookieContractURLProtocol.Mock()
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "ok",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-Source-Token"), "source-token-001")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "text/plain")
            }
        )

        client = makeClient(mock: mock)

        let response = try await client.send(HTTPRequest(
            url: "https://fixture.local/header/custom",
            headers: [
                "X-Source-Token": "source-token-001",
                "Accept": "text/plain"
            ],
            requiredHeaders: ["X-Source-Token"]
        ))

        XCTAssertEqual(response.statusCode, 200)
        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testDifferentHeadersMergedFromDefaultAndRequest() async throws {
        let mock = CookieContractURLProtocol.Mock()
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "ok",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-Default-Only"), "from-default",
                               "Default-only header must be present")
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-Request-Only"), "from-request",
                               "Request-only header must be present")
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-Shared"), "from-request",
                               "Shared key must use request value (override)")
            }
        )

        client = makeClient(mock: mock, defaultHeaders: [
            "X-Default-Only": "from-default",
            "X-Shared": "from-default"
        ])

        let response = try await client.send(HTTPRequest(
            url: "https://fixture.local/header/merge",
            headers: [
                "X-Request-Only": "from-request",
                "X-Shared": "from-request"
            ]
        ))

        XCTAssertEqual(response.statusCode, 200)
        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testCookieJarIntegration() async throws {
        let cookie = Cookie(
            name: "test",
            value: "123",
            domain: "example.com",
            path: "/"
        )
        await jar.setCookie(cookie)

        let request = HTTPRequest(
            url: "https://example.com/path",
            method: "GET",
            useCookieJar: true
        )
        XCTAssertNotNil(request)
    }

    func testRequiresCookieJarWithoutCookieThrowsCookieRequired() async throws {
        let mock = CookieContractURLProtocol.Mock()
        client = makeClient(mock: mock)

        do {
            _ = try await client.send(HTTPRequest(
                url: "https://fixture.local/cookie-required/search",
                requiresCookieJar: true
            ))
            XCTFail("Expected COOKIE_REQUIRED")
        } catch let error as MappedReaderError {
            XCTAssertEqual(error.code, .COOKIE_REQUIRED)
            XCTAssertEqual(error.stage, .request_build)
        }

        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testRequiresCookieJarWithCookieSendsRequest() async throws {
        let mock = CookieContractURLProtocol.Mock()
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "ok",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "reader_session=session-available")
            }
        )
        await jar.setCookie(Cookie(
            name: "reader_session",
            value: "session-available",
            domain: "fixture.local",
            path: "/"
        ))
        client = makeClient(mock: mock)

        let response = try await client.send(HTTPRequest(
            url: "https://fixture.local/cookie-required/search",
            requiresCookieJar: true
        ))

        XCTAssertEqual(response.statusCode, 200)
        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testCookieSample001StoresSetCookieAndInjectsOnSecondRequest() async throws {
        let mock = CookieContractURLProtocol.Mock()
        await mock.enqueue(
            statusCode: 200,
            headers: ["Set-Cookie": "reader_session=session-001; Path=/; HttpOnly"],
            body: "session issued"
        )
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "Session Cookie Book",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "reader_session=session-001")
            }
        )

        client = makeClient(mock: mock)

        _ = try await client.send(HTTPRequest(
            url: "https://fixture.local/cookie-session/start",
            useCookieJar: true
        ))
        let response = try await client.send(HTTPRequest(
            url: "https://fixture.local/cookie-session/search?q=session",
            useCookieJar: true
        ))

        XCTAssertEqual(String(data: response.data, encoding: .utf8), "Session Cookie Book")
        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 2)
    }

    func testCookieSample002SingleStepLoginCookieEnablesSearchAndToc() async throws {
        let mock = CookieContractURLProtocol.Mock()
        await mock.enqueue(
            statusCode: 200,
            headers: ["Set-Cookie": "login_session=login-001; Path=/; HttpOnly"],
            body: "login cookie established"
        )
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "Login Cookie Book",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "login_session=login-001")
            }
        )
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "Login Chapter 1",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "login_session=login-001")
            }
        )

        client = makeClient(mock: mock)

        _ = try await client.send(HTTPRequest(
            url: "https://fixture.local/cookie-login/login",
            method: "POST",
            useCookieJar: true
        ))
        let search = try await client.send(HTTPRequest(
            url: "https://fixture.local/cookie-login/search?q=login",
            useCookieJar: true
        ))
        let toc = try await client.send(HTTPRequest(
            url: "https://fixture.local/cookie-login/book/login-cookie-book",
            useCookieJar: true
        ))

        XCTAssertEqual(String(data: search.data, encoding: .utf8), "Login Cookie Book")
        XCTAssertEqual(String(data: toc.data, encoding: .utf8), "Login Chapter 1")
        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 3)
    }

    func testCookieSample003KeepsAntiBotBoundaryFailureWithCookiePresent() async throws {
        let mock = CookieContractURLProtocol.Mock()
        await mock.enqueue(
            statusCode: 200,
            headers: ["Set-Cookie": "bound_session=bound-001; Path=/; HttpOnly"],
            body: "session bound"
        )
        await mock.enqueue(
            statusCode: 403,
            headers: [:],
            body: "ANTI_BOT_BOUNDARY",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "bound_session=bound-001")
            }
        )

        client = makeClient(mock: mock)

        _ = try await client.send(HTTPRequest(
            url: "https://fixture.local/cookie-antibot/start",
            useCookieJar: true
        ))
        let response = try await client.send(HTTPRequest(
            url: "https://fixture.local/cookie-antibot/book/boundary/ch1",
            useCookieJar: true
        ))

        XCTAssertEqual(response.statusCode, 403)
        XCTAssertEqual(String(data: response.data, encoding: .utf8), "ANTI_BOT_BOUNDARY")
        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 2)
    }

    // MARK: - Cookie jar isolation tests (P3 cookie_jar_isolation)

    // 6. Request with cookieScopeKey only injects cookies from that scope.
    func testRequestUsesScopedCookieJarOnly() async throws {
        let mock = CookieContractURLProtocol.Mock()
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "ok",
            assertion: { request in
                // Only the scoped cookie must appear — NOT the unscoped one.
                let cookieHeader = request.value(forHTTPHeaderField: "Cookie") ?? ""
                XCTAssertTrue(cookieHeader.contains("scoped_sess=scoped-value"),
                              "Scoped cookie must be injected")
                XCTAssertFalse(cookieHeader.contains("global_sess=global-value"),
                               "Unscoped (global) cookie must NOT bleed into the scoped request")
            }
        )

        let scope = CookieJarScopeKey(sourceId: "wensang", host: "fixture.local")

        // Write scoped cookie.
        await jar.setCookie(
            Cookie(name: "scoped_sess", value: "scoped-value", domain: "fixture.local", path: "/"),
            scopeKey: scope
        )
        // Write a cookie into the default (unscoped) partition — must not appear.
        await jar.setCookie(Cookie(name: "global_sess", value: "global-value", domain: "fixture.local", path: "/"))

        client = makeClient(mock: mock)
        _ = try await client.send(HTTPRequest(
            url: "https://fixture.local/scoped/search",
            useCookieJar: true,
            cookieScopeKey: scope
        ))
        let count = await mock.requestCount
        XCTAssertEqual(count, 1)
    }

    // 7. requiresCookieJar with scopeKey only counts cookies in that scope.
    //    Another scope having cookies must NOT satisfy the requirement.
    func testRequiresCookieJarWithoutScopedCookieThrowsCookieRequired() async throws {
        let mock = CookieContractURLProtocol.Mock()
        let scopeWensang  = CookieJarScopeKey(sourceId: "wensang",  host: "fixture.local")
        let scopeXiangshu = CookieJarScopeKey(sourceId: "xiangshu", host: "fixture.local")

        // Put a cookie only in the xiangshu scope — wensang scope is empty.
        await jar.setCookie(
            Cookie(name: "sess", value: "xiangshu-cookie", domain: "fixture.local", path: "/"),
            scopeKey: scopeXiangshu
        )

        client = makeClient(mock: mock)

        do {
            _ = try await client.send(HTTPRequest(
                url: "https://fixture.local/wensang/search",
                requiresCookieJar: true,
                cookieScopeKey: scopeWensang    // wensang scope has no cookie
            ))
            XCTFail("Expected COOKIE_REQUIRED — xiangshu cookie must not satisfy wensang requirement")
        } catch let error as MappedReaderError {
            XCTAssertEqual(error.code, .COOKIE_REQUIRED,
                           "A cookie in a different scope must not satisfy requiresCookieJar")
        }

        let count = await mock.requestCount
        XCTAssertEqual(count, 0, "No network request must be made when cookie requirement fails")
    }

    // 8. Two requests with different scopeKeys do not share cookie headers.
    func testScopedCookieDoesNotPolluteOtherRequest() async throws {
        let mock = CookieContractURLProtocol.Mock()

        let scopeA = CookieJarScopeKey(sourceId: "src-A", host: "fixture.local")
        let scopeB = CookieJarScopeKey(sourceId: "src-B", host: "fixture.local")

        await jar.setCookie(
            Cookie(name: "token", value: "token-A", domain: "fixture.local", path: "/"), scopeKey: scopeA
        )
        await jar.setCookie(
            Cookie(name: "token", value: "token-B", domain: "fixture.local", path: "/"), scopeKey: scopeB
        )

        // First request (scopeA) — must see token-A only.
        await mock.enqueue(
            statusCode: 200, headers: [:], body: "resp-A",
            assertion: { request in
                let h = request.value(forHTTPHeaderField: "Cookie") ?? ""
                XCTAssertTrue(h.contains("token=token-A"), "scopeA request must carry token-A")
                XCTAssertFalse(h.contains("token-B"),      "scopeA request must NOT carry token-B")
            }
        )
        // Second request (scopeB) — must see token-B only.
        await mock.enqueue(
            statusCode: 200, headers: [:], body: "resp-B",
            assertion: { request in
                let h = request.value(forHTTPHeaderField: "Cookie") ?? ""
                XCTAssertTrue(h.contains("token=token-B"), "scopeB request must carry token-B")
                XCTAssertFalse(h.contains("token-A"),      "scopeB request must NOT carry token-A")
            }
        )

        client = makeClient(mock: mock)
        _ = try await client.send(HTTPRequest(url: "https://fixture.local/a", useCookieJar: true, cookieScopeKey: scopeA))
        _ = try await client.send(HTTPRequest(url: "https://fixture.local/b", useCookieJar: true, cookieScopeKey: scopeB))

        let count = await mock.requestCount
        XCTAssertEqual(count, 2)
    }

    func testBootstrapRequestUsesScopedJar() async throws {
        let mock = CookieContractURLProtocol.Mock()
        let scope = CookieJarScopeKey(sourceId: "bootstrap-source", host: "fixture.local")
        await jar.setCookie(
            Cookie(name: "login_session", value: "bootstrap-001", domain: "fixture.local", path: "/"),
            scopeKey: scope
        )
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "ok",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "login_session=bootstrap-001")
            }
        )

        client = makeClient(mock: mock)
        _ = try await client.send(HTTPRequest(
            url: "https://fixture.local/login/bootstrap",
            useCookieJar: true,
            cookieScopeKey: scope
        ))
    }

    func testFollowupRequestUsesSameScopedJar() async throws {
        let mock = CookieContractURLProtocol.Mock()
        let scope = CookieJarScopeKey(sourceId: "followup-source", host: "fixture.local")
        await mock.enqueue(
            statusCode: 200,
            headers: ["Set-Cookie": "login_session=followup-001; Path=/; HttpOnly"],
            body: "bootstrap ok"
        )
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "search ok",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "login_session=followup-001")
            }
        )

        client = makeClient(mock: mock)
        _ = try await client.send(HTTPRequest(
            url: "https://fixture.local/login/bootstrap",
            useCookieJar: true,
            cookieScopeKey: scope
        ))
        _ = try await client.send(HTTPRequest(
            url: "https://fixture.local/search",
            useCookieJar: true,
            cookieScopeKey: scope
        ))
    }

    func testScopedLoginCookieDoesNotLeakAcrossSources() async throws {
        let mock = CookieContractURLProtocol.Mock()
        let scopeA = CookieJarScopeKey(sourceId: "source-login-a", host: "fixture.local")
        let scopeB = CookieJarScopeKey(sourceId: "source-login-b", host: "fixture.local")
        await jar.setCookie(
            Cookie(name: "login_session", value: "value-a", domain: "fixture.local", path: "/"),
            scopeKey: scopeA
        )
        await jar.setCookie(
            Cookie(name: "login_session", value: "value-b", domain: "fixture.local", path: "/"),
            scopeKey: scopeB
        )

        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "resp-a",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "login_session=value-a")
            }
        )
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "resp-b",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "login_session=value-b")
            }
        )

        client = makeClient(mock: mock)
        _ = try await client.send(HTTPRequest(
            url: "https://fixture.local/a",
            useCookieJar: true,
            cookieScopeKey: scopeA
        ))
        _ = try await client.send(HTTPRequest(
            url: "https://fixture.local/b",
            useCookieJar: true,
            cookieScopeKey: scopeB
        ))
    }

    private func makeClient(
        mock: CookieContractURLProtocol.Mock,
        defaultHeaders: [String: String] = [:]
    ) -> URLSessionHTTPClient {
        CookieContractURLProtocol.mock = mock
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CookieContractURLProtocol.self]
        return URLSessionHTTPClient(
            configuration: configuration,
            cookieJar: jar,
            defaultHeaders: defaultHeaders
        )
    }
}

private final class CookieContractURLProtocol: URLProtocol {
    struct Response: Sendable {
        var statusCode: Int
        var headers: [String: String]
        var body: Data
        var assertion: @Sendable (URLRequest) -> Void
    }

    actor Mock {
        private var responses: [Response] = []
        private(set) var requestCount = 0

        func enqueue(
            statusCode: Int,
            headers: [String: String],
            body: String,
            assertion: @escaping @Sendable (URLRequest) -> Void = { _ in }
        ) {
            responses.append(Response(
                statusCode: statusCode,
                headers: headers,
                body: Data(body.utf8),
                assertion: assertion
            ))
        }

        func nextResponse(for request: URLRequest) -> Response {
            requestCount += 1
            guard !responses.isEmpty else {
                return Response(statusCode: 500, headers: [:], body: Data("missing mock".utf8), assertion: { _ in })
            }
            let response = responses.removeFirst()
            response.assertion(request)
            return response
        }
    }

    nonisolated(unsafe) static var mock: Mock?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let mock = Self.mock else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        Task {
            let mocked = await mock.nextResponse(for: request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: mocked.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: mocked.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: mocked.body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
