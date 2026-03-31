import XCTest
@testable import ReaderCoreModels

final class BookSourceCoreFieldTests: XCTestCase {
    func testDecodeCoreFields() throws {
        let data = """
        {
          "bookSourceId": "src-001",
          "bookSourceName": "源A",
          "bookSourceUrl": "https://example.com",
          "bookSourceGroup": "p0",
          "bookSourceType": 0,
          "bookUrlPattern": "https://example.com/book/.*",
          "customOrder": 9,
          "enabled": true,
          "enabledExplore": false,
          "header": {"User-Agent":"UA"},
          "loginUrl": "https://example.com/login",
          "loginUi": "none",
          "enabledCookieJar": true,
          "searchUrl": "https://example.com/search?q={{key}}",
          "exploreUrl": "https://example.com/explore",
          "ruleSearch": ".s-item",
          "ruleBookInfo": ".book-info",
          "ruleToc": ".toc-item",
          "ruleContent": ".content",
          "unknown_x": 123
        }
        """.data(using: .utf8)!

        let source = try JSONDecoder().decode(BookSource.self, from: data)
        XCTAssertEqual(source.id, "src-001")
        XCTAssertEqual(source.bookSourceName, "源A")
        XCTAssertEqual(source.bookSourceUrl, "https://example.com")
        XCTAssertEqual(source.bookSourceGroup, "p0")
        XCTAssertEqual(source.bookSourceType, 0)
        XCTAssertEqual(source.bookUrlPattern, "https://example.com/book/.*")
        XCTAssertEqual(source.customOrder, 9)
        XCTAssertEqual(source.enabled, true)
        XCTAssertEqual(source.enabledExplore, false)
        XCTAssertEqual(source.header["User-Agent"], "UA")
        XCTAssertEqual(source.loginUrl, "https://example.com/login")
        XCTAssertEqual(source.loginUi, "none")
        XCTAssertEqual(source.enabledCookieJar, true)
        XCTAssertEqual(source.searchUrl, "https://example.com/search?q={{key}}")
        XCTAssertEqual(source.exploreUrl, "https://example.com/explore")
        XCTAssertEqual(source.ruleSearch, ".s-item")
        XCTAssertEqual(source.ruleBookInfo, ".book-info")
        XCTAssertEqual(source.ruleToc, ".toc-item")
        XCTAssertEqual(source.ruleContent, ".content")
        XCTAssertEqual(source.unknownFields["unknown_x"], .number(123))
    }

    func testEncodeKeepsUnknownFields() throws {
        let source = BookSource(
            id: "src-002",
            bookSourceName: "源B",
            bookSourceUrl: "https://b.example.com",
            unknownFields: ["k": .string("v")]
        )

        let data = try JSONEncoder().encode(source)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["bookSourceName"] as? String, "源B")
        XCTAssertEqual(obj?["k"] as? String, "v")
    }
}
