import XCTest
import UIKit
import Vision
import CryptoKit

/// Bind every result to the delivery owner's sealed build. The real TXT must be
/// provisioned; all Core operations, clipboard use and positions originate in
/// the real App UI. This runner never calls Runtime or reads UIPasteboard.
final class ReaderReadingToolsJourneyTests: XCTestCase {
    // Only this explicitly selected original EPUB method uses WK. Existing
    // TXT methods retain their original identity on each XCTest instance.
    private var realEpubJourney = false
    private var bookID: String {
        realEpubJourney
            ? "book-local:5d6d9dd26bbea9ed0db4e4f7a127a538dfe439f5694c3370a30ac33503db9d67"
            : "book-local:aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5"
    }
    private let title = "仙子请听我解释"
    private enum JourneyError: Error { case prerequisite, nativeSelection, missingOwnedRule }
    private var displayRestored = false
    override func setUpWithError() throws { continueAfterFailure = false }

    /// Only the existing registered bundled faces and existing real TXT.
    /// Root independently binds raw preferences, original scope and products;
    /// this zero-environment method records actual public UI observations.
    func testExistingRealTXTRegisteredFontSelectionOrderAndColdAnchorWithOriginalPreferencesRestored() throws {
        guard !realEpubJourney,
              bookID == "book-local:aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5" else {
            XCTFail("Only the existing original TXT identity is allowed; never import or substitute a book")
            throw JourneyError.prerequisite
        }
        let app = XCUIApplication()
        guard app.state == .notRunning else {
            XCTFail("Root must establish the fresh no-App premise; do not terminate a live reading session to create it")
            throw JourneyError.prerequisite
        }
        let labels = ["系统（iOS）", "宋体", "黑体", "楷体", "仿宋", "等宽", "思源宋体", "霞鹜文楷"]
        let systemLabel = "系统（iOS）", serifLabel = "宋体"
        var fontMayHaveChanged = false, orderMayHaveChanged = false
        var returnedNormally = false
        var originalAnchor = ""
        var originalChapterIdentifier: String?
        var originalBookIdentifier: String?
        var fontObservations: [String: String] = [:]
        var visibleOrderObservations: [String: Bool] = [:]
        func existingBook() throws {
            try openExistingRuleRoundtripBook(app) // Existing exact-identity/no-filter-mutation harness.
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "reading-ebook-body").firstMatch.exists)
            openModule("home", app: app)
            let chapter = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'reading-chapter:'"))
            guard chapter.count == 1,
                  UInt32(chapter.element.identifier.dropFirst("reading-chapter:".count)) != nil else {
                XCTFail("Read one actual canonical chapter identity from the current original reader")
                throw JourneyError.prerequisite
            }
            let currentChapter = chapter.element.identifier
            if let originalChapterIdentifier {
                XCTAssertEqual(currentChapter, originalChapterIdentifier, "Every normal/cold reopen must retain the first actual UI chapter; never seek to manufacture it")
            } else { originalChapterIdentifier = currentChapter }
            let identity = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "reading-book:local|" + String(bookID.dropFirst(5))))
            XCTAssertEqual(identity.count, 1); XCTAssertEqual(identity.element.label, title)
            originalBookIdentifier = identity.element.identifier
            hideControls(app)
        }
        func fontPicker() throws -> XCUIElement {
            openModule("appearance", app: app)
            let query = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "正文字体"))
            XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 5)); XCTAssertEqual(query.count, 1)
            let picker = query.element
            reveal(picker, towardBottom: false, app: app)
            guard picker.isHittable && picker.isEnabled else { throw JourneyError.prerequisite }
            return picker
        }
        func selectedFont(_ picker: XCUIElement) throws -> String {
            let values = [picker.value as? String, picker.label].compactMap { $0 }
            // The longer same-face alias must not be mistaken for 宋体.
            let found = labels.sorted { $0.count > $1.count }.first { label in
                values.contains { $0 == label || $0.hasSuffix(", " + label) || $0.hasSuffix("," + label) || $0.hasSuffix("，" + label) || $0.hasSuffix("、" + label) }
            }
            guard let found else {
                XCTFail("Read the actual native font Picker value before any change: " + picker.debugDescription)
                throw JourneyError.prerequisite
            }
            return found
        }
        func editor(_ editing: Bool) throws {
            let name = editing ? "编辑" : "完成"
            let english = editing ? "Edit" : "Done"
            let candidates = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", name, english))
            if candidates.count == 1, !candidates.element.isHittable {
                reveal(candidates.element, towardBottom: true, app: app)
            }
            let controls = candidates.allElementsBoundByIndex.filter(\.isHittable)
            if controls.isEmpty {
                let currentName = editing ? "完成" : "编辑"
                let currentEnglish = editing ? "Done" : "Edit"
                let current = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", currentName, currentEnglish))
                    .allElementsBoundByIndex.filter(\.isHittable)
                if current.count == 1 { return } // Already at the requested actual native state.
            }
            guard controls.count == 1, let button = controls.first, button.isEnabled else {
                XCTFail("One real native font Edit/Done control is required; do not inject edit mode")
                throw JourneyError.prerequisite
            }
            button.tap()
        }
        func fontSectionOwner() throws -> (scroll: XCUIElement, viewport: CGRect, preview: XCUIElement) {
            let previewLabel = "天地玄黄，宇宙洪荒。Reader 123"
            // The List is a nested CollectionView. Bind its real outer owner
            // by all existing font-section facts, never by an unlabeled Cell.
            let owners = app.scrollViews.allElementsBoundByIndex.filter { scroll in
                scroll.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "正文字体")).count == 1
                    && scroll.staticTexts.matching(NSPredicate(format: "label == %@", previewLabel)).count == 1
                    && scroll.cells.containing(.staticText, identifier: systemLabel).count == 1
                    && scroll.cells.containing(.staticText, identifier: serifLabel).count == 1
            }
            guard owners.count == 1, let scroll = owners.first,
                  app.buttons["control-grabber"].label.hasPrefix("完整控制栏"),
                  app.keyboards.count == 0 else {
                XCTFail("Require one actual Full font-section ScrollView containing its Picker, preview and both existing List rows")
                throw JourneyError.prerequisite
            }
            // Full has no Quick module-bar overlay. Use the actual owner and
            // window intersection; no retained Quick-frame or screen guess.
            let viewport = scroll.frame.intersection(app.frame).insetBy(dx: 10, dy: 10)
            guard !viewport.isNull, viewport.width > 180, viewport.height > 180,
                  scroll.isHittable else { throw JourneyError.prerequisite }
            return (scroll, viewport, scroll.staticTexts.matching(NSPredicate(format: "label == %@", previewLabel)).element)
        }
        func reorderPair() throws -> (system: XCUIElement, serif: XCUIElement, handle: XCUIElement, viewport: CGRect) {
            for step in 0..<6 {
                let owner = try fontSectionOwner()
                let systems = owner.scroll.cells.containing(.staticText, identifier: systemLabel)
                let serifs = owner.scroll.cells.containing(.staticText, identifier: serifLabel)
                guard systems.count == 1, serifs.count == 1 else { throw JourneyError.prerequisite }
                let system = systems.element, serif = serifs.element
                let predicate = NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "重新排序", "Reorder")
                let systemHandles = system.buttons.matching(predicate), serifHandles = serif.buttons.matching(predicate)
                guard systemHandles.count == 1, serifHandles.count == 1 else {
                    XCTFail("Require each real native onMove handle; never invent a reorder touch target")
                    throw JourneyError.prerequisite
                }
                let handle = systemHandles.element, otherHandle = serifHandles.element
                let systemFrame = system.frame, serifFrame = serif.frame
                let frames = [systemFrame, serifFrame, handle.frame, otherHandle.frame]
                guard frames.allSatisfy({ !$0.isNull && $0.width > 0 && $0.height > 0
                    && $0.minX.isFinite && $0.minY.isFinite && $0.maxX.isFinite && $0.maxY.isFinite }),
                      !systemFrame.intersects(serifFrame) else { throw JourneyError.prerequisite }
                let dropX = serifFrame.minX + serifFrame.width * 0.75
                let dropBefore = CGPoint(x: dropX, y: serifFrame.minY + serifFrame.height * 0.15)
                let dropAfter = CGPoint(x: dropX, y: serifFrame.minY + serifFrame.height * 0.85)
                let fullyVisible = frames.allSatisfy { owner.viewport.contains($0) }
                    && owner.viewport.contains(dropBefore) && owner.viewport.contains(dropAfter)
                if fullyVisible {
                    guard system.isHittable, serif.isHittable, handle.isHittable, otherHandle.isHittable,
                          handle.isEnabled, otherHandle.isEnabled else {
                        XCTFail("Fully contained native font rows and handles must also be genuinely hittable")
                        throw JourneyError.prerequisite
                    }
                    let facts: [String: Any] = ["step":step,"owner":NSCoder.string(for: owner.scroll.frame),
                        "safeViewport":NSCoder.string(for: owner.viewport),
                        "systemRow":NSCoder.string(for: systemFrame),"serifRow":NSCoder.string(for: serifFrame),
                        "systemHandle":NSCoder.string(for: handle.frame),"serifHandle":NSCoder.string(for: otherHandle.frame),
                        "beforeDrop":NSCoder.string(for: CGRect(origin: dropBefore, size: .zero)),
                        "afterDrop":NSCoder.string(for: CGRect(origin: dropAfter, size: .zero)),
                        "wholeRowsAndHandlesAndBothDropsContained":true]
                    let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts,
                        options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
                    attachment.name = "real-font-reorder-actual-owner-and-safe-points"
                    attachment.lifetime = .keepAlways; add(attachment)
                    return (system, serif, handle, owner.viewport)
                }
                let rows = systemFrame.union(serifFrame)
                guard rows.height <= owner.viewport.height,
                      rows.minX >= owner.viewport.minX, rows.maxX <= owner.viewport.maxX else {
                    XCTFail("The two whole real font rows must fit this active font-section viewport")
                    throw JourneyError.prerequisite
                }
                let towardBottom = rows.maxY > owner.viewport.maxY
                let missing = towardBottom ? rows.maxY - owner.viewport.maxY : owner.viewport.minY - rows.minY
                let preview = owner.preview.frame.intersection(owner.viewport)
                guard missing > 0, owner.preview.isHittable, !preview.isNull,
                      preview.width > 60, preview.height > 16 else {
                    XCTFail("Only an actual visible noninteractive font preview may drive the required outer scroll")
                    throw JourneyError.prerequisite
                }
                let start = CGPoint(x: preview.midX, y: preview.midY)
                let available = towardBottom ? start.y - owner.viewport.minY - 12 : owner.viewport.maxY - start.y - 12
                let travel = min(max(missing + 12, 36), min(140, available))
                guard travel >= 24 else { throw JourneyError.prerequisite }
                let end = CGPoint(x: start.x, y: start.y + (towardBottom ? -travel : travel))
                guard owner.viewport.contains(start), owner.viewport.contains(end) else { throw JourneyError.prerequisite }
                coordinate(start, app: app).press(forDuration: 0.05,
                    thenDragTo: coordinate(end, app: app), withVelocity: .slow, thenHoldForDuration: 0.15)
            }
            evidence(app, "real-font-reorder-safe-viewport-prerequisite-failed")
            XCTFail("Both actual font rows, native handles and drop points must become fully visible before any persistent change")
            throw JourneyError.prerequisite
        }
        func orderSystemBeforeSerif() throws -> Bool {
            let pair = try reorderPair()
            guard pair.system.frame.intersects(app.frame), pair.serif.frame.intersects(app.frame),
                  !pair.system.frame.intersects(pair.serif.frame) else { throw JourneyError.prerequisite }
            return pair.system.frame.midY < pair.serif.frame.midY
        }
        // Poll only actual row order. Native onMove may temporarily expose
        // overlapping/missing AX frames; no prerequisite assertion or scroll
        // is allowed to run inside the post-drop observation predicate.
        func observedSystemBeforeSerif() -> Bool? {
            let systems = app.cells.containing(.staticText, identifier: systemLabel)
            let serifs = app.cells.containing(.staticText, identifier: serifLabel)
            guard systems.count == 1, serifs.count == 1 else { return nil }
            let system = systems.element, serif = serifs.element
            let a = system.frame, b = serif.frame
            guard [a,b].allSatisfy({ !$0.isNull && $0.width > 0 && $0.height > 0
                && $0.minX.isFinite && $0.minY.isFinite && $0.maxX.isFinite && $0.maxY.isFinite }),
                  !a.intersects(b), system.isHittable, serif.isHittable else { return nil }
            return a.midY < b.midY
        }
        func moveSystem(beforeSerif: Bool) throws {
            let pair = try reorderPair()
            let dy: CGFloat = beforeSerif ? 0.15 : 0.85
            let source = CGPoint(x: pair.handle.frame.midX, y: pair.handle.frame.midY)
            let target = CGPoint(x: pair.serif.frame.minX + pair.serif.frame.width * 0.75,
                y: pair.serif.frame.minY + pair.serif.frame.height * dy)
            guard pair.viewport.contains(source), pair.viewport.contains(target) else { throw JourneyError.prerequisite }
            pair.handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.6,
                thenDragTo: pair.serif.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: dy)),
                withVelocity: .slow, thenHoldForDuration: 0.2)
            let settledOrder = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                observedSystemBeforeSerif() == beforeSerif
            }, object: nil)
            guard XCTWaiter.wait(for: [settledOrder], timeout: 5) == .completed else {
                let detail = XCTAttachment(string: app.debugDescription)
                detail.name = "real-font-postdrop-order-not-observed"
                detail.lifetime = .keepAlways; add(detail)
                evidence(app, "real-font-postdrop-order-not-observed")
                XCTFail("The one actual onMove did not expose the expected settled native row order")
                throw JourneyError.prerequisite
            }
            XCTAssertEqual(try orderSystemBeforeSerif(), beforeSerif)
        }
        func bodyPixels(_ capture: Screen) throws -> String {
            let crop = try XCTUnwrap(capture.image.cropping(to: capture.pixelCrop))
            return SHA256.hash(data: Data(try rgba(crop))).map { String(format: "%02x", $0) }.joined()
        }
        func restoreOwnedFontChanges() throws {
            if app.state == .notRunning { app.launch(); try existingBook() }
            let picker = try fontPicker()
            if fontMayHaveChanged {
                if try selectedFont(picker) != serifLabel { choose(serifLabel, picker: picker, app: app) }
                let restored = try selectedFont(picker)
                XCTAssertEqual(restored, serifLabel); fontObservations["normal-restored"] = restored
                fontMayHaveChanged = false // Root independently checks the product setter restored both raw keys absent.
            }
            if orderMayHaveChanged {
                try editor(true)
                if try !orderSystemBeforeSerif() { try moveSystem(beforeSerif: true) }
                let restoredOrder = try orderSystemBeforeSerif()
                XCTAssertTrue(restoredOrder); visibleOrderObservations["normal-restored-system-before-serif"] = restoredOrder
                try editor(false); orderMayHaveChanged = false
            }
            hideControls(app)
        }
        addTeardownBlock {
            if fontMayHaveChanged || orderMayHaveChanged {
                // Recover only these actual UI choices. Never clear defaults,
                // select another book, repeat import, or reset all settings.
                try restoreOwnedFontChanges()
            }
            if !returnedNormally { self.evidence(app, "real-font-failed-original-state-and-recovery-boundary") }
        }
        app.launch(); try existingBook()
        originalAnchor = try anchor(app, name: "real-font-original-txt-visible-anchor")
        let before = try screen(app)
        let originalPixels = try bodyPixels(before)
        var picker = try fontPicker()
        let initialFont = try selectedFont(picker)
        XCTAssertEqual(initialFont, serifLabel); fontObservations["initial"] = initialFont
        // Reachability is checked before the first persisted choice. Edit mode
        // itself is transient; an absent handle leaves this method unexecuted.
        try editor(true)
        let initialPair = try reorderPair() // Explicit complete owner/rows/handles/drop preflight before the first font write.
        let initialOrder = initialPair.system.frame.midY < initialPair.serif.frame.midY
        XCTAssertTrue(initialOrder); visibleOrderObservations["initial-system-before-serif"] = initialOrder
        try editor(false)
        picker = try fontPicker()
        picker.tap()
        let sans = app.buttons.matching(NSPredicate(format: "label == %@", "黑体"))
        guard sans.count == 1, sans.element.isHittable, sans.element.isEnabled else {
            XCTFail("Require the actually available registered bundled 黑体 menu item; never import or substitute a font")
            throw JourneyError.prerequisite
        }
        fontMayHaveChanged = true; sans.element.tap()
        XCTAssertEqual(try selectedFont(picker), "黑体")
        try editor(true)
        orderMayHaveChanged = true; try moveSystem(beforeSerif: false)
        try editor(false)
        let changedFont = try selectedFont(picker)
        XCTAssertEqual(changedFont, "黑体"); fontObservations["after-selection-and-move"] = changedFont
        evidence(app, "real-font-actual-sans-choice-and-one-normal-onMove")
        hideControls(app)
        try assertVisible(originalAnchor, app: app, name: "real-font-registered-sans-keeps-original-passage")
        let after = try screen(app)
        XCTAssertEqual(after.viewport, before.viewport)
        let bodyPixelsDiffer = try bodyPixels(after) != originalPixels
        XCTAssertTrue(bodyPixelsDiffer,
            "The same actual paper viewport must render differently after only the real font choice; no exact line-wrap or 2pt paragraph equality is required")
        leaveReader(app); app.terminate(); app.launch(); try existingBook()
        try assertVisible(originalAnchor, app: app, name: "real-font-cold-sans-keeps-original-passage")
        picker = try fontPicker()
        let coldChangedFont = try selectedFont(picker)
        XCTAssertEqual(coldChangedFont, "黑体"); fontObservations["first-cold"] = coldChangedFont
        try editor(true)
        let coldChangedOrder = try orderSystemBeforeSerif()
        XCTAssertFalse(coldChangedOrder); visibleOrderObservations["first-cold-system-before-serif"] = coldChangedOrder
        try editor(false)
        try restoreOwnedFontChanges()
        try assertVisible(originalAnchor, app: app, name: "real-font-normal-ui-restored-default-keeps-original-passage")
        leaveReader(app); app.terminate(); app.launch(); try existingBook()
        try assertVisible(originalAnchor, app: app, name: "real-font-second-cold-original-default-anchor")
        picker = try fontPicker()
        let coldRestoredFont = try selectedFont(picker)
        XCTAssertEqual(coldRestoredFont, serifLabel); fontObservations["second-cold-restored"] = coldRestoredFont
        try editor(true)
        let coldRestoredOrder = try orderSystemBeforeSerif()
        XCTAssertTrue(coldRestoredOrder); visibleOrderObservations["second-cold-restored-system-before-serif"] = coldRestoredOrder
        try editor(false)
        hideControls(app); leaveReader(app); returnedNormally = true
        let facts: [String: Any] = ["bookAXID":try XCTUnwrap(originalBookIdentifier),
            "chapterAXID":try XCTUnwrap(originalChapterIdentifier),"originalVisibleAnchor":originalAnchor,
            "observedFontPickerValues":fontObservations,"observedSystemBeforeSerif":visibleOrderObservations,
            "sameViewportBodyPixelsDifferAfterFontChoice":bodyPixelsDiffer,"normalReturnToShelfObserved":returnedNormally,
            "boundary":"Only actual public UI observations are recorded here. Root independently binds the current original TXT/Core scope, initial absent font keys, exact full order, complete raw preferences, original assets and source/products; those are not observable as UI facts. Body pixel inequality is bounded to the same visible viewport after the font-only choice; it does not identify a physical font table or establish full typography/motion acceptance."]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "real-font-original-txt-selection-order-cold-and-restoration-facts.json"
        attachment.lifetime = .keepAlways; add(attachment)
    }

    /// Read only the restored outcome after the preserved Font69 failure.
    /// Root binds its final nil font keys/full order before this fresh launch.
    func testExistingRestoredFont69ColdReadOnlyTailPreservesOriginalTextAndDefaultOrder() throws {
        let app = XCUIApplication()
        guard !realEpubJourney, app.state == .notRunning else {
            XCTFail("Require the original TXT and Root's actual fresh no-App premise; never terminate a live session")
            throw JourneyError.prerequisite
        }
        let expectedAnchor = "而头颅上那一双和善的双眸正目泛幽光的盯着他"
        let systemLabel = "系统（iOS）", serifLabel = "宋体"
        let previewLabel = "天地玄黄，宇宙洪荒。Reader 123"
        // Exact OCR from Font69's original visible-anchor attachment. This
        // tail never selects a chapter, seeks or restores a preference.
        app.launch()
        try openExistingRuleRoundtripBook(app)
        openModule("home", app: app)
        let chapter = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'reading-chapter:'"))
        XCTAssertEqual(chapter.count, 1)
        XCTAssertEqual(chapter.element.identifier, "reading-chapter:1")
        let identity = app.staticTexts.matching(NSPredicate(format: "identifier == %@",
            "reading-book:local|" + String(bookID.dropFirst(5))))
        XCTAssertEqual(identity.count, 1); XCTAssertEqual(identity.element.label, title)
        let actualBookID = identity.element.identifier
        hideControls(app)
        try assertVisible(expectedAnchor, app: app, name: "font69-restored-cold-readonly-original-anchor")
        openModule("appearance", app: app)
        let pickers = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "正文字体"))
        XCTAssertTrue(pickers.firstMatch.waitForExistence(timeout: 5)); XCTAssertEqual(pickers.count, 1)
        let picker = pickers.element
        reveal(picker, towardBottom: false, app: app)
        let choices = ["系统（iOS）", "宋体", "黑体", "楷体", "仿宋", "等宽", "思源宋体", "霞鹜文楷"]
        func currentFont() throws -> String {
            let values = [picker.value as? String, picker.label].compactMap { $0 }
            let match = choices.sorted { $0.count > $1.count }.first { name in
                values.contains { $0 == name || $0.hasSuffix(", " + name) || $0.hasSuffix("," + name)
                    || $0.hasSuffix("，" + name) || $0.hasSuffix("、" + name) }
            }
            return try XCTUnwrap(match, "Read the exact actual native font label; do not choose a font")
        }
        let actualFont = try currentFont()
        XCTAssertEqual(actualFont, serifLabel)
        let edit = app.buttons.matching(NSPredicate(format: "label == '编辑' OR label == 'Edit'"))
        XCTAssertEqual(edit.count, 1)
        if !edit.element.isHittable { reveal(edit.element, towardBottom: true, app: app) }
        XCTAssertTrue(edit.element.isHittable && edit.element.isEnabled); edit.element.tap()
        var orderFacts: [String: Any]?
        for step in 0...6 {
            let owners = app.scrollViews.allElementsBoundByIndex.filter { scroll in
                scroll.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "正文字体")).count == 1
                    && scroll.staticTexts.matching(NSPredicate(format: "label == %@", previewLabel)).count == 1
                    && scroll.cells.containing(.staticText, identifier: systemLabel).count == 1
                    && scroll.cells.containing(.staticText, identifier: serifLabel).count == 1
            }
            guard owners.count == 1, let owner = owners.first,
                  app.buttons["control-grabber"].label.hasPrefix("完整控制栏"),
                  app.keyboards.count == 0 else { throw JourneyError.prerequisite }
            let viewport = owner.frame.intersection(app.frame).insetBy(dx: 10, dy: 10)
            let system = owner.cells.containing(.staticText, identifier: systemLabel).element
            let serif = owner.cells.containing(.staticText, identifier: serifLabel).element
            let systemFrame = system.frame, serifFrame = serif.frame
            guard !viewport.isNull, viewport.width > 180, viewport.height > 180,
                  systemFrame.width > 0, systemFrame.height > 0, serifFrame.width > 0, serifFrame.height > 0,
                  !systemFrame.intersects(serifFrame) else { throw JourneyError.prerequisite }
            if viewport.contains(systemFrame), viewport.contains(serifFrame) {
                XCTAssertTrue(system.isHittable && serif.isHittable)
                XCTAssertLessThan(systemFrame.midY, serifFrame.midY, "Read the actual restored order; never perform onMove")
                orderFacts = ["safeViewport":NSCoder.string(for: viewport),
                    "systemRow":NSCoder.string(for: systemFrame),"serifRow":NSCoder.string(for: serifFrame),
                    "completeRowsVisible":true,"observedSystemBeforeSerif":true]
                break
            }
            guard step < 6 else { break }
            let rows = systemFrame.union(serifFrame)
            let preview = owner.staticTexts.matching(NSPredicate(format: "label == %@", previewLabel)).element
            let visible = preview.frame.intersection(viewport)
            let towardBottom = rows.maxY > viewport.maxY
            let missing = towardBottom ? rows.maxY - viewport.maxY : viewport.minY - rows.minY
            guard rows.height <= viewport.height, rows.minX >= viewport.minX, rows.maxX <= viewport.maxX,
                  missing > 0, preview.isHittable, !visible.isNull, visible.width > 60, visible.height > 16 else {
                throw JourneyError.prerequisite
            }
            let start = CGPoint(x: visible.midX, y: visible.midY)
            let available = towardBottom ? start.y - viewport.minY - 12 : viewport.maxY - start.y - 12
            let travel = min(max(missing + 12, 36), min(140, available))
            let end = CGPoint(x: start.x, y: start.y + (towardBottom ? -travel : travel))
            guard travel >= 24, viewport.contains(start), viewport.contains(end) else { throw JourneyError.prerequisite }
            // A short real scroll on noninteractive preview text only. Native
            // reorder handles, font menu items and import controls are untouched.
            coordinate(start, app: app).press(forDuration: 0.05,
                thenDragTo: coordinate(end, app: app), withVelocity: .slow, thenHoldForDuration: 0.15)
        }
        let actualOrder = try XCTUnwrap(orderFacts, "Both original font rows must be completely visible in their real owner")
        let done = app.buttons.matching(NSPredicate(format: "label == '完成' OR label == 'Done'"))
        XCTAssertEqual(done.count, 1); XCTAssertTrue(done.element.isHittable && done.element.isEnabled)
        done.element.tap()
        XCTAssertEqual(try currentFont(), serifLabel)
        hideControls(app)
        try assertVisible(expectedAnchor, app: app, name: "font69-restored-readonly-settings-return-original-anchor")
        assertChapter(1, app: app)
        try assertVisible(expectedAnchor, app: app, name: "font69-restored-readonly-final-original-anchor")
        leaveReader(app)
        let facts: [String: Any] = ["originalRun":"large-font-selection-order-native69-1",
            "bookAXID":actualBookID,"chapterAXID":"reading-chapter:1",
            "originalVisibleAnchor":expectedAnchor,"observedFontPickerValue":actualFont,
            "observedSystemBeforeSerif":true,"normalReturnToShelfObserved":true,"actualOrderGeometry":actualOrder,
            "fontChoicesRequested":0,"reorderDragsRequested":0,"annotationWritesRequested":0,
            "boundary":"This is only a new cold read-only tail. Font69 remains failed. Full raw nine-item order, absent font keys, original user preferences/positions/files and exact timing ACKs require the external account; UI observations do not replace them."]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts,
            options: [.sortedKeys,.prettyPrinted]), uniformTypeIdentifier: "public.json")
        attachment.name = "real-font69-restored-cold-readonly-tail-facts.json"
        attachment.lifetime = .keepAlways; add(attachment)
    }

    /// Probe only the existing real Files item. An unavailable or ambiguous
    /// Reader activity remains an observed prerequisite failure, never a fake
    /// external-open success or an App picker/URL-injection substitute.
    func testExistingRealTXTExternalFilesReaderActivityRecognizesDuplicateWithoutLibraryMutation() throws {
        let app = XCUIApplication()
        let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        let filename = "仙子请听我解释.txt"
        guard !realEpubJourney, app.state == .notRunning else {
            XCTFail("Require Root's actual original TXT/no-Reader premise; never stop a live session")
            throw JourneyError.prerequisite
        }
        var readerActivityTaps = 0
        func systemEvidence(_ name: String) {
            let ax = XCTAttachment(string: files.debugDescription)
            ax.name = name + "-actual-Files-AX"; ax.lifetime = .keepAlways; add(ax)
            let image = XCTAttachment(screenshot: files.screenshot())
            image.name = name + "-actual-Files"; image.lifetime = .keepAlways; add(image)
        }
        func unavailable(_ detail: String, name: String) throws -> Never {
            systemEvidence(name)
            XCTFail(detail + ". Preserve this actual prerequisite failure; no alternate route or new file is authorized.")
            throw JourneyError.prerequisite
        }
        if files.state == .notRunning { files.launch() } else { files.activate() }
        let localNames = ["我的 iPhone", "我的iPhone", "On My iPhone"]
        let browseNames = ["浏览", "Browse"]
        var visited = Set<String>()
        var enteredLocal = false, enteredReader = false
        for _ in 0..<6 {
            let local = files.cells.containing(NSPredicate(format: "label IN %@", localNames))
                .allElementsBoundByIndex.filter(\.isHittable)
            if local.count == 1, let cell = local.first, visited.insert("local:" + cell.label).inserted {
                cell.tap(); enteredLocal = true; continue
            }
            if enteredLocal {
                let folders = files.cells.matching(NSPredicate(format:
                    "identifier == 'Reader, Container' OR label == 'Reader' OR label BEGINSWITH 'Reader,'"))
                    .allElementsBoundByIndex.filter(\.isHittable)
                if folders.count == 1, let cell = folders.first {
                    cell.tap(); enteredReader = true; break
                }
            }
            let navigation = files.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", browseNames))
                .allElementsBoundByIndex.filter(\.isHittable)
            if navigation.count == 1, let button = navigation.first,
               visited.insert("navigation-browse:" + button.identifier + button.label).inserted {
                button.tap(); continue
            }
            let tabs = files.tabBars.buttons.matching(NSPredicate(format: "label IN %@", browseNames))
                .allElementsBoundByIndex.filter(\.isHittable)
            if tabs.count == 1, let button = tabs.first,
               visited.insert("tab-browse:" + button.identifier + button.label).inserted {
                button.tap(); continue
            }
            let back = files.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", localNames))
                .allElementsBoundByIndex.filter(\.isHittable)
            if back.count == 1, let button = back.first, visited.insert("back-local:" + button.label).inserted {
                button.tap(); enteredLocal = true; continue
            }
            break
        }
        guard enteredLocal && enteredReader else {
            try unavailable("The real Files Browse → On My iPhone → Reader path was not uniquely exposed",
                name: "external-TXT-native-Files-location-unavailable")
        }
        let names = [filename, title]
        let originals = files.cells.containing(NSPredicate(format: "label IN %@", names))
        guard originals.firstMatch.waitForExistence(timeout: 10) else {
            try unavailable("The original exact TXT item is not present in this actual Reader folder",
                name: "external-TXT-original-item-unavailable")
        }
        let visible = originals.allElementsBoundByIndex.filter(\.isHittable)
        guard visible.count == 1, let original = visible.first,
              original.staticTexts.matching(NSPredicate(format: "label IN %@", names)).count == 1 else {
            try unavailable("Require one exact original filename cell; no default file tap or blind scrolling",
                name: "external-TXT-original-item-ambiguous")
        }
        let originalCellLabel = original.label
        systemEvidence("external-TXT-original-Files-item-before-long-press")
        original.press(forDuration: 1.0)
        systemEvidence("external-TXT-original-native-context-menu")
        let activityNames = ["Reader", "Open in Reader", "Copy to Reader",
            "在 Reader 中打开", "在Reader中打开", "拷贝到 Reader", "拷贝到Reader"]
        var actualShareCaption: String?
        var actualShareMetadata: String?
        func actualReaderActivities() throws -> [XCUIElement] {
            let owners = files.otherElements.matching(identifier: "ActivityListView")
            if owners.count > 0 {
                guard owners.count == 1 else {
                    try unavailable("The actual native sharing owner must be unique",
                        name: "external-TXT-native-share-owner-ambiguous")
                }
                let owner = owners.element
                let bars = owner.navigationBars.matching(identifier: "UIActivityContentView")
                guard bars.firstMatch.waitForExistence(timeout: 5), bars.count == 1 else {
                    try unavailable("The actual native share owner must expose its content caption bar",
                        name: "external-TXT-native-share-caption-bar-unavailable")
                }
                // These are the original Files71 native Other captions, not
                // StaticText or the dimmed filename cell behind the sheet.
                let tops = bars.element.otherElements.matching(identifier: "LP.CaptionBar.TopCaption")
                let bottoms = bars.element.otherElements.matching(identifier: "LP.CaptionBar.BottomCaption")
                guard tops.firstMatch.waitForExistence(timeout: 5), bottoms.firstMatch.waitForExistence(timeout: 5),
                      tops.count == 1, bottoms.count == 1,
                      tops.element.label == title,
                      bottoms.element.label == "文本文稿 · 8.9 MB" else {
                    try unavailable("The real share captions must identify this exact original TXT title, kind and observed size",
                        name: "external-TXT-native-share-file-identity-unconfirmed")
                }
                let viewport = owner.frame.intersection(files.frame)
                guard !viewport.isNull, viewport.width > 100, viewport.height > 100,
                      tops.element.frame.width > 0, tops.element.frame.height > 0,
                      bottoms.element.frame.width > 0, bottoms.element.frame.height > 0,
                      viewport.contains(tops.element.frame), viewport.contains(bottoms.element.frame) else {
                    try unavailable("Both exact native share captions must be visibly inside this same actual owner",
                        name: "external-TXT-native-share-captions-not-visible")
                }
                actualShareCaption = tops.element.label
                actualShareMetadata = bottoms.element.label
                let collections = owner.collectionViews.matching(identifier: "activityCollectionView")
                guard collections.count == 1 else {
                    try unavailable("Require this owner's actual native activity collection",
                        name: "external-TXT-native-share-collection-unavailable")
                }
                let readers = collections.element.cells.matching(NSPredicate(format:
                    "identifier == 'shareCell' AND label == 'Reader'"))
                guard readers.firstMatch.waitForExistence(timeout: 5), readers.count == 1 else {
                    try unavailable("Require one explicitly named Reader shareCell in this exact native sharing owner",
                        name: "external-TXT-native-Reader-shareCell-ambiguous-or-absent")
                }
                return readers.allElementsBoundByIndex.filter {
                    $0.isHittable && $0.isEnabled && $0.frame.width > 0 && $0.frame.height > 0
                        && viewport.contains($0.frame)
                }
            }
            // Preserve the original direct context-menu path if the real
            // system exposes an explicit Reader menu item instead of a sheet.
            let bars = files.navigationBars.allElementsBoundByIndex.map(\.frame)
            let predicate = NSPredicate(format: "label IN %@", activityNames)
            let menuItems = files.menuItems.matching(predicate).allElementsBoundByIndex.filter(\.isHittable)
            let candidates = menuItems.isEmpty ? files.buttons.matching(predicate).allElementsBoundByIndex.filter(\.isHittable) : menuItems
            return candidates.filter { item in
                item.isEnabled && item.frame.intersects(files.frame)
                    && !bars.contains(where: { $0.contains(CGPoint(x: item.frame.midX, y: item.frame.midY)) })
            }
        }
        var activities = try actualReaderActivities()
        var shareTapped = false
        if activities.isEmpty {
            let shares = files.menuItems.matching(NSPredicate(format: "label IN %@", ["共享", "分享", "Share"]))
                .allElementsBoundByIndex.filter(\.isHittable)
            let buttons = files.buttons.matching(NSPredicate(format: "label IN %@", ["共享", "分享", "Share"]))
                .allElementsBoundByIndex.filter(\.isHittable)
            let actual = shares.isEmpty ? buttons : shares
            guard actual.count == 1, let share = actual.first, share.isEnabled else {
                try unavailable("The actual original-file menu has neither a unique explicit Reader activity nor one native Share action",
                    name: "external-TXT-Reader-activity-unavailable")
            }
            share.tap(); shareTapped = true
            let owner = files.otherElements.matching(identifier: "ActivityListView")
            guard owner.firstMatch.waitForExistence(timeout: 5), owner.count == 1 else {
                try unavailable("The normal Share action must produce one actual native ActivityListView",
                    name: "external-TXT-native-share-owner-unavailable")
            }
            systemEvidence("external-TXT-original-native-share-candidates")
            activities = try actualReaderActivities()
        }
        guard activities.count == 1, let activity = activities.first else {
            try unavailable("Reader is not a unique explicitly named activity in this actual original-file menu",
                name: "external-TXT-native-Reader-activity-ambiguous-or-absent")
        }
        let actualActivityLabel = activity.label
        activity.tap(); readerActivityTaps += 1 // Exactly one normal system handoff; never activate/launch Reader here.
        waitUntil("The one actual Files Reader activity foregrounds Reader", timeout: 30) {
            app.state == .runningForeground
        }
        XCTAssertEqual(readerActivityTaps, 1)
        let close = app.buttons["关闭导入结果"]
        XCTAssertTrue(close.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["本地导入"].exists)
        XCTAssertGreaterThan(app.staticTexts.matching(NSPredicate(format: "label == %@", filename)).count, 0,
            "The actual import owner must identify the original filename; its header and item may both expose that same text")
        let duplicate = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "这本书已在书架中")).firstMatch
        XCTAssertTrue(duplicate.waitForExistence(timeout: 120),
            "Require the real existing-SHA duplicate result; pending/error/new import cannot pass")
        evidence(app, "external-TXT-actual-existing-SHA-duplicate-result")
        close.tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.textFields["shelf-filter"].exists, "Preserve any original shelf filter")
        XCTAssertTrue(app.buttons["全部分组"].exists, "Preserve the original group selection")
        let existingBook = app.buttons.matching(NSPredicate(format: "identifier == %@", bookID))
        XCTAssertEqual(existingBook.count, 1)
        XCTAssertTrue(existingBook.element.isHittable && existingBook.element.isEnabled)
        evidence(app, "external-TXT-duplicate-dismissed-original-bookshelf")
        let facts: [String: Any] = ["fileName":filename,"originalFilesCellLabel":originalCellLabel,
            "enteredActualLocalReaderFolder":enteredLocal && enteredReader,"shareActionTapped":shareTapped,
            "actualReaderActivityLabel":actualActivityLabel,"readerActivityTaps":readerActivityTaps,
            "actualShareCaption":actualShareCaption.map { $0 as Any } ?? NSNull(),
            "actualShareMetadata":actualShareMetadata.map { $0 as Any } ?? NSNull(),
            "duplicateResultObserved":true,"bookAXID":bookID,"normalReturnToShelfObserved":true,
            "AppLaunchesRequested":0,"URLInjectionsRequested":0,"fileWritesRequested":0,"bookOpensRequested":0,
            "boundary":"Root must bind actual Documents original8871723B/aac01d… and preserve all64tables/cache/heads/history/read_records/ledger/oldcommands/files/prefs plus complete .staging manifest. UI batch UUIDs are not Core ACKs; existing-SHA created:false returns before import.parse/persist. Only actual cold bootstrap and an exact new OS Inbox copy, if present, are separately reviewed. No reading session is opened."]
        let result = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts,
            options: [.sortedKeys,.prettyPrinted]), uniformTypeIdentifier: "public.json")
        result.name = "external-real-TXT-Files-Reader-duplicate-and-shelf-facts.json"
        result.lifetime = .keepAlways; add(result)
    }

    /// Existing untouched Downloads EPUB only; no import or generated book.
    /// Root binds fresh Large book/source/chapter20/scalar233/version facts and
    /// all old notes/drafts before selecting this single native method.
    func testExistingRealEpubNativeCopyAnnotationColdHighlightAndNoteJump() throws {
        realEpubJourney = true
        let app = XCUIApplication(); app.launch()
        func openExisting() {
            if app.buttons["书架"].waitForExistence(timeout: 10) { app.buttons["书架"].tap() }
            XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 20))
            XCTAssertFalse(app.textFields["shelf-filter"].exists, "Preserve any original shelf filter")
            XCTAssertTrue(app.buttons["全部分组"].exists, "Preserve any original shelf group choice")
            openBook(app)
            waitUntil("The actual original EPUB WK viewport is visible", timeout: 45) {
                self.body(app).isHittable && self.body(app).frame.width > 180 && self.body(app).frame.height > 120
                    && !app.buttons["阅读控制"].exists
            }
            XCTAssertFalse(app.textViews["reading-body"].exists, "A TXT fallback cannot prove the EPUB consumer")
        }
        func readDisplay() throws -> (paper: String, mode: String, selectable: String) {
            openModule("appearance", app: app)
            let names = ["日间", "暖白", "夜间", "暖夜", "纸纹", "青叶纹", "靛夜", "林夜纹"] as NSArray
            let selected = app.buttons.matching(NSPredicate(format: "label IN %@", names))
                .allElementsBoundByIndex.filter(\.isSelected)
            XCTAssertEqual(selected.count, 1, "Observe the effective visible original paper, not absent raw preference keys")
            let paper = try XCTUnwrap(selected.first).label
            let mode = app.buttons["reading-page-mode"]
            reveal(mode, towardBottom: true, app: app)
            let value = try menuValue(mode, choices: ["滚动", "分页"])
            let selectable = app.switches["长按选择文本"]
            reveal(selectable, towardBottom: true, app: app)
            let allowsSelection = try XCTUnwrap(selectable.value as? String)
            XCTAssertEqual(allowsSelection, "1", "Preserve a disabled original choice; do not enable it for a test")
            hideControls(app)
            return (paper, value, allowsSelection)
        }
        openExisting()
        assertChapter(20, app: app) // Observe only; never reset/select a chapter.
        let originalDisplay = try readDisplay()
        // Exact frozen registry paperStart values. WK paints its solid original
        // paper; the screenshot below must independently agree with that value.
        let papers = ["日间":[247,243,234], "暖白":[242,232,211], "纸纹":[238,228,208], "青叶纹":[227,235,221],
                      "夜间":[43,40,35], "暖夜":[65,48,32], "靛夜":[38,49,63], "林夜纹":[36,56,44]]
        let expectedPaper = try XCTUnwrap(papers[originalDisplay.paper])
        let originalAnchor = try anchor(app, name: "epub-note-original-existing-chapter20-passage")
        let native = try unpaintedNativeEpubSelection(app)
        let selectionText = native.text
        XCTAssertEqual(app.staticTexts["annotation-selected-text"].label, selectionText)
        let note = textInput("annotation-note", app: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        guard isEmpty(note), app.buttons["save-annotation"].label == "高亮并保存笔记" else {
            XCTFail("Preserve an existing note draft/edit; this method owns no replacement")
            throw JourneyError.prerequisite
        }
        note.tap(); note.press(forDuration: 0.8)
        try menuAction(["粘贴", "Paste"], app: app).tap()
        waitUntil("System Copy/Paste equals the same original WK scalar selection", timeout: 5) {
            self.textInput("annotation-note", app: app).value as? String == selectionText
        }
        let actualPastedText = try XCTUnwrap(textInput("annotation-note", app: app).value as? String)
        XCTAssertEqual(actualPastedText, selectionText)
        let ownedNote = "EPUB原生选文-" + UUID().uuidString
        let noteText = actualPastedText + " · " + ownedNote
        textInput("annotation-note", app: app).typeText(" · " + ownedNote)
        XCTAssertEqual(textInput("annotation-note", app: app).value as? String, noteText)
        let query = app.textFields["搜索笔记"]
        XCTAssertTrue(query.isHittable); query.tap(); query.typeText("\n")
        waitUntil("The real note keyboard dismisses", timeout: 5) { !app.keyboards.firstMatch.exists }
        let context = try native.before.context(startingAt: selectionText, in: native.line, count: 20)
        let save = app.buttons["save-annotation"]
        reveal(save, towardBottom: false, app: app)
        XCTAssertTrue(save.isEnabled && save.isHittable); save.tap() // One original write only.
        replace(query, with: ownedNote)
        let rows = app.buttons.matching(NSPredicate(format:
            "identifier BEGINSWITH 'annotation-' AND label CONTAINS %@", ownedNote))
        waitUntil("Exactly one original Core note row confirms this UUID", timeout: 25) { rows.count == 1 }
        let annotationID = rows.firstMatch.identifier
        XCTAssertTrue(rows.firstMatch.label.contains(selectionText))
        let facts: [String: Any] = ["bookAXID":bookID,"sourceID":"local","chapterIndex":20,
            "annotationAXID":annotationID,"ownedNoteMarker":ownedNote,"noteText":noteText,
            "selectedText":selectionText,"actualPastedText":actualPastedText,"context":context,
            "originalPaper":originalDisplay.paper,"originalMode":originalDisplay.mode,
            "originalSelectable":originalDisplay.selectable,"selectedRange":NSNull(),
            "rangeBoundary":"Native UI does not expose scalar endpoints; Root must bind the original createHighlight ACK range/scope and exact bookText. No injected range or second save."]
        let ownership = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys, .prettyPrinted]),
            uniformTypeIdentifier: "public.json")
        ownership.name = "epub-owned-original-note-visible-identity.json"; ownership.lifetime = .keepAlways; add(ownership)
        evidence(app, "epub-system-copy-paste-and-original-note-row")

        // Normal exit from the notes panel. Cold process retirement clears the
        // live system selection without a guessed outside tap or injected DOM.
        leaveReader(app); app.terminate(); app.launch(); openExisting()
        try assertVisible(originalAnchor, app: app, name: "epub-note-cold-restored-original-passage")
        let cold = try screen(app)
        let coldLine = try XCTUnwrap(cold.lines.first { normalized($0.text) == normalized(native.line.text) })
        let painted = try cold.wordImage(selectionText, in: coldLine)
        try assertEpubAlphaHighlight(painted, baseline: native.crop, expectedPaper: expectedPaper, name: originalDisplay.paper)
        let crop = XCTAttachment(image: UIImage(cgImage: painted))
        crop.name = "epub-cold-WK-original-alpha-highlight-no-live-selection"; crop.lifetime = .keepAlways; add(crop)
        assertChapter(20, app: app)

        // Return from a genuinely different visible passage, using the original
        // page mode. No mode/transition/paper/selectable setting is written.
        if originalDisplay.mode == "分页" { try turn(app, awayFrom: context) }
        else {
            body(app).swipeUp()
            waitUntil("The original scroll mode leaves the note passage", timeout: 20) {
                guard let text = try? self.screen(app).text else { return false }
                return !self.normalized(text).contains(context)
            }
        }
        XCTAssertFalse(normalized(try screen(app).text).contains(context))
        openTool("高亮与笔记", app: app)
        replace(app.textFields["搜索笔记"], with: ownedNote)
        let restored = app.buttons[annotationID]
        XCTAssertTrue(restored.waitForExistence(timeout: 25))
        XCTAssertTrue(restored.label.contains(ownedNote) && restored.label.contains(selectionText))
        restored.tap(); hideControls(app)
        try assertVisible(context, app: app, name: "epub-persisted-note-jump-back-from-different-passage")
        assertChapter(20, app: app)
        let finalDisplay = try readDisplay()
        XCTAssertEqual(finalDisplay.paper, originalDisplay.paper)
        XCTAssertEqual(finalDisplay.mode, originalDisplay.mode)
        XCTAssertEqual(finalDisplay.selectable, originalDisplay.selectable)
        leaveReader(app)
        // Keep exactly this UUID-owned note/original ACK for Root's accounting.
        // No old note, rule, draft or reading preference is edited/deleted.
    }

    /// EPUB-only alpha evidence. Existing TXT >=36/.12 checks remain unchanged.
    private func assertEpubAlphaHighlight(_ image: CGImage, baseline: CGImage, expectedPaper: [Int], name: String) throws {
        let selection = [89,70,50], alpha = 0.2
        let composite = zip(selection, expectedPaper).map { Int((Double($0.0) * alpha + Double($0.1) * (1 - alpha)).rounded()) }
        func measure(_ image: CGImage) throws -> (modal: [Int], fraction: Double) {
            let pixels = try rgba(image); var bins: [Int: Int] = [:]; var matching = 0
            for offset in stride(from: 0, to: pixels.count, by: 4) {
                let rgb = [Int(pixels[offset]),Int(pixels[offset+1]),Int(pixels[offset+2])]
                let key = rgb[0] << 16 | rgb[1] << 8 | rgb[2]; bins[key, default: 0] += 1
                if zip(rgb, composite).allSatisfy({ abs($0.0 - $0.1) <= 2 }) { matching += 1 }
            }
            let modal = try XCTUnwrap(bins.max { $0.value < $1.value }?.key)
            return ([modal >> 16 & 255,modal >> 8 & 255,modal & 255], Double(matching) / Double(max(1,image.width * image.height)))
        }
        let before = try measure(baseline), after = try measure(image)
        for (actual, expected) in zip(before.modal, expectedPaper) {
            XCTAssertEqual(Double(actual), Double(expected), accuracy: 2, "The original unpainted WK word must expose the actual selected paper")
        }
        for (actual, expected) in zip(after.modal, composite) {
            XCTAssertEqual(Double(actual), Double(expected), accuracy: 2, "Cold WK highlight must retain the frozen 0.2 alpha, not opaque or twice-multiplied selection")
        }
        XCTAssertLessThan(before.fraction, 0.01, "The before image cannot already contain the target highlight")
        XCTAssertGreaterThan(after.fraction, 0.30, "A real highlight background must occupy the selected glyph ROI")
        XCTAssertGreaterThan(after.fraction - before.fraction, 0.12, "Glyph ink or a saved note row cannot prove painted background")
        let facts: [String: Any] = ["paperName":name,"expectedPaperRGB":expectedPaper,"selectionRGB":selection,
            "selectionAlpha":alpha,"expectedCompositeRGB":composite,"channelTolerance":2,
            "beforeModalRGB":before.modal,"coldModalRGB":after.modal,
            "beforeCompositeFraction":before.fraction,"coldCompositeFraction":after.fraction,
            "boundary":"Same uniquely mapped original OCR word before selection vs cold WK with no live selection. No threshold change to TXT; no paper or display write."]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys,.prettyPrinted]), uniformTypeIdentifier: "public.json")
        attachment.name = "epub-original-paper-alpha-pixel-measurement.json"; attachment.lifetime = .keepAlways; add(attachment)
    }

    /// Continue only the preserved native63 note-jump tail. Copy/Paste, save
    /// and cold alpha painting already passed and must never be replayed here.
    func testExistingOwnedEpubNoteJumpTailWithoutCopyOrAnnotationMutation() throws {
        realEpubJourney = true
        let ownedNote = "EPUB原生选文-7866D199-304A-41C5-8000-9748A1977313"
        let annotationID = "annotation-1"
        let originalContext = "到珠翠楼耍下次再有这种事派我去吧我林子旁"
        let app = XCUIApplication(); app.launch()
        if app.buttons["书架"].waitForExistence(timeout: 10) { app.buttons["书架"].tap() }
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.textFields["shelf-filter"].exists, "Preserve any original shelf filter")
        XCTAssertTrue(app.buttons["全部分组"].exists, "Preserve any original group selection")
        openBook(app)
        waitUntil("The original EPUB WK is visible", timeout: 45) {
            self.body(app).isHittable && self.body(app).frame.width > 180 && self.body(app).frame.height > 120
        }
        XCTAssertFalse(app.textViews["reading-body"].exists)
        assertChapter(20, app: app) // Observe; never select/reset a chapter.
        // Native65 already recorded the original cold context. Observe this
        // fresh session without seeking back to its historical scalar offset.
        func readOriginalDisplay() throws {
            openModule("appearance", app: app)
            let names = ["日间", "暖白", "夜间", "暖夜", "纸纹", "青叶纹", "靛夜", "林夜纹"] as NSArray
            let papers = app.buttons.matching(NSPredicate(format: "label IN %@", names))
                .allElementsBoundByIndex.filter(\.isSelected)
            XCTAssertEqual(papers.count, 1)
            XCTAssertEqual(try XCTUnwrap(papers.first).label, "日间", "Preserve native63's effective original paper")
            let mode = app.buttons["reading-page-mode"]
            reveal(mode, towardBottom: true, app: app)
            XCTAssertEqual(try menuValue(mode, choices: ["滚动", "分页"]), "分页")
            let select = app.switches["长按选择文本"]
            reveal(select, towardBottom: true, app: app)
            XCTAssertEqual(select.value as? String, "1")
            hideControls(app)
        }
        func findOriginalNote() throws -> XCUIElement {
            openTool("高亮与笔记", app: app)
            let note = textInput("annotation-note", app: app)
            XCTAssertTrue(note.waitForExistence(timeout: 5))
            XCTAssertTrue(isEmpty(note), "Preserve any existing note draft; do not replace/edit/save it")
            let query = app.textFields["搜索笔记"]
            XCTAssertTrue(query.waitForExistence(timeout: 5))
            let before = try XCTUnwrap(query.value as? String)
            let alreadyOwned = before == ownedNote
            guard alreadyOwned || isEmpty(query) else {
                evidence(app, "epub-original-owned-note-tail-unexpected-query-preserved")
                XCTFail("Preserve an unknown existing note query instead of replacing or deleting it")
                throw JourneyError.prerequisite
            }
            if !alreadyOwned {
                XCTAssertTrue(query.isHittable)
                query.tap()
                query.typeText(ownedNote + "\n") // One input into an observed empty field; no Delete.
            } else if app.keyboards.count > 0 {
                query.tap()
                query.typeText("\n") // Submit only; never rewrite the retained marker.
            }
            waitUntil("The original note query keyboard is dismissed", timeout: 5) { app.keyboards.count == 0 }
            let after = try XCTUnwrap(query.value as? String)
            let queryFacts: [String: Any] = ["before":before,"after":after,
                "reusedExactOwnedQuery":alreadyOwned,"markerInputsRequested":alreadyOwned ? 0 : 1,
                "deletesRequested":0,"lookupsRequested":1]
            let queryAttachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: queryFacts,
                options: [.sortedKeys,.prettyPrinted]), uniformTypeIdentifier: "public.json")
            queryAttachment.name = "epub-original-owned-note-tail-exact-query.json"
            queryAttachment.lifetime = .keepAlways; add(queryAttachment)
            guard after == ownedNote else {
                XCTFail("The actual full query must equal the original owned marker after normal input")
                throw JourneyError.prerequisite
            }
            let rows = app.buttons.matching(NSPredicate(format:
                "identifier == %@ AND label CONTAINS %@", annotationID, ownedNote))
            waitUntil("Read exactly the original existing note", timeout: 25) { rows.count == 1 }
            XCTAssertTrue(rows.firstMatch.label.contains("第19章 说客"))
            XCTAssertTrue(rows.firstMatch.label.contains("到"))
            return rows.firstMatch
        }
        try readOriginalDisplay()
        waitUntil("Actual chapter 20 prose before the read-only tail", timeout: 25) {
            guard let capture = try? self.screen(app) else { return false }
            return self.normalized(capture.text).count >= 18
        }
        let entry = try screen(app)
        let entryAtOriginalContext = normalized(entry.text).contains(originalContext)
        let entryText = XCTAttachment(string: entry.lines.map(\.text).joined(separator: "\n")
            + "\nENTRY_AT_ORIGINAL_CONTEXT=\(entryAtOriginalContext)")
        entryText.name = "epub-original-owned-note-tail-fresh-entry-OCR"
        entryText.lifetime = .keepAlways; add(entryText)
        evidence(app, "epub-original-owned-note-tail-fresh-entry")
        if entryAtOriginalContext { try turn(app, awayFrom: originalContext) }
        waitUntil("Actual readable away passage before the only note lookup", timeout: 25) {
            guard let capture = try? self.screen(app) else { return false }
            let text = self.normalized(capture.text)
            return text.count >= 18 && !text.contains(originalContext)
        }
        let away = try screen(app)
        XCTAssertGreaterThanOrEqual(normalized(away.text).count, 18)
        XCTAssertFalse(normalized(away.text).contains(originalContext))
        let awayText = XCTAttachment(string: away.lines.map(\.text).joined(separator: "\n"))
        awayText.name = "epub-original-owned-note-tail-actual-away-OCR"
        awayText.lifetime = .keepAlways; add(awayText)
        evidence(app, "epub-original-owned-note-tail-actual-away-passage")
        let original = try findOriginalNote()
        let binding: [String: Any] = ["originalRun":"large-epub-annotation-native63-1",
            "bookAXID":bookID,"sourceID":"local","chapterIndex":20,"originalRange":[236,237],
            "annotationAXID":annotationID,"ownedNoteMarker":ownedNote,"selectedText":"到",
            "originalCreateOperationID":"afab99b5-07e5-4dc8-8607-8f54ad32f5b1",
            "context":originalContext,"annotationWritesRequested":0,"copyPasteRequested":false,
            "boundary":"Root must bind fresh preflight to the exact original completed ACK/one SQL mark. Only this original row is tapped once; no save/update/delete, synthesized selection or second note."]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: binding, options: [.sortedKeys,.prettyPrinted]), uniformTypeIdentifier: "public.json")
        attachment.name = "epub-original-owned-note-readonly-jump-tail-binding.json"; attachment.lifetime = .keepAlways; add(attachment)
        original.tap(); hideControls(app)
        try assertVisible(originalContext, app: app, name: "epub-original-owned-note-tail-returned-visible-context")
        assertChapter(20, app: app)
        try readOriginalDisplay()
        leaveReader(app)
    }

    /// A new Large-owned rule intent. This does not resume or replace the
    /// Compact rejected draft. Root's final fresh clone gate is required first.
    func testRealTXTNewSavedRuleExplicitReprocessDisableReprocessAndDeleteRestoresVisibleOriginal() throws {
        let proof = try realRuleRoundtripProof()
        let app = XCUIApplication()
        var requestedStage = "none"
        var normalExit = false
        defer {
            if !normalExit {
                let retained = XCTAttachment(string: "lastRequestedStage=\(requestedStage)\nStop here. Preserve the original action UUID, frozen parameters, Host command/reprocess journal, owned rule and draft. No automatic cleanup, re-dispatch or replacement UUID is authorized. UI rows alone never establish the original ACK.\n" + app.debugDescription)
                retained.name = "real-rule-roundtrip-failure-preserve-original-intent"
                retained.lifetime = .keepAlways; add(retained)
                evidence(app, "real-rule-roundtrip-failed-current-interface")
            }
        }
        app.launch()
        try openExistingRuleRoundtripBook(app)
        try recordRuleRoundtripHeader(app, stage: "initial", expectedChapter: proof.chapterIndex)
        hideControls(app)
        try captureRuleRoundtripPaper(app, present: proof.pattern, absent: proof.replacement,
                                      stage: "original-before-any-draft-edit")
        openTool("替换、字典与目录规则", app: app)
        let picker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '规则类型'"))
        guard picker.count == 1, picker.element.isHittable else { throw JourneyError.prerequisite }
        picker.element.tap()
        let kind = app.buttons["替换"]
        guard kind.waitForExistence(timeout: 5), kind.isHittable else { throw JourneyError.prerequisite }
        kind.tap()
        waitUntil("Actual saved-rule reads finish before inspecting the clean draft", timeout: 30) {
            !app.staticTexts["正在读取规则"].exists
        }
        try requireEmptyRuleRoundtripDraft(app)
        guard app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'replace-rule-' ")).count == 0 else {
            XCTFail("Root's fresh clean-scope prerequisite changed; preserve all saved rules")
            throw JourneyError.prerequisite
        }
        let ownedName = "真实原文规则-" + UUID().uuidString.lowercased()
        let input = XCTAttachment(string: "intent=new-owned-rule-not-replay\nownedName=\(ownedName)\npattern=\(proof.pattern)\nreplacement=\(proof.replacement)\nincludeScope=\(proof.includeScope)\nexcludeScope=\(proof.excludeScope)\nplain=true\nscopeContent=true\nscopeTitle=false\nscopeSource=false\nenabled=true\nproofSHA256=\(ProcessInfo.processInfo.environment["READER_RULE_SLICE_PROOF_SHA256"] ?? "")\nThis name is not a Core operation UUID. Every original action is resolved separately from the actual retained journal.")
        input.name = "real-rule-roundtrip-owned-input-before-save"
        input.lifetime = .keepAlways; add(input)
        try fill("规则名称", ownedName, towardBottom: false, app: app)
        try fill("匹配内容", proof.pattern, app: app)
        try fill("替换为", proof.replacement, app: app)
        try fill("作用范围，留空为全部", proof.includeScope, app: app)
        setToggle("正则表达式", value: "0", app: app)
        setToggle("作用于正文", value: "1", app: app)
        setToggle("作用于标题", value: "0", app: app)
        setToggle("作用于书源", value: "0", app: app)
        setToggle("启用此规则", value: "1", app: app)
        guard isEmpty(textInput("排除范围", app: app)), isEmpty(textInput("规则分组", app: app)) else {
            throw JourneyError.prerequisite
        }
        let save = app.buttons["保存规则"]
        reveal(save, towardBottom: true, app: app)
        guard save.isHittable, save.isEnabled else { throw JourneyError.prerequisite }
        requestedStage = "create"
        recordRuleRoundtripIntent("create", name: ownedName, ruleID: nil, app: app)
        save.tap() // Exactly one new save; no retry or alternative literal.
        let owned = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'replace-rule-' AND label == %@", ownedName))
        waitUntil("The actual owned saved rule is projected only after the original owner ends", timeout: 30) {
            owned.count == 1 && app.buttons["保存规则"].isEnabled && app.staticTexts["编辑替换规则"].exists
        }
        guard owned.count == 1, app.buttons["保存规则"].isEnabled else {
            XCTFail("Save is rejected, unknown or not projected. Preserve its original intent")
            throw JourneyError.missingOwnedRule
        }
        let ruleID = String(owned.element.identifier.dropFirst("replace-rule-".count))
        guard Int64(ruleID) != nil else { throw JourneyError.missingOwnedRule }
        recordRuleRoundtripIntent("create-ui-projection-await-external-original-ack-audit", name: ownedName, ruleID: ruleID, app: app)
        requestedStage = "enabled-reprocess"
        try explicitRuleRoundtripReprocess(app, stage: requestedStage, name: ownedName, ruleID: ruleID)
        // Save is not body adoption. The existing explicit reprocess must finish
        // and the new actual reader must consume the changed text first.
        try captureRuleRoundtripPaper(app, present: proof.replacement, absent: proof.pattern, stage: "enabled-reprocessed-body")
        try recordRuleRoundtripHeader(app, stage: "enabled-adopted")
        hideControls(app)
        openTool("替换、字典与目录规则", app: app)
        let enabled = app.switches.matching(NSPredicate(format: "identifier == %@", "enable-replace-rule-" + ruleID))
        guard enabled.count == 1 else { throw JourneyError.missingOwnedRule }
        reveal(enabled.element, towardBottom: false, app: app)
        guard enabled.element.value as? String == "1", enabled.element.label.contains(ownedName) else {
            throw JourneyError.prerequisite
        }
        requestedStage = "disable"
        recordRuleRoundtripIntent(requestedStage, name: ownedName, ruleID: ruleID, app: app)
        setSwitch(enabled.element, to: "0") // Existing one-touch native switch driver.
        waitUntil("The original disable owner ends with the same saved rule disabled", timeout: 30) {
            enabled.count == 1 && enabled.element.value as? String == "0" && app.buttons["保存规则"].isEnabled
        }
        guard enabled.element.value as? String == "0", app.buttons["保存规则"].isEnabled else {
            throw JourneyError.prerequisite
        }
        requestedStage = "disabled-reprocess"
        try explicitRuleRoundtripReprocess(app, stage: requestedStage, name: ownedName, ruleID: ruleID)
        try captureRuleRoundtripPaper(app, present: proof.pattern, absent: proof.replacement, stage: "disabled-reprocessed-original-body")
        try recordRuleRoundtripHeader(app, stage: "disabled-adopted")
        hideControls(app)
        openTool("替换、字典与目录规则", app: app)
        let disabled = app.switches.matching(NSPredicate(format: "identifier == %@", "enable-replace-rule-" + ruleID))
        guard disabled.count == 1 else { throw JourneyError.missingOwnedRule }
        reveal(disabled.element, towardBottom: false, app: app)
        guard disabled.element.value as? String == "0", disabled.element.label.contains(ownedName), app.buttons["保存规则"].isEnabled else {
            throw JourneyError.prerequisite
        }
        requestedStage = "delete"
        recordRuleRoundtripIntent(requestedStage, name: ownedName, ruleID: ruleID, app: app)
        removeOwnedRule(ruleID, name: ownedName, app: app) // Exact ID + named native confirmation, once.
        waitUntil("The original delete owner ends, with only the same owned rule removed", timeout: 30) {
            !app.buttons.matching(NSPredicate(format: "identifier == %@", "replace-rule-" + ruleID)).firstMatch.exists && app.buttons["保存规则"].isEnabled
        }
        guard !app.buttons.matching(NSPredicate(format: "identifier == %@", "replace-rule-" + ruleID)).firstMatch.exists,
              app.buttons["保存规则"].isEnabled else { throw JourneyError.prerequisite }
        // Only the exact completed/deleted owned draft can now be reset through
        // the existing normal confirmation. An unknown write never reaches here.
        let nameField = textInput("规则名称", app: app)
        reveal(nameField, towardBottom: false, app: app)
        guard nameField.value as? String == ownedName,
              textInput("匹配内容", app: app).value as? String == proof.pattern,
              textInput("替换为", app: app).value as? String == proof.replacement,
              textInput("作用范围，留空为全部", app: app).value as? String == proof.includeScope,
              isEmpty(textInput("排除范围", app: app)), isEmpty(textInput("规则分组", app: app)) else {
            XCTFail("Do not clear a draft whose exact owned input changed")
            throw JourneyError.prerequisite
        }
        let create = app.buttons["新建"]; reveal(create, towardBottom: false, app: app)
        guard create.isEnabled, create.isHittable else { throw JourneyError.prerequisite }
        create.tap()
        let discard = app.alerts["替换当前草稿？"]
        guard discard.waitForExistence(timeout: 5), discard.buttons["替换"].isHittable else { throw JourneyError.prerequisite }
        discard.buttons["替换"].tap()
        try requireEmptyRuleRoundtripDraft(app)
        requestedStage = "all-five-original-intents-ui-complete-external-ack-audit-required"
        hideControls(app)
        try captureRuleRoundtripPaper(app, present: proof.pattern, absent: proof.replacement, stage: "deleted-original-body")
        leaveReader(app)
        app.terminate(); app.launch()
        try openExistingRuleRoundtripBook(app)
        try recordRuleRoundtripHeader(app, stage: "cold-restored")
        hideControls(app)
        try captureRuleRoundtripPaper(app, present: proof.pattern, absent: proof.replacement, stage: "cold-original-body")
        leaveReader(app)
        XCUIDevice.shared.press(.home); app.terminate()
        normalExit = true
        // Core may migrate complete protected positions. Root verifies each
        // original mutation/reprocess ACK and all resulting position/version
        // facts, not pixel equality, guessed scalar mapping or one wholeDB hash.
    }

    /// Reads the existing four Core-backed records. The sole destructive
    /// confirmation is cancelled; no record is removed or constructed.
    func testExistingRealReadingRecordsShowFourBooksAndCancelClearPreservesOriginalRows() throws {
        let app = XCUIApplication()
        var normalExit = false
        defer {
            if !normalExit {
                let retained = XCTAttachment(string: app.debugDescription)
                retained.name = "reading-records-failure-preserve-original-state"
                retained.lifetime = .keepAlways; add(retained)
                evidence(app, "reading-records-failure-current-interface")
            }
        }
        guard bookID == "book-local:aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5" else {
            XCTFail("This independent method requires its default real TXT identity, not another journey's mode")
            throw JourneyError.prerequisite
        }
        app.launch()
        try openExistingRuleRoundtripBook(app)
        openTool("阅读记录", app: app)
        let total = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^累计阅读 [0-9]+ 分钟$"))
        waitUntil("Actual Core-backed reading summary is visible", timeout: 20) { total.count == 1 }
        let before = try readingRecordsUISnapshot(app, stage: "before-cancel")
        guard before.clearForTXT.isEnabled, before.clearForTXT.isHittable else {
            XCTFail("Only the actual Clear button paired with the existing TXT record may open the confirmation")
            throw JourneyError.prerequisite
        }
        before.clearForTXT.tap()
        let alert = app.alerts["清除阅读记录"]
        guard alert.waitForExistence(timeout: 5), app.alerts.count == 1,
              alert.staticTexts.matching(NSPredicate(format: "label == %@", "清除《仙子请听我解释》的阅读时长，书籍和位置保留。")).count == 1,
              alert.buttons["清除"].exists, alert.buttons["清除"].isEnabled,
              alert.buttons["取消"].exists, alert.buttons["取消"].isEnabled, alert.buttons["取消"].isHittable else {
            XCTFail("Require the confirmation for the exact observed TXT record; never tap a destructive action")
            throw JourneyError.prerequisite
        }
        evidence(app, "reading-records-exact-clear-confirmation-before-cancel")
        alert.buttons["取消"].tap()
        waitUntil("Cancel dismisses only the reading-record confirmation", timeout: 5) { !alert.exists }
        let after = try readingRecordsUISnapshot(app, stage: "after-cancel")
        XCTAssertEqual(after.minutesByName, before.minutesByName,
            "Cancel must preserve all four observed record values in the same loaded summary")
        XCTAssertEqual(after.totalMinutes, before.totalMinutes,
            "Cancel must preserve the actual loaded aggregate, independently of time accrued before this panel loaded")
        leaveReader(app)
        evidence(app, "reading-records-normal-bookshelf-exit")
        normalExit = true
        // The delivery account separately checks all original records and every
        // original time ACK and progress coordinates. Ordinary progress has no Host journal; a fresh read is not ACK.
    }

    private struct ReadingRecordsUISnapshot {
        let minutesByName: [String: Int]
        let totalMinutes: Int
        let clearForTXT: XCUIElement
    }
    private func readingRecordsUISnapshot(_ app: XCUIApplication, stage: String) throws -> ReadingRecordsUISnapshot {
        let names = ["仙子请听我解释", "终宋_怪诞的表哥_牧云斋_z_library_sk,_1lib_sk,_z_lib_sk",
                     "覆汉_校对版全本_榴弹怕水_z_library_sk,_1lib_sk,_z_lib_sk", "剑来"]
        for failure in ["正在读取记录", "暂无阅读记录", "阅读时长尚未入账", "阅读记录刷新失败，保留原列表", "原操作待核对"] {
            guard !app.staticTexts.matching(NSPredicate(format: "label == %@", failure)).allElementsBoundByIndex.contains(where: { $0.isHittable }) else {
                XCTFail("The original record state must be settled before this read-only consumer: \(failure)")
                throw JourneyError.prerequisite
            }
        }
        let totalQuery = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^累计阅读 [0-9]+ 分钟$"))
        guard totalQuery.count == 1, totalQuery.element.isHittable else { throw JourneyError.prerequisite }
        let totalLabel = totalQuery.element.label
        guard let totalMinutes = Int(totalLabel.replacingOccurrences(of: "累计阅读 ", with: "").replacingOccurrences(of: " 分钟", with: "")), totalMinutes > 0 else {
            throw JourneyError.prerequisite
        }
        let candidates = app.scrollViews.allElementsBoundByIndex.filter {
            $0.frame.width > 0 && $0.frame.height > 0 &&
            $0.staticTexts.matching(NSPredicate(format: "label == %@", totalLabel)).count == 1
        }.sorted { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        guard let viewport = candidates.first,
              candidates.count == 1 || candidates[1].frame.width * candidates[1].frame.height > viewport.frame.width * viewport.frame.height else {
            XCTFail("Require one smallest real ScrollView containing the loaded reading-record summary")
            throw JourneyError.prerequisite
        }
        let titles = try names.map { name -> XCUIElement in
            let query = viewport.staticTexts.matching(NSPredicate(format: "label == %@", name))
            guard query.count == 1, query.element.isHittable,
                  query.element.frame.minY >= viewport.frame.minY - 1,
                  query.element.frame.maxY <= viewport.frame.maxY + 1 else {
                XCTFail("All four original record titles must be uniquely visible in their real viewport: \(name)")
                throw JourneyError.prerequisite
            }
            return query.element
        }.sorted { $0.frame.minY < $1.frame.minY }
        let minutes = viewport.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+ 分钟$")).allElementsBoundByIndex
        let clear = viewport.buttons.matching(NSPredicate(format: "label == %@", "清除")).allElementsBoundByIndex
        guard minutes.count == 4, clear.count == 4 else {
            XCTFail("Require exactly four actual minute labels and four real Clear controls, without selecting an arbitrary action")
            throw JourneyError.prerequisite
        }
        var values: [String: Int] = [:]
        var clearForTXT: XCUIElement?
        var rows: [[String: Any]] = []
        for (index, heading) in titles.enumerated() {
            let upper = index + 1 < titles.count ? titles[index + 1].frame.minY : viewport.frame.maxY
            let rowMinutes = minutes.filter { $0.frame.midY >= heading.frame.maxY - 1 && $0.frame.midY < upper }
            let rowClear = clear.filter { $0.frame.midY >= heading.frame.minY && $0.frame.midY < upper }
            guard rowMinutes.count == 1, rowClear.count == 1,
                  rowMinutes[0].isHittable, rowClear[0].isHittable,
                  rowMinutes[0].frame.maxY <= viewport.frame.maxY + 1,
                  let value = Int(rowMinutes[0].label.replacingOccurrences(of: " 分钟", with: "")), value > 0 else {
                XCTFail("Pair the actual title, minutes and Clear only within the same visible row band")
                throw JourneyError.prerequisite
            }
            values[heading.label] = value
            if heading.label == title { clearForTXT = rowClear[0] }
            rows.append(["bookName": heading.label, "minutesLabel": rowMinutes[0].label,
                         "titleFrame": NSCoder.string(for: heading.frame), "minutesFrame": NSCoder.string(for: rowMinutes[0].frame),
                         "clearFrame": NSCoder.string(for: rowClear[0].frame)])
        }
        guard values.count == 4, let clearForTXT else { throw JourneyError.prerequisite }
        let sum = values.values.reduce(0, +)
        XCTAssertGreaterThanOrEqual(totalMinutes, sum,
            "Core floors the total after summing milliseconds, separately from each book's displayed floor")
        XCTAssertLessThanOrEqual(totalMinutes, sum + names.count - 1,
            "Four per-book minute floors can differ from the real aggregate by at most three minutes")
        let facts: [String: Any] = ["stage": stage, "totalLabel": totalLabel, "minutesByName": values,
                                  "viewportFrame": NSCoder.string(for: viewport.frame), "rows": rows]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "reading-records-\(stage)-actual-ui-values"
        attachment.lifetime = .keepAlways; add(attachment)
        evidence(app, "reading-records-\(stage)-actual-four-rows")
        return ReadingRecordsUISnapshot(minutesByName: values, totalMinutes: totalMinutes, clearForTXT: clearForTXT)
    }

    private func openExistingRuleRoundtripBook(_ app: XCUIApplication) throws {
        guard app.buttons["更多书架操作"].waitForExistence(timeout: 20) else { throw JourneyError.prerequisite }
        let book = app.buttons.matching(NSPredicate(format: "identifier == %@", bookID))
        guard book.count == 1, book.element.isEnabled, book.element.isHittable else {
            XCTFail("The existing exact book must already be visible; do not change filters, import, seek or reset to construct the premise")
            throw JourneyError.prerequisite
        }
        book.element.tap()
        guard body(app).waitForExistence(timeout: 30) else { throw JourneyError.prerequisite }
    }
    private func requireEmptyRuleRoundtripDraft(_ app: XCUIApplication) throws {
        for semantic in ["规则名称", "匹配内容", "替换为", "规则分组", "排除范围", "作用范围，留空为全部"] {
            let field = textInput(semantic, app: app); reveal(field, towardBottom: true, app: app)
            guard field.exists, isEmpty(field) else {
                XCTFail("An existing nonempty draft is preserved; no save, new-draft replacement or replay is authorized")
                throw JourneyError.prerequisite
            }
        }
        let first = textInput("规则名称", app: app); reveal(first, towardBottom: false, app: app)
        guard app.staticTexts["新替换规则"].exists, !app.staticTexts["编辑替换规则"].exists,
              textInput("执行顺序", app: app).value as? String == "0",
              (textInput("匹配超时（毫秒）", app: app).value as? String)?.replacingOccurrences(of: ",", with: "") == "3000" else {
            throw JourneyError.prerequisite
        }
        for (name, value) in [("正则表达式", "1"), ("作用于正文", "1"), ("作用于标题", "0"), ("作用于书源", "0"), ("启用此规则", "1")] {
            let control = app.switches[name]; reveal(control, towardBottom: true, app: app)
            guard control.value as? String == value else { throw JourneyError.prerequisite }
        }
    }
    private func recordRuleRoundtripIntent(_ stage: String, name: String, ruleID: String?, app: XCUIApplication) {
        let value = XCTAttachment(string: "stage=\(stage)\nat=\(Date().timeIntervalSince1970)\nownedName=\(name)\nactualCoreRuleID=\(ruleID ?? "not-yet-returned")\nbookAX=\(bookID)\nExternal original ACK/journal audit is mandatory. This stage/name is not an operation UUID. No fresh list or enabled button proves an original write terminal.")
        value.name = "real-rule-roundtrip-intent-" + stage; value.lifetime = .keepAlways; add(value)
        evidence(app, "real-rule-roundtrip-" + stage)
    }
    private func explicitRuleRoundtripReprocess(_ app: XCUIApplication, stage: String, name: String, ruleID: String) throws {
        let action = app.buttons["按已保存规则重新处理本书"]
        reveal(action, towardBottom: false, app: app)
        guard action.isEnabled, action.isHittable else { throw JourneyError.prerequisite }
        recordRuleRoundtripIntent(stage, name: name, ruleID: ruleID, app: app)
        action.tap()
        let alert = app.alerts["按已保存规则重新处理？"]
        guard alert.waitForExistence(timeout: 5), alert.buttons["重新处理"].isHittable else { throw JourneyError.prerequisite }
        alert.buttons["重新处理"].tap() // One original action; no retry.
        waitUntil("Explicit reprocess must replace the old reader controls through its completed new-session adoption", timeout: 180) {
            self.body(app).exists && !app.buttons["control-grabber"].exists && !alert.exists
        }
        guard body(app).exists, !app.buttons["control-grabber"].exists, !alert.exists else {
            XCTFail("Reprocess did not complete; preserve the original UUID and journal")
            throw JourneyError.prerequisite
        }
    }
    private func recordRuleRoundtripHeader(_ app: XCUIApplication, stage: String, expectedChapter: UInt32? = nil) throws {
        // A fresh query after every successful reprocess; never reuse an old
        // session's XCUIElement, chapter index, body/version or footer assertion.
        openModule("home", app: app)
        let header = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "reading-book:local|" + String(bookID.dropFirst("book-".count))))
        let chapter = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'reading-chapter:'"))
        guard header.count == 1, header.element.label == title, chapter.count == 1,
              let actualIndex = UInt32(chapter.element.identifier.dropFirst("reading-chapter:".count)) else {
            throw JourneyError.prerequisite
        }
        if let expectedChapter { guard actualIndex == expectedChapter else { throw JourneyError.prerequisite } }
        let value = XCTAttachment(string: "stage=\(stage)\nbookAX=\(header.element.identifier)\nchapterAX=\(chapter.element.identifier)\nchapterLabel=\(chapter.element.label)\nActual public identity only; Root binds the resulting Core progress/body/processing scope and original terminal separately.")
        value.name = "real-rule-roundtrip-actual-session-" + stage; value.lifetime = .keepAlways; add(value)
        evidence(app, "real-rule-roundtrip-actual-session-" + stage)
    }
    private func captureRuleRoundtripPaper(_ app: XCUIApplication, present: String, absent: String, stage: String) throws {
        var accepted: Screen?
        var observedFooter: String?
        waitUntil("The actual current paper consumes the exact original/changed literal: " + stage, timeout: 30) {
            let paper = app.textViews.matching(NSPredicate(format: "identifier == 'reading-body'"))
            let footer = app.staticTexts.matching(NSPredicate(format: "identifier == 'reading-progress'"))
            guard paper.count == 1, paper.element.isHittable, footer.count == 1 else { return false }
            let before = footer.element.label
            guard let capture = try? self.screen(app), footer.element.label == before else { return false }
            let text = self.normalized(capture.text)
            guard text.contains(self.normalized(present)), !text.contains(self.normalized(absent)) else { return false }
            accepted = capture; observedFooter = before
            return true
        }
        let capture = try XCTUnwrap(accepted)
        let text = normalized(capture.text)
        XCTAssertTrue(text.contains(normalized(present))); XCTAssertFalse(text.contains(normalized(absent)))
        let image = XCTAttachment(image: UIImage(cgImage: capture.image))
        image.name = "real-rule-roundtrip-paper-" + stage; image.lifetime = .keepAlways; add(image)
        let lines = XCTAttachment(string: "stage=\(stage)\nactualStableFooter=\(observedFooter ?? "missing")\n" + capture.lines.map(\.text).joined(separator: "\n"))
        lines.name = "real-rule-roundtrip-OCR-" + stage; lines.lifetime = .keepAlways; add(lines)
    }
    private struct RealRuleRoundtripProof: Decodable {
        let version: Int; let purpose: String; let targetUDID: String
        let bookId: String; let chapterIndex: UInt32; let retainedOriginalSHA256: String
        let hostLibraryIdentitySHA256: String; let draftSHA256: String
        let editingReplaceID: Int64?; let cleanReplacementDraftConfirmed: Bool
        let pattern: String; let replacement: String; let includeScope: String; let excludeScope: String
        let isRegex: Bool; let enabled: Bool
        let scopeContent: Bool; let scopeTitle: Bool; let scopeSource: Bool
        let allScopeOccurrencesAudited: Bool; let allAffectedProtectedBodiesAudited: Bool
        let matchedBookIdentities: [String]
        let eligibilityAuditSHA256: String; let coreCloneAuditSHA256: String
        let visibleCaptureOCRSHA256: String; let visibleCaptureImageSHA256: String
        let rootFinalSaveAdmissionConfirmed: Bool
    }
    private func realRuleRoundtripProof() throws -> RealRuleRoundtripProof {
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["READER_RULE_SLICE_PROOF_JSON"], raw.utf8.count <= 32 * 1024,
              let expected = env["READER_RULE_SLICE_PROOF_SHA256"],
              expected.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil,
              ruleRoundtripSHA(Data(raw.utf8)) == expected else {
            XCTFail("Root must first review the fresh full-scope clone and protected-position gate, then bind the exact approved new intent in the Runner only")
            throw JourneyError.prerequisite
        }
        let proof = try JSONDecoder().decode(RealRuleRoundtripProof.self, from: Data(raw.utf8))
        guard proof.version == 3, proof.purpose == "root-reviewed-new-real-txt-rule-roundtrip",
              proof.targetUDID == "EEA74BB1-5DFA-479A-ACAA-460503AD0F6B",
              env["SIMULATOR_UDID"] == proof.targetUDID,
              env["READER_TOOLS_PRIOR_OWNED_DRAFT_NAME"] == nil,
              proof.bookId == String(bookID.dropFirst("book-".count)),
              proof.retainedOriginalSHA256 == "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5",
              proof.pattern == "斟酌用词", proof.replacement == "推敲用词",
              proof.pattern.unicodeScalars.count == 4, proof.replacement.unicodeScalars.count == 4,
              proof.includeScope == title, proof.excludeScope.isEmpty, !proof.isRegex, proof.enabled,
              proof.scopeContent, !proof.scopeTitle, !proof.scopeSource,
              proof.editingReplaceID == nil, proof.cleanReplacementDraftConfirmed,
              proof.allScopeOccurrencesAudited, proof.allAffectedProtectedBodiesAudited,
              proof.rootFinalSaveAdmissionConfirmed,
              proof.matchedBookIdentities == ["local|" + proof.bookId],
              [proof.hostLibraryIdentitySHA256, proof.draftSHA256, proof.eligibilityAuditSHA256,
               proof.coreCloneAuditSHA256, proof.visibleCaptureOCRSHA256, proof.visibleCaptureImageSHA256]
                .allSatisfy({ $0.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil }) else {
            throw JourneyError.prerequisite
        }
        let binding = XCTAttachment(string: raw + "\nPROOF_SHA256=" + expected)
        binding.name = "real-rule-roundtrip-root-final-admission-not-original-write-ack"
        binding.lifetime = .keepAlways; add(binding)
        return proof
    }
    private func ruleRoundtripSHA(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }


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

    /// Root admits the existing real TXT and stopped-library preproof separately.
    /// Cursor/retirement semantics reuse ReaderTextToolsLifecycleTests; this is
    /// only the native More consumer, without import, rule or display changes.
    func testExistingRealTXTContentSearchMoreAppendsActualResultsAndRetainsFirstHit() throws {
        let app = XCUIApplication()
        guard !realEpubJourney, app.state == .notRunning,
              bookID == "book-local:aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5" else {
            XCTFail("Require the existing exact original TXT and Root's stopped-App premise")
            throw JourneyError.prerequisite
        }
        var returnedNormally = false
        defer {
            if !returnedNormally {
                evidence(app, "real-TXT-More-failure-current-screen")
                let ax = XCTAttachment(string: app.debugDescription)
                ax.name = "real-TXT-More-failure-AX"; ax.lifetime = .keepAlways; add(ax)
            }
        }
        app.launch(); try openExistingRuleRoundtripBook(app)
        openModule("home", app: app)
        let chapter = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'reading-chapter:'"))
        XCTAssertEqual(chapter.count, 1)
        let originalChapterID = chapter.element.identifier
        hideControls(app)
        let originalAnchor = try anchor(app, name: "real-TXT-More-original-visible-anchor")
        openTool("正文搜索", app: app)
        let query = app.textFields["content-search-query"]
        replace(query, with: "2") // One native Return/onSubmit; never tap the Search/Stop button again.
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@",
            "content-hit-local|" + String(bookID.dropFirst(5)) + "|")
        let hits = app.buttons.matching(predicate)
        waitUntil("The one real initial search returns actual source-bound hits", timeout: 45) {
            hits.count > 0 && app.buttons["content-search-submit"].label == "搜索" && !app.keyboards.firstMatch.exists
        }
        guard query.value as? String == "2", hits.count > 0, !app.keyboards.firstMatch.exists else { throw JourneyError.prerequisite }
        let firstID = hits.element(boundBy: 0).identifier, firstLabel = hits.element(boundBy: 0).label
        let candidates = app.scrollViews.allElementsBoundByIndex.enumerated().filter {
            $0.element.buttons.matching(identifier: firstID).count == 1 && $0.element.frame.width > 100 && $0.element.frame.height > 100
        }.sorted { $0.element.frame.width * $0.element.frame.height < $1.element.frame.width * $1.element.frame.height }
        guard let selected = candidates.first,
              candidates.count == 1 || candidates[1].element.frame.width * candidates[1].element.frame.height > selected.element.frame.width * selected.element.frame.height else {
            throw JourneyError.prerequisite
        }
        let ownerIndex = selected.offset, ownerFrame = selected.element.frame
        func owner() throws -> XCUIElement {
            let current = app.scrollViews.element(boundBy: ownerIndex)
            guard current.exists, current.frame == ownerFrame, current.isHittable,
                  !app.keyboards.firstMatch.exists, app.buttons["control-grabber"].label.hasPrefix("完整控制栏"),
                  [ownerFrame.minX, ownerFrame.minY, ownerFrame.maxX, ownerFrame.maxY].allSatisfy(\.isFinite) else { throw JourneyError.prerequisite }
            return current // Unfiltered index, never a query containing the now-lazy first row.
        }
        func record(_ stage: String) throws -> [String] {
            let rows = try owner().buttons.matching(predicate).allElementsBoundByIndex
            let ax = XCTAttachment(string: app.debugDescription)
            ax.name = "real-TXT-More-" + stage + "-AX"; ax.lifetime = .keepAlways; add(ax)
            evidence(app, "real-TXT-More-" + stage)
            return rows.map(\.identifier) // Observed AX rows only; no claim that LazyVStack exposed every page ID.
        }
        func reach(_ target: XCUIElement, downward: Bool, deadline: TimeInterval, fast: Bool = true) throws {
            for step in 0...32 {
                guard ProcessInfo.processInfo.systemUptime < deadline else { break }
                let scroll = try owner(), viewport = ownerFrame.intersection(app.frame).insetBy(dx: 8, dy: 8)
                if target.exists, target.isHittable, viewport.contains(target.frame), ProcessInfo.processInfo.systemUptime < deadline { return }
                guard step < 32, viewport.height > 100, ProcessInfo.processInfo.systemUptime < deadline else { break }
                if downward { scroll.swipeUp(velocity: fast ? .fast : .slow) } else { scroll.swipeDown(velocity: .fast) }
            }
            XCTFail("The actual result-list target was not reached within 30 seconds / 32 native scrolls; no late tap")
            throw JourneyError.prerequisite
        }
        let initialIDs = try record("initial-results")
        let more = try owner().buttons.matching(NSPredicate(format: "label == %@", "更多结果"))
        let moreDeadline = ProcessInfo.processInfo.systemUptime + 30
        try reach(more.firstMatch, downward: true, deadline: moreDeadline)
        let scroll = try owner(), before = scroll.buttons.matching(predicate).allElementsBoundByIndex
        let oldTail = try XCTUnwrap(before.last)
        let oldTailID = oldTail.identifier
        guard more.count == 1, more.element.isEnabled, oldTail.isHittable, ownerFrame.intersection(app.frame).contains(oldTail.frame),
              oldTail.frame.maxY <= more.element.frame.minY else { throw JourneyError.prerequisite }
        let beforeIDs = try record("before-one-More")
        guard ProcessInfo.processInfo.systemUptime < moreDeadline else { throw JourneyError.prerequisite }
        more.element.tap() // Exactly one real More, only while its original reach deadline still holds.
        waitUntil("More exposes an actual new row after the prior page's retained tail", timeout: 30) {
            let ids = app.scrollViews.element(boundBy: ownerIndex).buttons.matching(predicate).allElementsBoundByIndex.map(\.identifier)
            guard app.buttons["content-search-submit"].label == "搜索", let tail = ids.firstIndex(of: oldTailID) else { return false }
            return ids.dropFirst(tail + 1).contains { !beforeIDs.contains($0) && !initialIDs.contains($0) }
        }
        let appendedIDs = try record("after-one-More")
        let tailIndex = try XCTUnwrap(appendedIDs.firstIndex(of: oldTailID))
        let newID = try XCTUnwrap(appendedIDs.dropFirst(tailIndex + 1).first { !beforeIDs.contains($0) && !initialIDs.contains($0) })
        let appended = try owner().buttons.matching(identifier: newID)
        try reach(appended.element, downward: true, deadline: ProcessInfo.processInfo.systemUptime + 30, fast: false)
        _ = try record("actual-appended-row-visible")
        let first = try owner().buttons.matching(identifier: firstID)
        try reach(first.element, downward: false, deadline: ProcessInfo.processInfo.systemUptime + 30)
        XCTAssertEqual(first.count, 1); XCTAssertEqual(first.element.label, firstLabel)
        _ = try record("original-first-hit-retained")
        let facts = XCTAttachment(string: "firstHitID=\(firstID)\noldTailID=\(oldTailID)\nobservedAppendedID=\(newID)\nMoreTaps=1\nObserved AX order/visible rows only; cursor bytes, exact page counts and all-page unique IDs are NOT_CAPTURED. Root separately audits original inputs, progress, retained files and commands.")
        facts.name = "real-TXT-More-observed-identity-boundary"; facts.lifetime = .keepAlways; add(facts)
        hideControls(app)
        try assertVisible(originalAnchor, app: app, name: "real-TXT-More-reader-anchor-preserved")
        openModule("home", app: app); XCTAssertEqual(chapter.element.identifier, originalChapterID)
        leaveReader(app); returnedNormally = true
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

    /// WK Copy preserves the original native selection after dismissing its
    /// menu. One public blank-paper tap must visibly clear that selection before
    /// one new long press at the same original point. No business retry or DOM
    /// injection; the existing TXT helper below remains byte-for-byte unchanged.
    private func unpaintedNativeEpubSelection(_ app: XCUIApplication) throws -> UnpaintedNativeSelection {
        let before = try screen(app)
        let prose = try XCTUnwrap(before.lines.dropFirst().first { $0.text.count >= 14 },
            "The existing EPUB must expose actual long prose; do not navigate or generate input")
        let baseline = XCTAttachment(image: UIImage(cgImage: before.image))
        baseline.name = "epub-WK-exact-original-preselection-baseline"; baseline.lifetime = .keepAlways; add(baseline)
        let point = before.point(in: prose.box, xFraction: 0.27)
        let region = CGRect(x: before.pixelCrop.minX + prose.box.minX * before.pixelCrop.width,
            y: before.pixelCrop.minY + (1 - prose.box.maxY) * before.pixelCrop.height,
            width: prose.box.width * before.pixelCrop.width, height: prose.box.height * before.pixelCrop.height).integral
        let original = try XCTUnwrap(before.image.cropping(to: region))
        let originalPixels = try rgba(original)
        func selectionDifference(_ image: CGImage) throws -> Double {
            XCTAssertEqual(image.width, before.image.width); XCTAssertEqual(image.height, before.image.height)
            let crop = try XCTUnwrap(image.cropping(to: region)), pixels = try rgba(crop)
            guard pixels.count == originalPixels.count else { throw JourneyError.prerequisite }
            var changed = 0
            for offset in stride(from: 0, to: pixels.count, by: 4) {
                let distance = (0..<3).reduce(0) { $0 + abs(Int(pixels[offset+$1]) - Int(originalPixels[offset+$1])) }
                if distance >= 12 { changed += 1 }
            }
            return Double(changed) / Double(max(1, crop.width * crop.height))
        }
        func noNativeMenu() -> Bool {
            !app.menuItems.allElementsBoundByIndex.contains(where: \.isHittable)
        }
        coordinate(point, app: app).press(forDuration: 0.8)
        let copy = try menuAction(["拷贝", "复制", "Copy"], app: app)
        // Prove the original selection's Reader actions exist before Copy. This
        // is the same first native menu observed in the preserved failed run.
        let noteMenu = app.menuItems["高亮与笔记"]
        XCTAssertTrue(noteMenu.exists && noteMenu.isHittable, "The first actual WK menu must retain the original note action")
        evidence(app, "epub-WK-first-native-menu-before-system-copy")
        copy.tap()
        waitUntil("System Copy dismisses its native menu", timeout: 5) { noNativeMenu() }
        let copied = try screen(app), copiedDifference = try selectionDifference(copied.image)
        evidence(app, "epub-WK-copy-menu-dismissed-original-selection-observation")
        var clearPoint: CGPoint?
        if copiedDifference > 0.005 {
            // Find actual OCR paragraph whitespace in the middle third, then
            // independently require its screenshot to be blank paper. No edge
            // tap may accidentally turn a page, and no word/handle is retapped.
            let paper = try backgroundColour(before.paperMarginImage(near: prose))
            let rows = before.lines.map { line in
                CGRect(x: before.viewport.minX + line.box.minX * before.viewport.width,
                    y: before.viewport.minY + (1 - line.box.maxY) * before.viewport.height,
                    width: line.box.width * before.viewport.width, height: line.box.height * before.viewport.height)
            }.sorted { $0.minY < $1.minY }
            for pair in zip(rows, rows.dropFirst()) where pair.1.minY - pair.0.maxY >= 10 {
                let proposed = CGPoint(x: before.viewport.midX, y: (pair.0.maxY + pair.1.minY) / 2)
                let blank = CGRect(x: before.pixelCrop.minX + (proposed.x - before.viewport.minX - 3) * before.pixelCrop.width / before.viewport.width,
                    y: before.pixelCrop.minY + (proposed.y - before.viewport.minY - 2) * before.pixelCrop.height / before.viewport.height,
                    width: 6 * before.pixelCrop.width / before.viewport.width,
                    height: 4 * before.pixelCrop.height / before.viewport.height).integral
                if let sample = before.image.cropping(to: blank), try backgroundColour(sample) == paper {
                    clearPoint = proposed; break
                }
            }
            let blankPoint = try XCTUnwrap(clearPoint, "One real blank middle-third paper point is required; preserve the original selection if absent")
            coordinate(blankPoint, app: app).tap() // Exactly one selection-clear touch.
            if app.buttons["control-grabber"].isHittable { hideControls(app) }
        }
        waitUntil("The same original WK line has no native selection or menu", timeout: 5) {
            guard noNativeMenu(), !app.buttons["control-grabber"].isHittable,
                  let image = app.screenshot().image.cgImage,
                  let difference = try? selectionDifference(image) else { return false }
            return difference <= 0.005
        }
        let cleared = try screen(app), clearedDifference = try selectionDifference(cleared.image)
        XCTAssertEqual(normalized(cleared.text), normalized(before.text),
            "Clearing native selection cannot navigate, reflow or replace the original viewport")
        XCTAssertLessThanOrEqual(clearedDifference, 0.005)
        let clearFacts: [String: Any] = ["copyMenuExited":noNativeMenu(),"beforeCopyPoint":[point.x,point.y],
            "copyLinePixelDifference":copiedDifference,"clearedLinePixelDifference":clearedDifference,
            "clearTouchCount":clearPoint == nil ? 0 : 1,
            "clearTouchPoint":clearPoint.map { [$0.x,$0.y] } as Any? ?? NSNull(),
            "secondSelectionTouchCount":1,"boundary":"Native public touches only; no range/selection injection, no save retry, original full viewport OCR unchanged. Pixel return confirms native selection cleared before reselecting the same original point."]
        let receipt = XCTAttachment(data: try JSONSerialization.data(withJSONObject: clearFacts, options: [.sortedKeys,.prettyPrinted]), uniformTypeIdentifier: "public.json")
        receipt.name = "epub-WK-copy-clear-selection-before-one-reselection.json"; receipt.lifetime = .keepAlways; add(receipt)
        evidence(app, "epub-WK-original-selection-cleared-before-one-reselection")
        coordinate(point, app: app).press(forDuration: 0.8) // One new actual selection only.
        try menuAction(["高亮与笔记"], app: app).tap()
        let selected = app.staticTexts["annotation-selected-text"]
        XCTAssertTrue(selected.waitForExistence(timeout: 10))
        let text = selected.label, note = textInput("annotation-note", app: app)
        guard !text.isEmpty, text.count <= 80, prose.text.components(separatedBy: text).count == 2,
              note.waitForExistence(timeout: 5), isEmpty(note), app.buttons["save-annotation"].label == "高亮并保存笔记" else {
            XCTFail("Require one uniquely mapped original word and empty new note draft; preserve every existing note/edit")
            throw JourneyError.prerequisite
        }
        let crop = try before.wordImage(text, in: prose)
        let paper = try backgroundColour(before.paperMarginImage(near: prose)), background = try backgroundColour(crop)
        XCTAssertEqual(background, paper, "The original word must be unpainted before any note write")
        for part in 0..<min(4,crop.width) {
            let count = min(4,crop.width), left = part * crop.width / count, right = (part+1) * crop.width / count
            let image = try XCTUnwrap(crop.cropping(to: CGRect(x: CGFloat(left),y: 0,width: CGFloat(right-left),height: CGFloat(crop.height))))
            XCTAssertEqual(try backgroundColour(image), paper, "No pre-existing partial highlight may be used as the baseline")
        }
        let word = XCTAttachment(image: UIImage(cgImage: crop))
        word.name = "epub-WK-original-word-before-first-selection"; word.lifetime = .keepAlways; add(word)
        return UnpaintedNativeSelection(before: before, line: prose, text: text, crop: crop, background: background)
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
    private func body(_ app: XCUIApplication) -> XCUIElement {
        if realEpubJourney {
            return app.descendants(matching: .any).matching(identifier: "reading-ebook-body").firstMatch
        }
        return app.textViews["reading-body"]
    }
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
