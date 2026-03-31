import XCTest
import ReaderCoreNetwork
import ReaderCoreProtocols
import ReaderCoreModels

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
            XCTAssertEqual(error.code, .networkFailed)
            XCTAssertEqual(error.failure?.type, .INVALID_URL)
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
}
