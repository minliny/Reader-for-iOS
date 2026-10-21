import XCTest
import UIKit
import Vision
import CryptoKit

/// Bind every result to the delivery owner's sealed build. The real TXT must be
/// provisioned; all Core operations, clipboard use and positions originate in
/// the real App UI. This runner never calls Runtime or reads UIPasteboard.
final class ReaderReadingToolsJourneyTests: XCTestCase {
    private let bookID = "book-local:aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5"
    private let title = "仙子请听我解释"
    private enum JourneyError: Error { case prerequisite, nativeSelection, missingOwnedRule }
    private var displayRestored = false
    override func setUpWithError() throws { continueAfterFailure = false }

    /// Current native paper only. No import, rule/draft form, seek, chapter
    /// action, display preference, Core injection or reprocess is requested.
    func testExistingRealTXTVisibleLiteralCaptureAndNormalExitWithoutRuleMutation() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let json = environment["READER_TXT_VISIBLE_CAPTURE_PREFLIGHT_JSON"],
              let expectedSHA = environment["READER_TXT_VISIBLE_CAPTURE_PREFLIGHT_SHA256"],
              expectedSHA.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil,
              SHA256.hash(data: Data(json.utf8)).map({ String(format: "%02x", $0) }).joined() == expectedSHA,
              let proof = try? JSONDecoder().decode(TXTVisibleCapturePrerequisite.self, from: Data(json.utf8)),
              proof.schemaVersion == 1, proof.purpose == "existing-real-txt-visible-literal-capture-only",
              proof.targetUDID == "EEA74BB1-5DFA-479A-ACAA-460503AD0F6B",
              proof.sourceId == "local", proof.bookId == String(bookID.dropFirst("book-".count)),
              proof.originalSHA256 == "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5",
              proof.capturedAfterInstallBeforeLaunch, UUID(uuidString: proof.captureID) != nil,
              !proof.capturedAt.isEmpty, proof.processedScalarCount > 0,
              proof.chapterOffset <= proof.processedScalarCount,
              [proof.bodyVersion, proof.processingVersion, proof.libraryIdentitySHA256, proof.basisSHA256]
                .allSatisfy({ $0.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil }) else {
            XCTFail("Root must bind fresh actual post-install/pre-launch original progress, persisted Core processed scalar count, versions, library and true TXT SHA; never reuse the old3752 observation")
            throw JourneyError.prerequisite
        }
        if let actualUDID = environment["SIMULATOR_UDID"] { XCTAssertEqual(actualUDID, proof.targetUDID) }
        let binding = XCTAttachment(string: json + "\nPREFLIGHT_SHA256=" + expectedSHA)
        binding.name = "real-txt-visible-capture-original-readonly-basis-not-write-ack"
        binding.lifetime = .keepAlways; add(binding)
        let app = XCUIApplication(); app.launch()
        var returnedToShelf = false
        var terminated = false
        defer {
            if !returnedToShelf {
                evidence(app, "real-txt-visible-capture-failed-before-normal-return")
                let failure = XCTAttachment(string: app.debugDescription)
                failure.name = "real-txt-visible-capture-failed-actual-AX"; failure.lifetime = .keepAlways; add(failure)
            }
            // Failure is retained. Do not retry a tap, navigate another book,
            // discard a draft, or assert that an unobserved close completed.
            if !terminated {
                if app.state == .runningForeground { XCUIDevice.shared.press(.home) }
                if app.state != .notRunning { app.terminate() }
            }
        }
        let shelf = app.buttons["更多书架操作"]
        XCTAssertTrue(shelf.waitForExistence(timeout: 20)); XCTAssertTrue(shelf.isHittable)
        let exactBook = app.buttons.matching(NSPredicate(format: "identifier == %@", bookID))
        XCTAssertTrue(exactBook.firstMatch.waitForExistence(timeout: 20)); XCTAssertEqual(exactBook.count, 1)
        guard exactBook.element.isHittable, exactBook.element.isEnabled else {
            XCTFail("The already present exact original must be normally visible under the actual shelf state; do not clear a filter/group, import a substitute, or force-tap")
            throw JourneyError.prerequisite
        }
        evidence(app, "real-txt-visible-capture-existing-original-before-open")
        exactBook.element.tap()
        XCTAssertTrue(body(app).waitForExistence(timeout: 30))
        openModule("home", app: app)
        let expectedBookAX = "reading-book:" + proof.sourceId + "|" + proof.bookId
        let header = app.staticTexts.matching(NSPredicate(format: "identifier == %@", expectedBookAX))
        let chapter = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'reading-chapter:'"))
        XCTAssertTrue(header.firstMatch.waitForExistence(timeout: 5)); XCTAssertEqual(header.count, 1)
        XCTAssertEqual(chapter.count, 1)
        XCTAssertEqual(chapter.element.identifier, "reading-chapter:\(proof.chapterIndex)")
        XCTAssertEqual(header.element.label, title)
        let rect: (CGRect) -> [String: Double] = { ["x": Double($0.minX), "y": Double($0.minY), "width": Double($0.width), "height": Double($0.height)] }
        let publicSession: [String: Any] = ["bookAX": header.element.identifier, "bookLabel": header.element.label,
            "bookFrame": rect(header.element.frame), "chapterAX": chapter.element.identifier,
            "chapterLabel": chapter.element.label, "chapterFrame": rect(chapter.element.frame),
            "modelSessionUUIDExposedByAX": false,
            "boundary": "Actual public book/chapter/body/progress identity tuple, not an invented ReaderActiveSession UUID or UI bodyVersion observation"]
        evidence(app, "real-txt-visible-capture-actual-public-session-header")
        hideControls(app)
        let paper = app.textViews.matching(NSPredicate(format: "identifier == 'reading-body'"))
        let progress = app.staticTexts.matching(NSPredicate(format: "identifier == 'reading-progress'"))
        waitUntil("Actual single current paper and footer after controls finish dismissing", timeout: 5) {
            paper.count == 1 && paper.element.isHittable && progress.count == 1 && progress.element.exists
        }
        XCTAssertEqual(paper.count, 1); XCTAssertTrue(paper.element.isHittable)
        XCTAssertEqual(progress.count, 1)
        let expectedPercent = Int(Double(proof.chapterOffset) / Double(proof.processedScalarCount) * 100)
        XCTAssertEqual(progress.element.label, "\(expectedPercent)%", "Bind the actual fresh processed scalar basis; never treat a percent as a scalar/second or guess from raw TXT length")
        let progressBefore = progress.element.label
        let capture = try screen(app)
        guard capture.lines.contains(where: { normalized($0.text).count >= 2 }) else {
            XCTFail("Current real paper has insufficient visible OCR text; preserve the capture premise and do not seek/turn to manufacture a literal")
            throw JourneyError.prerequisite
        }
        XCTAssertEqual(progress.element.label, progressBefore)
        let payload: [String: Any] = ["purpose": "visible-literal-capture-only-not-save-admission",
            "captureID": proof.captureID, "freshOriginalBasisSHA256": proof.basisSHA256,
            "preflightSHA256": expectedSHA, "publicReadingSession": publicSession,
            "bodyAX": paper.element.identifier, "bodyFrame": rect(paper.element.frame),
            "progressAX": progress.element.identifier, "progressLabel": progressBefore, "progressFrame": rect(progress.element.frame),
            "appFrame": rect(app.frame), "actualOCRViewport": rect(capture.viewport), "actualOCRPixelCrop": rect(capture.pixelCrop),
            "imagePixelWidth": capture.image.width, "imagePixelHeight": capture.image.height,
            "lines": capture.lines.map { ["text": $0.text, "normalizedBoxInActualCrop": rect($0.box)] as [String: Any] },
            "noRuleOrDraftOrSeekRequested": true]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let observation = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        observation.name = "real-txt-current-paper-original-native-OCR-and-public-session"; observation.lifetime = .keepAlways; add(observation)
        let actualImage = XCTAttachment(image: UIImage(cgImage: capture.image))
        actualImage.name = "real-txt-current-paper-same-OCR-capture"; actualImage.lifetime = .keepAlways; add(actualImage)
        let ax = XCTAttachment(string: app.debugDescription)
        ax.name = "real-txt-current-paper-original-AX"; ax.lifetime = .keepAlways; add(ax)
        leaveReader(app)
        XCTAssertTrue(shelf.isHittable)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "identifier == %@", expectedBookAX)).firstMatch.exists)
        evidence(app, "real-txt-visible-capture-normal-return-to-original-shelf")
        returnedToShelf = true
        XCUIDevice.shared.press(.home)
        app.terminate(); terminated = true
        XCTAssertEqual(app.state, .notRunning)
    }

    private struct TXTVisibleCapturePrerequisite: Decodable {
        let schemaVersion: Int
        let purpose: String
        let targetUDID: String
        let captureID: String
        let capturedAt: String
        let capturedAfterInstallBeforeLaunch: Bool
        let sourceId: String
        let bookId: String
        let originalSHA256: String
        let chapterIndex: UInt32
        let chapterOffset: UInt64
        let processedScalarCount: UInt64
        let bodyVersion: String
        let processingVersion: String
        let libraryIdentitySHA256: String
        let basisSHA256: String
    }

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
        // This remaining consumer previews Core's bounded body with its title
        // removed. Use that real displayed preview as the rule's input sample.
        try previewAndRemoveOwnedRule(nil, app: app)
        chooseChapter(1, seekStart: true, app: app)
        try automaticPageConsumers(app)
        try restoreDisplay(originalDisplay, app: app); displayRestored = true
        leaveReader(app)
    }

    /// The existing rejected replacement draft is unrelated to the native
    /// scheduler. Do not visit its form, replay its Save, or discard its data.
    func testExistingRealTXTAutomaticPageConsumersAndBackgroundPauseWithoutRuleMutation() throws {
        let recovery = try originalAutomaticSpeedRecoveryProof()
        let app = XCUIApplication(); app.launch(); openBook(app)
        if let recovery { try restorePriorAutomaticSpeed(recovery, app: app) }
        let originalDisplay = try configureDisplay(app)
        displayRestored = false
        addTeardownBlock {
            guard !self.displayRestored else { return }
            if app.state != .runningForeground { app.activate() }
            try self.restoreDisplay(originalDisplay, app: app)
            self.displayRestored = true
        }
        chooseChapter(1, seekStart: true, app: app)
        try automaticPageConsumers(app, verifyBackgroundPause: true)
        try restoreDisplay(originalDisplay, app: app); displayRestored = true
        leaveReader(app)
    }

    /// Complete only Auto5's remaining display readback and normal exit. Its
    /// original whole-method failure and completed automatic consumers remain
    /// separate evidence; this method never starts another automatic session.
    func testOriginalAuto5DisplayValuesAndNormalExitWithoutReplayingConsumers() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let proofSHA = environment["READER_AUTO5_DISPLAY_RECOVERY_PROOF_SHA256"],
              proofSHA.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil,
              let json = environment["READER_AUTO5_ORIGINAL_DISPLAY_JSON"],
              let original = try? JSONDecoder().decode(AutomaticDisplayRecoveryTuple.self, from: Data(json.utf8)),
              original.mode == "分页", original.transition == "滑动", original.selectable == "1", original.paper == "夜间" else {
            XCTFail("Root must bind Auto5's original video/source/product/exit and exact original display tuple to the same owned library; never adopt current values as before")
            throw JourneyError.prerequisite
        }
        let proof = XCTAttachment(string: "externalEvidenceProofSHA256=\(proofSHA)\noriginalRun=compact-automatic-page-5\nbook=\(bookID)\noriginalMode=\(original.mode)\noriginalTransition=\(original.transition)\noriginalSelectable=\(original.selectable)\noriginalPaper=\(original.paper)\nproofRole=private evidence binding, not a Core operation UUID")
        proof.name = "auto5-original-display-evidence-binding"; proof.lifetime = .keepAlways; add(proof)
        let app = XCUIApplication(); app.launch(); openBook(app)
        openModule("appearance", app: app)
        let header = app.staticTexts["reading-book:local|" + String(bookID.dropFirst("book-".count))]
        guard header.exists, header.label == title else {
            XCTFail("Do not verify or restore another book's display")
            throw JourneyError.prerequisite
        }
        let paper = try originalPaperControl(original.paper, app: app)
        XCTAssertTrue(paper.isSelected, "Auto5 never changed paper; preserve any unowned different selection instead of overwriting it")
        evidence(app, "auto5-original-night-paper-selected-through-real-heading")
        let mode = app.buttons["reading-page-mode"]
        reveal(mode, towardBottom: true, app: app)
        XCTAssertEqual(try menuValue(mode, choices: ["滚动", "分页"]), original.mode)
        let transition = app.buttons["reading-page-transition"]
        reveal(transition, towardBottom: true, app: app)
        XCTAssertEqual(try menuValue(transition, choices: ["仿真", "覆盖", "滑动", "无动画"]), original.transition)
        evidence(app, "auto5-original-page-mode-and-transition-readback")
        let selectable = app.switches["长按选择文本"]
        reveal(selectable, towardBottom: true, app: app)
        XCTAssertEqual(selectable.value as? String, original.selectable)
        evidence(app, "auto5-original-text-selection-readback")
        hideControls(app); leaveReader(app)
        evidence(app, "auto5-original-display-readback-and-normal-exit-completed")
    }

    /// Diagnose physical input separately from XCTest's AX hittability.
    /// Historical failures remain; consumers still require actual Core results.
    /// This method makes one read-only preview touch and never creates a rule.
    func testDiagnosticOriginalTXTVisiblePreviewSingleNativeTouchWithoutRuleMutation() throws {
        let app = XCUIApplication(); app.launch(); openBook(app)
        openTool("替换、字典与目录规则", app: app)
        let viewport = try tapSavedReplacementPreviewOnce(app, evidenceName: "tools-preview-single-physical-touch-diagnostic")
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

    /// Native evidence proves this measured center reaches the real action even
    /// when XCTest reports AXHittable=false. Keep that AX observation, require
    /// the same settled/unique/visible control, and send exactly one touch.
    @discardableResult
    private func tapSavedReplacementPreviewOnce(_ app: XCUIApplication, evidenceName: String) throws -> CGRect {
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
        var viewport = scroll.frame.intersection(app.frame).insetBy(dx: 4, dy: 4)
        var visible = false
        for _ in 0..<24 {
            viewport = scroll.frame.intersection(app.frame).insetBy(dx: 4, dy: 4)
            if button.exists, button.frame.width > 0, button.frame.height > 0, viewport.contains(button.frame) {
                visible = true; break
            }
            let high = coordinate(CGPoint(x: viewport.midX, y: viewport.minY + 30), app: app)
            let low = coordinate(CGPoint(x: viewport.midX, y: viewport.maxY - 30), app: app)
            if button.exists && button.frame.midY < viewport.minY { high.press(forDuration: 0.05, thenDragTo: low) }
            else { low.press(forDuration: 0.05, thenDragTo: high) }
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
        let observation = XCTAttachment(string: "physicalControlDriver=true\nAXHittable=\(reportedHittable)\nactualButtonFrame=\(frame)\nactualScrollViewport=\(viewport)\nsingleNativeTouchPoint=\(point)\nThis helper performs no rule save, deletion, draft edit, direct Runner Core call or retry. Historical failures remain; callers require actual Core results.")
        observation.name = evidenceName + "-boundary"; observation.lifetime = .keepAlways; add(observation)
        evidence(app, evidenceName + "-before-touch")
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
        return finalViewport
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

    private func previewAndRemoveOwnedRule(_ preferredLiteral: String?, app: XCUIApplication) throws {
        openTool("替换、字典与目录规则", app: app)
        let kind = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '规则类型'")).firstMatch
        XCTAssertTrue(kind.waitForExistence(timeout: 10)); kind.tap()
        XCTAssertTrue(app.buttons["替换"].waitForExistence(timeout: 5)); app.buttons["替换"].tap()
        try tapSavedReplacementPreviewOnce(app, evidenceName: "tools-existing-preview-single-touch")
        let before = app.staticTexts["replacement-preview-before"]
        let after = app.staticTexts["replacement-preview-after"]
        waitUntil("Read the actual existing Core preview before adding an owned rule", timeout: 25) {
            before.exists && after.exists && !before.label.isEmpty && !after.label.isEmpty
        }
        reveal(before, towardBottom: true, app: app)
        evidence(app, "tools-existing-preview-original-visible")
        reveal(after, towardBottom: true, app: app)
        evidence(app, "tools-existing-preview-processed-visible")
        let originalRaw = before.label, originalProcessed = after.label
        let literal: String
        if let preferredLiteral {
            // The original copy/note journey keeps its same-selection contract.
            literal = preferredLiteral
        } else {
            let scalars = Array(originalProcessed.unicodeScalars)
            literal = try XCTUnwrap(zip(scalars, scalars.dropFirst()).compactMap { first, second -> String? in
                guard (0x4E00...0x9FFF).contains(first.value), (0x4E00...0x9FFF).contains(second.value) else { return nil }
                let candidate = String(first) + String(second)
                return originalRaw.contains(candidate) ? candidate : nil
            }.first, "Require an actual nonempty common original/processed Core preview sample; never generate chapter text")
            let sample = XCTAttachment(string: "inputOrigin=actual visible Core preview UI\nliteral=\(literal)\noriginalUTF8Bytes=\(originalRaw.utf8.count)\nprocessedUTF8Bytes=\(originalProcessed.utf8.count)\nNo appended native chapter title, generated prose or request beyond the Core bound.")
            sample.name = "tools-rule-input-from-real-bounded-preview"; sample.lifetime = .keepAlways; add(sample)
        }
        XCTAssertTrue(originalProcessed.contains(literal), "The real displayed copied text must be in the bounded actual chapter preview")
        let create = app.buttons["新建"]
        try beginEmptyReplacementDraft(app)
        let ownedName = "原生预览-" + UUID().uuidString
        let replacement = "ReaderPreview" + String(UUID().uuidString.prefix(8))
        let draftIdentity = XCTAttachment(string: "phase=before-any-form-fill\nownedDraftName=\(ownedName)\nbook=\(bookID)\nscopeBookName=\(title)\nliteral=\(literal)\nreplacement=\(replacement)\nNo rule save has been requested. This complete UUID identifies only this method's draft, not a Core receipt.")
        draftIdentity.name = "tools-owned-unsaved-draft-identity-before-fill"; draftIdentity.lifetime = .keepAlways; add(draftIdentity)
        var saveRequested = false
        var ownedDraftCleared = false
        addTeardownBlock {
            guard !ownedDraftCleared else { return }
            guard !saveRequested else {
                let preserved = XCTAttachment(string: "ownedDraftName=\(ownedName)\nSave was requested. Do not infer an absent receipt or discard a possibly committed/pending write from its draft alone.")
                preserved.name = "tools-owned-draft-preserved-after-save-request"; preserved.lifetime = .keepAlways; self.add(preserved)
                return
            }
            try self.discardExactUnsavedReplacementDraft(ownedName, app: app)
        }
        try fill("规则名称", ownedName, towardBottom: false, app: app)
        try fill("匹配内容", literal, app: app)
        try fill("替换为", replacement, app: app)
        try fill("作用范围，留空为全部", title, app: app)
        setToggle("正则表达式", value: "0", app: app)
        setToggle("作用于正文", value: "1", app: app)
        setToggle("作用于标题", value: "0", app: app)
        setToggle("作用于书源", value: "0", app: app)
        setToggle("启用此规则", value: "1", app: app)
        let save = app.buttons["保存规则"]; reveal(save, towardBottom: true, app: app)
        XCTAssertTrue(save.isEnabled); saveRequested = true; save.tap()
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
        try tapSavedReplacementPreviewOnce(app, evidenceName: "tools-owned-rule-preview-single-touch")
        waitUntil("Real Core preview must consume the owned saved rule", timeout: 25) {
            before.exists && after.exists && before.label.contains(literal) && after.label.contains(replacement)
        }
        reveal(after, towardBottom: true, app: app)
        XCTAssertEqual(before.label, originalRaw, "Previewing a rule cannot rewrite the original chapter")
        XCTAssertNotEqual(before.label, after.label)
        let previewText = XCTAttachment(string: "BEFORE:\n" + before.label + "\nAFTER:\n" + after.label)
        previewText.name = "tools-real-core-owned-replacement-preview"; previewText.lifetime = .keepAlways; add(previewText)
        evidence(app, "tools-real-rule-preview-consumer")
        removeOwnedRule(ruleID, name: ownedName, app: app); deleted = true
        try tapSavedReplacementPreviewOnce(app, evidenceName: "tools-removed-owned-rule-preview-single-touch")
        waitUntil("Deleting the exact owned rule must remove its real preview effect", timeout: 25) {
            before.exists && before.label == originalRaw && after.exists && !after.label.contains(replacement) && after.label == originalProcessed
        }
        reveal(after, towardBottom: true, app: app)
        evidence(app, "tools-removed-owned-rule-effect-no-longer-visible")
        // The only discarded draft is this method's exact UUID-owned draft.
        let name = textInput("规则名称", app: app)
        reveal(name, towardBottom: false, app: app)
        XCTAssertEqual(name.value as? String, ownedName)
        reveal(create, towardBottom: true, app: app); create.tap()
        let discardOwned = app.alerts["替换当前草稿？"]
        if discardOwned.waitForExistence(timeout: 1) { discardOwned.buttons["替换"].tap() }
        reveal(name, towardBottom: false, app: app)
        XCTAssertTrue(isEmpty(name), "The owned rule draft must also be cleared after cleanup")
        ownedDraftCleared = true
        hideControls(app)
    }

    private func beginEmptyReplacementDraft(_ app: XCUIApplication) throws {
        let prior = ProcessInfo.processInfo.environment["READER_TOOLS_PRIOR_OWNED_DRAFT_NAME"]
        if let prior {
            // Root's Runner-only gate binds Source24's failed native input,
            // complete archived name, raw draft SHA, and absence of a save.
            guard prior == "原生预览-721ED1D3-4DC1-4F6C-9349-9A08DE1B465F" else {
                XCTFail("No ownership proof authorizes discarding another prior draft")
                throw JourneyError.prerequisite
            }
            let name = textInput("规则名称", app: app)
            reveal(name, towardBottom: false, app: app)
            guard name.value as? String == prior,
                  app.staticTexts["新替换规则"].exists, !app.staticTexts["编辑替换规则"].exists,
                  app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'replace-rule-' AND label == %@", prior)).count == 0 else {
                XCTFail("The prior name or new-unsaved-draft identity changed; preserve it")
                throw JourneyError.prerequisite
            }
            for placeholder in ["匹配内容", "替换为", "规则分组", "排除范围", "作用范围，留空为全部"] {
                let field = textInput(placeholder, app: app)
                guard field.exists, field.value is String, isEmpty(field) else {
                    XCTFail("The proven prior draft acquired content in " + placeholder + "; preserve it")
                    throw JourneyError.prerequisite
                }
            }
            let order = textInput("执行顺序", app: app).value as? String
            let timeout = (textInput("匹配超时（毫秒）", app: app).value as? String)?.replacingOccurrences(of: ",", with: "")
            guard order == "0", timeout == "3000",
                  app.switches["正则表达式"].value as? String == "1",
                  app.switches["作用于正文"].value as? String == "1",
                  app.switches["作用于标题"].value as? String == "0",
                  app.switches["作用于书源"].value as? String == "0",
                  app.switches["启用此规则"].value as? String == "1" else {
                XCTFail("The prior draft's observed default configuration changed; preserve it")
                throw JourneyError.prerequisite
            }
            let identity = XCTAttachment(string: "priorOwnedDraftName=\(prior)\nactualNameExactlyMatches=true\notherTextFieldsEmpty=true\nnewUnsavedDraft=true\ndefaultConfigurationMatches=true\nRecovery uses only normal New and its native confirmation; no saved rule is deleted.")
            identity.name = "tools-prior-source24-owned-draft-ui-preconditions"; identity.lifetime = .keepAlways; add(identity)
        }
        let create = app.buttons["新建"]
        reveal(create, towardBottom: false, app: app)
        if let prior {
            guard textInput("规则名称", app: app).value as? String == prior else {
                XCTFail("Preserve a prior draft whose name changed before normal New")
                throw JourneyError.prerequisite
            }
        }
        XCTAssertTrue(create.isEnabled); create.tap()
        let alert = app.alerts["替换当前草稿？"]
        if prior != nil {
            guard alert.waitForExistence(timeout: 3) else {
                XCTFail("The exact prior owned draft must require its normal discard confirmation")
                throw JourneyError.prerequisite
            }
            // Identity was checked immediately before New. Do not query the
            // obscured form through a modal native alert's accessibility tree.
            alert.buttons["替换"].tap()
        } else if alert.waitForExistence(timeout: 1) {
            alert.buttons["取消"].tap()
            XCTFail("An existing unowned rule draft is preserved; a clean owned test draft is required")
            throw JourneyError.prerequisite
        }
        let name = textInput("规则名称", app: app)
        reveal(name, towardBottom: false, app: app)
        XCTAssertTrue(isEmpty(name), "Normal New must establish the empty draft before any owned input")
    }

    private func discardExactUnsavedReplacementDraft(_ name: String, app: XCUIApplication) throws {
        // This cleanup is armed before filling, and retired before any save.
        // Never navigate through an unknown alert or infer a write outcome.
        guard app.state == .runningForeground, app.alerts.count == 0 else { return }
        let field = textInput("规则名称", app: app)
        guard field.exists, field.value as? String == name,
              app.staticTexts["新替换规则"].exists, !app.staticTexts["编辑替换规则"].exists,
              app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'replace-rule-' AND label == %@", name)).count == 0 else { return }
        dismissKeyboardByScrolling(app, field: field)
        reveal(field, towardBottom: false, app: app)
        guard field.value as? String == name else { return }
        let create = app.buttons["新建"]
        reveal(create, towardBottom: true, app: app)
        guard create.isEnabled, field.value as? String == name else { return }
        create.tap()
        let alert = app.alerts["替换当前草稿？"]
        guard alert.waitForExistence(timeout: 3) else {
            XCTFail("The exact owned unsaved draft was not confirmed for cleanup")
            throw JourneyError.prerequisite
        }
        alert.buttons["替换"].tap()
        reveal(field, towardBottom: false, app: app)
        XCTAssertTrue(isEmpty(field), "Only this method's exact unsaved draft is cleared")
        evidence(app, "tools-exact-owned-unsaved-draft-cleared-through-native-new")
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

    private final class AutomaticSpeedRestoration {
        let original: Int
        var ownedValues: Set<Int>
        var requested = false
        var restored = false
        init(original: Int) { self.original = original; ownedValues = [original] }
    }
    private final class AutomaticPageRestoration {
        let minute: String
        let second: String
        let speed: AutomaticSpeedRestoration
        var minuteRequested = false
        var secondRequested = false
        var minuteRestored = false
        var secondRestored = false
        var runRequested = false
        var runRetired = false
        init(minute: String, second: String, speed: Int) {
            self.minute = minute; self.second = second; self.speed = AutomaticSpeedRestoration(original: speed)
        }
    }
    private enum AutomaticPagePreference: Equatable { case minute, second, speed }
    private struct AutomaticPageObservation {
        let capture: Screen
        let anchor: String
        let progress: String
    }
    private func automaticPageObservation(_ app: XCUIApplication) throws -> AutomaticPageObservation? {
        let footer = app.staticTexts["reading-progress"]
        guard body(app).exists, footer.exists else { return nil }
        let before = footer.label
        let capture = try screen(app)
        guard body(app).exists, footer.exists, footer.label == before,
              !before.isEmpty, capture.lines.count >= 4 else { return nil }
        // Actual pages can begin with ellipses and a two-character dialogue.
        // Accumulate the same consecutive visible OCR lines; neither a fixed
        // two-line assumption nor a later screenshot owns this observation.
        let quote = String(normalized(capture.lines.dropFirst().map(\.text).joined()).prefix(24))
        guard quote.count >= 18 else { return nil }
        return AutomaticPageObservation(capture: capture, anchor: quote, progress: before)
    }
    @discardableResult
    private func recordAutomaticPage(_ observation: AutomaticPageObservation, name: String) -> String {
        XCTAssertGreaterThanOrEqual(observation.capture.lines.count, 4)
        XCTAssertGreaterThanOrEqual(observation.anchor.count, 18)
        let text = XCTAttachment(string: observation.capture.lines.map(\.text).joined(separator: "\n")
            + "\nANCHOR=" + observation.anchor + "\nPROGRESS=" + observation.progress
            + "\nprogressUnchangedAcrossScreenshot=true")
        text.name = name + "-actual-viewport-OCR"; text.lifetime = .keepAlways; add(text)
        let screenshot = XCTAttachment(image: UIImage(cgImage: observation.capture.image))
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
        return observation.anchor
    }
    private func automaticPageConsumers(_ app: XCUIApplication, verifyBackgroundPause: Bool = false) throws {
        let originalPage = try XCTUnwrap(try automaticPageObservation(app), "Require a stable actual page with at least four OCR lines and eighteen anchor characters")
        let baseline = recordAutomaticPage(originalPage, name: "tools-before-actual-auto-consumer")
        // The real footer exists only while the reading controls are hidden.
        // Capture the same visible passage's progress before opening Full.
        let initialProgress = originalPage.progress
        openTool("自动翻页", app: app)
        let stop = app.buttons["auto-page-stop"]
        let toggle = app.buttons["auto-page-toggle"]
        guard toggle.label == "开始自动翻页", !stop.isEnabled else {
            XCTFail("Preserve an automatic owner that this method did not start")
            throw JourneyError.prerequisite
        }
        let wheels = app.pickerWheels
        XCTAssertEqual(wheels.count, 2)
        let minute = wheels.element(boundBy: 0), second = wheels.element(boundBy: 1)
        reveal(minute, towardBottom: false, app: app)
        let oldMinute = try XCTUnwrap(minute.value as? String), oldSecond = try XCTUnwrap(second.value as? String)
        try quickAutomaticPage(app)
        let oldSpeed = try XCTUnwrap(observedQuickAutomaticSpeed(app))
        try fullAutomaticPage(app)
        try assertFullAutomaticSpeed(oldSpeed, app: app)
        let restoration = AutomaticPageRestoration(minute: oldMinute, second: oldSecond, speed: oldSpeed)
        // XCTest tears these stages down in reverse order: stop only this
        // method's run, then restore speed/seconds/minutes independently. Each
        // stage is armed before any preference mutation; a failed stage cannot
        // make another known original value lose its own restoration owner.
        addTeardownBlock { try self.restoreAutomaticPreference(.minute, owner: restoration, app: app) }
        addTeardownBlock { try self.restoreAutomaticPreference(.second, owner: restoration, app: app) }
        addTeardownBlock { try self.restoreAutomaticPreference(.speed, owner: restoration, app: app) }
        addTeardownBlock { try self.stopOwnedAutomaticPage(restoration, app: app) }
        reveal(minute, towardBottom: false, app: app)
        if oldMinute != "00 分" {
            restoration.minuteRequested = true; minute.adjust(toPickerWheelValue: "00 分")
        }
        if oldSecond != "45 秒" {
            restoration.secondRequested = true; second.adjust(toPickerWheelValue: "45 秒")
        }
        XCTAssertEqual(minute.value as? String, "00 分"); XCTAssertEqual(second.value as? String, "45 秒")
        try quickAutomaticPage(app)
        try stepAutomaticSpeed(to: 3, owner: restoration.speed, app: app)
        try fullAutomaticPage(app)
        try assertFullAutomaticSpeed(3, app: app)
        reveal(toggle, towardBottom: false, app: app)
        XCTAssertEqual(toggle.label, "开始自动翻页")
        restoration.runRequested = true; toggle.tap()
        var firstObservation: AutomaticPageObservation?
        waitUntil("First actual automatic page must change visible text", timeout: 18) {
            guard let observed = try? self.automaticPageObservation(app),
                  !self.normalized(observed.capture.text).contains(baseline), observed.progress != initialProgress else { return false }
            firstObservation = observed
            return true
        }
        let firstPage = try XCTUnwrap(firstObservation)
        let first = recordAutomaticPage(firstPage, name: "tools-first-real-auto-native-commit")
        let firstProgress = firstPage.progress
        var secondObservation: AutomaticPageObservation?
        waitUntil("A second actual page requires the first native ACK to be consumed", timeout: 18) {
            guard let observed = try? self.automaticPageObservation(app),
                  !self.normalized(observed.capture.text).contains(first), observed.progress != firstProgress else { return false }
            secondObservation = observed
            return true
        }
        let secondPage = try XCTUnwrap(secondObservation)
        let secondPassage = recordAutomaticPage(secondPage, name: "tools-second-real-auto-native-commit")
        if verifyBackgroundPause {
            let secondProgress = secondPage.progress
            XCUIDevice.shared.press(.home)
            waitUntil("The real App must enter the background without termination", timeout: 5) {
                app.state == .runningBackground || app.state == .runningBackgroundSuspended
            }
            app.activate()
            XCTAssertTrue(body(app).waitForExistence(timeout: 10))
            try assertVisible(secondPassage, app: app, name: "tools-auto-background-retains-actual-passage")
            XCTAssertEqual(app.staticTexts["reading-progress"].label, secondProgress)
            try assertStable(secondPassage, interval: 4.5, app: app, name: "tools-auto-background-pause-outlasts-selected-speed")
            openTool("自动翻页", app: app)
            reveal(toggle, towardBottom: false, app: app)
            XCTAssertEqual(toggle.label, "继续自动翻页", "Background pause retains this owner's resumable session")
            toggle.tap()
            var resumedObservation: AutomaticPageObservation?
            waitUntil("Normal Continue after background must consume a new native page", timeout: 18) {
                guard let observed = try? self.automaticPageObservation(app),
                      !self.normalized(observed.capture.text).contains(secondPassage), observed.progress != secondProgress else { return false }
                resumedObservation = observed
                return true
            }
            recordAutomaticPage(try XCTUnwrap(resumedObservation), name: "tools-auto-background-normal-resume-native-commit")
        }
        // Real centre tap pauses the owner. No Runtime phase is injected.
        body(app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        if app.buttons["control-grabber"].isHittable { hideControls(app) }
        let paused = recordAutomaticPage(try XCTUnwrap(try automaticPageObservation(app)), name: "tools-manually-paused-visible-passage")
        try assertStable(paused, interval: 4.5, app: app, name: "tools-pause-consumed-beyond-selected-speed")
        openTool("自动翻页", app: app)
        XCTAssertEqual(toggle.label, "继续自动翻页")
        stop.tap()
        waitUntil("The real stop action must reset the auto owner", timeout: 5) { toggle.label == "开始自动翻页" }
        hideControls(app)
        let stopped = recordAutomaticPage(try XCTUnwrap(try automaticPageObservation(app)), name: "tools-stopped-visible-passage")
        try assertStable(stopped, interval: 4.5, app: app, name: "tools-stop-rejects-future-page-consumer")
        try stopOwnedAutomaticPage(restoration, app: app)
        try restoreAutomaticPreference(.speed, owner: restoration, app: app)
        try restoreAutomaticPreference(.second, owner: restoration, app: app)
        try restoreAutomaticPreference(.minute, owner: restoration, app: app)
        reveal(minute, towardBottom: false, app: app)
        XCTAssertEqual(minute.value as? String, oldMinute); XCTAssertEqual(second.value as? String, oldSecond)
        try assertFullAutomaticSpeed(oldSpeed, app: app)
        evidence(app, "tools-original-auto-configuration-restored")
        hideControls(app)
    }

    private func openAutomaticRestorationPanel(_ app: XCUIApplication) throws {
        if app.state != .runningForeground { app.activate() }
        guard body(app).exists else {
            XCTFail("Do not navigate another book to restore an absent reading session")
            throw JourneyError.prerequisite
        }
        openTool("自动翻页", app: app)
        let header = app.staticTexts["reading-book:local|" + String(bookID.dropFirst("book-".count))]
        guard header.exists, header.label == title else {
            XCTFail("Preserve automatic preferences in another book's reading session")
            throw JourneyError.prerequisite
        }
    }
    private func stopOwnedAutomaticPage(_ owner: AutomaticPageRestoration, app: XCUIApplication) throws {
        guard owner.runRequested, !owner.runRetired else { return }
        try openAutomaticRestorationPanel(app)
        let toggle = app.buttons["auto-page-toggle"], stop = app.buttons["auto-page-stop"]
        guard ["开始自动翻页", "继续自动翻页", "暂停自动翻页"].contains(toggle.label) else {
            XCTFail("Preserve an automatic owner whose actual phase is unknown")
            throw JourneyError.prerequisite
        }
        if stop.isEnabled {
            reveal(stop, towardBottom: false, app: app); stop.tap()
        }
        waitUntil("The method's automatic owner is stopped before preference restoration", timeout: 5) {
            toggle.label == "开始自动翻页" && !stop.isEnabled
        }
        owner.runRetired = true
    }
    private func restoreAutomaticPreference(_ preference: AutomaticPagePreference, owner: AutomaticPageRestoration,
                                            app: XCUIApplication) throws {
        switch preference {
        case .minute: guard owner.minuteRequested, !owner.minuteRestored else { return }
        case .second: guard owner.secondRequested, !owner.secondRestored else { return }
        case .speed: guard owner.speed.requested, !owner.speed.restored else { return }
        }
        if preference == .speed {
            try restoreAutomaticSpeed(owner.speed, app: app)
            return
        }
        try openAutomaticRestorationPanel(app)
        guard app.buttons["auto-page-toggle"].label == "开始自动翻页", !app.buttons["auto-page-stop"].isEnabled else {
            XCTFail("Do not restore settings beneath a live or unowned automatic session")
            throw JourneyError.prerequisite
        }
        let wheel = app.pickerWheels.element(boundBy: preference == .minute ? 0 : 1)
        let original = preference == .minute ? owner.minute : owner.second
        let requested = preference == .minute ? "00 分" : "45 秒"
        reveal(wheel, towardBottom: false, app: app)
        let actual = try XCTUnwrap(wheel.value as? String)
        guard actual == original || actual == requested else {
            XCTFail("Preserve a timer value other than the captured original or this method's request")
            throw JourneyError.prerequisite
        }
        if actual != original { wheel.adjust(toPickerWheelValue: original) }
        XCTAssertEqual(wheel.value as? String, original)
        if preference == .minute { owner.minuteRestored = true } else { owner.secondRestored = true }
    }

    private struct AutomaticSpeedRecoveryProof {
        let originalSeconds: Int
        let changedSeconds: Int
        let sha256: String
    }
    private func originalAutomaticSpeedRecoveryProof() throws -> AutomaticSpeedRecoveryProof? {
        let environment = ProcessInfo.processInfo.environment
        let original = environment["READER_AUTO_PRIOR_ORIGINAL_SECONDS"]
        let changed = environment["READER_AUTO_PRIOR_OWNED_SECONDS"]
        let sha = environment["READER_AUTO_PRIOR_RECOVERY_PROOF_SHA256"]
        if original == nil, changed == nil, sha == nil { return nil }
        guard original == "8", changed == "2", let sha,
              sha.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil else {
            XCTFail("All three Runner-only recovery values must bind Root's exact Auto1 proof; incomplete or unknown prior ownership must not change a preference")
            throw JourneyError.prerequisite
        }
        // Root's private preflight binds this digest to the failed sealed29
        // run, exact target/library/book, preserved rejected draft and original
        // rejection ACK. Nothing is passed into the App or assigned to prefs.
        let attachment = XCTAttachment(string: "proofSHA256=\(sha)\noriginalRun=compact-automatic-page-1 (exit 65 preserved)\nbook=\(bookID)\noriginalSeconds=8 (original video UI; no fabricated prefs-before)\nchangedSeconds=2 (actual read-only post prefs)")
        attachment.name = "auto1-original-owned-speed-recovery-proof"; attachment.lifetime = .keepAlways; add(attachment)
        return AutomaticSpeedRecoveryProof(originalSeconds: 8, changedSeconds: 2, sha256: sha)
    }
    private func restorePriorAutomaticSpeed(_ proof: AutomaticSpeedRecoveryProof, app: XCUIApplication) throws {
        try openAutomaticRestorationPanel(app)
        guard app.buttons["auto-page-toggle"].label == "开始自动翻页", !app.buttons["auto-page-stop"].isEnabled else {
            XCTFail("Do not change speed beneath an unowned live automatic session")
            throw JourneyError.prerequisite
        }
        try quickAutomaticPage(app)
        guard observedQuickAutomaticSpeed(app) == proof.changedSeconds else {
            XCTFail("The exact old Auto1-owned 2-second result is required; another value is preserved without guessing")
            throw JourneyError.prerequisite
        }
        let restoration = AutomaticSpeedRestoration(original: proof.originalSeconds)
        restoration.ownedValues.insert(proof.changedSeconds); restoration.requested = true
        // The historical ownership proof and teardown are armed before the
        // first real UI step. A partial recovery still has only owned values.
        addTeardownBlock {
            guard !restoration.restored else { return }
            try self.restoreAutomaticSpeed(restoration, app: app)
        }
        try stepAutomaticSpeed(to: proof.originalSeconds, owner: restoration, app: app)
        try fullAutomaticPage(app)
        try assertFullAutomaticSpeed(proof.originalSeconds, app: app)
        restoration.restored = true
        evidence(app, "auto1-owned-two-to-original-eight-restored-through-normal-ui")
        hideControls(app)
    }
    private func quickAutomaticPage(_ app: XCUIApplication) throws {
        let matches = app.buttons.matching(identifier: "control-grabber")
        guard matches.count == 1 else { XCTFail("Use the unique actual reading grabber"); throw JourneyError.prerequisite }
        let grabber = matches.element
        if grabber.label.hasPrefix("完整控制栏") {
            guard grabber.isEnabled, grabber.isHittable else { XCTFail("The Full grabber must be a real visible touch target"); throw JourneyError.prerequisite }
            grabber.tap()
        }
        waitUntil("Actual Quick automatic endpoint", timeout: 5) { grabber.label.hasPrefix("快捷控制栏") }
        guard grabber.label.hasPrefix("快捷控制栏"), observedQuickAutomaticSpeed(app) != nil else {
            XCTFail("The real Quick speed buttons and readout must be unique and visible")
            throw JourneyError.prerequisite
        }
    }
    private func fullAutomaticPage(_ app: XCUIApplication) throws {
        let matches = app.buttons.matching(identifier: "control-grabber")
        guard matches.count == 1 else { XCTFail("Use the unique actual reading grabber"); throw JourneyError.prerequisite }
        let grabber = matches.element
        guard grabber.label.hasPrefix("快捷控制栏"), grabber.isEnabled, grabber.isHittable else {
            XCTFail("Return from the actual Quick endpoint using its real grabber")
            throw JourneyError.prerequisite
        }
        grabber.tap()
        waitUntil("Actual Full automatic endpoint", timeout: 5) { grabber.label.hasPrefix("完整控制栏") }
        guard grabber.label.hasPrefix("完整控制栏"), app.buttons["auto-page-toggle"].exists else {
            XCTFail("Only the actual Full automatic panel exposes its native slider")
            throw JourneyError.prerequisite
        }
    }
    private func observedQuickAutomaticSpeed(_ app: XCUIApplication) -> Int? {
        guard app.buttons["control-grabber"].label.hasPrefix("快捷控制栏") else { return nil }
        let slower = app.buttons.matching(NSPredicate(format: "label == %@", "减慢自动翻页"))
        let faster = app.buttons.matching(NSPredicate(format: "label == %@", "加快自动翻页"))
        guard slower.count == 1, faster.count == 1 else { return nil }
        let left = slower.element, right = faster.element
        guard left.isEnabled, right.isEnabled, left.isHittable, right.isHittable,
              app.frame.contains(left.frame), app.frame.contains(right.frame), right.frame.minX > left.frame.maxX else { return nil }
        let region = CGRect(x: left.frame.maxX, y: min(left.frame.minY, right.frame.minY),
            width: right.frame.minX - left.frame.maxX, height: max(left.frame.maxY, right.frame.maxY) - min(left.frame.minY, right.frame.minY))
        // Full's retained endpoint labels must not masquerade as the current
        // value. Read only the actual label between the two visible Quick keys.
        let values = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", #"^[0-9]{1,2} 秒$"#))
            .allElementsBoundByIndex.filter { $0.isHittable && region.contains($0.frame) }
        guard values.count == 1, let value = Int(values[0].label.replacingOccurrences(of: " 秒", with: "")), (2...20).contains(value) else { return nil }
        return value
    }
    private func stepAutomaticSpeed(to target: Int, owner: AutomaticSpeedRestoration, app: XCUIApplication) throws {
        guard (2...20).contains(target), let current = observedQuickAutomaticSpeed(app), owner.ownedValues.contains(current) else {
            XCTFail("Preserve an automatic speed outside the original and this owner's requested/observed values")
            throw JourneyError.prerequisite
        }
        var value = current
        let count = abs(target - current)
        guard count <= 18 else { throw JourneyError.prerequisite }
        for _ in 0..<count {
            let next = value + (target > value ? 1 : -1)
            let label = next > value ? "减慢自动翻页" : "加快自动翻页"
            let matches = app.buttons.matching(NSPredicate(format: "label == %@", label))
            guard matches.count == 1, matches.element.isEnabled, matches.element.isHittable,
                  observedQuickAutomaticSpeed(app) == value else {
                XCTFail("Only one actual one-second control may advance the same observed speed")
                throw JourneyError.prerequisite
            }
            owner.requested = true; owner.ownedValues.insert(next) // Arm before the real touch.
            matches.element.tap()
            waitUntil("Actual Quick speed becomes exactly \(next) seconds", timeout: 5) { self.observedQuickAutomaticSpeed(app) == next }
            guard observedQuickAutomaticSpeed(app) == next else { throw JourneyError.prerequisite }
            let observation = XCTAttachment(string: "beforeSeconds=\(value)\nrequestedSeconds=\(next)\nobservedSeconds=\(next)\ncontrol=\(label)")
            observation.name = "auto-speed-owned-native-one-second-step"; observation.lifetime = .keepAlways; add(observation)
            value = next
        }
        XCTAssertEqual(observedQuickAutomaticSpeed(app), target)
    }
    private func assertFullAutomaticSpeed(_ seconds: Int, app: XCUIApplication) throws {
        let matches = app.sliders.matching(NSPredicate(format: "label == %@", "自动翻页速度"))
        guard matches.count == 1 else { XCTFail("Require one actual Full speed slider"); throw JourneyError.prerequisite }
        let control = matches.element
        reveal(control, towardBottom: true, app: app)
        guard control.isEnabled, control.isHittable else {
            XCTFail("The native Full slider must be visible before its value confirms the actual speed")
            throw JourneyError.prerequisite
        }
        let rawValue = control.value
        let rawType = rawValue.map { String(reflecting: type(of: $0)) } ?? "nil"
        let observation = XCTAttachment(string: "rawValue=\(String(describing: rawValue))\nrawType=\(rawType)\nexpectedSeconds=\(seconds)\ncontrolLabel=\(control.label)\nendpoint=\(app.buttons["control-grabber"].label)")
        observation.name = "auto-speed-actual-full-native-value-and-unit"; observation.lifetime = .keepAlways; add(observation)
        let text = try XCTUnwrap(rawValue as? String).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(app.staticTexts["\(seconds) 秒"].exists, "Read the actual selected UI speed before testing its consumer")
        if text.hasSuffix("%") {
            let percent = try XCTUnwrap(Double(String(text.dropLast()).trimmingCharacters(in: .whitespaces)))
            guard percent.isFinite, (0...100).contains(percent) else {
                XCTFail("Preserve an invalid native percentage instead of guessing its unit")
                throw JourneyError.prerequisite
            }
            XCTAssertEqual(CGFloat(percent / 100), CGFloat(seconds - 2) / 18, accuracy: 0.015)
        } else {
            guard text.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
                  let actualSeconds = Double(text), (2...20).contains(actualSeconds) else {
                XCTFail("A non-percent native value must be an actual 2...20 second value; unknown units are preserved")
                throw JourneyError.prerequisite
            }
            XCTAssertEqual(actualSeconds, Double(seconds), "The native seconds value must exactly match the observed Full speed")
        }
    }
    private func restoreAutomaticSpeed(_ owner: AutomaticSpeedRestoration, app: XCUIApplication) throws {
        guard owner.requested, !owner.restored else { return }
        try openAutomaticRestorationPanel(app)
        guard app.buttons["auto-page-toggle"].label == "开始自动翻页", !app.buttons["auto-page-stop"].isEnabled else {
            XCTFail("Stop this method's automatic session before restoring its speed")
            throw JourneyError.prerequisite
        }
        try quickAutomaticPage(app)
        try stepAutomaticSpeed(to: owner.original, owner: owner, app: app)
        try fullAutomaticPage(app)
        try assertFullAutomaticSpeed(owner.original, app: app)
        owner.restored = true
    }

    private struct AutomaticDisplayRecoveryTuple: Decodable {
        let mode: String
        let transition: String
        let selectable: String
        let paper: String
    }
    private struct Display { let mode: String; let transition: String; let selectable: String; let paper: String }
    private final class DisplaySetupRestoration {
        let paper: String
        let mode: String
        var modeChangeRequested = false
        var anyChangeRequested = false
        var handedOff = false
        init(paper: String, mode: String) { self.paper = paper; self.mode = mode }
    }
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
        let setup = DisplaySetupRestoration(paper: oldPaper, mode: oldMode)
        // Register mode first so XCTest restores it last, even when another
        // stage's teardown fails. Successful setup hands every stage off to
        // the caller's existing complete Display owner.
        addTeardownBlock {
            guard !setup.handedOff, setup.anyChangeRequested else { return }
            if app.state != .runningForeground { app.activate() }
            self.openModule("appearance", app: app)
            let picker = app.buttons["reading-page-mode"]
            self.reveal(picker, towardBottom: true, app: app)
            if setup.modeChangeRequested {
                try self.restoreSetupChoice(setup.mode, changedTo: "分页", picker: picker,
                    choices: ["滚动", "分页"], app: app)
            } else {
                XCTAssertEqual(try self.menuValue(picker, choices: ["滚动", "分页"]), setup.mode,
                               "Setup never owned a change to the original mode")
            }
            self.evidence(app, "tools-setup-captured-display-changes-restored")
            self.hideControls(app)
        }
        if oldMode != "分页" {
            setup.modeChangeRequested = true; setup.anyChangeRequested = true
            choose("分页", picker: mode, app: app)
        }
        let transition = app.buttons["reading-page-transition"]
        reveal(transition, towardBottom: true, app: app)
        let oldTransition = try menuValue(transition, choices: ["仿真", "覆盖", "滑动", "无动画"])
        if oldTransition != "滑动" {
            setup.anyChangeRequested = true
            addTeardownBlock {
                guard !setup.handedOff else { return }
                if app.state != .runningForeground { app.activate() }
                self.openModule("appearance", app: app)
                let mode = app.buttons["reading-page-mode"]
                self.reveal(mode, towardBottom: true, app: app)
                guard try self.menuValue(mode, choices: ["滚动", "分页"]) == "分页" else {
                    XCTFail("Preserve an unexpected mode; do not guess a hidden transition value")
                    throw JourneyError.prerequisite
                }
                let picker = app.buttons["reading-page-transition"]
                self.reveal(picker, towardBottom: true, app: app)
                try self.restoreSetupChoice(oldTransition, changedTo: "滑动", picker: picker,
                    choices: ["仿真", "覆盖", "滑动", "无动画"], app: app)
            }
            choose("滑动", picker: transition, app: app)
        }
        let selectable = app.switches["长按选择文本"]
        reveal(selectable, towardBottom: true, app: app)
        let oldSelectable = try XCTUnwrap(selectable.value as? String)
        if oldSelectable != "1" {
            guard oldSelectable == "0" else {
                XCTFail("Preserve an unrecognized original text-selection choice")
                throw JourneyError.prerequisite
            }
            setup.anyChangeRequested = true
            addTeardownBlock {
                guard !setup.handedOff else { return }
                if app.state != .runningForeground { app.activate() }
                self.openModule("appearance", app: app)
                let row = app.switches["长按选择文本"]
                self.reveal(row, towardBottom: true, app: app)
                let actual = try XCTUnwrap(row.value as? String)
                guard actual == oldSelectable || actual == "1" else {
                    XCTFail("Preserve a selection setting not attributable to this setup")
                    throw JourneyError.prerequisite
                }
                if actual != oldSelectable { self.setSwitch(row, to: oldSelectable) }
            }
            setSwitch(selectable, to: "1")
        }
        hideControls(app)
        let original = Display(mode: setup.mode, transition: oldTransition, selectable: oldSelectable, paper: setup.paper)
        setup.handedOff = true
        return original
    }
    private func restoreSetupChoice(_ original: String, changedTo target: String, picker: XCUIElement,
                                    choices: [String], app: XCUIApplication) throws {
        // Arming before a tap is not proof of a change. Restore only when the
        // current normal UI confirms this setup's requested value; an already
        // original value needs no write, and another value is preserved.
        let actual = try menuValue(picker, choices: choices)
        guard actual == original || actual == target else {
            XCTFail("Preserve a display choice not attributable to this setup")
            throw JourneyError.prerequisite
        }
        if actual != original { choose(original, picker: picker, app: app) }
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
        let paper = try originalPaperControl(old.paper, app: app)
        paper.tap()
        XCTAssertTrue(paper.isSelected, "Restore the original paper through its normal visible control even after a failed test")
        evidence(app, "tools-original-reader-display-restored"); hideControls(app)
    }
    private func originalPaperControl(_ name: String, app: XCUIApplication) throws -> XCUIElement {
        // The paper buttons are in LazyVGrid and can be absent from AX while
        // offscreen. Its eager section heading still identifies the real Full
        // appearance ScrollView; reveal that before querying the original key.
        let headings = app.staticTexts.matching(NSPredicate(format: "label == %@", "阅读纸色"))
        guard headings.count == 1 else {
            XCTFail("Require the unique actual paper section heading")
            throw JourneyError.prerequisite
        }
        reveal(headings.element, towardBottom: false, app: app)
        guard headings.element.isHittable else { throw JourneyError.prerequisite }
        let papers = app.buttons.matching(NSPredicate(format: "label == %@", name))
        guard papers.count == 1 else {
            XCTFail("The exact original paper must materialize uniquely after revealing its real section")
            throw JourneyError.prerequisite
        }
        let paper = papers.element
        reveal(paper, towardBottom: false, app: app)
        guard paper.isEnabled, paper.isHittable else { throw JourneyError.prerequisite }
        return paper
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
        // Keyboard dismissal and long preview text can leave a zero-frame AX
        // field thousands of points above the viewport. Re-establish the real
        // form's name row before each input instead of guessing its direction.
        let anchor = textInput("规则名称", app: app)
        reveal(anchor, towardBottom: false, app: app)
        XCTAssertTrue(anchor.isHittable)
        let field = textInput(placeholder, app: app); reveal(field, towardBottom: towardBottom, app: app)
        XCTAssertTrue(field.exists && field.isHittable); field.tap()
        let focused = textInput(placeholder, app: app)
        XCTAssertTrue(focused.exists)
        if !isEmpty(focused) { focused.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (focused.value as? String ?? "").count)) }
        // Axis.vertical text fields treat Return as content. Do not silently
        // append a newline to the real literal/replacement/scope definitions.
        focused.typeText(text)
        let updated = textInput(placeholder, app: app)
        XCTAssertEqual(updated.value as? String, text)
        dismissKeyboardByScrolling(app, field: updated)
    }
    private func textInput(_ identifier: String, app: XCUIApplication) -> XCUIElement {
        // The same SwiftUI axis.vertical input can change its reported AX role
        // when focused, and its placeholder disappears after entering content.
        // Resolve the replacement form's semantic names to declared stable IDs;
        // every input stage keeps that identity without a role/value predicate.
        let stableID: String
        switch identifier {
        case "规则名称": stableID = "replacement-draft-name"
        case "匹配内容": stableID = "replacement-draft-pattern"
        case "替换为": stableID = "replacement-draft-replacement"
        case "规则分组": stableID = "replacement-draft-group"
        case "排除范围": stableID = "replacement-draft-exclude-scope"
        case "作用范围，留空为全部": stableID = "replacement-draft-scope"
        default: stableID = identifier
        }
        return app.descendants(matching: .any).matching(identifier: stableID).firstMatch
    }
    private func dismissKeyboardByScrolling(_ app: XCUIApplication, field: XCUIElement) {
        guard app.keyboards.firstMatch.exists else { return }
        let hide = app.buttons.matching(NSPredicate(format: "label == '隐藏键盘' OR label == 'Hide keyboard' OR label == 'Dismiss keyboard'")).firstMatch
        if hide.exists && hide.isHittable { hide.tap(); return }
        // Native SwiftUI ScrollView keyboard dismissal, in the actual panel
        // viewport above the keyboard; no responder or App-state injection.
        guard let viewport = containingScrollViewport(field, app: app) else {
            XCTFail("The real editable field has no observed ScrollView viewport above the keyboard"); return
        }
        let inset = min(28, viewport.height * 0.15)
        let highY = viewport.minY + inset, lowY = viewport.maxY - inset
        XCTAssertGreaterThan(lowY, highY + 20, "The real panel must have room to dismiss its keyboard")
        coordinate(CGPoint(x: viewport.midX, y: lowY), app: app).press(forDuration: 0.05,
            thenDragTo: coordinate(CGPoint(x: viewport.midX, y: highY), app: app))
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
                guard let actual = containingScrollViewport(target, app: app) else {
                    XCTFail("No actual ScrollView contains the requested control: " + target.debugDescription); return
                }
                viewport = actual
            }
            let inset = min(36, viewport.height * 0.15)
            let top = viewport.minY + inset, bottom = viewport.maxY - inset
            XCTAssertGreaterThan(bottom, top + 30)
            if chapterIndex == nil {
                guard let frame = observedTargetFrame(target) else {
                    XCTFail("No public geometry locates the requested control: " + target.debugDescription); return
                }
                let distance: CGFloat
                if frame.height > bottom - top {
                    // Long Core preview text may exceed one viewport. Bring
                    // its real centre into view without inventing a smaller
                    // text frame or treating clipped text as a hit target.
                    if frame.midY < top { down = false; distance = (top + bottom) / 2 - frame.midY }
                    else if frame.midY > bottom { down = true; distance = frame.midY - (top + bottom) / 2 }
                    else {
                        XCTFail("The control's centre is already inside its actual ScrollView but is not hittable: " + target.debugDescription); return
                    }
                } else if frame.minY < top {
                    down = false; distance = top - frame.minY
                } else if frame.maxY > bottom {
                    down = true; distance = frame.maxY - bottom
                } else {
                    XCTFail("The control is already inside its safe ScrollView viewport but is not hittable: " + target.debugDescription); return
                }
                // The old full-span gesture oscillated a control between the
                // two clipped edges. Move only its observed missing distance;
                // the short end hold releases a stationary finger, avoiding
                // an inertial fling past the opposite edge.
                let travel = min(max(distance, 24), (bottom - top) * 0.6)
                let startY = down ? bottom : top
                let endY = down ? startY - travel : startY + travel
                let start = coordinate(CGPoint(x: viewport.midX, y: startY), app: app)
                let end = coordinate(CGPoint(x: viewport.midX, y: endY), app: app)
                start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
                continue
            }
            let high = coordinate(CGPoint(x: viewport.midX, y: top), app: app)
            let low = coordinate(CGPoint(x: viewport.midX, y: bottom), app: app)
            if down { low.press(forDuration: 0.05, thenDragTo: high) }
            else { high.press(forDuration: 0.05, thenDragTo: low) }
        }
        XCTFail("Actual control did not become hittable: " + target.debugDescription)
    }
    private func observedTargetFrame(_ target: XCUIElement) -> CGRect? {
        func usable(_ rect: CGRect) -> Bool {
            rect.minX.isFinite && rect.minY.isFinite && rect.width.isFinite && rect.height.isFinite
                && rect.width > 0 && rect.height > 0
        }
        let frame = target.frame
        if usable(frame) { return frame }
        // Empty axis.vertical fields may expose a zero outer AX frame while
        // their public descendant geometry still locates the real input row.
        // This determines scroll direction only; tapping still requires the
        // original editable control to become natively hittable.
        for child in target.descendants(matching: .any).allElementsBoundByIndex.prefix(16) {
            let frame = child.frame
            if usable(frame) { return frame }
        }
        return nil
    }
    private func containingScrollViewport(_ target: XCUIElement, app: XCUIApplication) -> CGRect? {
        guard target.exists else { return nil }
        let identifier = target.identifier, label = target.label
        let placeholder = target.placeholderValue ?? ""
        var selected: CGRect?
        for scroll in app.scrollViews.allElementsBoundByIndex {
            var viewport = scroll.frame.intersection(app.frame)
            guard !viewport.isNull, viewport.width > 80, viewport.height > 80 else { continue }
            let children = scroll.descendants(matching: .any)
            let containsTarget: Bool
            if !identifier.isEmpty { containsTarget = children.matching(identifier: identifier).count > 0 }
            else if !placeholder.isEmpty { containsTarget = children.matching(NSPredicate(format: "placeholderValue == %@", placeholder)).count > 0 }
            else if !label.isEmpty { containsTarget = children.matching(NSPredicate(format: "label == %@", label)).count > 0 }
            else { containsTarget = false }
            guard containsTarget else { continue }
            if app.keyboards.firstMatch.exists {
                let keyboard = app.keyboards.firstMatch.frame
                if viewport.intersects(keyboard) { viewport.size.height = max(0, keyboard.minY - 8 - viewport.minY) }
            }
            // At the actual Full endpoint, the Quick module bar is hidden.
            // Its retained AX frames cannot clip the real Full ScrollView.
            let grabber = app.buttons["control-grabber"]
            let full = grabber.exists && grabber.label.hasPrefix("完整控制栏")
            if !full {
                let modules = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'control-module-'"))
                    .allElementsBoundByIndex.filter(\.isHittable)
                for module in modules where viewport.intersects(module.frame) && module.frame.minY > viewport.minY {
                    viewport.size.height = min(viewport.maxY, module.frame.minY) - viewport.minY
                }
            }
            guard viewport.height > 80 else { continue }
            if let previous = selected, viewport.height >= previous.height { continue }
            selected = viewport
        }
        return selected
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
