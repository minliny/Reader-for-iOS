import XCTest
@testable import ReaderCoreModels

final class BookSourceDecodingTests: XCTestCase {
    func testDecodeKeepsUnknownFields() throws {
        let raw = """
        {
          "bookSourceId": "id-1",
          "bookSourceName": "source",
          "searchUrl": "https://example.com/search?q={{key}}",
          "ruleSearch": ".item",
          "customA": "value",
          "customB": {
            "nested": true
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(BookSource.self, from: raw)

        XCTAssertEqual(decoded.id, "id-1")
        XCTAssertEqual(decoded.bookSourceName, "source")
        XCTAssertEqual(decoded.ruleSearch, ".item")
        XCTAssertEqual(decoded.unknownFields["customA"], .string("value"))
    }
}
