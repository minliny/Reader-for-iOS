import XCTest
import UIKit
import Vision

final class ReaderTXTTOCPreviewJourneyTests: XCTestCase {
    private enum JourneyError: Error { case prerequisite(String) }
    private let originalID = "local:aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5"
    private struct DirectorySample {
        let countLabel: String
        let titles: [String: String]
    }
    // Critical preconditions throw, so a Swift defer can restore only this
    // test's pattern through normal controls after a later failure.
    override func setUpWithError() throws { continueAfterFailure = true }

    func testExistingRealTXTDraftPreviewInvalidatesEditedResultAndPreservesReadingAndDirectory() throws {
        let app = XCUIApplication(); app.launch()
        try require(app.buttons["更多书架操作"].waitForExistence(timeout: 25), "Start from the real existing shelf")
        if app.textFields["shelf-filter"].exists { app.buttons["搜索本地书架"].tap() }
        let book = app.buttons.matching(NSPredicate(format: "identifier == %@", "book-" + originalID))
        try require(book.firstMatch.waitForExistence(timeout: 20) && book.count == 1 && book.firstMatch.isHittable,
                    "The existing byte-bound Downloads 仙子 book is required; no import or generated replacement")
        book.firstMatch.tap()
        try require(app.textViews["reading-body"].waitForExistence(timeout: 30), "Open its actual native body")
        try controls(app)
        try require(exact("reading-book:local|" + originalID, type: .staticText, app: app).exists, "Keep the exact original local source/book identity")
        let chapterBefore = try chapterID(app)
        try hide(app)
        let progressBefore = app.staticTexts["reading-progress"].label
        let anchorBefore = try anchor(app)
        let directoryBefore = try directorySample(app)
        let pattern = "^(?:" + directoryBefore.titles.keys.sorted().compactMap { directoryBefore.titles[$0] }
            .map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + ")$"

        try module("settings", app: app)
        let rules = app.buttons["替换、字典与目录规则"]
        try require(rules.waitForExistence(timeout: 5) && rules.isHittable, "Use the actual nested rule tools entry"); rules.tap()
        let kind = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '规则类型'")).firstMatch
        try reveal(kind, towardBottom: false, app: app); kind.tap()
        try require(app.buttons["TXT目录"].waitForExistence(timeout: 5), "Select the real TXT editor"); app.buttons["TXT目录"].tap()
        let name = input("规则名称", app: app), example = input("示例", app: app)
        let order = input("识别顺序", app: app), draft = input("txt-toc-draft-pattern", app: app)
        for field in [name, draft, example, order] { try reveal(field, towardBottom: true, app: app) }
        let beforeName = value(name), beforeExample = value(example), beforeOrder = value(order)
        try require(beforeName.isEmpty && value(draft).isEmpty && beforeExample.isEmpty && beforeOrder == "-1",
                    "An existing nonempty/edited TXT draft is preserved; never tap New, overwrite, discard or save it")
        let enabled = try draftEnable(after: order, app: app)
        let beforeEnabled = enabled.value as? String
        try require(beforeEnabled == "1", "A disabled draft is also retained rather than overwritten")
        var ownsPattern = true
        defer {
            if ownsPattern {
                do { try clearOwnedPattern(draft, allowed: [pattern, "("], app: app) }
                catch { XCTFail("The owned draft could not be restored through its actual control: \(error)") }
            }
        }
        try fill(draft, with: pattern, app: app)
        let preview = app.buttons["txt-toc-preview-draft"]
        try reveal(preview, towardBottom: true, app: app)
        try require(preview.isEnabled, "Preview must be available for this actual local TXT"); preview.tap()
        let validStatus = app.staticTexts.matching(NSPredicate(format: "identifier IN %@",
            ["txt-toc-preview-status:selected", "txt-toc-preview-status:shadowed"])).firstMatch
        try wait("The real Core must evaluate the genuine-title draft in its complete saved priority order", timeout: 120) { validStatus.exists }
        try reveal(validStatus, towardBottom: true, app: app)
        let actualCount = try previewCount(app)
        let rows = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'txt-toc-preview-chapter:'"))
        try require(rows.count == min(actualCount, 20), "Read the actual bounded Core title list, not an assumed 20 rows")
        try require(rows.allElementsBoundByIndex.allSatisfy { !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "Each returned actual preview title must be nonempty")
        evidence(app, "txt-real-genuine-title-draft-preview", text: "diagnosis=" + validStatus.identifier + "\ncount=" + String(actualCount) + "\ntitles=" + rows.allElementsBoundByIndex.map(\.label).joined(separator: "\n"))

        try fill(draft, with: "(", app: app)
        try wait("Editing must invalidate the previous diagnosis/count/titles before another preview is dispatched", timeout: 5) {
            !validStatus.exists && rows.count == 0 && self.countText(app).exists == false
        }
        try reveal(preview, towardBottom: true, app: app); try require(preview.isEnabled, "Do not save or reprocess to obtain a preview"); preview.tap()
        let invalid = app.staticTexts["txt-toc-preview-status:invalidRegex"]
        try wait("The actual Core must return the invalid-regex diagnosis", timeout: 120) { invalid.exists }
        try reveal(invalid, towardBottom: true, app: app)
        try require(!validStatus.exists, "An old valid/shadowed result cannot accompany the new invalid draft")
        let invalidCount = try previewCount(app)
        try require(rows.count == min(invalidCount, 20), "Any saved-rule/automatic fallback directory remains a bounded actual Core result")
        evidence(app, "txt-real-invalid-draft-preview", text: "diagnosis=" + invalid.identifier + "\ncount=" + String(invalidCount))

        try clearOwnedPattern(draft, allowed: [pattern, "("], app: app); ownsPattern = false
        try require(value(name) == beforeName && value(example) == beforeExample && value(order) == beforeOrder,
                    "Only the initially empty pattern may be edited and it must be restored")
        try require((try draftEnable(after: order, app: app)).value as? String == beforeEnabled, "Retain the original draft enable state")
        try wait("Restoring the original empty draft removes its invalid preview", timeout: 5) { !invalid.exists && rows.count == 0 }
        let directoryAfter = try directorySample(app, expected: directoryBefore.titles)
        XCTAssertEqual(directoryAfter.countLabel, directoryBefore.countLabel)
        XCTAssertEqual(directoryAfter.titles, directoryBefore.titles)
        try hide(app); try controls(app)
        XCTAssertEqual(try chapterID(app), chapterBefore)
        try hide(app)
        try wait("The original actual visible body must remain after the two read-only previews", timeout: 30) {
            guard let text = try? self.ocr(app) else { return false }; return self.normalize(text.joined()).contains(anchorBefore)
        }
        XCTAssertEqual(app.staticTexts["reading-progress"].label, progressBefore)
        evidence(app, "txt-preview-preserved-original-body-and-directory", text: "originalChapter=" + chapterBefore + "\ndirectory=" + directoryBefore.countLabel)
        try controls(app); app.buttons["leave-reader"].tap()
        try require(app.buttons["更多书架操作"].waitForExistence(timeout: 20), "Leave through the normal reader exit")
    }

    private func directorySample(_ app: XCUIApplication, expected: [String: String]? = nil) throws -> DirectorySample {
        // The actual total belongs to the Reading/home Quick module. Selecting
        // Directory replaces that content with the query and chapter rows.
        try module("home", expand: false, app: app)
        let counts = app.staticTexts.matching(NSPredicate(format: "label MATCHES '共 [0-9]+ 章'"))
        let count = counts.firstMatch
        try require(count.waitForExistence(timeout: 5), "Read the actual complete current catalog count in Quick controls")
        try require(counts.count == 1 && app.buttons["control-module-home"].isSelected && count.isHittable,
                    "Read the displayed count in the actual Reading Quick module, not a hidden directory or preview result")
        let countLabel = count.label
        let countDigits = countLabel.dropFirst("共 ".count).prefix(while: \.isNumber)
        try require((Int(countDigits) ?? 0) > 0, "The count must come from the actual nonempty Core catalog")
        evidence(app, expected == nil ? "txt-current-catalog-before-preview" : "txt-current-catalog-after-preview",
                 text: "actualQuickCatalog=" + countLabel)
        let directoryModule = app.buttons["control-module-directory"]
        try require(directoryModule.isHittable, "Open the actual directory after observing the Reading Quick count")
        directoryModule.tap()
        try expand(app)
        let directory = app.buttons.matching(NSPredicate(format: "label == '目录' AND identifier != 'control-module-directory'")).firstMatch
        try require(directory.waitForExistence(timeout: 5), "Read the existing canonical/proven directory"); directory.tap()
        let query = app.textFields["directory-query"]
        try require(query.waitForExistence(timeout: 10) && value(query).isEmpty, "Preserve an existing directory query rather than replace it")
        var titles: [String: String] = [:]
        if let expected {
            for id in expected.keys.sorted() {
                let row = exact(id, type: .button, app: app)
                try reveal(row, towardBottom: false, chapterIndex: UInt32(id.dropFirst("chapter-".count)), app: app)
                try require(row.isEnabled && row.label == expected[id], "The same actual catalog row must retain its title and navigation availability")
                titles[id] = row.label
            }
        } else {
            for _ in 0..<8 {
                let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chapter-'"))
                    .allElementsBoundByIndex.filter { $0.isHittable && $0.isEnabled }
                for row in rows {
                    if let index = UInt32(row.identifier.dropFirst("chapter-".count)), index > 0, !row.label.isEmpty { titles[row.identifier] = row.label }
                }
                if titles.count >= 4 { break }
                try scroll(towardBottom: false, app: app)
            }
            try require(titles.count >= 4, "At least four actual non-preface chapter titles are required; never fabricate headings")
            titles = Dictionary(uniqueKeysWithValues: titles.keys.sorted().prefix(4).compactMap { id in titles[id].map { (id, $0) } })
        }
        try hide(app)
        return DirectorySample(countLabel: countLabel, titles: titles)
    }
    private func draftEnable(after order: XCUIElement, app: XCUIApplication) throws -> XCUIElement {
        let save = app.buttons["保存规则"]
        try reveal(save, towardBottom: true, app: app)
        let candidates = app.switches.matching(NSPredicate(format: "label == '启用'")).allElementsBoundByIndex
            .filter { $0.isHittable && $0.frame.midY > order.frame.midY && $0.frame.midY < save.frame.midY }
        try require(candidates.count == 1, "Read the draft switch between its actual order and Save row, never an existing saved-rule switch")
        return try XCTUnwrap(candidates.first)
    }
    private func clearOwnedPattern(_ field: XCUIElement, allowed: [String], app: XCUIApplication) throws {
        try reveal(field, towardBottom: false, app: app)
        let actual = value(field)
        try require(actual.isEmpty || allowed.contains(actual) || allowed.contains(where: { $0.hasPrefix(actual) }),
                    "A different unowned draft appeared; preserve it rather than clear it")
        if !actual.isEmpty { try fill(field, with: "", app: app) }
        try require(value(field).isEmpty, "Restore the original empty draft through the real text control")
    }
    private func input(_ name: String, app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@ OR label == %@ OR placeholderValue == %@", name, name, name))
            .matching(NSPredicate(format: "elementType == %d OR elementType == %d", Int(XCUIElement.ElementType.textField.rawValue), Int(XCUIElement.ElementType.textView.rawValue))).element
    }
    private func value(_ field: XCUIElement) -> String {
        let result = field.value as? String ?? ""; return result == field.placeholderValue ? "" : result
    }
    private func fill(_ field: XCUIElement, with text: String, app: XCUIApplication) throws {
        try reveal(field, towardBottom: false, app: app)
        try require(field.isEnabled, "Use the actual editable draft control"); field.tap()
        let old = value(field)
        if !old.isEmpty {
            // Multi-line pattern taps can place the caret in the middle. Use
            // the native Select All action rather than assume caret-at-end.
            field.press(forDuration: 1.0)
            var selected = false
            for _ in 0..<3 {
                let predicate = NSPredicate(format: "label == '全选' OR label == 'Select All'")
                let choices = app.menuItems.matching(predicate).allElementsBoundByIndex + app.buttons.matching(predicate).allElementsBoundByIndex
                if let all = choices.first(where: \.isHittable) { all.tap(); selected = true; break }
                let more = app.buttons.matching(NSPredicate(format: "label == '前进' OR label == '显示更多项目' OR label == 'Show more items'")).firstMatch
                guard more.exists && more.isHittable else { break }; more.tap()
            }
            try require(selected, "Use the actual native Select All action before replacing only this owned pattern")
        }
        if text.isEmpty, !old.isEmpty { field.typeText(XCUIKeyboardKey.delete.rawValue) }
        else if !text.isEmpty { field.typeText(text) }
        try require(value(field) == text, "The exact pattern input must reach its real control without an appended newline")
        if app.keyboards.firstMatch.exists {
            let hide = app.buttons.matching(NSPredicate(format: "label == '隐藏键盘' OR label == 'Hide keyboard' OR label == 'Dismiss keyboard'")).firstMatch
            if hide.exists && hide.isHittable { hide.tap() }
            else { try scroll(towardBottom: true, app: app) }
            try wait("Dismiss the native keyboard by ordinary panel interaction", timeout: 5) { !app.keyboards.firstMatch.exists }
        }
    }
    private func countText(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '模拟目录共 '")).firstMatch
    }
    private func previewCount(_ app: XCUIApplication) throws -> Int {
        let text = countText(app)
        try require(text.waitForExistence(timeout: 5), "Read the actual Core simulation count")
        let digits = text.label.dropFirst("模拟目录共 ".count).prefix(while: \.isNumber)
        let result = try XCTUnwrap(Int(digits))
        try require(result > 0, "The genuine original must yield an actual simulated directory"); return result
    }
    private func exact(_ id: String, type: XCUIElement.ElementType, app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: type).matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }
    private func controls(_ app: XCUIApplication) throws {
        if !app.buttons["reader-more"].isHittable { app.textViews["reading-body"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap() }
        try wait("Normal native reading controls", timeout: 10) { app.buttons["reader-more"].isHittable }
    }
    private func hide(_ app: XCUIApplication) throws {
        let button = app.buttons["收起阅读控制"]
        if button.isHittable { button.tap() }
        try wait("Normal control dismissal", timeout: 10) { !app.buttons["control-grabber"].isHittable }
    }
    private func module(_ name: String, expand full: Bool = true, app: XCUIApplication) throws {
        try hide(app); try controls(app)
        let module = app.buttons["control-module-" + name]
        try require(module.waitForExistence(timeout: 5) && module.isHittable, "Open the existing reading module"); module.tap()
        if full { try expand(app) }
    }
    private func expand(_ app: XCUIApplication) throws {
        let grabber = app.buttons["control-grabber"]
        if !grabber.label.hasPrefix("完整控制栏") { grabber.tap() }
        try wait("Actual full reading controls", timeout: 10) { grabber.label.hasPrefix("完整控制栏") }
    }
    private func chapterID(_ app: XCUIApplication) throws -> String {
        let value = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'reading-chapter:'")).firstMatch
        try require(value.waitForExistence(timeout: 5), "Read the actual current canonical chapter identity"); return value.identifier
    }
    private func reveal(_ target: XCUIElement, towardBottom: Bool, chapterIndex: UInt32? = nil, app: XCUIApplication) throws {
        for _ in 0..<28 {
            if target.exists && target.isHittable { return }
            var down = towardBottom
            if let wanted = chapterIndex {
                let visible = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chapter-'"))
                    .allElementsBoundByIndex.filter(\.isHittable).compactMap { UInt32($0.identifier.dropFirst("chapter-".count)) }
                if let first = visible.min(), wanted < first { down = false }
                else if let last = visible.max(), wanted > last { down = true }
            }
            try scroll(towardBottom: down, app: app)
        }
        try require(false, "The actual control must be reachable through normal scrolling: " + target.debugDescription)
    }
    private func scroll(towardBottom: Bool, app: XCUIApplication) throws {
        if app.textFields["directory-query"].exists {
            let viewports = app.scrollViews.allElementsBoundByIndex.compactMap { view -> CGRect? in
                let frame = view.frame.intersection(app.frame)
                guard frame.width > 80, frame.height > 80 else { return nil }
                let rows = view.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chapter-'"))
                    .allElementsBoundByIndex
                guard rows.contains(where: { $0.isHittable && frame.intersects($0.frame) }) else { return nil }
                return frame
            }
            let viewport = try XCTUnwrap(viewports.min(by: { $0.height < $1.height }), "Use the actual directory ScrollView rather than its search/header controls")
            let inset = min(36, viewport.height * 0.15)
            let high = point(CGPoint(x: viewport.midX, y: viewport.minY + inset), app: app)
            let low = point(CGPoint(x: viewport.midX, y: viewport.maxY - inset), app: app)
            if towardBottom { low.press(forDuration: 0.05, thenDragTo: high) }
            else { high.press(forDuration: 0.05, thenDragTo: low) }
            return
        }
        let top = app.buttons["control-grabber"].frame.maxY + 70
        let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY - 25 : app.frame.maxY - 110
        let bottom = min(keyboardTop, top + 220)
        try require(bottom > top + 30, "The actual control panel must have a visible scroll viewport")
        let high = point(CGPoint(x: app.frame.midX, y: top), app: app), low = point(CGPoint(x: app.frame.midX, y: bottom), app: app)
        if towardBottom { low.press(forDuration: 0.05, thenDragTo: high) }
        else { high.press(forDuration: 0.05, thenDragTo: low) }
    }
    private func point(_ value: CGPoint, app: XCUIApplication) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: value.x - app.frame.minX, dy: value.y - app.frame.minY))
    }
    private func require(_ condition: Bool, _ fact: String, file: StaticString = #filePath, line: UInt = #line) throws {
        guard condition else { XCTFail(fact, file: file, line: line); throw JourneyError.prerequisite(fact) }
    }
    private func wait(_ fact: String, timeout: TimeInterval, _ condition: @escaping () -> Bool) throws {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        try require(XCTWaiter.wait(for: [expected], timeout: timeout) == .completed, fact)
    }
    private func anchor(_ app: XCUIApplication) throws -> String {
        var lines: [String] = []
        try wait("Read an actual visible original-body OCR anchor", timeout: 30) {
            guard let actual = try? self.ocr(app), actual.count >= 4 else { return false }; lines = actual; return true
        }
        let result = String(normalize(lines.dropFirst().prefix(2).joined()).prefix(24))
        try require(result.count >= 18, "The anchor must contain actual paragraph text"); return result
    }
    private func normalize(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }
    private func ocr(_ app: XCUIApplication) throws -> [String] {
        let source = try XCTUnwrap(app.screenshot().image.cgImage), window = app.frame
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
    private func evidence(_ app: XCUIApplication, _ name: String, text: String) {
        let values = XCTAttachment(string: text); values.name = name + "-actual-values"; values.lifetime = .keepAlways; add(values)
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
