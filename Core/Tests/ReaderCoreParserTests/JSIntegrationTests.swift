// Tests/ReaderCoreParserTests/JSIntegrationTests.swift
//
// End-to-end integration: NonJSParserEngine + JSRuntimeDOMBridge via JSParserEngineFactory.
//
// CONTRACT:
//   - All JS execution goes through NonJSParserEngine(jsGate:) — never calls
//     JSRuntimeDOMBridge directly.
//   - Tests cover: @js: rule success path, JS exception fallback, and
//     non-JS rule regression (must be identical to pre-P2 behaviour).

import XCTest
import ReaderCoreModels
import ReaderCoreParser
import ReaderCoreJSRenderer   // for JSParserEngineFactory

final class JSIntegrationTests: XCTestCase {

    // Parser wired with live JSRuntimeDOMBridge — same factory used in production.
    private let jsEngine = JSParserEngineFactory.makeJSCapableParser()

    // Null-gate engine used to verify non-JS path is unaffected.
    private let plainEngine = NonJSParserEngine()

    // MARK: - 1. JS rule execution in search flow

    /// @js: code modifies the DOM; the subsequent CSS rule extracts the modified value.
    /// Verifies that the JS preprocessing + CSS extraction pipeline works end-to-end.
    func testJSRulePreprocessingProducesCorrectSearchResult() throws {
        let html = """
        <html><body>
          <div id="result">original</div>
        </body></html>
        """
        // JS sets textContent; CSS rule extracts it.
        let source = BookSource(
            bookSourceName: "js-integration-search",
            ruleSearch: "@js:document.querySelector('#result').textContent = 'js-processed';|css:#result"
        )
        let items = try jsEngine.parseSearchResponse(
            Data(html.utf8), source: source, query: SearchQuery(keyword: "test")
        )
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "js-processed",
                       "@js: preprocessing should set textContent to 'js-processed'")
    }

    /// @js: code modifies multiple list items; querySelectorAll count is reflected.
    func testJSRuleModifiesMultipleElementsInTOCFlow() throws {
        let html = """
        <html><body>
          <ul>
            <li class="ch">Chapter 1|/ch/1</li>
            <li class="ch">Chapter 2|/ch/2</li>
          </ul>
        </body></html>
        """
        // JS appends a marker to every .ch element; the CSS rule extracts them.
        let source = BookSource(
            bookSourceName: "js-integration-toc",
            ruleToc: "@js:var els=document.querySelectorAll('.ch');for(var i=0;i<els.length;i++){els[i].textContent=els[i].textContent+'-ok';}|css:.ch"
        )
        let items = try jsEngine.parseTOCResponse(
            Data(html.utf8), source: source, detailURL: "/book/1"
        )
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items[0].chapterTitle.hasSuffix("-ok"),
                      "JS should append '-ok' to first chapter title; got '\(items[0].chapterTitle)'")
        XCTAssertTrue(items[1].chapterTitle.hasSuffix("-ok"),
                      "JS should append '-ok' to second chapter title; got '\(items[1].chapterTitle)'")
    }

    /// @js: code sets innerHTML; the result is reflected in the content extraction.
    func testJSRuleInnerHTMLMutationIsReflectedInContentFlow() throws {
        let html = "<html><body><div id='content'>raw</div></body></html>"
        let source = BookSource(
            bookSourceName: "js-integration-content",
            ruleContent: "@js:document.querySelector('#content').innerHTML='<p>cleaned</p>';|css:#content"
        )
        let page = try jsEngine.parseContentResponse(
            Data(html.utf8), source: source, chapterURL: "/ch/1"
        )
        XCTAssertEqual(page.content, "cleaned",
                       "innerHTML assignment should be visible after JS preprocessing; got '\(page.content)'")
    }

    // MARK: - 2. JS exception fallback

    /// When evalScript throws, JSRuntime returns the original HTML unchanged.
    /// The subsequent CSS rule runs on the unmodified HTML — parser does NOT crash.
    func testJSExceptionFallsBackToOriginalHTMLAndCSSRuleStillRuns() throws {
        let html = "<html><body><div class='entry'>safe-value</div></body></html>"
        let source = BookSource(
            bookSourceName: "js-exception-fallback",
            // null.boom() throws TypeError; fallback HTML is handed to css:.entry
            ruleSearch: "@js:null.boom();|css:.entry"
        )
        // Should not throw — fallback HTML is well-formed and css:.entry matches.
        let items = try jsEngine.parseSearchResponse(
            Data(html.utf8), source: source, query: SearchQuery(keyword: "q")
        )
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "safe-value",
                       "After JS exception the CSS rule should run on original HTML; got '\(items[0].title)'")
    }

    /// An evalScript that references an undefined variable also triggers fallback.
    func testUndefinedVariableInJSFallsBackToOriginalHTML() throws {
        let html = "<html><body><div class='target'>untouched</div></body></html>"
        let source = BookSource(
            bookSourceName: "js-undefined-fallback",
            ruleSearch: "@js:nonExistentFunction();|css:.target"
        )
        let items = try jsEngine.parseSearchResponse(
            Data(html.utf8), source: source, query: SearchQuery(keyword: "q")
        )
        XCTAssertFalse(items.isEmpty, "Parser must not throw on JS exception")
        XCTAssertEqual(items[0].title, "untouched")
    }

    // MARK: - 3. Non-JS path regression

    /// Rules without @js: prefix must behave exactly as before P2.
    /// Tests that the plain engine and the JS-capable engine produce identical results
    /// for non-JS sources.
    func testNonJSRuleIsUnaffectedByJSGateInjection() throws {
        let html = """
        <html><body>
          <div class="title">Book One</div>
          <div class="title">Book Two</div>
        </body></html>
        """
        let source = BookSource(
            bookSourceName: "regression-non-js",
            ruleSearch: "css:.title"
        )
        let query = SearchQuery(keyword: "any")

        let itemsJS    = try jsEngine.parseSearchResponse(Data(html.utf8), source: source, query: query)
        let itemsPlain = try plainEngine.parseSearchResponse(Data(html.utf8), source: source, query: query)

        XCTAssertEqual(itemsJS.count, itemsPlain.count,
                       "JS-capable engine must produce the same count as plain engine for non-JS rules")
        XCTAssertEqual(itemsJS.map(\.title), itemsPlain.map(\.title),
                       "Titles must be identical for non-JS rules")
    }

    /// CSS-only TOC rule regression.
    func testNonJSTOCRuleRegressionWithJSGateInjected() throws {
        let html = """
        <html><body>
          <a class="ch" href="/1">Chapter A|/1</a>
          <a class="ch" href="/2">Chapter B|/2</a>
        </body></html>
        """
        let source = BookSource(
            bookSourceName: "regression-toc",
            ruleToc: "css:.ch"
        )
        let itemsJS    = try jsEngine.parseTOCResponse(Data(html.utf8), source: source, detailURL: "/")
        let itemsPlain = try plainEngine.parseTOCResponse(Data(html.utf8), source: source, detailURL: "/")

        XCTAssertEqual(itemsJS.map(\.chapterTitle), itemsPlain.map(\.chapterTitle))
    }

    /// CSS-only content rule regression.
    func testNonJSContentRuleRegressionWithJSGateInjected() throws {
        let html = "<html><body><div class='body'>Main text here.</div></body></html>"
        let source = BookSource(
            bookSourceName: "regression-content",
            ruleContent: "css:.body"
        )
        let pageJS    = try jsEngine.parseContentResponse(Data(html.utf8), source: source, chapterURL: "/")
        let pagePlain = try plainEngine.parseContentResponse(Data(html.utf8), source: source, chapterURL: "/")

        XCTAssertEqual(pageJS.content, pagePlain.content)
    }

    // MARK: - 4. NullJSRenderingGate passthrough (unit boundary)

    /// Verifies that NullJSRenderingGate returns the HTML unchanged so the CSS
    /// rule runs on the original content (no hidden transformation).
    func testNullJSRenderingGatePassesThroughHTML() {
        let gate = NullJSRenderingGate.shared
        let original = "<html><body><div>check</div></body></html>"
        let result = gate.execute(html: original, evalScript: "document.querySelector('div').textContent = 'changed';")
        XCTAssertEqual(result, original,
                       "NullJSRenderingGate must return HTML unchanged regardless of evalScript")
    }
}
