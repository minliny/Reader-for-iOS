import XCTest
import ReaderCoreParser
import ReaderCoreModels

final class HTMLParserTests: XCTestCase {
    private let parser = HTMLParser()
    private let executor = CSSExecutor()

    func testBuildsExpectedDOMStructureForNestedList() throws {
        let html = #"<ul><li><a href="a">A</a></li><li><a href="b">B</a></li></ul>"#

        let document = try parser.parse(html)

        XCTAssertEqual(document.type, .document)
        XCTAssertEqual(document.children.count, 1)

        let ul = try XCTUnwrap(document.children.first)
        XCTAssertEqual(ul.tagName, "ul")
        XCTAssertEqual(ul.children.count, 2)

        let firstListItem = try XCTUnwrap(ul.children.first)
        XCTAssertEqual(firstListItem.tagName, "li")
        XCTAssertEqual(firstListItem.children.count, 1)

        let firstAnchor = try XCTUnwrap(firstListItem.children.first)
        XCTAssertEqual(firstAnchor.tagName, "a")
        XCTAssertEqual(firstAnchor.innerText, "A")
    }

    func testPreservesAttributesOnParsedElements() throws {
        let html = #"<ul><li><a href="a" data-id="chapter-a">A</a></li><li><a href="b" data-id="chapter-b">B</a></li></ul>"#

        let document = try parser.parse(html)
        let ul = try XCTUnwrap(document.children.first)
        let firstListItem = try XCTUnwrap(ul.children.first)
        let firstAnchor = try XCTUnwrap(firstListItem.children.first)

        XCTAssertEqual(firstAnchor.href, "a")
        XCTAssertEqual(firstAnchor.attribute("href"), "a")
        XCTAssertEqual(firstAnchor.attribute("data-id"), "chapter-a")
        XCTAssertEqual(firstAnchor.attributes["data-id"], "chapter-a")
    }

    func testMalformedHTMLReturnsPartialDOMInsteadOfCrashing() throws {
        let html = "<ul><li><a>test"

        let document = try parser.parse(html)

        XCTAssertEqual(document.type, .document)
        XCTAssertFalse(document.children.isEmpty)
        XCTAssertTrue(document.innerText.contains("test"))
    }

    func testSelectorFindsNestedAnchorNodes() throws {
        let html = #"<ul><li><a href="a">A</a></li><li><a href="b">B</a></li></ul>"#

        let nodes = try executor.select("a", from: html)

        XCTAssertEqual(nodes.count, 2)
        XCTAssertEqual(nodes.map(\.innerText), ["A", "B"])
        XCTAssertEqual(nodes.map(\.href), ["a", "b"])
    }
}
