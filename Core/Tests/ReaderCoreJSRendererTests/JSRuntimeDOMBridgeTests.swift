import XCTest
@testable import ReaderCoreJSRenderer

final class JSRuntimeDOMBridgeTests: XCTestCase {

    private let bridge = JSRuntimeDOMBridge()

    // MARK: - 1. Tag selector

    func testTagSelectorReturnsMatchedElement() {
        let html = "<html><body><div><a>hello</a></div></body></html>"
        let script = """
        var el = document.querySelector('a');
        if (el) { el.textContent = '__TAG_PASS__'; }
        """
        let result = bridge.execute(html: html, evalScript: script)
        XCTAssertTrue(result.contains("__TAG_PASS__"),
                      "tag selector 'a' should find the element; got: \(result)")
    }

    // MARK: - 2. Class selector

    func testClassSelectorReturnsMatchedElement() {
        let html = "<html><body><div class='x'>A</div></body></html>"
        let script = """
        var el = document.querySelector('.x');
        if (el) { el.textContent = '__CLASS_PASS__'; }
        """
        let result = bridge.execute(html: html, evalScript: script)
        XCTAssertTrue(result.contains("__CLASS_PASS__"),
                      "class selector '.x' should match the div; got: \(result)")
    }

    // MARK: - 3. ID selector

    func testIdSelectorReturnsMatchedElement() {
        let html = "<html><body><div id='y'>B</div></body></html>"
        let script = """
        var el = document.querySelector('#y');
        if (el) { el.textContent = '__ID_PASS__'; }
        """
        let result = bridge.execute(html: html, evalScript: script)
        XCTAssertTrue(result.contains("__ID_PASS__"),
                      "id selector '#y' should match the div; got: \(result)")
    }

    // MARK: - 4. Compound selector (tag.class)

    func testCompoundSelectorTagDotClassMatchesCorrectElement() {
        let html = """
        <html><body>
          <div class='y'>wrong</div>
          <a class='y'>C</a>
        </body></html>
        """
        let script = """
        var el = document.querySelector('a.y');
        if (el) { el.textContent = '__COMPOUND_PASS__'; }
        """
        let result = bridge.execute(html: html, evalScript: script)
        XCTAssertTrue(result.contains("__COMPOUND_PASS__"),
                      "compound selector 'a.y' should match only the <a> element; got: \(result)")
        // The <div class='y'> must NOT have been modified.
        XCTAssertTrue(result.contains("wrong"),
                      "the <div class='y'> should remain 'wrong'; got: \(result)")
    }

    // MARK: - 5. querySelectorAll returns correct count

    func testQuerySelectorAllReturnsCorrectCount() {
        let html = """
        <html><body>
          <ul>
            <li>one</li>
            <li>two</li>
            <li>three</li>
          </ul>
          <div id='counter'></div>
        </body></html>
        """
        let script = """
        var items = document.querySelectorAll('li');
        var count = String(items.length);
        var el = document.querySelector('#counter');
        if (el) { el.textContent = count; }
        """
        let result = bridge.execute(html: html, evalScript: script)
        XCTAssertTrue(result.contains(">3<") || result.contains(">3\n") || result.contains(">3 ") || result.contains("3"),
                      "querySelectorAll('li') should return 3 elements; got: \(result)")
    }

    // MARK: - 6. evalScript innerHTML mutation is reflected in outerHTML

    func testEvalScriptInnerHTMLMutationIsVisibleInOuterHTML() {
        let html = "<html><body><div class='target'>original</div></body></html>"
        let script = """
        var el = document.querySelector('.target');
        if (el) { el.innerHTML = '<span>changed</span>'; }
        """
        let result = bridge.execute(html: html, evalScript: script)
        XCTAssertTrue(result.contains("<span>changed</span>"),
                      "innerHTML assignment should appear in outerHTML; got: \(result)")
        XCTAssertFalse(result.contains("original"),
                       "original text should be replaced; got: \(result)")
    }

    // MARK: - 7. Missing element: querySelector returns null, no throw

    func testQuerySelectorReturnsNullForMissingElement() {
        let html = "<html><body><p>text</p></body></html>"
        let script = """
        var el = document.querySelector('.nonexistent');
        if (!el) { document.querySelector('p').textContent = '__NULL_PASS__'; }
        """
        let result = bridge.execute(html: html, evalScript: script)
        XCTAssertTrue(result.contains("__NULL_PASS__"),
                      "querySelector should return null for missing selector; got: \(result)")
    }

    // MARK: - 8. Fallback: bridge returns original HTML on JS exception

    func testBridgeReturnsFallbackHTMLOnJSException() {
        let html = "<html><body><p>safe</p></body></html>"
        let badScript = "null.nonexistentMethod();"   // will throw TypeError
        let result = bridge.execute(html: html, evalScript: badScript)
        XCTAssertEqual(result, html,
                       "bridge must return original HTML when evalScript throws; got: \(result)")
    }
}
