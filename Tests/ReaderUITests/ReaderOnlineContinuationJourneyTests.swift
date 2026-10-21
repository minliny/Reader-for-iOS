import XCTest
import UIKit
import Vision

/// Prerequisite: the existing real package/search/admission native journey has
/// succeeded in this same App library. Process environment selects those exact
/// observed identities; it is never sent to the App or used to inject data.
final class ReaderOnlineContinuationJourneyTests: XCTestCase {
    private enum Prerequisite: Error { case missing(String), invalid(String) }
    private struct Book {
        let source: String
        let id: String
        let title: String
        var identity: String { source + "|" + id }
        var shelfID: String { "book-" + id }
    }

    override func setUpWithError() throws { continueAfterFailure = false }

    /// This proves a normal online cold reopen of an explicitly completed
    /// download. It does NOT claim the OS or source origin was offline.
    func testActualCatalogRefreshPreservesVisibleBodyThenDownloadsOneUncachedChapterAndColdReopens() throws {
        let book = try originalBook()
        let indexText = try required("READER_ONLINE_DOWNLOAD_CHAPTER_INDEX")
        guard let downloadIndex = UInt32(indexText) else {
            XCTFail("The selected real canonical download index must be an unsigned integer")
            throw Prerequisite.invalid("READER_ONLINE_DOWNLOAD_CHAPTER_INDEX")
        }
        let app = XCUIApplication(); app.launch()
        open(book, app: app)
        let originalChapter = try currentChapter(book, app: app)
        guard abs(Int64(downloadIndex) - Int64(originalChapter)) > 2 else {
            XCTFail("Choose an actual missing chapter outside the current +/-2 reading cache window")
            throw Prerequisite.invalid("download chapter is inside the reading cache window")
        }
        hideControls(app)
        let progress = app.staticTexts["reading-progress"].label
        let originalAnchor = try anchor(app, name: "real-online-before-catalog-refresh")

        downloads(app)
        let update = app.buttons["online-update-catalog"]
        XCTAssertTrue(update.waitForExistence(timeout: 10)); XCTAssertTrue(update.isEnabled); update.tap()
        let feedback = app.staticTexts["online-catalog-feedback"]
        wait("The actual catalog request must finish", timeout: 180) {
            feedback.exists && feedback.label.hasPrefix("已取得目录，共 ") && update.isEnabled
        }
        keep(app, name: "real-online-updated-installed-catalog")
        app.buttons["online-download-close"].tap()
        XCTAssertEqual(try currentChapter(book, app: app), originalChapter)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "real-online-current-body-preserved-after-catalog-refresh")
        XCTAssertEqual(app.staticTexts["reading-progress"].label, progress)

        downloads(app)
        let stateID = "online-download-state:" + book.identity + ":" + String(downloadIndex)
        let state = app.staticTexts[stateID]
        let select = element("online-download-select:" + book.identity + ":" + String(downloadIndex), app: app)
        reveal(select, in: app.scrollViews["online-download-scroll"], app: app)
        XCTAssertTrue(state.exists, "The selected index must belong to the actual installed catalog")
        XCTAssertEqual(state.label, "未下载", "A cached/completed chapter cannot satisfy the uncached-download prerequisite")
        XCTAssertTrue(select.isHittable); select.tap()
        let download = app.buttons["online-download-selected"]
        reveal(download, in: app.scrollViews["online-download-scroll"], app: app, towardTop: true)
        XCTAssertTrue(download.isEnabled); download.tap()
        // The download list is lazy. Observe the same exact chapter in the
        // visible list rather than treating an unbuilt offscreen row as absent.
        reveal(select, in: app.scrollViews["online-download-scroll"], app: app)
        wait("This exact chapter must complete its original download and materialization", timeout: 300) {
            state.exists && state.label == "已完成"
        }
        keep(app, name: "real-online-exact-uncached-chapter-completed")
        app.buttons["online-download-close"].tap()
        choose(downloadIndex, app: app)
        XCTAssertEqual(try currentChapter(book, app: app), downloadIndex)
        hideControls(app)
        let downloadedAnchor = try anchor(app, name: "real-online-downloaded-chapter-reading")
        XCTAssertNotEqual(downloadedAnchor, originalAnchor)
        leave(app)

        app.terminate(); app.launch()
        open(book, app: app)
        XCTAssertEqual(try currentChapter(book, app: app), downloadIndex)
        hideControls(app)
        try visible(downloadedAnchor, app: app, name: "real-online-downloaded-body-cold-reopen-NETWORK-NOT-DISABLED")
        downloads(app)
        let retainedState = app.staticTexts[stateID]
        reveal(element("online-download-select:" + book.identity + ":" + String(downloadIndex), app: app),
               in: app.scrollViews["online-download-scroll"], app: app)
        XCTAssertEqual(retainedState.label, "已完成")
        keep(app, name: "real-online-completed-download-retained-after-cold-reopen")
        app.buttons["online-download-close"].tap()
        leave(app)
    }

    /// Select this method only after an actual alternate candidate has been
    /// observed. Missing candidates or an unexpected outcome FAIL; a bad source
    /// is never manufactured to make the rollback branch run.
    func testActualSelectableSourceSwitchConfirmsTheSelectedOutcomeAndRetainsOriginalIdentityOnFailure() throws {
        let original = try originalBook()
        let target = Book(source: try required("READER_ONLINE_SWITCH_TARGET_SOURCE_ID"),
                          id: try required("READER_ONLINE_SWITCH_TARGET_BOOK_ID"),
                          title: original.title)
        let expected = try required("READER_ONLINE_SWITCH_EXPECTATION")
        guard target.identity != original.identity, ["success", "failure"].contains(expected) else {
            XCTFail("Choose a real alternate candidate and explicitly select its observed success or failure branch")
            throw Prerequisite.invalid("source-switch prerequisites")
        }
        let app = XCUIApplication(); app.launch(); open(original, app: app)
        let originalChapter = try currentChapter(original, app: app)
        hideControls(app)
        let originalProgress = app.staticTexts["reading-progress"].label
        let originalAnchor = try anchor(app, name: "real-online-original-before-switch")
        controls(app)
        app.buttons["reader-more"].tap(); app.buttons["切换书源"].tap()
        let owner = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-switch-owner:")).firstMatch
        XCTAssertTrue(owner.waitForExistence(timeout: 15))
        let candidate = app.buttons.matching(NSPredicate(format: "identifier == %@", "online-switch-candidate:" + target.identity)).firstMatch
        XCTAssertTrue(candidate.waitForExistence(timeout: 180),
                      "A real selectable candidate is required; no-candidate is an OPEN prerequisite, not a simulated rollback.\n" + app.debugDescription)
        let evidence = XCTAttachment(string: "original=" + original.identity + "\ntarget=" + target.identity + "\nexpected=" + expected)
        evidence.name = "actual-source-switch-identity"; evidence.lifetime = .keepAlways; add(evidence)
        candidate.tap()
        if expected == "success" {
            wait("The original switch must finish and close its sheet", timeout: 300) { !owner.exists }
            XCTAssertTrue(app.textViews["reading-body"].waitForExistence(timeout: 20))
            _ = try currentChapter(target, app: app)
            hideControls(app)
            _ = try anchor(app, name: "real-online-target-body-after-direct-source-selection")
            leave(app)
            app.terminate(); app.launch(); open(target, app: app)
            _ = try currentChapter(target, app: app)
            hideControls(app)
            _ = try anchor(app, name: "real-online-selected-source-after-cold-reopen")
            leave(app)
        } else {
            let outcome = element("online-switch-outcome", app: app)
            wait("The exact source-switch owner must report a definite failure, not pending", timeout: 300) {
                owner.exists && owner.identifier.hasSuffix(":settled") && outcome.exists && !outcome.label.isEmpty && candidate.isEnabled
            }
            keep(app, name: "actual-source-switch-definite-failure")
            app.buttons["online-switch-close"].tap()
            XCTAssertEqual(try currentChapter(original, app: app), originalChapter)
            hideControls(app)
            try visible(originalAnchor, app: app, name: "real-online-old-source-body-preserved-after-actual-switch-failure")
            XCTAssertEqual(app.staticTexts["reading-progress"].label, originalProgress)
            leave(app)
            app.terminate(); app.launch(); open(original, app: app)
            XCTAssertEqual(try currentChapter(original, app: app), originalChapter)
            hideControls(app)
            try visible(originalAnchor, app: app, name: "real-online-original-source-after-failed-switch-and-cold-reopen")
            leave(app)
        }
    }

    private func required(_ key: String) throws -> String {
        guard let value = ProcessInfo.processInfo.environment[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            XCTFail("Required actual-journey provenance is absent from the UITest process: " + key)
            throw Prerequisite.missing(key)
        }
        return value
    }
    private func originalBook() throws -> Book {
        Book(source: try required("READER_ONLINE_SOURCE_ID"), id: try required("READER_ONLINE_BOOK_ID"),
             title: try required("READER_ONLINE_BOOK_TITLE"))
    }
    private func element(_ id: String, app: XCUIApplication) -> XCUIElement {
        // Real source/book URLs can exceed XCTest's string-query limit.
        // A predicate retains exact original identity without truncation.
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }
    private func open(_ book: Book, app: XCUIApplication) {
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 25))
        if app.textFields["shelf-filter"].exists { app.buttons["搜索本地书架"].tap() }
        let rows = app.buttons.matching(NSPredicate(format: "identifier == %@", book.shelfID))
        let row = rows.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), "Reuse the original real admitted shelf book.\n" + app.debugDescription)
        XCTAssertEqual(rows.count, 1, "An ambiguous shelf ID cannot select an exact source")
        XCTAssertTrue(row.isHittable); row.tap()
        XCTAssertTrue(app.textViews["reading-body"].waitForExistence(timeout: 180))
        controls(app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier == %@", "reading-book:" + book.identity)).firstMatch.exists, "The opened reader must retain the exact real source and book identity")
    }
    private func controls(_ app: XCUIApplication) {
        if !app.buttons["reader-more"].isHittable {
            app.textViews["reading-body"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        }
        wait("Normal native reading controls must appear", timeout: 10) { app.buttons["reader-more"].isHittable }
    }
    private func hideControls(_ app: XCUIApplication) {
        let hide = app.buttons["收起阅读控制"]
        if hide.isHittable { hide.tap() }
        wait("Normal reading controls must hide", timeout: 10) { !hide.isHittable }
    }
    private func currentChapter(_ book: Book, app: XCUIApplication) throws -> UInt32 {
        controls(app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier == %@", "reading-book:" + book.identity)).firstMatch.exists)
        let prefix = "reading-chapter:"
        let chapter = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(chapter.waitForExistence(timeout: 10))
        return try XCTUnwrap(UInt32(chapter.identifier.dropFirst(prefix.count)), "Read the real canonical chapter identity without changing its spoken label")
    }
    private func downloads(_ app: XCUIApplication) {
        controls(app); app.buttons["reader-more"].tap()
        XCTAssertTrue(app.buttons["下载管理"].waitForExistence(timeout: 5)); app.buttons["下载管理"].tap()
        XCTAssertTrue(app.buttons["online-update-catalog"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["online-download-selected"].waitForExistence(timeout: 30))
    }
    private func choose(_ index: UInt32, app: XCUIApplication) {
        controls(app)
        app.buttons["control-module-directory"].tap()
        let grabber = app.buttons["control-grabber"]
        if !grabber.label.hasPrefix("完整控制栏") { grabber.tap() }
        wait("The existing full directory controls must open", timeout: 10) { grabber.label.hasPrefix("完整控制栏") }
        let directory = app.buttons.matching(NSPredicate(format: "label == '目录' AND identifier != 'control-module-directory'")).firstMatch
        XCTAssertTrue(directory.waitForExistence(timeout: 5)); directory.tap()
        let row = app.buttons["chapter-\(index)"]
        let scroll = try? XCTUnwrap(app.scrollViews.allElementsBoundByIndex.first(where: \.isHittable))
        XCTAssertNotNil(scroll, "The actual directory scroll surface must be visible")
        if let scroll { reveal(row, in: scroll, app: app) }
        XCTAssertTrue(row.isHittable); row.tap()
        wait("The actual Core directory target must become selected", timeout: 30) { row.isSelected }
    }
    private func reveal(_ target: XCUIElement, in scroll: XCUIElement, app: XCUIApplication, towardTop: Bool = false) {
        XCTAssertTrue(scroll.exists, "Use the actual currently presented scroll surface")
        for _ in 0..<30 {
            if target.exists && target.isHittable { return }
            if towardTop { scroll.swipeDown() } else { scroll.swipeUp() }
        }
        XCTAssertTrue(target.exists && target.isHittable, "The exact real chapter must be reachable through ordinary scrolling.\n" + app.debugDescription)
    }
    private func leave(_ app: XCUIApplication) {
        controls(app); app.buttons["leave-reader"].tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 30))
    }
    private func wait(_ fact: String, timeout: TimeInterval, _ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, fact)
    }
    private func anchor(_ app: XCUIApplication, name: String) throws -> String {
        var lines: [String] = []
        wait("The actual reading viewport must contain visible body text", timeout: 30) {
            guard let actual = try? self.ocr(app), actual.count >= 4 else { return false }
            lines = actual; return true
        }
        let value = String(normalize(lines.dropFirst().prefix(2).joined()).prefix(24))
        XCTAssertGreaterThanOrEqual(value.count, 18)
        keep(app, name: name)
        let evidence = XCTAttachment(string: value)
        evidence.name = name + "-visible-OCR"; evidence.lifetime = .keepAlways; add(evidence)
        return value
    }
    private func visible(_ anchor: String, app: XCUIApplication, name: String) throws {
        wait("The original visible real-body anchor must remain: " + name, timeout: 30) {
            guard let text = try? self.ocr(app) else { return false }
            return self.normalize(text.joined()).contains(anchor)
        }
        keep(app, name: name)
    }
    private func normalize(_ value: String) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }
    private func ocr(_ app: XCUIApplication) throws -> [String] {
        let source = try XCTUnwrap(app.screenshot().image.cgImage)
        let window = app.frame
        let frame = app.textViews["reading-body"].frame.intersection(window).insetBy(dx: 6, dy: 6)
        let rect = CGRect(x: (frame.minX - window.minX) * CGFloat(source.width) / window.width,
            y: (frame.minY - window.minY) * CGFloat(source.height) / window.height,
            width: frame.width * CGFloat(source.width) / window.width,
            height: frame.height * CGFloat(source.height) / window.height).integral
        let image = try XCTUnwrap(source.cropping(to: rect))
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]; request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).sorted {
            abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.01
                ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
        }.compactMap { $0.topCandidates(1).first?.string }
    }
    private func keep(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
