import XCTest
import Vision
import UIKit

final class ReaderNativeJourneyTests: XCTestCase {
    // Provision the user's original Downloads file in this simulator's Documents
    // before running. This test never generates or substitutes book contents.
    private let bookName = "仙子请听我解释"
    override func setUpWithError() throws { continueAfterFailure = false }

    func testOrdinaryPageNavigationAndAppAppearance() throws {
        func tapNativeSwitch(_ row: XCUIElement) {
            // SwiftUI exposes both a labelled row and its UISwitch child.
            // The row's centre is label space on a compact display; it did not
            // toggle follow-system in the retained compact-ui-1 failure.
            let nativeSwitch = row.switches.firstMatch
            let control = nativeSwitch.exists ? nativeSwitch : row
            XCTAssertTrue(control.isEnabled)
            XCTAssertTrue(control.isHittable)
            control.tap()
        }
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 15))
        app.buttons["设置"].tap()
        let systemAppearance = app.switches["settings-follow-system"]
        XCTAssertTrue(systemAppearance.waitForExistence(timeout: 5))
        let initialSystem = try XCTUnwrap(systemAppearance.value as? String)
        XCTAssertTrue(["0", "1"].contains(initialSystem))
        if initialSystem == "1" { tapNativeSwitch(systemAppearance) }
        let manualAppearance = expectation(for: NSPredicate(format: "value == '0'"), evaluatedWith: systemAppearance)
        wait(for: [manualAppearance], timeout: 5)
        let appearance = app.switches["settings-night-mode"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        let enabled = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: appearance)
        wait(for: [enabled], timeout: 5)
        let previous = try XCTUnwrap(appearance.value as? String)
        XCTAssertTrue(["0", "1"].contains(previous))
        let expected = previous == "0" ? "1" : "0"
        tapNativeSwitch(appearance)
        let changed = expectation(for: NSPredicate(format: "value == %@", expected), evaluatedWith: appearance)
        wait(for: [changed], timeout: 5)
        app.buttons["书架"].tap()
        XCTAssertTrue(app.buttons["更多书架操作"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "bookshelf-native"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["设置"].waitForExistence(timeout: 15))
        app.buttons["设置"].tap()
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        XCTAssertEqual(systemAppearance.value as? String, "0")
        XCTAssertEqual(appearance.value as? String, expected)
    }

    func testNativePickerToReadingAndColdReopen() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 15))
        app.buttons["更多书架操作"].tap()
        app.buttons["import-book"].tap()
        // Wait for the picker cell itself: the shelf already contains a title
        // with the same label after an earlier successful import.
        let cell = app.cells.containing(.staticText, identifier: bookName).firstMatch
        let cellWithExtension = app.cells.containing(.staticText, identifier: bookName + ".txt").firstMatch
        if !cell.waitForExistence(timeout: 3), !cellWithExtension.exists {
            // The retained iPad failure was at My iPad, where the real Reader
            // Documents container was visible but had not yet been entered.
            let readerFolder = app.cells.matching(NSPredicate(
                format: "identifier == 'Reader, Container' OR label BEGINSWITH 'Reader,'")).firstMatch
            XCTAssertTrue(readerFolder.waitForExistence(timeout: 10), app.debugDescription)
            readerFolder.tap()
        }
        XCTAssertTrue(cell.waitForExistence(timeout: 15) || cellWithExtension.waitForExistence(timeout: 5), app.debugDescription)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "native-picker-hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        if cell.exists { cell.tap() } else { cellWithExtension.tap() }
        let openSelection = app.buttons["打开"]
        if openSelection.waitForExistence(timeout: 2) { openSelection.tap() }
        XCTAssertTrue(app.buttons["关闭导入结果"].waitForExistence(timeout: 20), app.debugDescription)
        let imported = NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "已导入书架", "这本书已在书架中")
        let result = app.staticTexts.matching(imported).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 120), app.debugDescription)
        app.buttons["关闭导入结果"].tap()
        let book = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'book-' AND label CONTAINS %@", bookName)).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 10))
        book.tap()
        let body = app.textViews["reading-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 15))
        let progress = app.staticTexts["reading-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        let initialReading = XCTAttachment(screenshot: app.screenshot())
        initialReading.name = "real-book-initial-reading"; initialReading.lifetime = .keepAlways; add(initialReading)
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        XCTAssertTrue(app.buttons["control-module-directory"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '948' AND label CONTAINS '章'")).firstMatch.waitForExistence(timeout: 5))
        let quick = XCTAttachment(screenshot: app.screenshot()); quick.name = "reader-quick"; quick.lifetime = .keepAlways; add(quick)
        app.buttons["control-module-directory"].tap()
        app.buttons["control-grabber"].tap()
        XCTAssertTrue(app.buttons["chapter-1"].waitForExistence(timeout: 5))
        let full = XCTAttachment(screenshot: app.screenshot()); full.name = "reader-directory-full"; full.lifetime = .keepAlways; add(full)
        dragControls(app, by: 90)
        waitForControls(app, labelPrefix: "快捷控制栏")
        dragControls(app, by: -90)
        waitForControls(app, labelPrefix: "完整控制栏")
        app.buttons["control-grabber"].press(forDuration: 0.65)
        XCTAssertTrue(app.buttons["control-grabber"].label.hasPrefix("完整控制栏"))
        let dragged = XCTAttachment(screenshot: app.screenshot())
        dragged.name = "reader-full-after-native-drag"; dragged.lifetime = .keepAlways; add(dragged)
        app.buttons["chapter-2"].tap()
        let nextSelected = expectation(for: NSPredicate(format: "selected == true"), evaluatedWith: app.buttons["chapter-2"])
        wait(for: [nextSelected], timeout: 10)
        app.buttons["chapter-1"].tap()
        let selected = expectation(for: NSPredicate(format: "selected == true"), evaluatedWith: app.buttons["chapter-1"])
        wait(for: [selected], timeout: 10)
        app.buttons["control-grabber"].tap()
        waitForControls(app, labelPrefix: "快捷控制栏")
        dragControls(app, by: 45)
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.swipeLeft()
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        let chapterProgressed = expectation(for: NSPredicate(format: "label != '0%'"), evaluatedWith: progress)
        wait(for: [chapterProgressed], timeout: 10)
        // A rounded percentage cannot prove restoration. Capture the actual
        // native-rendered Chinese text lines with the system OCR framework.
        let expectedAnchor = try renderedAnchor(in: body, app: app)
        let expectedChapterProgress = progress.label
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        XCTAssertEqual(try renderedAnchor(in: body, app: app), expectedAnchor)
        XCTAssertEqual(progress.label, expectedChapterProgress)
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        app.buttons["leave-reader"].tap()
        XCTAssertTrue(book.waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(book.waitForExistence(timeout: 15))
        book.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 15))
        XCTAssertEqual(try renderedAnchor(in: body, app: app), expectedAnchor)
        XCTAssertEqual(app.staticTexts["reading-progress"].label, expectedChapterProgress)
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        app.buttons["control-module-directory"].tap()
        XCTAssertTrue(app.buttons["chapter-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["chapter-1"].isSelected)
        app.buttons["收起阅读控制"].tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        let restored = XCTAttachment(screenshot: app.screenshot()); restored.name = "reader-restored"; restored.lifetime = .keepAlways; add(restored)
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        let chapterSlider = app.sliders["chapter-progress"]
        XCTAssertTrue(chapterSlider.waitForExistence(timeout: 5))
        chapterSlider.adjust(toNormalizedSliderPosition: 1)
        let adjusted = chapterSlider.normalizedSliderPosition
        let sliderInput = XCTAttachment(string: "XCTest best-effort normalized position=\(adjusted); actual AX value=\(String(describing: chapterSlider.value))")
        sliderInput.name = "actual-chapter-end-slider-input"; sliderInput.lifetime = .keepAlways; add(sliderInput)
        if adjusted < 0.9999 {
            // Public XCTest documents normalized adjustment as best effort.
            // Reach the actual UISlider endpoint with a real track drag before
            // requiring an exact end request; do not round 98.8% into 100%.
            let center = chapterSlider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let beyondEnd = chapterSlider.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
                .withOffset(CGVector(dx: 12, dy: 0))
            center.press(forDuration: 0.1, thenDragTo: beyondEnd)
        }
        XCTAssertEqual(chapterSlider.normalizedSliderPosition, 1, accuracy: 0.0001,
            "The real native slider must receive the end before testing end-of-chapter persistence")
        app.buttons["收起阅读控制"].tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        let reachedEnd = expectation(for: NSPredicate(format: "label == '100%'"), evaluatedWith: progress)
        wait(for: [reachedEnd], timeout: 10)
        XCTAssertLessThan(body.frame.maxY, progress.frame.minY)
        let end = XCTAttachment(screenshot: app.screenshot()); end.name = "real-book-chapter-end"; end.lifetime = .keepAlways; add(end)
    }

    func testTwoOriginalTXTBatchImport() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 15))
        app.buttons["更多书架操作"].tap()
        app.buttons["import-book"].tap()
        // Both inputs must be copies of the user's untouched Downloads files.
        // Absence is a failed prerequisite; this test never generates fixtures.
        for filename in ["仙子请听我解释.txt", "湛蓝权杖 (躺摆混) (Z-Library).txt"] {
            let basename = (filename as NSString).deletingPathExtension
            let item = app.cells.containing(NSPredicate(format: "label == %@ OR label == %@", filename, basename)).firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 10), app.debugDescription)
            item.tap()
        }
        let open = app.buttons["打开"]
        XCTAssertTrue(open.waitForExistence(timeout: 5), app.debugDescription)
        open.tap()
        XCTAssertTrue(app.buttons["关闭导入结果"].waitForExistence(timeout: 20))
        let completed = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '已完成 2 项' AND label CONTAINS '失败 0 项'")).firstMatch
        XCTAssertTrue(completed.waitForExistence(timeout: 180), app.debugDescription)
        app.buttons["关闭导入结果"].tap()
        for title in ["仙子请听我解释", "湛蓝权杖"] {
            let book = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'book-' AND label CONTAINS %@", title)).firstMatch
            XCTAssertTrue(book.waitForExistence(timeout: 10), app.debugDescription)
        }
    }

    func testCompactGutenbergTXTDirectoryBoundsAndColdVisibleAnchor() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("This verification uses a dedicated iPhone simulator")
        #endif
        let environment = ProcessInfo.processInfo.environment
        let simulator = "Reader-iPhone-Daily-Closeout-20261123"
        guard environment["SIMULATOR_DEVICE_NAME"] == simulator, UIDevice.current.userInterfaceIdiom == .phone else {
            XCTFail("Select the dedicated \(simulator) iPhone simulator")
            return
        }

        executionTimeAllowance = 300
        let app = XCUIApplication()
        let bookID = "book-local:997442c1d041cc731d57bd164078a1dd6e98a5fe0eb9b6ec8b202edc3d0a5a38"
        let book = app.buttons[bookID]
        let shelf = app.buttons["更多书架操作"]
        let body = app.textViews["reading-body"]
        let progress = app.staticTexts["reading-progress"]
        let grabber = app.buttons["control-grabber"]
        let query = app.textFields["directory-query"]
        let chapterPrefix = "reading-chapter:"
        var completed = false
        addTeardownBlock {
            if !completed && app.state == .runningForeground {
                let tree = XCTAttachment(string: app.debugDescription)
                tree.name = "compact-TXT-failure-actual-AX"
                tree.lifetime = .keepAlways
                self.add(tree)
            }
        }

        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        func waitUntil(_ detail: String, timeout: TimeInterval = 10, _ condition: @escaping () -> Bool) {
            let predicate = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [predicate], timeout: timeout), .completed, detail)
        }

        func openBook() {
            XCTAssertTrue(book.waitForExistence(timeout: 15))
            XCTAssertTrue(book.isHittable)
            book.tap()
            XCTAssertTrue(body.waitForExistence(timeout: 20))
            XCTAssertTrue(progress.waitForExistence(timeout: 5))
        }

        func showQuick() {
            if !grabber.isHittable {
                body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
                XCTAssertTrue(grabber.waitForExistence(timeout: 5))
            }
            if grabber.label.hasPrefix("完整控制栏") {
                grabber.tap()
                waitForControls(app, labelPrefix: "快捷控制栏")
            }
        }

        func showDirectory() {
            showQuick()
            let module = app.buttons["control-module-directory"]
            XCTAssertTrue(module.isHittable)
            module.tap()
            if !grabber.label.hasPrefix("完整控制栏") { grabber.tap() }
            waitForControls(app, labelPrefix: "完整控制栏")
            let directory = app.buttons.matching(NSPredicate(
                format: "label == '目录' AND identifier != 'control-module-directory'")).firstMatch
            XCTAssertTrue(directory.waitForExistence(timeout: 5))
            if !directory.isSelected { directory.tap() }
            XCTAssertTrue(query.waitForExistence(timeout: 5))
        }

        func showHome() {
            showQuick()
            let home = app.buttons["control-module-home"]
            XCTAssertTrue(home.isHittable)
            home.tap()
        }

        func dismissControls() {
            let hide = app.buttons["收起阅读控制"]
            XCTAssertTrue(hide.isHittable)
            hide.tap()
            waitUntil("The unobscured original body and footer return") { body.isHittable && progress.exists }
        }

        func currentChapter() throws -> UInt32 {
            let chapter = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", chapterPrefix))
            XCTAssertEqual(chapter.count, 1)
            return try XCTUnwrap(UInt32(chapter.element.identifier.dropFirst(chapterPrefix.count)))
        }

        func directoryViewport() throws -> CGRect {
            // The Full directory owns an unnamed ScrollView. Read its actual
            // ancestry in one AX snapshot. A global ScrollView query can also
            // resolve the unrelated UIPageViewController content scroll.
            func locate(_ node: any XCUIElementSnapshot) -> (hasRows: Bool, viewport: CGRect?) {
                if node.identifier.hasPrefix("chapter-") { return (true, nil) }
                var hasRows = false
                for child in node.children {
                    let found = locate(child)
                    if let viewport = found.viewport { return (true, viewport) }
                    hasRows = hasRows || found.hasRows
                }
                return (hasRows, hasRows && node.elementType == .scrollView ? node.frame : nil)
            }
            let viewport = try XCTUnwrap(locate(app.snapshot()).viewport, "Require the actual scroll ancestor of chapter rows")
            let visible = viewport.intersection(app.frame)
            XCTAssertGreaterThan(visible.height, 100)
            return visible
        }

        func visibleRows(in viewport: CGRect) -> [UInt32] {
            return app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chapter-'"))
                .allElementsBoundByIndex.compactMap { row -> (UInt32, CGFloat)? in
                    guard let index = UInt32(row.identifier.dropFirst("chapter-".count)),
                          !row.frame.isEmpty, viewport.contains(row.frame), row.isHittable else { return nil }
                    return (index, row.frame.midY)
                }.sorted { $0.1 < $1.1 }.map(\.0)
        }

        func scrollDirectory(_ viewport: CGRect, towardEnd: Bool) {
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let x = viewport.midX - app.frame.minX
            let top = viewport.minY - app.frame.minY + viewport.height * 0.22
            let bottom = viewport.minY - app.frame.minY + viewport.height * 0.78
            let start = origin.withOffset(CGVector(dx: x, dy: towardEnd ? bottom : top))
            let end = origin.withOffset(CGVector(dx: x, dy: towardEnd ? top : bottom))
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        func leadingRows(_ viewport: CGRect, descending: Bool) -> [UInt32] {
            var before = visibleRows(in: viewport)
            for _ in 0..<5 {
                scrollDirectory(viewport, towardEnd: false)
                let after = visibleRows(in: viewport)
                if before == after { break }
                before = after
            }
            XCTAssertGreaterThanOrEqual(before.count, 2, "Two actual fully visible directory rows are required")
            XCTAssertTrue(zip(before, before.dropFirst()).allSatisfy { descending ? $0.0 > $0.1 : $0.0 < $0.1 })
            return before
        }

        app.launch()
        XCTAssertTrue(shelf.waitForExistence(timeout: 20))
        XCTAssertLessThanOrEqual(app.frame.height, 750, "Select a short phone simulator; this receipt records its actual app window")
        let existing = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'book-'"))
        XCTAssertTrue(existing.allElementsBoundByIndex.allSatisfy { $0.identifier == bookID },
                      "Only the standalone Gutenberg simulator fixture is allowed")
        let geometry = XCTAttachment(string: "simulator=\(simulator)\nos=\(UIDevice.current.systemVersion)\nwindow=\(app.frame)\nbook=\(bookID)")
        geometry.name = "compact-TXT-actual-window-and-book"
        geometry.lifetime = .keepAlways
        add(geometry)
        if !book.exists {
            shelf.tap()
            app.buttons["import-book"].tap()
            let files = app.cells.containing(NSPredicate(format: "label == 'pg25332.txt' OR label == 'pg25332'"))
            if !files.firstMatch.waitForExistence(timeout: 3) {
                let folder = app.cells.matching(NSPredicate(
                    format: "identifier == 'Reader, Container' OR label BEGINSWITH 'Reader,'")).firstMatch
                XCTAssertTrue(folder.waitForExistence(timeout: 10))
                folder.tap()
            }
            XCTAssertTrue(files.firstMatch.waitForExistence(timeout: 10))
            XCTAssertEqual(files.count, 1)
            files.element.tap()
            let open = app.buttons.matching(NSPredicate(format: "label == '打开' OR label == 'Open'")).firstMatch
            if open.waitForExistence(timeout: 2) { open.tap() }
            let result = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '已导入书架'")).firstMatch
            XCTAssertTrue(result.waitForExistence(timeout: 45))
            app.buttons["关闭导入结果"].tap()
        }
        openBook()

        showDirectory()
        let initial = try currentChapter()
        let initialRow = app.buttons["chapter-\(initial)"]
        waitUntil("The exact current chapter is initially selected") { initialRow.isSelected }
        let directory = try directoryViewport()
        let ascending = leadingRows(directory, descending: false)
        capture("compact-TXT-ascending-visible-rows")

        let descendingButton = app.buttons["倒序"]
        XCTAssertTrue(descendingButton.isHittable)
        descendingButton.tap()
        waitUntil("The native directory order becomes descending") {
            let rows = visibleRows(in: directory)
            return app.buttons["正序"].isHittable && rows.count >= 2
                && zip(rows, rows.dropFirst()).allSatisfy { $0.0 > $0.1 }
        }
        let descending = leadingRows(directory, descending: true)
        capture("compact-TXT-descending-visible-rows")

        let last = app.buttons["chapter-\(descending[0])"]
        XCTAssertTrue(last.isHittable)
        last.tap()
        waitUntil("The last directory chapter becomes the actual chapter") {
            app.staticTexts[chapterPrefix + String(descending[0])].exists
        }
        showHome()
        let previous = app.buttons["上一章"], next = app.buttons["下一章"]
        XCTAssertTrue(previous.isHittable && previous.isEnabled && next.exists && !next.isEnabled)
        previous.tap()
        waitUntil("Previous moves to the adjacent original chapter") {
            app.staticTexts[chapterPrefix + String(descending[1])].exists
        }

        showDirectory()
        XCTAssertTrue(query.isHittable)
        query.tap()
        query.typeText("readerverificationnomatch")
        XCTAssertTrue(app.staticTexts["没有符合条件的章节"].waitForExistence(timeout: 8))
        capture("compact-TXT-directory-no-matches")
        let locate = app.buttons["locate-current-chapter"]
        XCTAssertTrue(locate.isHittable)
        locate.tap()
        let selected = app.buttons["chapter-\(descending[1])"]
        waitUntil("Locate clears the filter and brings its actual current row back") {
            let value = query.value as? String
            return (value == nil || value == "" || value == query.placeholderValue)
                && selected.isSelected && selected.isHittable
        }
        capture("compact-TXT-located-current-chapter")

        dismissControls()
        waitUntil("Leaving the directory releases its keyboard") { !app.keyboards.firstMatch.exists }
        showDirectory()
        let firstViewport = try directoryViewport()
        let ascendingButton = app.buttons["正序"]
        XCTAssertTrue(ascendingButton.isHittable)
        ascendingButton.tap()
        let firstRows = leadingRows(firstViewport, descending: false)
        XCTAssertEqual(firstRows.prefix(2), ascending.prefix(2), "Both native observations agree on the leading chapters")
        let first = app.buttons["chapter-\(firstRows[0])"]
        XCTAssertTrue(first.isHittable)
        first.tap()
        waitUntil("The first directory chapter becomes the actual chapter") {
            app.staticTexts[chapterPrefix + String(firstRows[0])].exists
        }
        showHome()
        XCTAssertTrue(previous.exists && !previous.isEnabled && next.isHittable && next.isEnabled)
        next.tap()
        let readingChapter = chapterPrefix + String(firstRows[1])
        waitUntil("Next moves to the adjacent original chapter") { app.staticTexts[readingChapter].exists }
        dismissControls()

        let languages = ["zh-Hant", "en-US"]
        let beforeControlMotion = try renderedAnchor(in: body, app: app, languages: languages)
        let beforeControlProgress = progress.label
        showDirectory()
        let motionViewport = try directoryViewport()
        let beforeScroll = visibleRows(in: motionViewport)
        scrollDirectory(motionViewport, towardEnd: true)
        waitUntil("A vertical gesture scrolls the directory's own visible rows") {
            let rows = visibleRows(in: motionViewport)
            return !rows.isEmpty && rows != beforeScroll
        }
        dragControls(app, by: 90)
        waitForControls(app, labelPrefix: "快捷控制栏")
        dragControls(app, by: -90)
        waitForControls(app, labelPrefix: "完整控制栏")
        XCTAssertEqual(try currentChapter(), firstRows[1])
        dismissControls()
        XCTAssertEqual(try renderedAnchor(in: body, app: app, languages: languages), beforeControlMotion)
        XCTAssertEqual(progress.label, beforeControlProgress)
        body.swipeLeft()
        waitUntil("The real body gesture advances the visible reading position") { progress.label != beforeControlProgress }
        let expectedAnchor = try renderedAnchor(in: body, app: app, languages: languages)
        let expectedProgress = progress.label
        XCTAssertNotEqual(expectedAnchor, beforeControlMotion)
        capture("compact-TXT-before-process-exit")

        showHome()
        XCTAssertTrue(app.staticTexts[readingChapter].exists)
        app.buttons["leave-reader"].tap()
        XCTAssertTrue(shelf.waitForExistence(timeout: 15))
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        app.launch()
        openBook()
        waitUntil("Restored visible position in a new App process") {
            progress.label == expectedProgress && body.isHittable
        }
        XCTAssertEqual(try renderedAnchor(in: body, app: app, languages: languages), expectedAnchor)
        capture("compact-TXT-after-process-cold-reopen")
        showHome()
        XCTAssertTrue(app.staticTexts[readingChapter].exists)
        app.buttons["leave-reader"].tap()
        XCTAssertTrue(shelf.waitForExistence(timeout: 15))
        completed = true
    }

    /// Run against the installed ordinary App using destination artifacts.
    /// Expected progress and prose come from the pre-install evidence.
    func testOrdinaryAppColdContinuePreservesExistingGutenbergAnchor() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("This verification uses the dedicated compact iPhone simulator")
        #endif
        let environment = ProcessInfo.processInfo.environment
        let simulator = "Reader-iPhone-Daily-Closeout-20261123"
        XCTAssertEqual(environment["SIMULATOR_DEVICE_NAME"], simulator)
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .phone)
        executionTimeAllowance = 90

        func normalized(_ value: String) -> String {
            let folded = value.folding(options: [.widthInsensitive], locale: Locale(identifier: "zh-Hant"))
            return String(String.UnicodeScalarView(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
        }
        let expectedPassage = normalized(try XCTUnwrap(environment["READER_ORDINARY_EXPECTED_ANCHOR"],
            "Require the old prose witness taken independently of this launch"))
        XCTAssertGreaterThanOrEqual(expectedPassage.count, 18)
        let expectedProgress = try XCTUnwrap(environment["READER_ORDINARY_EXPECTED_PROGRESS"],
            "Require the independently recorded, nonzero reading footer value")
        XCTAssertTrue(expectedProgress.hasSuffix("%"))
        let percent = try XCTUnwrap(Int(expectedProgress.dropLast()))
        XCTAssertTrue((1...99).contains(percent))

        let app = XCUIApplication(bundleIdentifier: "io.reader.minliny")
        let bookID = "local:997442c1d041cc731d57bd164078a1dd6e98a5fe0eb9b6ec8b202edc3d0a5a38"
        let shelf = app.buttons["更多书架操作"]
        let book = app.buttons["book-" + bookID]
        let card = app.buttons["shelf-continue-card"]
        let body = app.textViews["reading-body"]
        let progress = app.staticTexts["reading-progress"]
        if app.state != .notRunning { app.terminate() }
        XCTAssertEqual(app.state, .notRunning)
        app.launch()
        XCTAssertTrue(shelf.waitForExistence(timeout: 20))
        XCTAssertTrue(book.waitForExistence(timeout: 15), "Shelf must retain the original by its SHA identity")
        XCTAssertTrue(card.waitForExistence(timeout: 15) && card.isHittable)
        XCTAssertEqual(card.label, "继续阅读，pg25332")
        let shelfEvidence = XCTAttachment(screenshot: app.screenshot())
        shelfEvidence.name = "ordinary-app-cold-shelf-with-original"
        shelfEvidence.lifetime = .keepAlways
        add(shelfEvidence)

        card.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 20))
        let correctProgress = expectation(for: NSPredicate(format: "label == %@", expectedProgress), evaluatedWith: progress)
        wait(for: [correctProgress], timeout: 10)
        let observed = try renderedAnchor(in: body, app: app, languages: ["zh-Hant", "en-US"], characterLimit: 256)
        let anchorEvidence = XCTAttachment(string: "book=local|\(bookID)\nchapter=1\nprogress=\(progress.label)"
            + "\nexpectedPassage=\(expectedPassage)\nrecognizedViewport=\(observed)")
        anchorEvidence.name = "ordinary-app-existing-anchor-and-progress"
        anchorEvidence.lifetime = .keepAlways
        add(anchorEvidence)
        let bodyEvidence = XCTAttachment(screenshot: app.screenshot())
        bodyEvidence.name = "ordinary-app-cold-existing-anchor"
        bodyEvidence.lifetime = .keepAlways
        add(bodyEvidence)
        XCTAssertTrue(normalized(observed).contains(expectedPassage), "The old passage must already be visible without scrolling")

        body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        let identity = app.staticTexts["reading-book:local|" + bookID]
        let chapter = app.staticTexts["reading-chapter:1"]
        XCTAssertTrue(identity.waitForExistence(timeout: 10))
        XCTAssertTrue(chapter.waitForExistence(timeout: 5))
        let headingEvidence = XCTAttachment(screenshot: app.screenshot())
        headingEvidence.name = "ordinary-app-existing-book-and-chapter"
        headingEvidence.lifetime = .keepAlways
        add(headingEvidence)
        let leave = app.buttons["leave-reader"]
        XCTAssertTrue(leave.isHittable)
        leave.tap()
        XCTAssertTrue(shelf.waitForExistence(timeout: 15))
    }

    /// OCR reads the actual native viewport, independent of model offsets and
    /// progress labels. Retain screenshot evidence separately from this check.
    private func renderedAnchor(in body: XCUIElement, app: XCUIApplication,
                                languages: [String] = ["zh-Hans", "en-US"], characterLimit: Int = 64) throws -> String {
        let screenshot = app.screenshot().image
        let source = try XCTUnwrap(screenshot.cgImage)
        let window = app.frame
        let scaleX = CGFloat(source.width) / window.width
        let scaleY = CGFloat(source.height) / window.height
        let frame = body.frame.intersection(window).insetBy(dx: 6, dy: 6)
        let rect = CGRect(x: (frame.minX - window.minX) * scaleX,
                          y: (frame.minY - window.minY) * scaleY,
                          width: frame.width * scaleX, height: frame.height * scaleY).integral
        let image = try XCTUnwrap(source.cropping(to: rect))
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        let observations = (request.results ?? []).sorted {
            if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.01 { return $0.boundingBox.midY > $1.boundingBox.midY }
            return $0.boundingBox.minX < $1.boundingBox.minX
        }
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        // Ignore the viewport's partially clipped first line. Real chapters
        // contain short dialogue and ellipsis-only paragraphs, so consume a
        // bounded span of the actual visible lines rather than exactly two.
        XCTAssertGreaterThanOrEqual(lines.count, 4, "No attributable native text anchor")
        let anchor = String(lines.dropFirst().joined(separator: "\n").prefix(characterLimit))
        XCTAssertGreaterThan(anchor.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.count, 15)
        return anchor
    }

    private func dragControls(_ app: XCUIApplication, by distance: CGFloat) {
        let start = app.buttons["control-grabber"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
    }

    private func waitForControls(_ app: XCUIApplication, labelPrefix: String) {
        let reached = expectation(for: NSPredicate(format: "label BEGINSWITH %@", labelPrefix),
                                  evaluatedWith: app.buttons["control-grabber"])
        wait(for: [reached], timeout: 5)
    }
}
