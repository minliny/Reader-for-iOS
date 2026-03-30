import XCTest
@testable import ReaderCoreParser
import ReaderCoreModels

final class NonJSParserEngineTests: XCTestCase {
    func testSearchParseByRegex() throws {
        let source = BookSource(
            bookSourceName: "s1",
            ruleSearch: "regex:book=([^\\n]+)"
        )
        let body = "book=三体|https://example.com/b1|刘慈欣\nbook=银河帝国|https://example.com/b2|阿西莫夫"
        let engine = NonJSParserEngine()
        let result = try engine.parseSearchResponse(Data(body.utf8), source: source, query: SearchQuery(keyword: "三体"))
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.title, "三体")
        XCTAssertEqual(result.first?.detailURL, "https://example.com/b1")
    }

    func testTOCParseByJSONPath() throws {
        let source = BookSource(bookSourceName: "s2", ruleToc: "jsonpath:$.chapters[0].name")
        let body = #"{"chapters":[{"name":"第一章"}]}"#
        let engine = NonJSParserEngine()
        let result = try engine.parseTOCResponse(Data(body.utf8), source: source, detailURL: "https://example.com/book")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].chapterTitle, "第一章")
    }

    func testContentParseByReplacePipeline() throws {
        let source = BookSource(bookSourceName: "s3", ruleContent: "regex:content=([^\\n]+)|replace:[广告]=>")
        let body = "content=这是正文[广告]"
        let engine = NonJSParserEngine()
        let page = try engine.parseContentResponse(Data(body.utf8), source: source, chapterURL: "https://example.com/c1")
        XCTAssertEqual(page.content, "这是正文")
    }

    func testJSRuleWillDegradeNotCrash() throws {
        let source = BookSource(bookSourceName: "s4", ruleSearch: "js:return x")
        let engine = NonJSParserEngine()
        let body = "abc"
        XCTAssertThrowsError(try engine.parseSearchResponse(Data(body.utf8), source: source, query: SearchQuery(keyword: "k"))) { error in
            guard let readerError = error as? ReaderError else {
                return XCTFail("unexpected error type")
            }
            XCTAssertEqual(readerError.failure?.type, .JS_DEGRADED)
        }
    }

    func testUnsupportedRuleFailureType() throws {
        let source = BookSource(bookSourceName: "s5", ruleSearch: "lua:abc")
        let engine = NonJSParserEngine()
        XCTAssertThrowsError(try engine.parseSearchResponse(Data("x".utf8), source: source, query: SearchQuery(keyword: "x"))) { error in
            guard let readerError = error as? ReaderError else {
                return XCTFail("unexpected error type")
            }
            XCTAssertEqual(readerError.failure?.type, .RULE_UNSUPPORTED)
        }
    }
}
