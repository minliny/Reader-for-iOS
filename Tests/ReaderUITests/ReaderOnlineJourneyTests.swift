import XCTest
import UIKit
import CryptoKit

final class ReaderOnlineJourneyTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    /// The Runner binds an existing, real source-file draft before this method.
    /// This cancels replacement and reselects those same real file bytes. It
    /// never edits the draft or submits a Core source import/save.
    func testExistingRealSourceDraftCancelledReplacementAndColdReopenPreserveExactInput() throws {
        let environment = ProcessInfo.processInfo.environment
        let expectedSHA = try XCTUnwrap(environment["READER_SOURCE_DRAFT_EXPECTED_SHA256"])
        let expectedBytes = try XCTUnwrap(Int(environment["READER_SOURCE_DRAFT_EXPECTED_BYTES"] ?? ""))
        XCTAssertEqual(expectedSHA.count, 64)
        XCTAssertGreaterThan(expectedBytes, 0)
        let app = XCUIApplication()
        app.launch()
        openExistingSourceManagement(app)
        assertPreservedSourceDraft(app, sha: expectedSHA, bytes: expectedBytes)
        closePreservedSourceDraft(app)

        let edits = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-source-edit:"))
        XCTAssertGreaterThan(edits.count, 0, "An actual already saved source is required; no source is generated or imported here.")
        let edit = edits.element(boundBy: 0)
        let sourceIdentity = edit.identifier
        XCTAssertTrue(edit.isHittable, app.debugDescription)
        edit.tap()
        let alert = app.alerts["替换当前书源草稿？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "Editing a different saved source must protect the existing unsaved real-file draft.\n" + app.debugDescription)
        let identity = XCTAttachment(string: "incomingSavedSource=\(sourceIdentity)\noriginalDraftSHA256=\(expectedSHA)\noriginalDraftUTF8Bytes=\(expectedBytes)\nNo save, text edit, confirmation acceptance or Core mutation is requested.")
        identity.name = "real-source-draft-cancelled-replacement-identity"
        identity.lifetime = .keepAlways
        add(identity)
        keepScreenshot(app, name: "real-source-draft-replacement-requires-confirmation")
        let cancel = alert.buttons["取消"]
        XCTAssertTrue(cancel.isHittable)
        cancel.tap()
        waitFor(alert, timeout: 5, message: "Cancellation must dismiss only the replacement confirmation") { !$0.exists }
        assertPreservedSourceDraft(app, sha: expectedSHA, bytes: expectedBytes)
        closePreservedSourceDraft(app)
        leaveExistingSourceManagement(app)

        // Cold startup follows the normal parent return, with no accepted save.
        app.terminate()
        app.launch()
        openExistingSourceManagement(app)
        assertPreservedSourceDraft(app, sha: expectedSHA, bytes: expectedBytes)
        keepScreenshot(app, name: "real-source-draft-cold-reopened-exact-input")
        closePreservedSourceDraft(app)
        let file = app.buttons["online-source-file"]
        XCTAssertTrue(file.isHittable)
        file.tap()
        selectProvisionedSourcePackage(in: app)
        assertSourceDraftValue(app, sha: expectedSHA, bytes: expectedBytes)
        keepScreenshot(app, name: "real-source-draft-same-original-file-read-without-save")
        closePreservedSourceDraft(app)
        leaveExistingSourceManagement(app)
    }

    /// Uses one source already present in the real saved source library and
    /// currently disabled by the user. The method temporarily enables that
    /// exact source through the public management UI, performs one real
    /// search, observes its failure/empty outcome alongside the two existing
    /// enabled sources, then restores the disabled state through the same UI.
    /// No source JSON, URL, network response, delay, or result is fabricated.
    func testExistingRealDisabledSourceFailureIsolatedFromEnabledSearchResultsAndRestored() throws {
        let disabledSourceID = "http://199.33.126.51"
        let enabledSourceIDs = ["https://m.idejian.com", "https://dushu.baidu.com/"]
        let keyword = "剑来"
        let app = XCUIApplication()
        var changed = false
        var restored = false

        func toggle(_ sourceID: String) -> XCUIElement {
            app.switches["online-source-enabled:\(sourceID)"]
        }
        func toggleValue(_ sourceID: String) -> String? {
            toggle(sourceID).value as? String
        }
        func waitToggle(_ sourceID: String, _ expected: String) throws {
            try sourceToolsWait("The existing source toggle did not settle to \(expected): \(sourceID)", timeout: 30) {
                toggleValue(sourceID) == expected
            }
        }
        func closeSourcesKeepWorkspace() throws {
            let close = app.buttons["online-close-sources"]
            if close.exists, close.isHittable { close.tap() }
            try sourceToolsRequire(app.buttons["online-search-submit"].waitForExistence(timeout: 10),
                "Return to the actual search workspace", app: app)
        }
        func restoreDisabledSource() {
            guard changed, app.state != .notRunning else { return }
            if !toggle(disabledSourceID).exists {
                if app.buttons["online-open-sources"].exists, app.buttons["online-open-sources"].isHittable {
                    app.buttons["online-open-sources"].tap()
                    _ = app.buttons["online-source-file"].waitForExistence(timeout: 10)
                }
            }
            let sourceToggle = toggle(disabledSourceID)
            if sourceToggle.exists, (sourceToggle.value as? String) == "1" {
                sourceToggle.tap()
                try? sourceToolsWait("Restore the existing disabled source in teardown", timeout: 30) {
                    (sourceToggle.value as? String) == "0"
                }
            }
            restored = sourceToggle.exists && (sourceToggle.value as? String) == "0"
            if app.buttons["online-close-sources"].exists, app.buttons["online-close-sources"].isHittable {
                app.buttons["online-close-sources"].tap()
            }
            if app.buttons["online-close-workspace"].exists, app.buttons["online-close-workspace"].isHittable {
                app.buttons["online-close-workspace"].tap()
            }
        }
        addTeardownBlock { restoreDisabledSource() }

        app.launch()
        openExistingSourceManagement(app)
        let sourceRows = try sourceToolsSourceLabels(app)
        try sourceToolsRequire(sourceRows["online-source:\(disabledSourceID)"] == "👍 同人圈",
            "Require the existing disabled source identity and name; no substitute source is allowed", app: app)
        for sourceID in enabledSourceIDs {
            try sourceToolsRequire(toggleValue(sourceID) == "1",
                "The two known real sources must remain enabled before this search", app: app)
        }
        try sourceToolsRequire(toggleValue(disabledSourceID) == "0",
            "The historical real source must start disabled", app: app)
        let before = XCTAttachment(string: "disabledSource=\(disabledSourceID)\nname=👍 同人圈\nenabledSources=\(enabledSourceIDs.joined(separator: ","))\nkeyword=\(keyword)")
        before.name = "real-disabled-source-before-enable"; before.lifetime = .keepAlways; add(before)

        toggle(disabledSourceID).tap(); changed = true
        try waitToggle(disabledSourceID, "1")
        try closeSourcesKeepWorkspace()

        let query = app.textFields["online-search-query"]
        try sourceToolsRequire(query.waitForExistence(timeout: 10) && (query.value as? String == "书名或作者" || query.value as? String == ""),
            "The real search query must start empty", app: app)
        query.tap(); query.typeText(keyword)
        app.buttons["online-search-submit"].tap()
        try sourceToolsWait("Wait for this actual mixed-source search to settle", timeout: 180) {
            !app.buttons["online-search-stop"].exists
        }
        let failures = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "个书源未完成"))
        let candidates = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-result:"))
            .allElementsBoundByIndex
        let enabledResults = candidates.filter { button in
            enabledSourceIDs.contains { button.identifier.contains($0 + "|") }
        }
        let resultFacts: [String: Any] = [
            "disabledSourceID": disabledSourceID,
            "enabledSourceIDs": enabledSourceIDs,
            "keyword": keyword,
            "failureMessageCount": failures.count,
            "allResultIdentifiers": candidates.map(\.identifier),
            "enabledResultIdentifiers": enabledResults.map(\.identifier),
            "restoredAfterTest": false
        ]
        let resultAttachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: resultFacts, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        resultAttachment.name = "real-disabled-source-failure-isolation-outcome"; resultAttachment.lifetime = .keepAlways; add(resultAttachment)
        try sourceToolsRequire(failures.count == 1,
            "The actual disabled-source request must surface one public failure indicator; no synthetic failure is accepted", app: app)
        try sourceToolsRequire(!enabledResults.isEmpty,
            "At least one existing enabled source must retain real results while the disabled-source failure is shown", app: app)

        try closeSourcesKeepWorkspace()
        app.buttons["online-close-workspace"].tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 10))
        app.buttons["更多书架操作"].tap(); app.buttons["搜索与书源"].tap(); app.buttons["online-open-sources"].tap()
        XCTAssertTrue(toggle(disabledSourceID).waitForExistence(timeout: 10))
        if (toggleValue(disabledSourceID) == "1") { toggle(disabledSourceID).tap() }
        try waitToggle(disabledSourceID, "0")
        restored = true
        try sourceToolsRequire(try sourceToolsSourceLabels(app)["online-source:\(disabledSourceID)"] == "👍 同人圈",
            "Restoring the real source must preserve its original identity and definition", app: app)
        let after = XCTAttachment(string: "disabledSource=\(disabledSourceID)\nenabled=\(toggleValue(disabledSourceID) ?? "unknown")\nrestored=true")
        after.name = "real-disabled-source-restored-disabled"; after.lifetime = .keepAlways; add(after)
        try closeSourcesKeepWorkspace(); app.buttons["online-close-workspace"].tap()
        XCTAssertTrue(restored)
    }

    /// Stop a real search as soon as the public stop control appears. The two
    /// enabled sources and the real keyword come from the existing saved
    /// library; no artificial delay, response, or source is introduced.
    func testExistingRealSearchCanStopBeforeCompletionAndRetainsActualResults() throws {
        let app = XCUIApplication()
        app.launch()
        let shelfMenu = app.buttons["更多书架操作"]
        XCTAssertTrue(shelfMenu.waitForExistence(timeout: 20), app.debugDescription)
        shelfMenu.tap()
        let online = app.buttons["搜索与书源"]
        XCTAssertTrue(online.waitForExistence(timeout: 5), app.debugDescription)
        online.tap()
        let query = app.textFields["online-search-query"]
        XCTAssertTrue(query.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(query.value as? String == "书名或作者" || query.value as? String == "")
        query.tap(); query.typeText("剑来")
        app.buttons["online-search-submit"].tap()
        let stop = app.buttons["online-search-stop"]
        guard stop.waitForExistence(timeout: 15), stop.isHittable, stop.isEnabled else {
            let prerequisite = XCTAttachment(string: "The real search completed before its stop control became available; no artificial delay is allowed")
            prerequisite.name = "real-search-stop-prerequisite-unavailable"; prerequisite.lifetime = .keepAlways; add(prerequisite)
            throw XCTSkip("The real search completed before its stop control became available; no artificial delay is allowed")
        }
        stop.tap()
        try sourceToolsWait("The actual search must settle after the one real stop action", timeout: 20) {
            !app.buttons["online-search-stop"].exists
        }
        let stopped = app.staticTexts["搜索已停止"]
        let candidates = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-result:"))
        let facts: [String: Any] = [
            "keyword": "剑来",
            "stopTapCount": 1,
            "stoppedStateVisible": stopped.exists,
            "candidateCountAfterStop": candidates.count,
            "boundary": "This is one real stop action against the existing enabled source set. It does not claim a partial network response if the live request completed before stop; the method remains a prerequisite failure in that case."
        ]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "real-search-stop-actual-outcome"; attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertTrue(stopped.exists, "The existing public stopped state must be visible after the actual stop")
        app.buttons["online-close-workspace"].tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 10), app.debugDescription)
    }

    private func openExistingSourceManagement(_ app: XCUIApplication) {
        let shelfMenu = app.buttons["更多书架操作"]
        XCTAssertTrue(shelfMenu.waitForExistence(timeout: 20), app.debugDescription)
        shelfMenu.tap()
        let online = app.buttons["搜索与书源"]
        XCTAssertTrue(online.waitForExistence(timeout: 5), app.debugDescription)
        online.tap()
        let sources = app.buttons["online-open-sources"]
        XCTAssertTrue(sources.waitForExistence(timeout: 10), app.debugDescription)
        sources.tap()
        XCTAssertTrue(app.buttons["online-source-file"].waitForExistence(timeout: 10), app.debugDescription)
    }

    private func assertPreservedSourceDraft(_ app: XCUIApplication, sha: String, bytes: Int) {
        let resume = app.buttons["导入 JSON"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5), app.debugDescription)
        resume.tap()
        assertSourceDraftValue(app, sha: sha, bytes: bytes)
    }

    private func assertSourceDraftValue(_ app: XCUIApplication, sha: String, bytes: Int) {
        let draft = app.textViews["online-source-draft"]
        XCTAssertTrue(draft.waitForExistence(timeout: 10), app.debugDescription)
        let value = draft.value as? String ?? ""
        XCTAssertEqual(value.utf8.count, bytes, "The entire real source draft must remain available, not only its first visible lines.")
        XCTAssertEqual(SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined(), sha,
                       "Closing, cancelling and cold startup must preserve the exact original UTF-8 draft.")
    }

    private func closePreservedSourceDraft(_ app: XCUIApplication) {
        let close = app.buttons["保留草稿并关闭"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), app.debugDescription)
        close.tap()
        waitFor(app.textViews["online-source-draft"], timeout: 5, message: "Normal close must leave source management") { !$0.exists }
    }

    private func leaveExistingSourceManagement(_ app: XCUIApplication) {
        let search = app.buttons["online-close-sources"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), app.debugDescription)
        search.tap()
        let close = app.buttons["online-close-workspace"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), app.debugDescription)
        close.tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 10), app.debugDescription)
    }

    /// Requires the byte-bound, real Reader-real-sources.json package already
    /// provisioned in this App's Documents. All candidates and body text come
    /// from actual Core requests to its sources; there is no fixture fallback.
    func testRealSourceFileSearchAdmissionReadingReturnAndColdShelfReopen() throws {
        let app = XCUIApplication()
        app.launch()
        let shelfMenu = app.buttons["更多书架操作"]
        XCTAssertTrue(shelfMenu.waitForExistence(timeout: 20), app.debugDescription)
        shelfMenu.tap()
        let online = app.buttons["搜索与书源"]
        XCTAssertTrue(online.waitForExistence(timeout: 5), app.debugDescription)
        online.tap()
        let openSources = app.buttons["online-open-sources"]
        XCTAssertTrue(openSources.waitForExistence(timeout: 10), app.debugDescription)
        openSources.tap()
        let sourceFile = app.buttons["online-source-file"]
        XCTAssertTrue(sourceFile.waitForExistence(timeout: 10), app.debugDescription)
        sourceFile.tap()
        selectProvisionedSourcePackage(in: app)

        let save = app.buttons["online-source-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 15), app.debugDescription)
        let draft = app.textViews["online-source-draft"]
        XCTAssertTrue(draft.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse((draft.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       "The actual system-picked source package must populate the editor")
        waitFor(save, timeout: 10, message: "The imported package must be saveable") { $0.exists && $0.isEnabled && $0.isHittable }
        save.tap()
        waitFor(save, timeout: 90, message: "Actual Core source import must finish; an open editor is not a saved source") { !$0.exists }
        let storedSource = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-source:")).firstMatch
        XCTAssertTrue(storedSource.waitForExistence(timeout: 15), app.debugDescription)
        let closeSources = app.buttons["online-close-sources"]
        XCTAssertTrue(closeSources.waitForExistence(timeout: 5), app.debugDescription)
        closeSources.tap()

        let query = app.textFields["online-search-query"]
        XCTAssertTrue(query.waitForExistence(timeout: 10), app.debugDescription)
        query.tap()
        query.typeText("剑来")
        let search = app.buttons["online-search-submit"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), app.debugDescription)
        search.tap()
        let candidate = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-result:")).firstMatch
        XCTAssertTrue(candidate.waitForExistence(timeout: 180), "A real source must return a candidate. No generated result is accepted.\n" + app.debugDescription)
        let candidateID = String(candidate.identifier.dropFirst("online-result:".count))
        XCTAssertFalse(candidateID.isEmpty)
        let originalResultIdentifier = candidate.identifier
        candidate.tap()
        let selected = app.staticTexts["online-selected:" + candidateID]
        XCTAssertTrue(selected.waitForExistence(timeout: 10), app.debugDescription)
        let detailBook = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-detail-book:")).firstMatch
        XCTAssertTrue(detailBook.waitForExistence(timeout: 120), "The selected real source must provide the actual detail and catalog.\n" + app.debugDescription)
        let bookID = String(detailBook.identifier.dropFirst("online-detail-book:".count))
        XCTAssertFalse(bookID.isEmpty)
        XCTAssertTrue(candidateID.hasSuffix("|" + bookID), "Detail must remain bound to the selected candidate's exact book")
        let shelfIdentifier = "book-" + bookID
        let identity = XCTAttachment(string: "source package: Reader-real-sources.json\nquery: 剑来\ncandidate: \(candidateID)\nshelf identifier: \(shelfIdentifier)")
        identity.name = "real-online-selected-identity"; identity.lifetime = .keepAlways; add(identity)

        let addAndRead = app.buttons["online-add-and-read"]
        XCTAssertTrue(addAndRead.waitForExistence(timeout: 10), app.debugDescription)
        waitFor(addAndRead, timeout: 15, message: "The real detail must permit its original admission") { $0.exists && $0.isEnabled }
        for _ in 0..<8 {
            if addAndRead.isHittable { break }
            // The admission action is above the chapter list. If the native
            // scroll view restores a prior offset, reveal that action by
            // moving toward the top instead of pushing it farther away.
            app.scrollViews["online-detail-scroll"].swipeDown()
        }
        if addAndRead.isHittable {
            addAndRead.tap()
        } else {
            // A long native catalog can make XCTest report a visible enabled
            // control as not hittable even though its screen coordinate still
            // receives the real touch. Exercise that same visible control
            // instead of turning a UIAutomation hit-test quirk into a false
            // online-flow failure.
            addAndRead.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        let body = app.textViews["reading-body"]
        assertNativeBody(body, in: app, timeout: 180)
        keepScreenshot(app, name: "real-online-first-reading")
        leaveReader(body, in: app)
        XCTAssertTrue(selected.waitForExistence(timeout: 20), "Leaving reading must restore the same selected detail.\n" + app.debugDescription)
        XCTAssertEqual(selected.identifier, "online-selected:" + candidateID)
        XCTAssertTrue(app.staticTexts["online-detail-book:" + bookID].exists)
        let backSearch = app.buttons["online-back-search"]
        XCTAssertTrue(backSearch.waitForExistence(timeout: 10), app.debugDescription)
        backSearch.tap()
        XCTAssertTrue(query.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(query.value as? String, "剑来")
        let retainedCandidate = app.buttons[originalResultIdentifier]
        XCTAssertTrue(retainedCandidate.waitForExistence(timeout: 15), "The same real candidate identity must remain in the original search")
        XCTAssertEqual(retainedCandidate.identifier, originalResultIdentifier)
        keepScreenshot(app, name: "real-online-returned-search")

        let closeOnline = app.buttons["online-close-workspace"]
        XCTAssertTrue(closeOnline.waitForExistence(timeout: 5), app.debugDescription)
        closeOnline.tap()
        let shelfBook = app.buttons[shelfIdentifier]
        XCTAssertTrue(shelfBook.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier == %@", shelfIdentifier)).count, 1,
                       "The exact shelf identifier must be unambiguous")
        // Termination follows the normal reader exit/save barrier above.
        // No app data, sources, cache, or shelf entries are cleared here.
        app.terminate()
        app.launch()
        XCTAssertTrue(shelfBook.waitForExistence(timeout: 25), "Cold startup must retain the actual admitted shelf book.\n" + app.debugDescription)
        XCTAssertEqual(shelfBook.identifier, shelfIdentifier)
        shelfBook.tap()
        assertNativeBody(body, in: app, timeout: 120)
        keepScreenshot(app, name: "real-online-cold-shelf-reading")
        leaveReader(body, in: app)
        XCTAssertTrue(shelfBook.waitForExistence(timeout: 20), app.debugDescription)
    }

    private func selectProvisionedSourcePackage(in app: XCUIApplication) {
        // Use only the system browser's App Documents location. Locale aliases
        // below identify native controls, never alternative source inputs.
        if !app.navigationBars["Reader"].waitForExistence(timeout: 3) {
            let browse = firstExistingButton(in: app, labels: ["浏览", "Browse"], timeout: 3)
            if let browse { browse.tap() }
            let deviceNames = ["我的 iPhone", "我的iPhone", "On My iPhone", "我的 iPad", "我的iPad", "On My iPad"]
            if !deviceNames.contains(where: { app.navigationBars[$0].exists }) {
                let device = app.cells.containing(NSPredicate(format: "label IN %@", deviceNames)).firstMatch
                XCTAssertTrue(device.waitForExistence(timeout: 15), "Open the actual on-device Documents browser.\n" + app.debugDescription)
                device.tap()
            }
            let folder = app.cells.containing(.staticText, identifier: "Reader").firstMatch
            XCTAssertTrue(folder.waitForExistence(timeout: 10), "The provisioned Reader Documents folder is required.\n" + app.debugDescription)
            folder.tap()
        }
        let file = app.cells.containing(NSPredicate(format: "label == %@ OR label == %@", "Reader-real-sources.json", "Reader-real-sources")).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 15), "Missing provisioned Reader-real-sources.json is FAIL; never paste or generate a replacement.\n" + app.debugDescription)
        file.tap()
        if let open = firstExistingButton(in: app, labels: ["打开", "Open"], timeout: 2) { open.tap() }
    }

    private func assertNativeBody(_ body: XCUIElement, in app: XCUIApplication, timeout: TimeInterval) {
        XCTAssertTrue(body.waitForExistence(timeout: timeout), "Actual admitted native body is required.\n" + app.debugDescription)
        waitFor(body, timeout: 15, message: "The native reading body must be visible and contain actual nonempty text") { element in
            guard element.exists, element.isHittable, let value = element.value as? String else { return false }
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !text.isEmpty && text != "小说正文"
        }
    }

    private func leaveReader(_ body: XCUIElement, in app: XCUIApplication) {
        let leave = app.buttons["leave-reader"]
        if !leave.exists || !leave.isHittable { body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap() }
        waitFor(leave, timeout: 10, message: "The existing native reading controls must expose the normal exit") { $0.exists && $0.isHittable }
        leave.tap()
    }

    private func firstExistingButton(in app: XCUIApplication, labels: [String], timeout: TimeInterval) -> XCUIElement? {
        for label in labels {
            let button = app.buttons[label].firstMatch
            if button.waitForExistence(timeout: timeout) { return button }
        }
        return nil
    }

    private func waitFor(_ element: XCUIElement, timeout: TimeInterval, message: String,
                         predicate: @escaping (XCUIElement) -> Bool) {
        let condition = NSPredicate { object, _ in
            guard let element = object as? XCUIElement else { return false }
            return predicate(element)
        }
        let expected = XCTNSPredicateExpectation(predicate: condition, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: timeout), .completed, message)
    }

    private func keepScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    /// Real existing inputs only. No source save/import, credential write,
    /// admission, download, source edit or draft replacement is submitted.
    func testExistingRealSourceDraftValidationExportFileReturnAndDiagnosticPreserveOriginalSources() throws {
        let environment = ProcessInfo.processInfo.environment
        let expectedSHA = try XCTUnwrap(environment["READER_SOURCE_DRAFT_EXPECTED_SHA256"])
        let expectedBytes = try XCTUnwrap(Int(environment["READER_SOURCE_DRAFT_EXPECTED_BYTES"] ?? ""))
        try sourceToolsRequire(expectedSHA == "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322" && expectedBytes == 5606,
                               "Require the existing complete real two-source package; no substitute draft", app: nil)
        let app = XCUIApplication(); app.launch()
        openExistingSourceManagement(app)
        let originalSources = try sourceToolsSourceLabels(app)
        try sourceToolsRequire(originalSources.count == 3 && originalSources["online-source:https://dushu.baidu.com/"] == "百度小说"
                               && originalSources["online-source:https://m.idejian.com"] == "得间小说",
                               "Use the actual saved three-source library, preserving its third source", app: app)
        assertPreservedSourceDraft(app, sha: expectedSHA, bytes: expectedBytes)
        let validation = app.buttons.matching(NSPredicate(format: "label == %@", "校验"))
        try sourceToolsRequire(validation.count == 1 && validation.element.isHittable && validation.element.isEnabled,
                               "Use the existing explicit Core validation action", app: app)
        validation.element.tap()
        try sourceToolsWait("Both real definitions must return the actual unsaved Core validation result", timeout: 75) {
            app.staticTexts["百度小说 · 结构校验通过，尚未保存"].exists && app.staticTexts["得间小说 · 结构校验通过，尚未保存"].exists
                && !app.staticTexts["正在校验"].exists
        }
        assertSourceDraftValue(app, sha: expectedSHA, bytes: expectedBytes)
        keepScreenshot(app, name: "source-tools-actual-two-definition-explicit-validation")
        closePreservedSourceDraft(app)
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalSources, "Validation must not save or replace sources", app: app)

        let fileBase = "Reader-Source-Tools-" + UUID().uuidString.lowercased()
        let fileFacts: [String: Any] = ["ownedFilename": fileBase + ".json", "originalDraftSHA256": expectedSHA,
            "originalDraftUTF8Bytes": expectedBytes, "actualSourceLabels": originalSources,
            "scope": "Normal App source.export through Files only. Root separately verifies actual complete exported UTF8/schema/each current source definition against fresh original Core rows. No source save or replacement is authorized."]
        let binding = XCTAttachment(data: try JSONSerialization.data(withJSONObject: fileFacts, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        binding.name = "source-tools-owned-export-file-and-original-source-binding"; binding.lifetime = .keepAlways; add(binding)
        let export = app.buttons.matching(NSPredicate(format: "label == %@", "导出"))
        try sourceToolsRequire(export.count == 1 && export.element.isHittable && export.element.isEnabled,
                               "Use one actual source export action; no background file creation", app: app)
        export.element.tap()
        let names = app.textFields.matching(identifier: "DOCPicker.filenameTextField")
        let saveLabels = ["导出", "存储", "保存", "移动", "Export", "Save", "Move"]
        try sourceToolsWait("Wait for actual native export presentation before Files navigation", timeout: 30) {
            app.navigationBars.firstMatch.exists && (names.count == 1 || app.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", saveLabels + ["取消", "Cancel"])).allElementsBoundByIndex.contains(where: \.isHittable))
        }
        try sourceToolsEnterReaderDocuments(app)
        try sourceToolsWait("Require one native filename control", timeout: 15) { names.count == 1 && names.element.isHittable }
        let initialName = try XCTUnwrap(names.element.value as? String)
        try sourceToolsRequire(["Reader-书源", "Reader-书源.json"].contains(initialName), "Do not rename an unrelated native document", app: app)
        let conflicts = app.cells.containing(NSPredicate(format: "label == %@ OR label == %@", fileBase, fileBase + ".json"))
        try sourceToolsRequire(conflicts.count == 0, "Do not overwrite an existing Files entry", app: app)
        try sourceToolsReplaceNativeFilename(names, with: fileBase, app: app)
        let saves = app.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", saveLabels))
            .allElementsBoundByIndex.filter { $0.isHittable && $0.isEnabled }
        try sourceToolsRequire(saves.count == 1 && names.count == 1 && [fileBase, fileBase + ".json"].contains(names.element.value as? String ?? ""),
                               "Require the entire UUID-owned name before the one native save", app: app)
        keepScreenshot(app, name: "source-tools-actual-owned-filename-before-only-files-save")
        saves[0].tap()
        try sourceToolsWait("Return from actual native export without replacing a file", timeout: 30) {
            (names.count == 0 && app.buttons["online-source-file"].isHittable) || app.alerts.firstMatch.exists
        }
        try sourceToolsRequire(!app.alerts.firstMatch.exists && app.buttons["online-source-file"].isHittable,
                               "Never accept a file-overwrite or unexpected save confirmation", app: app)
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalSources, "Export must not change source facts", app: app)
        app.buttons["online-source-file"].tap()
        try sourceToolsEnterReaderDocuments(app)
        let files = app.cells.containing(NSPredicate(format: "label == %@ OR label == %@", fileBase, fileBase + ".json"))
        try sourceToolsWait("Select only the same actual App-exported file", timeout: 15) { files.count == 1 && files.element.isHittable }
        keepScreenshot(app, name: "source-tools-same-actual-exported-file-in-native-picker")
        files.element.tap()
        let opens = app.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", ["打开", "Open"]))
            .allElementsBoundByIndex.filter { $0.isHittable && $0.isEnabled }
        if opens.count == 1 { opens[0].tap() }
        let replacement = app.alerts["替换当前书源草稿？"]
        try sourceToolsRequire(replacement.waitForExistence(timeout: 15),
                               "The three-source export must not silently overwrite the existing two-source draft", app: app)
        let cancel = replacement.buttons["取消"]
        try sourceToolsRequire(cancel.isHittable, "Cancel replacement, never apply exported text to the old draft", app: app)
        keepScreenshot(app, name: "source-tools-exported-input-original-draft-replacement-cancel")
        cancel.tap()
        try sourceToolsWait("Only the original replacement confirmation may dismiss", timeout: 5) { !replacement.exists }
        assertPreservedSourceDraft(app, sha: expectedSHA, bytes: expectedBytes)
        closePreservedSourceDraft(app)
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalSources, "Picker return and cancellation must not import sources", app: app)

        let sourceID = "https://dushu.baidu.com/"
        let detector = try sourceToolsDiagnosticButton(sourceID: sourceID, app: app)
        detector.tap()
        var actualReport: [String: Any]?
        try sourceToolsWait("Require this actual diagnostic terminal, not just its entry/loading label", timeout: 80) {
            actualReport = self.sourceToolsDiagnosticReport(sourceID: sourceID, app: app)
            return actualReport != nil
        }
        let result = try XCTUnwrap(actualReport)
        let rows = try XCTUnwrap(result["results"] as? [[String: Any]])
        try sourceToolsRequire(rows.count == 1 && rows[0]["sourceId"] as? String == sourceID, "Exact selected diagnostic source", app: app)
        let row = rows[0], report = try XCTUnwrap(row["report"] as? [String: Any])
        let trace = try XCTUnwrap(result["traceId"] as? String), options = try XCTUnwrap(report["executionOptions"] as? [String: Any])
        let steps = try XCTUnwrap(report["steps"] as? [[String: Any]])
        let levels = ["L1", "L2", "L3", "L4", "L5"]
        try sourceToolsRequire(!trace.isEmpty && report["traceId"] as? String == trace && report["version"] as? Int == 2
                               && options["timeoutMs"] as? Int == 60000 && steps.map { $0["level"] as? String ?? "" } == levels
                               && steps.allSatisfy { $0["requested"] as? Bool == true }, "Full original v2 execution report", app: app)
        try sourceToolsRequire(steps.first?["executed"] as? Bool == true && steps.first?["status"] as? String == "pass",
                               "The existing original source must actually load at L1", app: app)
        let statuses = Set(["pass", "fail", "not_requested", "not_supported", "blocked", "cancelled"])
        try sourceToolsRequire(steps.allSatisfy { statuses.contains($0["status"] as? String ?? "") }, "Use actual Core diagnostic statuses", app: app)
        let passed = try XCTUnwrap(row["levelsPassed"] as? [String])
        try sourceToolsRequire(passed == steps.filter { $0["status"] as? String == "pass" }.map { $0["level"] as? String ?? "" },
                               "Per-level original outcomes must agree", app: app)
        let available = try XCTUnwrap(row["available"] as? Bool)
        if available {
            try sourceToolsRequire(passed == levels && row["failureReason"] == nil, "Healthy means every requested level truly passed", app: app)
        } else {
            try sourceToolsRequire(!(row["failureReason"] as? String ?? "").isEmpty && passed != levels,
                                   "A genuine negative diagnosis must expose its actual failure; never label it healthy", app: app)
        }
        let diagnostic = XCTAttachment(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        diagnostic.name = "source-tools-actual-original-diagnostic-v2-terminal"; diagnostic.lifetime = .keepAlways; add(diagnostic)
        // Expose the actual returned feedback through this existing ScrollView.
        for _ in 0..<8 {
            if app.staticTexts.allElementsBoundByIndex.contains(where: { text in
                text.isHittable && (text.label.contains(trace)) && text.frame.intersects(app.frame)
            }) { break }
            app.scrollViews["online-source-scroll"].swipeUp()
        }
        try sourceToolsRequire(app.staticTexts.allElementsBoundByIndex.contains { $0.isHittable && $0.label.contains(trace) },
                               "The actual report/failure must be visibly reachable", app: app)
        keepScreenshot(app, name: available ? "source-tools-diagnostic-actual-all-levels-passed" : "source-tools-diagnostic-actual-failure-visible-not-healthy")
        for _ in 0..<8 {
            if app.buttons["导入 JSON"].isHittable { break }
            app.scrollViews["online-source-scroll"].swipeDown()
        }
        try sourceToolsRequire(app.buttons["导入 JSON"].isHittable, "Return to the original draft entry through the actual source ScrollView", app: app)
        assertPreservedSourceDraft(app, sha: expectedSHA, bytes: expectedBytes)
        closePreservedSourceDraft(app)
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalSources, "Diagnostic must retain every original source identity/name", app: app)
        leaveExistingSourceManagement(app)
    }

    private enum SourceToolsFailure: Error { case prerequisite }
    private func sourceToolsRequire(_ valid: Bool, _ message: String, app: XCUIApplication?, file: StaticString = #filePath, line: UInt = #line) throws {
        guard valid else {
            if let app {
                keepScreenshot(app, name: "source-tools-prerequisite-or-consumer-failure")
                let attachment = XCTAttachment(string: app.debugDescription); attachment.name = "source-tools-actual-failure-AX"; attachment.lifetime = .keepAlways; add(attachment)
            }
            XCTFail(message, file: file, line: line); throw SourceToolsFailure.prerequisite
        }
    }
    private func sourceToolsWait(_ message: String, timeout: TimeInterval, _ condition: @escaping () -> Bool) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        try sourceToolsRequire(XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed, message, app: XCUIApplication())
    }
    private func sourceToolsSourceLabels(_ app: XCUIApplication) throws -> [String: String] {
        let rows = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-source:")).allElementsBoundByIndex
        try sourceToolsRequire(!rows.isEmpty && Set(rows.map(\.identifier)).count == rows.count, "Complete unambiguous existing source identities", app: app)
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.identifier, $0.label) })
    }
    private func sourceToolsDiagnosticReport(sourceID: String, app: XCUIApplication) -> [String: Any]? {
        let reports = app.staticTexts.allElementsBoundByIndex.compactMap { text -> [String: Any]? in
            guard text.label.hasPrefix("{"), let data = text.label.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rows = object["results"] as? [[String: Any]], rows.count == 1,
                  rows[0]["sourceId"] as? String == sourceID, object["traceId"] as? String != nil else { return nil }
            return object
        }
        return reports.count == 1 ? reports[0] : nil
    }
    private func sourceToolsDiagnosticButton(sourceID: String, app: XCUIApplication) throws -> XCUIElement {
        let scroll = app.scrollViews["online-source-scroll"]
        for _ in 0..<8 {
            let header = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "online-source:" + sourceID))
            if header.count == 1 && header.element.isHittable {
                let lower = header.element.frame.maxY
                let nextHeader = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-source:"))
                    .allElementsBoundByIndex.map(\.frame).filter { $0.minY > lower }.map(\.minY).min() ?? scroll.frame.maxY
                let buttons = scroll.buttons.matching(NSPredicate(format: "label == %@", "检测")).allElementsBoundByIndex
                    .filter { $0.isHittable && $0.frame.midY > lower && $0.frame.midY < min(nextHeader, scroll.frame.maxY) }
                if buttons.count == 1 { return buttons[0] }
            }
            scroll.swipeUp()
        }
        try sourceToolsRequire(false, "One actual diagnostic button must belong to the selected source's visible row", app: app)
        throw SourceToolsFailure.prerequisite
    }

    private func sourceToolsEnterReaderDocuments(_ app: XCUIApplication) throws {
        // Navigate only actual native Files locations. A missing filename or
        // location fails; there is no shell path, injected file or URL route.
        let localNames = ["我的 iPhone", "我的iPhone", "我的 iPad", "我的iPad", "On My iPhone", "On My iPad"]
        var visited = Set<String>()
        for _ in 0..<6 {
            if sourceToolsReaderDocumentsVisible(app) { return }
            let reader = app.cells.matching(NSPredicate(format: "identifier == 'Reader, Container' OR label BEGINSWITH 'Reader,'"))
            if let cell = reader.allElementsBoundByIndex.filter(\.isHittable).sourceToolsOnly {
                cell.tap()
                let arrival = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    self.sourceToolsReaderDocumentsVisible(app)
                }, object: nil)
                let arrived = XCTWaiter.wait(for: [arrival], timeout: 10) == .completed
                if !arrived {
                    keepScreenshot(app, name: "source-tools-native-reader-folder-not-recognized")
                }
                try sourceToolsRequire(arrived, "Enter the actual Reader Documents folder", app: app)
                keepScreenshot(app, name: "source-tools-actual-native-reader-folder")
                return
            }
            let local = app.cells.containing(NSPredicate(format: "label IN %@", localNames))
                .allElementsBoundByIndex.filter(\.isHittable)
            if let cell = local.sourceToolsOnly, visited.insert("local:" + cell.label).inserted { cell.tap(); continue }
            let browse = app.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", ["浏览", "Browse"])).allElementsBoundByIndex
                + app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["浏览", "Browse"])).allElementsBoundByIndex
            if let button = browse.filter(\.isHittable).first, visited.insert("browse:" + button.identifier + button.label).inserted {
                button.tap(); continue
            }
            let backToLocal = app.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", localNames))
                .allElementsBoundByIndex.filter(\.isHittable)
            if let button = backToLocal.sourceToolsOnly, visited.insert("back:" + button.label).inserted { button.tap(); continue }
            break
        }
        keepScreenshot(app, name: "source-tools-native-Files-location-not-available")
        try sourceToolsRequire(false, "The normal Files sheet must expose the actual local Reader folder; do not write or provision a file behind the UI", app: app)
    }
    private func sourceToolsReaderDocumentsVisible(_ app: XCUIApplication) -> Bool {
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
    private func sourceToolsReplaceNativeFilename(_ fields: XCUIElementQuery, with filename: String, app: XCUIApplication) throws {
        try sourceToolsRequire(fields.count == 1 && fields.element.isHittable && fields.element.isEnabled,
                    "The native identifier must resolve one editable exported filename", app: app)
        let originalValue = try XCTUnwrap(fields.element.value as? String)
        try sourceToolsRequire(originalValue.count > 1, "The original filename must contain more than one character", app: app)
        fields.element.tap()
        try sourceToolsSettleNativeFilenameKeyboard(fields, app: app)
        try sourceToolsRequire(fields.count == 1 && (fields.element.value as? String) == originalValue,
                    "Keyboard setup must preserve the original exported filename", app: app)
        // Use one native Delete and one UUID input. The complete resulting
        // value, rather than the empty field's AX representation, gates Save.
        fields.element.typeText(XCUIKeyboardKey.delete.rawValue)
        try sourceToolsRequire(fields.count == 1 && (fields.element.value as? String) == "", "The one native Delete must leave the filename actually empty before typing", app: app)
        fields.element.typeText(filename)
        let actualValue = fields.count == 1 ? (fields.element.value as? String) : nil
        guard actualValue == filename || actualValue == filename + ".json" else {
            keepScreenshot(app, name: "source-tools-native-owned-filename-mismatch-after-input")
            try sourceToolsRequire(false, "The actual system filename must contain only the new UUID-owned name", app: app)
            return
        }
    }
    private func sourceToolsSettleNativeFilenameKeyboard(_ fields: XCUIElementQuery, app: XCUIApplication) throws {
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
            guard let text = visibleGuide().sourceToolsOnly, let button = buttons.sourceToolsOnly,
                  button.frame.minY >= text.frame.maxY else { return false }
            action = button; return true
        }, object: nil)
        if XCTWaiter.wait(for: [actionable], timeout: 5) != .completed {
            keepScreenshot(app, name: "source-tools-native-quickpath-not-actionable")
            try sourceToolsRequire(false, "The exact QuickPath explanation must expose one visible enabled Continue", app: app)
        }
        keepScreenshot(app, name: "source-tools-observed-native-quickpath-guide")
        try XCTUnwrap(action).tap()
        resetStability()
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !guide.firstMatch.exists && inputIsStable()
        }, object: nil)
        if XCTWaiter.wait(for: [settled], timeout: 10) != .completed {
            keepScreenshot(app, name: "source-tools-native-filename-keyboard-not-settled")
            try sourceToolsRequire(false, "QuickPath must dismiss and the same filename/keyboard must settle before editing", app: app)
        }
    }

    /// The only replay input is Root's original 10609-byte real HTTP capture.
    /// Missing nested sourceId exercises the production current-source binding.
    func testActualCapturedSourceDebugL1L2ReplayAndCloseReopenPreserveOriginalSourceFacts() throws {
        let environment = ProcessInfo.processInfo.environment
        let inputPath = try XCTUnwrap(environment["READER_SOURCE_DEBUG_REAL_RESPONSES_FILE"])
        let expectedSHA = try XCTUnwrap(environment["READER_SOURCE_DEBUG_REAL_RESPONSES_SHA256"])
        try sourceToolsRequire(inputPath.hasPrefix("/") && expectedSHA == "f7bc4ad5b7a28101e81b48d1d321a32e31346505aab85c02efd2509ba3c16d41",
                               "Only the Root-bound original real response file is admitted", app: nil)
        let raw = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        try sourceToolsRequire(raw.count == 10609 && SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined() == expectedSHA,
                               "The real capture bytes must match before any UI edit", app: nil)
        let originalInput = try XCTUnwrap(String(data: raw, encoding: .utf8))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        try sourceToolsRequire(Set(payload.keys) == ["searchResponse"] && !(payload["searchResponse"] as? String ?? "").isEmpty,
                               "This actual small capture supplies L2 only, without nested sourceId or invented later layers", app: nil)
        let sourceID = "https://m.idejian.com", app = XCUIApplication()
        app.launch(); openExistingSourceManagement(app)
        let originalSources = try sourceToolsSourceLabels(app)
        try sourceToolsRequire(originalSources.count == 3 && originalSources["online-source:" + sourceID] == "得间小说",
                               "The real captured response belongs to the existing saved idejian source", app: app)
        try sourceToolsDebugButton(sourceID: sourceID, app: app).tap()
        let key = app.textFields["source-debug-key"], responses = app.textViews["source-debug-responses"]
        let run = app.buttons["source-debug-run"], close = app.buttons["source-debug-close"]
        let result = app.staticTexts["source-debug-result"]
        try sourceToolsRequire(key.waitForExistence(timeout: 10) && responses.exists && run.exists && close.exists,
                               "Require the actual production debug editor", app: app)
        let keyBefore = key.value as? String ?? ""
        try sourceToolsRequire((keyBefore.isEmpty || keyBefore == key.placeholderValue) && (responses.value as? String) == "{}"
                               && run.label == "运行" && !result.exists,
                               "Never overwrite an existing user debug key/response draft or pending run", app: app)
        key.tap(); key.typeText("剑来")
        try sourceToolsRequire(key.value as? String == "剑来", "Observe the actual captured search key", app: app)
        // The observed default occupies only the first line. A center tap in
        // this large TextEditor placed its caret before {}, so backspace had
        // no effect. Tap the visible first line after those two characters.
        try sourceToolsRequire(responses.isEnabled && responses.isHittable && responses.frame.height > 24
                               && (responses.value as? String) == "{}",
                               "Only the still-observed two-character default may be cleared", app: app)
        let defaultLinePoint = CGPoint(x: responses.frame.midX, y: responses.frame.minY + 12)
        try sourceToolsRequire(app.frame.contains(defaultLinePoint), "The actual default first line must be visible", app: app)
        let caret = XCTAttachment(string: "textViewFrame=\(responses.frame)\nnormalFirstLineTouch=\(defaultLinePoint)\nobservedDefaultUTF8Bytes=2")
        caret.name = "source-debug-default-first-line-caret-before-clear"; caret.lifetime = .keepAlways; add(caret)
        responses.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 12)).tap()
        keepScreenshot(app, name: "source-debug-actual-default-first-line-caret-before-delete")
        responses.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2))
        try sourceToolsRequire((responses.value as? String) == "", "Only the observed default two-character JSON may be cleared", app: app)
        responses.typeText(originalInput) // One normal input; no clipboard, route or App-state injection.
        try sourceToolsRequire((responses.value as? String) == originalInput, "Require the entire exact actual HTTP replay JSON after native input", app: app)
        let input = XCTAttachment(string: "sourceID=\(sourceID)\nkey=剑来\ninputUTF8Bytes=\(raw.count)\ninputSHA256=\(expectedSHA)\nOriginal capture only searchResponse; omitted inner sourceId must be bound by Host, never inserted into the user's editor. L3-L5 are explicitly not supplied.")
        input.name = "source-debug-real-L2-input-binding"; input.lifetime = .keepAlways; add(input)
        keepScreenshot(app, name: "source-debug-actual-real-L2-input-before-single-run")
        try sourceToolsRequire(run.isHittable && run.isEnabled && run.label == "运行", "One actual replay action must be available", app: app)
        run.tap()
        try sourceToolsWait("Require actual Core replay terminal or visible failure, not just the debug entry", timeout: 75) {
            result.exists || app.descendants(matching: .any).matching(identifier: "source-debug-failure").firstMatch.exists
        }
        try sourceToolsRequire(result.exists && run.label == "运行", "An actual replay error is retained as FAIL, never substituted by another input or run", app: app)
        let terminalText = result.label
        let terminal = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(terminalText.utf8)) as? [String: Any])
        let logs = try XCTUnwrap(terminal["logs"] as? [[String: Any]])
        try sourceToolsRequire(terminal["finalState"] as? Int == 1000 && logs.contains { $0["step"] as? String == "import" && ($0["msg"] as? String ?? "").contains(sourceID) }
                               && logs.contains { $0["step"] as? String == "import" && $0["state"] as? Int == 10 }
                               && logs.contains { $0["step"] as? String == "search" && $0["state"] as? Int == 1 && ($0["extractedCount"] as? Int ?? 0) > 0 }
                               && !logs.contains { $0["state"] as? Int == -1 },
                               "Only this real source's actually extracted L1/L2 may pass", app: app)
        for (step, state) in [("detail", 30), ("toc", 30), ("content", 40)] {
            let entries = logs.filter { $0["step"] as? String == step }
            try sourceToolsRequire(entries.contains { $0["state"] as? Int == state && ($0["msg"] as? String ?? "").contains("跳过") && ($0["msg"] as? String ?? "").contains("未验证") }
                                   && !entries.contains { ($0["extractedCount"] as? Int ?? 0) > 0 || $0["state"] as? Int == 1 },
                                   "Unsupplied \(step) must be explicitly skipped, never a later-level success claim", app: app)
        }
        let diagnostic = XCTAttachment(data: try JSONSerialization.data(withJSONObject: terminal, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        diagnostic.name = "source-debug-actual-L1-L2-and-explicit-L3-L5-skips"; diagnostic.lifetime = .keepAlways; add(diagnostic)
        try sourceToolsRequire((responses.value as? String) == originalInput, "Host identity binding must not rewrite the user's original JSON", app: app)
        keepScreenshot(app, name: "source-debug-real-L2-terminal-not-full-L5-acceptance")
        try sourceToolsRequire(close.isHittable, "Close through the existing debug host", app: app); close.tap()
        try sourceToolsWait("Normal debug closure must reveal management", timeout: 10) { !app.buttons["source-debug-close"].exists && app.buttons["online-source-file"].exists }
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalSources, "Replay must not change original source facts", app: app)
        try sourceToolsDebugButton(sourceID: sourceID, app: app).tap()
        try sourceToolsRequire(key.waitForExistence(timeout: 10) && (key.value as? String) == "剑来"
                               && (responses.value as? String) == originalInput && run.label == "运行" && !result.exists,
                               "New presentation must restore the exact owned original draft without rerunning or publishing the old result", app: app)
        keepScreenshot(app, name: "source-debug-real-captured-draft-normally-reopened-without-rerun")
        close.tap()
        try sourceToolsWait("Second normal close returns to the original source host", timeout: 10) { !app.buttons["source-debug-close"].exists }
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalSources, "All source definitions remain represented by their original identities", app: app)
        leaveExistingSourceManagement(app)
    }

    private func sourceToolsDebugButton(sourceID: String, app: XCUIApplication) throws -> XCUIElement {
        let scroll = app.scrollViews["online-source-scroll"]
        for _ in 0..<8 {
            let header = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "online-source:" + sourceID))
            if header.count == 1 && header.element.isHittable {
                let lower = header.element.frame.maxY
                let nextHeader = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-source:"))
                    .allElementsBoundByIndex.map(\.frame).filter { $0.minY > lower }.map(\.minY).min() ?? scroll.frame.maxY
                let buttons = scroll.buttons.matching(NSPredicate(format: "label == %@", "调试")).allElementsBoundByIndex
                    .filter { $0.isHittable && $0.frame.midY > lower && $0.frame.midY < min(nextHeader, scroll.frame.maxY) }
                if buttons.count == 1 { return buttons[0] }
            }
            scroll.swipeUp()
        }
        try sourceToolsRequire(false, "One actual debug button must belong to the exact source's visible row", app: app)
        throw SourceToolsFailure.prerequisite
    }


    /// Uses the exact existing Large subscription captured in R33. Root binds
    /// its fresh absent-intent precondition before execution. This method never
    /// creates/edits/deletes a subscription, changes a toggle or applies sources.
    /// Real HTTP/admission failures stay FAIL; an empty diff is not a new release.
    func testExistingRealSubscriptionPreviewForegroundInvalidationAndExplicitRecheckPreserveOriginalState() throws {
        let subscriptionID = "1792571258468"
        let expectedName = "原生订阅-15781c89-a11c-4ad0-854e-64b66a9db637"
        let expectedURL = "https://shuyuan-api.yiove.com/import/book-source-collection/3d9f811b-0831-4203-9fcb-3e8020f8aa2d"
        let app = XCUIApplication(); app.launch()
        addTeardownBlock { self.subscriptionPreviewCloseOnlyKnownReadHosts(app) }
        openExistingSourceManagement(app)
        let originalSources = try sourceToolsSourceLabels(app)
        try sourceToolsRequire(!app.textViews["online-source-draft"].exists,
            "Do not open, replace or close an unknown source draft", app: app)
        let subscriptions = subscriptionPreviewButton("online-rule-subscriptions", app: app)
        try subscriptionPreviewReveal(subscriptions, app: app, scrollID: "online-source-scroll", towardTop: true)
        try sourceToolsRequire(subscriptions.isEnabled && subscriptions.isHittable, "Open only the existing subscription manager", app: app)
        subscriptions.tap()
        let addEntry = subscriptionPreviewButton("subscription-add", app: app)
        try sourceToolsRequire(addEntry.waitForExistence(timeout: 15), "Existing subscription list must open normally", app: app)
        let originalDraftEntryLabel = addEntry.label // Observe only; never open the draft.
        let name = subscriptionPreviewText("subscription:" + subscriptionID, app: app)
        let url = subscriptionPreviewText("subscription-url:" + subscriptionID, app: app)
        let check = subscriptionPreviewButton("subscription-check:" + subscriptionID, app: app)
        try subscriptionPreviewReveal(check, app: app, scrollID: "subscription-scroll", towardTop: true)
        try sourceToolsRequire(name.exists && name.label == expectedName && url.exists && url.label == expectedURL,
            "Require the entire original Core subscription identity and real saved URL; never create a replacement", app: app)
        try sourceToolsRequire(check.isEnabled && check.isHittable && !app.staticTexts["原操作待核对"].exists
            && !app.staticTexts["正在核对订阅操作"].exists && !app.textFields["subscription-url"].exists,
            "No unknown accepted operation or subscription editor may be touched", app: app)
        check.tap() // First explicit real fetch + Core preview; no apply.
        let apply = subscriptionPreviewButton("subscription-apply-selection", app: app)
        let invalid = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", "subscription-preview-invalid:" + subscriptionID)).firstMatch
        try subscriptionPreviewWaitForActualPlan(app, apply: apply, check: check, invalid: invalid, phase: "first explicit check")
        let originalApplyLabel = apply.label
        let selectedCount = try subscriptionPreviewSelectionCount(apply, app: app)
        let firstRow = try subscriptionPreviewObserveOneActualDifference(subscriptionID: subscriptionID,
            selectedCount: selectedCount, app: app)
        let firstFacts: [String: Any] = ["subscriptionID": subscriptionID, "subscriptionName": expectedName,
            "subscriptionURL": expectedURL, "applyLabel": originalApplyLabel, "selectedSafeCount": selectedCount,
            "actualObservedRow": firstRow, "draftEntryLabel": originalDraftEntryLabel,
            "scope": "Actual real URL preview only. No remote-version publication/update/apply claim; no toggle changes."]
        let firstAttachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: firstFacts, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        firstAttachment.name = "subscription-preview-actual-original-identity-selection-and-observed-row"
        firstAttachment.lifetime = .keepAlways; add(firstAttachment)
        keepScreenshot(app, name: "subscription-preview-real-first-diff")

        XCUIDevice.shared.press(.home)
        try sourceToolsWait("Observe actual background transition; do not substitute a delay", timeout: 10) {
            app.state == .runningBackground || app.state == .runningBackgroundSuspended
        }
        app.activate()
        try sourceToolsWait("The same App must return to the foreground", timeout: 15) { app.state == .runningForeground }
        // This production detail reports read-state invalidation only. It is
        // not a successful source-update receipt or remote publication claim.
        let invalidTitle = app.staticTexts.matching(NSPredicate(format: "label == %@", "差异需要重新检查")).firstMatch
        try sourceToolsWait("The actual page-state title must be rendered after foreground return", timeout: 30) {
            invalid.exists && invalidTitle.exists
        }
        try subscriptionPreviewReveal(invalidTitle, app: app, scrollID: "subscription-scroll", towardTop: true)
        try sourceToolsWait("Actual ReaderPageState must retain the stale preview until explicit recheck", timeout: 30) {
            invalid.exists && app.staticTexts["差异需要重新检查"].exists
                && app.staticTexts["订阅检查状态已变化，请重新检查差异。"].exists
                && apply.exists && apply.label == originalApplyLabel && !apply.isEnabled
        }
        try sourceToolsRequire(addEntry.label == originalDraftEntryLabel,
            "Scene transitions must not replace the untouched subscription draft entry", app: app)
        keepScreenshot(app, name: "subscription-preview-actual-read-state-requires-explicit-recheck")
        if let switchID = firstRow["switchIdentifier"] {
            let toggle = subscriptionPreviewSwitch(switchID, app: app)
            try subscriptionPreviewReveal(toggle, app: app, scrollID: "subscription-scroll")
            try sourceToolsRequire(toggle.exists && !toggle.isEnabled && toggle.label == firstRow["switchLabel"]
                && (toggle.value as? String) == firstRow["switchValue"],
                "The original safe source toggle must retain its exact selection and become disabled", app: app)
        }
        if let rowID = firstRow["kindIdentifier"] {
            let row = subscriptionPreviewText(rowID, app: app)
            try subscriptionPreviewReveal(row, app: app, scrollID: "subscription-scroll")
            try sourceToolsRequire(row.label == firstRow["kindLabel"], "The same actual old difference must remain visible", app: app)
        } else {
            try sourceToolsRequire(firstRow["actualEmptyDiff"] == "true" && app.staticTexts["订阅没有变更"].exists,
                "A real empty preview must remain empty; it is not update/publication evidence", app: app)
        }
        try sourceToolsRequire(apply.label == originalApplyLabel && !apply.isEnabled,
            "No scene callback may replace the retained selection or enable Apply", app: app)
        keepScreenshot(app, name: "subscription-preview-old-actual-diff-and-selection-disabled")

        let retry = app.buttons.matching(NSPredicate(format: "label == %@", "重新检查"))
        try sourceToolsRequire(retry.count == 1, "Only the actual ReaderPageState recheck action may start the second check", app: app)
        try subscriptionPreviewReveal(retry.element, app: app, scrollID: "subscription-scroll", towardTop: true)
        try sourceToolsRequire(retry.element.isHittable && retry.element.isEnabled, "The normal explicit recheck must be available", app: app)
        retry.element.tap() // Second and final explicit fetch/preview; still no apply.
        try subscriptionPreviewWaitForActualPlan(app, apply: apply, check: check, invalid: invalid, phase: "explicit PageState recheck")
        let secondCount = try subscriptionPreviewSelectionCount(apply, app: app)
        try sourceToolsRequire(addEntry.label == originalDraftEntryLabel, "Explicit reads must retain the untouched draft entry", app: app)
        let finalFacts: [String: Any] = ["subscriptionID": subscriptionID, "subscriptionURL": expectedURL,
            "secondApplyLabel": apply.label, "secondSelectedSafeCount": secondCount,
            "safeToggleEvidence": firstRow["switchIdentifier"] == nil ? "not applicable: actual first preview has zero safe items" : "one actual source toggle retained and disabled",
            "normalUIActions": "open existing subscription; explicit check; Home; activate; explicit PageState recheck; normal exits",
            "remotePublicationVerified": false, "sourceApplyRequested": false, "businessMutationRequested": false]
        let finalAttachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: finalFacts, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        finalAttachment.name = "subscription-preview-real-explicit-recheck-scope-and-empty-safe-boundary"
        finalAttachment.lifetime = .keepAlways; add(finalAttachment)
        keepScreenshot(app, name: "subscription-preview-real-explicit-recheck-restored")
        let close = app.buttons.matching(NSPredicate(format: "label == %@", "关闭订阅管理"))
        try sourceToolsRequire(close.count == 1 && close.element.isHittable, "Exit through the same normal subscription host", app: app)
        close.element.tap()
        try sourceToolsRequire(subscriptions.waitForExistence(timeout: 15), "Normal close returns to the original source host", app: app)
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalSources,
            "The original sources must remain represented after the read-only journey", app: app)
        leaveExistingSourceManagement(app)
    }

    private func subscriptionPreviewWaitForActualPlan(_ app: XCUIApplication, apply: XCUIElement,
                                                      check: XCUIElement, invalid: XCUIElement, phase: String) throws {
        try sourceToolsWait("Actual remote subscription terminal: " + phase, timeout: 180) {
            (apply.exists && check.exists && check.isEnabled && !invalid.exists)
                || app.staticTexts["订阅检查未完成"].exists
        }
        try sourceToolsRequire(apply.exists && check.isEnabled && !invalid.exists
            && !app.staticTexts["订阅检查未完成"].exists && !app.staticTexts["正在检查订阅"].exists,
            "The actual URL fetch/encoding/admission/preview must succeed; failures are FAIL, without fallback: " + phase, app: app)
    }

    private func subscriptionPreviewSelectionCount(_ apply: XCUIElement, app: XCUIApplication) throws -> Int {
        let pieces = apply.label.split(separator: " ")
        try sourceToolsRequire(pieces.count == 3 && pieces.first == "应用所选" && pieces.last == "项",
            "Observe the production Apply label without replacing actual selection", app: app)
        let count = try XCTUnwrap(Int(pieces[1])); try sourceToolsRequire(count >= 0, "Actual selected item count", app: app)
        return count
    }

    private func subscriptionPreviewObserveOneActualDifference(subscriptionID: String, selectedCount: Int,
                                                               app: XCUIApplication) throws -> [String: String] {
        let changePrefix = "subscription-change:" + subscriptionID + ":"
        let kindPrefix = "subscription-change-kind:" + subscriptionID + ":"
        if selectedCount > 0 {
            let toggle = app.switches.matching(NSPredicate(format: "identifier BEGINSWITH %@", changePrefix)).firstMatch
            try subscriptionPreviewReveal(toggle, app: app, scrollID: "subscription-scroll")
            try sourceToolsRequire(toggle.isEnabled && (toggle.value as? String) == "1",
                "A fresh real preview must expose an actual selected safe item", app: app)
            let kindID = kindPrefix + String(toggle.identifier.dropFirst(changePrefix.count))
            let kind = subscriptionPreviewText(kindID, app: app)
            try sourceToolsRequire(kind.exists && ["新增", "可更新"].contains(kind.label), "Full original safe source identity and kind", app: app)
            return ["switchIdentifier": toggle.identifier, "switchLabel": toggle.label,
                "switchValue": try XCTUnwrap(toggle.value as? String), "kindIdentifier": kindID, "kindLabel": kind.label]
        }
        let empty = app.staticTexts["订阅没有变更"]
        let row = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", kindPrefix)).firstMatch
        if !empty.exists { try subscriptionPreviewReveal(row, app: app, scrollID: "subscription-scroll") }
        if row.exists { return ["kindIdentifier": row.identifier, "kindLabel": row.label] }
        try sourceToolsRequire(empty.exists, "Zero safe items must retain an actual unsafe/unchanged difference or the real empty state", app: app)
        return ["actualEmptyDiff": "true"]
    }

    // Full predicates preserve every source-URL byte beyond XCTest's subscript limit.
    private func subscriptionPreviewText(_ id: String, app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }
    private func subscriptionPreviewButton(_ id: String, app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }
    private func subscriptionPreviewSwitch(_ id: String, app: XCUIApplication) -> XCUIElement {
        app.switches.matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }
    private func subscriptionPreviewReveal(_ element: XCUIElement, app: XCUIApplication,
                                           scrollID: String, towardTop: Bool = false) throws {
        let scroll = app.scrollViews.matching(NSPredicate(format: "identifier == %@", scrollID)).firstMatch
        try sourceToolsRequire(scroll.exists, "The existing native scroll host is required", app: app)
        for _ in 0..<24 {
            if element.exists && element.frame.width > 0 && element.frame.height > 0
                && element.frame.intersection(scroll.frame).height > 8 { return }
            if towardTop { scroll.swipeDown() } else { scroll.swipeUp() }
        }
        try sourceToolsRequire(false, "Reveal only the exact actual UI element through ordinary scrolling: " + element.identifier, app: app)
    }
    private func subscriptionPreviewCloseOnlyKnownReadHosts(_ app: XCUIApplication) {
        guard app.state == .runningForeground, !app.textViews["online-source-draft"].exists,
              !app.textFields["subscription-url"].exists, !app.alerts.firstMatch.exists else { return }
        let close = app.buttons.matching(NSPredicate(format: "label == %@", "关闭订阅管理")).firstMatch
        if close.exists && close.isHittable { close.tap() }
        let search = subscriptionPreviewButton("online-close-sources", app: app)
        if search.exists && search.isHittable { search.tap() }
        let workspace = subscriptionPreviewButton("online-close-workspace", app: app)
        if workspace.exists && workspace.isHittable { workspace.tap() }
    }

    /// One normal real URL read reaches the existing UTF-8/replacement consumer.
    /// Only Cancel is selected. This does not prove URLSession cancellation,
    /// JSON save/import, an upstream new version or a newly installed source.
    func testExistingRealSourceLinkReadReplacementCancelledAndColdReopenPreserveExactDraft() throws {
        let expectedSHA = "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322"
        let expectedBytes = 5606
        let expectedURL = "https://shuyuan-api.yiove.com/import/book-source-collection/3d9f811b-0831-4203-9fcb-3e8020f8aa2d"
        let expectedMessage = "导入链接中的书源将覆盖当前未保存的内容。取消可保留原草稿。"
        let app = XCUIApplication(); app.launch()
        openExistingSourceManagement(app)
        let originalSources = try sourceToolsSourceLabels(app)
        try sourceToolsRequire(originalSources.count == 3
            && originalSources["online-source:https://dushu.baidu.com/"] == "百度小说"
            && originalSources["online-source:https://m.idejian.com"] == "得间小说",
            "Use the same actual existing three-source library, preserving its third source", app: app)
        assertPreservedSourceDraft(app, sha: expectedSHA, bytes: expectedBytes)
        keepScreenshot(app, name: "source-link-original-complete-unsaved-draft-before-read")
        closePreservedSourceDraft(app)
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalSources,
            "Observing and normally closing the original editor must preserve all original source identities", app: app)
        try sourceToolsRequire(!app.alerts.firstMatch.exists && !app.staticTexts["原操作待核对"].exists
            && !app.staticTexts["书源操作未完成"].exists,
            "Do not proceed under an unrelated pending operation, error or confirmation", app: app)

        let fields = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "书源包链接"))
        try sourceToolsRequire(fields.count == 1 && fields.element.isEnabled && fields.element.isHittable,
            "Require the actual unique normal source-package URL field", app: app)
        let initialValue = try XCTUnwrap(fields.element.value as? String)
        try sourceToolsRequire(initialValue.isEmpty || initialValue == "书源包链接",
            "Do not overwrite an existing user-entered link", app: app)
        fields.element.tap(); fields.element.typeText(expectedURL)
        try sourceToolsRequire(fields.count == 1 && fields.element.value as? String == expectedURL,
            "The complete original real subscription URL must be entered through normal UI", app: app)
        let reads = app.buttons.matching(NSPredicate(format: "label == %@", "读取"))
        try sourceToolsRequire(reads.count == 1 && reads.element.isEnabled && reads.element.isHittable,
            "Use exactly one ordinary visible source-link read action", app: app)
        keepScreenshot(app, name: "source-link-exact-real-url-before-only-read")
        reads.element.tap()
        let replacement = app.alerts["替换当前书源草稿？"]
        // Host's real read deadline is 30 seconds. Observe its actual terminal,
        // allowing UI delivery time; never race a close or fabricate a response.
        try sourceToolsWait("The real source-link read must reach replacement confirmation or an actual error", timeout: 70) {
            replacement.exists || app.staticTexts["书源操作未完成"].exists
        }
        try sourceToolsRequire(replacement.exists && !app.staticTexts["书源操作未完成"].exists,
            "Real HTTP/UTF-8 failure is FAIL; only the actual replacement consumer satisfies this journey", app: app)
        let completeMessage = replacement.staticTexts.matching(NSPredicate(format: "label == %@", expectedMessage))
        try sourceToolsRequire(completeMessage.count == 1 && completeMessage.element.label.contains("导入链接中的书源"),
            "Require the entire actual link-replacement message, including its incoming origin and preservation consequence", app: app)
        let facts: [String: Any] = ["actualInputURL": expectedURL,
            "originalDraftSHA256": expectedSHA, "originalDraftUTF8Bytes": expectedBytes,
            "originalSourceLabels": originalSources,
            "actualAlertTexts": replacement.staticTexts.allElementsBoundByIndex.map(\.label),
            "actualReplacementMessage": completeMessage.element.label,
            "sourceSaveRequested": false, "replacementAccepted": false,
            "urlSessionCancellationVerified": false, "remoteNewVersionVerified": false]
        let terminal = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts, options: [.prettyPrinted, .sortedKeys]),
            uniformTypeIdentifier: "public.json")
        terminal.name = "source-link-real-read-terminal-and-original-input-binding"; terminal.lifetime = .keepAlways; add(terminal)
        keepScreenshot(app, name: "source-link-actual-full-replacement-confirmation-before-cancel")
        let cancellations = replacement.buttons.matching(NSPredicate(format: "label == %@", "取消"))
        try sourceToolsRequire(cancellations.count == 1 && cancellations.element.isEnabled && cancellations.element.isHittable,
            "Only cancel the actual original-draft replacement; never accept or save", app: app)
        cancellations.element.tap()
        try sourceToolsWait("Cancellation must dismiss only the actual replacement confirmation", timeout: 5) { !replacement.exists }
        try subscriptionPreviewReveal(app.buttons["导入 JSON"], app: app, scrollID: "online-source-scroll", towardTop: true)
        assertPreservedSourceDraft(app, sha: expectedSHA, bytes: expectedBytes)
        closePreservedSourceDraft(app)
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalSources,
            "The real URL read and Cancel must leave every original source identity/name unchanged", app: app)
        leaveExistingSourceManagement(app)

        // Cold startup follows normal parent exit and the completed read.
        // No source save/import/delete, draft edit or source update is submitted.
        app.terminate(); app.launch()
        openExistingSourceManagement(app)
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalSources,
            "Cold startup must retain the same original source identities/names", app: app)
        assertPreservedSourceDraft(app, sha: expectedSHA, bytes: expectedBytes)
        keepScreenshot(app, name: "source-link-original-full-draft-cold-reopened-after-cancel")
        closePreservedSourceDraft(app)
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalSources,
            "Normal cold-session editor close must still retain all original source projections", app: app)
        leaveExistingSourceManagement(app)
    }

}

/// Read-only real-source search restoration; execution remains UNRUN.
/// Uses the already saved Reader-real-sources.json sources and the same real
/// keyword as ReaderOnlineJourneyTests. It never imports, saves or admits.
final class ReaderOnlineSearchRestorationJourneyTests: XCTestCase {
    private let keyword = "剑来"
    private enum Prerequisite: Error { case unavailable }

    override func setUpWithError() throws { continueAfterFailure = false }

    func testExistingRealSearchFilterEmptyAndSourceDetailReturnsRestoreScrolledCandidate() throws {
        let app = XCUIApplication(); app.launch()
        let menu = app.buttons["更多书架操作"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20)); XCTAssertTrue(menu.isHittable); menu.tap()
        let online = app.buttons["搜索与书源"]
        XCTAssertTrue(online.waitForExistence(timeout: 5)); XCTAssertTrue(online.isHittable); online.tap()
        addTeardownBlock { self.closeReadOnlyWorkspaceIfKnown(app) }

        let query = app.textFields["online-search-query"]
        XCTAssertTrue(query.waitForExistence(timeout: 10)); XCTAssertTrue(query.isHittable)
        // A new workspace has an empty query. Preserve any unexpected owner.
        guard query.value as? String == "书名或作者" || query.value as? String == "" else {
            XCTFail("Do not overwrite another search query"); throw Prerequisite.unavailable
        }
        query.tap(); query.typeText(keyword)
        let submit = app.buttons["online-search-submit"]
        XCTAssertTrue(submit.isHittable); submit.tap()
        try wait("A real current search must finish with actual candidates", timeout: 180) {
            !app.buttons["online-search-stop"].exists && self.results(app).count > 0
        }
        XCTAssertEqual(query.value as? String, keyword)
        let initial = try visibleRows(app)
        guard self.results(app).count >= 2 else {
            XCTFail("The actual saved sources returned too few candidates; no substitute input or generated result is allowed")
            throw Prerequisite.unavailable
        }

        let filter = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "筛选来源或书名"))
        XCTAssertEqual(filter.count, 1)
        let field = filter.element
        XCTAssertTrue(field.isHittable)
        guard field.value as? String == "筛选来源或书名" || field.value as? String == "" else {
            XCTFail("Preserve an unexpected existing filter"); throw Prerequisite.unavailable
        }
        // This is a local filter token, never a fabricated remote result.
        let absent = "ReaderNativeFilter-" + UUID().uuidString
        field.tap(); field.typeText(absent)
        let empty = app.staticTexts["没有符合筛选的书籍"]
        let clear = app.buttons["清除筛选"]
        try wait("The existing public empty state must replace the filtered list", timeout: 10) {
            empty.exists && clear.exists && clear.isHittable && self.results(app).count == 0
        }
        XCTAssertTrue(app.frame.contains(empty.frame)); XCTAssertGreaterThan(empty.frame.height, 0)
        keep(app, "actual-existing-search-filter-public-empty")
        clear.tap()
        try wait("Clearing only the filter must expose the original candidate identities", timeout: 10) {
            !empty.exists && initial.rows.allSatisfy { row in
                let matches = app.buttons.matching(NSPredicate(format: "identifier == %@", row.id))
                return matches.count == 1 && matches.element.label == row.label
            }
        }
        XCTAssertEqual(query.value as? String, keyword)
        XCTAssertTrue(field.value as? String == "筛选来源或书名" || field.value as? String == "")

        // Removing a focused field through this existing read-only parent
        // route dismisses its real keyboard. Do not inject resignFirstResponder
        // or use a hidden control to invent a larger result viewport.
        if app.keyboards.firstMatch.exists { try sourceRoundTrip(app) }
        guard !app.keyboards.firstMatch.exists else {
            XCTFail("The actual result viewport must not be obscured by a retained keyboard")
            throw Prerequisite.unavailable
        }
        let beforeScroll = try visibleRows(app)
        let initiallyVisible = Set(beforeScroll.rows.map(\.id))
        var moved: Viewport?
        for _ in 0..<4 {
            let viewport = try resultViewport(app)
            let start = coordinate(CGPoint(x: viewport.midX, y: viewport.maxY - 28), app: app)
            let end = coordinate(CGPoint(x: viewport.midX, y: viewport.minY + 28), app: app)
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
            let now = try visibleRows(app)
            let newIdentity = now.rows.contains { !initiallyVisible.contains($0.id) }
            let oldMoved = beforeScroll.rows.contains { old in
                let match = app.buttons.matching(NSPredicate(format: "identifier == %@", old.id))
                return match.count == 0 || abs(match.element.frame.minY - old.frame.minY) >= min(80, old.frame.height / 2)
            }
            if newIdentity && oldMoved { moved = now; break }
        }
        guard let scrolled = moved, let chosen = scrolled.rows.first(where: { !initiallyVisible.contains($0.id) }) else {
            XCTFail("The actual current source results did not provide observable scrolling to a new original source/book candidate")
            throw Prerequisite.unavailable
        }
        keep(app, "actual-original-candidate-after-native-scroll")

        try sourceRoundTrip(app)
        try assertRestored(scrolled, app: app, name: "source-management-return")

        let original = app.buttons.matching(NSPredicate(format: "identifier == %@", chosen.id))
        XCTAssertEqual(original.count, 1); XCTAssertTrue(original.element.isHittable)
        let identity = String(chosen.id.dropFirst("online-result:".count))
        let separator = try XCTUnwrap(identity.firstIndex(of: "|"))
        let sourceID = String(identity[..<separator])
        let bookID = String(identity[identity.index(after: separator)...])
        XCTAssertFalse(sourceID.isEmpty); XCTAssertFalse(bookID.isEmpty)
        let binding = XCTAttachment(string: "keyword=\(keyword)\ncandidate=\(identity)\nsourceID=\(sourceID)\nbookID=\(bookID)\noriginalCandidateFrame=\(chosen.frame)\noriginalViewport=\(scrolled.frame)")
        binding.name = "actual-scrolled-source-book-binding"; binding.lifetime = .keepAlways; add(binding)
        original.element.tap()
        let selected = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "online-selected:" + identity)).element
        XCTAssertTrue(selected.waitForExistence(timeout: 10))
        let detail = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "online-detail-book:" + bookID)).element
        XCTAssertTrue(detail.waitForExistence(timeout: 120), "Require this exact actual candidate's detail, with no generated fallback")
        XCTAssertFalse(detail.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        // The exact Core source/book IDs bind this detail. A real upstream
        // detail may normalize its display title independently of search.
        let titles = XCTAttachment(string: "candidate=\(identity)\noriginalResultLabel=\(chosen.label)\nactualDetailTitle=\(detail.label)")
        titles.name = "actual-scrolled-candidate-and-detail-display-titles"; titles.lifetime = .keepAlways; add(titles)
        let back = app.buttons["online-back-search"]
        XCTAssertTrue(back.isHittable); back.tap()
        try assertRestored(scrolled, app: app, name: "exact-source-book-detail-return")
        // No add-and-read, chapter admission, source edits or source switches.
    }

    private struct Row { let id: String; let label: String; let frame: CGRect }
    private struct Viewport { let frame: CGRect; let rows: [Row] }

    private func results(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-result:"))
    }
    private func resultViewport(_ app: XCUIApplication) throws -> CGRect {
        guard let frame = observedResultViewport(app) else {
            XCTFail("No actual result-containing ScrollView viewport"); throw Prerequisite.unavailable
        }
        return frame
    }
    private func observedResultViewport(_ app: XCUIApplication) -> CGRect? {
        let choices = app.scrollViews.allElementsBoundByIndex.compactMap { scroll -> CGRect? in
            let rows = scroll.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-result:"))
            var frame = scroll.frame.intersection(app.frame)
            guard !frame.isNull, frame.width > 100, frame.height > 100,
                  rows.allElementsBoundByIndex.contains(where: { $0.isHittable && frame.intersects($0.frame) }) else { return nil }
            if app.keyboards.firstMatch.exists {
                let keyboard = app.keyboards.firstMatch.frame
                if frame.intersects(keyboard) { frame.size.height = max(0, keyboard.minY - frame.minY) }
            }
            return frame.height > 100 ? frame : nil
        }
        return choices.min(by: { $0.height < $1.height })
    }
    private func visibleRows(_ app: XCUIApplication) throws -> Viewport {
        try wait("Require actual fully visible original candidate rows", timeout: 10) { self.observedVisibleRows(app) != nil }
        return try XCTUnwrap(observedVisibleRows(app))
    }
    private func observedVisibleRows(_ app: XCUIApplication) -> Viewport? {
        guard let viewport = observedResultViewport(app) else { return nil }
        let rows = results(app).allElementsBoundByIndex.compactMap { row -> Row? in
            guard row.isHittable, row.frame.width > 0, row.frame.height > 0,
                  viewport.insetBy(dx: -1, dy: -1).contains(row.frame) else { return nil }
            return Row(id: row.identifier, label: row.label, frame: row.frame)
        }.sorted { $0.frame.minY < $1.frame.minY }
        guard !rows.isEmpty else { return nil }
        return Viewport(frame: viewport, rows: rows)
    }
    private func sourceRoundTrip(_ app: XCUIApplication) throws {
        let sources = app.buttons["online-open-sources"]
        XCTAssertTrue(sources.isHittable); sources.tap()
        XCTAssertTrue(app.buttons["online-source-file"].waitForExistence(timeout: 10))
        XCTAssertGreaterThan(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-source:")).count, 0)
        guard !app.textViews["online-source-draft"].exists else {
            XCTFail("Preserve any unexpectedly presented original source draft"); throw Prerequisite.unavailable
        }
        let back = app.buttons["online-close-sources"]
        XCTAssertTrue(back.isHittable); back.tap()
        XCTAssertTrue(app.textFields["online-search-query"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["online-search-query"].value as? String, keyword)
    }
    private func assertRestored(_ original: Viewport, app: XCUIApplication, name: String) throws {
        let condition = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let now = self.observedVisibleRows(app), now.rows.map(\.id) == original.rows.map(\.id),
                  abs(now.frame.minY - original.frame.minY) <= 2, abs(now.frame.height - original.frame.height) <= 2 else { return false }
            return zip(now.rows, original.rows).allSatisfy { actual, expected in
                actual.label == expected.label && abs(actual.frame.minY - expected.frame.minY) <= 2
                    && abs(actual.frame.height - expected.frame.height) <= 2
            }
        }, object: nil)
        let outcome = XCTWaiter.wait(for: [condition], timeout: 10)
        // Attach the actual geometry before recording any failure. A remount
        // jump is a product finding, not permission to relax the original ROI.
        let actual = observedVisibleRows(app)
        func describe(_ viewport: Viewport?) -> String {
            guard let viewport else { return "No fully visible original result rows" }
            return "viewport=\(viewport.frame)\n" + viewport.rows.map {
                "candidate=\($0.id)\nframe=\($0.frame)\nlabel=\($0.label)"
            }.joined(separator: "\n")
        }
        let geometry = XCTAttachment(string: "ORIGINAL\n" + describe(original) + "\nACTUAL\n" + describe(actual))
        geometry.name = "actual-source-book-viewport-geometry-" + name; geometry.lifetime = .keepAlways; add(geometry)
        guard outcome == .completed else {
            XCTFail("The same actual candidate rows must return to the same viewport: " + name)
            throw Prerequisite.unavailable
        }
        XCTAssertEqual(app.textFields["online-search-query"].value as? String, keyword)
        keep(app, "actual-candidate-viewport-restored-" + name)
    }
    private func closeReadOnlyWorkspaceIfKnown(_ app: XCUIApplication) {
        guard app.state == .runningForeground, !app.textViews["online-source-draft"].exists else { return }
        if app.buttons["online-back-search"].exists && app.buttons["online-back-search"].isHittable { app.buttons["online-back-search"].tap() }
        if app.buttons["online-close-sources"].exists && app.buttons["online-close-sources"].isHittable { app.buttons["online-close-sources"].tap() }
        if app.buttons["online-close-workspace"].exists && app.buttons["online-close-workspace"].isHittable { app.buttons["online-close-workspace"].tap() }
    }
    private func coordinate(_ point: CGPoint, app: XCUIApplication) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x - app.frame.minX, dy: point.y - app.frame.minY))
    }
    private func wait(_ message: String, timeout: TimeInterval, _ condition: @escaping () -> Bool) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        guard XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed else {
            XCTFail(message); throw Prerequisite.unavailable
        }
    }
    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}

private extension Array {
    var sourceToolsOnly: Element? { count == 1 ? first : nil }
}
