import XCTest
import ReaderCoreModels
import ReaderCoreNetwork
import ReaderCoreProtocols
import ReaderCoreFoundation
@testable import ReaderPlatformAdapters

final class LoginBootstrapTests: XCTestCase {
    private var jar: BasicCookieJar!

    override func setUp() {
        super.setUp()
        jar = BasicCookieJar()
        LoginBootstrapURLProtocol.mock = nil
    }

    override func tearDown() {
        LoginBootstrapURLProtocol.mock = nil
        jar = nil
        super.tearDown()
    }

    func testLoginSuccessStoresCookieIntoScopedJar() async throws {
        let mock = LoginBootstrapURLProtocol.Mock()
        await mock.enqueue(statusCode: 200, headers: [:], body: "login page")
        await mock.enqueue(statusCode: 200, headers: [
            "Set-Cookie": "session=scope-a; Path=/; HttpOnly"
        ], body: "login submitted")
        await mock.enqueue(statusCode: 200, headers: [:], body: "You logged into a secure area! Logout")
        await mock.enqueue(statusCode: 200, headers: [:], body: "search ok")

        let layer = makeLayer(mock: mock)
        let source = makeSource(sourceId: "source-a")

        _ = try await layer.performSearch(source: source, query: SearchQuery(keyword: "secure"))

        let cookies = await jar.getCookies(
            for: "fixture.local",
            path: "/secure",
            scopeKey: CookieJarScopeKey(sourceId: "source-a", host: "fixture.local")
        )
        XCTAssertEqual(cookies.map(\.name), ["session"])
        XCTAssertEqual(cookies.first?.value, "scope-a")
    }

    func testLoginFailureDoesNotStoreCookie() async throws {
        let mock = LoginBootstrapURLProtocol.Mock()
        await mock.enqueue(statusCode: 200, headers: [:], body: "login page")
        await mock.enqueue(statusCode: 200, headers: [
            "Set-Cookie": "session=bad; Path=/; HttpOnly"
        ], body: "Invalid password.")

        let layer = makeLayer(mock: mock)
        let source = makeSource(sourceId: "source-failure")

        do {
            _ = try await layer.performSearch(source: source, query: SearchQuery(keyword: "secure"))
            XCTFail("Expected login bootstrap failure")
        } catch let error as ReaderError {
            XCTAssertEqual(error.failure?.type, .LOGIN_REQUIRED)
        }

        let cookies = await jar.getCookies(
            for: "fixture.local",
            path: "/secure",
            scopeKey: CookieJarScopeKey(sourceId: "source-failure", host: "fixture.local")
        )
        XCTAssertTrue(cookies.isEmpty)
    }

    func testLoginCookieIsReusedByFollowupRequest() async throws {
        let mock = LoginBootstrapURLProtocol.Mock()
        await mock.enqueue(statusCode: 200, headers: [:], body: "login page")
        await mock.enqueue(statusCode: 200, headers: [
            "Set-Cookie": "session=scope-b; Path=/; HttpOnly"
        ], body: "login submitted")
        await mock.enqueue(statusCode: 200, headers: [:], body: "You logged into a secure area! Logout")
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "search ok",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "session=scope-b")
            }
        )

        let layer = makeLayer(mock: mock)
        let source = makeSource(sourceId: "source-b")

        _ = try await layer.performSearch(source: source, query: SearchQuery(keyword: "secure"))

        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 4)
    }

    func testLoginFailureInOneScopeDoesNotPolluteAnotherScope() async throws {
        let mock = LoginBootstrapURLProtocol.Mock()
        await mock.enqueue(statusCode: 200, headers: [:], body: "login page")
        await mock.enqueue(statusCode: 200, headers: [
            "Set-Cookie": "session=bad; Path=/; HttpOnly"
        ], body: "Invalid password.")
        await mock.enqueue(statusCode: 200, headers: [:], body: "login page")
        await mock.enqueue(statusCode: 200, headers: [
            "Set-Cookie": "session=good; Path=/; HttpOnly"
        ], body: "login submitted")
        await mock.enqueue(statusCode: 200, headers: [:], body: "You logged into a secure area! Logout")
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "search ok",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "session=good")
            }
        )

        let layer = makeLayer(mock: mock)
        let failingSource = makeSource(sourceId: "source-c")
        let passingSource = makeSource(sourceId: "source-d")

        do {
            _ = try await layer.performSearch(source: failingSource, query: SearchQuery(keyword: "secure"))
            XCTFail("Expected login bootstrap failure")
        } catch {}

        _ = try await layer.performSearch(source: passingSource, query: SearchQuery(keyword: "secure"))

        let failedScopeCookies = await jar.getCookies(
            for: "fixture.local",
            path: "/secure",
            scopeKey: CookieJarScopeKey(sourceId: "source-c", host: "fixture.local")
        )
        let passingScopeCookies = await jar.getCookies(
            for: "fixture.local",
            path: "/secure",
            scopeKey: CookieJarScopeKey(sourceId: "source-d", host: "fixture.local")
        )

        XCTAssertTrue(failedScopeCookies.isEmpty)
        XCTAssertEqual(passingScopeCookies.first?.value, "good")
    }

    func testNoSuccessMarkerKeepsConservativeFailure() async throws {
        let mock = LoginBootstrapURLProtocol.Mock()
        await mock.enqueue(statusCode: 200, headers: [:], body: "login page")
        await mock.enqueue(statusCode: 200, headers: [
            "Set-Cookie": "session=uncertain; Path=/; HttpOnly"
        ], body: "login submitted")
        await mock.enqueue(statusCode: 200, headers: [:], body: "secure page without success markers")

        let layer = makeLayer(mock: mock)
        let source = makeSource(sourceId: "source-e")

        do {
            _ = try await layer.performSearch(source: source, query: SearchQuery(keyword: "secure"))
            XCTFail("Expected conservative login failure")
        } catch let error as ReaderError {
            XCTAssertEqual(error.failure?.type, .LOGIN_REQUIRED)
        }

        let cookies = await jar.getCookies(
            for: "fixture.local",
            path: "/secure",
            scopeKey: CookieJarScopeKey(sourceId: "source-e", host: "fixture.local")
        )
        XCTAssertTrue(cookies.isEmpty)
    }

    func testRepeatedBootstrapSkipsSecondBootstrapRequests() async throws {
        let mock = LoginBootstrapURLProtocol.Mock()
        await mock.enqueue(statusCode: 200, headers: [:], body: "login page")
        await mock.enqueue(statusCode: 200, headers: [
            "Set-Cookie": "session=scope-repeat; Path=/; HttpOnly"
        ], body: "login submitted")
        await mock.enqueue(statusCode: 200, headers: [:], body: "You logged into a secure area! Logout")
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "search-1",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "session=scope-repeat")
            }
        )
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "search-2",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "session=scope-repeat")
            }
        )

        let layer = makeLayer(mock: mock)
        let source = makeSource(sourceId: "source-repeat")

        _ = try await layer.performSearch(source: source, query: SearchQuery(keyword: "secure-1"))
        _ = try await layer.performSearch(source: source, query: SearchQuery(keyword: "secure-2"))

        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 5, "Bootstrap should run only once per scoped source.")
    }

    func testBootstrapUsesSubmitResponseWhenVerificationRequestAbsent() async throws {
        let mock = LoginBootstrapURLProtocol.Mock()
        await mock.enqueue(statusCode: 200, headers: [:], body: "login page")
        await mock.enqueue(statusCode: 200, headers: [
            "Set-Cookie": "session=submit-only; Path=/; HttpOnly"
        ], body: "You logged into a secure area! Logout")
        await mock.enqueue(
            statusCode: 200,
            headers: [:],
            body: "search ok",
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "session=submit-only")
            }
        )

        let flowWithoutVerification = defaultLoginFlow(
            successURL: nil,
            successMarkers: ["You logged into a secure area!", "Logout"]
        )
        let layer = makeLayer(mock: mock)
        let source = makeSource(sourceId: "source-submit-only", loginFlow: flowWithoutVerification)

        _ = try await layer.performSearch(source: source, query: SearchQuery(keyword: "secure"))

        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 3)
    }

    func testPreflightOnlyBootstrapPath() async throws {
        let mock = LoginBootstrapURLProtocol.Mock()
        await mock.enqueue(statusCode: 200, headers: [:], body: "login landing")
        await mock.enqueue(statusCode: 200, headers: [:], body: "search ok")

        let layer = makeLayer(mock: mock)
        let source = makeSource(
            sourceId: "source-preflight-only",
            loginFlow: nil,
            includeDefaultLoginFlow: false
        )

        _ = try await layer.performSearch(source: source, query: SearchQuery(keyword: "secure"))

        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 2, "Preflight-only sources should still proceed to search.")
    }

    func testMalformedLoginDescriptorThrowsLoginRequired() async throws {
        let mock = LoginBootstrapURLProtocol.Mock()
        let malformedFlow: JSONValue = .object([
            "enabled": .bool(true),
            "method": .string("POST"),
            "contentType": .string("application/x-www-form-urlencoded")
        ])

        let layer = makeLayer(mock: mock)
        let source = makeSource(sourceId: "source-malformed", loginFlow: malformedFlow)

        do {
            _ = try await layer.performSearch(source: source, query: SearchQuery(keyword: "secure"))
            XCTFail("Expected malformed login descriptor to fail.")
        } catch let error as ReaderError {
            XCTAssertEqual(error.failure?.type, .LOGIN_REQUIRED)
            XCTAssertTrue(error.message.contains("Malformed xReaderLoginFlow"))
        }

        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 0, "Malformed descriptor should fail before request dispatch.")
    }

    func testBootstrapErrorContractMapsToLoginRequired() async throws {
        let mock = LoginBootstrapURLProtocol.Mock()
        await mock.enqueueFailure(URLError(.timedOut))

        let layer = makeLayer(mock: mock)
        let source = makeSource(sourceId: "source-contract-error")

        do {
            _ = try await layer.performSearch(source: source, query: SearchQuery(keyword: "secure"))
            XCTFail("Expected bootstrap error contract failure")
        } catch let error as ReaderError {
            XCTAssertEqual(error.code, .networkFailed)
            XCTAssertEqual(error.failure?.type, .LOGIN_REQUIRED)
            XCTAssertTrue(
                error.message.hasPrefix("Login bootstrap failed."),
                "Error message should follow the stable login bootstrap contract prefix."
            )
        }

        let requestCount = await mock.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    private func makeLayer(mock: LoginBootstrapURLProtocol.Mock) -> NetworkPolicyLayer {
        LoginBootstrapURLProtocol.mock = mock
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LoginBootstrapURLProtocol.self]
        let client = URLSessionHTTPClient(configuration: configuration, cookieJar: jar)
        return NetworkPolicyLayer(httpClient: client)
    }

    private func makeSource(
        sourceId: String,
        loginFlow: JSONValue? = nil,
        includeDefaultLoginFlow: Bool = true
    ) -> BookSource {
        var unknownFields: [String: JSONValue] = [:]
        if let loginFlow {
            unknownFields["xReaderLoginFlow"] = loginFlow
        } else if includeDefaultLoginFlow {
            let resolvedLoginFlow = defaultLoginFlow()
            unknownFields["xReaderLoginFlow"] = resolvedLoginFlow
        }
        return BookSource(
            id: sourceId,
            bookSourceName: sourceId,
            bookSourceUrl: "https://fixture.local",
            searchUrl: "https://fixture.local/secure",
            header: ["Referer": "https://fixture.local/login"],
            loginUrl: "https://fixture.local/login",
            enabledCookieJar: true,
            unknownFields: unknownFields
        )
    }

    private func defaultLoginFlow(
        successURL: String? = "https://fixture.local/secure",
        successMarkers: [String] = ["You logged into a secure area!", "Logout"],
        failureMarkers: [String] = ["Invalid password."]
    ) -> JSONValue {
        var object: [String: JSONValue] = [
            "enabled": .bool(true),
            "method": .string("POST"),
            "contentType": .string("application/x-www-form-urlencoded"),
            "actionUrl": .string("https://fixture.local/authenticate"),
            "form": .object([
                "username": .string("reader"),
                "password": .string("secret")
            ]),
            "successMarkers": .array(successMarkers.map(JSONValue.string)),
            "failureMarkers": .array(failureMarkers.map(JSONValue.string))
        ]
        if let successURL {
            object["successUrl"] = .string(successURL)
        }
        return .object(object)
    }
}

private final class LoginBootstrapURLProtocol: URLProtocol {
    struct Response: Sendable {
        var statusCode: Int
        var headers: [String: String]
        var body: Data
        var assertion: @Sendable (URLRequest) -> Void
    }

    actor Mock {
        private enum QueueItem: Sendable {
            case response(Response)
            case failure(URLError)
        }

        private var responses: [QueueItem] = []
        private(set) var requestCount = 0

        func enqueue(
            statusCode: Int,
            headers: [String: String],
            body: String,
            assertion: @escaping @Sendable (URLRequest) -> Void = { _ in }
        ) {
            responses.append(.response(Response(
                statusCode: statusCode,
                headers: headers,
                body: Data(body.utf8),
                assertion: assertion
            )))
        }

        func enqueueFailure(_ error: URLError) {
            responses.append(.failure(error))
        }

        func nextResponse(for request: URLRequest) throws -> Response {
            requestCount += 1
            guard !responses.isEmpty else {
                return Response(statusCode: 500, headers: [:], body: Data("missing mock".utf8), assertion: { _ in })
            }
            switch responses.removeFirst() {
            case .response(let response):
                response.assertion(request)
                return response
            case .failure(let error):
                throw error
            }
        }
    }

    nonisolated(unsafe) static var mock: Mock?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let mock = Self.mock else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        Task {
            do {
                let mocked = try await mock.nextResponse(for: request)
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: mocked.statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: mocked.headers
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: mocked.body)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}
