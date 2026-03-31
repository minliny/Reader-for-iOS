import XCTest
@testable import ReaderCoreModels

final class ReadingFlowModelsTests: XCTestCase {
    func testSearchQueryDefaultPage() {
        let query = SearchQuery(keyword: "测试")
        XCTAssertEqual(query.keyword, "测试")
        XCTAssertEqual(query.page, 1)
    }

    func testContentPageInit() {
        let content = ContentPage(title: "章1", content: "正文", chapterURL: "https://example.com/c1")
        XCTAssertEqual(content.title, "章1")
        XCTAssertEqual(content.content, "正文")
        XCTAssertEqual(content.chapterURL, "https://example.com/c1")
    }
}
