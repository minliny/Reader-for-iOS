import XCTest
import ReaderCoreParser
import ReaderCoreModels

final class CSSExecutorTests: XCTestCase {
    private var executor: CSSExecutor!
    
    override func setUp() {
        super.setUp()
        executor = CSSExecutor()
    }
    
    override func tearDown() {
        executor = nil
        super.tearDown()
    }
    
    func testSelectByTag() throws {
        let html = HTMLFixtures.simpleList
        let nodes = try executor.select("li", from: html)
        XCTAssertEqual(nodes.count, 3)
    }
    
    func testSelectByClass() throws {
        let html = HTMLFixtures.simpleList
        let nodes = try executor.select(".item", from: html)
        XCTAssertEqual(nodes.count, 3)
    }
    
    func testSelectById() throws {
        let html = HTMLFixtures.simpleList
        let nodes = try executor.select("#list", from: html)
        XCTAssertEqual(nodes.count, 1)
    }
    
    func testExtractText() throws {
        let html = HTMLFixtures.simpleList
        let texts = try executor.extractText("li", from: html)
        XCTAssertEqual(texts, ["Item 1", "Item 2", "Item 3"])
    }
    
    func testExtractHTML() throws {
        let html = HTMLFixtures.innerHTMLTest
        let htmls = try executor.extractHTML("#inner", from: html)
        XCTAssertEqual(htmls.count, 1)
        XCTAssertTrue(htmls[0].contains("<span>Inner content</span>"))
        XCTAssertFalse(htmls[0].contains("Outer text before"))
        XCTAssertFalse(htmls[0].contains("Outer text after"))
    }
    
    func testExtractHref() throws {
        let html = HTMLFixtures.nestedElements
        let hrefs = try executor.extractHref("a", from: html)
        XCTAssertEqual(hrefs, ["/page1", "/page2"])
    }
    
    func testExtractSrc() throws {
        let html = HTMLFixtures.withImages
        let srcs = try executor.extractSrc("img", from: html)
        XCTAssertEqual(srcs, ["/cover.jpg", "/figure1.png"])
    }
    
    func testExtractAlt() throws {
        let html = HTMLFixtures.withImages
        let alts = try executor.extractAlt("img", from: html)
        XCTAssertEqual(alts, ["Cover Image", "Figure 1"])
    }
    
    func testChainedSelector() throws {
        let html = HTMLFixtures.tocStructure
        let nodes = try executor.select("div>ul>li", from: html)
        XCTAssertEqual(nodes.count, 3)
    }
    
    func testChainedSelectorWithClass() throws {
        let html = HTMLFixtures.tocStructure
        let nodes = try executor.select(".toc>ul>li", from: html)
        XCTAssertEqual(nodes.count, 3)
    }
    
    func testExecuteWithAtText() throws {
        let html = HTMLFixtures.simpleList
        let results = try executor.execute("li@text", from: html)
        XCTAssertEqual(results, ["Item 1", "Item 2", "Item 3"])
    }
    
    func testExecuteWithAtHTML() throws {
        let html = HTMLFixtures.innerHTMLTest
        let results = try executor.execute("#inner@html", from: html)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].contains("<span>Inner content</span>"))
    }
    
    func testExecuteWithAtHref() throws {
        let html = HTMLFixtures.tocStructure
        let results = try executor.execute("a@href", from: html)
        XCTAssertEqual(results, ["/chapter1.html", "/chapter2.html", "/chapter3.html"])
    }
    
    func testExecuteWithAtSrc() throws {
        let html = HTMLFixtures.withImages
        let results = try executor.execute("img@src", from: html)
        XCTAssertEqual(results, ["/cover.jpg", "/figure1.png"])
    }
    
    func testExecuteWithAtAlt() throws {
        let html = HTMLFixtures.withImages
        let results = try executor.execute("img@alt", from: html)
        XCTAssertEqual(results, ["Cover Image", "Figure 1"])
    }
    
    func testExecuteDefaultIsText() throws {
        let html = HTMLFixtures.simpleList
        let results = try executor.execute("li", from: html)
        XCTAssertEqual(results, ["Item 1", "Item 2", "Item 3"])
    }
}
