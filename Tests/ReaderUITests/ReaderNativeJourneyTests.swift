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

    /// OCR reads the actual native viewport, independent of model offsets and
    /// progress labels. Retain screenshot evidence separately from this check.
    private func renderedAnchor(in body: XCUIElement, app: XCUIApplication) throws -> String {
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
        request.recognitionLanguages = ["zh-Hans", "en-US"]
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
        let anchor = String(lines.dropFirst().joined(separator: "\n").prefix(64))
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
