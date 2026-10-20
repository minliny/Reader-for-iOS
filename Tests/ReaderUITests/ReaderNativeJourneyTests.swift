import XCTest

final class ReaderNativeJourneyTests: XCTestCase {
    // Provision the user's original Downloads file in this simulator's Documents
    // before running. This test never generates or substitutes book contents.
    private let bookName = "仙子请听我解释"
    override func setUpWithError() throws { continueAfterFailure = false }

    func testOrdinaryPageNavigationAndAppAppearance() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 15))
        app.buttons["设置"].tap()
        XCTAssertTrue(app.switches["夜间模式"].waitForExistence(timeout: 5))
        let appearance = app.switches["夜间模式"]
        let previous = appearance.value as? String
        let nativeSwitch = appearance.switches.firstMatch
        XCTAssertTrue(nativeSwitch.exists)
        nativeSwitch.tap()
        let changed = expectation(for: NSPredicate(format: "value != %@", previous ?? ""), evaluatedWith: appearance)
        wait(for: [changed], timeout: 5)
        let expected = appearance.value as? String
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
        XCTAssertTrue(cell.waitForExistence(timeout: 15) || cellWithExtension.waitForExistence(timeout: 5), app.debugDescription)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "native-picker-hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        if cell.exists { cell.tap() } else { cellWithExtension.tap() }
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
        body.swipeUp()
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        let chapterProgressed = expectation(for: NSPredicate(format: "label != '0%'"), evaluatedWith: progress)
        wait(for: [chapterProgressed], timeout: 10)
        let expectedChapterProgress = progress.label
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        XCTAssertEqual(progress.label, expectedChapterProgress)
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        app.buttons["leave-reader"].tap()
        XCTAssertTrue(book.waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(book.waitForExistence(timeout: 15))
        book.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 15))
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
        app.buttons["收起阅读控制"].tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        let reachedEnd = expectation(for: NSPredicate(format: "label == '100%'"), evaluatedWith: progress)
        wait(for: [reachedEnd], timeout: 10)
        XCTAssertLessThan(body.frame.maxY, progress.frame.minY)
        let end = XCTAttachment(screenshot: app.screenshot()); end.name = "real-book-chapter-end"; end.lifetime = .keepAlways; add(end)
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
