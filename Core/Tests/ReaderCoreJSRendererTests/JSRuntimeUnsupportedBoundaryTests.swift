import XCTest
@testable import ReaderCoreJSRenderer

final class JSRuntimeUnsupportedBoundaryTests: XCTestCase {
    private enum RegressionSampleID {
        static let querySelectorUnsupported = "sample_js_runtime_002"
    }

    private let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>JSRuntime Query Selector Unsupported</title>
    </head>
    <body>
      <article class="entry">querySelector unsupported boundary</article>
    </body>
    </html>
    """

    func testExecuteReturnsOriginalHTMLWhenQuerySelectorIsUnavailable() {
        XCTAssertEqual(RegressionSampleID.querySelectorUnsupported, "sample_js_runtime_002")

        let runtime = JSRuntime.makeForTesting(
            timeoutMilliseconds: 1500,
            preExecutionDelayMilliseconds: 0,
            additionalEvaluationScripts: [
                "document.querySelector('article')"
            ]
        )

        let output = runtime.execute(html: fixtureHTML)

        XCTAssertEqual(output, fixtureHTML)
    }
}
