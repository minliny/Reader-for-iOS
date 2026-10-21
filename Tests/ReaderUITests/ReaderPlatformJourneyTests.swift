import UIKit
import Vision
import XCTest
import CoreImage
import ImageIO

/// Select on an explicitly owned iPad simulator after the real system picker
/// has imported this unchanged Downloads original. No Runtime call, launch
/// argument, generated content or simulated window geometry participates.
final class ReaderPlatformJourneyTests: XCTestCase {
    private let originalBookID = "book-local:aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5"
    private enum Prerequisite: Error { case iPadRequired, invalidViewport, maximumContentSizeRequired }
    private var lastOCRGeometry = ""
    private var lastOCRLines: [String] = []
    private var lastOCRImage: UIImage?

    override func setUpWithError() throws { continueAfterFailure = false }

    func testIPadPortraitLandscapeRetainsOriginalTXTAnchorAndDirectoryWithinWindow() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            XCTFail("Select the explicitly provisioned iPad; a phone run cannot prove this platform baseline")
            throw Prerequisite.iPadRequired
        }
        let device = XCUIDevice.shared
        let originalOrientation = device.orientation
        // A newly provisioned owned simulator can have no initial sensor
        // orientation. Establish a real portrait baseline in that case; never
        // report it as an observed original direction.
        let cleanupOrientation: UIDeviceOrientation = originalOrientation.isValidInterfaceOrientation
            ? originalOrientation : .portrait
        let app = XCUIApplication()
        let initialAppFrame = app.state == .runningForeground ? app.frame : .zero
        var completedJourney = false
        #if DEBUG
        app.launchEnvironment["READER_DEBUG_ORIENTATION_SAMPLES"] = "1"
        #endif
        app.launch()
        // Registered first so this runs after the original direction/window
        // cleanup, including when a fail-fast assertion aborts the method.
        // Only this App instance was launched with the diagnostic opt-in.
        addTeardownBlock {
            if !completedJourney && app.state != .notRunning { app.terminate() }
        }
        // XCTest runs teardown blocks even when a fail-fast assertion aborts
        // the test body. A sensor setter alone is not window restoration.
        addTeardownBlock {
            if app.state != .runningForeground { app.activate() }
            self.establishOrientationInput(app, desired: cleanupOrientation, stage: "cleanup")
        }

        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 20))
        // Request only after the new App scene is active. Requesting against
        // the previous reading process immediately before launch terminates it
        // can leave the new scene in its persisted landscape orientation.
        establishOrientationInput(app, desired: .portrait, stage: "initial-portrait")
        let baseline = XCTAttachment(string: "initialOrientationGetterRawValue=\(originalOrientation.rawValue); originalDirectionKnown=\(originalOrientation.isValidInterfaceOrientation); initialForegroundAppFrame=\(initialAppFrame); requestedBaseline=portrait-after-new-App-shelf-ready; actualAppFrame=\(app.frame); cleanupDirectionRawValue=\(cleanupOrientation.rawValue); cleanupChecksActualWindowClass=true; readerDirectionPreferenceUnchanged=true")
        baseline.name = "ipad-real-orientation-baseline"; baseline.lifetime = .keepAlways; add(baseline)
        if !app.textFields["shelf-filter"].exists { app.buttons["搜索本地书架"].tap() }
        let filter = app.textFields["shelf-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        replace(filter, text: "仙子请听我解释")
        let book = app.buttons[originalBookID]
        XCTAssertTrue(book.waitForExistence(timeout: 15), "The exact real picker-imported original is required; this method does not create a library")
        XCTAssertTrue(book.isHittable); book.tap()
        XCTAssertTrue(app.textViews["reading-body"].waitForExistence(timeout: 20))

        // The untouched original's first actual prose chapter is 第一章 深山古庙.
        // Its preceding short 序章 cannot provide a meaningful reflow anchor.
        showDirectory(app)
        let query = app.textFields["directory-query"]
        replace(query, text: "深山古庙")
        let firstChapter = app.buttons["chapter-1"]
        XCTAssertTrue(firstChapter.waitForExistence(timeout: 15))
        XCTAssertTrue(firstChapter.label.contains("深山古庙"))
        XCTAssertTrue(firstChapter.isHittable); firstChapter.tap()
        waitUntil("The exact original chapter is selected", timeout: 15) { firstChapter.isSelected }
        let chapterStart = app.buttons["章首"]
        XCTAssertTrue(chapterStart.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(chapterStart.isHittable, app.debugDescription); chapterStart.tap()
        hideControls(app)
        waitUntil("The real first prose page must settle before measuring rotation", timeout: 15) {
            app.staticTexts["reading-progress"].label == "0%"
        }
        let anchor = try captureAnchor(app, name: "ipad-portrait-original-TXT-anchor")
        assertReadingWithinWindow(app)
        assertDirectoryWithinWindow(app, name: "ipad-portrait-directory")

        let input = XCTAttachment(string: "stage=reading-landscape-before-input; uptime=\(ProcessInfo.processInfo.systemUptime); actualSensorOrientation=\(device.orientation.rawValue); appState=\(app.state.rawValue); actualAppFrame=\(app.frame); \(fullScreenOrientationEvidence(stage: "reading-landscape-before-input"))")
        input.name = "ipad-orientation-reading-landscape-before-input"; input.lifetime = .keepAlways; add(input)
        device.orientation = .landscapeLeft
        waitForOrientation(app, landscape: true, stage: "reading-landscape")
        try assertVisible(anchor, app: app, name: "ipad-landscape-original-TXT-anchor")
        assertReadingWithinWindow(app)
        assertDirectoryWithinWindow(app, name: "ipad-landscape-directory")

        device.orientation = .portrait
        waitForOrientation(app, landscape: false, stage: "reading-returned-portrait")
        try assertVisible(anchor, app: app, name: "ipad-returned-portrait-original-TXT-anchor")
        assertReadingWithinWindow(app)
        assertDirectoryWithinWindow(app, name: "ipad-returned-portrait-directory")
        showModule("home", app: app)
        let leave = app.buttons["leave-reader"]
        XCTAssertTrue(leave.waitForExistence(timeout: 5)); leave.tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 20))
        completedJourney = true
    }

    /// The delivery owner sets/restores the actual simulator content size and
    /// passes its observed prerequisite to the Runner, never to the App. This
    /// proves only this maximum-size iPad journey, not VoiceOver or iOS 17.
    @MainActor
    func testIPadSystemMaximumContentSizeOriginalTXTControlsAndVisibleAnchor() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            XCTFail("Select the explicitly provisioned iPad"); throw Prerequisite.iPadRequired
        }
        let expected = ProcessInfo.processInfo.environment["READER_EXPECTED_CONTENT_SIZE"]
        guard expected == "accessibility-extra-extra-extra-large",
              UIApplication.shared.preferredContentSizeCategory == .accessibilityExtraExtraExtraLarge else {
            XCTFail("Set and read back the real simulator maximum content size; pass READER_EXPECTED_CONTENT_SIZE only to the Runner")
            throw Prerequisite.maximumContentSizeRequired
        }
        let prerequisite = XCTAttachment(string: "Runner premise=\(expected ?? "missing"); actualRunnerContentSize=\(UIApplication.shared.preferredContentSizeCategory.rawValue); App launch arguments/environment not modified; original TXT must already have been admitted by the real picker")
        prerequisite.name = "ipad-actual-system-maximum-content-size-prerequisite"
        prerequisite.lifetime = .keepAlways; add(prerequisite)
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 20))
        showAllShelfGroups(app)
        if !app.textFields["shelf-filter"].exists { app.buttons["搜索本地书架"].tap() }
        let filter = app.textFields["shelf-filter"]
        assertInteractiveWithinWindow(filter, app: app, label: "actual shelf title field")
        replace(filter, text: "仙子请听我解释")
        waitUntil("The actual shelf keyboard closes after Return", timeout: 5) { !app.keyboards.firstMatch.exists }
        XCTAssertTrue((filter.value as? String ?? "").contains("仙子请听我解释"))
        let shelfTitle = app.staticTexts.matching(NSPredicate(format: "label == '书架'"))
            .allElementsBoundByIndex.filter(\.isHittable).min { $0.frame.minY < $1.frame.minY }
        let actualShelfTitle = try XCTUnwrap(shelfTitle)
        try assertShortLabel("书架", on: actualShelfTitle, app: app, name: "maximum-size-shelf-title")
        let book = app.buttons[originalBookID]
        XCTAssertTrue(book.waitForExistence(timeout: 15), "The exact picker-imported original is required; no test library is created")
        assertInteractiveWithinWindow(book, app: app, label: "exact real TXT shelf item"); book.tap()
        XCTAssertTrue(app.textViews["reading-body"].waitForExistence(timeout: 20))

        // Choose the original's long first prose chapter through the real UI
        // before measuring. A saved short preface/tail is not an anchor fixture.
        showDirectory(app)
        let query = app.textFields["directory-query"]
        assertInteractiveWithinWindow(query, app: app, label: "actual full directory title filter")
        replace(query, text: "深山古庙")
        waitUntil("The actual directory keyboard closes after Return", timeout: 5) { !app.keyboards.firstMatch.exists }
        let chapter = app.buttons["chapter-1"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 15)); XCTAssertTrue(chapter.label.contains("深山古庙"))
        assertInteractiveWithinWindow(chapter, app: app, label: "exact original first prose chapter"); chapter.tap()
        waitUntil("The actual first prose chapter is selected", timeout: 15) { chapter.isSelected }
        let start = app.buttons["章首"]
        assertInteractiveWithinWindow(start, app: app, label: "actual chapter beginning"); start.tap()
        hideControls(app)
        waitUntil("Actual chapter beginning establishes the maximum-size body", timeout: 15) {
            app.staticTexts["reading-progress"].label == "0%"
        }
        let anchor = try captureMaximumSizeProseAnchor(app)
        assertReadingWithinWindow(app)

        showModule("directory", app: app)
        try assertMaximumSizeReadingHeader(app)
        let cap = app.buttons["control-grabber"]
        assertInteractiveWithinWindow(cap, app: app, label: "actual quick/full control cap")
        if cap.label.hasPrefix("完整控制栏") { cap.tap() }
        waitUntil("Actual quick directory endpoint", timeout: 5) { cap.label.hasPrefix("快捷控制栏") }
        let directoryTab = app.buttons.matching(NSPredicate(format: "label == '目录' AND identifier != 'control-module-directory'")).firstMatch
        try assertShortLabel("目录", on: directoryTab, app: app, name: "maximum-size-quick-directory")
        assertInteractiveWithinWindow(app.buttons["control-module-directory"], app: app, label: "actual quick directory module")
        cap.tap()
        waitUntil("Actual full directory endpoint", timeout: 5) { cap.label.hasPrefix("完整控制栏") && query.isHittable }
        try assertShortLabel("收起", on: app.buttons["expand-controls"], app: app, name: "maximum-size-full-directory")
        assertInteractiveWithinWindow(query, app: app, label: "actual full directory title filter")
        replace(query, text: "深山古庙")
        waitUntil("Actual filtered directory has no covering keyboard", timeout: 5) { !app.keyboards.firstMatch.exists }
        assertInteractiveWithinWindow(chapter, app: app, label: "actual filtered original title")
        try assertShortLabel("深山古庙", on: chapter, app: app, name: "maximum-size-filtered-original-chapter")
        chapter.tap()
        waitUntil("Filtered original chapter remains selected", timeout: 15) { chapter.isSelected }
        hideControls(app)
        try assertVisible(anchor, app: app, name: "maximum-size-original-prose-after-directory")

        showModule("appearance", app: app)
        if !cap.label.hasPrefix("完整控制栏") { cap.tap() }
        waitUntil("Actual full appearance endpoint", timeout: 5) { cap.label.hasPrefix("完整控制栏") }
        let themeNames = ["日间", "暖白", "夜间", "暖夜", "纸纹", "青叶纹", "靛夜", "林夜纹"] as NSArray
        let themes = app.buttons.matching(NSPredicate(format: "label IN %@", themeNames))
            .allElementsBoundByIndex.filter(\.isSelected)
        XCTAssertEqual(themes.count, 1, "The existing real paper selection must be unambiguous")
        let selectedTheme = try XCTUnwrap(themes.first)
        try assertShortLabel(selectedTheme.label, on: selectedTheme, app: app, name: "maximum-size-existing-paper-control")
        selectedTheme.tap()
        XCTAssertTrue(selectedTheme.isSelected, "Operate the actual existing choice without changing font size or another preference")
        hideControls(app)
        try assertVisible(anchor, app: app, name: "maximum-size-original-prose-after-appearance")
        assertReadingWithinWindow(app)
        showModule("home", app: app)
        let leave = app.buttons["leave-reader"]
        assertInteractiveWithinWindow(leave, app: app, label: "normal reader exit"); leave.tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 20))
        if app.textFields["shelf-filter"].exists {
            let closeSearch = app.buttons["搜索本地书架"]
            assertInteractiveWithinWindow(closeSearch, app: app, label: "normal shelf filter close"); closeSearch.tap()
            waitUntil("The actual shelf title filter closes", timeout: 5) { !app.textFields["shelf-filter"].exists }
        }
        try assertMaximumSizeContinueCard(app)
        evidence(app, name: "maximum-size-normal-return-to-original-library")
    }

    private func actualElement(_ id: String, app: XCUIApplication) -> XCUIElement {
        let matches = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", id))
        XCTAssertEqual(matches.count, 1, "Use the unique real visible surface: " + id)
        return matches.element
    }

    private func assertContained(_ element: XCUIElement, in surface: XCUIElement, name: String) {
        XCTAssertGreaterThan(element.frame.width, 0, name)
        XCTAssertGreaterThan(element.frame.height, 0, name)
        XCTAssertTrue(surface.frame.insetBy(dx: -1, dy: -1).contains(element.frame),
                      "The actual maximum-size text must fit its painted surface: \(name), text=\(element.frame), surface=\(surface.frame)")
    }

    private func assertMaximumSizeReadingHeader(_ app: XCUIApplication) throws {
        let surface = actualElement("reading-header-surface", app: app)
        let title = actualElement("reading-header-book-title", app: app)
        let chapter = actualElement("reading-header-chapter-title", app: app)
        assertWithinWindow(surface, app: app, label: "actual maximum-size reading header")
        assertContained(title, in: surface, name: "actual book title")
        assertContained(chapter, in: surface, name: "actual chapter/source title")
        XCTAssertLessThanOrEqual(title.frame.maxY, chapter.frame.minY + 1,
                                 "The real book/chapter lines may not overlap at maximum system size")
        try assertShortLabel("仙子请听我解释", on: title, app: app, name: "maximum-size-contained-reading-book-title")
        try assertShortLabel("深山古庙", on: chapter, app: app, name: "maximum-size-contained-reading-chapter-title")
    }

    private func assertMaximumSizeContinueCard(_ app: XCUIApplication) throws {
        let surface = actualElement("shelf-continue-card", app: app)
        let title = actualElement("shelf-continue-title", app: app)
        let chapter = actualElement("shelf-continue-chapter", app: app)
        assertInteractiveWithinWindow(surface, app: app, label: "actual maximum-size continue card")
        assertContained(title, in: surface, name: "actual continue book title")
        assertContained(chapter, in: surface, name: "actual continue chapter title")
        let nextHeading = app.staticTexts["全部书籍"]
        XCTAssertTrue(nextHeading.exists)
        XCTAssertLessThanOrEqual(surface.frame.maxY, nextHeading.frame.minY + 1,
                                 "The actual continue chapter must not overlap the next shelf section")
        try assertShortLabel("仙子请听我解释", on: title, app: app, name: "maximum-size-contained-continue-title")
        try assertShortLabel("深山古庙", on: chapter, app: app, name: "maximum-size-contained-continue-chapter")
    }

    private func showAllShelfGroups(_ app: XCUIApplication) {
        if app.textFields["shelf-filter"].exists { app.buttons["搜索本地书架"].tap() }
        if app.buttons["全部分组"].exists { return }
        let sorts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '默认顺序' OR label BEGINSWITH '加入时间' OR label BEGINSWITH '最近阅读' OR label BEGINSWITH '书名' OR label BEGINSWITH '作者'"))
        let sort = sorts.allElementsBoundByIndex.filter(\.isHittable).sorted {
            abs($0.frame.midY - $1.frame.midY) < 10 ? $0.frame.maxX > $1.frame.maxX : $0.frame.midY < $1.frame.midY
        }.first
        guard let sort else { XCTFail("Actual shelf sort/group row missing"); return }
        let groups = app.buttons.allElementsBoundByIndex.filter {
            $0.isHittable && $0.frame.maxX < sort.frame.minX && abs($0.frame.midY - sort.frame.midY) < 10
        }
        XCTAssertEqual(groups.count, 1, "The real existing group menu must be unambiguous")
        guard let group = groups.first else { return }
        assertInteractiveWithinWindow(group, app: app, label: "actual shelf group filter"); group.tap()
        let all = app.buttons["全部分组"]
        XCTAssertTrue(all.waitForExistence(timeout: 5)); all.tap()
    }

    private func assertInteractiveWithinWindow(_ element: XCUIElement, app: XCUIApplication, label: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), label)
        XCTAssertTrue(element.isHittable && element.isEnabled, label)
        assertWithinWindow(element, app: app, label: label)
    }

    private func assertShortLabel(_ text: String, on element: XCUIElement, app: XCUIApplication, name: String) throws {
        assertInteractiveWithinWindow(element, app: app, label: name)
        // OCR exactly this actual control's on-screen frame. A matching label
        // elsewhere in a hidden/duplicate module cannot satisfy this check.
        let lines = try ocr(app, region: element.frame,
            labelMetadata: "name=\(name); expectedLabel=\(text); identifier=\(element.identifier); actualLabel=\(element.label); actualControlFrame=\(element.frame)")
        let actual = normalized(lines.joined())
        let attachment = XCTAttachment(string: "label=\(text); actualControlFrame=\(element.frame); actualOCR=\(lines.joined(separator: "\n")); \(lastOCRGeometry)")
        attachment.name = name + "-actual-visible-label"; attachment.lifetime = .keepAlways; add(attachment)
        evidence(app, name: name)
        XCTAssertTrue(actual.contains(normalized(text)), "The actual maximum-size label must be painted inside its own visible control")
    }

    private func captureMaximumSizeProseAnchor(_ app: XCUIApplication) throws -> String {
        let lines = try ocr(app)
        let prose = lines.filter {
            let value = normalized($0)
            return !value.isEmpty && !value.contains("第一章") && !value.contains("深山古庙")
        }
        XCTAssertGreaterThanOrEqual(prose.count, 4, "An actual long prose chapter must provide visible body lines")
        let anchor = String(normalized(prose.joined()).prefix(24))
        XCTAssertGreaterThanOrEqual(anchor.count, 18, "Combine naturally wrapped real prose; do not accept a short title/tail anchor")
        let text = XCTAttachment(string: anchor)
        text.name = "maximum-size-original-prose-actual-native-OCR"; text.lifetime = .keepAlways; add(text)
        evidence(app, name: "maximum-size-original-prose-before-controls")
        return anchor
    }

    private func showModule(_ module: String, app: XCUIApplication) {
        let button = app.buttons["control-module-" + module]
        if !button.isHittable {
            let body = app.textViews["reading-body"]
            XCTAssertTrue(body.waitForExistence(timeout: 10))
            body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(button.isHittable); button.tap()
    }

    private func showDirectory(_ app: XCUIApplication) {
        showModule("directory", app: app)
        let grabber = app.buttons["control-grabber"]
        XCTAssertTrue(grabber.waitForExistence(timeout: 5))
        if !grabber.label.hasPrefix("完整控制栏") { grabber.tap() }
        waitUntil("The actual directory controls must finish opening", timeout: 5) {
            grabber.label.hasPrefix("完整控制栏") && app.textFields["directory-query"].isHittable
        }
    }

    private func hideControls(_ app: XCUIApplication) {
        let hide = app.buttons["收起阅读控制"]
        XCTAssertTrue(hide.waitForExistence(timeout: 5)); hide.tap()
        waitUntil("The real reading surface must own input again", timeout: 5) {
            app.textViews["reading-body"].isHittable && !app.buttons["control-grabber"].isHittable
        }
    }

    private func assertDirectoryWithinWindow(_ app: XCUIApplication, name: String) {
        showDirectory(app)
        let chapter = app.buttons["chapter-1"]
        waitUntil("The current actual chapter must remain selected after reflow", timeout: 10) { chapter.isSelected }
        let controls: [(String, XCUIElement)] = [
            ("grabber", app.buttons["control-grabber"]),
            ("directory module", app.buttons["control-module-directory"]),
            ("directory filter", app.textFields["directory-query"]),
            ("locate current chapter", app.buttons["locate-current-chapter"]),
            ("selected original chapter", chapter),
            ("normal close", app.buttons["收起阅读控制"]),
            ("normal reader exit", app.buttons["leave-reader"])
        ]
        for (label, element) in controls {
            XCTAssertTrue(element.exists, label)
            XCTAssertTrue(element.isHittable, label)
            assertWithinWindow(element, app: app, label: label)
        }
        evidence(app, name: name)
        hideControls(app)
    }

    private func assertReadingWithinWindow(_ app: XCUIApplication) {
        let body = app.textViews["reading-body"]
        let footer = app.staticTexts["reading-progress"]
        XCTAssertTrue(body.exists); XCTAssertTrue(footer.exists)
        assertWithinWindow(body, app: app, label: "native body viewport")
        assertWithinWindow(footer, app: app, label: "native reading footer")
        XCTAssertLessThanOrEqual(body.frame.maxY, footer.frame.minY + 1,
            "The native body must not paint under the reserved footer after a real window rotation")
    }

    private func assertWithinWindow(_ element: XCUIElement, app: XCUIApplication, label: String) {
        let frame = element.frame
        XCTAssertGreaterThan(frame.width, 0, label)
        XCTAssertGreaterThan(frame.height, 0, label)
        XCTAssertTrue(app.frame.insetBy(dx: -1, dy: -1).contains(frame),
            "\(label) lies outside the actual app window: element=\(frame), window=\(app.frame)")
    }

    private func waitForOrientation(_ app: XCUIApplication, landscape: Bool, stage: String) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = app.frame
            return frame.width > 0 && frame.height > 0 && (landscape ? frame.width > frame.height : frame.height > frame.width)
        }, object: nil)
        let result = XCTWaiter.wait(for: [expected], timeout: 15)
        let screenshot = app.screenshot().image
        let facts = "stage=\(stage); requestedWindowClass=\(landscape ? "landscape" : "portrait"); result=\(result.rawValue); uptime=\(ProcessInfo.processInfo.systemUptime); actualSensorOrientation=\(XCUIDevice.shared.orientation.rawValue); appState=\(app.state.rawValue); actualAppFrame=\(app.frame); screenshotOrientation=\(screenshot.imageOrientation.rawValue); screenshotPixels=\(screenshot.cgImage?.width ?? 0)x\(screenshot.cgImage?.height ?? 0); \(fullScreenOrientationEvidence(stage: stage)); readerDirectionPreferenceUnchanged=true"
        let audit = XCTAttachment(string: facts)
        audit.name = "ipad-actual-orientation-\(stage)"; audit.lifetime = .keepAlways; add(audit)
        if result != .completed {
            evidence(app, name: "ipad-orientation-\(stage)-failure")
        }
        XCTAssertEqual(result, .completed, "The actual app window must rotate; a requested orientation alone is insufficient")
    }

    private func fullScreenOrientationEvidence(stage: String) -> String {
        let screenshot = XCUIScreen.main.screenshot()
        let image = screenshot.image
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "ipad-orientation-\(stage)-actual-full-screen"; attachment.lifetime = .keepAlways; add(attachment)
        return "fullScreenOrientation=\(image.imageOrientation.rawValue); fullScreenPixels=\(image.cgImage?.width ?? 0)x\(image.cgImage?.height ?? 0)"
    }

    /// A repeated identical XCTest sensor value may emit no new event. Only
    /// when that exact value already disagrees with the live window, establish
    /// one observed opposite input before returning to the requested baseline.
    /// This does not set an App preference or call the App's scene APIs.
    private func establishOrientationInput(_ app: XCUIApplication, desired: UIDeviceOrientation, stage: String) {
        let device = XCUIDevice.shared
        let beforeSensor = device.orientation
        let beforeFrame = app.frame
        let validWindow = beforeFrame.width > 0 && beforeFrame.height > 0
        let windowMatches = validWindow && (desired.isLandscape
            ? beforeFrame.width > beforeFrame.height : beforeFrame.height > beforeFrame.width)
        let requiresFreshEvent = beforeSensor == desired && validWindow && !windowMatches
        let before = XCTAttachment(string: "stage=\(stage); uptime=\(ProcessInfo.processInfo.systemUptime); desiredSensor=\(desired.rawValue); beforeSensor=\(beforeSensor.rawValue); beforeWindow=\(beforeFrame); singleAwayBackRequired=\(requiresFreshEvent); maximumAwayBackCycles=1; readerDirectionPreferenceUnchanged=true")
        before.name = "ipad-orientation-input-\(stage)-before"; before.lifetime = .keepAlways; add(before)
        if requiresFreshEvent {
            let away: UIDeviceOrientation = desired.isLandscape ? .portrait : .landscapeLeft
            device.orientation = away
            let observedAway = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let frame = app.frame
                return device.orientation == away && frame.width > 0 && frame.height > 0 &&
                    (away.isLandscape ? frame.width > frame.height : frame.height > frame.width)
            }, object: nil)
            let result = XCTWaiter.wait(for: [observedAway], timeout: 15)
            let screenshot = app.screenshot().image
            let awayFacts = XCTAttachment(string: "stage=\(stage); requestedAwaySensor=\(away.rawValue); actualSensor=\(device.orientation.rawValue); actualWindow=\(app.frame); result=\(result.rawValue); screenshotOrientation=\(screenshot.imageOrientation.rawValue); screenshotPixels=\(screenshot.cgImage?.width ?? 0)x\(screenshot.cgImage?.height ?? 0); awayBackCycle=1; readerDirectionPreferenceUnchanged=true")
            awayFacts.name = "ipad-orientation-input-\(stage)-away"; awayFacts.lifetime = .keepAlways; add(awayFacts)
            guard result == .completed else {
                evidence(app, name: "ipad-orientation-input-\(stage)-away-failure")
                XCTAssertEqual(result, .completed, "The single real away input must change the sensor and match the actual window before returning")
                return
            }
        }
        device.orientation = desired
        waitForOrientation(app, landscape: desired.isLandscape, stage: stage)
        let after = XCTAttachment(string: "stage=\(stage); uptime=\(ProcessInfo.processInfo.systemUptime); requestedSensor=\(desired.rawValue); actualSensor=\(device.orientation.rawValue); actualWindow=\(app.frame); awayBackCycles=\(requiresFreshEvent ? 1 : 0); readerDirectionPreferenceUnchanged=true")
        after.name = "ipad-orientation-input-\(stage)-after"; after.lifetime = .keepAlways; add(after)
        XCTAssertEqual(device.orientation, desired, "The observed sensor must match the requested baseline as well as the actual window")
    }

    private func replace(_ field: XCUIElement, text: String) {
        field.tap()
        let old = field.value as? String ?? ""
        if old != (field.placeholderValue ?? "") { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }
        field.typeText(text + "\n")
    }

    private func captureAnchor(_ app: XCUIApplication, name: String) throws -> String {
        let lines = try ocr(app)
        XCTAssertGreaterThanOrEqual(lines.count, 4, "Real prose must be visible; a short title-only chapter cannot prove rotation recovery")
        let anchor = String(normalized(lines.dropFirst().prefix(2).joined()).prefix(24))
        XCTAssertGreaterThanOrEqual(anchor.count, 18)
        evidence(app, name: name)
        let text = XCTAttachment(string: anchor)
        text.name = name + "-actual-native-OCR"; text.lifetime = .keepAlways; add(text)
        return anchor
    }

    private func assertVisible(_ anchor: String, app: XCUIApplication, name: String) throws {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let lines = try? self.ocr(app) else { return false }
            return self.normalized(lines.joined()).contains(anchor)
        }, object: nil)
        let result = XCTWaiter.wait(for: [expected], timeout: 15)
        if result != .completed {
            let geometry = XCTAttachment(string: lastOCRGeometry + "\nexpected=" + anchor + "\nactual=" + lastOCRLines.joined(separator: "\n"))
            geometry.name = name + "-actual-OCR-geometry-failure"; geometry.lifetime = .keepAlways; add(geometry)
            if let lastOCRImage {
                let image = XCTAttachment(image: lastOCRImage)
                image.name = name + "-actual-upright-OCR-crop-failure"; image.lifetime = .keepAlways; add(image)
            }
            evidence(app, name: name + "-failure")
        }
        XCTAssertEqual(result, .completed, "The same original passage must remain visible after actual rotation")
        XCTAssertTrue(normalized(try ocr(app).joined()).contains(anchor))
        evidence(app, name: name)
    }

    private func ocr(_ app: XCUIApplication, region: CGRect? = nil, labelMetadata: String? = nil) throws -> [String] {
        let captureTime = Date()
        let capture = app.screenshot()
        let screenshot = capture.image
        let raw = try XCTUnwrap(screenshot.cgImage)
        let oriented = CIImage(cgImage: raw).oriented(try imageOrientation(screenshot.imageOrientation))
        let source = try XCTUnwrap(CIContext(options: [.cacheIntermediates: false]).createCGImage(oriented, from: oriented.extent))
        let window = app.frame
        let frame = region?.intersection(window)
            ?? app.textViews["reading-body"].frame.intersection(window).insetBy(dx: 6, dy: 6)
        lastOCRLines = []; lastOCRImage = nil
        lastOCRGeometry = "raw=\(raw.width)x\(raw.height); UIImageOrientation=\(screenshot.imageOrientation.rawValue); upright=\(source.width)x\(source.height); window=\(window); bodyCrop=\(frame)"
        guard window.width > 0, window.height > 0, frame.width > 0, frame.height > 0 else {
            recordViewportMismatch(capture, image: screenshot, raw: raw, normalized: source,
                app: app, window: window, region: region, crop: frame, captureTime: captureTime,
                labelMetadata: labelMetadata, reason: "invalid-window-or-ROI")
            throw Prerequisite.invalidViewport
        }
        // App coordinates describe the displayed, upright image. Never stretch
        // pixels to a guessed orientation or crop an earlier portrait frame
        // using a landscape window while the real rotation is still settling.
        guard abs(CGFloat(source.width) / CGFloat(source.height) - window.width / window.height) < 0.01 else {
            recordViewportMismatch(capture, image: screenshot, raw: raw, normalized: source,
                app: app, window: window, region: region, crop: frame, captureTime: captureTime,
                labelMetadata: labelMetadata, reason: "strict-normalized-image-window-aspect-mismatch")
            throw Prerequisite.invalidViewport
        }
        let crop = CGRect(x: (frame.minX - window.minX) * CGFloat(source.width) / window.width,
            y: (frame.minY - window.minY) * CGFloat(source.height) / window.height,
            width: frame.width * CGFloat(source.width) / window.width,
            height: frame.height * CGFloat(source.height) / window.height).integral
        let image = try XCTUnwrap(source.cropping(to: crop))
        lastOCRImage = UIImage(cgImage: image)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate; request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        let lines = (request.results ?? []).sorted {
            abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.01
                ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
        }.compactMap { $0.topCandidates(1).first?.string }
        lastOCRLines = lines
        return lines
    }

    /// Diagnostic attachments share one retained XCUIScreenshot. Direct
    /// CGImage encoding never draws a UIImage or applies orientation metadata;
    /// the system PNG is kept independently so serialization can be compared.
    private func recordViewportMismatch(_ capture: XCUIScreenshot, image: UIImage, raw: CGImage,
                                        normalized: CGImage, app: XCUIApplication, window: CGRect,
                                        region: CGRect?, crop: CGRect, captureTime: Date,
                                        labelMetadata: String?, reason: String) {
        let identity = UUID().uuidString
        var encodings = [String]()
        func attachCG(_ pixels: CGImage, name: String) {
            guard let bytes = CFDataCreateMutable(nil, 0),
                  let destination = CGImageDestinationCreateWithData(bytes, "public.png" as CFString, 1, nil) else {
                encodings.append("\(name)=destination-unavailable"); return
            }
            CGImageDestinationAddImage(destination, pixels, nil)
            guard CGImageDestinationFinalize(destination) else {
                encodings.append("\(name)=encoding-failed"); return
            }
            let data = bytes as Data
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = "platform-viewport-\(identity)-\(name)"
            attachment.lifetime = .keepAlways; add(attachment)
            encodings.append("\(name)=\(pixels.width)x\(pixels.height),bytes=\(data.count),orientationProperty=omitted")
        }
        attachCG(raw, name: "raw-CGImage-no-transform")
        let systemPNG = capture.pngRepresentation
        let original = XCTAttachment(data: systemPNG, uniformTypeIdentifier: "public.png")
        original.name = "platform-viewport-\(identity)-same-XCUIScreenshot-pngRepresentation"
        original.lifetime = .keepAlways; add(original)
        encodings.append("systemPNGBytes=\(systemPNG.count)")
        attachCG(normalized, name: "current-normalized-CGImage-no-extra-transform")
        let windows = app.windows.allElementsBoundByIndex.map { "identifier=\($0.identifier),frame=\($0.frame)" }.joined(separator: "; ")
        let facts = "captureID=\(identity); captureRequestedAt=\(captureTime.timeIntervalSince1970); reason=\(reason); sameRetainedScreenshot=true; extraScreenshotCapture=false; rawCG=\(raw.width)x\(raw.height); UIImageOrientation=\(image.imageOrientation.rawValue); UIImageScale=\(image.scale); UIImageSize=\(image.size); normalizedCG=\(normalized.width)x\(normalized.height); capturedAppFrame=\(window); observedAppFrameAfterEncoding=\(app.frame); appWindows=[\(windows)]; appState=\(app.state.rawValue); observedSensorAfterCapture=\(XCUIDevice.shared.orientation.rawValue); requestedRegion=\(String(describing: region)); intersectedROI=\(crop); labelMetadata=\(labelMetadata ?? "body ROI"); encodings=[\(encodings.joined(separator: "; "))]; originalAspectAndROIRulesUnchanged=true"
        let metadata = XCTAttachment(string: facts)
        metadata.name = "platform-viewport-\(identity)-same-capture-metadata"
        metadata.lifetime = .keepAlways; add(metadata)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "platform-viewport-\(identity)-AX-after-same-capture"
        hierarchy.lifetime = .keepAlways; add(hierarchy)
    }

    private func imageOrientation(_ orientation: UIImage.Orientation) throws -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: throw Prerequisite.invalidViewport
        }
    }

    private func normalized(_ value: String) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }

    private func evidence(_ app: XCUIApplication, name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + "-native-window-and-controls"; hierarchy.lifetime = .keepAlways; add(hierarchy)
    }

    private func waitUntil(_ fact: String, timeout: TimeInterval, _ condition: @escaping () -> Bool) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: timeout), .completed, fact)
    }
}
