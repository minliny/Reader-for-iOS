import XCTest
import UIKit
import Vision

/// The App exports its actual Core bundle. Only normal Files controls create
/// the owned file and read it back; this Runner never reads or writes JSON.
/// The delivery owner additionally binds the original Host/Core receipt and
/// compares the exported bytes and business snapshots outside the UITest.
final class ReaderRuleBundleJourneyTests: XCTestCase {
    private enum JourneyError: Error { case prerequisite(String) }
    private let originalID = "local:aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5"
    private let importMessage = "合并规则包；同 ID 的规则或订阅、同名字典将由文件内容覆盖，其他现有项保留。"
    private struct Directory: Equatable { let count: String; let chapterID: String; let title: String }

    override func setUpWithError() throws { continueAfterFailure = false }

    func testActualCoreRuleBundleNativeExportAndSameFileMergeImportPreservesOriginalReading() throws {
        let app = XCUIApplication(); app.launch()
        try openOriginal(app)
        try controls(app)
        let chapterBefore = try chapterID(app)
        try hide(app)
        let progressBefore = try progress(app), anchorBefore = try anchor(app)
        let directoryBefore = try directory(app, chapterID: chapterBefore)
        try openRules(app)
        try wait("Read the actual current rules before opening a system file sheet", timeout: 30) {
            !app.staticTexts["正在读取规则"].exists
        }
        try require(!app.staticTexts["规则工具尚未完成"].exists, "Preserve a failed or unavailable rule workspace")
        let kind = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '规则类型'")).element
        try require(kind.waitForExistence(timeout: 5), "Use the real existing rule workspace without selecting or replacing a draft")
        let kindBefore = kind.label, draftBefore = draftValues(app)
        let fileBase = "Reader-Rule-RoundTrip-" + UUID().uuidString.lowercased()
        facts("ownedBaseName=\(fileBase)\nownedFilename=\(fileBase).json\nbookId=\(originalID)\nchapterId=\(chapterBefore)\nruleKind=\(kindBefore)\nApp launch environment not modified; exported JSON is never generated or read by the Runner",
              name: "rule-roundtrip-owned-system-file-and-original-context")

        let export = app.buttons["导出规则"]
        try require(export.isHittable && export.isEnabled, "Export the actual Core bundle through the existing App entry")
        export.tap()
        let names = app.textFields.matching(NSPredicate(format: "value == %@ OR value == %@", "Reader规则", "Reader规则.json"))
        // Core export is asynchronous. Do not inspect Files locations while
        // the underlying App rules panel is still the visible surface.
        let nativeFileActions = app.navigationBars.buttons.matching(NSPredicate(format: "label IN %@",
            ["取消", "Cancel", "导出", "Export", "存储", "保存", "Save", "移动", "Move"]))
        let nativeSaveUI = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.navigationBars.firstMatch.exists &&
                (names.allElementsBoundByAccessibilityElement.filter(\.isHittable).count == 1 ||
                 nativeFileActions.allElementsBoundByIndex.contains(where: \.isHittable))
        }, object: nil)
        if XCTWaiter.wait(for: [nativeSaveUI], timeout: 30) != .completed {
            evidence(app, "rule-roundtrip-native-export-not-presented")
            try require(false, "Wait for the actual system save UI before navigating Files; no generated file or export redispatch")
        }
        try enterReaderDocuments(app)
        try wait("The native save sheet must expose the actual exported filename for editing", timeout: 15) {
            names.allElementsBoundByAccessibilityElement.filter(\.isHittable).count == 1
        }
        // Keep this actual UIKit element when its value changes; a query still
        // matching the old filename cannot resolve the renamed field.
        let name = try XCTUnwrap(names.allElementsBoundByAccessibilityElement.first(where: \.isHittable))
        try replaceNativeFilename(name, with: fileBase, app: app)
        let saveLabels = ["导出", "存储", "保存", "移动", "Export", "Save", "Move"]
        let saves = app.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", saveLabels))
        let save = try XCTUnwrap(saves.allElementsBoundByIndex.filter { $0.isHittable && $0.isEnabled }.only,
            "Use one actual native save/export button; never substitute a background file write")
        try require((name.value as? String) == fileBase || (name.value as? String) == fileBase + ".json",
                    "Verify the new UUID-owned filename before the one actual save action")
        evidence(app, "rule-roundtrip-actual-native-owned-filename-before-save")
        save.tap()
        try wait("The normal native save sheet must return to the same rules workspace", timeout: 30) {
            (!name.exists && app.buttons["导入规则"].isHittable) || app.alerts.firstMatch.exists
        }
        try require(!app.alerts.firstMatch.exists, "Never replace an existing file or accept an unexpected native save confirmation")
        try require(app.buttons["导入规则"].isHittable, "Return from actual Files saving before importing")
        evidence(app, "rule-roundtrip-returned-from-native-export")

        app.buttons["导入规则"].tap()
        try enterReaderDocuments(app)
        let files = app.cells.containing(NSPredicate(format: "label == %@ OR label == %@", fileBase, fileBase + ".json"))
        try require(files.firstMatch.waitForExistence(timeout: 15) && files.count == 1 && files.element.isHittable,
                    "Select the one actual file just exported by the App; no provisioned or generated replacement")
        evidence(app, "rule-roundtrip-actual-same-exported-file-in-system-picker")
        files.element.tap()
        let open = app.navigationBars.buttons.matching(NSPredicate(format: "label == '打开' OR label == 'Open'"))
        if let button = open.allElementsBoundByIndex.filter({ $0.isHittable && $0.isEnabled }).only { button.tap() }
        let confirmation = app.alerts["导入规则"]
        try require(confirmation.waitForExistence(timeout: 20), "Reading the actual chosen file must reach the existing public confirmation")
        try require(confirmation.staticTexts[importMessage].exists, "Confirm the real merge/identity-overwrite contract, not collection replacement")
        evidence(app, "rule-roundtrip-original-file-merge-confirmation")
        confirmation.buttons["导入"].tap() // The only mutation dispatch in this journey.
        try wait("The same original operation must leave pending before proceeding; never redispatch an unknown import", timeout: 120) {
            !confirmation.exists && app.buttons["导入规则"].isHittable && app.buttons["导入规则"].isEnabled
        }
        try require(!app.staticTexts["原操作待核对"].exists, "Pending is not a completed import")
        try wait("Refresh only after the original operation returns", timeout: 30) { !app.staticTexts["正在读取规则"].exists }
        try require(!app.staticTexts["规则工具尚未完成"].exists, "Keep a real projection failure as a failure")
        XCTAssertEqual(kind.label, kindBefore)
        XCTAssertEqual(draftValues(app), draftBefore, "File import must not edit, discard or replace any current editor draft")
        facts("ownedFilename=\(fileBase).json\nNative sheet returned without retry. This is not an ACK assertion.\nRequired outer proof: exactly one new rules.mutation.apply Host UUID whose mutation.method=rule-bundle.import, mutation.params.json equals this exported UTF-8 file and replaceExisting=false; original binding operationId/sequence, outcome=applied, completed=true, no rejection.\nThe delivery owner also compares original/export SHA and pre/post rules, books, positions and assets. A fresh list cannot confirm this original write.",
              name: "rule-roundtrip-original-ACK-and-data-audit-requirement")
        evidence(app, "rule-roundtrip-same-rules-workspace-after-original-import")

        try hide(app)
        try assertVisible(anchorBefore, app: app)
        XCTAssertEqual(try progress(app), progressBefore)
        XCTAssertEqual(try directory(app, chapterID: chapterBefore), directoryBefore)
        try controls(app); XCTAssertEqual(try chapterID(app), chapterBefore)
        app.buttons["leave-reader"].tap()
        try require(app.buttons["更多书架操作"].waitForExistence(timeout: 20), "Leave through the normal original reader")
        app.terminate(); app.launch(); try openOriginal(app)
        try assertVisible(anchorBefore, app: app)
        XCTAssertEqual(try progress(app), progressBefore)
        try controls(app); XCTAssertEqual(try chapterID(app), chapterBefore)
        XCTAssertEqual(try directory(app, chapterID: chapterBefore), directoryBefore)
        try controls(app); app.buttons["leave-reader"].tap()
        try require(app.buttons["更多书架操作"].waitForExistence(timeout: 20), "Finish with the real existing library")
        // Retain the one UUID-owned exported file as evidence. Never remove
        // rules, subscriptions, books, the exported bundle or any originals.
    }

    private func openOriginal(_ app: XCUIApplication) throws {
        try require(app.buttons["更多书架操作"].waitForExistence(timeout: 25), "The exact original must already be picker-imported")
        if app.textFields["shelf-filter"].exists { app.buttons["搜索本地书架"].tap() }
        let book = app.buttons.matching(NSPredicate(format: "identifier == %@", "book-" + originalID))
        try require(book.firstMatch.waitForExistence(timeout: 20) && book.count == 1 && book.element.isHittable,
                    "Use the existing exact real TXT shelf item without importing or replacing it")
        book.element.tap()
        try require(app.textViews["reading-body"].waitForExistence(timeout: 30), "Read the actual original native body")
    }
    private func controls(_ app: XCUIApplication) throws {
        if !app.buttons["reader-more"].isHittable {
            app.textViews["reading-body"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        }
        try wait("Actual reading controls", timeout: 10) { app.buttons["reader-more"].isHittable }
        let book = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "reading-book:local|" + originalID)).element
        try require(book.exists, "Keep the same real book identity")
    }
    private func hide(_ app: XCUIApplication) throws {
        if app.buttons["收起阅读控制"].isHittable { app.buttons["收起阅读控制"].tap() }
        try wait("Actual reader control dismissal", timeout: 10) { !app.buttons["control-grabber"].isHittable }
    }
    private func openRules(_ app: XCUIApplication) throws {
        try hide(app); try controls(app)
        app.buttons["control-module-settings"].tap(); try expand(app)
        let rules = app.buttons["替换、字典与目录规则"]
        try require(rules.waitForExistence(timeout: 5) && rules.isHittable, "Use the existing nested rule tools entry")
        rules.tap()
        try require(app.buttons["导出规则"].waitForExistence(timeout: 10), "The actual file actions must be available")
    }
    private func expand(_ app: XCUIApplication) throws {
        let cap = app.buttons["control-grabber"]
        if !cap.label.hasPrefix("完整控制栏") { cap.tap() }
        try wait("Actual full reader controls", timeout: 10) { cap.label.hasPrefix("完整控制栏") }
    }
    private func chapterID(_ app: XCUIApplication) throws -> String {
        let chapter = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'reading-chapter:'")).element
        try require(chapter.waitForExistence(timeout: 5), "Observe the actual canonical chapter identity")
        return chapter.identifier
    }
    private func progress(_ app: XCUIApplication) throws -> String {
        let progress = app.staticTexts["reading-progress"]
        try require(progress.waitForExistence(timeout: 5), "Read the actual original progress label")
        return progress.label
    }
    private func directory(_ app: XCUIApplication, chapterID original: String) throws -> Directory {
        try hide(app); try controls(app)
        app.buttons["control-module-home"].tap()
        let counts = app.staticTexts.matching(NSPredicate(format: "label MATCHES '共 [0-9]+ 章'"))
        try require(counts.firstMatch.waitForExistence(timeout: 5) && counts.count == 1 && counts.element.isHittable,
                    "Read the actual complete Core count in Reading Quick controls")
        let count = counts.element.label
        try require((Int(count.dropFirst("共 ".count).prefix(while: \.isNumber)) ?? 0) > 0, "An actual nonempty catalog is required")
        app.buttons["control-module-directory"].tap(); try expand(app)
        let tab = app.buttons.matching(NSPredicate(format: "label == '目录' AND identifier != 'control-module-directory'")).element
        try require(tab.waitForExistence(timeout: 5), "Read the existing original directory"); tab.tap()
        let query = app.textFields["directory-query"]
        try require(query.waitForExistence(timeout: 10) && value(query).isEmpty, "Preserve an existing nonempty directory filter")
        let index = String(original.dropFirst("reading-chapter:".count))
        try require(UInt32(index) != nil, "Keep the observed canonical chapter index")
        let row = app.buttons.matching(NSPredicate(format: "identifier == %@", "chapter-" + index)).element
        let locate = app.buttons["locate-current-chapter"]
        try require(locate.exists && locate.isHittable, "Locate the current chapter without selecting another chapter"); locate.tap()
        try wait("The actual current directory row remains selected", timeout: 20) { row.exists && row.isSelected && row.isHittable }
        let result = Directory(count: count, chapterID: row.identifier, title: row.label)
        evidence(app, "rule-roundtrip-actual-original-directory")
        try hide(app); return result
    }

    private func enterReaderDocuments(_ app: XCUIApplication) throws {
        // Navigate only actual native Files locations. A missing filename or
        // location fails; there is no shell path, injected file or URL route.
        let localNames = ["我的 iPhone", "我的iPhone", "我的 iPad", "我的iPad", "On My iPhone", "On My iPad"]
        var visited = Set<String>()
        for _ in 0..<6 {
            if readerDocumentsVisible(app) { return }
            let reader = app.cells.matching(NSPredicate(format: "identifier == 'Reader, Container' OR label BEGINSWITH 'Reader,'"))
            if let cell = reader.allElementsBoundByIndex.filter(\.isHittable).only {
                cell.tap()
                let arrival = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    self.readerDocumentsVisible(app)
                }, object: nil)
                let arrived = XCTWaiter.wait(for: [arrival], timeout: 10) == .completed
                if !arrived {
                    evidence(app, "rule-roundtrip-native-reader-folder-not-recognized")
                }
                try require(arrived, "Enter the actual Reader Documents folder")
                evidence(app, "rule-roundtrip-actual-native-reader-folder")
                return
            }
            let local = app.cells.containing(NSPredicate(format: "label IN %@", localNames))
                .allElementsBoundByIndex.filter(\.isHittable)
            if let cell = local.only, visited.insert("local:" + cell.label).inserted { cell.tap(); continue }
            let browse = app.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", ["浏览", "Browse"])).allElementsBoundByIndex
                + app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["浏览", "Browse"])).allElementsBoundByIndex
            if let button = browse.filter(\.isHittable).first, visited.insert("browse:" + button.identifier + button.label).inserted {
                button.tap(); continue
            }
            let backToLocal = app.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", localNames))
                .allElementsBoundByIndex.filter(\.isHittable)
            if let button = backToLocal.only, visited.insert("back:" + button.label).inserted { button.tap(); continue }
            break
        }
        evidence(app, "rule-roundtrip-native-Files-location-not-available")
        try require(false, "The normal Files sheet must expose the actual local Reader folder; do not write or provision a file behind the UI")
    }
    private func readerDocumentsVisible(_ app: XCUIApplication) -> Bool {
        if app.navigationBars.matching(NSPredicate(format: "identifier == 'Reader' OR label == 'Reader'")).firstMatch.exists { return true }
        // The actual iOS 26 save sheet shows its current folder as the
        // navigation bar's Reader menu button, rather than naming the bar.
        // Accept only that visible exact title within the native bar.
        for bar in app.navigationBars.allElementsBoundByIndex {
            let titleRegion = bar.frame.insetBy(dx: bar.frame.width * 0.25, dy: -2)
            let buttons = bar.buttons.matching(NSPredicate(format: "label IN %@ AND identifier != 'BackButton'", ["Reader", "Reader, 操作菜单"]))
                .allElementsBoundByIndex.filter {
                    $0.isHittable && titleRegion.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY))
                }
            if buttons.count == 1 { return true }
            let titles = bar.staticTexts.matching(NSPredicate(format: "label == 'Reader'"))
                .allElementsBoundByIndex.filter {
                    $0.isHittable && titleRegion.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY))
                }
            if titles.count == 1 { return true }
        }
        return false
    }
    private func replaceNativeFilename(_ field: XCUIElement, with filename: String, app: XCUIApplication) throws {
        try require(field.isHittable && field.isEnabled, "The native exported filename must be editable")
        field.tap(); field.press(forDuration: 0.8)
        var selectAll: XCUIElement?
        for _ in 0..<3 {
            let all = app.menuItems.matching(NSPredicate(format: "label == '全选' OR label == 'Select All'")).allElementsBoundByIndex
                + app.buttons.matching(NSPredicate(format: "label == '全选' OR label == 'Select All'")).allElementsBoundByIndex
            if let button = all.filter(\.isHittable).first { selectAll = button; break }
            let more = app.buttons.matching(NSPredicate(format: "label IN %@", ["前进", "显示更多项目", "Show more items", "More"]))
                .allElementsBoundByIndex.filter(\.isHittable)
            guard let button = more.only else { break }; button.tap()
        }
        let selectedAll = try XCTUnwrap(selectAll,
            "Use the native Select All control; do not assume caret placement in a system filename")
        selectedAll.tap(); field.typeText(filename)
        try require((field.value as? String) == filename || (field.value as? String) == filename + ".json",
                    "The actual system filename must contain only the new UUID-owned name")
    }
    private func draftValues(_ app: XCUIApplication) -> [String: String] {
        var result: [String: String] = [:]
        for type in [XCUIElement.ElementType.textField, .textView] {
            for field in app.descendants(matching: type).allElementsBoundByIndex where field.isHittable && field.identifier != "reading-body" {
                let key = "\(type.rawValue)|\(field.identifier)|\(field.label)|\(field.placeholderValue ?? "")"
                result[key] = value(field)
            }
        }
        return result
    }
    private func value(_ field: XCUIElement) -> String {
        let value = field.value as? String ?? ""; return value == field.placeholderValue ? "" : value
    }
    private func anchor(_ app: XCUIApplication) throws -> String {
        var lines: [String] = []
        try wait("Observe a real original-body paragraph anchor", timeout: 30) {
            guard let actual = try? self.ocr(app), actual.count >= 4 else { return false }; lines = actual; return true
        }
        let result = String(normalize(lines.dropFirst().prefix(2).joined()).prefix(24))
        try require(result.count >= 18, "The existing actual passage must expose enough original text")
        facts(lines.joined(separator: "\n") + "\nANCHOR=" + result, name: "rule-roundtrip-original-viewport-OCR")
        return result
    }
    private func assertVisible(_ anchor: String, app: XCUIApplication) throws {
        try wait("The same original passage remains visible", timeout: 30) {
            guard let actual = try? self.ocr(app) else { return false }; return self.normalize(actual.joined()).contains(anchor)
        }
        evidence(app, "rule-roundtrip-preserved-original-visible-body")
    }
    private func normalize(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }
    private func ocr(_ app: XCUIApplication) throws -> [String] {
        let image = try XCTUnwrap(app.screenshot().image.cgImage), window = app.frame
        let viewport = app.textViews["reading-body"].frame.intersection(window).insetBy(dx: 6, dy: 6)
        let rect = CGRect(x: (viewport.minX - window.minX) * CGFloat(image.width) / window.width,
            y: (viewport.minY - window.minY) * CGFloat(image.height) / window.height,
            width: viewport.width * CGFloat(image.width) / window.width, height: viewport.height * CGFloat(image.height) / window.height).integral
        let crop = try XCTUnwrap(image.cropping(to: rect))
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]; request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: crop).perform([request])
        return (request.results ?? []).sorted {
            abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.01 ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
        }.compactMap { $0.topCandidates(1).first?.string }
    }
    private func wait(_ fact: String, timeout: TimeInterval, _ condition: @escaping () -> Bool) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        try require(XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed, fact)
    }
    private func require(_ condition: Bool, _ fact: String, file: StaticString = #filePath, line: UInt = #line) throws {
        guard condition else { XCTFail(fact, file: file, line: line); throw JourneyError.prerequisite(fact) }
    }
    private func facts(_ text: String, name: String) {
        let attachment = XCTAttachment(string: text); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func evidence(_ app: XCUIApplication, _ name: String) {
        let snapshot = XCTAttachment(string: app.debugDescription); snapshot.name = name + "-actual-AX"; snapshot.lifetime = .keepAlways; add(snapshot)
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
}

private extension Array {
    var only: Element? { count == 1 ? first : nil }
}
