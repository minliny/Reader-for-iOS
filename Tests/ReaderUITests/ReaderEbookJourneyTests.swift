import XCTest
import UIKit
import Vision

/// Run explicitly on a provisioned native target. Import journeys use the
/// untouched Downloads originals; the existing-book diagnostic also supports
/// an already provisioned physical device without importing. Operations use
/// the real UI, without launch arguments, Runtime calls or generated books.
/// The delivery owner separately binds provisioned bytes to their SHA.
final class ReaderEbookJourneyTests: XCTestCase {
    private let epubID = "book-local:5d6d9dd26bbea9ed0db4e4f7a127a538dfe439f5694c3370a30ac33503db9d67"
    private let mobiID = "book-local:a25dcde710240f9c2c03d7b7b98aa09277d83392f3dc0da9779f6bc78e7c0cef"

    override func setUpWithError() throws { continueAfterFailure = false }

    func testExistingRealEpubChapterAndBackNativeStateObservationWithoutImport() throws {
        executionTimeAllowance = 120
        let app = XCUIApplication(), started = ProcessInfo.processInfo.systemUptime
        let deadline = started + 110
        // Shelf AX uses book-<bookId>; reading AX uses ReaderBook.id == sourceId|bookId.
        let readingBookID = "reading-book:local|" + String(epubID.dropFirst("book-".count))
        let target = app.buttons.matching(NSPredicate(format:
            "identifier BEGINSWITH 'chapter-' AND label == %@", "第1章 牢房"))
        let back = app.buttons.matching(identifier: "leave-reader")
        let headers = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'reading-chapter:'"))
        var report: [String: Any] = ["scope": "DIAGNOSTIC_ONLY_NOT_JOURNEY_ACCEPTANCE",
            "expectedShelfBookAXID": epubID, "expectedReadingBookAXID": readingBookID,
            "chapterTapRequested": false, "backTapRequested": false,
            "chapterTapReturned": "NOT_SENT", "backTapReturned": "NOT_SENT",
            "chapterObservation": "NOT_RUN", "backObservation": "NOT_RUN",
            "stateSampleStage": "NOT_RUN",
            "historicalDockInputLogger": "NOT_CAPTURED", "liveModelBusyFlags": "NOT_CAPTURED_UI_INDICATORS_ONLY",
            "tapReturnMeaning": "XCTEST_API_RETURNED_NOT_PRODUCTION_CLOSURE_PROOF"]
        func json(_ stage: String) {
            report["stage"] = stage; report["elapsedSeconds"] = ProcessInfo.processInfo.systemUptime - started
            let data = (try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])) ?? Data()
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "existing-epub-native-" + stage; attachment.lifetime = .keepAlways; add(attachment)
        }
        func fields(_ query: XCUIElementQuery) -> [[String: Any]] {
            query.allElementsBoundByIndex.map { element in
                let f = element.frame
                return ["identifier": element.identifier, "label": element.label,
                    "frame": [f.minX, f.minY, f.width, f.height], "isEnabled": element.isEnabled,
                    "isHittable": element.isHittable, "isSelected": element.isSelected]
            }
        }
        func record(_ stage: String) {
            // Persist the phase before querying AX: XCTest failures need not unwind through defer.
            json(stage + "-before-snapshot"); evidence(app, name: "existing-epub-native-" + stage)
            let ax = XCTAttachment(string: app.debugDescription)
            ax.name = "existing-epub-native-" + stage + "-AX"; ax.lifetime = .keepAlways; add(ax)
            report["readingBooks"] = fields(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'reading-book:'")))
            report["chapterHeaders"] = fields(headers)
            let candidates = fields(target); report["targetCount"] = candidates.count; report["targetCandidates"] = candidates
            report["backCandidates"] = fields(back); report["backCount"] = back.count
            report["activityIndicators"] = fields(app.activityIndicators)
            report["keyboardCount"] = app.keyboards.count
            report["fullGrabber"] = fields(app.buttons.matching(identifier: "control-grabber"))
            report["alerts"] = fields(app.alerts); report["stateSampleStage"] = stage; json(stage)
        }
        func wait(_ seconds: TimeInterval, _ condition: @escaping () -> Bool) -> XCTWaiter.Result {
            let timeout = max(0, min(seconds, deadline - ProcessInfo.processInfo.systemUptime))
            guard timeout > 0 else { return .timedOut }
            return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)], timeout: timeout)
        }
        func fail(_ reason: String) { report["preconditionFailure"] = reason; record("precondition-failed"); XCTFail(reason) }
        json("before-normal-launch"); app.launch(); json("launched")
        let book = app.buttons.matching(identifier: epubID)
        _ = wait(10) { book.count == 1 }
        json("before-existing-book-native-tap")
        guard book.count == 1, book.firstMatch.isEnabled, book.firstMatch.isHittable else {
            fail("The exact existing real EPUB shelf button is not uniquely actionable"); return
        }
        book.firstMatch.tap(); json("existing-book-native-tap-returned-before-body-wait")
        let body = ebookBody(app)
        _ = wait(15) { body.exists && body.isHittable && !app.buttons["阅读控制"].exists }
        json("before-normal-quick-entry")
        guard body.exists, body.isHittable, !app.buttons["阅读控制"].exists else {
            fail("The existing EPUB WK body is not ready for the normal controls entry"); return
        }
        // Same normal WK touch as openModule; no alternate entry or forced row/Back coordinates.
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap(); json("normal-quick-touch-returned")
        let directory = app.buttons["control-module-directory"]
        _ = wait(5) { directory.exists && directory.isHittable }
        json("before-quick-directory-native-tap")
        guard directory.exists, directory.isEnabled, directory.isHittable else {
            fail("The normal Quick directory control is not actionable"); return
        }
        directory.tap(); json("quick-directory-native-tap-returned")
        let grabber = app.buttons["control-grabber"]
        _ = wait(5) { grabber.exists && grabber.isHittable }
        json("before-full-grabber-native-tap")
        guard grabber.exists, grabber.isEnabled, grabber.isHittable else {
            fail("The actual directory grabber is not actionable"); return
        }
        if !grabber.label.hasPrefix("完整控制栏") {
            let viewport = app.frame, handle = grabber.frame
            let start = CGPoint(x: handle.midX, y: handle.midY)
            let end = CGPoint(x: handle.midX, y: viewport.minY + viewport.height * 0.2)
            report["fullExpansionGesture"] = ["kind": "ONE_NATIVE_SLOW_HELD_DRAG_NO_RETRY",
                "appFrame": [viewport.minX, viewport.minY, viewport.width, viewport.height],
                "grabberFrame": [handle.minX, handle.minY, handle.width, handle.height],
                "startPoint": [start.x, start.y], "endPoint": [end.x, end.y],
                "pressSeconds": 0.08, "endHoldSeconds": 0.25]
            json("before-full-grabber-native-drag")
            guard viewport.width > 0, viewport.height > 0, viewport.contains(start), viewport.contains(end) else {
                fail("The actual grabber drag endpoints must lie inside the app frame"); return
            }
            let dx = (handle.midX - viewport.minX) / viewport.width
            grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.08,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.2)),
                withVelocity: .slow, thenHoldForDuration: 0.25)
            json("full-grabber-native-drag-returned")
        }
        _ = wait(5) { grabber.exists && grabber.label.hasPrefix("完整控制栏") }
        record("full-directory-native-state")
        guard grabber.exists, grabber.label.hasPrefix("完整控制栏"),
              app.staticTexts[readingBookID].exists else {
            fail("Full directory and the exact real EPUB reading identity are required"); return
        }
        for (name, query) in [("chapter", target), ("back", back)] {
            // Reuse the immediately preceding full state; persist the phase before the live guard.
            report[name + "PreTapStateSampleStage"] = report["stateSampleStage"]
            json(name + "-before-native-precondition")
            guard query.count == 1, query.firstMatch.isEnabled, query.firstMatch.isHittable,
                  ProcessInfo.processInfo.systemUptime + 15 < deadline else {
                report[name + "NotSentReason"] = "NOT_UNIQUE_ENABLED_HITTABLE_OR_OBSERVATION_BUDGET_EXHAUSTED"
                record(name + "-not-sent"); continue
            }
            let before = headers.allElementsBoundByIndex.map { $0.identifier + "|" + $0.label }
            report[name + "TapRequested"] = true; report[name + "TapReturned"] = false; json(name + "-before-native-tap")
            query.firstMatch.tap(); report[name + "TapReturned"] = true
            let observationDeadline = min(deadline, ProcessInfo.processInfo.systemUptime + 15)
            record(name + "-native-tap-returned")
            var indicatorSeen = false, alertSeen = false
            let outcome = wait(max(0, observationDeadline - ProcessInfo.processInfo.systemUptime)) {
                indicatorSeen = indicatorSeen || app.activityIndicators.count > 0
                alertSeen = alertSeen || app.alerts.count > 0
                let now = headers.allElementsBoundByIndex.map { $0.identifier + "|" + $0.label }
                return alertSeen || (name == "back" ? app.buttons["更多书架操作"].exists : !now.isEmpty && now != before)
            }
            let after = headers.allElementsBoundByIndex.map { $0.identifier + "|" + $0.label }
            report[name + "Observation"] = ["waitResult": outcome.rawValue, "headerChanged": after != before,
                "headerBefore": before, "headerAfter": after, "activityIndicatorSeen": indicatorSeen,
                "alertSeen": alertSeen, "shelfVisible": app.buttons["更多书架操作"].exists]
            record(name + "-observed")
        }
        json("observations-complete-not-journey-acceptance")
    }

    func testOriginalZhongSongPickerHierarchySimulationReflowAndColdVisibleAnchor() throws {
        let app = XCUIApplication(); app.launch()
        importOriginal(prefix: "终宋", format: "epub", expectedID: epubID, app: app)
        openBook(epubID, app: app)
        // The original OEBPS/Text/Cha19.xhtml heading is 第19章 说客.
        // large-original-ebook-1's actual Core-backed AX row is chapter-20.
        // Do not infer an index from the chapter number or the dynamic probe.
        chooseChapter(20, query: "第19章 说客", seekStart: true, app: app)
        let originalSettings = try enableSimulation(app)
        let before = try captureAnchor(app, name: "epub-cha19-real-prose-before-native-curl")
        let beforeLines = try ocr(app).map(normalized)
        let body = ebookBody(app)
        let smallStart = body.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.48))
        smallStart.press(forDuration: 0.08,
            thenDragTo: smallStart.withOffset(CGVector(dx: -min(24, body.frame.width * 0.06), dy: 0)),
            withVelocity: .slow, thenHoldForDuration: 0.4)
        try assertVisible(before, app: app, name: "epub-native-insufficient-release-returned-original")
        XCTAssertEqual(try ocr(app).map(normalized), beforeLines,
            "An insufficient native release must return to the same actual viewport, not merely retain a rounded percent")
        let advanced = try advance(app, original: before, name: "epub-native-qualified-release-new-prose")
        XCTAssertNotEqual(advanced, before)
        let wrapping = try ocr(app).dropFirst().prefix(3).map(normalized)
        let fontChange = try changeFont(app)
        try assertVisible(advanced, app: app, name: "epub-original-passage-survives-real-font-reflow")
        XCTAssertNotEqual(try ocr(app).dropFirst().prefix(3).map(normalized), wrapping,
            "Actual visible line wrapping must change; a changed settings number is insufficient")
        let restoredAnchor = try captureAnchor(app, name: "epub-real-reflowed-anchor")
        leaveReader(app)
        openBook(epubID, app: app)
        try assertVisible(restoredAnchor, app: app, name: "epub-normal-leave-reopen-visible-anchor")
        leaveReader(app); app.terminate(); app.launch()
        openBook(epubID, app: app)
        try assertVisible(restoredAnchor, app: app, name: "epub-cold-reopen-visible-anchor")
        assertSelectedChapter(20, query: "第19章 说客", app: app)
        try restoreSettings(originalSettings, fontChange: fontChange, app: app)
        leaveReader(app)
        // Screenshots/OCR prove the native gestures' outcomes. They do not
        // claim intermediate curl geometry or override system Reduce Motion.
        // Root may record the gesture run; separate native-frame methods must
        // establish actual in-flight rendering before full motion acceptance.
    }

    func testExistingRealZhongSongFirstProseAndShelfReturn() throws {
        executionTimeAllowance = 180
        let app = XCUIApplication(); app.launch(); openBook(epubID, app: app)
        openModule("directory", app: app)
        let tab = app.buttons.matching(NSPredicate(format: "label == '目录' AND identifier != 'control-module-directory'")).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
        let title = "第1章 牢房"
        let prose = app.buttons.matching(NSPredicate(format: "identifier == 'chapter-2' AND label == %@", title))
        XCTAssertTrue(prose.firstMatch.waitForExistence(timeout: 10)); XCTAssertEqual(prose.count, 1)
        XCTAssertTrue(prose.firstMatch.isEnabled && prose.firstMatch.isHittable); prose.firstMatch.tap()
        let header = app.staticTexts["reading-chapter:2"]
        waitUntil("Actual existing EPUB first prose", timeout: 25) { header.exists && header.label.hasPrefix(title + " · ") }
        hideControls(app)
        try assertVisible("一缕微光从高墙上的小小气窗透进来昏暗", app: app, name: "epub-existing-source-first-prose")
        leaveReader(app)
    }

    func testOriginalFuHanPickerFirstProseAdjacentChapterAndReturn() throws {
        executionTimeAllowance = 300
        let app = XCUIApplication(); app.launch()
        importOriginal(prefix: "覆汉", format: "mobi", expectedID: mobiID, app: app)
        openBook(mobiID, app: app)
        // Existing source-bound Core materializations independently agree on
        // these actual prose titles/anchors. No cover or TOC is prose evidence.
        let firstTitle = "第一章 卢龙塞"
        let nextTitle = "第二章 请战"
        let firstAnchor = "塞外一座足可容纳数千鲜卑军士的大营立"
        let nextAnchor = "诸位乡邻子弟自从建宁年间算起这么多年"
        openModule("directory", app: app)
        let tab = app.buttons.matching(NSPredicate(format: "label == '目录' AND identifier != 'control-module-directory'")).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
        let prose = app.buttons.matching(NSPredicate(format: "identifier == 'chapter-3' AND label == %@", firstTitle))
        XCTAssertTrue(prose.firstMatch.waitForExistence(timeout: 10)); XCTAssertEqual(prose.count, 1)
        XCTAssertTrue(prose.firstMatch.isEnabled && prose.firstMatch.isHittable); prose.firstMatch.tap()
        let firstHeader = app.staticTexts["reading-chapter:3"]
        waitUntil("Actual original MOBI prose selected", timeout: 25) { firstHeader.exists && firstHeader.label.hasPrefix(firstTitle + " · ") }
        let start = app.buttons["章首"]
        XCTAssertTrue(start.isEnabled && start.isHittable); start.tap()
        hideControls(app)
        try assertVisible(firstAnchor, app: app, name: "mobi-ordinary-source-prose")

        openModule("home", app: app)
        let next = app.buttons["下一章"]
        XCTAssertTrue(next.isEnabled && next.isHittable); next.tap()
        let nextHeader = app.staticTexts["reading-chapter:4"]
        waitUntil("Actual adjacent original MOBI chapter", timeout: 25) { nextHeader.exists && nextHeader.label.hasPrefix(nextTitle + " · ") }
        hideControls(app)
        try assertVisible(nextAnchor, app: app, name: "mobi-ordinary-source-adjacent")

        openModule("home", app: app)
        let previous = app.buttons["上一章"]
        XCTAssertTrue(previous.isEnabled && previous.isHittable); previous.tap()
        waitUntil("Return to actual original MOBI prose", timeout: 25) { firstHeader.exists && firstHeader.label.hasPrefix(firstTitle + " · ") }
        hideControls(app)
        try assertVisible(firstAnchor, app: app, name: "mobi-ordinary-source-return")
        leaveReader(app)
        XCTAssertTrue(app.buttons[mobiID].waitForExistence(timeout: 15), "The actual admitted original remains on the shelf")
    }

    func testOriginalFuHanPickerBodyChapterReturnAndColdVisibleAnchor() throws {
        let app = XCUIApplication(); app.launch()
        importOriginal(prefix: "覆汉", format: "mobi", expectedID: mobiID, app: app)
        openBook(mobiID, app: app)
        // The original libmobi entry / Core probe established chapter 3 is
        // actual prose. Never use the cover/TOC as this body's evidence.
        chooseChapter(3, query: "", seekStart: true, app: app)
        let originalSettings = try enableSimulation(app)
        let chapterStart = try captureAnchor(app, name: "mobi-core-chapter3-original-prose")
        chooseChapter(2, query: "", seekStart: true, app: app)
        waitUntil("A real different chapter must replace chapter 3", timeout: 25) {
            guard let lines = try? self.ocr(app), !lines.isEmpty else { return false }
            return !self.normalized(lines.joined()).contains(chapterStart)
        }
        evidence(app, name: "mobi-chapter2-navigation-only-not-prose-acceptance")
        chooseChapter(3, query: "", seekStart: true, app: app)
        try assertVisible(chapterStart, app: app, name: "mobi-return-to-original-body-chapter3")
        let advanced = try advance(app, original: chapterStart, name: "mobi-real-body-page-after-native-release")
        leaveReader(app)
        openBook(mobiID, app: app)
        try assertVisible(advanced, app: app, name: "mobi-normal-leave-reopen-visible-anchor")
        leaveReader(app); app.terminate(); app.launch()
        openBook(mobiID, app: app)
        try assertVisible(advanced, app: app, name: "mobi-cold-reopen-visible-anchor")
        assertSelectedChapter(3, query: "", app: app)
        try restoreSettings(originalSettings, fontChange: nil, app: app)
        leaveReader(app)
    }

    private struct DisplaySettings {
        let mode: String
        let transition: String
        let reduceMotion: String
    }
    private struct FontChange {
        let initial: Int
        let increased: Bool
    }

    private func importOriginal(prefix: String, format: String, expectedID: String, app: XCUIApplication) {
        if app.buttons["书架"].waitForExistence(timeout: 10) { app.buttons["书架"].tap() }
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 15), app.debugDescription)
        resetShelfVisibility(app)
        app.buttons["更多书架操作"].tap(); app.buttons["import-book"].tap()
        func candidates() -> XCUIElementQuery {
            app.cells.containing(NSPredicate(format: "label BEGINSWITH %@", prefix))
        }
        if !candidates().firstMatch.waitForExistence(timeout: 3) {
            let folder = app.cells.matching(NSPredicate(format: "identifier == 'Reader, Container' OR label BEGINSWITH 'Reader,'")).firstMatch
            XCTAssertTrue(folder.waitForExistence(timeout: 10), "Missing real \(format) original / Reader Documents: " + app.debugDescription)
            folder.tap()
        }
        XCTAssertTrue(candidates().firstMatch.waitForExistence(timeout: 15), "Provision the actual \(prefix) \(format) original; missing input FAILS")
        XCTAssertEqual(candidates().count, 1, "The real system picker must identify one unambiguous original")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = prefix + "-original-system-picker"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        candidates().firstMatch.tap()
        let open = app.buttons["打开"]
        if open.waitForExistence(timeout: 2) { open.tap() }
        XCTAssertTrue(app.buttons["关闭导入结果"].waitForExistence(timeout: 20), app.debugDescription)
        let success = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '已导入书架' OR label CONTAINS '这本书已在书架中'")).firstMatch
        XCTAssertTrue(success.waitForExistence(timeout: 180), app.debugDescription)
        evidence(app, name: prefix + "-real-picker-import-result")
        app.buttons["关闭导入结果"].tap()
        resetShelfVisibility(app)
        XCTAssertTrue(app.buttons[expectedID].waitForExistence(timeout: 15), "The original's Core SHA book identity must appear")
    }

    private func openBook(_ id: String, app: XCUIApplication) {
        resetShelfVisibility(app)
        let book = app.buttons[id]
        XCTAssertTrue(book.waitForExistence(timeout: 20), app.debugDescription); book.tap()
        waitForBody(app)
    }

    private func resetShelfVisibility(_ app: XCUIApplication) {
        // A previous real journey can leave either a title/author query or a
        // named/ungrouped shelf predicate. Neither changes this book's identity
        // or import result, so restore the visible neutral predicates through
        // their existing UI before looking up the exact SHA book button.
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 15), app.debugDescription)
        if app.textFields["shelf-filter"].exists {
            app.buttons["搜索本地书架"].tap()
            waitUntil("The native title/author shelf filter is cleared", timeout: 5) {
                !app.textFields["shelf-filter"].exists
            }
        }
        if !app.buttons["全部分组"].exists {
            // The group menu's label is the actual arbitrary user group name.
            // Locate that existing AX button beside the known sort menu; do
            // not invent a production ID or assume a particular group label.
            let sortChoices = app.buttons.matching(NSPredicate(format:
                "label BEGINSWITH '默认顺序' OR label BEGINSWITH '加入时间' OR label BEGINSWITH '最近阅读' OR label BEGINSWITH '书名' OR label BEGINSWITH '作者'"))
            XCTAssertTrue(sortChoices.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
            // A user group may itself be named e.g. 作者. On the first
            // matching row the sort menu is the right-hand button.
            let sort = sortChoices.allElementsBoundByIndex.filter(\.isHittable).sorted {
                abs($0.frame.midY - $1.frame.midY) < 10 ? $0.frame.maxX > $1.frame.maxX : $0.frame.midY < $1.frame.midY
            }.first
            guard let sort else { XCTFail("The actual shelf sort menu is missing"); return }
            let frame = sort.frame
            let menus = app.buttons.allElementsBoundByIndex.filter {
                $0.isHittable && $0.frame.maxX < frame.minX && abs($0.frame.midY - frame.midY) < 10
            }
            XCTAssertEqual(menus.count, 1, "The actual group menu must be unambiguous beside shelf sorting")
            guard let menu = menus.first else { return }
            menu.tap()
            let all = app.buttons["全部分组"]
            XCTAssertTrue(all.waitForExistence(timeout: 5), app.debugDescription); all.tap()
            waitUntil("The actual named/ungrouped shelf predicate is cleared", timeout: 10) {
                app.buttons["全部分组"].exists
            }
        }
    }

    private func ebookBody(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "reading-ebook-body").firstMatch
    }

    private func waitForBody(_ app: XCUIApplication) {
        let body = ebookBody(app)
        XCTAssertTrue(body.waitForExistence(timeout: 30), "A real WK ebook viewport is required; a TXT fallback is not eligible")
        waitUntil("The original native WK must be ready for reading", timeout: 45) {
            body.isHittable && body.frame.width > 180 && body.frame.height > 120 && !app.buttons["阅读控制"].exists
        }
    }

    private func openModule(_ module: String, app: XCUIApplication) {
        let target = app.buttons["control-module-" + module]
        if !target.isHittable {
            if app.buttons["control-grabber"].isHittable { hideControls(app) }
            ebookBody(app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        }
        XCTAssertTrue(target.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(target.isHittable, app.debugDescription); target.tap()
        if module != "home" {
            let grabber = app.buttons["control-grabber"]
            if !grabber.label.hasPrefix("完整控制栏") { grabber.tap() }
            waitUntil("Full actual reading controls", timeout: 5) { grabber.label.hasPrefix("完整控制栏") }
        }
    }

    private func hideControls(_ app: XCUIApplication) {
        let hide = app.buttons["收起阅读控制"]
        XCTAssertTrue(hide.waitForExistence(timeout: 5)); hide.tap()
        waitUntil("Native reading controls dismissed", timeout: 5) { !app.buttons["control-grabber"].isHittable }
    }

    private func directory(_ app: XCUIApplication, query: String) {
        openModule("directory", app: app)
        let tab = app.buttons.matching(NSPredicate(format: "label == '目录' AND identifier != 'control-module-directory'")).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
        let field = app.textFields["directory-query"]
        XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap()
        let old = field.value as? String ?? ""
        if old != field.placeholderValue { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }
        field.typeText(query + "\n")
    }

    private func chooseChapter(_ index: Int, query: String, seekStart: Bool, app: XCUIApplication) {
        directory(app, query: query)
        let chapter = app.buttons["chapter-\(index)"]
        reveal(chapter, identifier: "chapter-\(index)", towardBottom: true, app: app)
        if !query.isEmpty {
            let sameTitle = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chapter-' AND label == %@", query))
            XCTAssertEqual(sameTitle.count, 1, "The actual original entry title must resolve to one navigable Core row")
            XCTAssertEqual(chapter.label, query)
            XCTAssertEqual(sameTitle.firstMatch.identifier, "chapter-\(index)")
        }
        XCTAssertTrue(chapter.isHittable && chapter.isEnabled, app.debugDescription); chapter.tap()
        waitUntil("Core-backed directory selected chapter \(index)", timeout: 25) { chapter.isSelected }
        if seekStart { app.buttons["章首"].tap() }
        evidence(app, name: "real-core-directory-selected-chapter-\(index)")
        hideControls(app); waitForBody(app)
    }

    private func assertSelectedChapter(_ index: Int, query: String, app: XCUIApplication) {
        directory(app, query: query)
        let chapter = app.buttons["chapter-\(index)"]
        reveal(chapter, identifier: "chapter-\(index)", towardBottom: true, app: app)
        XCTAssertTrue(chapter.isSelected, "Cold restoration must retain the original chapter before any new chapter selection")
        hideControls(app); waitForBody(app)
    }

    private func enableSimulation(_ app: XCUIApplication) throws -> DisplaySettings {
        openModule("appearance", app: app)
        let mode = app.buttons["reading-page-mode"]
        reveal(mode, identifier: "reading-page-mode", towardBottom: true, app: app)
        let originalMode = try selected(mode, among: ["滚动", "分页"])
        choose("分页", picker: "reading-page-mode", towardBottom: true, app: app)
        let transition = app.buttons["reading-page-transition"]
        reveal(transition, identifier: "reading-page-transition", towardBottom: true, app: app)
        let originalTransition = try selected(transition, among: ["仿真", "覆盖", "滑动", "无动画"])
        choose("仿真", picker: "reading-page-transition", towardBottom: true, app: app)
        let reduce = app.switches["reading-reduce-motion"]
        reveal(reduce, identifier: "reading-reduce-motion", towardBottom: true, app: app)
        let originalReduce = try XCTUnwrap(reduce.value as? String)
        XCTAssertTrue(["0", "1"].contains(originalReduce))
        setSwitch(reduce, to: "0")
        let settings = DisplaySettings(mode: originalMode, transition: originalTransition, reduceMotion: originalReduce)
        let audit = XCTAttachment(string: "Original mode=\(originalMode), transition=\(originalTransition), ReaderReduceMotion=\(originalReduce). Selected paged/simulation/ReaderReduceMotion=0 through real UI. System Reduce Motion is not overridden or inferred from terminal text changes.")
        audit.name = "original-and-selected-native-reader-settings"; audit.lifetime = .keepAlways; add(audit)
        evidence(app, name: "actual-simulation-setting-reader-reduce-motion-off")
        hideControls(app); waitForBody(app)
        return settings
    }

    private func changeFont(_ app: XCUIApplication) throws -> FontChange {
        openModule("appearance", app: app)
        let stepper = app.steppers["reading-font-size"]
        reveal(stepper, identifier: "reading-font-size", towardBottom: false, app: app)
        let before = try XCTUnwrap(fontSize(stepper), "The actual native font stepper must expose one numeric 12...40 value")
        let increased = before < 40
        tapFontStepper(stepper, increase: increased, app: app)
        let expected = before + (increased ? 1 : -1)
        waitUntil("Real font stepper must change by exactly one to \(expected)", timeout: 5) { self.fontSize(stepper) == expected }
        hideControls(app); waitForBody(app)
        return FontChange(initial: before, increased: increased)
    }

    private func restoreSettings(_ original: DisplaySettings, fontChange: FontChange?, app: XCUIApplication) throws {
        openModule("appearance", app: app)
        if let fontChange {
            let stepper = app.steppers["reading-font-size"]
            reveal(stepper, identifier: "reading-font-size", towardBottom: false, app: app)
            let changed = fontChange.initial + (fontChange.increased ? 1 : -1)
            XCTAssertEqual(try XCTUnwrap(fontSize(stepper)), changed)
            tapFontStepper(stepper, increase: !fontChange.increased, app: app)
            waitUntil("Restore original numeric font through its real stepper", timeout: 5) { self.fontSize(stepper) == fontChange.initial }
        }
        choose("分页", picker: "reading-page-mode", towardBottom: true, app: app)
        choose(original.transition, picker: "reading-page-transition", towardBottom: true, app: app)
        let reduce = app.switches["reading-reduce-motion"]
        reveal(reduce, identifier: "reading-reduce-motion", towardBottom: true, app: app)
        setSwitch(reduce, to: original.reduceMotion)
        choose(original.mode, picker: "reading-page-mode", towardBottom: false, app: app)
        evidence(app, name: "original-reader-settings-restored-through-ui")
        hideControls(app); waitForBody(app)
    }

    private func selected(_ picker: XCUIElement, among choices: [String]) throws -> String {
        let description = picker.label + " " + (picker.value as? String ?? "")
        let matches = choices.filter { description.contains($0) }
        XCTAssertEqual(matches.count, 1, "The native picker must expose its actual selected value: " + description)
        return try XCTUnwrap(matches.first)
    }

    private func choose(_ value: String, picker id: String, towardBottom: Bool, app: XCUIApplication) {
        let picker = app.buttons[id]
        reveal(picker, identifier: id, towardBottom: towardBottom, app: app); picker.tap()
        let item = app.buttons[value]
        XCTAssertTrue(item.waitForExistence(timeout: 5), app.debugDescription); item.tap()
        waitUntil("Actual menu selection \(id)=\(value)", timeout: 5) {
            (picker.label + " " + (picker.value as? String ?? "")).contains(value)
        }
    }

    private func setSwitch(_ row: XCUIElement, to value: String) {
        if row.value as? String != value {
            let inner = row.switches.firstMatch
            let control = inner.exists ? inner : row
            XCTAssertTrue(control.isHittable && control.isEnabled); control.tap()
        }
        waitUntil("Actual reduce-motion switch value \(value)", timeout: 5) { row.value as? String == value }
    }

    private func fontSize(_ element: XCUIElement) -> Int? {
        let description = (element.value as? String ?? "") + " " + element.label
        let numbers = Set(description.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init))
        guard numbers.count == 1, let number = numbers.first, (12...40).contains(number) else { return nil }
        return number
    }

    private func tapFontStepper(_ element: XCUIElement, increase: Bool, app: XCUIApplication) {
        let action = element.buttons.matching(NSPredicate(format: increase
            ? "label CONTAINS[c] 'increment' OR label CONTAINS[c] 'increase' OR label CONTAINS '增加' OR label CONTAINS '递增'"
            : "label CONTAINS[c] 'decrement' OR label CONTAINS[c] 'decrease' OR label CONTAINS '减少' OR label CONTAINS '递减'")).firstMatch
        let evidence = XCTAttachment(string: "Actual native font=\(String(describing: fontSize(element))), frame=\(element.frame), increase=\(increase)\n" + app.debugDescription)
        evidence.name = "ebook-native-font-stepper-before-action"; evidence.lifetime = .keepAlways; add(evidence)
        if action.exists {
            XCTAssertTrue(action.isEnabled && action.isHittable); action.tap()
            return
        }
        let buttons = element.buttons.allElementsBoundByIndex.sorted { $0.frame.midX < $1.frame.midX }
        if buttons.count == 2 {
            let target = increase ? buttons[1] : buttons[0]
            XCTAssertTrue(target.isEnabled && target.isHittable); target.tap()
            return
        }
        guard buttons.isEmpty else { XCTFail("Unexpected native Stepper AX children; retain the actual hierarchy"); return }
        // compact-daily-a274's retained native recording established minus
        // left / plus right. Some SwiftUI versions expose only the grouped
        // Stepper; use its two real trailing 44pt segments, never a value write.
        XCTAssertTrue(element.isHittable && element.isEnabled)
        XCTAssertGreaterThanOrEqual(element.frame.width, 88)
        XCTAssertTrue(app.frame.contains(element.frame))
        element.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: increase ? -22 : -66, dy: 0)).tap()
    }

    private func reveal(_ target: XCUIElement, identifier: String, towardBottom: Bool, app: XCUIApplication) {
        for _ in 0..<16 {
            if target.exists && target.isHittable { return }
            var down = towardBottom
            if identifier.hasPrefix("chapter-"), let wanted = Int(identifier.dropFirst("chapter-".count)) {
                // Native directory scroll position survives closing/reopening
                // its controls. Read the actual visible canonical indices each
                // step, so chapter 3 -> 2 scrolls upwards rather than marching
                // to chapters 89...108 as the failed original driver did.
                let visible = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chapter-'"))
                    .allElementsBoundByIndex.filter(\.isHittable).compactMap { Int($0.identifier.dropFirst("chapter-".count)) }
                if let first = visible.min(), wanted < first { down = false }
                else if let last = visible.max(), wanted > last { down = true }
                else if target.exists {
                    down = target.frame.midY > app.frame.midY
                }
            }
            guard let viewport = scrollViewport(containing: identifier, app: app) else {
                XCTFail("No actual visible ScrollView contains \(identifier). " + app.debugDescription); return
            }
            if target.exists, !target.frame.isEmpty {
                // The font stepper is below the top of the actual appearance
                // content (R12 y1172), even when an older call site preferred
                // an upwards search. Use real clipped geometry every step.
                if target.frame.minY < viewport.minY { down = false }
                else if target.frame.maxY > viewport.maxY { down = true }
            }
            let margin = min(36, viewport.height * 0.15)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let high = origin.withOffset(CGVector(dx: viewport.midX - app.frame.minX, dy: viewport.minY + margin - app.frame.minY))
            let low = origin.withOffset(CGVector(dx: viewport.midX - app.frame.minX, dy: viewport.maxY - margin - app.frame.minY))
            if down { low.press(forDuration: 0.05, thenDragTo: high) }
            else { high.press(forDuration: 0.05, thenDragTo: low) }
            XCTAssertTrue(app.buttons["control-grabber"].exists && app.buttons["control-grabber"].isHittable,
                "A gesture wholly within the actual scroll clip must not dismiss its controls; viewport=\(viewport), target=\(identifier). " + app.debugDescription)
        }
        XCTFail("Real control did not become hittable: \(identifier). " + app.debugDescription)
    }

    private func scrollViewport(containing identifier: String, app: XCUIApplication) -> CGRect? {
        let ancestors = app.scrollViews.containing(.any, identifier: identifier).allElementsBoundByIndex
        var candidates = ancestors
        if candidates.isEmpty, identifier.hasPrefix("chapter-") {
            candidates = app.scrollViews.allElementsBoundByIndex.filter {
                $0.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chapter-'"))
                    .allElementsBoundByIndex.contains(where: \.isHittable)
            }
        }
        var selected: CGRect?
        for scroll in candidates {
            var viewport = scroll.frame.intersection(app.frame)
            guard !viewport.isNull, viewport.width > 80, viewport.height > 80 else { continue }
            let modules = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'control-module-'"))
                .allElementsBoundByIndex
            for module in modules where module.frame.minY > viewport.minY {
                viewport.size.height = min(viewport.maxY, module.frame.minY) - viewport.minY
            }
            guard viewport.height > 80 else { continue }
            if let previous = selected, viewport.height >= previous.height { continue }
            selected = viewport
        }
        return selected
    }

    private func advance(_ app: XCUIApplication, original: String, name: String) throws -> String {
        waitForBody(app)
        let body = ebookBody(app)
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.83, dy: 0.5)).press(forDuration: 0.08,
            thenDragTo: body.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.5)),
            withVelocity: .slow, thenHoldForDuration: 0.15)
        waitUntil("Qualified native release must change the actual prose passage", timeout: 30) {
            guard self.ebookBody(app).isHittable, let lines = try? self.ocr(app), lines.count >= 4 else { return false }
            return !self.normalized(lines.joined()).contains(original)
        }
        return try captureAnchor(app, name: name)
    }

    private func leaveReader(_ app: XCUIApplication) {
        openModule("home", app: app)
        let leave = app.buttons["leave-reader"]
        XCTAssertTrue(leave.waitForExistence(timeout: 5)); leave.tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 20))
    }

    private func captureAnchor(_ app: XCUIApplication, name: String) throws -> String {
        waitForBody(app)
        let lines = try ocr(app)
        XCTAssertGreaterThanOrEqual(lines.count, 4, "Original prose must be nonempty and actually visible")
        let anchor = String(normalized(lines.dropFirst().prefix(2).joined()).prefix(24))
        XCTAssertGreaterThanOrEqual(anchor.count, 18, "An empty title/cover is not a visible prose anchor")
        evidence(app, name: name)
        let text = XCTAttachment(string: lines.joined(separator: "\n") + "\nANCHOR=" + anchor)
        text.name = name + "-actual-viewport-OCR"; text.lifetime = .keepAlways; add(text)
        return anchor
    }

    private func assertVisible(_ anchor: String, app: XCUIApplication, name: String) throws {
        waitForBody(app)
        waitUntil("Actual original passage remains visible: " + name, timeout: 30) {
            guard self.ebookBody(app).isHittable, let lines = try? self.ocr(app) else { return false }
            return self.normalized(lines.joined()).contains(anchor)
        }
        XCTAssertTrue(normalized(try ocr(app).joined()).contains(anchor))
        evidence(app, name: name)
    }

    private func normalized(_ value: String) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }

    private func ocr(_ app: XCUIApplication) throws -> [String] {
        let source = try XCTUnwrap(app.screenshot().image.cgImage)
        let window = app.frame
        let visible = ebookBody(app).frame.intersection(window).insetBy(dx: 6, dy: 6)
        XCTAssertGreaterThan(visible.width, 100); XCTAssertGreaterThan(visible.height, 100)
        let crop = CGRect(x: (visible.minX - window.minX) * CGFloat(source.width) / window.width,
            y: (visible.minY - window.minY) * CGFloat(source.height) / window.height,
            width: visible.width * CGFloat(source.width) / window.width,
            height: visible.height * CGFloat(source.height) / window.height).integral
        let image = try XCTUnwrap(source.cropping(to: crop))
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate; request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).sorted {
            abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.01
                ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
        }.compactMap { $0.topCandidates(1).first?.string }
    }

    private func evidence(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    private func waitUntil(_ fact: String, timeout: TimeInterval, _ condition: @escaping () -> Bool) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: timeout), .completed, fact)
    }
}
