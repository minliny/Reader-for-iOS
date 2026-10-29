import XCTest
import UIKit
import Vision

/// Select explicitly after the required original books have been imported by
/// the real system picker. These methods never call Runtime or inject book data.
final class ReaderDailyJourneyTests: XCTestCase {
    private let firstID = "book-local:aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5"
    private let secondID = "book-local:ebe4b6535def1853e2d4d039f14981035fbfba8dcd6864fa6d0ecb2174e23952"
    private let firstTitle = "仙子请听我解释"
    private let secondTitle = "湛蓝权杖"
    private enum Prerequisite: Error { case removalOwnershipMissing }

    override func setUpWithError() throws { continueAfterFailure = false }

    /// Existing-book continuation only. This does not complete the two-TXT
    /// journey, create bookmarks, change preferences or move either position.
    func testExistingRealTXTAndEPUBAlternateAndColdReopenPreserveIndependentVisibleAnchors() throws {
        executionTimeAllowance = 240
        let app = XCUIApplication()
        let epubID = "book-local:5d6d9dd26bbea9ed0db4e4f7a127a538dfe439f5694c3370a30ac33503db9d67"
        app.launch()
        assertContinuationShelf(app)

        openContinuationBook(firstID, title: firstTitle, ebook: false, app: app)
        let txt = try captureContinuation(firstID, ebook: false, app: app, name: "txt-original-position")
        leaveContinuation(ebook: false, app: app)
        openContinuationBook(epubID, title: "终宋", ebook: true, app: app)
        let epub = try captureContinuation(epubID, ebook: true, app: app, name: "epub-original-position")
        XCTAssertNotEqual(txt.passage, epub.passage, "The two original books require independent visible prose anchors")
        leaveContinuation(ebook: true, app: app)

        openContinuationBook(firstID, title: firstTitle, ebook: false, app: app)
        try assertContinuation(txt, ebook: false, app: app, name: "txt-after-alternating")
        leaveContinuation(ebook: false, app: app)
        app.terminate()
        app.launch()
        assertContinuationShelf(app)
        openContinuationBook(epubID, title: "终宋", ebook: true, app: app)
        try assertContinuation(epub, ebook: true, app: app, name: "epub-after-one-cold-reopen")
        leaveContinuation(ebook: true, app: app)
        openContinuationBook(firstID, title: firstTitle, ebook: false, app: app)
        try assertContinuation(txt, ebook: false, app: app, name: "txt-after-one-cold-reopen")
        leaveContinuation(ebook: false, app: app)
        assertContinuationShelf(app)
    }

    private struct ContinuationAnchor {
        let shelfID: String
        let chapterID: String
        let chapterLabel: String
        let passage: String
    }

    private func assertContinuationShelf(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.textFields["shelf-filter"].exists, "Retain the original closed shelf search")
        XCTAssertTrue(app.buttons["全部分组"].exists, "This narrow method requires the original all-groups shelf")
    }

    private func continuationBody(ebook: Bool, app: XCUIApplication) -> XCUIElement {
        ebook ? app.descendants(matching: .any).matching(identifier: "reading-ebook-body").firstMatch
            : app.textViews["reading-body"]
    }

    private func openContinuationBook(_ id: String, title: String, ebook: Bool, app: XCUIApplication) {
        assertContinuationShelf(app)
        filterShelf(title, app: app)
        let books = app.buttons.matching(identifier: id)
        XCTAssertTrue(books.firstMatch.waitForExistence(timeout: 15)); XCTAssertEqual(books.count, 1)
        XCTAssertTrue(books.firstMatch.isEnabled && books.firstMatch.isHittable); books.firstMatch.tap()
        let body = continuationBody(ebook: ebook, app: app)
        XCTAssertTrue(body.waitForExistence(timeout: 20))
        waitUntil("The exact existing book has a ready, unobscured native body", timeout: 20) {
            body.isHittable && !app.buttons["阅读控制"].exists && !app.buttons["control-grabber"].isHittable
        }
    }

    private func continuationHome(ebook: Bool, app: XCUIApplication) {
        let home = app.buttons["control-module-home"]
        if !home.isHittable {
            continuationBody(ebook: ebook, app: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        }
        XCTAssertTrue(home.waitForExistence(timeout: 5)); XCTAssertTrue(home.isHittable); home.tap()
    }

    private func continuationChapter(_ id: String, ebook: Bool, app: XCUIApplication, name: String) -> (String, String) {
        continuationHome(ebook: ebook, app: app)
        let bookID = "reading-book:local|" + String(id.dropFirst("book-".count))
        XCTAssertTrue(app.staticTexts[bookID].waitForExistence(timeout: 5), "The reading header must bind the exact original book")
        let chapters = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'reading-chapter:'"))
        XCTAssertEqual(chapters.count, 1)
        let chapter = chapters.firstMatch
        let result = (chapter.identifier, chapter.label)
        let binding = XCTAttachment(string: "book=\(bookID)\nchapter=\(result.0)\ntitle=\(result.1)\nscalar/bodyVersion/processingVersion=NOT_CAPTURED_BY_NATIVE_AX; no percent-to-scalar inference")
        binding.name = name + "-native-book-and-chapter"; binding.lifetime = .keepAlways; add(binding)
        hideControls(app)
        return result
    }

    private func captureContinuation(_ id: String, ebook: Bool, app: XCUIApplication, name: String) throws -> ContinuationAnchor {
        let chapter = continuationChapter(id, ebook: ebook, app: app, name: name)
        let lines = try ocr(app: app, wholeAppScreenshot: true)
        XCTAssertGreaterThanOrEqual(lines.count, 4, "A full native prose viewport is required")
        // Controls are hidden. A long actual OCR line excludes status-clock,
        // progress and short book/chapter labels without cropping live AX frames.
        let passage = try XCTUnwrap(lines.map(normalized).first(where: { $0.count >= 18 }))
        let anchor = String(passage.prefix(24))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
        let text = XCTAttachment(string: anchor)
        text.name = name + "-actual-native-prose-anchor"; text.lifetime = .keepAlways; add(text)
        return ContinuationAnchor(shelfID: id, chapterID: chapter.0, chapterLabel: chapter.1, passage: anchor)
    }

    private func assertContinuation(_ expected: ContinuationAnchor, ebook: Bool, app: XCUIApplication, name: String) throws {
        let chapter = continuationChapter(expected.shelfID, ebook: ebook, app: app, name: name)
        XCTAssertEqual(chapter.0, expected.chapterID); XCTAssertEqual(chapter.1, expected.chapterLabel)
        waitUntil("The same original visible prose must return: " + name, timeout: 15) {
            guard let lines = try? self.ocr(app: app, wholeAppScreenshot: true) else { return false }
            return self.normalized(lines.joined()).contains(expected.passage)
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    private func leaveContinuation(ebook: Bool, app: XCUIApplication) {
        continuationHome(ebook: ebook, app: app)
        let leave = app.buttons["leave-reader"]
        XCTAssertTrue(leave.isEnabled && leave.isHittable); leave.tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 20))
        clearShelfFilter(app)
        assertContinuationShelf(app)
    }

    func testATwoOriginalTXTBookmarksReflowAlternationAndColdVisibleAnchors() throws {
        let app = XCUIApplication()
        app.launch()
        openBook(firstID, title: firstTitle, app: app)
        chooseChapter(1, app: app)
        seekChapterStart(app)
        let firstPassage = try advanceAndCapture(app: app, name: "first-book-real-passage")
        let firstBookmark = try createBookmark(app: app)
        chooseChapter(2, app: app)
        try assertDifferentVisiblePassage(from: firstPassage, app: app, name: "first-book-left-original-bookmark-chapter")
        jumpBookmark(firstBookmark, app: app)
        try assertVisible(firstPassage, app: app, name: "first-book-original-bookmark-jump")
        let beforeReflow = try ocr(app: app).dropFirst().prefix(3).map(normalized)
        changeFontSize(app: app)
        try assertVisible(firstPassage, app: app, name: "first-book-visible-anchor-after-native-reflow")
        let afterReflow = try ocr(app: app).dropFirst().prefix(3).map(normalized)
        XCTAssertNotEqual(afterReflow, beforeReflow, "Real native text wrapping must change; a changed settings value alone is insufficient")
        let firstAnchor = try captureAnchor(app: app, name: "first-book-reflowed-anchor")
        XCUIDevice.shared.press(.home)
        app.activate()
        try assertVisible(firstAnchor, app: app, name: "first-book-after-real-background")
        leaveReader(app)

        openBook(secondID, title: secondTitle, app: app)
        chooseChapter(3, app: app)
        seekChapterStart(app)
        let secondAnchor = try advanceAndCapture(app: app, name: "second-book-different-real-passage")
        XCTAssertNotEqual(firstAnchor, secondAnchor, "Two real books must have distinguishable visible text anchors")
        let secondBookmark = try createBookmark(app: app)
        chooseChapter(4, app: app)
        try assertDifferentVisiblePassage(from: secondAnchor, app: app, name: "second-book-left-original-bookmark-chapter")
        jumpBookmark(secondBookmark, app: app)
        try assertVisible(secondAnchor, app: app, name: "second-book-original-bookmark-jump")
        XCUIDevice.shared.press(.home)
        app.activate()
        try assertVisible(secondAnchor, app: app, name: "second-book-after-real-background")
        leaveReader(app)

        openBook(firstID, title: firstTitle, app: app)
        try assertVisible(firstAnchor, app: app, name: "first-book-after-alternating-books")
        leaveReader(app)
        app.terminate()
        app.launch()
        openBook(secondID, title: secondTitle, app: app)
        try assertVisible(secondAnchor, app: app, name: "second-book-cold-visible-anchor")
        leaveReader(app)
        app.terminate()
        app.launch()
        openBook(firstID, title: firstTitle, app: app)
        try assertVisible(firstAnchor, app: app, name: "first-book-cold-visible-anchor")
        leaveReader(app)
    }

    /// Destructive tail: select only for the newly provisioned compact library,
    /// after testA. A selected method without its exact ownership proof FAILS.
    /// Root separately compares original/provisioned file hashes before/after;
    /// native picker visibility below is not a claim of byte preservation.
    func testBOriginalTXTFiltersLayoutGroupsSelectionAndExplicitlyOwnedRemoval() throws {
        let environment = ProcessInfo.processInfo.environment
        let ownedBook = String(secondID.dropFirst("book-".count))
        let ownedSimulator = environment["READER_DAILY_OWNED_SIMULATOR_UDID"] ?? ""
        guard environment["READER_DAILY_OWNED_BOOK_ID"] == ownedBook,
              !ownedSimulator.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              environment["SIMULATOR_UDID"] == ownedSimulator else {
            XCTFail("Removal requires Root's exact owned 湛蓝 test-copy ID and dedicated compact simulator; no existing library is eligible")
            throw Prerequisite.removalOwnershipMissing
        }
        let app = XCUIApplication()
        app.launch()
        openBook(firstID, title: firstTitle, app: app)
        let retainedAnchor = try captureAnchor(app: app, name: "retained-book-before-owned-removal")
        leaveReader(app)
        filterShelf(secondTitle, app: app)
        XCTAssertTrue(app.buttons[secondID].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons[firstID].exists, "The real title filter must exclude the other book")
        clearShelfFilter(app)
        switchShelfLayout(app)
        switchShelfLayout(app)
        if app.buttons["使用封面布局"].exists {
            app.buttons["使用封面布局"].tap()
            XCTAssertTrue(app.buttons["使用列表布局"].waitForExistence(timeout: 5))
        }

        let groupName = "日用原生旅程-" + String(UUID().uuidString.prefix(8))
        shelfMore("管理分组", app: app)
        let name = app.textFields["group-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText(String(groupName))
        app.buttons["创建"].tap()
        XCTAssertTrue(app.buttons[String(groupName)].waitForExistence(timeout: 10))
        app.buttons["关闭分组管理"].tap()
        XCTAssertTrue(app.buttons[secondID].waitForExistence(timeout: 10))
        app.buttons[secondID].press(forDuration: 1)
        XCTAssertTrue(app.buttons["书籍信息与分组"].waitForExistence(timeout: 5))
        app.buttons["书籍信息与分组"].tap()
        XCTAssertTrue(app.buttons[String(groupName)].waitForExistence(timeout: 10))
        app.buttons[String(groupName)].tap()
        app.buttons["关闭书籍信息"].tap()
        XCTAssertTrue(app.buttons["全部分组"].waitForExistence(timeout: 5))
        app.buttons["全部分组"].tap()
        app.buttons[String(groupName)].tap()
        waitUntil("The actual named group must contain only the assigned original", timeout: 15) {
            app.buttons[self.secondID].exists && !app.buttons[self.firstID].exists
        }
        app.buttons[String(groupName)].tap()
        app.buttons["全部分组"].tap()
        XCTAssertTrue(app.buttons[firstID].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[secondID].waitForExistence(timeout: 10))

        shelfMore("批量管理", app: app)
        app.buttons[firstID].tap(); app.buttons[secondID].tap()
        XCTAssertTrue(app.staticTexts["已选 2 本"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()
        XCTAssertFalse(app.staticTexts["已选 2 本"].exists)
        XCTAssertTrue(app.buttons[firstID].exists); XCTAssertTrue(app.buttons[secondID].exists)
        shelfMore("批量管理", app: app)
        app.buttons[secondID].tap()
        XCTAssertTrue(app.staticTexts["已选 1 本"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[firstID].isSelected)
        XCTAssertTrue(app.buttons[secondID].isSelected)
        app.buttons["移除"].tap()
        let confirmation = app.alerts["移出书架"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmation.staticTexts.matching(NSPredicate(format: "label CONTAINS '所选 1 本'")).firstMatch.exists)
        confirmation.buttons["移除"].tap()
        waitUntil("Only the explicitly owned original is removed", timeout: 20) {
            !app.buttons[self.secondID].exists && app.buttons[self.firstID].exists
        }
        if app.buttons["取消"].exists { app.buttons["取消"].tap() }
        app.terminate(); app.launch()
        openBook(firstID, title: firstTitle, app: app)
        try assertVisible(retainedAnchor, app: app, name: "other-original-after-removal-and-cold-reopen")
        leaveReader(app)
        filterShelf(secondTitle, app: app)
        XCTAssertTrue(app.staticTexts["没有符合条件的书籍"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons[secondID].exists)
        clearShelfFilter(app)
        XCTAssertTrue(app.buttons[firstID].waitForExistence(timeout: 10))

        shelfMore("本地导入", app: app, identifier: "import-book")
        enterReaderDocumentsIfNeeded(app, filename: "仙子请听我解释.txt")
        for filename in ["仙子请听我解释.txt", "湛蓝权杖 (躺摆混) (Z-Library).txt"] {
            XCTAssertTrue(pickerFile(filename, app: app).waitForExistence(timeout: 10), app.debugDescription)
        }
        let inputEvidence = XCTAttachment(screenshot: app.screenshot())
        inputEvidence.name = "system-picker-both-original-inputs-still-visible-SHA-checked-separately"
        inputEvidence.lifetime = .keepAlways; add(inputEvidence)
        let cancel = app.navigationBars.buttons["取消"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5)); cancel.tap()
        XCTAssertTrue(app.buttons[firstID].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons[secondID].exists, "Picker inspection must not reimport the removed test copy")
    }

    private func openBook(_ id: String, title: String, app: XCUIApplication) {
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 20), app.debugDescription)
        filterShelf(title, app: app)
        let book = app.buttons[id]
        XCTAssertTrue(book.waitForExistence(timeout: 15), "The original picker-imported book is required: " + id)
        XCTAssertTrue(book.isHittable); book.tap()
        XCTAssertTrue(app.textViews["reading-body"].waitForExistence(timeout: 20))
    }

    private func filterShelf(_ title: String, app: XCUIApplication) {
        if !app.textFields["shelf-filter"].exists { app.buttons["搜索本地书架"].tap() }
        let field = app.textFields["shelf-filter"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); replace(field, text: title)
    }

    private func clearShelfFilter(_ app: XCUIApplication) {
        if app.textFields["shelf-filter"].exists { app.buttons["搜索本地书架"].tap() }
    }

    private func replace(_ field: XCUIElement, text: String) {
        field.tap()
        let old = field.value as? String ?? ""
        let placeholder = field.placeholderValue ?? ""
        if old != placeholder { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }
        field.typeText(text + "\n")
    }

    private func openModule(_ module: String, app: XCUIApplication) {
        if !app.buttons["control-module-" + module].isHittable {
            // Deliberately retain the real tap contract. Do not bypass a native
            // reading-body gesture failure through an alternate test route.
            app.textViews["reading-body"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        }
        let button = app.buttons["control-module-" + module]
        XCTAssertTrue(button.waitForExistence(timeout: 5), app.debugDescription); button.tap()
        if module == "home" { return }
        let grabber = app.buttons["control-grabber"]
        if !grabber.label.hasPrefix("完整控制栏") { grabber.tap() }
        waitUntil("Full native reading controls", timeout: 5) { grabber.label.hasPrefix("完整控制栏") }
    }

    private func hideControls(_ app: XCUIApplication) {
        let hide = app.buttons["收起阅读控制"]
        XCTAssertTrue(hide.waitForExistence(timeout: 5)); hide.tap()
        waitUntil("Reading controls dismissed", timeout: 5) { !app.buttons["control-grabber"].isHittable }
    }

    private func chooseChapter(_ index: Int, app: XCUIApplication) {
        openModule("directory", app: app)
        let directory = app.buttons.matching(NSPredicate(format: "label == '目录' AND identifier != 'control-module-directory'")).firstMatch
        XCTAssertTrue(directory.waitForExistence(timeout: 5)); directory.tap()
        let chapter = app.buttons["chapter-\(index)"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 10), app.debugDescription); chapter.tap()
        waitUntil("Actual selected canonical chapter \(index)", timeout: 15) { chapter.isSelected }
        hideControls(app)
    }

    private func seekChapterStart(_ app: XCUIApplication) {
        // A previous native journey may have left this chapter at its end.
        // Exercise the existing visible slider before the next real page turn.
        openModule("home", app: app)
        let slider = app.sliders["chapter-progress"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5)); slider.adjust(toNormalizedSliderPosition: 0)
        let adjusted = slider.normalizedSliderPosition
        let input = XCTAttachment(string: "XCTest best-effort chapter-start normalized position=\(adjusted); actual AX value=\(String(describing: slider.value))")
        input.name = "actual-chapter-start-slider-input"; input.lifetime = .keepAlways; add(input)
        if adjusted != 0 {
            let center = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let beyondStart = slider.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
                .withOffset(CGVector(dx: -12, dy: 0))
            center.press(forDuration: 0.1, thenDragTo: beyondStart)
        }
        XCTAssertEqual(slider.normalizedSliderPosition, 0,
            "The actual native slider must reach zero before checking the chapter start. " + app.debugDescription)
        hideControls(app)
        let progress = app.staticTexts["reading-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        waitUntil("The selected chapter must actually display its start before advancing", timeout: 15) {
            progress.label == "0%"
        }
    }

    private func createBookmark(app: XCUIApplication) throws -> String {
        openModule("directory", app: app)
        app.buttons["directory-bookmarks"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bookmark-'"))
        XCTAssertTrue(app.buttons["add-bookmark"].waitForExistence(timeout: 10))
        waitUntil("The original bookmark list has actually loaded", timeout: 10) {
            !app.staticTexts["正在读取书签"].exists &&
                (app.staticTexts["暂无书签"].exists || rows.count > 0)
        }
        let before = Set(rows.allElementsBoundByIndex.map(\.identifier))
        app.buttons["add-bookmark"].tap()
        waitUntil("One new actual Core bookmark must appear", timeout: 15) {
            Set(rows.allElementsBoundByIndex.map(\.identifier)).subtracting(before).count == 1
        }
        let id = try XCTUnwrap(Set(rows.allElementsBoundByIndex.map(\.identifier)).subtracting(before).first)
        hideControls(app)
        return id
    }

    private func jumpBookmark(_ id: String, app: XCUIApplication) {
        openModule("directory", app: app); app.buttons["directory-bookmarks"].tap()
        XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 10)); app.buttons[id].tap()
        hideControls(app)
    }

    private func changeFontSize(app: XCUIApplication) {
        openModule("appearance", app: app)
        let metric = app.steppers["reading-font-size"]
        let scroll = app.scrollViews.containing(.stepper, identifier: "reading-font-size").firstMatch
        for _ in 0..<8 where !metric.isHittable { scroll.swipeUp() }
        XCTAssertTrue(metric.isHittable, app.debugDescription)
        func fontSize() -> Int? {
            let description = (metric.value as? String ?? "") + " " + metric.label
            let numbers = Set(description.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init))
            guard numbers.count == 1, let value = numbers.first, (12...40).contains(value) else { return nil }
            return value
        }
        guard let before = fontSize() else { XCTFail("The native font stepper must expose its actual numeric value. " + app.debugDescription); return }
        let increasing = before < 40
        let action = metric.buttons.matching(NSPredicate(format: increasing
            ? "label CONTAINS[c] 'increment' OR label CONTAINS[c] 'increase' OR label CONTAINS '增加' OR label CONTAINS '递增'"
            : "label CONTAINS[c] 'decrement' OR label CONTAINS[c] 'decrease' OR label CONTAINS '减少' OR label CONTAINS '递减'")).firstMatch
        let hierarchy = XCTAttachment(string: "Actual font=\(before), stepperFrame=\(metric.frame), increasing=\(increasing).\n" + app.debugDescription)
        hierarchy.name = "actual-native-font-stepper-before-action"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        if action.exists {
            XCTAssertTrue(action.isEnabled && action.isHittable, app.debugDescription); action.tap()
        } else {
            let buttons = metric.buttons.allElementsBoundByIndex.sorted { $0.frame.midX < $1.frame.midX }
            if buttons.count == 2 {
                let target = increasing ? buttons[1] : buttons[0]
                XCTAssertTrue(target.isEnabled && target.isHittable, app.debugDescription); target.tap()
            } else {
                // The retained compact recording shows the native minus/plus
                // pair at the trailing edge: each segment is about 44pt wide.
                // Some SwiftUI versions expose only the grouped Stepper. Tap
                // its actual plus/minus segment; never assign a settings value.
                let frame = metric.frame
                XCTAssertGreaterThanOrEqual(frame.width, 88, app.debugDescription)
                XCTAssertTrue(app.frame.contains(frame), app.debugDescription)
                metric.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
                    .withOffset(CGVector(dx: increasing ? -22 : -66, dy: 0)).tap()
            }
        }
        let expected = before + (increasing ? 1 : -1)
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in fontSize() == expected }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed,
            "The real font stepper must change by one to \(expected). " + app.debugDescription)
        hideControls(app)
    }

    private func leaveReader(_ app: XCUIApplication) {
        openModule("home", app: app)
        app.buttons["leave-reader"].tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 20))
    }

    private func shelfMore(_ label: String, app: XCUIApplication, identifier: String? = nil) {
        app.buttons["更多书架操作"].tap()
        let action = app.buttons[identifier ?? label]
        XCTAssertTrue(action.waitForExistence(timeout: 5)); action.tap()
    }

    private func switchShelfLayout(_ app: XCUIApplication) {
        let toCover = app.buttons["使用封面布局"]
        let action = toCover.exists ? toCover : app.buttons["使用列表布局"]
        let expected = toCover.exists ? "使用列表布局" : "使用封面布局"
        XCTAssertTrue(action.isHittable); action.tap()
        XCTAssertTrue(app.buttons[expected].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[firstID].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[secondID].waitForExistence(timeout: 10))
    }

    private func advanceAndCapture(app: XCUIApplication, name: String) throws -> String {
        let before = try captureAnchor(app: app, name: name + "-before")
        app.textViews["reading-body"].swipeLeft()
        waitUntil("A real page turn changes visible native text", timeout: 10) {
            guard let text = try? self.ocr(app: app), text.count >= 4 else { return false }
            return !self.normalized(text.joined()).contains(before)
        }
        return try captureAnchor(app: app, name: name)
    }

    private func assertDifferentVisiblePassage(from original: String, app: XCUIApplication, name: String) throws {
        waitUntil("A different selected chapter must show different real text before jumping to the bookmark", timeout: 15) {
            guard let text = try? self.ocr(app: app), text.count >= 4 else { return false }
            return !self.normalized(text.joined()).contains(original)
        }
        XCTAssertNotEqual(try captureAnchor(app: app, name: name), original)
    }

    private func captureAnchor(app: XCUIApplication, name: String) throws -> String {
        let lines = try ocr(app: app)
        XCTAssertGreaterThanOrEqual(lines.count, 4, "A clipped/empty viewport is not a reading anchor")
        // The real second book contains short bracketed paragraphs and an
        // ellipsis. Two OCR lines can contain fewer than 18 letters even when
        // the actual viewport is full. Keep the same 24/18-character contract
        // and consume the contiguous visible text across real line wraps.
        let anchor = String(normalized(lines.dropFirst().joined()).prefix(24))
        XCTAssertGreaterThanOrEqual(anchor.count, 18)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
        let evidence = XCTAttachment(string: anchor)
        evidence.name = name + "-actual-native-OCR"; evidence.lifetime = .keepAlways; add(evidence)
        return anchor
    }

    private func assertVisible(_ anchor: String, app: XCUIApplication, name: String) throws {
        XCTAssertTrue(app.textViews["reading-body"].waitForExistence(timeout: 20))
        waitUntil("Original visible passage must be restored: " + name, timeout: 15) {
            guard let text = try? self.ocr(app: app) else { return false }
            return self.normalized(text.joined()).contains(anchor)
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    private func normalized(_ value: String) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }

    private func ocr(app: XCUIApplication, wholeAppScreenshot: Bool = false) throws -> [String] {
        let source = try XCTUnwrap(app.screenshot().image.cgImage)
        let image: CGImage
        if wholeAppScreenshot { image = source }
        else {
            let body = app.textViews["reading-body"]
            let window = app.frame
            let frame = body.frame.intersection(window).insetBy(dx: 6, dy: 6)
            let rect = CGRect(x: (frame.minX - window.minX) * CGFloat(source.width) / window.width,
                y: (frame.minY - window.minY) * CGFloat(source.height) / window.height,
                width: frame.width * CGFloat(source.width) / window.width,
                height: frame.height * CGFloat(source.height) / window.height).integral
            image = try XCTUnwrap(source.cropping(to: rect))
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate; request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).sorted {
            abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.01
                ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
        }.compactMap { $0.topCandidates(1).first?.string }
    }

    private func waitUntil(_ fact: String, timeout: TimeInterval, _ condition: @escaping () -> Bool) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: timeout), .completed, fact)
    }

    private func pickerFile(_ filename: String, app: XCUIApplication) -> XCUIElement {
        let basename = (filename as NSString).deletingPathExtension
        return app.cells.containing(NSPredicate(format: "label == %@ OR label == %@", filename, basename)).firstMatch
    }

    private func enterReaderDocumentsIfNeeded(_ app: XCUIApplication, filename: String) {
        if pickerFile(filename, app: app).waitForExistence(timeout: 3) { return }
        let folder = app.cells.matching(NSPredicate(format: "identifier == 'Reader, Container' OR label BEGINSWITH 'Reader,'")).firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 10), app.debugDescription); folder.tap()
    }
}
