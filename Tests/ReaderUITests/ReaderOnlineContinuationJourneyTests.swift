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

    /// Real discovery reads only. The same observed candidate identities,
    /// labels/timings and intra-row geometry must survive ordinary sheet closes.
    /// The Runner selects an already admitted real book; no candidate is tapped.
    func testExistingOnlineSourceSwitchSheetReopenPreservesActualScrolledCandidatesWithoutSwitching() throws {
        let book = try originalBook()
        let app = XCUIApplication(); app.launch(); open(book, app: app)
        let originalChapter = try currentChapter(book, app: app)
        hideControls(app)
        let originalProgress = app.staticTexts["reading-progress"].label
        let originalAnchor = try anchor(app, name: "real-switch-viewport-original-body")
        openReadOnlySwitchSheet(app)
        let initial = try stableSwitchSnapshot(app, timeout: 180, name: "initial-real-settled-candidates")
        try keepSwitchGeometry(initial, app: app, name: "initial-real-settled-candidates")

        var scrolled: SwitchSnapshot?
        for attempt in 0..<6 {
            let current = try stableSwitchSnapshot(app, timeout: 10, name: "before-owned-drag-\(attempt)")
            let distance = min(CGFloat(120), max(CGFloat(50), current.rows[0].frame.height * 0.45))
            let from = switchCoordinate(CGPoint(x: current.frame.midX, y: current.frame.minY + current.frame.height * 0.72), app: app)
            let to = switchCoordinate(CGPoint(x: current.frame.midX, y: current.frame.minY + current.frame.height * 0.72 - distance), app: app)
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
            let now = try stableSwitchSnapshot(app, timeout: 10, name: "after-owned-drag-\(attempt)")
            try keepSwitchGeometry(now, app: app, name: "after-owned-drag-\(attempt)")
            let hasMoved = initial.rows.contains { old in
                guard let current = now.rows.first(where: { $0.id == old.id }) else { return true }
                return abs(current.frame.minY - old.frame.minY) >= min(CGFloat(40), old.frame.height / 3)
            }
            let hasIntraRowOffset = now.rows.contains { row in
                row.frame.minY <= now.frame.minY - 12 && row.frame.maxY >= now.frame.minY + 28
            }
            if hasMoved && hasIntraRowOffset { scrolled = now; break }
        }
        guard let baseline = scrolled else {
            XCTFail("Actual candidates must provide genuine scrolling with a clipped row's interior at the viewport edge; do not manufacture candidates or replace this prerequisite with a top-aligned row")
            throw Prerequisite.invalid("actual intra-row scroll unavailable")
        }
        try keepSwitchGeometry(baseline, app: app, name: "exact-intra-row-baseline")
        closeReadOnlySwitchSheet(app)
        XCTAssertEqual(try currentChapter(book, app: app), originalChapter)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "real-body-preserved-after-first-sheet-close")
        XCTAssertEqual(app.staticTexts["reading-progress"].label, originalProgress)

        openReadOnlySwitchSheet(app)
        try assertSwitchRestored(baseline, query: baseline.query, app: app, name: "same-query-first-reopen")
        closeReadOnlySwitchSheet(app)
        XCTAssertEqual(try currentChapter(book, app: app), originalChapter)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "real-switch-viewport-final-original-body")
        XCTAssertEqual(app.staticTexts["reading-progress"].label, originalProgress)
        leave(app)
    }

    private struct SwitchRow {
        let id: String
        let label: String
        let timing: String
        let frame: CGRect
    }
    private struct SwitchSnapshot {
        let query: String
        let frame: CGRect
        let rows: [SwitchRow]
        let observedUptime: TimeInterval
    }
    private func openReadOnlySwitchSheet(_ app: XCUIApplication) {
        controls(app); app.buttons["reader-more"].tap()
        let route = app.buttons["切换书源"]
        XCTAssertTrue(route.waitForExistence(timeout: 5)); XCTAssertTrue(route.isHittable); route.tap()
        XCTAssertTrue(app.buttons["online-switch-close"].waitForExistence(timeout: 15))
    }
    private func closeReadOnlySwitchSheet(_ app: XCUIApplication) {
        let close = app.buttons["online-switch-close"]
        XCTAssertTrue(close.isHittable); close.tap()
        wait("The real switch sheet and its keyboard must finish dismissing", timeout: 10) {
            !close.exists && !app.keyboards.firstMatch.exists
        }
    }
    private func switchQueryValue(_ app: XCUIApplication) -> String? {
        let fields = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "书名或作者"))
            .allElementsBoundByIndex.filter(\.isHittable)
        guard fields.count == 1, let value = fields[0].value as? String else { return nil }
        return value == "书名或作者" ? "" : value
    }
    private func observedSwitchSnapshot(_ app: XCUIApplication) -> SwitchSnapshot? {
        guard !app.keyboards.firstMatch.exists, app.buttons["online-switch-close"].isHittable,
              let query = switchQueryValue(app) else { return nil }
        let owner = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "online-switch-owner:settled"))
        let settled = app.buttons.matching(NSPredicate(format: "label == %@", "重新搜索"))
        guard owner.count == 1, owner.element.exists, settled.count == 1, settled.element.isHittable,
              !app.buttons.matching(NSPredicate(format: "label == %@", "停止")).firstMatch.exists,
              !app.staticTexts["正在查找其他来源"].exists else { return nil }
        let prefix = "online-switch-candidate:"
        let frames = app.scrollViews.allElementsBoundByIndex.compactMap { scroll -> CGRect? in
            let frame = scroll.frame.intersection(app.frame)
            guard !frame.isNull, frame.width > 100, frame.height > 100,
                  scroll.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
                    .allElementsBoundByIndex.contains(where: { $0.isHittable && frame.intersects($0.frame) }) else { return nil }
            return frame
        }
        guard let viewport = frames.min(by: { $0.height < $1.height }) else { return nil }
        let visible = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .allElementsBoundByIndex.filter { row in
                let frame = row.frame, intersection = frame.intersection(viewport)
                return row.isHittable && !intersection.isNull && intersection.height >= 12 && frame.width > 0 && frame.height > 0
            }
        // Do not silently drop a visible stale/untimed/disabled candidate from
        // the exact geometry group merely because other rows would qualify.
        var rows: [SwitchRow] = []
        for row in visible {
            guard row.isEnabled, let timingRange = row.label.range(of: #"[0-9]+ ms"#, options: .regularExpression),
                  !row.label.contains("上次候选") else { return nil }
            let identity = String(row.identifier.dropFirst(prefix.count))
            guard let split = identity.firstIndex(of: "|"), split != identity.startIndex,
                  identity.index(after: split) != identity.endIndex else { return nil }
            rows.append(SwitchRow(id: row.identifier, label: row.label,
                timing: String(row.label[timingRange]), frame: row.frame))
        }
        rows.sort { $0.frame.minY == $1.frame.minY ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY }
        guard rows.count >= 2, Set(rows.map(\.id)).count == rows.count else { return nil }
        return SwitchSnapshot(query: query, frame: viewport, rows: rows, observedUptime: ProcessInfo.processInfo.systemUptime)
    }

    private func sameSwitchGeometry(_ a: SwitchSnapshot, _ b: SwitchSnapshot, tolerance: CGFloat, compareQuery: Bool) -> Bool {
        func equal(_ x: CGRect, _ y: CGRect) -> Bool {
            [abs(x.minX-y.minX), abs(x.minY-y.minY), abs(x.width-y.width), abs(x.height-y.height)].allSatisfy { $0 <= tolerance }
        }
        guard (!compareQuery || a.query == b.query), equal(a.frame, b.frame),
              a.rows.map(\.id) == b.rows.map(\.id) else { return false }
        return zip(a.rows,b.rows).allSatisfy { x,y in
            x.label == y.label && x.timing == y.timing &&
            equal(x.frame.offsetBy(dx: -a.frame.minX, dy: -a.frame.minY), y.frame.offsetBy(dx: -b.frame.minX, dy: -b.frame.minY))
        }
    }
    private func stableSwitchSnapshot(_ app: XCUIApplication, timeout: TimeInterval, name: String) throws -> SwitchSnapshot {
        var reference: SwitchSnapshot?, since: TimeInterval?, captured: SwitchSnapshot?
        let condition = XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
            guard let now = self.observedSwitchSnapshot(app) else { reference=nil; since=nil; return false }
            let time = ProcessInfo.processInfo.systemUptime
            if let old = reference, self.sameSwitchGeometry(old, now, tolerance: 0.25, compareQuery: true) {
                if let began = since, time-began >= 0.5 { captured=now; return true }
            } else { reference=now; since=time }
            return false
        }, object: nil)
        let outcome = XCTWaiter.wait(for: [condition], timeout: timeout)
        if let actual = observedSwitchSnapshot(app) { try keepSwitchGeometry(actual, app: app, name: name+"-actual") }
        guard outcome == .completed, let result = captured else {
            keep(app, name: name+"-prerequisite-failure")
            let evidence = XCTAttachment(string: app.debugDescription); evidence.name=name+"-actual-AX"; evidence.lifetime = .keepAlways; add(evidence)
            XCTFail("Require settled real search, >=2 actual candidates with real timings, no keyboard and stable public geometry: "+name)
            throw Prerequisite.invalid("real switch viewport prerequisite")
        }
        return result
    }
    private func assertSwitchRestored(_ original: SwitchSnapshot, query: String, app: XCUIApplication, name: String) throws {
        let actual = try stableSwitchSnapshot(app, timeout: 15, name: name)
        try keepSwitchGeometry(original, app: app, name: name+"-original-reference", includeScreenshot: false)
        try keepSwitchGeometry(actual, app: app, name: name+"-reopened-actual")
        XCTAssertEqual(actual.query, query, "Preserve the exact visible query intent without starting a new search")
        guard actual.query == query, sameSwitchGeometry(original, actual, tolerance: 2, compareQuery: false) else {
            XCTFail("The same complete candidate IDs/order/labels/timings and each viewport-relative x/y/width/height must survive the real sheet reopen within the original2pt; do not snap to a row or scroll to repair the observation")
            throw Prerequisite.invalid("actual sheet viewport changed")
        }
    }
    private func keepSwitchGeometry(_ snapshot: SwitchSnapshot, app: XCUIApplication, name: String, includeScreenshot: Bool = true) throws {
        func rect(_ value: CGRect) -> [String: Double] {
            ["x":Double(value.minX),"y":Double(value.minY),"width":Double(value.width),"height":Double(value.height)]
        }
        let value: [String: Any] = ["query":snapshot.query,"viewport":rect(snapshot.frame),
            "rows":snapshot.rows.map { row -> [String: Any] in
                ["identifier":row.id,"label":row.label,"timing":row.timing,"frame":rect(row.frame),
                 "viewportRelative":rect(row.frame.offsetBy(dx:-snapshot.frame.minX,dy:-snapshot.frame.minY))]
            },"keyboardVisibleAtAttachment":app.keyboards.firstMatch.exists,"observedUptime":snapshot.observedUptime,
            "attachmentAtUptime":ProcessInfo.processInfo.systemUptime]
        let attachment = XCTAttachment(data:try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]),uniformTypeIdentifier:"public.json")
        attachment.name=name+"-actual-source-book-geometry"; attachment.lifetime = .keepAlways; add(attachment)
        if includeScreenshot { keep(app,name:name) }
    }
    private func switchCoordinate(_ point: CGPoint, app: XCUIApplication) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx:point.x-app.frame.minX,dy:point.y-app.frame.minY))
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
