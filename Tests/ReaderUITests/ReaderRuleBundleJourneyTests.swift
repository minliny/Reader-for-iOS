import XCTest
import UIKit
import Vision
import CryptoKit
import Darwin

/// The App exports its actual Core bundle. Only normal Files controls create
/// the owned bundle file and read it back. The Runner reads/writes only a
/// separate private checkpoint protocol, never bundle bytes or App state.
/// Automatic external predicates bind original Host/Core terminals and the
/// four complete collections; their summaries are not themselves Core ACKs.
final class ReaderRuleBundleJourneyTests: XCTestCase {
    private enum JourneyError: Error { case prerequisite(String) }
    private let originalID = "local:aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5"
    private let importMessage = "合并规则包；同 ID 的规则或订阅、同名字典将由文件内容覆盖，其他现有项保留。"
    private struct Directory: Equatable { let count: String; let chapterID: String; let title: String }

    override func setUpWithError() throws { continueAfterFailure = false }

    func testActualCoreRuleBundleNativeExportAndSameFileMergeImportPreservesOriginalReading() throws {
        let checkpoints = try NativeRuleFileCheckpoints()
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
        try require(kind.label.contains("替换"), "The actual selected kind must already be replacement; preserve every other existing intent without switching")
        let kindBefore = kind.label
        try ruleFileRequireEmptyDraft(app)
        try checkpoints.reach("before-create", ruleID: nil, selectedKindLabel: kind.label)
        let ownedName = checkpoints.proof.ownedRuleName
        let fileBase = checkpoints.proof.ownedFileBase
        try ruleFileFill("replacement-draft-name", ownedName, app: app)
        try ruleFileFill("replacement-draft-pattern", checkpoints.proof.pattern, app: app)
        try ruleFileFill("replacement-draft-replacement", checkpoints.proof.replacement, app: app)
        try ruleFileFill("replacement-draft-scope", checkpoints.proof.includeScope, app: app)
        for (label, wanted) in [("正则表达式", "0"), ("作用于正文", "1"), ("作用于标题", "0"),
                                ("作用于书源", "0"), ("启用此规则", "0")] {
            try ruleFileSetSwitch(app.switches[label], to: wanted, app: app)
        }
        try ruleFileRequireOwnedDraft(ownedName, app: app)
        let saveRule = app.buttons["保存规则"]
        try ruleFileReveal(saveRule, app: app)
        try require(saveRule.isHittable && saveRule.isEnabled, "Dispatch exactly one new disabled rule through the real form")
        saveRule.tap()
        let owned = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'replace-rule-' AND label == %@", ownedName))
        try wait("Original create must project the one owned rule", timeout: 30) {
            owned.count == 1 && app.buttons["保存规则"].isEnabled && app.staticTexts["编辑替换规则"].exists
        }
        let ruleID = String(owned.element.identifier.dropFirst("replace-rule-".count))
        try require(Int64(ruleID) != nil, "Use the actual projected Core ID, then bind it to the original create ACK")
        try checkpoints.reach("after-create-before-export", ruleID: ruleID, selectedKindLabel: kind.label)
        try ruleFileRequireOwnedDraft(ownedName, app: app)
        facts("ownedBaseName=\(fileBase)\nownedFilename=\(fileBase).json\nbookId=\(originalID)\nchapterId=\(chapterBefore)\nruleKind=\(kindBefore)\nApp launch environment not modified; exported JSON is never generated or read by the Runner",
              name: "rule-roundtrip-owned-system-file-and-original-context")

        let export = app.buttons["导出规则"]
        try ruleFileReveal(export, app: app)
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
        // Value discovers the initial filename only. Resolve the observed
        // native identifier afresh throughout editing and sheet dismissal.
        let nameFields = app.textFields.matching(identifier: "DOCPicker.filenameTextField")
        try replaceNativeFilename(nameFields, with: fileBase, app: app)
        let saveLabels = ["导出", "存储", "保存", "移动", "Export", "Save", "Move"]
        let saves = app.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", saveLabels))
        let save = try XCTUnwrap(saves.allElementsBoundByIndex.filter { $0.isHittable && $0.isEnabled }.only,
            "Use one actual native save/export button; never substitute a background file write")
        let nameBeforeSave = nameFields.count == 1 ? (nameFields.element.value as? String) : nil
        guard nameBeforeSave == fileBase || nameBeforeSave == fileBase + ".json" else {
            evidence(app, "rule-roundtrip-native-owned-filename-mismatch-before-save")
            try require(false, "Verify the new UUID-owned filename before the one actual save action")
            return
        }
        evidence(app, "rule-roundtrip-actual-native-owned-filename-before-save")
        save.tap()
        try wait("The normal native save sheet must return to the same rules workspace", timeout: 30) {
            (nameFields.count == 0 && app.buttons["导入规则"].isHittable) || app.alerts.firstMatch.exists
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
        // Reading the chosen file does not dispatch import. Recheck the exact
        // current four collections and original file before this one confirm.
        try checkpoints.reach("actual-file-before-import", ruleID: ruleID, selectedKindLabel: kind.label)
        confirmation.buttons["导入"].tap() // One original same-file merge, never a replay.
        try wait("The same original operation must leave pending before proceeding; never redispatch an unknown import", timeout: 120) {
            !confirmation.exists && app.buttons["导入规则"].isHittable && app.buttons["导入规则"].isEnabled
        }
        try require(!app.staticTexts["原操作待核对"].exists, "Pending is not a completed import")
        try wait("Refresh only after the original operation returns", timeout: 30) { !app.staticTexts["正在读取规则"].exists }
        try require(!app.staticTexts["规则工具尚未完成"].exists, "Keep a real projection failure as a failure")
        XCTAssertEqual(kind.label, kindBefore)
        try checkpoints.reach("import-terminal-before-delete", ruleID: ruleID, selectedKindLabel: kind.label)
        try ruleFileRequireOwnedDraft(ownedName, app: app)
        // Preserve the original form inputs through the file import. The full
        // persisted draft is independently checked at every external phase.
        let ownedRow = app.buttons["replace-rule-" + ruleID]
        try ruleFileReveal(ownedRow, app: app)
        try require(ownedRow.label == ownedName, "Never delete any other saved rule")
        let enabled = app.switches["enable-replace-rule-" + ruleID]
        try require(enabled.value as? String == "0", "The owned exported/imported rule remains disabled")
        let delete = app.buttons["delete-replace-rule-" + ruleID]
        try ruleFileReveal(delete, app: app)
        try require(delete.isHittable && delete.isEnabled, "Only the exact original Core ID may be deleted")
        delete.tap()
        let deleteAlert = app.alerts["删除规则"]
        try require(deleteAlert.waitForExistence(timeout: 5) && deleteAlert.staticTexts[ownedName].exists,
                    "The normal delete confirmation must name this exact owned rule")
        deleteAlert.buttons["删除"].tap()
        try wait("Only this owned rule leaves its projection", timeout: 25) { !ownedRow.exists && app.buttons["保存规则"].isEnabled }
        try checkpoints.reach("delete-terminal-before-clear", ruleID: ruleID, selectedKindLabel: kind.label)
        try ruleFileRequireOwnedDraft(ownedName, app: app)
        let reset = app.buttons["新建"]; try ruleFileReveal(reset, app: app)
        try require(reset.isHittable && reset.isEnabled, "Clear only the known-deleted owned input through normal New")
        reset.tap()
        let discard = app.alerts["替换当前草稿？"]
        try require(discard.waitForExistence(timeout: 5) && discard.buttons["替换"].isHittable,
                    "Require the existing owned draft replacement confirmation")
        discard.buttons["替换"].tap()
        try ruleFileRequireEmptyDraft(app)
        try checkpoints.reach("final", ruleID: ruleID, selectedKindLabel: kind.label)
        facts("ownedFilename=\(fileBase).json\nNative sheet returned without retry. This is not an ACK assertion.\nRequired original evidence: three finite rules.mutation.apply Host UUIDs in create → same-file merge → exact-ID delete order. The import mutation.params.json equals the actual exported UTF-8 file and replaceExisting=false. Each original binding operationId/sequence, outcome=applied, completed=true and original ACK is separately captured; no rejection or unknown is replayed.\nThe delivery owner also compares original/export SHA and pre/post rules, books, positions and assets. A fresh list cannot confirm this original write.",
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
        // Retain the one UUID-owned exported file. Only the exact owned rule
        // was deleted after its original import ACK. There is no failure-path
        // rule/file/draft cleanup, original replay, reprocess or arbitrary delete.
    }

    /// A separate readonly tail of the already terminal RuleFile1 journey.
    /// Its Runner proof is an external evidence binding, never a Core ACK.
    /// No old business intent or UserDefaults cleanup is executed here.
    func testKnownOriginalRuleFileTerminalsColdReadOnlyTailPreservesOriginalReading() throws {
        let proof = try NativeKnownRuleFileColdTailProof.load()
        let app = XCUIApplication()
        try require(app.state == .notRunning, "Require the external fresh post-install no-App observation; never terminate a running App to construct the premise")
        app.launch() // One cold launch; App environment/arguments are not changed.
        try openOriginal(app)
        try assertVisible(proof.reading.anchor, app: app) // The archived original OCR, never a fresh expected anchor.
        try controls(app)
        let expectedChapter = "reading-chapter:" + String(proof.reading.coreChapterIndex)
        try require(try chapterID(app) == expectedChapter, "Cold chapter must equal the externally protected original Core identity")
        try hide(app)
        let coldProgress = try progress(app)
        let coldDirectory = try directory(app, chapterID: expectedChapter)
        // The original 156s method's local AX values are not all necessarily
        // archived. Only actually observed original fields may constrain this
        // baseline; missing fields are never guessed from current UI or Core.
        if let original = proof.reading.originalProgressLabel {
            try require(coldProgress == original, "Compare the archived original footer when it actually exists")
        }
        if let original = proof.reading.originalDirectoryCountLabel {
            try require(coldDirectory.count == original, "Compare the archived original directory count when it actually exists")
        }
        if let original = proof.reading.originalDirectoryRowID {
            try require(coldDirectory.chapterID == original, "Compare the archived original directory row identity when it actually exists")
        }
        if let original = proof.reading.originalDirectoryRowTitle {
            try require(coldDirectory.title == original, "Compare the archived original directory title when it actually exists")
        }
        let baseline: [String: Any] = ["purpose":proof.purpose,"originalRun":proof.originalRunName,
            "originalCoreChapterIndex":proof.reading.coreChapterIndex,"originalCoreScalarOffset":proof.reading.coreScalarOffset,
            "currentColdSessionProgress":coldProgress,"currentColdSessionDirectoryCount":coldDirectory.count,
            "currentColdSessionDirectoryRowID":coldDirectory.chapterID,"currentColdSessionDirectoryRowTitle":coldDirectory.title,
            "archivedOriginalProgressAvailable":proof.reading.originalProgressLabel != nil,
            "archivedOriginalDirectoryCountAvailable":proof.reading.originalDirectoryCountLabel != nil,
            "archivedOriginalDirectoryRowIDAvailable":proof.reading.originalDirectoryRowID != nil,
            "archivedOriginalDirectoryTitleAvailable":proof.reading.originalDirectoryRowTitle != nil,
            "originalReadingFactsSHA256":proof.originalReadingFactsSHA256,
            "boundary":"Missing old AX strings are unobserved. Current values are a baseline only for this single cold session; original Core position/catalog versions/47 endpoints require external original-before preservation. This does not fill RuleFile1 phase6 evidence."]
        facts(String(decoding: try JSONSerialization.data(withJSONObject: baseline, options: [.sortedKeys]), as: UTF8.self),
              name: "rule-file-cold-tail-actual-session-baseline-and-old-evidence-limits")
        try openRules(app)
        try wait("Read current rules without mutating any collection or draft", timeout: 30) {
            !app.staticTexts["正在读取规则"].exists
        }
        try require(!app.staticTexts["规则工具尚未完成"].exists && !app.staticTexts["原操作待核对"].exists,
                    "A pending or failed read cannot stand in for the original rule terminals")
        let kinds = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '规则类型'"))
        try require(kinds.count == 1 && kinds.element.label.contains("替换"),
                    "The actual existing kind must already be replacement; never select another kind")
        try ruleFileRequireEmptyDraft(app) // Actual fields/default flags/order/timeout only; no New/Save.
        let ownedID = String(proof.ownedRuleID)
        let byName = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'replace-rule-' AND label == %@", proof.ownedRuleName))
        try require(!app.buttons["replace-rule-" + ownedID].exists &&
                    !app.buttons["delete-replace-rule-" + ownedID].exists && byName.count == 0,
                    "The known-deleted original ID/name must not appear in the actual replacement projection")
        evidence(app, "rule-file-cold-tail-actual-default-draft-and-owned-rule-absent")
        facts("purpose=\(proof.purpose)\noriginalRun=\(proof.originalRunName)\noriginalHostUUIDs=\(proof.originalHostOperationIDs.joined(separator: ","))\nownedFilename=\(proof.exportedFilename)\nactualFileSHA256=\(proof.exportedFileSHA256)\nexternalFactsSHA256=\(proof.externalFactsSHA256)\noriginalReadingFactsSHA256=\(proof.originalReadingFactsSHA256)\nsourceSnapshotSHA256=\(proof.sourceSnapshotSHA256)\nproductSealSHA256=\(proof.productSealSHA256)\nProof is not an ACK. No rule/file mutation intent is dispatched; ordinary reading persistence requires external original-ACK accounting. This does not replace RuleFile1's retained FAIL.",
              name: "rule-file-cold-tail-external-evidence-binding-not-ACK")
        try hide(app)
        try assertVisible(proof.reading.anchor, app: app)
        try require(try progress(app) == coldProgress, "Footer remains strictly equal to this actual cold-session baseline")
        try controls(app)
        try require(try chapterID(app) == expectedChapter, "Original Core chapter remains exact after readonly rule inspection")
        try require(try directory(app, chapterID: expectedChapter) == coldDirectory,
                    "Complete directory values remain strictly equal to this actual cold-session baseline")
        try controls(app); app.buttons["leave-reader"].tap()
        try require(app.buttons["更多书架操作"].waitForExistence(timeout: 20), "Finish through normal Leave; no second cold launch or cleanup")
    }

    // The native form driver follows the existing Native43 stable AX IDs and
    // public viewport geometry. It does not share that enabled-rule admission.
    private func ruleFileControl(_ id: String, app: XCUIApplication) throws -> XCUIElement {
        let values = app.descendants(matching: .any).matching(identifier: id)
        try require(values.count == 1, "The replacement form must expose one real control: " + id)
        return values.element
    }
    private func ruleFileFrame(_ control: XCUIElement) -> CGRect? {
        func usable(_ r: CGRect) -> Bool { r.minX.isFinite && r.minY.isFinite && r.width > 0 && r.height > 0 }
        if usable(control.frame) { return control.frame }
        return control.descendants(matching: .any).allElementsBoundByIndex.prefix(16).map(\.frame).first(where: usable)
    }
    private func ruleFileViewport(_ control: XCUIElement, app: XCUIApplication) -> CGRect? {
        let matches = app.scrollViews.allElementsBoundByIndex.filter { scroll in
            if !control.identifier.isEmpty { return scroll.descendants(matching: .any).matching(identifier: control.identifier).count > 0 }
            return scroll.descendants(matching: .any).matching(NSPredicate(format: "label == %@", control.label)).count > 0
        }
        return matches.compactMap { scroll -> CGRect? in
            var rect = scroll.frame.intersection(app.frame)
            if app.keyboards.firstMatch.exists && rect.intersects(app.keyboards.firstMatch.frame) {
                rect.size.height = max(0, app.keyboards.firstMatch.frame.minY - 8 - rect.minY)
            }
            return !rect.isNull && rect.width > 80 && rect.height > 80 ? rect : nil
        }.min(by: { $0.height < $1.height })
    }
    private func ruleFileCoordinate(_ p: CGPoint, app: XCUIApplication) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: p.x - app.frame.minX, dy: p.y - app.frame.minY))
    }
    private func ruleFileReveal(_ control: XCUIElement, app: XCUIApplication) throws {
        for _ in 0..<24 {
            if control.exists && control.isHittable { return }
            guard let frame = ruleFileFrame(control), let viewport = ruleFileViewport(control, app: app) else {
                evidence(app, "rule-file-form-real-geometry-missing")
                try require(false, "No actual form/ScrollView geometry for " + control.identifier); return
            }
            let inset = min(36, viewport.height * 0.15), top = viewport.minY + inset, bottom = viewport.maxY - inset
            let down: Bool, distance: CGFloat
            if frame.minY < top { down = false; distance = top - frame.minY }
            else if frame.maxY > bottom { down = true; distance = frame.maxY - bottom }
            else { try require(false, "The actual control is already in its viewport but is not hittable"); return }
            let travel = min(max(distance, 24), (bottom - top) * 0.6), startY = down ? bottom : top
            ruleFileCoordinate(CGPoint(x: viewport.midX, y: startY), app: app).press(forDuration: 0.05,
                thenDragTo: ruleFileCoordinate(CGPoint(x: viewport.midX, y: down ? startY - travel : startY + travel), app: app),
                withVelocity: .slow, thenHoldForDuration: 0.15)
        }
        evidence(app, "rule-file-form-control-not-hittable")
        try require(false, "Actual form control did not become hittable")
    }
    private func ruleFileFill(_ id: String, _ text: String, app: XCUIApplication) throws {
        let first = try ruleFileControl("replacement-draft-name", app: app); try ruleFileReveal(first, app: app)
        let field = try ruleFileControl(id, app: app); try ruleFileReveal(field, app: app)
        try require(value(field).isEmpty, "Never overwrite an unexpected existing draft field")
        field.tap(); try ruleFileControl(id, app: app).typeText(text)
        let updated = try ruleFileControl(id, app: app)
        try require(updated.value as? String == text, "The real field must contain the exact literal, without an appended newline")
        if app.keyboards.firstMatch.exists {
            let hide = app.buttons.matching(NSPredicate(format: "label IN %@", ["隐藏键盘", "Hide keyboard", "Dismiss keyboard"]))
                .allElementsBoundByIndex.filter { $0.isHittable && $0.isEnabled }
            if let button = hide.only { button.tap() }
            else {
                guard let viewport = ruleFileViewport(updated, app: app) else { try require(false, "Observe the real form above its keyboard"); return }
                let inset = min(28, viewport.height * 0.15)
                ruleFileCoordinate(CGPoint(x: viewport.midX, y: viewport.maxY - inset), app: app).press(forDuration: 0.05,
                    thenDragTo: ruleFileCoordinate(CGPoint(x: viewport.midX, y: viewport.minY + inset), app: app))
            }
            try wait("Native form keyboard dismissal", timeout: 5) { !app.keyboards.firstMatch.exists }
        }
    }
    private func ruleFileSetSwitch(_ control: XCUIElement, to wanted: String, app: XCUIApplication) throws {
        try ruleFileReveal(control, app: app)
        if control.value as? String != wanted {
            let inner = control.switches.firstMatch, action = inner.exists ? inner : control
            try require(action.isHittable && action.isEnabled, "Use the actual native switch")
            action.tap()
        }
        try wait("Native rule flag must match its original intent", timeout: 5) { control.value as? String == wanted }
    }
    private func ruleFileRequireEmptyDraft(_ app: XCUIApplication) throws {
        for id in ["replacement-draft-name", "replacement-draft-pattern", "replacement-draft-replacement",
                   "replacement-draft-scope", "replacement-draft-exclude-scope", "replacement-draft-group"] {
            let field = try ruleFileControl(id, app: app); try ruleFileReveal(field, app: app)
            try require(value(field).isEmpty, "Preserve any preexisting nonempty draft")
        }
        try ruleFileReveal(try ruleFileControl("replacement-draft-name", app: app), app: app)
        try require(app.staticTexts["新替换规则"].exists && !app.staticTexts["编辑替换规则"].exists, "Require a new-rule draft, not an existing saved-rule editor")
        try ruleFileRequireOriginalNumericDefaults(app)
        for (label, expected) in [("正则表达式", "1"), ("作用于正文", "1"), ("作用于标题", "0"), ("作用于书源", "0"), ("启用此规则", "1")] {
            let control = app.switches[label]; try ruleFileReveal(control, app: app)
            try require(control.value as? String == expected, "The original empty draft configuration must remain unchanged")
        }
    }
    private func ruleFileRequireOwnedDraft(_ name: String, app: XCUIApplication) throws {
        let fields = [("replacement-draft-name",name),("replacement-draft-pattern","斟酌用词"),
            ("replacement-draft-replacement","推敲用词"),("replacement-draft-scope","仙子请听我解释"),
            ("replacement-draft-exclude-scope",""),("replacement-draft-group","")]
        for (id, expected) in fields {
            let field = try ruleFileControl(id, app: app); try ruleFileReveal(field, app: app)
            try require(value(field) == expected, "Preserve the exact owned input before any next intent")
        }
        try ruleFileRequireOriginalNumericDefaults(app)
        for (label, expected) in [("正则表达式", "0"), ("作用于正文", "1"), ("作用于标题", "0"), ("作用于书源", "0"), ("启用此规则", "0")] {
            let control = app.switches[label]; try ruleFileReveal(control, app: app)
            try require(control.value as? String == expected, "The owned saved/exported rule is plain, body-only and disabled")
        }
    }

    private func ruleFileRequireOriginalNumericDefaults(_ app: XCUIApplication) throws {
        for (label, expected) in [("执行顺序", "0"), ("匹配超时（毫秒）", "3000")] {
            let fields = app.textFields.matching(NSPredicate(format: "label == %@ OR placeholderValue == %@", label, label))
            try require(fields.count == 1, "Use the existing actual numeric field: " + label)
            let field = fields.element; try ruleFileReveal(field, app: app)
            try require((field.value as? String)?.replacingOccurrences(of: ",", with: "") == expected,
                        "Preserve the existing original order and timeout")
        }
    }

    private func openOriginal(_ app: XCUIApplication) throws {
        try require(app.buttons["更多书架操作"].waitForExistence(timeout: 25), "The exact original must already be picker-imported")
        if app.textFields["shelf-filter"].exists { app.buttons["bookshelf-filter-close"].tap() }
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
    private func replaceNativeFilename(_ fields: XCUIElementQuery, with filename: String, app: XCUIApplication) throws {
        try require(fields.count == 1 && fields.element.isHittable && fields.element.isEnabled,
                    "The native identifier must resolve one editable exported filename")
        let originalValue = try XCTUnwrap(fields.element.value as? String)
        try require(originalValue.count > 1, "The original filename must contain more than one character")
        fields.element.tap()
        try settleNativeFilenameKeyboard(fields, app: app)
        try require(fields.count == 1 && (fields.element.value as? String) == originalValue,
                    "Keyboard setup must preserve the original exported filename")
        // Use one native Delete and one UUID input. The complete resulting
        // value, rather than the empty field's AX representation, gates Save.
        fields.element.typeText(XCUIKeyboardKey.delete.rawValue)
        fields.element.typeText(filename)
        let actualValue = fields.count == 1 ? (fields.element.value as? String) : nil
        guard actualValue == filename || actualValue == filename + ".json" else {
            evidence(app, "rule-roundtrip-native-owned-filename-mismatch-after-input")
            try require(false, "The actual system filename must contain only the new UUID-owned name")
            return
        }
    }
    private func settleNativeFilenameKeyboard(_ fields: XCUIElementQuery, app: XCUIApplication) throws {
        let explanation = "Speed up your typing by sliding your finger across the letters to compose a word."
        let guide = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR value == %@", explanation, explanation))
        func visibleGuide() -> [XCUIElement] {
            guide.allElementsBoundByIndex.filter { !$0.frame.isEmpty && app.frame.contains($0.frame) }
        }
        // The explanation is literal evidence from Rule6's native video; its
        // AX role is not assumed. Without this exact text, retain the ordinary
        // filename path and never select an unrelated Continue action.
        let appeared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !visibleGuide().isEmpty }, object: nil)
        guard XCTWaiter.wait(for: [appeared], timeout: 1) == .completed else { return }

        var previousField: CGRect?, previousKeyboard: CGRect?, stableSince: Date?
        func resetStability() { previousField = nil; previousKeyboard = nil; stableSince = nil }
        func sameFrame(_ first: CGRect, _ second: CGRect) -> Bool {
            abs(first.minX - second.minX) < 0.5 && abs(first.minY - second.minY) < 0.5 &&
                abs(first.width - second.width) < 0.5 && abs(first.height - second.height) < 0.5
        }
        func inputIsStable() -> Bool {
            let keyboard = app.keyboards.firstMatch
            guard fields.count == 1 else { resetStability(); return false }
            let field = fields.element
            guard field.exists, field.isHittable, field.isEnabled, keyboard.exists else { resetStability(); return false }
            let fieldFrame = field.frame, keyboardFrame = keyboard.frame
            guard !fieldFrame.isEmpty, !keyboardFrame.isEmpty, app.frame.contains(fieldFrame),
                  keyboardFrame.intersects(app.frame), fieldFrame.maxY <= keyboardFrame.minY + 1 else {
                resetStability(); return false
            }
            if let previousField, let previousKeyboard, let stableSince,
               sameFrame(fieldFrame, previousField), sameFrame(keyboardFrame, previousKeyboard) {
                return Date().timeIntervalSince(stableSince) >= 0.25
            }
            previousField = fieldFrame; previousKeyboard = keyboardFrame; stableSince = Date()
            return false
        }
        var action: XCUIElement?
        let actionable = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let buttons = app.buttons.matching(NSPredicate(format: "label == 'Continue'"))
                .allElementsBoundByIndex.filter { $0.isHittable && $0.isEnabled && app.frame.contains($0.frame) }
            guard let text = visibleGuide().only, let button = buttons.only,
                  button.frame.minY >= text.frame.maxY else { return false }
            action = button; return true
        }, object: nil)
        if XCTWaiter.wait(for: [actionable], timeout: 5) != .completed {
            evidence(app, "rule-roundtrip-native-quickpath-not-actionable")
            try require(false, "The exact QuickPath explanation must expose one visible enabled Continue")
        }
        evidence(app, "rule-roundtrip-observed-native-quickpath-guide")
        try XCTUnwrap(action).tap()
        resetStability()
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !guide.firstMatch.exists && inputIsStable()
        }, object: nil)
        if XCTWaiter.wait(for: [settled], timeout: 10) != .completed {
            evidence(app, "rule-roundtrip-native-filename-keyboard-not-settled")
            try require(false, "QuickPath must dismiss and the same filename/keyboard must settle before editing")
        }
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

/// Simulator Runner evidence only. These files are private checkpoint records,
/// never App preferences, bundle input, a Core command, or a write ACK.
private final class NativeRuleFileCheckpoints {
    struct Proof: Decodable {
        let schemaVersion: Int; let purpose: String; let runNonce: String; let targetUDID: String
        let channelDirectory: String; let challengeSHA256: String
        let sourceSnapshotSHA256: String; let productSealSHA256: String
        let bookId: String; let originalSHA256: String
        let ownedRuleName: String; let ownedFileBase: String
        let pattern: String; let replacement: String; let includeScope: String
        let enabled: Bool; let isRegex: Bool; let scopeContent: Bool; let scopeTitle: Bool; let scopeSource: Bool
    }
    private enum Boundary: Error { case invalidEvidence }
    let proof: Proof
    private let directory: URL
    private var index = 0
    private var exportSHA: String?
    private let phases = ["before-create", "after-create-before-export", "actual-file-before-import",
                          "import-terminal-before-delete", "delete-terminal-before-clear", "final"]
    init() throws {
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["READER_RULE_FILE_CHECKPOINT_JSON"], raw.utf8.count <= 32 * 1024,
              let expected = env["READER_RULE_FILE_CHECKPOINT_SHA256"], Self.sha(Data(raw.utf8)) == expected else {
            XCTFail("Require this run's exact disabled-rule file checkpoint proof, not the Native43 enabled admission")
            throw Boundary.invalidEvidence
        }
        proof = try JSONDecoder().decode(Proof.self, from: Data(raw.utf8))
        guard proof.schemaVersion == 1, proof.purpose == "disabled-real-rule-native-file-checkpoints-v2",
              UUID(uuidString: proof.runNonce) != nil,
              env["SIMULATOR_UDID"] == proof.targetUDID,
              proof.targetUDID == "EEA74BB1-5DFA-479A-ACAA-460503AD0F6B",
              proof.bookId == "local:aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5",
              proof.originalSHA256 == String(proof.bookId.dropFirst("local:".count)),
              proof.pattern == "斟酌用词", proof.replacement == "推敲用词", proof.includeScope == "仙子请听我解释",
              !proof.enabled, !proof.isRegex, proof.scopeContent, !proof.scopeTitle, !proof.scopeSource,
              proof.ownedRuleName == "规则文件-" + proof.runNonce,
              proof.ownedFileBase == "Reader-Rule-RoundTrip-" + proof.runNonce else { throw Boundary.invalidEvidence }
        directory = URL(fileURLWithPath: proof.channelDirectory, isDirectory: true).standardizedFileURL
        guard directory.path.hasPrefix("/Users/minliny/Documents/Reader/.reader-artifacts/ios-v2-v4-development/"),
              directory.lastPathComponent == "rule-file-checkpoints-" + proof.runNonce else { throw Boundary.invalidEvidence }
    }
    func reach(_ phase: String, ruleID: String?, selectedKindLabel: String) throws {
        guard index < phases.count, phases[index] == phase,
              selectedKindLabel.hasPrefix("规则类型"), selectedKindLabel.contains("替换") else { throw Boundary.invalidEvidence }
        if index == 0 {
            let challenge = try read(directory.appendingPathComponent("challenge.json"))
            guard Self.sha(challenge) == proof.challengeSHA256,
                  let value = try JSONSerialization.jsonObject(with: challenge) as? [String: Any],
                  value["runNonce"] as? String == proof.runNonce,
                  value["purpose"] as? String == proof.purpose else { throw Boundary.invalidEvidence }
        }
        let requestID = UUID().uuidString.lowercased()
        let prefix = String(format: "%02d-", index + 1) + phase
        let request: [String: Any] = ["schemaVersion":1,"purpose":proof.purpose,"runNonce":proof.runNonce,
            "phase":phase,"ordinal":index + 1,"requestUUID":requestID,"ruleID":ruleID ?? NSNull(),
            "actualSelectedKindLabel":selectedKindLabel,
            "ownedRuleName":proof.ownedRuleName,"ownedFilename":proof.ownedFileBase + ".json",
            "sourceSnapshotSHA256":proof.sourceSnapshotSHA256,"productSealSHA256":proof.productSealSHA256]
        let raw = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
        let path = directory.appendingPathComponent(prefix + ".request.json")
        // Complete a unique temporary file, then publish a no-overwrite hard
        // link. If Simulator Runner cannot read/write this Mac path, this first
        // checkpoint fails before any save and the directory is retained.
        let temporary = directory.appendingPathComponent(requestID + ".request.tmp")
        try raw.write(to: temporary, options: .withoutOverwriting)
        guard Darwin.link(temporary.path, path.path) == 0 else { throw Boundary.invalidEvidence }
        try FileManager.default.removeItem(at: temporary)
        let responsePath = directory.appendingPathComponent(prefix + ".response.json")
        let observed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: responsePath.path)
        }, object: nil)
        guard XCTWaiter.wait(for: [observed], timeout: 30) == .completed else {
            XCTFail("No finite original-evidence response; preserve this run's UUID/file/rule/draft and stop")
            throw Boundary.invalidEvidence
        }
        let bytes = try read(responsePath)
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        attachment.name = "rule-file-original-evidence-" + phase; attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Original evidence checkpoint " + phase) { $0.add(attachment) }
        guard let response = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              response["schemaVersion"] as? Int == 1, response["purpose"] as? String == proof.purpose,
              response["runNonce"] as? String == proof.runNonce, response["phase"] as? String == phase,
              response["ordinal"] as? Int == index + 1, response["requestUUID"] as? String == requestID,
              response["requestSHA256"] as? String == Self.sha(raw),
              response["status"] as? String == "PASS_ORIGINAL_FACTS",
              let checks = response["checks"] as? [String: Bool], !checks.isEmpty, checks.values.allSatisfy({ $0 }),
              let commands = response["originalCommands"] as? [[String: Any]],
              commands.count == [0,1,1,2,3,3][index] else { throw Boundary.invalidEvidence }
        if let ruleID { guard (response["ownedRuleID"] as? NSNumber)?.stringValue == ruleID else { throw Boundary.invalidEvidence } }
        if index >= 2 {
            guard let actual = response["exportSHA256"] as? String, actual.count == 64,
                  exportSHA == nil || exportSHA == actual else { throw Boundary.invalidEvidence }
            exportSHA = actual
        }
        index += 1
    }
    private func read(_ url: URL) throws -> Data {
        let facts = try url.resourceValues(forKeys: [.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
        guard facts.isRegularFile == true, facts.isSymbolicLink != true,
              let count = facts.fileSize, count <= 64 * 1024 else { throw Boundary.invalidEvidence }
        let value = try Data(contentsOf: url)
        guard value.count == count else { throw Boundary.invalidEvidence }; return value
    }
    private static func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format:"%02x",$0) }.joined() }
}

/// Runner-only readonly evidence for a known, already completed original run.
/// The external guard validates original frozen UUID/parameters/ACK/file bytes,
/// all four collections, defaults, original progress/47 positions and fonts.
/// This type does not query Core, read the App sandbox or declare an ACK.
private struct NativeKnownRuleFileColdTailProof: Decodable {
    struct Reading: Decodable {
        let coreChapterIndex: UInt32
        let coreScalarOffset: UInt64
        let anchor: String
        let originalProgressLabel: String?
        let originalDirectoryCountLabel: String?
        let originalDirectoryRowID: String?
        let originalDirectoryRowTitle: String?
    }
    let schemaVersion: Int
    let purpose: String
    let targetUDID: String
    let bookId: String
    let originalSHA256: String
    let originalRunName: String
    let originalHostOperationIDs: [String]
    let ownedRuleID: Int64
    let ownedRuleName: String
    let exportedFilename: String
    let exportedFileSHA256: String
    let coreCommit: String
    let bindingSHA256: String
    let sourceSnapshotSHA256: String
    let productSealSHA256: String
    let externalFactsSHA256: String
    let originalReadingFactsSHA256: String
    let capturedAfterInstallBeforeLaunch: Bool
    let deviceStateBooted: Bool
    let observedNoAppProcess: Bool
    let quiescentObservedAtUTC: String
    let productSealUTC: String
    let protectedPositionCount: Int
    let checks: [String: Bool]
    let reading: Reading
    private enum Invalid: Error { case externalEvidenceRequired }
    static func load() throws -> Self {
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["READER_RULE_FILE_COLD_TAIL_PROOF_JSON"], raw.utf8.count <= 32 * 1024,
              let expected = env["READER_RULE_FILE_COLD_TAIL_PROOF_SHA256"],
              SHA256.hash(data: Data(raw.utf8)).map({ String(format: "%02x", $0) }).joined() == expected else {
            XCTFail("Require the exact new readonly cold-tail proof; no prior business admission or fresh read is an ACK")
            throw Invalid.externalEvidenceRequired
        }
        let value = try JSONDecoder().decode(Self.self, from: Data(raw.utf8))
        let requiredChecks: Set<String> = ["originalThreeCommandsExactUUIDParamsACK", "noPendingOriginalOperation",
            "actualOriginalExportFileExact", "fourCompleteRuleCollectionsRestored",
            "completeOwnedDraftDefaultAndOtherFieldsOriginal", "originalProgressAndAll47PositionsExact", "originalCatalogCacheVersionsExact",
            "fontsAndRawFontPreferencesExact", "originalFilesSourcesLibraryIdentityProtected",
            "noNewRuleReprocessDownloadOperation", "freshPostInstallQuiescentObservation"]
        let hashes = [value.originalSHA256, value.exportedFileSHA256, value.bindingSHA256,
            value.sourceSnapshotSHA256, value.productSealSHA256, value.externalFactsSHA256, value.originalReadingFactsSHA256]
        let originalIDs = ["ceae9eb7-ba3e-45c8-8567-821b70471749", "0e24b5c8-a932-4c31-8623-8e5dad5f2ed8",
                           "c877aebb-26aa-4332-a276-9ef78b9cf0d9"]
        let normalizedAnchor = String(String.UnicodeScalarView(value.reading.anchor.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
        let timestamp = ISO8601DateFormatter()
        timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let observed = timestamp.date(from: value.quiescentObservedAtUTC) ?? ISO8601DateFormatter().date(from: value.quiescentObservedAtUTC)
        let sealed = timestamp.date(from: value.productSealUTC) ?? ISO8601DateFormatter().date(from: value.productSealUTC)
        guard value.schemaVersion == 1, value.purpose == "readonly-known-rule-file-cold-tail-v1",
              env["SIMULATOR_UDID"] == value.targetUDID,
              value.targetUDID == "EEA74BB1-5DFA-479A-ACAA-460503AD0F6B",
              value.bookId == "local:aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5",
              value.originalSHA256 == String(value.bookId.dropFirst("local:".count)),
              value.originalRunName == "large-disabled-rule-file-1", value.originalHostOperationIDs == originalIDs,
              value.ownedRuleID == 1, value.ownedRuleName == "规则文件-8ca90df2-dce9-4256-9fb1-d38957bab488",
              value.exportedFilename == "Reader-Rule-RoundTrip-8ca90df2-dce9-4256-9fb1-d38957bab488.json",
              value.exportedFileSHA256 == "f5b8c81bead87308cbbf2ffd246456064a2b1006ccc7b20717f6c9fa19da7817",
              value.coreCommit == "1411965a65a0f3098c02679be5ef979ae9462867",
              value.bindingSHA256 == "e503d27a66db701d85a6c55e76051617a0878b0e39707400dc6ddbd73452bdc0",
              value.originalReadingFactsSHA256 == "d266407ed559a7808ad06937e0b0e377aca7b8c137753975f82c9fecc9999b2f",
              hashes.allSatisfy({ $0.count == 64 && $0.unicodeScalars.allSatisfy { "0123456789abcdef".unicodeScalars.contains($0) } }),
              value.capturedAfterInstallBeforeLaunch, value.deviceStateBooted, value.observedNoAppProcess,
              let observed, let sealed, sealed <= observed, observed <= Date(), value.protectedPositionCount == 47,
              requiredChecks.isSubset(of: Set(value.checks.keys)), value.checks.values.allSatisfy({ $0 }),
              // Original UI facts archive the chapter/selected row and visible
              // Quick count. The old footer AX return was not archived; its
              // separate visible Quick 100% frame is not substituted for it.
              value.reading.coreChapterIndex == 1, value.reading.originalProgressLabel == nil,
              value.reading.originalDirectoryCountLabel == "共 948 章",
              value.reading.originalDirectoryRowID == "chapter-1",
              value.reading.originalDirectoryRowTitle == "第一章 深山古庙",
              (18...24).contains(value.reading.anchor.count), normalizedAnchor == value.reading.anchor else {
            XCTFail("Readonly original terminal/file/position/defaults/font/quiescence evidence is incomplete; preserve data and do not replay anything")
            throw Invalid.externalEvidenceRequired
        }
        return value
    }
}
