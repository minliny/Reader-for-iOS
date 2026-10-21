import XCTest
import UIKit
import Vision

/// Bind every result to the delivery owner's sealed build. The real TXT must be
/// provisioned; all Core operations, clipboard use and positions originate in
/// the real App UI. This runner never calls Runtime or reads UIPasteboard.
final class ReaderReadingToolsJourneyTests: XCTestCase {
    private let bookID = "book-local:aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5"
    private let title = "仙子请听我解释"
    private enum JourneyError: Error { case prerequisite, nativeSelection, missingOwnedRule }
    private var displayRestored = false
    override func setUpWithError() throws { continueAfterFailure = false }

    func testOriginalTXTSearchNativeCopyHighlightPreviewAndAutomaticPageConsumer() throws {
        let app = XCUIApplication(); app.launch()
        try importAndOpenOriginal(app)
        let originalDisplay = try configureDisplay(app)
        displayRestored = false
        addTeardownBlock {
            guard !self.displayRestored else { return }
            if app.state != .runningForeground { app.activate() }
            try self.restoreDisplay(originalDisplay, app: app)
            self.displayRestored = true
        }
        selectDayPaperForPaint(app)

        // Derive a real search needle from a different Core-backed chapter.
        // No fixture phrase, guessed title offset or synthetic progress is used.
        chooseChapter(2, seekStart: true, app: app)
        let chapterTwo = try screen(app)
        let needleLine = try XCTUnwrap(chapterTwo.lines.dropFirst().first { $0.text.count >= 14 })
        let needle = String(needleLine.text.prefix(10))
        XCTAssertGreaterThanOrEqual(needle.unicodeScalars.count, 8)
        chooseChapter(1, seekStart: true, app: app)
        let first = try anchor(app, name: "tools-real-txt-original-chapter1-start")
        try turn(app, awayFrom: first)
        let searchOrigin = try anchor(app, name: "tools-search-original-visible-position")
        openTool("正文搜索", app: app)
        replace(app.textFields["content-search-query"], with: needle)
        // Return submits this real field via onSubmit. Tapping the same
        // submit/stop button again while it runs would cancel the search.
        let hits = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'content-hit-'"))
        waitUntil("A real Core text search must return the actual chapter-2 needle", timeout: 45) {
            hits.count > 0 && !app.staticTexts["正在搜索正文"].exists
        }
        let hit = hits.matching(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
        XCTAssertTrue(hit.waitForExistence(timeout: 10), app.debugDescription)
        evidence(app, "tools-real-core-search-hit"); hit.tap()
        hideControls(app)
        try assertVisible(normalized(needle), app: app, name: "tools-real-search-hit-visible-quote")
        XCTAssertFalse(normalized(try screen(app).text).contains(searchOrigin), "Hit navigation must actually leave the original passage")
        assertChapter(2, app: app)
        openTool("正文搜索", app: app)
        let back = app.buttons["返回搜索前的位置"]
        XCTAssertTrue(back.waitForExistence(timeout: 5)); back.tap()
        hideControls(app)
        try assertVisible(searchOrigin, app: app, name: "tools-search-return-original-visible-position")
        assertChapter(1, app: app)

        // Copy through the system menu, then paste through the App's own note
        // field. A second actual selection must equal that copied text exactly.
        chooseChapter(1, seekStart: true, app: app)
        let native = try unpaintedNativeSelection(app)
        let beforeSelection = native.before, prose = native.line
        let selectionText = native.text
        XCTAssertEqual(app.staticTexts["annotation-selected-text"].label, selectionText)
        let note = textInput("annotation-note", app: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertTrue(isEmpty(note), "An existing note draft is preserved; this test may not overwrite it")
        note.tap(); note.press(forDuration: 0.8)
        try menuAction(["粘贴", "Paste"], app: app).tap()
        waitUntil("The system clipboard must paste the same actual native selection", timeout: 5) {
            note.value as? String == selectionText
        }
        XCTAssertEqual(note.value as? String, selectionText)
        let ownedNote = "原生工具旅程-" + UUID().uuidString
        note.typeText(" · " + ownedNote)
        // The notes form itself is not a ScrollView. Use its existing
        // single-line search input's native Return to leave multiline editing.
        let noteQuery = app.textFields["搜索笔记"]
        XCTAssertTrue(noteQuery.isHittable); noteQuery.tap(); noteQuery.typeText("\n")
        waitUntil("Native multiline note keyboard dismissed", timeout: 5) { !app.keyboards.firstMatch.exists }
        let selectedCrop = native.crop
        let context = try beforeSelection.context(startingAt: selectionText, in: prose, count: 20)
        let beforeBackground = native.background
        let saveNote = app.buttons["save-annotation"]
        reveal(saveNote, towardBottom: false, app: app); saveNote.tap()
        XCTAssertTrue(noteQuery.waitForExistence(timeout: 5)); replace(noteQuery, with: ownedNote)
        let annotations = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'annotation-' AND label CONTAINS %@", ownedNote))
        waitUntil("Exactly one owned Core annotation must be saved", timeout: 25) { annotations.count == 1 }
        let annotationID = annotations.firstMatch.identifier
        XCTAssertTrue(annotations.firstMatch.label.contains(selectionText))
        evidence(app, "tools-original-native-copy-and-saved-core-note")
        let ownership = XCTAttachment(string: "book=\(bookID)\nannotation=\(annotationID)\nnote=\(ownedNote)\nselected=\(selectionText)")
        ownership.name = "tools-owned-annotation-receipt-visible-identity"; ownership.lifetime = .keepAlways; add(ownership)
        hideControls(app)
        // A plain tap lets UIKit dismiss its selection handles; the saved
        // attributed highlight must survive independently of native selection.
        body(app).coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.88)).tap()
        if app.buttons["control-grabber"].isHittable { hideControls(app) }
        let noteAnchor = try anchor(app, name: "tools-annotated-original-visible-passage")
        leaveReader(app); app.terminate(); app.launch(); openBook(app)
        try assertVisible(noteAnchor, app: app, name: "tools-note-cold-reopened-original-passage")
        let coldPaint = try screen(app)
        let coldLine = try XCTUnwrap(coldPaint.lines.first { normalized($0.text) == normalized(prose.text) })
        let highlightedCrop = try coldPaint.wordImage(selectionText, in: coldLine)
        try assertPaintedHighlight(highlightedCrop, baseline: selectedCrop, against: beforeBackground)
        let paint = XCTAttachment(image: UIImage(cgImage: highlightedCrop))
        paint.name = "tools-cold-native-attributed-highlight-with-no-active-selection"; paint.lifetime = .keepAlways; add(paint)
        openTool("高亮与笔记", app: app)
        replace(app.textFields["搜索笔记"], with: ownedNote)
        let restoredNote = app.buttons[annotationID]
        XCTAssertTrue(restoredNote.waitForExistence(timeout: 25))
        XCTAssertTrue(restoredNote.label.contains(ownedNote) && restoredNote.label.contains(selectionText))
        restoredNote.tap(); hideControls(app)
        try assertVisible(context, app: app, name: "tools-persisted-note-jump-real-original-context")

        // Preview an owned literal rule and remove that exact Core rule before
        // any further chapter navigation. No reprocess is requested. Core scope
        // tokens match book name / origin (not book ID), hence the real title.
        chooseChapter(1, seekStart: true, app: app)
        try previewAndRemoveOwnedRule(selectionText, app: app)

        // Two separately observed new passages require the first native page
        // completion to be consumed before another request can be scheduled.
        chooseChapter(1, seekStart: true, app: app)
        try automaticPageConsumers(app)
        try restoreDisplay(originalDisplay, app: app)
        displayRestored = true
        leaveReader(app)
    }

    /// The earlier exact native journey already proved search/copy/notes and
    /// cold painting. Exercise its remaining real consumers without repeating
    /// those mutations or creating another annotation.
    func testExistingRealTXTReplacementAndAutomaticPagingAfterPriorNoteJourney() throws {
        guard ProcessInfo.processInfo.environment["READER_TOOLS_PRIOR_ORIGINAL_PAPER"] == "夜间" else {
            XCTFail("Root must bind the prior failed cleanup's actual original Night choice in the Runner only")
            throw JourneyError.prerequisite
        }
        let app = XCUIApplication(); app.launch(); openBook(app)
        // Restore only the paper this owned earlier measurement changed. Do
        // not overwrite an intervening selection of a different paper.
        openModule("appearance", app: app)
        let day = app.buttons["日间"], night = app.buttons["夜间"]
        reveal(night, towardBottom: false, app: app)
        guard day.isSelected || night.isSelected else {
            XCTFail("Preserve any intervening unowned paper selection")
            throw JourneyError.prerequisite
        }
        night.tap(); XCTAssertTrue(night.isSelected)
        evidence(app, "tools-prior-original-night-restored-through-native-control")
        hideControls(app)
        let originalDisplay = try configureDisplay(app)
        displayRestored = false
        addTeardownBlock {
            guard !self.displayRestored else { return }
            if app.state != .runningForeground { app.activate() }
            try self.restoreDisplay(originalDisplay, app: app)
            self.displayRestored = true
        }
        chooseChapter(1, seekStart: true, app: app)
        let actual = try screen(app)
        let bodyText = try XCTUnwrap(body(app).value as? String)
        let literal = try XCTUnwrap(actual.lines.lazy.flatMap { line -> [String] in
            let scalars = Array(line.text.unicodeScalars)
            return zip(scalars, scalars.dropFirst()).compactMap { first, second in
                guard (0x4E00...0x9FFF).contains(first.value), (0x4E00...0x9FFF).contains(second.value) else { return nil }
                return String(first) + String(second)
            }
        }.first(where: { bodyText.contains($0) }),
            "Use a real visible OCR word also present verbatim in the actual native text, never generated chapter text")
        try previewAndRemoveOwnedRule(literal, app: app)
        chooseChapter(1, seekStart: true, app: app)
        try automaticPageConsumers(app)
        try restoreDisplay(originalDisplay, app: app); displayRestored = true
        leaveReader(app)
    }

    /// Diagnose physical input separately from XCTest's AX hittability. The
    /// strict consumer journeys above retain their original failure contract.
    /// This method makes one read-only preview touch and never creates a rule.
    func testDiagnosticOriginalTXTVisiblePreviewSingleNativeTouchWithoutRuleMutation() throws {
        let app = XCUIApplication(); app.launch(); openBook(app)
        openTool("替换、字典与目录规则", app: app)
        waitUntil("The existing rule load must finish before measuring a physical control", timeout: 30) {
            !app.staticTexts["正在读取规则"].exists
        }
        XCTAssertFalse(app.staticTexts["规则工具尚未完成"].exists)
        let preview = app.buttons.matching(NSPredicate(format: "label == '预览已保存规则'"))
        XCTAssertEqual(preview.count, 1, "Use the one actual existing replacement preview control")
        let button = preview.element
        let viewports = app.scrollViews.allElementsBoundByIndex.filter { scroll in
            scroll.buttons.matching(NSPredicate(format: "label == '预览已保存规则'")).count == 1
                && scroll.frame.intersection(app.frame).height > 100
        }
        let scroll = try XCTUnwrap(viewports.min(by: { $0.frame.height < $1.frame.height }))
        let viewport = scroll.frame.intersection(app.frame).insetBy(dx: 4, dy: 4)
        var visible = false
        for _ in 0..<12 {
            if button.exists, button.frame.width > 0, button.frame.height > 0, viewport.contains(button.frame) {
                visible = true; break
            }
            let high = coordinate(CGPoint(x: viewport.midX, y: viewport.minY + 30), app: app)
            let low = coordinate(CGPoint(x: viewport.midX, y: viewport.maxY - 30), app: app)
            low.press(forDuration: 0.05, thenDragTo: high)
        }
        XCTAssertTrue(visible, "The actual unique preview label must be completely inside its real native scroll viewport")
        XCTAssertTrue(button.isEnabled)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertTrue(app.buttons["control-grabber"].label.hasPrefix("完整控制栏"))
        let frame = button.frame, secondFrame = button.frame
        XCTAssertLessThan(abs(frame.midX - secondFrame.midX), 0.5)
        XCTAssertLessThan(abs(frame.midY - secondFrame.midY), 0.5)
        let point = CGPoint(x: frame.midX, y: frame.midY)
        let reportedHittable = button.isHittable
        let observation = XCTAttachment(string: "diagnosticOnly=true\nAXHittable=\(reportedHittable)\nactualButtonFrame=\(frame)\nactualScrollViewport=\(viewport)\nsingleNativeTouchPoint=\(point)\nNo rule save, deletion, draft edit, direct Runner Core call or retry. This cannot promote either strict consumer's earlier failure to PASS.")
        observation.name = "tools-preview-single-physical-touch-diagnostic-boundary"; observation.lifetime = .keepAlways; add(observation)
        evidence(app, "tools-preview-visible-before-one-diagnostic-touch")
        let finalViewport = scroll.frame.intersection(app.frame).insetBy(dx: 4, dy: 4)
        let finalFrame = button.frame
        guard preview.count == 1, button.isEnabled, finalViewport.contains(finalFrame),
              finalFrame.width > 0, finalFrame.height > 0,
              abs(frame.midX - finalFrame.midX) < 0.5, abs(frame.midY - finalFrame.midY) < 0.5,
              !app.staticTexts["正在读取规则"].exists, !app.staticTexts["规则工具尚未完成"].exists,
              !app.keyboards.firstMatch.exists, app.alerts.count == 0,
              app.buttons["control-grabber"].label.hasPrefix("完整控制栏") else {
            XCTFail("The same actual preview moved or became unavailable before the one diagnostic touch")
            throw JourneyError.prerequisite
        }
        coordinate(CGPoint(x: finalFrame.midX, y: finalFrame.midY), app: app).tap()
        let before = app.staticTexts["replacement-preview-before"]
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline && !(before.exists && before.isHittable) {
            let high = coordinate(CGPoint(x: viewport.midX, y: viewport.minY + 30), app: app)
            let low = coordinate(CGPoint(x: viewport.midX, y: viewport.maxY - 30), app: app)
            low.press(forDuration: 0.05, thenDragTo: high)
        }
        evidence(app, "tools-preview-after-one-diagnostic-touch")
        XCTAssertTrue(before.exists && before.isHittable && !before.label.isEmpty,
                      "Only an actual visible Core preview result can establish that this single physical touch reached its consumer")
        leaveReader(app)
    }

    private struct UnpaintedNativeSelection {
        let before: Screen
        let line: Line
        let text: String
        let crop: CGImage
        let background: [Int]
    }

    private func unpaintedNativeSelection(_ app: XCUIApplication) throws -> UnpaintedNativeSelection {
        let initial = try screen(app)
        let candidates = Array(initial.lines.dropFirst().filter { $0.text.count >= 14 }.prefix(6))
        XCTAssertFalse(candidates.isEmpty, "Use real visible long prose, never generated or substituted text")
        for (offset, candidate) in candidates.enumerated() {
            let before = try screen(app)
            let prose = try XCTUnwrap(before.lines.first { normalized($0.text) == normalized(candidate.text) },
                "Trying another visible word must not navigate or replace the original page")
            let point = before.point(in: prose.box, xFraction: 0.27)
            coordinate(point, app: app).press(forDuration: 0.8)
            try menuAction(["拷贝", "复制", "Copy"], app: app).tap()
            coordinate(point, app: app).press(forDuration: 0.8)
            try menuAction(["高亮与笔记"], app: app).tap()
            let selected = app.staticTexts["annotation-selected-text"]
            XCTAssertTrue(selected.waitForExistence(timeout: 10))
            let text = selected.label
            XCTAssertGreaterThanOrEqual(text.count, 1)
            XCTAssertLessThanOrEqual(text.count, 80)
            let note = textInput("annotation-note", app: app)
            XCTAssertTrue(note.waitForExistence(timeout: 5))
            guard isEmpty(note), app.buttons["save-annotation"].label == "高亮并保存笔记" else {
                XCTFail("An existing note draft/edit must be preserved; do not close, replace or save it")
                throw JourneyError.prerequisite
            }

            // A repeated OCR word cannot identify the native-selected occurrence
            // precisely. Only accept a uniquely mapped original word ROI.
            let unique = !text.isEmpty && prose.text.components(separatedBy: text).count == 2
            if unique {
                let crop = try before.wordImage(text, in: prose)
                let margin = try before.paperMarginImage(near: prose)
                let paper = try backgroundColour(margin), word = try backgroundColour(crop)
                // Compare segments too, rejecting localized background changes
                // that a single whole-word modal colour could conceal.
                let partCount = min(4, crop.width)
                var partBackgrounds: [[Int]] = []
                for part in 0..<partCount {
                    let left = part * crop.width / partCount, right = (part + 1) * crop.width / partCount
                    let image = try XCTUnwrap(crop.cropping(to: CGRect(x: CGFloat(left), y: 0,
                        width: CGFloat(right - left), height: CGFloat(crop.height))))
                    partBackgrounds.append(try backgroundColour(image))
                }
                let eligible = word == paper && !partBackgrounds.isEmpty && partBackgrounds.allSatisfy { $0 == paper }
                let facts = XCTAttachment(string: "candidate=\(offset + 1)\nselected=\(text)\noriginalLine=\(prose.text)\nwordBackground=\(word)\nwordPartBackgrounds=\(partBackgrounds)\nblankMarginBackground=\(paper)\nunpainted=\(eligible)")
                facts.name = "tools-native-candidate-\(offset + 1)-actual-baseline"; facts.lifetime = .keepAlways; add(facts)
                for (name, image) in [("word-before-selection", crop), ("adjacent-blank-paper-margin", margin)] {
                    let attachment = XCTAttachment(image: UIImage(cgImage: image))
                    attachment.name = "tools-native-candidate-\(offset + 1)-" + name; attachment.lifetime = .keepAlways; add(attachment)
                }
                if eligible {
                    let original = XCTAttachment(image: UIImage(cgImage: before.image))
                    original.name = "tools-accepted-unpainted-original-before-selection"; original.lifetime = .keepAlways; add(original)
                    return UnpaintedNativeSelection(before: before, line: prose, text: text, crop: crop, background: word)
                }
            } else {
                let facts = XCTAttachment(string: "candidate=\(offset + 1)\nselected=\(text)\noriginalLine=\(prose.text)\nrejected=Native selection has no unique original OCR word ROI")
                facts.name = "tools-native-candidate-\(offset + 1)-ambiguous-original-ROI"; facts.lifetime = .keepAlways; add(facts)
            }

            // Nothing was typed or saved. Close only this empty new editor, then
            // use the same actual outside tap that cleared selection in Tools 4.
            XCTAssertTrue(isEmpty(note))
            hideControls(app)
            body(app).coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.88)).tap()
            if app.buttons["control-grabber"].isHittable { hideControls(app) }
        }
        XCTFail("No uniquely mapped, unhighlighted word among the finite real visible prose candidates; preserve every existing note")
        throw JourneyError.prerequisite
    }

    private func previewAndRemoveOwnedRule(_ literal: String, app: XCUIApplication) throws {
        openTool("替换、字典与目录规则", app: app)
        let kind = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '规则类型'")).firstMatch
        XCTAssertTrue(kind.waitForExistence(timeout: 10)); kind.tap()
        XCTAssertTrue(app.buttons["替换"].waitForExistence(timeout: 5)); app.buttons["替换"].tap()
        let preview = app.buttons["预览已保存规则"]
        reveal(preview, towardBottom: true, app: app); preview.tap()
        let before = app.staticTexts["replacement-preview-before"]
        let after = app.staticTexts["replacement-preview-after"]
        waitUntil("Read the actual existing Core preview before adding an owned rule", timeout: 25) {
            before.exists && after.exists && !before.label.isEmpty && !after.label.isEmpty
        }
        let originalRaw = before.label, originalProcessed = after.label
        XCTAssertTrue(originalProcessed.contains(literal), "The real displayed copied text must be in the bounded actual chapter preview")
        let create = app.buttons["新建"]
        reveal(create, towardBottom: false, app: app); create.tap()
        let existingDraft = app.alerts["替换当前草稿？"]
        if existingDraft.waitForExistence(timeout: 1) {
            existingDraft.buttons["取消"].tap()
            XCTFail("An existing unowned rule draft is preserved; a clean owned test draft is required")
            throw JourneyError.prerequisite
        }
        let ownedName = "原生预览-" + UUID().uuidString
        let replacement = "ReaderPreview" + String(UUID().uuidString.prefix(8))
        try fill("规则名称", ownedName, towardBottom: false, app: app)
        try fill("匹配内容", literal, app: app)
        try fill("替换为", replacement, app: app)
        try fill("作用范围，留空为全部", title, app: app)
        setToggle("正则表达式", value: "0", app: app)
        setToggle("作用于正文", value: "1", app: app)
        setToggle("作用于标题", value: "0", app: app)
        setToggle("作用于书源", value: "0", app: app)
        setToggle("启用此规则", value: "1", app: app)
        let save = app.buttons["保存规则"]; reveal(save, towardBottom: true, app: app); save.tap()
        let owned = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'replace-rule-' AND label == %@", ownedName)).firstMatch
        reveal(owned, towardBottom: false, app: app)
        XCTAssertTrue(owned.waitForExistence(timeout: 25), app.debugDescription)
        let ruleID = String(owned.identifier.dropFirst("replace-rule-".count))
        guard !ruleID.isEmpty, Int64(ruleID) != nil else { throw JourneyError.missingOwnedRule }
        let ownership = XCTAttachment(string: "ownedRuleID=\(ruleID)\nname=\(ownedName)\nscopeBookName=\(title)\nliteral=\(literal)\nreplacement=\(replacement)\nOnly this exact newly created rule may be deleted.")
        ownership.name = "tools-owned-rule-ui-identity-for-cleanup"; ownership.lifetime = .keepAlways; add(ownership)
        // Keep cleanup armed even if a later throwing image/OCR operation fails.
        // Assertions remain failures; a successful cleanup never changes that.
        var deleted = false
        defer { if !deleted { removeOwnedRule(ruleID, name: ownedName, app: app) } }
        reveal(preview, towardBottom: true, app: app); preview.tap()
        waitUntil("Real Core preview must consume the owned saved rule", timeout: 25) {
            before.exists && after.exists && before.label.contains(literal) && after.label.contains(replacement)
        }
        XCTAssertEqual(before.label, originalRaw, "Previewing a rule cannot rewrite the original chapter")
        XCTAssertNotEqual(before.label, after.label)
        let previewText = XCTAttachment(string: "BEFORE:\n" + before.label + "\nAFTER:\n" + after.label)
        previewText.name = "tools-real-core-owned-replacement-preview"; previewText.lifetime = .keepAlways; add(previewText)
        evidence(app, "tools-real-rule-preview-consumer")
        removeOwnedRule(ruleID, name: ownedName, app: app); deleted = true
        reveal(preview, towardBottom: true, app: app); preview.tap()
        waitUntil("Deleting the exact owned rule must remove its real preview effect", timeout: 25) {
            before.exists && before.label == originalRaw && after.exists && !after.label.contains(replacement) && after.label == originalProcessed
        }
        // The only discarded draft is this method's exact UUID-owned draft.
        let name = textInput("规则名称", app: app)
        reveal(name, towardBottom: false, app: app)
        XCTAssertEqual(name.value as? String, ownedName)
        reveal(create, towardBottom: true, app: app); create.tap()
        let discardOwned = app.alerts["替换当前草稿？"]
        if discardOwned.waitForExistence(timeout: 1) { discardOwned.buttons["替换"].tap() }
        reveal(name, towardBottom: false, app: app)
        XCTAssertTrue(isEmpty(name), "The owned rule draft must also be cleared after cleanup")
        hideControls(app)
    }

    private func removeOwnedRule(_ id: String, name: String, app: XCUIApplication) {
        let row = app.buttons["replace-rule-" + id]
        reveal(row, towardBottom: false, app: app)
        XCTAssertEqual(row.label, name, "Never delete an unowned rule")
        let remove = app.buttons["delete-replace-rule-" + id]
        XCTAssertTrue(remove.isHittable); remove.tap()
        let alert = app.alerts["删除规则"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts[name].exists, "Native confirmation must name the same owned rule")
        alert.buttons["删除"].tap()
        waitUntil("Only the exact owned Core rule is removed", timeout: 25) { !row.exists }
    }

    private func automaticPageConsumers(_ app: XCUIApplication) throws {
        let baseline = try anchor(app, name: "tools-before-actual-auto-consumer")
        openTool("自动翻页", app: app)
        let stop = app.buttons["auto-page-stop"]
        if stop.isEnabled { stop.tap() }
        let wheels = app.pickerWheels
        XCTAssertEqual(wheels.count, 2)
        let minute = wheels.element(boundBy: 0), second = wheels.element(boundBy: 1)
        reveal(minute, towardBottom: false, app: app)
        let oldMinute = try XCTUnwrap(minute.value as? String), oldSecond = try XCTUnwrap(second.value as? String)
        minute.adjust(toPickerWheelValue: "00 分"); second.adjust(toPickerWheelValue: "45 秒")
        let speed = app.sliders["自动翻页速度"]
        reveal(speed, towardBottom: true, app: app)
        let oldSpeed = try sliderFraction(speed)
        speed.adjust(toNormalizedSliderPosition: 1.0 / 18.0) // Native 2...20 step 1 => 3 seconds.
        XCTAssertTrue(app.staticTexts["3 秒"].exists, "Read the actual selected UI speed before testing its consumer")
        let toggle = app.buttons["auto-page-toggle"]
        reveal(toggle, towardBottom: false, app: app)
        let initialProgress = app.staticTexts["reading-progress"].label
        XCTAssertEqual(toggle.label, "开始自动翻页"); toggle.tap()
        waitUntil("First actual automatic page must change visible text", timeout: 18) {
            guard let capture = try? self.screen(app), capture.lines.count >= 4 else { return false }
            return !self.normalized(capture.text).contains(baseline) && app.staticTexts["reading-progress"].label != initialProgress
        }
        let first = try anchor(app, name: "tools-first-real-auto-native-commit")
        let firstProgress = app.staticTexts["reading-progress"].label
        waitUntil("A second actual page requires the first native ACK to be consumed", timeout: 18) {
            guard let capture = try? self.screen(app), capture.lines.count >= 4 else { return false }
            return !self.normalized(capture.text).contains(first) && app.staticTexts["reading-progress"].label != firstProgress
        }
        _ = try anchor(app, name: "tools-second-real-auto-native-commit")
        // Real centre tap pauses the owner. No Runtime phase is injected.
        body(app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        if app.buttons["control-grabber"].isHittable { hideControls(app) }
        let paused = try anchor(app, name: "tools-manually-paused-visible-passage")
        try assertStable(paused, interval: 4.5, app: app, name: "tools-pause-consumed-beyond-selected-speed")
        openTool("自动翻页", app: app)
        XCTAssertEqual(toggle.label, "继续自动翻页")
        stop.tap()
        waitUntil("The real stop action must reset the auto owner", timeout: 5) { toggle.label == "开始自动翻页" }
        hideControls(app)
        let stopped = try anchor(app, name: "tools-stopped-visible-passage")
        try assertStable(stopped, interval: 4.5, app: app, name: "tools-stop-rejects-future-page-consumer")
        openTool("自动翻页", app: app)
        reveal(minute, towardBottom: false, app: app)
        minute.adjust(toPickerWheelValue: oldMinute); second.adjust(toPickerWheelValue: oldSecond)
        reveal(speed, towardBottom: true, app: app); speed.adjust(toNormalizedSliderPosition: oldSpeed)
        XCTAssertEqual(try sliderFraction(speed), oldSpeed, accuracy: 0.015)
        XCTAssertEqual(minute.value as? String, oldMinute); XCTAssertEqual(second.value as? String, oldSecond)
        evidence(app, "tools-original-auto-configuration-restored")
        hideControls(app)
    }

    private struct Display { let mode: String; let transition: String; let selectable: String; let paper: String }
    private func configureDisplay(_ app: XCUIApplication) throws -> Display {
        openModule("appearance", app: app)
        let papers = ["日间", "暖白", "夜间", "暖夜", "纸纹", "青叶纹", "靛夜", "林夜纹"] as NSArray
        let selectedPapers = app.buttons.matching(NSPredicate(format: "label IN %@", papers))
            .allElementsBoundByIndex.filter(\.isSelected)
        XCTAssertEqual(selectedPapers.count, 1, "Preserve the actual original paper before this contrast-specific paint measurement")
        let oldPaper = try XCTUnwrap(selectedPapers.first).label
        let mode = app.buttons["reading-page-mode"]
        reveal(mode, towardBottom: true, app: app)
        let oldMode = try menuValue(mode, choices: ["滚动", "分页"])
        choose("分页", picker: mode, app: app)
        let transition = app.buttons["reading-page-transition"]
        reveal(transition, towardBottom: true, app: app)
        let oldTransition = try menuValue(transition, choices: ["仿真", "覆盖", "滑动", "无动画"])
        choose("滑动", picker: transition, app: app)
        let selectable = app.switches["长按选择文本"]
        reveal(selectable, towardBottom: true, app: app)
        let oldSelectable = try XCTUnwrap(selectable.value as? String)
        setSwitch(selectable, to: "1")
        hideControls(app)
        return Display(mode: oldMode, transition: oldTransition, selectable: oldSelectable, paper: oldPaper)
    }
    private func selectDayPaperForPaint(_ app: XCUIApplication) {
        // The frozen night selection composites to RGB(52,46,38) over paper
        // RGB(43,40,35), a real distance18. The unchanged >=36/.12 metric is
        // meaningful on the actual day paper; it cannot reject night painting
        // merely for using the approved subtle night colour. Teardown is
        // registered before this paper change, including for fail-fast asserts.
        openModule("appearance", app: app)
        let day = app.buttons["日间"]
        reveal(day, towardBottom: false, app: app); day.tap()
        XCTAssertTrue(day.isSelected)
        evidence(app, "tools-actual-day-paper-contrast-prerequisite")
        hideControls(app)
    }
    private func restoreDisplay(_ old: Display, app: XCUIApplication) throws {
        openModule("appearance", app: app)
        let mode = app.buttons["reading-page-mode"]
        reveal(mode, towardBottom: true, app: app); choose("分页", picker: mode, app: app)
        let transition = app.buttons["reading-page-transition"]
        reveal(transition, towardBottom: true, app: app); choose(old.transition, picker: transition, app: app)
        let selectable = app.switches["长按选择文本"]
        reveal(selectable, towardBottom: true, app: app); setSwitch(selectable, to: old.selectable)
        reveal(mode, towardBottom: false, app: app); choose(old.mode, picker: mode, app: app)
        let paper = app.buttons[old.paper]
        reveal(paper, towardBottom: false, app: app); paper.tap()
        XCTAssertTrue(paper.isSelected, "Restore the original paper through its normal visible control even after a failed test")
        evidence(app, "tools-original-reader-display-restored"); hideControls(app)
    }

    private func importAndOpenOriginal(_ app: XCUIApplication) throws {
        if app.buttons["书架"].waitForExistence(timeout: 10) { app.buttons["书架"].tap() }
        neutralShelf(app)
        app.buttons["更多书架操作"].tap(); app.buttons["import-book"].tap()
        let files = app.cells.containing(NSPredicate(format: "label == %@ OR label == %@", title, title + ".txt"))
        if !files.firstMatch.waitForExistence(timeout: 3) {
            let reader = app.cells.matching(NSPredicate(format: "identifier == 'Reader, Container' OR label BEGINSWITH 'Reader,'")).firstMatch
            XCTAssertTrue(reader.waitForExistence(timeout: 10), "Provision the real original TXT, not a generated substitute"); reader.tap()
        }
        XCTAssertTrue(files.firstMatch.waitForExistence(timeout: 15)); XCTAssertEqual(files.count, 1)
        evidence(app, "tools-real-original-system-picker"); files.firstMatch.tap()
        if app.buttons["打开"].waitForExistence(timeout: 2) { app.buttons["打开"].tap() }
        XCTAssertTrue(app.buttons["关闭导入结果"].waitForExistence(timeout: 20))
        let result = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '已导入书架' OR label CONTAINS '这本书已在书架中'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 180), app.debugDescription)
        app.buttons["关闭导入结果"].tap(); openBook(app)
    }
    private func neutralShelf(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 20))
        if app.textFields["shelf-filter"].exists { app.buttons["搜索本地书架"].tap() }
        if !app.buttons["全部分组"].exists {
            let sorts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '默认顺序' OR label BEGINSWITH '加入时间' OR label BEGINSWITH '最近阅读' OR label BEGINSWITH '书名' OR label BEGINSWITH '作者'"))
            let sort = sorts.allElementsBoundByIndex.filter(\.isHittable).sorted {
                abs($0.frame.midY - $1.frame.midY) < 10 ? $0.frame.maxX > $1.frame.maxX : $0.frame.midY < $1.frame.midY
            }.first
            guard let sort else { XCTFail("Actual shelf sort/group row missing"); return }
            let group = app.buttons.allElementsBoundByIndex.filter { $0.isHittable && $0.frame.maxX < sort.frame.minX && abs($0.frame.midY - sort.frame.midY) < 10 }
            XCTAssertEqual(group.count, 1); group.first?.tap()
            XCTAssertTrue(app.buttons["全部分组"].waitForExistence(timeout: 5)); app.buttons["全部分组"].tap()
        }
    }
    private func openBook(_ app: XCUIApplication) {
        neutralShelf(app)
        let book = app.buttons[bookID]; XCTAssertTrue(book.waitForExistence(timeout: 20)); book.tap()
        XCTAssertTrue(body(app).waitForExistence(timeout: 30))
    }
    private func body(_ app: XCUIApplication) -> XCUIElement { app.textViews["reading-body"] }
    private func openModule(_ module: String, app: XCUIApplication) {
        let grabber = app.buttons["control-grabber"]
        if !grabber.exists {
            body(app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
            XCTAssertTrue(grabber.waitForExistence(timeout: 5))
        }
        // Full's invisible module bar is not a navigation entry. Establish the
        // real Quick endpoint before asking for a visible module button.
        if grabber.label.hasPrefix("完整控制栏") {
            grabber.tap()
            waitUntil("Actual Quick endpoint before module navigation", timeout: 5) {
                grabber.label.hasPrefix("快捷控制栏")
            }
        }
        let button = app.buttons["control-module-" + module]
        XCTAssertTrue(button.waitForExistence(timeout: 5)); XCTAssertTrue(button.isHittable); button.tap()
        if module != "home" {
            if !grabber.label.hasPrefix("完整控制栏") { grabber.tap() }
            waitUntil("Actual full reading controls", timeout: 5) { grabber.label.hasPrefix("完整控制栏") }
        }
    }
    private func openTool(_ name: String, app: XCUIApplication) {
        openModule("settings", app: app)
        let action = app.buttons[name]; XCTAssertTrue(action.waitForExistence(timeout: 5)); action.tap()
        waitUntil("Nested actual reading tool", timeout: 5) { app.buttons["control-grabber"].label.hasPrefix("完整控制栏") }
    }
    private func hideControls(_ app: XCUIApplication) {
        let hide = app.buttons["收起阅读控制"]
        XCTAssertTrue(hide.waitForExistence(timeout: 5)); hide.tap()
        waitUntil("Reading controls dismissed", timeout: 5) { !app.buttons["control-grabber"].isHittable }
    }
    private func chooseChapter(_ index: Int, seekStart: Bool, app: XCUIApplication) {
        openModule("directory", app: app)
        let directory = app.buttons.matching(NSPredicate(format: "label == '目录' AND identifier != 'control-module-directory'")).firstMatch
        XCTAssertTrue(directory.waitForExistence(timeout: 5)); directory.tap()
        let query = app.textFields["directory-query"]
        if query.exists && !isEmpty(query) { replace(query, with: "") }
        let chapter = app.buttons["chapter-\(index)"]; reveal(chapter, towardBottom: true, chapterIndex: index, app: app)
        XCTAssertTrue(chapter.isEnabled && chapter.isHittable); chapter.tap()
        waitUntil("Canonical chapter \(index) selected", timeout: 25) { chapter.isSelected }
        if seekStart { app.buttons["章首"].tap() }
        hideControls(app)
    }
    private func assertChapter(_ index: Int, app: XCUIApplication) {
        openModule("directory", app: app)
        let chapter = app.buttons["chapter-\(index)"]
        reveal(chapter, towardBottom: true, chapterIndex: index, app: app)
        XCTAssertTrue(chapter.isSelected, "Check the actual jump without selecting a new chapter")
        hideControls(app)
    }
    private func leaveReader(_ app: XCUIApplication) {
        openModule("home", app: app); app.buttons["leave-reader"].tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 20))
    }
    private func turn(_ app: XCUIApplication, awayFrom old: String) throws {
        body(app).swipeLeft()
        waitUntil("Real page must change", timeout: 20) {
            guard let text = try? self.screen(app).text else { return false }; return !self.normalized(text).contains(old)
        }
    }
    private func menuAction(_ labels: [String], app: XCUIApplication) throws -> XCUIElement {
        for _ in 0..<4 {
            for label in labels {
                for item in [app.buttons[label], app.menuItems[label]] {
                    if item.waitForExistence(timeout: 0.5) && item.isHittable { return item }
                }
            }
            // The retained native iOS menu exposes its next-page arrow as
            // “前进”; its Copy item is “拷贝” on this actual system locale.
            let more = ["前进", "显示更多项目", "Show more items", "更多", "More"].map { app.buttons[$0] }.first { $0.exists && $0.isHittable }
            if let more { more.tap() }
        }
        XCTFail("Actual native edit menu missing: " + labels.joined(separator: "/"))
        throw JourneyError.nativeSelection
    }
    private func replace(_ field: XCUIElement, with value: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        if !isEmpty(field) { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count)) }
        field.typeText(value + "\n")
    }
    private func isEmpty(_ field: XCUIElement) -> Bool {
        let value = field.value as? String ?? ""; return value.isEmpty || value == field.placeholderValue
    }
    private func fill(_ placeholder: String, _ text: String, towardBottom: Bool = true, app: XCUIApplication) throws {
        let field = textInput(placeholder, app: app); reveal(field, towardBottom: towardBottom, app: app)
        XCTAssertTrue(field.exists); field.tap()
        if !isEmpty(field) { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count)) }
        // Axis.vertical text fields treat Return as content. Do not silently
        // append a newline to the real literal/replacement/scope definitions.
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text)
        dismissKeyboardByScrolling(app)
    }
    private func textInput(_ identifier: String, app: XCUIApplication) -> XCUIElement {
        // SwiftUI axis.vertical can expose a native text view on iOS. Restrict
        // to real editable AX roles while retaining the production identifier.
        app.descendants(matching: .any).matching(identifier: identifier).matching(NSPredicate(
            format: "elementType == %d OR elementType == %d", Int(XCUIElement.ElementType.textField.rawValue),
            Int(XCUIElement.ElementType.textView.rawValue))).firstMatch
    }
    private func dismissKeyboardByScrolling(_ app: XCUIApplication) {
        guard app.keyboards.firstMatch.exists else { return }
        let hide = app.buttons.matching(NSPredicate(format: "label == '隐藏键盘' OR label == 'Hide keyboard' OR label == 'Dismiss keyboard'")).firstMatch
        if hide.exists && hide.isHittable { hide.tap(); return }
        // Native SwiftUI ScrollView keyboard dismissal, in the actual panel
        // viewport above the keyboard; no responder or App-state injection.
        let highY = app.buttons["control-grabber"].frame.maxY + 65
        let lowY = min(app.keyboards.firstMatch.frame.minY - 25, highY + 180)
        XCTAssertGreaterThan(lowY, highY + 20, "The real panel must have room to dismiss its keyboard")
        coordinate(CGPoint(x: app.frame.midX, y: lowY), app: app).press(forDuration: 0.05,
            thenDragTo: coordinate(CGPoint(x: app.frame.midX, y: highY), app: app))
        waitUntil("Native keyboard dismissed by real panel scroll", timeout: 5) { !app.keyboards.firstMatch.exists }
    }
    private func choose(_ value: String, picker: XCUIElement, app: XCUIApplication) {
        picker.tap(); XCTAssertTrue(app.buttons[value].waitForExistence(timeout: 5)); app.buttons[value].tap()
        waitUntil("Actual picker selected " + value, timeout: 5) { (picker.label + " " + (picker.value as? String ?? "")).contains(value) }
    }
    private func menuValue(_ picker: XCUIElement, choices: [String]) throws -> String {
        let text = picker.label + " " + (picker.value as? String ?? "")
        let values = choices.filter { text.contains($0) }; XCTAssertEqual(values.count, 1)
        return try XCTUnwrap(values.first)
    }
    private func setToggle(_ name: String, value: String, app: XCUIApplication) {
        let row = app.switches[name]; reveal(row, towardBottom: true, app: app); setSwitch(row, to: value)
    }
    private func setSwitch(_ row: XCUIElement, to value: String) {
        if row.value as? String != value {
            let inner = row.switches.firstMatch, control = inner.exists ? inner : row
            XCTAssertTrue(control.isHittable && control.isEnabled); control.tap()
        }
        waitUntil("Native switch actually changed", timeout: 5) { row.value as? String == value }
    }
    private func sliderFraction(_ slider: XCUIElement) throws -> CGFloat {
        let text = try XCTUnwrap(slider.value as? String).replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        let value = try XCTUnwrap(Double(text)); XCTAssertTrue((0...100).contains(value)); return CGFloat(value / 100)
    }
    private func reveal(_ target: XCUIElement, towardBottom: Bool, chapterIndex: Int? = nil, app: XCUIApplication) {
        for _ in 0..<24 {
            if target.exists && target.isHittable { return }
            var down = towardBottom
            if let wanted = chapterIndex {
                // Directory scrolling survives closing its controls. Choose
                // direction from the real visible canonical rows on every
                // step, including the search return from chapter 2 to 1.
                let visible = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chapter-'"))
                    .allElementsBoundByIndex.filter(\.isHittable).compactMap { Int($0.identifier.dropFirst("chapter-".count)) }
                if let first = visible.min(), wanted < first { down = false }
                else if let last = visible.max(), wanted > last { down = true }
                else if target.exists { down = target.frame.midY > app.frame.midY }
            }
            let viewport: CGRect
            if let chapterIndex {
                guard let actual = directoryViewport(chapterIndex: chapterIndex, app: app) else {
                    XCTFail("No actual visible directory ScrollView contains canonical rows: " + app.debugDescription); return
                }
                viewport = actual
            } else {
                let top = app.buttons["control-grabber"].frame.maxY + 70
                viewport = CGRect(x: app.frame.minX, y: top, width: app.frame.width,
                    height: min(app.frame.maxY - 45, top + 240) - top)
            }
            let inset = chapterIndex == nil ? CGFloat.zero : min(36, viewport.height * 0.15)
            let top = viewport.minY + inset, bottom = viewport.maxY - inset
            XCTAssertGreaterThan(bottom, top + 30)
            let high = coordinate(CGPoint(x: viewport.midX, y: top), app: app)
            let low = coordinate(CGPoint(x: viewport.midX, y: bottom), app: app)
            if down { low.press(forDuration: 0.05, thenDragTo: high) }
            else { high.press(forDuration: 0.05, thenDragTo: low) }
        }
        XCTFail("Actual control did not become hittable: " + target.debugDescription)
    }
    private func directoryViewport(chapterIndex: Int, app: XCUIApplication) -> CGRect? {
        let ancestors = app.scrollViews.containing(.button, identifier: "chapter-\(chapterIndex)").allElementsBoundByIndex
        let candidates = ancestors + app.scrollViews.allElementsBoundByIndex
        var selected: CGRect?
        for scroll in candidates {
            var viewport = scroll.frame.intersection(app.frame)
            guard !viewport.isNull, viewport.width > 80, viewport.height > 80 else { continue }
            let rows = scroll.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chapter-'"))
                .allElementsBoundByIndex
            guard rows.contains(where: { $0.isHittable && viewport.intersects($0.frame) }) else { continue }
            // The native module bar overlays the lower directory viewport.
            // Both ends of the gesture must stay in the real scroll area.
            let modules = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'control-module-'"))
                .allElementsBoundByIndex.filter(\.isHittable)
            for module in modules where module.frame.minY > viewport.minY {
                viewport.size.height = min(viewport.maxY, module.frame.minY) - viewport.minY
            }
            guard viewport.height > 80 else { continue }
            if let previous = selected, viewport.height >= previous.height { continue }
            selected = viewport
        }
        return selected
    }
    private func coordinate(_ point: CGPoint, app: XCUIApplication) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x - app.frame.minX, dy: point.y - app.frame.minY))
    }

    private struct Line {
        let candidate: VNRecognizedText
        let box: CGRect
        var text: String { candidate.string }
    }
    private struct Screen {
        let image: CGImage
        let pixelCrop: CGRect
        let viewport: CGRect
        let lines: [Line]
        var text: String { lines.map(\.text).joined() }
        func point(in box: CGRect, xFraction: CGFloat) -> CGPoint {
            CGPoint(x: viewport.minX + (box.minX + box.width * xFraction) * viewport.width,
                y: viewport.minY + (1 - box.midY) * viewport.height)
        }
        func wordImage(_ word: String, in line: Line) throws -> CGImage {
            let range = try XCTUnwrap(line.text.range(of: word), "Native copied word must be found in actual preselection OCR")
            let observation = try XCTUnwrap(try line.candidate.boundingBox(for: range))
            let box = observation.boundingBox
            let rect = CGRect(x: pixelCrop.minX + box.minX * pixelCrop.width,
                y: pixelCrop.minY + (1 - box.maxY) * pixelCrop.height,
                width: box.width * pixelCrop.width, height: box.height * pixelCrop.height).integral
            return try XCTUnwrap(image.cropping(to: rect))
        }
        func paperMarginImage(near line: Line) throws -> CGImage {
            // This is the actual left paper margin beside the same OCR line,
            // outside all of its glyphs; no theme colour or App state is read.
            let left = pixelCrop.minX + 2
            let textLeft = pixelCrop.minX + line.box.minX * pixelCrop.width
            let width = min(6 * pixelCrop.width / viewport.width, textLeft - left - 2)
            guard width >= 4 else {
                XCTFail("The real prose line must expose a blank paper margin for its baseline")
                throw JourneyError.prerequisite
            }
            let rect = CGRect(x: left, y: pixelCrop.minY + (1 - line.box.maxY) * pixelCrop.height,
                width: width, height: line.box.height * pixelCrop.height).integral
            return try XCTUnwrap(image.cropping(to: rect))
        }
        func context(startingAt word: String, in line: Line, count: Int) throws -> String {
            let index = try XCTUnwrap(lines.firstIndex { $0.text == line.text })
            let text = lines.dropFirst(index).map(\.text).joined()
            let range = try XCTUnwrap(text.range(of: word))
            let raw = String(text[range.lowerBound...])
            let normal = String(String.UnicodeScalarView(raw.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
            XCTAssertGreaterThanOrEqual(normal.count, count)
            return String(normal.prefix(count))
        }
    }
    private func screen(_ app: XCUIApplication) throws -> Screen {
        XCTAssertTrue(body(app).exists)
        let image = try XCTUnwrap(app.screenshot().image.cgImage)
        let viewport = body(app).frame.intersection(app.frame).insetBy(dx: 6, dy: 6)
        XCTAssertGreaterThan(viewport.width, 100); XCTAssertGreaterThan(viewport.height, 100)
        let pixel = CGRect(x: (viewport.minX - app.frame.minX) * CGFloat(image.width) / app.frame.width,
            y: (viewport.minY - app.frame.minY) * CGFloat(image.height) / app.frame.height,
            width: viewport.width * CGFloat(image.width) / app.frame.width,
            height: viewport.height * CGFloat(image.height) / app.frame.height).integral
        let crop = try XCTUnwrap(image.cropping(to: pixel))
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]; request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: crop).perform([request])
        let lines = (request.results ?? []).sorted {
            abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.01 ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
        }.compactMap { value -> Line? in value.topCandidates(1).first.map { Line(candidate: $0, box: value.boundingBox) } }
        return Screen(image: image, pixelCrop: pixel, viewport: viewport, lines: lines)
    }
    private func anchor(_ app: XCUIApplication, name: String) throws -> String {
        let capture = try screen(app); XCTAssertGreaterThanOrEqual(capture.lines.count, 4)
        let value = String(normalized(capture.lines.dropFirst().prefix(2).map(\.text).joined()).prefix(24))
        XCTAssertGreaterThanOrEqual(value.count, 18)
        let text = XCTAttachment(string: capture.lines.map(\.text).joined(separator: "\n") + "\nANCHOR=" + value)
        text.name = name + "-actual-viewport-OCR"; text.lifetime = .keepAlways; add(text)
        let screenshot = XCTAttachment(image: UIImage(cgImage: capture.image))
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
        return value
    }
    private func assertVisible(_ quote: String, app: XCUIApplication, name: String) throws {
        waitUntil("Actual visible text: " + name, timeout: 25) {
            guard let text = try? self.screen(app).text else { return false }; return self.normalized(text).contains(quote)
        }
        XCTAssertTrue(normalized(try screen(app).text).contains(quote)); evidence(app, name)
    }
    private func assertStable(_ quote: String, interval: TimeInterval, app: XCUIApplication, name: String) throws {
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let capture = try? self.screen(app) else { return true }
            return !self.normalized(capture.text).contains(quote)
        }, object: nil)
        changed.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: interval), .completed,
            "The real page must remain unchanged for longer than the chosen three-second speed")
        try assertVisible(quote, app: app, name: name)
    }
    private func normalized(_ value: String) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }
    private func rgba(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        }
        return pixels
    }
    private func backgroundColour(_ image: CGImage) throws -> [Int] {
        let pixels = try rgba(image)
        var bins: [Int: Int] = [:]
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let key = Int(pixels[offset] / 8) << 10 | Int(pixels[offset + 1] / 8) << 5 | Int(pixels[offset + 2] / 8)
            bins[key, default: 0] += 1
        }
        let key = try XCTUnwrap(bins.max { $0.value < $1.value }?.key)
        return [(key >> 10 & 31) * 8 + 4, (key >> 5 & 31) * 8 + 4, (key & 31) * 8 + 4]
    }
    private func assertPaintedHighlight(_ image: CGImage, baseline: CGImage, against paper: [Int]) throws {
        func fraction(_ image: CGImage) throws -> Double {
            let pixels = try rgba(image), count = image.width * image.height
            var different = 0
            for offset in stride(from: 0, to: pixels.count, by: 4) {
                let colour = [Int(pixels[offset]), Int(pixels[offset + 1]), Int(pixels[offset + 2])]
                let distance = zip(colour, paper).reduce(0) { $0 + abs($1.0 - $1.1) }
                if distance >= 36 { different += 1 }
            }
            return Double(different) / Double(max(1, count))
        }
        // Subtract the same real word's original glyph/antialias coverage.
        // Grayscale highlights remain eligible; glyph ink alone cannot pass.
        XCTAssertGreaterThan(try fraction(image) - fraction(baseline), 0.12,
            "Saved Core highlight must actually paint the original word after cold reopen, independently of a note row or system selection")
    }
    private func evidence(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
    }
    private func waitUntil(_ fact: String, timeout: TimeInterval, _ condition: @escaping () -> Bool) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: timeout), .completed, fact)
    }
}
