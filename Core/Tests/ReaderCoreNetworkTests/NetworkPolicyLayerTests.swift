import Foundation
import XCTest
import ReaderCoreModels
import ReaderCoreNetwork
import ReaderCoreParser
import ReaderCoreProtocols
@testable import ReaderPlatformAdapters

final class NetworkPolicyLayerTests: XCTestCase {
    private let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    override func tearDown() {
        PolicyURLProtocol.mock = nil
        super.tearDown()
    }

    func testPolicySample001BuildsHeaderAwareSearchRequestAndParsesExpected() async throws {
        let source = try loadBookSource("samples/booksources/p1_policy/SAMPLE-P1-POLICY-001.json")
        let expected = try loadExpectedSearch("samples/expected/search/policy_header_search_expected.json")
        let body = try Data(contentsOf: repoRoot.appendingPathComponent("samples/fixtures/text/policy_header_search.txt"))
        let client = MockHTTPClient(response: HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "text/plain; charset=utf-8"],
            data: body
        ))
        let layer = NetworkPolicyLayer(httpClient: client)

        let response = try await layer.performSearch(source: source, query: SearchQuery(keyword: "policy"))
        let items = try NonJSParserEngine().parseSearchResponse(response.data, source: source, query: SearchQuery(keyword: "policy"))
        let captured = await client.capturedRequest

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, expected.items[0].name)
        XCTAssertEqual(items[0].author, expected.items[0].author)
        XCTAssertEqual(items[0].detailURL, expected.items[0].detailURL)
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Accept"), "text/plain")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "X-Policy-Token"), "policy-header-001")
        XCTAssertNotNil(captured?.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertNil(captured?.value(forHTTPHeaderField: "Cookie"))
    }

    func testPolicySample002UsesMinimalCookieStoreAcrossBootstrapAndSearch() async throws {
        let source = try loadBookSource("samples/booksources/p1_policy/SAMPLE-P1-POLICY-002.json")
        let expected = try loadExpectedSearch("samples/expected/search/policy_cookie_search_expected.json")
        let mock = PolicyURLProtocol.Mock()
        await mock.enqueue(
            statusCode: 200,
            headers: ["Set-Cookie": "policy_session=session-002; Path=/; HttpOnly"],
            body: try Data(contentsOf: repoRoot.appendingPathComponent("samples/fixtures/text/policy_cookie_bootstrap.txt"))
        )
        await mock.enqueue(
            statusCode: 200,
            headers: ["Content-Type": "text/plain; charset=utf-8"],
            body: try Data(contentsOf: repoRoot.appendingPathComponent("samples/fixtures/text/policy_cookie_search.txt")),
            assertion: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "policy_session=session-002")
            }
        )
        PolicyURLProtocol.mock = mock

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PolicyURLProtocol.self]
        let jar = BasicCookieJar()
        let client = URLSessionHTTPClient(configuration: configuration, cookieJar: jar)
        let layer = NetworkPolicyLayer(httpClient: client)

        _ = try await layer.send(HTTPRequest(
            url: source.bookSourceUrl ?? "",
            headers: source.header,
            useCookieJar: true
        ))
        let response = try await layer.performSearch(source: source, query: SearchQuery(keyword: "policy"))
        let items = try NonJSParserEngine().parseSearchResponse(response.data, source: source, query: SearchQuery(keyword: "policy"))
        let stored = await jar.getCookies(for: "fixture.local", path: "/policy/cookie/search")

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, expected.items[0].name)
        XCTAssertEqual(items[0].author, expected.items[0].author)
        XCTAssertEqual(items[0].detailURL, expected.items[0].detailURL)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.name, "policy_session")
        XCTAssertEqual(stored.first?.value, "session-002")
    }

    func testPolicySample003Maps404ToExistingContentFailedFailure() async throws {
        let source = try loadBookSource("samples/booksources/p1_policy/SAMPLE-P1-POLICY-003.json")
        let expected = try loadExpectedError("samples/expected/error/policy_http_404_expected.json")
        let body = try Data(contentsOf: repoRoot.appendingPathComponent("samples/fixtures/json/policy_http_404.json"))
        let client = MockHTTPClient(response: HTTPResponse(
            statusCode: 404,
            headers: ["Content-Type": "application/json"],
            data: body
        ))
        let layer = NetworkPolicyLayer(httpClient: client)

        do {
            _ = try await layer.performSearch(source: source, query: SearchQuery(keyword: "missing"))
            XCTFail("Expected CONTENT_FAILED mapping")
        } catch let error as ReaderError {
            XCTAssertEqual(error.failure?.type.rawValue, expected.failureType)
            XCTAssertEqual(error.code.rawValue, expected.errorCode)
            XCTAssertEqual(error.message, expected.message)
        }
    }

    private func loadBookSource(_ relativePath: String) throws -> BookSource {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent(relativePath))
        return try JSONDecoder().decode(BookSource.self, from: data)
    }

    private func loadExpectedSearch(_ relativePath: String) throws -> ExpectedSearchPayload {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent(relativePath))
        return try JSONDecoder().decode(ExpectedSearchPayload.self, from: data)
    }

    private func loadExpectedError(_ relativePath: String) throws -> ExpectedErrorPayload {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent(relativePath))
        return try JSONDecoder().decode(ExpectedErrorPayload.self, from: data)
    }
}

private actor MockHTTPClient: HTTPClient {
    let response: HTTPResponse
    private(set) var capturedRequest: URLRequest?

    init(response: HTTPResponse) {
        self.response = response
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let url = URL(string: request.url) ?? URL(string: "https://invalid.local")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        capturedRequest = urlRequest
        return response
    }
}

private struct ExpectedSearchPayload: Decodable {
    let items: [ExpectedSearchItem]
}

private struct ExpectedSearchItem: Decodable {
    let name: String
    let author: String?
    let detailURL: String

    private enum CodingKeys: String, CodingKey {
        case name
        case author
        case detailURL
        case detailUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        detailURL = try container.decodeIfPresent(String.self, forKey: .detailURL)
            ?? container.decode(String.self, forKey: .detailUrl)
    }
}

private struct ExpectedErrorPayload: Decodable {
    let failureType: String
    let errorCode: String
    let message: String
}

private final class PolicyURLProtocol: URLProtocol {
    struct Response: Sendable {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
        let assertion: @Sendable (URLRequest) -> Void
    }

    actor Mock {
        private var responses: [Response] = []

        func enqueue(
            statusCode: Int,
            headers: [String: String],
            body: Data,
            assertion: @escaping @Sendable (URLRequest) -> Void = { _ in }
        ) {
            responses.append(Response(statusCode: statusCode, headers: headers, body: body, assertion: assertion))
        }

        func nextResponse(for request: URLRequest) -> Response {
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
