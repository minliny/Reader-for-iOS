import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
import ReaderCoreModels
import ReaderCoreParser
import ReaderCoreProtocols
@testable import ReaderPlatformAdapters

final class MinimalHTTPAdapterTests: XCTestCase {
    private let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    override func tearDown() {
        AdapterValidationURLProtocol.mock = nil
        super.tearDown()
    }

    func testSample004SearchChainThroughMinimalHTTPAdapter() async throws {
        let body = """
        <!DOCTYPE html>
        <html>
        <body>
        <div class="entry">三体|http://fixture4.local/book/1.html</div>
        <div class="entry">斗破苍穹|http://fixture4.local/book/2.html</div>
        <div class="entry">完美世界|http://fixture4.local/book/3.html</div>
        </body>
        </html>
        """
        let mock = AdapterValidationURLProtocol.Mock(
            statusCode: 200,
            headers: ["Content-Type": "text/html; charset=utf-8"],
            body: body
        )
        AdapterValidationURLProtocol.mock = mock

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AdapterValidationURLProtocol.self]
        let adapter = MinimalHTTPAdapter(configuration: configuration)

        let response = try await adapter.send(HTTPRequest(
            url: "http://fixture4.local/search?q=reader",
            headers: ["Accept": "text/html"]
        ))
        let source = BookSource(
            id: "sample_004",
            bookSourceName: "Sample-004-Fixture",
            bookSourceUrl: "http://fixture4.local",
            searchUrl: "http://fixture4.local/search?q={{key}}",
            ruleSearch: "css:.entry"
        )
        let items = try NonJSParserEngine().parseSearchResponse(
            response.data,
            source: source,
            query: SearchQuery(keyword: "reader")
        )

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].title, "三体")
        XCTAssertEqual(items[0].detailURL, "http://fixture4.local/book/1.html")
        XCTAssertEqual(items[1].title, "斗破苍穹")
        XCTAssertEqual(items[1].detailURL, "http://fixture4.local/book/2.html")
        XCTAssertEqual(items[2].title, "完美世界")
        XCTAssertEqual(items[2].detailURL, "http://fixture4.local/book/3.html")

        let captured = await mock.capturedRequest
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Accept"), "text/html")
        XCTAssertNil(captured?.value(forHTTPHeaderField: "Cookie"))
    }

    func testAdapterHardeningHeaderSample001PassesCustomHeadersAndMatchesExpected() async throws {
        let body = "Header 基础样本|/book/header-basic|Reader Core"
        let mock = AdapterValidationURLProtocol.Mock(
            statusCode: 200,
            headers: ["Content-Type": "text/plain; charset=utf-8"],
            body: body
        )
        AdapterValidationURLProtocol.mock = mock

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AdapterValidationURLProtocol.self]
        let adapter = MinimalHTTPAdapter(configuration: configuration)

        let response = try await adapter.send(HTTPRequest(
            url: "https://fixture.local/header/search?q=header-basic",
            headers: [
                "Accept": "text/html",
                "X-Requested-With": "XMLHttpRequest"
            ]
        ))
        let source = BookSource(
            id: "SAMPLE-P1-HEADER-001",
            bookSourceName: "Header Basic Fixture",
            bookSourceUrl: "https://fixture.local/header",
            searchUrl: "https://fixture.local/header/search?q={{key}}",
            ruleSearch: "regex:(.+)"
        )
        let items = try NonJSParserEngine().parseSearchResponse(
            response.data,
            source: source,
            query: SearchQuery(keyword: "header-basic")
        )
        let expected = try loadExpectedSearchItem("samples/expected/search/SAMPLE-P1-HEADER-001.json")

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, expected.name)
        XCTAssertEqual(items[0].author, expected.author)
        XCTAssertEqual(items[0].detailURL, expected.detailURL)

        let captured = await mock.capturedRequest
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Accept"), "text/html")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "X-Requested-With"), "XMLHttpRequest")
        XCTAssertNil(captured?.value(forHTTPHeaderField: "Cookie"))
    }

    func testAdapterHardeningCookieSample001PreservesCookieHeaderAndMatchesExpected() async throws {
        let body = "Session Cookie Book|/cookie/book/session-cookie-book|Cookie Author"
        let mock = AdapterValidationURLProtocol.Mock(
            statusCode: 200,
            headers: ["Content-Type": "text/plain; charset=utf-8"],
            body: body
        )
        AdapterValidationURLProtocol.mock = mock

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AdapterValidationURLProtocol.self]
        let adapter = MinimalHTTPAdapter(configuration: configuration)

        let response = try await adapter.send(HTTPRequest(
            url: "https://fixture.local/cookie-session/search?q=session-cookie",
            headers: [
                "Accept": "text/html",
                "Cookie": "reader_session=session-001"
            ]
        ))
        let source = BookSource(
            id: "SAMPLE-P1-COOKIE-001",
            bookSourceName: "Cookie Session Fixture",
            bookSourceUrl: "https://fixture.local/cookie-session",
            searchUrl: "https://fixture.local/cookie-session/search?q={{key}}",
            ruleSearch: "regex:(.+)",
            enabledCookieJar: true
        )
        let items = try NonJSParserEngine().parseSearchResponse(
            response.data,
            source: source,
            query: SearchQuery(keyword: "session-cookie")
        )
        let expected = try loadExpectedSearchItem("samples/expected/search/cookie_session_search_expected.json")

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, expected.name)
        XCTAssertEqual(items[0].author, expected.author)
        XCTAssertEqual(items[0].detailURL, expected.detailURL)

        let captured = await mock.capturedRequest
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Accept"), "text/html")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Cookie"), "reader_session=session-001")
    }

    func testAdapterHardeningErrorSample001Maps404WithoutParserDeviation() async throws {
        let body = #"{"httpStatus":404,"body":"","marker":"HTTP_404_CONTENT_FAILED"}"#
        let mock = AdapterValidationURLProtocol.Mock(
            statusCode: 404,
            headers: ["Content-Type": "application/json"],
            body: body
        )
        AdapterValidationURLProtocol.mock = mock

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AdapterValidationURLProtocol.self]
        let adapter = MinimalHTTPAdapter(configuration: configuration)

        let response = try await adapter.send(HTTPRequest(
            url: "https://fixture.local/error/http-404",
            headers: ["Accept": "application/json"]
        ))
        let mapped = ErrorMapper.map(.httpStatus(response.statusCode))
        let expected = try loadExpectedError("samples/expected/error/error_http_404_expected.json")

        XCTAssertEqual(response.statusCode, 404)
        XCTAssertEqual(mapped.failureType.rawValue, expected.failureType)
        XCTAssertEqual(mapped.errorCode.rawValue, expected.errorCode)
        XCTAssertEqual(mapped.message, expected.message)

        let captured = await mock.capturedRequest
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNil(captured?.value(forHTTPHeaderField: "Cookie"))
    }

    private func loadExpectedSearchItem(_ relativePath: String) throws -> ExpectedSearchItem {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent(relativePath))
        return try JSONDecoder().decode(ExpectedSearchPayload.self, from: data).items[0]
    }

    private func loadExpectedError(_ relativePath: String) throws -> ExpectedErrorPayload {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent(relativePath))
        return try JSONDecoder().decode(ExpectedErrorPayload.self, from: data)
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
        case bookUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        if let detailURL = try container.decodeIfPresent(String.self, forKey: .detailURL) {
            self.detailURL = detailURL
        } else if let detailUrl = try container.decodeIfPresent(String.self, forKey: .detailUrl) {
            self.detailURL = detailUrl
        } else if let bookUrl = try container.decodeIfPresent(String.self, forKey: .bookUrl) {
            self.detailURL = bookUrl
        } else {
            self.detailURL = ""
        }
    }
}

private struct ExpectedErrorPayload: Decodable {
    let failureType: String
    let errorCode: String
    let message: String
}

private final class AdapterValidationURLProtocol: URLProtocol {
    actor Mock {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
        private(set) var capturedRequest: URLRequest?

        init(statusCode: Int, headers: [String: String], body: String) {
            self.statusCode = statusCode
            self.headers = headers
            self.body = Data(body.utf8)
        }

        func capture(_ request: URLRequest) {
            capturedRequest = request
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
            await mock.capture(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: mock.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: mock.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: mock.body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
