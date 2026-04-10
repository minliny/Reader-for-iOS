import XCTest
import ReaderCoreCache
import ReaderCoreProtocols

final class MinimalCacheHTTPClientTests: XCTestCase {
    func testSearchSample001ReturnsFirstResponseForRepeatedIdenticalRequest() async throws {
        let upstream = SequenceHTTPClient([
            response(body: "Cache Book|/book/cache-book|Cache Author"),
            response(body: "Changed Origin Book|/book/cache-book-changed|Changed Origin Author")
        ])
        let client = MinimalCacheHTTPClient(upstream: upstream)
        let request = HTTPRequest(url: "https://fixture.local/cache-search?q=cache", method: "GET")

        let first = try await client.send(request)
        let second = try await client.send(request)

        XCTAssertEqual(String(data: first.data, encoding: .utf8), "Cache Book|/book/cache-book|Cache Author")
        XCTAssertEqual(String(data: second.data, encoding: .utf8), "Cache Book|/book/cache-book|Cache Author")
        let callCount = await upstream.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testTocSample002ReturnsFirstResponseForRepeatedIdenticalRequest() async throws {
        let upstream = SequenceHTTPClient([
            response(body: "Chapter 1|/book/cache-book/ch1"),
            response(body: "Chapter 1 Updated|/book/cache-book/ch1-updated")
        ])
        let client = MinimalCacheHTTPClient(upstream: upstream)
        let request = HTTPRequest(url: "https://fixture.local/book/cache-book", method: "GET")

        let first = try await client.send(request)
        let second = try await client.send(request)

        XCTAssertEqual(String(data: first.data, encoding: .utf8), "Chapter 1|/book/cache-book/ch1")
        XCTAssertEqual(String(data: second.data, encoding: .utf8), "Chapter 1|/book/cache-book/ch1")
        let callCount = await upstream.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testContentSample003AllowsStaleForSameRequest() async throws {
        let upstream = SequenceHTTPClient([
            response(body: "Cached content body"),
            response(body: "Changed origin content body")
        ])
        let client = MinimalCacheHTTPClient(upstream: upstream)
        let request = HTTPRequest(url: "https://fixture.local/book/cache-book/ch1", method: "GET")

        let first = try await client.send(request)
        let second = try await client.send(request)

        XCTAssertEqual(String(data: first.data, encoding: .utf8), "Cached content body")
        XCTAssertEqual(String(data: second.data, encoding: .utf8), "Cached content body")
        let callCount = await upstream.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testDifferentSelectedHeadersDoNotShareCacheEntry() async throws {
        let upstream = SequenceHTTPClient([
            response(body: "ua-a"),
            response(body: "ua-b")
        ])
        let client = MinimalCacheHTTPClient(upstream: upstream, selectedHeaderNames: ["User-Agent"])
        let firstRequest = HTTPRequest(url: "https://fixture.local/cache-search?q=cache", headers: ["User-Agent": "A"])
        let secondRequest = HTTPRequest(url: "https://fixture.local/cache-search?q=cache", headers: ["User-Agent": "B"])

        let first = try await client.send(firstRequest)
        let second = try await client.send(secondRequest)

        XCTAssertEqual(String(data: first.data, encoding: .utf8), "ua-a")
        XCTAssertEqual(String(data: second.data, encoding: .utf8), "ua-b")
        let callCount = await upstream.callCount
        XCTAssertEqual(callCount, 2)
    }

    func testCookieRuntimeFlagsDoNotChangeCacheKey() async throws {
        let upstream = SequenceHTTPClient([
            response(body: "cookie-independent"),
            response(body: "would-be-origin")
        ])
        let client = MinimalCacheHTTPClient(upstream: upstream)
        let firstRequest = HTTPRequest(
            url: "https://fixture.local/cache-cookie?q=cache",
            method: "GET",
            useCookieJar: false
        )
        let secondRequest = HTTPRequest(
            url: "https://fixture.local/cache-cookie?q=cache",
            method: "GET",
            requiresCookieJar: true
        )

        let first = try await client.send(firstRequest)
        let second = try await client.send(secondRequest)

        XCTAssertEqual(String(data: first.data, encoding: .utf8), "cookie-independent")
        XCTAssertEqual(String(data: second.data, encoding: .utf8), "cookie-independent")
        let callCount = await upstream.callCount
        XCTAssertEqual(callCount, 1)
    }
}

private actor SequenceHTTPClient: HTTPClient {
    private var responses: [HTTPResponse]
    private(set) var callCount = 0

    init(_ responses: [HTTPResponse]) {
        self.responses = responses
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        callCount += 1
        guard !responses.isEmpty else {
            return HTTPResponse(statusCode: 500, headers: [:], data: Data())
        }
        return responses.removeFirst()
    }
}

private func response(body: String, contentType: String = "text/plain; charset=utf-8") -> HTTPResponse {
    HTTPResponse(
        statusCode: 200,
        headers: ["Content-Type": contentType],
        data: Data(body.utf8)
    )
}
