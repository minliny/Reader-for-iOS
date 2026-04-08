import XCTest
import ReaderCoreNetwork
import ReaderCoreProtocols
import ReaderCoreModels

final class BookSourceRequestBuilderTests: XCTestCase {
    var builder: BookSourceRequestBuilder!

    override func setUp() {
        super.setUp()
        builder = BookSourceRequestBuilder()
    }

    override func tearDown() {
        builder = nil
        super.tearDown()
    }

    func testMakeSearchRequestWithKey() throws {
        let source = BookSource(
            bookSourceName: "Test",
            searchUrl: "https://example.com/search?q={{key}}"
        )
        let query = SearchQuery(keyword: "测试", page: 1)
        let request = try builder.makeSearchRequest(source: source, query: query)

        XCTAssertEqual(request.url, "https://example.com/search?q=%E6%B5%8B%E8%AF%95")
        XCTAssertEqual(request.method, "GET")
    }

    func testMakeSearchRequestWithKeyword() throws {
        let source = BookSource(
            bookSourceName: "Test",
            searchUrl: "https://example.com/search?q={{keyword}}"
        )
        let query = SearchQuery(keyword: "abc", page: 1)
        let request = try builder.makeSearchRequest(source: source, query: query)

        XCTAssertEqual(request.url, "https://example.com/search?q=abc")
    }

    func testMakeSearchRequestWithPost() throws {
        let source = BookSource(
            bookSourceName: "Test",
            searchUrl: "POST,https://example.com/search,keyword={{key}}"
        )
        let query = SearchQuery(keyword: "test", page: 1)
        let request = try builder.makeSearchRequest(source: source, query: query)

        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url, "https://example.com/search")
        let bodyStr = String(data: request.body!, encoding: .utf8)
        XCTAssertEqual(bodyStr, "keyword=test")
    }

    func testMakeTOCRequest() throws {
        let source = BookSource(
            bookSourceName: "Test",
            bookSourceUrl: "https://example.com"
        )
        let request = try builder.makeTOCRequest(source: source, detailURL: "https://example.com/book/1")

        XCTAssertEqual(request.url, "https://example.com/book/1")
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.headers["Referer"], "https://example.com")
    }

    func testMakeContentRequest() throws {
        let source = BookSource(
            bookSourceName: "Test",
            bookSourceUrl: "https://example.com"
        )
        let request = try builder.makeContentRequest(source: source, chapterURL: "https://example.com/chapter/1")

        XCTAssertEqual(request.url, "https://example.com/chapter/1")
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.headers["Referer"], "https://example.com")
    }

    func testMissingSearchUrlThrows() {
        let source = BookSource(bookSourceName: "Test", searchUrl: nil)
        let query = SearchQuery(keyword: "test", page: 1)

        XCTAssertThrowsError(try builder.makeSearchRequest(source: source, query: query)) { error in
            guard let readerError = error as? ReaderError else {
                XCTFail("Expected ReaderError")
                return
            }
            XCTAssertEqual(readerError.code, .invalidInput)
            XCTAssertEqual(readerError.failure?.type, .FIELD_MISSING)
        }
    }
}
