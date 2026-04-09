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

    func testDefaultHeadersApplied() async throws {
        let customClient = URLSessionHTTPClient(
            defaultHeaders: ["X-Custom": "value"]
        )
        let request = HTTPRequest(url: "https://example.com", method: "GET")
        XCTAssertNotNil(customClient)
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

    private func makeClient(mock: CookieContractURLProtocol.Mock) -> URLSessionHTTPClient {
        CookieContractURLProtocol.mock = mock
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CookieContractURLProtocol.self]
        return URLSessionHTTPClient(configuration: configuration, cookieJar: jar)
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
