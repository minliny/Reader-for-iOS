import XCTest
@testable import ReaderCoreJSRenderer

final class JSRuntimeTests: XCTestCase {
    private enum RegressionSampleID {
        static let timeoutFallback = "sample_js_runtime_001"
    }

    private let fixtureHTML = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>JSRuntime Timeout Fallback</title>
    </head>
    <body>
      <article data-sample="sample_js_runtime_001">timeout fallback contract</article>
    </body>
    </html>
    """

    func testExecuteReturnsOuterHTMLForInjectedDocument() {
        let runtime = JSRuntime()

        let output = runtime.execute(html: fixtureHTML)

        XCTAssertEqual(output, fixtureHTML)
    }

    func testExecuteReturnsOriginalHTMLWhenExecutionTimesOut() {
        XCTAssertEqual(RegressionSampleID.timeoutFallback, "sample_js_runtime_001")

        let runtime = JSRuntime.makeForTesting(
            timeoutMilliseconds: 10,
            preExecutionDelayMilliseconds: 30,
            additionalEvaluationScripts: []
        )

        let output = runtime.execute(html: fixtureHTML)

        XCTAssertEqual(output, fixtureHTML)
    }
}
