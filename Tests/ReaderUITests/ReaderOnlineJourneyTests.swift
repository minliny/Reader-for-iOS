import XCTest
import UIKit
import CryptoKit

final class ReaderOnlineJourneyTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    /// The Runner records the original phone package's read-only hash/size.
    /// This opens its existing Baidu source's native sheet and closes it;
    /// no source import, form submission or credential save is requested.
    func testExistingRealBaiduLoginSheetOpensAndCancelsWithoutChangingSourceOrShelfIdentities() throws {
#if targetEnvironment(simulator)
        XCTFail("This journey requires the original physical iPhone")
        throw SourceToolsFailure.prerequisite
#endif
        let environment = ProcessInfo.processInfo.environment
        let packageSHA = "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322"
        try sourceToolsRequire(UIDevice.current.userInterfaceIdiom == .phone
            && environment["READER_SOURCE_LOGIN_PACKAGE_SHA256"] == packageSHA
            && environment["READER_SOURCE_LOGIN_PACKAGE_BYTES"] == "5606",
            "Require a fresh read-only observation of the original phone's 5606-byte package; this method never provisions it", app: nil)
        let sourceID = "https://dushu.baidu.com/"
        let app = XCUIApplication()
        app.launch()
        try sourceToolsRequire(app.buttons["更多书架操作"].waitForExistence(timeout: 20),
            "The original shelf must load before entering source management", app: app)
        func shelfEntries() throws -> [String: String] {
            let entries = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ OR identifier == %@",
                "book-", "shelf-continue-card")).allElementsBoundByIndex
            try sourceToolsRequire(!entries.isEmpty && Set(entries.map(\.identifier)).count == entries.count
                && entries.contains(where: \.isHittable), "Require existing unambiguous shelf reading entries", app: app)
            return Dictionary(uniqueKeysWithValues: entries.map { ($0.identifier, $0.label) })
        }
        let originalShelf = try shelfEntries()
        openExistingSourceManagement(app)
        try sourceToolsRequire(!app.textViews["online-source-draft"].exists,
            "An existing source draft must remain untouched", app: app)
        let originalSources = try sourceToolsSourceLabels(app)
        try sourceToolsRequire(originalSources["online-source:" + sourceID] == "百度小说"
            && originalSources["online-source:https://m.idejian.com"] == "得间小说",
            "Require the two original saved package identities; no alternate source may be imported", app: app)
        let login = app.buttons.matching(identifier: "online-source-login:" + sourceID)
        try sourceToolsRequire(login.count == 1, "The Baidu login action must have one exact source-bound AX identity", app: app)
        let scroll = app.scrollViews["online-source-scroll"]
        for _ in 0..<6 {
            if login.element.isHittable { break }
            try sourceToolsRequire(scroll.exists && scroll.isHittable, "The actual source list must remain scrollable", app: app)
            scroll.swipeUp()
        }
        try sourceToolsRequire(login.element.isEnabled && login.element.isHittable,
            "The exact existing Baidu action must be reachable by normal source-list scrolling", app: app)
        let close = app.buttons.matching(identifier: "online-source-login-close")
        addTeardownBlock {
            if close.count == 1, close.element.isHittable { close.element.tap() }
        }
        login.element.tap()
        try sourceToolsWait("The real source login sheet must expose its native close control and WKWebView", timeout: 20) {
            close.count == 1 && close.element.isHittable && app.webViews.count >= 1
        }
        let title = app.staticTexts.matching(identifier: "online-source-login-title:" + sourceID)
        try sourceToolsRequire(title.count == 1 && title.element.label == "百度小说",
            "The sheet's source title must identify the same original Baidu source", app: app)
        let provenance = XCTAttachment(string: "sourceId=\(sourceID)\noriginalPackageSHA256=\(packageSHA)\noriginalPackageBytes=5606\nroute=existing source -> native WKWebView sheet -> close\nNo Complete Login, password input, source mutation or Cookie save.\nOrigin reachability, anonymous Cookie acquisition, authentication and relative loginUrl remain OPEN.")
        provenance.name = "existing-real-baidu-native-login-sheet-cancel-boundary"
        provenance.lifetime = .keepAlways; add(provenance)
        keepScreenshot(app, name: "existing-real-baidu-native-login-sheet-before-cancel")
        close.element.tap()
        try sourceToolsWait("Closing must retire only the sheet and reveal original source management", timeout: 10) {
            close.count == 0 && app.webViews.count == 0 && app.buttons["online-close-sources"].isHittable
        }
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalSources && login.count == 1,
            "Closing without saving must retain every original visible source identity and its Baidu login entry", app: app)
        leaveExistingSourceManagement(app)
        try sourceToolsRequire(try shelfEntries() == originalShelf,
            "Returning must preserve the original shelf and reading-entry identities", app: app)
        keepScreenshot(app, name: "existing-real-baidu-login-cancel-returned-original-shelf")
    }

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
        revealSourceFile(file, app: app)
        if file.isHittable {
            file.tap()
        } else {
            // SwiftUI may expose the visible toolbar button as non-hittable
            // while its native screen coordinate remains actionable. Keep
            // the real file picker path; do not turn that AX quirk into a
            // product-flow failure.
            file.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
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
        // SwiftUI's empty TextField can expose nil through XCTest AX while
        // its placeholder is rendered as "书名或作者". Accept that native
        // empty representation without treating it as a retained query.
        let queryValue = query.value as? String
        try sourceToolsRequire(query.waitForExistence(timeout: 10) && (queryValue == "书名或作者" || queryValue == "" || queryValue == nil),
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
        let queryValue = query.value as? String
        XCTAssertTrue(queryValue == "书名或作者" || queryValue == "" || queryValue == nil)
        let keyword = ProcessInfo.processInfo.environment["READER_REAL_SEARCH_STOP_KEYWORD"] ?? "剑来"
        query.tap(); query.typeText(keyword)
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
        let candidates = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-result:"))
        func visibleCandidateIDs() -> Set<String> {
            Set(candidates.allElementsBoundByIndex.map(\.identifier))
        }
        let stoppedIDs = visibleCandidateIDs()
        let emptyStopped = app.staticTexts["搜索已停止"]
        let partialStopped = app.staticTexts["搜索已停止，可保留已有结果并重新搜索"]
        let stoppedStateVisible = stoppedIDs.isEmpty ? emptyStopped.exists : partialStopped.exists
        XCTAssertTrue(stoppedStateVisible, "The actual stopped state must match whether real candidates arrived before cancellation")
        XCTAssertEqual(query.value as? String, keyword)
        let retry = stoppedIDs.isEmpty ? app.buttons["重新搜索"] : app.buttons["online-research-failed"]
        XCTAssertTrue(retry.exists && retry.isEnabled, "Stopped results need a usable re-search action")
        let facts: [String: Any] = [
            "keyword": keyword,
            "stopTapCount": 1,
            "stoppedStateVisible": stoppedStateVisible,
            "candidateCountAfterStop": stoppedIDs.count,
            "presentation": stoppedIDs.isEmpty ? "empty" : "partial",
            "boundary": "This is one real stop action against the existing enabled source set. Candidate identities are visible UI projections, not a fabricated network response or a claim that every late callback was observed."
        ]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "real-search-stop-actual-outcome"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["online-open-sources"].tap()
        let backToSearch = app.buttons["online-close-sources"]
        XCTAssertTrue(backToSearch.waitForExistence(timeout: 10))
        backToSearch.tap()
        XCTAssertEqual(visibleCandidateIDs(), stoppedIDs, "Source management must preserve the stopped candidate viewport identities")
        XCTAssertEqual(query.value as? String, keyword)
        XCTAssertTrue(retry.exists && retry.isEnabled)
        retry.tap()
        try sourceToolsWait("The explicit real re-search must settle", timeout: 45) {
            app.buttons["online-search-submit"].exists && !app.buttons["online-search-stop"].exists
        }
        XCTAssertTrue(visibleCandidateIDs().isSuperset(of: stoppedIDs),
                      "Re-search of the same keyword must retain candidates obtained before Stop")
        XCTAssertEqual(query.value as? String, keyword)
        app.buttons["online-close-workspace"].tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 10), app.debugDescription)
    }

    /// Uses only the phone's three saved sources. Both enabled sources must
    /// return real candidates while the temporarily enabled third source is
    /// still the sole unfinished request; a missed natural window is a skip.
    func testExistingRealThreeSourcePartialSearchStopRestoresDisabledSourceAndRetainsCandidates() throws {
#if targetEnvironment(simulator)
        XCTFail("This journey requires the original physical iPhone")
        throw SourceToolsFailure.prerequisite
#endif
#if !DEBUG
        XCTFail("This exact Stop witness requires the opt-in DEBUG search trace")
        throw SourceToolsFailure.prerequisite
#endif
        try sourceToolsRequire(UIDevice.current.userInterfaceIdiom == .phone,
            "Require the original physical phone and its existing source library", app: nil)
        struct PendingOperation: Decodable {
            let operationID: String
            let method: String
            let scope: String
            let commandSHA256: String
            let completed: Bool
            let resultPresent: Bool
            let failurePresent: Bool
            let sourceId: String
            let bookId: String
            let title: String
        }
        struct Preproof: Decodable {
            let schemaVersion: Int
            let policy: String
            let capturedAtUTC: String
            let targetUDID: String
            let bundleID: String
            let snapshotSHA256: String
            let sourcePackageSHA256: String
            let sourcePackageBytes: Int
            let hostCommandCount: Int
            let hostCommandManifestSHA256: String
            let captureReceiptsSHA256: String
            let coreCommit: String
            let pendingOperationCount: Int
            let pendingOperationIDs: [String]
            let pendingOperations: [PendingOperation]
            let descriptorSHA256: String
            let preparationCommandSHA256: String
            let corePreparationPayloadSHA256: String
            let taskCount: Int
            let completedTaskCount: Int
            let failedTaskCount: Int
            let cancelledTaskCount: Int
            let pausedTaskCount: Int
            let pendingTaskCount: Int
            let inProgressTaskCount: Int
            let physicalBodyCount: Int
            let protectedOriginalHostCommandCount: Int
            let protectedOriginalCompletedTaskCount: Int
            let protectedOriginalFailedTaskCount: Int
            let protectedOriginalPhysicalBodyCount: Int
            let protectedOriginalManifestSHA256: String
            let originalChapterIndex: UInt32
            let originalScalarOffset: UInt32
            let sourceNames: [String: String]
            let sourceValues: [String: String]
            let stoppedPhysicalApp: Bool
            let preserveDataUpdateVerified: Bool
        }
        let environment = ProcessInfo.processInfo.environment
        let rawPreproof = try XCTUnwrap(environment["READER_V4_STOP_PREPROOF_JSON"])
        let expectedPreproofSHA = try XCTUnwrap(environment["READER_V4_STOP_PREPROOF_SHA256"])
        let expectedCoreCommit = try XCTUnwrap(environment["READER_V4_STOP_EXPECTED_CORE_COMMIT"])
        let targetUDID = try XCTUnwrap(environment["READER_PHYSICAL_TARGET_UDID"])
        let preproofBytes = Data(rawPreproof.utf8)
        let actualPreproofSHA = SHA256.hash(data: preproofBytes).map { String(format: "%02x", $0) }.joined()
        try sourceToolsRequire(preproofBytes.count <= 16 * 1024 && actualPreproofSHA == expectedPreproofSHA,
            "Require exact fresh stopped-App external preproof bytes before any source toggle", app: nil)
        let proof = try JSONDecoder().decode(Preproof.self, from: preproofBytes)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let captured = formatter.date(from: proof.capturedAtUTC) ?? ISO8601DateFormatter().date(from: proof.capturedAtUTC)
        let age = captured.map { Date().timeIntervalSince($0) }
        let originalPendingID = "0ad35be2-67cd-43a0-b4b4-34e98814e40d"
        let pendingSourceID = "https://dushu.baidu.com/"
        let pendingBookID = "https://boxnovel.baidu.com/boxnovel/wiseapi/chapterList?bookid=4345127024&pageNum=1&order=asc&site="
        let originalSourceValues = ["http://199.33.126.51": "0", "https://m.idejian.com": "1", pendingSourceID: "1"]
        let originalSourceNames = ["http://199.33.126.51": "👍 同人圈", "https://m.idejian.com": "得间小说", pendingSourceID: "百度小说"]
        func isLowerHex(_ value: String, length: Int) -> Bool {
            value.utf8.count == length && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
        }
        let currentCounts = [proof.hostCommandCount, proof.taskCount, proof.completedTaskCount, proof.failedTaskCount,
            proof.cancelledTaskCount, proof.pausedTaskCount, proof.pendingTaskCount, proof.inProgressTaskCount, proof.physicalBodyCount]
        let taskClasses = [proof.completedTaskCount, proof.failedTaskCount, proof.cancelledTaskCount,
            proof.pausedTaskCount, proof.pendingTaskCount, proof.inProgressTaskCount]
        // Bound before summing untrusted decoded integers; the six classes
        // describe the complete fresh task table, not the original subset.
        let currentCountsConsistent = currentCounts.allSatisfy { (0...1_000_000).contains($0) }
            && taskClasses.reduce(0, +) == proof.taskCount
        try sourceToolsRequire(proof.schemaVersion == 3 && proof.policy == "physical-real-three-source-stop-v3"
            && age.map({ (0...600).contains($0) }) == true
            && proof.targetUDID == targetUDID && proof.bundleID == "io.reader.minliny.free"
            && environment["SIMULATOR_UDID"] == nil
            && isLowerHex(proof.snapshotSHA256, length: 64)
            && isLowerHex(proof.hostCommandManifestSHA256, length: 64)
            && isLowerHex(proof.captureReceiptsSHA256, length: 64)
            && isLowerHex(proof.coreCommit, length: 40) && proof.coreCommit == expectedCoreCommit
            && currentCountsConsistent && proof.pendingTaskCount == 0 && proof.inProgressTaskCount == 0,
            "Require the fresh complete-current manifest, capture receipts, exact Runner-expected Core and exhaustive bounded task classifications", app: nil)
        try sourceToolsRequire(proof.protectedOriginalHostCommandCount == 581
            && proof.protectedOriginalCompletedTaskCount == 50 && proof.protectedOriginalFailedTaskCount == 1
            && proof.protectedOriginalPhysicalBodyCount == 57
            && proof.protectedOriginalManifestSHA256 == "566c856f78ae1d7d00dadd050bc9cb1d4c5349e82a4af7e43eb2f9863a92d635"
            && proof.hostCommandCount >= proof.protectedOriginalHostCommandCount
            && proof.completedTaskCount >= proof.protectedOriginalCompletedTaskCount
            && proof.failedTaskCount >= proof.protectedOriginalFailedTaskCount
            && proof.physicalBodyCount >= proof.protectedOriginalPhysicalBodyCount,
            "The complete fresh totals must include the exact independently preserved original 581 Host/50 completed/1 failed/57 body subset", app: nil)
        try sourceToolsRequire(proof.sourcePackageSHA256 == "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322"
            && proof.sourcePackageBytes == 5606
            && proof.pendingOperationCount == 1 && proof.pendingOperationIDs == [originalPendingID]
            && proof.pendingOperations.count == 1
            && proof.pendingOperations.allSatisfy({ pending in
                pending.operationID == originalPendingID && pending.method == "bookshelf.add"
                    && pending.scope == "shelf-add:" + pendingSourceID + "|" + pendingBookID
                    && pending.commandSHA256 == "b8da0dd291ca82d63ba2afb88a9e371a280cfd130317c6d7e5e167f0e93a8f82"
                    && !pending.completed && !pending.resultPresent && !pending.failurePresent
                    && pending.sourceId == pendingSourceID && pending.bookId == pendingBookID && pending.title == "等到鸢尾纯白"
            })
            && proof.descriptorSHA256 == "b00559c3fda92b5515e69a4a577e0a50a2c0f3062ced7b1eaa2d92d72ec91e83"
            && proof.preparationCommandSHA256 == "c3feb8f93a79776d5402763d8187b8730ff04b269272339d27fef810f08d8c67"
            && proof.corePreparationPayloadSHA256 == "63b45965e8295bb40ad0a2b649d8d1756e6c65c834c3157563fab2586c0aac58"
            && proof.originalChapterIndex == 40 && proof.originalScalarOffset == 0
            && proof.sourceNames == originalSourceNames && proof.sourceValues == originalSourceValues
            && proof.stoppedPhysicalApp && proof.preserveDataUpdateVerified,
            "Require exact original pending owner, source definitions and protected reader facts before Stop", app: nil)
        let preproofFacts: [String: Any] = [
            "schemaVersion": proof.schemaVersion, "policy": proof.policy,
            "preproofSHA256": expectedPreproofSHA, "snapshotSHA256": proof.snapshotSHA256,
            "currentComplete": ["hostCommandCount": proof.hostCommandCount,
                "hostCommandManifestSHA256": proof.hostCommandManifestSHA256,
                "captureReceiptsSHA256": proof.captureReceiptsSHA256, "coreCommit": proof.coreCommit,
                "taskCount": proof.taskCount, "completedTaskCount": proof.completedTaskCount,
                "failedTaskCount": proof.failedTaskCount, "cancelledTaskCount": proof.cancelledTaskCount,
                "pausedTaskCount": proof.pausedTaskCount, "pendingTaskCount": proof.pendingTaskCount,
                "inProgressTaskCount": proof.inProgressTaskCount, "physicalBodyCount": proof.physicalBodyCount,
                "descriptorSHA256": proof.descriptorSHA256, "preparationCommandSHA256": proof.preparationCommandSHA256,
                "corePreparationPayloadSHA256": proof.corePreparationPayloadSHA256] as [String: Any],
            "protectedOriginal": ["hostCommandCount": proof.protectedOriginalHostCommandCount,
                "completedTaskCount": proof.protectedOriginalCompletedTaskCount,
                "failedTaskCount": proof.protectedOriginalFailedTaskCount,
                "physicalBodyCount": proof.protectedOriginalPhysicalBodyCount,
                "manifestSHA256": proof.protectedOriginalManifestSHA256] as [String: Any],
            "originalPendingOperationID": originalPendingID,
            "originalPendingCommandSHA256": proof.pendingOperations[0].commandSHA256,
            "boundary": "The trusted full proof SHA binds actual current totals, complete Host manifest, capture receipts and the exact Runner-expected Core. Current totals are not the protected original subset. The original b8 add remains unknown; its current continued descriptor and read/revision2 Core intent are independently bound and do not acknowledge that add. External postproof must protect all complete-current Host records/tasks/bodies, both admission descriptors, current Core intent, original unknown command, original source bytes and reader facts, and attribute only authorized changes."
        ]
        let preproofAttachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: preproofFacts,
            options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        preproofAttachment.name = "physical-real-three-source-stop-v3-external-preproof"
        preproofAttachment.lifetime = .keepAlways; add(preproofAttachment)
        let app = XCUIApplication()
        let traceMode = "physical-v4-02-search-trace-v1"
        let traceRunID = UUID().uuidString.lowercased()
        app.launchEnvironment["READER_V4_SEARCH_TRACE_MODE"] = traceMode
        app.launchEnvironment["READER_V4_SEARCH_TRACE_RUN_ID"] = traceRunID
        try sourceToolsRequire(app.state == .notRunning,
            "The fresh global trace run must use the stopped App from the external preproof", app: app)
        let disabledSourceID = "http://199.33.126.51"
        let enabledSourceIDs = ["https://m.idejian.com", "https://dushu.baidu.com/"]
        let originalLabels = ["online-source:" + disabledSourceID: "👍 同人圈",
            "online-source:https://m.idejian.com": "得间小说", "online-source:https://dushu.baidu.com/": "百度小说"]
        let originalValues = [disabledSourceID: "0", "https://m.idejian.com": "1", "https://dushu.baidu.com/": "1"]
        let keyword = "剑来"
        var sourceWriteReadRevision: Int?
        var sourceWriteOperationID: String?
        var sourceWriteExpectedValue = "1"
        var reconciledSourceOperationIDs = Set<String>()
        var disableTapCount = 0
        var stopTapCount = 0
        func attach(_ name: String, _ facts: [String: Any]) throws {
            let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts,
                options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        addTeardownBlock {
            try attach("physical-real-three-source-stop-global-trace-run-binding", [
                "mode": traceMode, "runID": traceRunID,
                "rawRelativePath": "tmp/ReaderOnlineSearchTrace-" + traceRunID + "/trace.json",
                "ownerRelativePath": "tmp/ReaderOnlineSearchTrace-" + traceRunID + "/owner.json",
                "boundary": "This identifies only the first launch's opt-in run, including a skipped natural Stop window. Files may be absent before an actual search; their existence is not retirement evidence. Recovery relaunches clear trace mode/run rather than reusing this directory. External raw SHA/version/mode correspondence remains required."
            ])
        }
        func exactToggle(_ sourceID: String) throws -> XCUIElement {
            let matches = app.switches.matching(identifier: "online-source-enabled:" + sourceID)
            try sourceToolsRequire(matches.count == 1, "Require one exact existing source toggle: \(sourceID)", app: app)
            return matches.element
        }
        func sourceValues() throws -> [String: String] {
            try sourceToolsSourceValues(app, sourceIDs: Set(originalValues.keys))
        }
        func sourceState() -> SourceToolsSourceState? { sourceToolsSourceState(app) }
        @discardableResult
        func settleOriginalSourceWrite(_ stage: String) throws -> Int {
            let previousRead = try XCTUnwrap(sourceWriteReadRevision)
            var observedOperation = sourceWriteOperationID != nil
            var changedOperationID: String?
            func persistedValueMatchesWrite() -> Bool {
                let source = app.switches.matching(identifier: "online-source-enabled:" + disabledSourceID)
                return source.count == 1 && source.element.value as? String == sourceWriteExpectedValue
            }
            // rulesMutation may take 120 seconds. A stale, idle 0 immediately
            // after tap cannot finish this wait without a newer persisted read.
            try sourceToolsWait("\(stage): observe the accepted original write, its terminal result or its recovery entry", timeout: 130) {
                guard let status = sourceState() else { return false }
                if !status.operationID.isEmpty {
                    if let originalID = sourceWriteOperationID, originalID != status.operationID {
                        changedOperationID = status.operationID; return true
                    }
                    sourceWriteOperationID = status.operationID; observedOperation = true
                }
                return status.operation == "pending"
                    || (status.operation == "terminal" && (observedOperation
                        || (status.revision > previousRead && persistedValueMatchesWrite())))
            }
            try sourceToolsRequire(changedOperationID == nil,
                "\(stage): a different operation must never be recovered or treated as this source write", app: app)
            let observed = try XCTUnwrap(sourceState())
            if observed.operation == "pending" {
                try attach("real-three-source-write-needs-original-recovery", ["stage": stage,
                    "operationID": observed.operationID, "sourceReadRevision": observed.revision,
                    "boundary": "An unresolved source write is not restoration; only its existing original recovery action may be used once."])
                try sourceToolsRequire(!reconciledSourceOperationIDs.contains(observed.operationID),
                    "\(stage): the original write remains unresolved after its one recovery; stop without another source toggle", app: app)
                let notice = app.descendants(matching: .any).matching(identifier: "online-original-operation").firstMatch
                let retry = notice.buttons.matching(identifier: "重试")
                try sourceToolsRequire(notice.exists && notice.staticTexts["原操作待核对"].exists
                    && retry.count == 1 && retry.element.isEnabled && retry.element.isHittable
                    && sourceState()?.operationID == observed.operationID && sourceState()?.operation == "pending",
                    "\(stage): reconcile only this source owner's original pending operation through its existing recovery UI", app: app)
                reconciledSourceOperationIDs.insert(observed.operationID)
                retry.element.tap()
                try sourceToolsWait("\(stage): the one original recovery must reach terminal status; unresolved means stop", timeout: 130) {
                    guard let status = sourceState() else { return false }
                    if !status.operationID.isEmpty && status.operationID != observed.operationID {
                        changedOperationID = status.operationID; return true
                    }
                    return status.operation == "terminal"
                }
                try sourceToolsRequire(changedOperationID == nil,
                    "\(stage): recovery must retain the original operation identity", app: app)
            }
            try sourceToolsWait("\(stage): require a successful fresh persisted source read after the terminal original write", timeout: 30) {
                guard let status = sourceState() else { return false }
                return status.operation == "terminal" && status.read == "ready" && status.revision > previousRead
                    && persistedValueMatchesWrite()
            }
            let confirmed = try XCTUnwrap(sourceState())
            try sourceToolsRequire(confirmed.operation == "terminal" && confirmed.operationID.isEmpty
                && confirmed.read == "ready" && confirmed.revision > previousRead && persistedValueMatchesWrite(),
                "\(stage): neither busy/pending state nor a cached source value proves completion", app: app)
            return confirmed.revision
        }
        func enterSources() throws {
            if app.state == .notRunning {
                // Recovery may reopen source management, never reuse a trace
                // run directory or restart the observed search generation.
                app.launchEnvironment["READER_V4_SEARCH_TRACE_MODE"] = ""
                app.launchEnvironment["READER_V4_SEARCH_TRACE_RUN_ID"] = ""
                app.launch()
            }
            else if app.state != .runningForeground { app.activate() }
            if !app.buttons["online-close-sources"].exists {
                if !app.buttons["online-open-sources"].exists {
                    let online = app.buttons["搜索与书源"]
                    if !online.exists {
                        let menu = app.buttons["更多书架操作"]
                        try sourceToolsRequire(menu.waitForExistence(timeout: 20) && menu.isHittable,
                            "Restore sources only through the existing shelf menu", app: app)
                        menu.tap()
                    }
                    try sourceToolsRequire(online.waitForExistence(timeout: 5) && online.isHittable,
                        "The original online workspace must remain reachable", app: app)
                    online.tap()
                }
                let sources = app.buttons["online-open-sources"]
                try sourceToolsRequire(sources.waitForExistence(timeout: 10) && sources.isHittable,
                    "The original source management entry must remain reachable", app: app)
                sources.tap()
            }
            try sourceToolsRequire(app.buttons["online-close-sources"].waitForExistence(timeout: 10),
                "Require the actual source management page", app: app)
            try sourceToolsWait("The original three source toggles must load", timeout: 15) {
                app.switches.matching(identifier: "online-source-enabled:" + disabledSourceID).count == 1
            }
        }
        func returnToSearch() throws {
            let close = app.buttons["online-close-sources"]
            try sourceToolsRequire(close.exists && close.isHittable, "Return through the existing source-page control", app: app)
            close.tap()
            try sourceToolsRequire(app.textFields["online-search-query"].waitForExistence(timeout: 10),
                "Return to the same real search workspace", app: app)
        }
        func restoreOriginalSources(returnToShelf: Bool) throws {
            // No source mutation can precede the captured pre-enable read.
            // Leave the UI untouched when a prerequisite failed before it.
            guard sourceWriteReadRevision != nil else { return }
            try enterSources()
            let settledRead = try settleOriginalSourceWrite("Before restoration")
            let bad = try exactToggle(disabledSourceID)
            let value = bad.value as? String
            try sourceToolsRequire(value == "0" || value == "1", "The exact temporary source must remain readable for restoration", app: app)
            if value == "1" {
                let scroll = app.scrollViews["online-source-scroll"]
                for _ in 0..<3 {
                    if sourceToolsVisibleSourceToggle(app, sourceID: disabledSourceID, sourceIDs: Set(originalValues.keys)) != nil { break }
                    try sourceToolsRequire(scroll.exists && scroll.isHittable, "Use only the real source list to reveal its original toggle", app: app)
                    scroll.swipeDown()
                }
                for _ in 0..<3 {
                    if sourceToolsVisibleSourceToggle(app, sourceID: disabledSourceID, sourceIDs: Set(originalValues.keys)) != nil { break }
                    try sourceToolsRequire(scroll.exists && scroll.isHittable, "Use only the real source list to reveal its original toggle", app: app)
                    scroll.swipeUp()
                }
                try sourceToolsRequire(disableTapCount == 0 && sourceState()?.operation == "terminal"
                    && sourceState()?.revision == settledRead,
                    "A new disable may follow only the terminal original write and its fresh read; never repeat an unresolved disable", app: app)
                var enabledValues = originalValues; enabledValues[disabledSourceID] = "1"
                try sourceToolsDisableExactVisibleSource(app, sourceID: disabledSourceID, labels: originalLabels,
                    values: enabledValues, readRevision: settledRead, tapCount: &disableTapCount) {
                    sourceWriteReadRevision = settledRead; sourceWriteOperationID = nil; sourceWriteExpectedValue = "0"
                }
            }
            let restoredRead = try settleOriginalSourceWrite("Confirm disabled restoration")
            try sourceToolsRequire((bad.value as? String) == "0" && bad.isEnabled,
                "Only a terminal write and its fresh persisted disabled value confirm this source restoration", app: app)
            try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalLabels && sourceValues() == originalValues,
                "Restoration must keep the exact three names/identities, disable only the original bad source and retain both enabled good sources", app: app)
            try attach("real-three-source-stop-restored-original-source-state", ["sourceValues": try sourceValues(),
                "returnToShelf": returnToShelf, "scenarioStopTapCount": stopTapCount,
                "disableTapCount": disableTapCount, "sourceReadRevision": restoredRead,
                "originalRecoveryOperationIDs": reconciledSourceOperationIDs.sorted(),
                "boundary": "Only the original disabled source may be toggled, after terminal original-operation status and a newer successful source.list projection. Full source definitions, database integrity and all 50 downloads require the runner's independent persisted snapshots."])
            try returnToSearch()
            if returnToShelf {
                let close = app.buttons["online-close-workspace"]
                try sourceToolsRequire(close.exists && close.isHittable, "Close the real workspace after exact source restoration", app: app)
                close.tap()
                try sourceToolsRequire(app.buttons["更多书架操作"].waitForExistence(timeout: 15),
                    "Restoration must return to the original shelf", app: app)
            }
        }
        // XCTest executes this throwing teardown on both failure and XCTSkip.
        // It never treats an unavailable page or failed restore as success.
        addTeardownBlock {
            try restoreOriginalSources(returnToShelf: true)
        }

        app.launch()
        try enterSources()
        try sourceToolsRequire(app.staticTexts.matching(identifier: "online-search-trace-owner").count == 1,
            "Require the global workspace's one opt-in trace owner before changing the original source", app: app)
        try sourceToolsWait("Require a successful persisted initial source read with no unresolved source operation", timeout: 15) {
            guard let status = sourceState() else { return false }
            return status.revision > 0 && status.read == "ready" && status.operation == "terminal"
        }
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalLabels && sourceValues() == originalValues,
            "Require the phone's exact original disabled/enabled three-source state before any change", app: app)
        try sourceToolsRequire(!app.textViews["online-source-draft"].exists,
            "An existing source draft must remain untouched", app: app)
        let bad = try exactToggle(disabledSourceID)
        try sourceToolsRequire(bad.isHittable && bad.isEnabled, "The original disabled source must be reachable without a substitute", app: app)
        sourceWriteReadRevision = try XCTUnwrap(sourceState()).revision
        bad.tap()
        try settleOriginalSourceWrite("Temporarily enable the original disabled source")
        try sourceToolsRequire((bad.value as? String) == "1" && bad.isEnabled,
            "The temporary enable must have a terminal original write and a fresh persisted enabled value", app: app)
        var mixedValues = originalValues; mixedValues[disabledSourceID] = "1"
        try sourceToolsRequire(try sourceValues() == mixedValues, "Only the existing disabled source may change for this search", app: app)
        try returnToSearch()
        let query = app.textFields["online-search-query"]
        let queryValue = query.value as? String
        let candidates = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-result:"))
        func candidateIDs() -> Set<String> { Set(candidates.allElementsBoundByIndex.map(\.identifier)) }
        func bothGoodSourcesReturned(_ ids: Set<String>) -> Bool {
            enabledSourceIDs.allSatisfy { sourceID in ids.contains { $0.hasPrefix("online-result:" + sourceID + "|") } }
        }
        try sourceToolsRequire((queryValue == nil || queryValue == "" || queryValue == "书名或作者") && candidateIDs().isEmpty,
            "The one real search must start with an empty query and no retained candidates from another generation", app: app)
        query.tap(); query.typeText(keyword)
        let submit = app.buttons["online-search-submit"]
        try sourceToolsRequire(submit.exists && submit.isHittable && submit.isEnabled, "Submit this one real mixed-source search", app: app)
        let stop = app.buttons["online-search-stop"]
        let progressLabel = "正在搜索 · 已返回 2/3 个书源"
        struct StopSnapshotNode {
            let element: any XCUIElementSnapshot
            let path: String
            let windows: [String]
        }
        typealias StopObservation = (ids: Set<String>, ready: Bool, settled: Bool, keyboardAbsent: Bool, facts: [String: Any])
        func valid(_ rect: CGRect) -> Bool {
            !rect.isNull && !rect.isInfinite && rect.width > 0 && rect.height > 0
                && [rect.minX, rect.minY, rect.maxX, rect.maxY].allSatisfy(\.isFinite)
        }
        func rectFacts(_ rect: CGRect) -> [String: Any] {
            var facts: [String: Any] = ["description": String(describing: rect), "valid": valid(rect)]
            if valid(rect) { facts["x"] = rect.minX; facts["y"] = rect.minY; facts["width"] = rect.width; facts["height"] = rect.height }
            return facts
        }
        func captureStopObservation() throws -> StopObservation {
            let foreground = app.state == .runningForeground
            let began = ProcessInfo.processInfo.systemUptime
            let tree = try app.snapshot()
            let returned = ProcessInfo.processInfo.systemUptime
            var nodes = [StopSnapshotNode]()
            func collect(_ element: any XCUIElementSnapshot, path: String, windows: [String]) {
                let ancestors = element.elementType == .window ? windows + [path] : windows
                nodes.append(StopSnapshotNode(element: element, path: path, windows: ancestors))
                for (index, child) in element.children.enumerated() {
                    collect(child, path: path + "/" + String(index), windows: ancestors)
                }
            }
            collect(tree, path: "root", windows: [])
            let stops = nodes.filter { $0.element.elementType == .button && $0.element.identifier == "online-search-stop" }
            let queries = nodes.filter { $0.element.elementType == .textField && $0.element.identifier == "online-search-query" }
            let stopNode = stops.count == 1 ? stops.first : nil
            let queryNode = queries.count == 1 ? queries.first : nil
            let windows = nodes.filter { $0.element.elementType == .window && queryNode?.windows.contains($0.path) == true }
            let mainWindow = windows.count == 1 ? windows.first : nil
            let frame = stopNode?.element.frame ?? .null, queryFrame = queryNode?.element.frame ?? .null
            let appFrame = tree.frame, windowFrame = mainWindow?.element.frame ?? .null
            let viewport = appFrame.intersection(windowFrame)
            let ids = Set(nodes.filter { $0.element.elementType == .button && $0.element.identifier.hasPrefix("online-result:") }.map { $0.element.identifier })
            var witnesses = [String: String]()
            for sourceID in enabledSourceIDs {
                witnesses[sourceID] = ids.sorted().first { $0.hasPrefix("online-result:" + sourceID + "|") }
            }
            let keyboardAbsent = !nodes.contains { $0.element.elementType == .keyboard }
            let conditions: [String: Bool] = [
                "runningForegroundBeforeSnapshot": foreground,
                "noAlert": !nodes.contains { $0.element.elementType == .alert },
                "noSheet": !nodes.contains { $0.element.elementType == .sheet },
                "keyboardAbsent": keyboardAbsent, "uniqueStop": stops.count == 1, "uniqueQuery": queries.count == 1,
                "exactStopLabel": stopNode?.element.label == "停止", "uniqueQueryWindow": windows.count == 1,
                "sameUniqueWindow": mainWindow != nil && stopNode?.windows == queryNode?.windows,
                "stopEnabled": stopNode?.element.isEnabled == true, "queryEnabled": queryNode?.element.isEnabled == true,
                "sameKeyword": queryNode?.element.value as? String == keyword,
                "exactPublicProgressInWindow": mainWindow.map { window in nodes.contains { $0.windows.contains(window.path) && $0.element.label == progressLabel } } ?? false,
                "bothActualSourceWitnesses": witnesses.count == enabledSourceIDs.count,
                "finiteFrames": [frame, queryFrame, appFrame, windowFrame, viewport].allSatisfy(valid),
                "stopFullyVisible": valid(viewport) && viewport.insetBy(dx: 1, dy: 1).contains(frame),
                "queryFullyVisible": valid(viewport) && viewport.contains(queryFrame),
                "sameRow": valid(frame) && valid(queryFrame) && abs(frame.midY - queryFrame.midY) <= 2,
                "stopRightOfQuery": valid(frame) && valid(queryFrame) && frame.minX > queryFrame.maxX
            ]
            func identity(_ node: StopSnapshotNode) -> [String: Any] {
                ["path": node.path, "windowPaths": node.windows, "identifier": node.element.identifier,
                 "label": node.element.label, "enabled": node.element.isEnabled, "frame": rectFacts(node.element.frame)]
            }
            let ready = conditions.values.allSatisfy { $0 }
            let settled = stops.isEmpty && nodes.contains { $0.element.elementType == .button && $0.element.identifier == "online-search-submit" }
            return (ids, ready, settled, keyboardAbsent, ["snapshotBeganUptime": began, "snapshotReturnedUptime": returned,
                "evaluatedUptime": ProcessInfo.processInfo.systemUptime, "conditions": conditions,
                "candidateIDs": ids.sorted(), "actualSourceWitnesses": witnesses,
                "stops": stops.map(identity), "queries": queries.map(identity), "queryWindows": windows.map(identity),
                "queryValue": queryNode?.element.value as? String ?? "<unavailable>",
                "appFrame": rectFacts(appFrame), "viewport": rectFacts(viewport), "ready": ready, "searchSettled": settled])
        }
        var observations = [[String: Any]]()
        var acceptedObservation: StopObservation?
        var lastObservedIDs = Set<String>()
        var observationError: String?
        var keyboardDismissed = false
        var observationFinished = false
        var submitReturnedUptime = 0.0
        var stopDispatchAttemptUptime: TimeInterval?
        var stopDispatchReturnedUptime: TimeInterval?
        var observationAttached = false
        var observationMode = "immediate"
        var windowResult: XCTWaiter.Result = .completed
        func observeStopWindow() -> Bool {
            if observationFinished { return true }
            do {
                let observed = try captureStopObservation()
                observations.append(observed.facts)
                lastObservedIDs = observed.ids
                let elapsed = ProcessInfo.processInfo.systemUptime - submitReturnedUptime
                keyboardDismissed = keyboardDismissed || (observed.keyboardAbsent && elapsed <= 5)
                if observed.ready { acceptedObservation = observed }
                observationFinished = observed.ready || observed.settled
                    || (!keyboardDismissed && elapsed >= 5)
            } catch {
                observationError = String(describing: error); observationFinished = true
            }
            return observationFinished
        }
        func keepStopObservation(_ name: String) throws {
            var facts: [String: Any] = ["keyword": keyword, "requiredPublicProgress": progressLabel,
                "observedCandidateIDs": acceptedObservation?.ids.sorted() ?? lastObservedIDs.sorted(),
                "stopTapCount": stopTapCount, "observation": String(describing: windowResult),
                "stopDispatchAttempted": stopDispatchAttemptUptime != nil, "stopTapCallReturned": stopDispatchReturnedUptime != nil,
                "observationMode": observationMode, "submitReturnedUptime": submitReturnedUptime,
                "keyboardDismissedWithinFiveSeconds": keyboardDismissed, "observations": observations,
                "boundary": "One snapshot tree per observation; paths and semantic identifiers are not opaque AX identities. stopTapCount counts returned Stop-relative tap calls; a dispatch attempt or returned call is not Stop acceptance, which requires the separate stopped partial-state message. Public XCTest does not make snapshot and tap atomic; no cached app coordinate, manufactured response, delay, source or retry is used."]
            if let observationError { facts["snapshotError"] = observationError }
            if let stopDispatchAttemptUptime { facts["stopDispatchAttemptUptime"] = stopDispatchAttemptUptime }
            if let stopDispatchReturnedUptime { facts["stopDispatchReturnedUptime"] = stopDispatchReturnedUptime }
            try attach(name, facts); observationAttached = true
        }
        addTeardownBlock {
            if !observationAttached { try keepStopObservation("real-three-source-partial-stop-snapshot-observation-teardown") }
        }
        submit.tap()
        submitReturnedUptime = ProcessInfo.processInfo.systemUptime
        if !observeStopWindow() {
            observationMode = "bounded-wait-after-immediate-observation"
            let window = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in observeStopWindow() }, object: nil)
            windowResult = XCTWaiter.wait(for: [window], timeout: 30)
        }
        try sourceToolsRequire(windowResult == .completed || windowResult == .timedOut,
            "The one bounded observation must finish normally; no search retry is allowed", app: app)
        try sourceToolsRequire(observationError == nil, "A snapshot failure cannot establish the natural Stop window", app: app)
        try sourceToolsRequire(keyboardDismissed, "Submitting the one real search must dismiss the keyboard within five seconds", app: app)
        guard let selection = acceptedObservation else {
            try keepStopObservation("real-three-source-partial-stop-prerequisite-unavailable")
            throw XCTSkip("The real two-good-source partial-result Stop window was not available; restore the original source state in teardown")
        }
        let beforeStopIDs = selection.ids
        stopDispatchAttemptUptime = ProcessInfo.processInfo.systemUptime
        // Resolve the exact current Stop at dispatch. If it has disappeared or
        // is ambiguous, fail closed; never tap its old app-relative position.
        let liveStop = app.windows.containing(.textField, identifier: "online-search-query").buttons
            .matching(NSPredicate(format: "identifier == %@ AND label == %@", "online-search-stop", "停止")).element
        liveStop.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        stopTapCount = 1
        stopDispatchReturnedUptime = ProcessInfo.processInfo.systemUptime
        try keepStopObservation("real-three-source-partial-stop-snapshot-observation")
        try sourceToolsWait("The one real Stop action must settle", timeout: 20) { !stop.exists }
        let partial = app.staticTexts["搜索已停止，可保留已有结果并重新搜索"]
        guard partial.exists else {
            try attach("real-three-source-partial-stop-natural-window-closed", ["stopTapCount": stopTapCount,
                "candidateIDsBeforeTap": beforeStopIDs.sorted(), "candidateIDsAfterTap": candidateIDs().sorted()])
            throw XCTSkip("The real search settled before Stop acceptance could be established; no second Stop or search retry is allowed")
        }
        let stoppedIDs = candidateIDs()
        try sourceToolsRequire(bothGoodSourcesReturned(stoppedIDs) && stoppedIDs.isSuperset(of: beforeStopIDs)
            && query.value as? String == keyword, "A successful partial Stop must retain the actual good-source candidates and keyword", app: app)
        try restoreOriginalSources(returnToShelf: false)
        try sourceToolsRequire(candidateIDs() == stoppedIDs && partial.exists && query.value as? String == keyword,
            "Restoring the source page must preserve the stopped candidates, partial-state message and keyword", app: app)
        let research = app.buttons["online-research-failed"]
        try sourceToolsRequire(research.exists && research.isEnabled && research.isHittable,
            "Explicitly re-search the same keyword after restoring the original two enabled sources", app: app)
        research.tap()
        try sourceToolsWait("The explicit real two-source re-search must settle", timeout: 45) {
            app.buttons["online-search-submit"].exists && !app.buttons["online-search-stop"].exists
        }
        let researchedIDs = candidateIDs()
        try sourceToolsRequire(researchedIDs.isSuperset(of: stoppedIDs) && query.value as? String == keyword,
            "The explicit two-source re-search must retain every observed stopped candidate and the same keyword", app: app)
        try attach("real-three-source-partial-stop-and-two-source-research-outcome", ["keyword": keyword,
            "temporarilyEnabledExistingSourceID": disabledSourceID, "goodSourceIDs": enabledSourceIDs,
            "publicProgressBeforeStop": progressLabel, "stopTapCount": stopTapCount,
            "candidateIDsBeforeStop": beforeStopIDs.sorted(), "candidateIDsAfterStop": stoppedIDs.sorted(),
            "candidateIDsAfterResearch": researchedIDs.sorted(), "originalSourceStateRestoredBeforeResearch": true,
            "boundary": "One natural three-source partial Stop, exact restoration through source management, then one explicit search of the original two enabled sources. UI identities do not claim raw transport callback or universal source coverage."])

        struct StopSearchTraceProof: Decodable {
            let r: String; let g: String; let n: Int; let e: Int; let f: Int; let c: Int
            let s: String; let h: String; let v: Int
            var fields: [String: Any] {
                ["r": r, "g": g, "n": n, "e": e, "f": f, "c": c, "s": s, "h": h, "v": v]
            }
        }
        var finalTraceProof: StopSearchTraceProof?
        var finalTraceBytes: Data?
        func completeTraceProof() -> Bool {
            let owners = app.staticTexts.matching(identifier: "online-search-trace-owner")
            guard owners.count == 1, let raw = owners.element.value as? String,
                  let bytes = raw.data(using: .utf8), bytes.count <= 256,
                  let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                  Set(object.keys) == Set(["r", "g", "n", "e", "f", "c", "s", "h", "v"]),
                  let value = try? JSONDecoder().decode(StopSearchTraceProof.self, from: bytes),
                  value.r == traceRunID, UUID(uuidString: value.g)?.uuidString.lowercased() == value.g,
                  (1...2).contains(value.n), (0...value.n).contains(value.f), (0...value.n).contains(value.c),
                  (1...4096).contains(value.e), value.v > 0,
                  ["captured", "incomplete"].contains(value.s),
                  value.h.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil else { return false }
            finalTraceProof = value; finalTraceBytes = bytes
            return value.n == 2 && value.f == 2 && value.c == 2
        }
        let traceWaitBegan = ProcessInfo.processInfo.systemUptime
        let traceReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in completeTraceProof() }, object: nil)
        let traceWait = XCTWaiter.wait(for: [traceReady], timeout: 5)
        let traceComplete = traceWait == .completed && finalTraceProof?.n == 2
            && finalTraceProof?.f == 2 && finalTraceProof?.c == 2
        try attach("physical-real-three-source-stop-global-trace-boundary", [
            "mode": traceMode, "runID": traceRunID, "configuredWaitLimitSeconds": 5,
            "observedWaitSeconds": ProcessInfo.processInfo.systemUptime - traceWaitBegan,
            "waitResult": String(describing: traceWait), "twoGenerationCountsComplete": traceComplete,
            "traceProof": finalTraceProof.map { $0.fields as Any } ?? NSNull(),
            "rawRelativePath": "tmp/ReaderOnlineSearchTrace-" + traceRunID + "/trace.json",
            "ownerRelativePath": "tmp/ReaderOnlineSearchTrace-" + traceRunID + "/owner.json",
            "transportQuiescenceProven": false,
            "boundary": "The method does not cold-relaunch its observed search. Both generations must be recorded, observer-finished and strictly Core-retired in this same run (n=f=c=2). Stop may leave the overall trace incomplete; these counters do not establish Host/HTTP closure or OS socket closure. Export the original raw files without relaunching into this run directory; owner.json and snapshot mode/run must match, and raw bytes must match this exact compact h/v and final g. A later SHA revision cannot substitute. Missing counts fail this witness; missing raw/hash correspondence remains INCOMPLETE externally. No extra search, Stop, source mutation, transport delay or automatic retry is authorized by this wait."
        ])
        if let finalTraceBytes {
            let receipt = XCTAttachment(data: finalTraceBytes, uniformTypeIdentifier: "public.json")
            receipt.name = "physical-real-three-source-stop-global-compact-proof"; receipt.lifetime = .keepAlways; add(receipt)
        }
        try sourceToolsRequire(traceComplete,
            "Require this same global trace run's n=f=c=2 within the one five-second wait; incomplete counts cannot pass", app: app)
    }

    /// A separately selected recovery for a sealed failed Stop run. The runner
    /// binds both SHA values to its immutable failure receipt and fresh persisted
    /// source proof. This method only disables the exact original source once;
    /// it performs no search, Stop, import, download or mutating teardown.
    func testRestoreOriginalRealDisabledSourceAfterSealedStopFailure() throws {
#if targetEnvironment(simulator)
        XCTFail("This recovery requires the original physical iPhone")
        throw SourceToolsFailure.prerequisite
#endif
        let environment = ProcessInfo.processInfo.environment
        let receiptSHA = environment["READER_STOP_RECOVERY_FAILED_RECEIPT_SHA256"] ?? ""
        let proofSHA = environment["READER_STOP_RECOVERY_SOURCE_PROOF_SHA256"] ?? ""
        func isSHA256(_ value: String) -> Bool {
            value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
        }
        try sourceToolsRequire(UIDevice.current.userInterfaceIdiom == .phone && isSHA256(receiptSHA) && isSHA256(proofSHA),
            "Require runner-bound sealed Stop failure and fresh persisted source proof SHA256 values", app: nil)
        let sourceID = "http://199.33.126.51"
        let labels = ["online-source:" + sourceID: "👍 同人圈", "online-source:https://m.idejian.com": "得间小说",
            "online-source:https://dushu.baidu.com/": "百度小说"]
        let enabledValues = [sourceID: "1", "https://m.idejian.com": "1", "https://dushu.baidu.com/": "1"]
        var restoredValues = enabledValues; restoredValues[sourceID] = "0"
        let sourceIDs = Set(enabledValues.keys)
        let app = XCUIApplication()
        app.launch()
        openExistingSourceManagement(app)
        try sourceToolsWait("Recovery requires a successful current source read with no unresolved source operation", timeout: 15) {
            guard let state = self.sourceToolsSourceState(app) else { return false }
            return state.revision > 0 && state.read == "ready" && state.operation == "terminal" && state.operationID.isEmpty
        }
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == labels && sourceToolsSourceValues(app, sourceIDs: sourceIDs) == enabledValues,
            "Recover only the exact three original sources while all three are enabled", app: app)
        let initial = try XCTUnwrap(sourceToolsSourceState(app))
        let provenance = XCTAttachment(string: "failedStopReceiptSHA256=\(receiptSHA)\ncurrentPersistedSourceProofSHA256=\(proofSHA)\nsourceId=\(sourceID)\nsourceReadRevision=\(initial.revision)\nRunner validates the receipt bindings; this recovery never reruns search or Stop and never retries a source toggle.")
        provenance.name = "sealed-stop-failure-one-time-source-recovery-inputs"; provenance.lifetime = .keepAlways; add(provenance)
        var disableTapCount = 0
        try sourceToolsDisableExactVisibleSource(app, sourceID: sourceID, labels: labels, values: enabledValues,
            readRevision: initial.revision, tapCount: &disableTapCount) {}
        var operationID: String?
        var changedOperationID: String?
        var pending = false
        try sourceToolsWait("The sole recovery disable must reach terminal status and a newer successful persisted disabled read", timeout: 130) {
            guard let state = self.sourceToolsSourceState(app) else { return false }
            if !state.operationID.isEmpty {
                if let original = operationID, original != state.operationID {
                    changedOperationID = state.operationID; return true
                }
                operationID = state.operationID
            }
            if state.operation == "pending" { pending = true; return true }
            return state.operation == "terminal" && state.operationID.isEmpty && state.read == "ready"
                && state.revision > initial.revision && self.sourceToolsObservedSourceValues(app, sourceIDs: sourceIDs) == restoredValues
        }
        let final = try XCTUnwrap(sourceToolsSourceState(app))
        try sourceToolsRequire(!pending && changedOperationID == nil && disableTapCount == 1
            && final.operation == "terminal" && final.operationID.isEmpty && final.read == "ready" && final.revision > initial.revision
            && sourceToolsSourceLabels(app) == labels && sourceToolsSourceValues(app, sourceIDs: sourceIDs) == restoredValues,
            "Only the sole source disable and its fresh terminal read confirm recovery; pending or another operation must stop without another mutation", app: app)
        let result = XCTAttachment(string: "sourceId=\(sourceID)\ndisableTapCount=\(disableTapCount)\nsourceReadRevisionBefore=\(initial.revision)\nsourceReadRevisionAfter=\(final.revision)\nobservedOperationID=\(operationID ?? "not-observed-before-terminal-read")\nUI source values are 0/1/1. Runner must independently compare persisted source definitions, Host operations and protected downloads; the sealed original Stop result remains FAIL.")
        result.name = "sealed-stop-failure-one-time-source-recovery-terminal-read"; result.lifetime = .keepAlways; add(result)
        keepScreenshot(app, name: "sealed-stop-failure-original-disabled-source-restored")
        leaveExistingSourceManagement(app)
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

    private func revealSourceFile(_ file: XCUIElement, app: XCUIApplication) {
        let scroll = app.scrollViews["online-source-scroll"]
        XCTAssertTrue(scroll.exists, app.debugDescription)
        for _ in 0..<40 {
            let frame = file.frame
            if file.exists && file.isEnabled && frame.width > 0 && frame.height > 0 && app.frame.intersects(frame) { return }
            scroll.swipeDown()
        }
        let frame = file.frame
        XCTAssertTrue(file.exists && file.isEnabled && frame.width > 0 && frame.height > 0 && app.frame.intersects(frame),
                      "The real source file control must be reachable by normal scrolling\n" + app.debugDescription)
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

    /// One explicit admission of the already observed real Baidu candidate.
    /// Runner-only preproof binds the stopped physical library; it supplies no
    /// App state, source definitions, response, URL override or task mutation.
    func testPhysicalExistingRealBaiduCandidateAdmissionAndColdShelfRetentionPreservesOriginalBook() throws {
        struct Chapter: Decodable {
            let index: UInt32
            let title: String
            let url: String
        }
        struct Preproof: Decodable {
            let schemaVersion: Int
            let policy: String
            let capturedAtUTC: String
            let targetUDID: String
            let bundleID: String
            let snapshotSHA256: String
            let protectedSHA256: [String: String]
            let sourceId: String
            let sourceEnabled: Bool
            let bookId: String
            let title: String
            let chapters: [Chapter]
            let cachedIndexes: [UInt32]
            let taskCount: Int
            let inShelf: Bool
            let hasReadingProgress: Bool
            let originalSourceId: String
            let originalBookId: String
            let originalTitle: String
            let originalChapterIndex: UInt32
            let originalShelfBookIds: [String]
            let originalCompletedTaskCount: Int
            let originalFailedTaskCount: Int
            let originalPhysicalBodyCount: Int
            let pendingOperationCount: Int
        }
#if targetEnvironment(simulator)
        XCTFail("This admission requires the original physical iPhone free-bundle library")
        throw SourceToolsFailure.prerequisite
#endif
        let environment = ProcessInfo.processInfo.environment
        let raw = try XCTUnwrap(environment["READER_PHYSICAL_ADMISSION_PREPROOF_JSON"])
        let expectedSHA = try XCTUnwrap(environment["READER_PHYSICAL_ADMISSION_PREPROOF_SHA256"])
        let snapshotSHA = try XCTUnwrap(environment["READER_PHYSICAL_ADMISSION_SNAPSHOT_SHA256"])
        let target = try XCTUnwrap(environment["READER_PHYSICAL_TARGET_UDID"])
        let sourceID = "https://dushu.baidu.com/"
        let bookID = "https://boxnovel.baidu.com/boxnovel/wiseapi/chapterList?bookid=4345127024&pageNum=1&order=asc&site="
        let title = "等到鸢尾纯白"
        let originalBookID = "https://boxnovel.baidu.com/boxnovel/wiseapi/chapterList?bookid=4305547728&pageNum=1&order=asc&site="
        let bytes = Data(raw.utf8)
        func isSHA(_ value: String) -> Bool {
            value.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil
        }
        try sourceToolsRequire(bytes.count <= 32 * 1024 && isSHA(expectedSHA)
            && SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() == expectedSHA,
            "Bind the exact external physical admission preproof before launching the App", app: nil)
        let proof = try JSONDecoder().decode(Preproof.self, from: bytes)
        let timestamp = ISO8601DateFormatter()
        timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let captured = timestamp.date(from: proof.capturedAtUTC)
            ?? ISO8601DateFormatter().date(from: proof.capturedAtUTC)
        let age = captured.map { Date().timeIntervalSince($0) }
        let protectedKeys: Set<String> = ["library", "files", "sources", "ledger", "originalBook",
                                          "originalProgress", "originalTasks", "originalBodies"]
        try sourceToolsRequire(UIDevice.current.userInterfaceIdiom == .phone
            && environment["SIMULATOR_UDID"] == nil
            && proof.schemaVersion == 1 && proof.policy == "physical-real-baidu-candidate-admission-v1"
            && age.map { (0...1800).contains($0) } == true
            && target.range(of: #"^(?:[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40})$"#, options: .regularExpression) != nil
            && proof.targetUDID == target && proof.bundleID == "io.reader.minliny.free"
            && isSHA(snapshotSHA) && proof.snapshotSHA256 == snapshotSHA
            && Set(proof.protectedSHA256.keys) == protectedKeys && proof.protectedSHA256.values.allSatisfy(isSHA)
            && proof.sourceId == sourceID && proof.sourceEnabled && proof.bookId == bookID && proof.title == title
            && proof.chapters.map(\.index) == Array(UInt32(0)..<UInt32(50))
            && proof.chapters.allSatisfy({ chapter in
                !chapter.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && chapter.url.hasPrefix("https://dushu.baidu.com/api/pc/getChapterContent?")
            })
            && proof.cachedIndexes == [0] && proof.taskCount == 0 && !proof.inShelf && !proof.hasReadingProgress
            && proof.originalSourceId == sourceID && proof.originalBookId == originalBookID
            && proof.originalTitle == "剑来" && proof.originalChapterIndex < 50
            && proof.originalShelfBookIds == [originalBookID]
            && proof.originalCompletedTaskCount == 50 && proof.originalFailedTaskCount == 1
            && proof.originalPhysicalBodyCount == 57 && proof.pendingOperationCount == 0,
            "Require the fresh stopped original library, protected 50 completed tasks and untouched real candidate directory/cache facts; no replacement library is accepted", app: nil)
        let preproof = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        preproof.name = "physical-real-baidu-admission-external-preproof"; preproof.lifetime = .keepAlways; add(preproof)

        let app = XCUIApplication(bundleIdentifier: proof.bundleID)
        try sourceToolsRequire(app.state == .notRunning,
            "Root must stop the original App before capturing the preproof and selecting this cold journey", app: app)
        func button(_ identifier: String) throws -> XCUIElement {
            let matches = app.buttons.matching(NSPredicate(format: "identifier == %@", identifier))
            try sourceToolsRequire(matches.count == 1, "Require one exact native button: " + identifier, app: app)
            return matches.element
        }
        func tap(_ identifier: String) throws {
            let value = try button(identifier)
            try sourceToolsRequire(value.isEnabled && value.isHittable,
                "The exact native action must be enabled and hittable; no coordinate or alternate-result fallback: " + identifier, app: app)
            value.tap()
        }
        func tapLabel(_ label: String) throws {
            let matches = app.buttons.matching(NSPredicate(format: "label == %@", label))
            try sourceToolsWait("Require one exact visible native menu label: " + label, timeout: 10) {
                matches.count == 1 && matches.element.isEnabled && matches.element.isHittable
            }
            matches.element.tap()
        }
        func shelfBookIds() -> [String] {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "book-"))
                .allElementsBoundByIndex.map { String($0.identifier.dropFirst("book-".count)) }.sorted()
        }
        addTeardownBlock {
            // An assertion failure must leave the original library stopped for
            // postproof; an accepted admission is never rolled back or cleared.
            if app.state != .notRunning { app.terminate() }
            let attachment = XCTAttachment(string: "External full original-data postproof is required after every outcome. Teardown only stops the current original App; it never rolls back an admission, changes sources, clears data or replays an operation.")
            attachment.name = "physical-real-baidu-admission-failure-postproof-required"
            attachment.lifetime = .keepAlways; self.add(attachment)
        }
        app.launch()
        try sourceToolsWait("Require the complete original unfiltered shelf before one new admission", timeout: 25) {
            app.buttons["更多书架操作"].exists && !app.textFields["shelf-filter"].exists
                && shelfBookIds() == proof.originalShelfBookIds.sorted()
        }
        let originalShelfLabel = try button("book-" + originalBookID).label
        try sourceToolsRequire(originalShelfLabel.contains(proof.originalTitle), "The original shelf row must identify 剑来", app: app)
        try tapLabel("更多书架操作"); try tapLabel("搜索与书源")
        let queryMatches = app.textFields.matching(NSPredicate(format: "identifier == %@", "online-search-query"))
        try sourceToolsWait("The normal online workspace must expose one real search field", timeout: 15) { queryMatches.count == 1 }
        let query = queryMatches.element
        let oldQuery = query.value as? String
        try sourceToolsRequire(query.isHittable && (oldQuery == nil || oldQuery == "" || oldQuery == "书名或作者"),
            "Preserve any unexpected search owner instead of replacing its query", app: app)
        query.tap(); query.typeText(title)
        try sourceToolsRequire(query.value as? String == title, "Search only the exact observed real candidate title", app: app)
        try tap("online-search-submit")
        let identity = sourceID + "|" + bookID
        let candidateID = "online-result:" + identity
        let candidates = app.buttons.matching(NSPredicate(format: "identifier == %@", candidateID))
        try sourceToolsWait("The current real search must finish with this exact single Baidu candidate", timeout: 180) {
            !app.buttons["online-search-stop"].exists && candidates.count == 1
        }
        try sourceToolsRequire(candidates.element.label.contains(title), "The exact source/book result must carry its real title", app: app)
        try tap(candidateID)
        let selected = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "online-selected:" + identity))
        let detail = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "online-detail-book:" + bookID))
        try sourceToolsWait("The selected exact source/book must provide its real detail and directory", timeout: 120) {
            selected.count == 1 && detail.count == 1 && detail.element.label == title
                && app.staticTexts["目录 · 50 章"].exists
        }
        try sourceToolsRequire(selected.element.label == "百度小说", "The admission must remain bound to the original Baidu source", app: app)
        let admission = try button("online-add-and-read")
        try sourceToolsWait("The real detail must permit its one explicit admission", timeout: 15) { admission.isEnabled }
        for _ in 0..<8 {
            if admission.isHittable { break }
            let scrolls = app.scrollViews.matching(NSPredicate(format: "identifier == %@", "online-detail-scroll"))
            try sourceToolsRequire(scrolls.count == 1 && scrolls.element.isHittable,
                "Reveal the exact admission action only through its normal detail scroll", app: app)
            scrolls.element.swipeDown()
        }
        keepScreenshot(app, name: "physical-real-baidu-candidate-before-explicit-admission")
        try tap("online-add-and-read")
        let body = app.textViews["reading-body"]
        assertNativeBody(body, in: app, timeout: 180)
        if !app.buttons["leave-reader"].isHittable {
            body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        }
        let readingBook = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "reading-book:" + identity))
        try sourceToolsWait("The actual reading controls must identify only the admitted candidate at its first chapter", timeout: 15) {
            readingBook.count == 1 && readingBook.element.label == title
                && app.staticTexts["reading-chapter:0"].exists && app.buttons["leave-reader"].isHittable
        }
        keepScreenshot(app, name: "physical-real-baidu-candidate-admitted-reading-identity")
        try tap("leave-reader")
        try sourceToolsWait("Normal reader exit must return to this same selected detail", timeout: 20) {
            selected.count == 1 && detail.count == 1 && app.buttons["online-back-search"].isHittable
        }
        try tap("online-back-search"); try tap("online-close-workspace")
        let expectedShelf = [originalBookID, bookID].sorted()
        try sourceToolsWait("The shelf must contain the original book and exactly the one admitted candidate", timeout: 25) {
            shelfBookIds() == expectedShelf && !app.textViews["reading-body"].exists
        }
        try sourceToolsRequire(try button("book-" + originalBookID).label == originalShelfLabel,
            "The original 剑来 shelf projection must remain unchanged", app: app)
        try sourceToolsRequire(try button("book-" + bookID).label.contains(title), "The new shelf row must identify the admitted title", app: app)
        app.terminate()
        try sourceToolsRequire(app.wait(for: .notRunning, timeout: 10), "Normal exit must finish before the cold shelf check", app: app)
        app.launch()
        try sourceToolsWait("Cold startup must retain both exact shelf identities without opening either reader", timeout: 30) {
            app.buttons["更多书架操作"].exists && shelfBookIds() == expectedShelf && !app.textViews["reading-body"].exists
        }
        try sourceToolsRequire(try button("book-" + originalBookID).label == originalShelfLabel,
            "Cold startup must preserve the original shelf projection", app: app)
        try sourceToolsRequire(try button("book-" + bookID).label.contains(title), "Cold startup must retain the real candidate title", app: app)
        keepScreenshot(app, name: "physical-real-baidu-candidate-cold-two-book-shelf")
        app.terminate()
        try sourceToolsRequire(app.wait(for: .notRunning, timeout: 10), "Leave the App stopped for the independent postproof snapshot", app: app)
        let boundary = XCTAttachment(string: "preproofSHA256=\(expectedSHA)\nsnapshotSHA256=\(snapshotSHA)\ntargetUDID=\(target)\nbundleID=\(proof.bundleID)\nadmittedIdentity=\(identity)\noriginalIdentity=\(sourceID)|\(originalBookID)\nOne explicit real admission and first-chapter read only. New candidate shelf/progress, normal reading-window cache, admission/read-time commands and global continue-card attribution may change. Root must independently compare every original source, shelf row, 50 completed task rows, failed task, original body, progress and retained command after this method. No download control, whole/finite download dispatch, source management/import, cleanup or source switch is selected. Native pause/resume/cancel remain OPEN.")
        boundary.name = "physical-real-baidu-candidate-admission-postproof-required"; boundary.lifetime = .keepAlways; add(boundary)
    }

    /// Continues only the retained unknown admission, once, through its explicit
    /// UI action. The external stopped-library proof supplies identities and
    /// hashes, never App state, a body, a response or replacement source data.
    func testPhysicalExistingRealBaiduUnknownAdmissionExplicitContinuationAndColdShelfRetentionPreservesOriginalBook() throws {
        struct Source: Decodable { let id: String; let name: String; let enabled: Bool }
        struct Chapter: Decodable { let index: UInt32; let title: String; let url: String }
        struct PendingAdd: Decodable {
            let sourceId: String; let bookId: String; let title: String; let requireReadable: Bool
        }
        struct CoreIntent: Decodable {
            let sha256: String; let sourceId: String; let bookId: String; let reason: String
            let state: String; let revision: Int; let sourceVersion: String
            let pendingAdd: PendingAdd; let pendingAddMatchesOriginalParameters: Bool
        }
        struct Preparation: Decodable {
            let operationID: String; let method: String; let scope: String; let commandSHA256: String
            let completed: Bool; let resultPresent: Bool; let failurePresent: Bool
            let action: String; let reason: String; let sourceId: String; let bookId: String
            let pendingAdd: PendingAdd; let pendingAddMatchesOriginalParameters: Bool
            let coreIntent: CoreIntent
        }
        struct UnknownAdmission: Decodable {
            let operationID: String; let method: String; let scope: String
            let commandSHA256: String; let descriptorSHA256: String
            let completed: Bool; let resultPresent: Bool; let failurePresent: Bool
            let sourceId: String; let bookId: String; let title: String
            let chapterIndex: UInt32; let chapterTitle: String; let chapterURL: String
            let preparation: Preparation
        }
        struct CompletedStopSourceUpdate: Decodable {
            let operationID: String; let commandSHA256: String; let method: String; let scope: String
            let mutationMethod: String; let sourceId: String; let enabled: Bool; let sequence: Int
            let completed: Bool; let resultPresent: Bool; let failurePresent: Bool
        }
        struct Preproof: Decodable {
            let schemaVersion: Int; let policy: String; let capturedAtUTC: String
            let historicalDraft: Bool; let captureFactsSHA256: String
            let stoppedPhysicalApp: Bool; let preserveDataUpdateVerified: Bool
            let targetUDID: String; let bundleID: String; let snapshotSHA256: String
            let protectedSHA256: [String: String]
            let sourcePackageSHA256: String; let sourcePackageBytes: Int; let sources: [Source]
            let sourceId: String; let bookId: String; let title: String; let chapters: [Chapter]
            let cachedIndexes: [UInt32]; let taskCount: Int; let inShelf: Bool; let hasReadingProgress: Bool
            let originalSourceId: String; let originalBookId: String; let originalTitle: String
            let originalChapterIndex: UInt32; let originalScalarOffset: UInt64; let originalShelfBookIds: [String]
            let originalCompletedTaskCount: Int; let originalFailedTaskCount: Int; let originalPhysicalBodyCount: Int
            let hostCommandCount: Int; let pendingOperationCount: Int; let pendingOperationIDs: [String]
            let originalHostCommandCount: Int; let originalHostCommandSHA256: String
            let allOriginalHostCommandBytesExact: Bool; let completedStopSourceUpdates: [CompletedStopSourceUpdate]
            let pendingAdmission: UnknownAdmission; let independentFullPostproofRequired: Bool
        }
#if targetEnvironment(simulator)
        XCTFail("This continuation requires the original physical iPhone free-bundle library")
        throw SourceToolsFailure.prerequisite
#endif
        let environment = ProcessInfo.processInfo.environment
        let raw = try XCTUnwrap(environment["READER_PHYSICAL_ADMISSION_CONTINUATION_PREPROOF_JSON"])
        let expectedSHA = try XCTUnwrap(environment["READER_PHYSICAL_ADMISSION_CONTINUATION_PREPROOF_SHA256"])
        let snapshotSHA = try XCTUnwrap(environment["READER_PHYSICAL_ADMISSION_CONTINUATION_SNAPSHOT_SHA256"])
        let target = try XCTUnwrap(environment["READER_PHYSICAL_TARGET_UDID"])
        let operationID = "0ad35be2-67cd-43a0-b4b4-34e98814e40d"
        let sourceID = "https://dushu.baidu.com/"
        let bookID = "https://boxnovel.baidu.com/boxnovel/wiseapi/chapterList?bookid=4345127024&pageNum=1&order=asc&site="
        let title = "等到鸢尾纯白"
        let originalBookID = "https://boxnovel.baidu.com/boxnovel/wiseapi/chapterList?bookid=4305547728&pageNum=1&order=asc&site="
        let identity = sourceID + "|" + bookID
        let originalIdentity = sourceID + "|" + originalBookID
        func isSHA(_ value: String) -> Bool { value.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil }
        let bytes = Data(raw.utf8)
        try sourceToolsRequire(bytes.count <= 48 * 1024 && isSHA(expectedSHA)
            && SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() == expectedSHA,
            "Bind the exact fresh external continuation preproof before launching the original App", app: nil)
        let proof = try JSONDecoder().decode(Preproof.self, from: bytes)
        let timestamp = ISO8601DateFormatter(); timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let captured = timestamp.date(from: proof.capturedAtUTC) ?? ISO8601DateFormatter().date(from: proof.capturedAtUTC)
        let requiredProtectedKeys: Set<String> = ["library", "files", "sources", "ledger", "originalBook",
            "originalProgress", "originalTasks", "originalBodies", "hostCommands", "historicalHostBaseline", "completedStopSourceUpdates"]
        try sourceToolsRequire(UIDevice.current.userInterfaceIdiom == .phone && environment["SIMULATOR_UDID"] == nil
            && proof.schemaVersion == 2 && proof.policy == "physical-real-baidu-admission-continuation-after-stop-v2"
            && !proof.historicalDraft && isSHA(proof.captureFactsSHA256)
            && proof.stoppedPhysicalApp && proof.preserveDataUpdateVerified
            && captured.map { (0...1800).contains(Date().timeIntervalSince($0)) } == true
            && target.range(of: #"^(?:[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40})$"#, options: .regularExpression) != nil
            && proof.targetUDID == target && proof.bundleID == "io.reader.minliny.free"
            && environment["READER_PHYSICAL_ADMISSION_CONTINUATION_OPERATION_ID"] == operationID
            && environment["READER_PHYSICAL_ADMISSION_CONTINUATION_ATTEMPT"] == "1"
            && isSHA(snapshotSHA) && proof.snapshotSHA256 == snapshotSHA
            && requiredProtectedKeys.isSubset(of: Set(proof.protectedSHA256.keys))
            && proof.protectedSHA256.values.allSatisfy(isSHA) && proof.independentFullPostproofRequired,
            "Require one externally selected physical attempt, its exact stopped-library snapshot and complete original-data protection hashes", app: nil)
        let knownSources: [String: String] = [sourceID: "百度小说", "https://m.idejian.com": "得间小说", "http://199.33.126.51": "👍 同人圈"]
        try sourceToolsRequire(proof.sourcePackageSHA256 == "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322"
            && proof.sourcePackageBytes == 5606 && proof.sources.count == 3 && Set(proof.sources.map(\.id)).count == 3
            && proof.sources.allSatisfy { knownSources[$0.id] == $0.name && $0.enabled == ($0.id != "http://199.33.126.51") }
            && proof.sourceId == sourceID && proof.bookId == bookID && proof.title == title
            && proof.chapters.map(\.index) == Array(UInt32(0)..<UInt32(50))
            && proof.chapters.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.url.hasPrefix("https://dushu.baidu.com/api/pc/getChapterContent?") }
            && proof.cachedIndexes == [0] && proof.taskCount == 0 && !proof.inShelf && !proof.hasReadingProgress
            && proof.originalSourceId == sourceID && proof.originalBookId == originalBookID && proof.originalTitle == "剑来"
            && proof.originalChapterIndex == 40 && proof.originalScalarOffset == 0 && proof.originalShelfBookIds == [originalBookID]
            && proof.originalCompletedTaskCount == 50 && proof.originalFailedTaskCount == 1 && proof.originalPhysicalBodyCount == 57
            && proof.hostCommandCount == 583 && proof.originalHostCommandCount == 581
            && proof.originalHostCommandSHA256 == "90c64359624b004e9b5ca0f09c5c585a1f700eb01df21cad899e59518814c3a1"
            && proof.allOriginalHostCommandBytesExact && proof.pendingOperationCount == 1 && proof.pendingOperationIDs == [operationID],
            "Require the original three sources, protected original book/progress/tasks/bodies and only the retained unknown candidate owner", app: nil)
        let expectedStopUpdates: [(operationID: String, sha: String, enabled: Bool, sequence: Int)] = [
            ("757453de-2016-46dd-bd32-af1073a83f7b", "fd5a63c1a77cdc1053d5692d3e9b093dca9ea3ee3eb0d127cb94daa3e543e8ea", true, 24),
            ("e4e09ddb-cabf-442b-a8d5-ac7b5acb12d6", "77ae6aee6933b8839556e0a48b87bf5c648bc16e91acd63b62575720cb8be047", false, 25)
        ]
        try sourceToolsRequire(proof.completedStopSourceUpdates.count == expectedStopUpdates.count
            && expectedStopUpdates.indices.allSatisfy { index in
                let actual = proof.completedStopSourceUpdates[index], expected = expectedStopUpdates[index]
                return actual.operationID == expected.operationID && actual.commandSHA256 == expected.sha
                    && actual.method == "rules.mutation.apply" && actual.scope == "rules-mutation"
                    && actual.mutationMethod == "source.update" && actual.sourceId == "http://199.33.126.51"
                    && actual.enabled == expected.enabled && actual.sequence == expected.sequence
                    && actual.completed && actual.resultPresent && !actual.failurePresent
            }, "Require only the two completed Stop source updates in addition to all 581 original command bytes", app: nil)
        let pending = proof.pendingAdmission, preparation = pending.preparation, intent = preparation.coreIntent
        func matchesCandidate(_ add: PendingAdd) -> Bool {
            add.sourceId == sourceID && add.bookId == bookID && add.title == title && add.requireReadable
        }
        try sourceToolsRequire(pending.operationID == operationID && pending.method == "bookshelf.add"
            && pending.scope == "shelf-add:" + identity
            && pending.commandSHA256 == "b8da0dd291ca82d63ba2afb88a9e371a280cfd130317c6d7e5e167f0e93a8f82"
            && pending.descriptorSHA256 == "f8eb6db590458d31ac5a60cbccdc2ef43b703867fc055d61acdd306701f61855"
            && !pending.completed && !pending.resultPresent && !pending.failurePresent
            && pending.sourceId == sourceID && pending.bookId == bookID && pending.title == title
            && pending.chapterIndex == 0 && pending.chapterTitle == proof.chapters[0].title && pending.chapterURL == proof.chapters[0].url
            && preparation.operationID == operationID + ":preparation" && preparation.method == "reading.preparation"
            && preparation.scope == "online-preparation:" + identity
            && preparation.commandSHA256 == "c3feb8f93a79776d5402763d8187b8730ff04b269272339d27fef810f08d8c67"
            && preparation.completed && preparation.resultPresent && !preparation.failurePresent
            && preparation.action == "begin" && preparation.reason == "add" && preparation.sourceId == sourceID && preparation.bookId == bookID
            && matchesCandidate(preparation.pendingAdd) && preparation.pendingAddMatchesOriginalParameters
            && isSHA(intent.sha256) && intent.sourceId == sourceID && intent.bookId == bookID && intent.reason == "add"
            && intent.state == "active" && intent.revision == 1
            && intent.sourceVersion == "47ff0e3312f354175e488ce582fcf699d0dc7a486a6f69903a0bb2b7f5894ce3"
            && matchesCandidate(intent.pendingAdd) && intent.pendingAddMatchesOriginalParameters,
            "Bind the original unknown Host bytes and descriptor to its completed preparation receipt and exact active Core intent; a Host completion alone is not a terminal intent", app: nil)
        let preproof = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        preproof.name = "physical-real-baidu-admission-continuation-external-preproof"; preproof.lifetime = .keepAlways; add(preproof)
        let app = XCUIApplication(bundleIdentifier: proof.bundleID)
        var startupAppState = "unobserved"
        var startupNormalizationAttempted = false
        var continuationTapCount = 0
        let originalResumeTapCount = 0
        var resumeFeatureObserved = false, continuedMessageObserved = false, coldTwoBookShelfObserved = false
        func buttons(_ identifier: String) -> XCUIElementQuery { app.buttons.matching(NSPredicate(format: "identifier == %@", identifier)) }
        func tap(_ identifier: String) throws {
            let values = buttons(identifier)
            try sourceToolsRequire(values.count == 1 && values.element.isEnabled && values.element.isHittable,
                "Require one exact native action without coordinate or alternate-action fallback: " + identifier, app: app)
            values.element.tap()
        }
        func tapLabel(_ label: String) throws {
            let values = app.buttons.matching(NSPredicate(format: "label == %@", label))
            try sourceToolsRequire(values.count == 1 && values.element.isEnabled && values.element.isHittable,
                "Require one exact visible native label: " + label, app: app)
            values.element.tap()
        }
        func shelfBookIds() -> [String] {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "book-"))
                .allElementsBoundByIndex.map { String($0.identifier.dropFirst("book-".count)) }.sorted()
        }
        func showReadingIdentity(_ expectedIdentity: String, title: String, chapter: UInt32) throws {
            if !app.buttons["leave-reader"].isHittable {
                app.textViews["reading-body"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
            }
            let book = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "reading-book:" + expectedIdentity))
            let chapters = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "reading-chapter:"))
            try sourceToolsWait("The native controls must identify the exact real source/book/chapter", timeout: 15) {
                book.count == 1 && book.element.label == title && chapters.count == 1
                    && chapters.element.identifier == "reading-chapter:" + String(chapter) && app.buttons["leave-reader"].isHittable
            }
        }
        addTeardownBlock {
            // Save the attempt facts even if process shutdown later fails. A
            // failed attachment must still stop the App for external postproof.
            defer {
                if app.state != .notRunning { app.terminate() }
                XCTAssertTrue(app.wait(for: .notRunning, timeout: 10),
                    "Stop the original App for independent preserve-data postproof")
            }
            let facts: [String: Any] = ["preproofSHA256": expectedSHA, "snapshotSHA256": snapshotSHA,
                "operationID": operationID, "candidateIdentity": identity, "originalIdentity": originalIdentity,
                "startupAppState": startupAppState, "startupNormalizationAttempted": startupNormalizationAttempted,
                "continuationTapCount": continuationTapCount, "originalResumeTapCount": originalResumeTapCount,
                "resumeFeatureObserved": resumeFeatureObserved, "continuedMessageObserved": continuedMessageObserved,
                "coldTwoBookShelfObserved": coldTwoBookShelfObserved, "independentFullOriginalDataPostproofRequired": true,
                "boundary": "One explicit continue-admission tap only. resume-feature is observed, never tapped. Unknown/failure stops without retry, replacement, rollback, cleanup or uninstall. UI reads prove real candidate chapter0 and original chapter40 visibility; exact original scalar/body/source/task/file/command retention requires Root's independent full postproof after App and Runner stop. Normal reading-time and reading-window cache changes must be attributed separately."]
            let data = try JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys])
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "physical-real-admission-continuation-one-attempt-and-postproof-boundary"
            attachment.lifetime = .keepAlways; self.add(attachment)
        }
        // XCTest may start the target in the background after the external
        // stopped preproof. Normalize that process before the explicit cold launch.
        let observedStartupState = app.state
        startupAppState = String(describing: observedStartupState)
        if observedStartupState != .notRunning {
            startupNormalizationAttempted = true
            app.terminate()
        }
        try sourceToolsRequire(app.wait(for: .notRunning, timeout: 10),
            "Stop only XCTest's startup App before the explicit cold launch", app: nil)
        app.launch()
        try sourceToolsRequire(app.wait(for: .runningForeground, timeout: 20),
            "The original Reader App must reach the foreground after its cold launch", app: nil)
        try sourceToolsWait("Cold startup must retain the original single-book shelf before explicit continuation", timeout: 30) {
            app.buttons["更多书架操作"].exists && !app.textFields["shelf-filter"].exists
                && shelfBookIds() == proof.originalShelfBookIds.sorted() && !app.textViews["reading-body"].exists
                && app.staticTexts["原操作待核对"].exists
        }
        let originalRows = buttons("book-" + originalBookID)
        try sourceToolsRequire(originalRows.count == 1 && originalRows.element.label.contains(proof.originalTitle),
            "Require the original 剑来 shelf identity", app: app)
        let originalShelfLabel = originalRows.element.label
        try tapLabel("查看")
        let continuationID = "continue-admission-" + operationID
        let continuation = buttons(continuationID)
        let originalResume = buttons("resume-feature-" + operationID)
        try sourceToolsWait("Expose only the retained original admission's explicit continuation action", timeout: 20) {
            app.staticTexts["原操作核对"].exists && continuation.count == 1 && continuation.element.isEnabled && continuation.element.isHittable
        }
        let allContinuations = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "continue-admission-"))
        try sourceToolsRequire(allContinuations.count == 1 && app.staticTexts["在线书籍入库"].exists,
            "A second admission owner is a stop condition", app: app)
        resumeFeatureObserved = originalResume.count == 1
        keepScreenshot(app, name: "physical-real-admission-continuation-before-only-explicit-tap")
        try sourceToolsRequire(continuationTapCount == 0 && originalResumeTapCount == 0,
            "This method permits exactly one continuation tap and no original-resume or new-admission tap", app: app)
        continuationTapCount += 1
        try tap(continuationID)
        try sourceToolsWait("The one continuation must finish with the explicit continued result; pending/unknown never triggers another tap", timeout: 180) {
            app.staticTexts["已继续完成入库"].exists && continuation.count == 0 && originalResume.count == 0
        }
        continuedMessageObserved = true
        keepScreenshot(app, name: "physical-real-admission-continuation-explicit-continued-result")
        try tapLabel("关闭")
        let expectedShelf = [originalBookID, bookID].sorted()
        try sourceToolsWait("The continued result must correspond to exactly the original and actual admitted shelf entries", timeout: 30) {
            shelfBookIds() == expectedShelf && !app.textViews["reading-body"].exists
        }
        try sourceToolsRequire(buttons("book-" + originalBookID).element.label == originalShelfLabel
            && buttons("book-" + bookID).element.label.contains(title), "Retain the original shelf projection alongside the actual candidate", app: app)
        try tap("book-" + bookID)
        let body = app.textViews["reading-body"]
        assertNativeBody(body, in: app, timeout: 180)
        try showReadingIdentity(identity, title: title, chapter: 0)
        keepScreenshot(app, name: "physical-real-admission-continuation-real-candidate-first-chapter")
        try tap("leave-reader")
        try sourceToolsWait("Normal candidate exit must return to the two real shelf entries", timeout: 25) { shelfBookIds() == expectedShelf && !body.exists }
        app.terminate()
        try sourceToolsRequire(app.wait(for: .notRunning, timeout: 10), "Finish the normal stop before cold double-shelf retention", app: nil)
        app.launch()
        try sourceToolsWait("Cold startup must retain both exact books before opening the original reader", timeout: 30) {
            app.buttons["更多书架操作"].exists && shelfBookIds() == expectedShelf && !body.exists
        }
        coldTwoBookShelfObserved = true
        try sourceToolsRequire(buttons("book-" + originalBookID).element.label == originalShelfLabel
            && buttons("book-" + bookID).element.label.contains(title), "Cold startup must retain both titles and the original shelf projection", app: app)
        keepScreenshot(app, name: "physical-real-admission-continuation-cold-two-book-shelf")
        try tap("book-" + originalBookID)
        assertNativeBody(body, in: app, timeout: 180)
        try showReadingIdentity(originalIdentity, title: proof.originalTitle, chapter: proof.originalChapterIndex)
        keepScreenshot(app, name: "physical-real-admission-continuation-original-book-retained-chapter")
        try tap("leave-reader")
        try sourceToolsWait("Return both books without chapter navigation or progress manipulation", timeout: 25) { shelfBookIds() == expectedShelf && !body.exists }
        try sourceToolsRequire(buttons("book-" + originalBookID).element.label == originalShelfLabel
            && continuationTapCount == 1 && originalResumeTapCount == 0,
            "The original shelf projection and one-tap continuation boundary must remain intact; exact progress is independently compared outside XCTest", app: app)
        app.terminate()
        try sourceToolsRequire(app.wait(for: .notRunning, timeout: 10), "Leave the original App stopped for Root's full independent postproof", app: nil)
    }

    /// Reads the already completed r5 admission through two ordinary cold
    /// shelf entries. This selector never submits or resumes an admission.
    /// Runner-only proof bytes bind real external stopped-phone evidence; no
    /// proof, body, source or state is forwarded to the target application.
    func testPhysicalCompletedRealBaiduAdmissionColdTwoBookReadingPreservesOriginalPosition() throws {
        struct Source: Decodable { let id: String; let name: String; let enabled: Bool }
        struct Book: Decodable {
            let sourceId: String; let bookId: String; let title: String
            let chapterIndex: UInt32; let chapterTitle: String; let chapterURL: String; let scalarOffset: UInt64
            let cachedIndexes: [UInt32]; let taskCount: Int; let hasReadingProgress: Bool
            let bodyRowSHA256: String; let contentSHA256: String; let catalogSHA256: String
        }
        struct Host: Decodable {
            let count: Int; let rawMapSHA256: String; let all584BaselineCommandsRawExact: Bool
            let historicalCount: Int; let historicalSHA256: String; let pendingOperationIDs: [String]
            let originalOperationID: String; let originalCommandSHA256: String; let originalStillUnknown: Bool
            let childOperationID: String; let childCommandSHA256: String; let childCompleted: Bool
            let childCreated: Bool; let childOriginalParameterBytesExact: Bool; let onlyOneContinuationChild: Bool
            let descriptorSHA256: String; let descriptorCompletionKind: String
            let candidateIntentRevision: Int; let candidateIntentReason: String; let candidateIntentState: String
            let candidateIntentPendingAddAbsent: Bool; let candidateIntentSourceVersion: String
            let originalIntentRevision: Int; let originalIntentReason: String; let originalIntentState: String
        }
        struct Preproof: Decodable {
            let schemaVersion: Int; let policy: String; let historicalDraft: Bool; let capturedAtUTC: String
            let targetUDID: String; let bundleID: String; let snapshotSHA256: String
            let captureFactsSHA256: String; let artifactBindingSHA256: String; let artifactSchemaVersion: Int
            let appSignedTreeSHA256: String; let runnerSignedTreeSHA256: String; let sourceManifestSHA256: String
            let sameSourceAppAndRunner: Bool; let newAppInstalled: Bool; let newRunnerInstalled: Bool
            let r5BaselineSnapshotSHA256: String; let r5CaptureFactsSHA256: String
            let r5TestExitSHA256: String; let r5CaptureResultSHA256: String; let r5TestExitCode: Int
            let stoppedPhysicalApp: Bool; let preserveDataUpdateVerified: Bool; let allBaselineProtectedDataExact: Bool
            let protectedSHA256: [String: String]; let sourcePackageSHA256: String; let sourcePackageBytes: Int
            let sources: [Source]; let expectedShelfBookIds: [String]; let candidate: Book; let original: Book; let host: Host
            let originalCompletedTaskCount: Int; let originalFailedTaskCount: Int; let physicalBodyCount: Int
            let independentFullPostproofRequired: Bool
        }
#if targetEnvironment(simulator)
        XCTFail("This completed-admission follow-up requires the original physical iPhone library")
        throw SourceToolsFailure.prerequisite
#endif
        let environment = ProcessInfo.processInfo.environment
        let raw = try XCTUnwrap(environment["READER_PHYSICAL_COLD_TWO_BOOK_PREPROOF_JSON"])
        let expectedSHA = try XCTUnwrap(environment["READER_PHYSICAL_COLD_TWO_BOOK_PREPROOF_SHA256"])
        let snapshotSHA = try XCTUnwrap(environment["READER_PHYSICAL_COLD_TWO_BOOK_SNAPSHOT_SHA256"])
        let artifactSHA = try XCTUnwrap(environment["READER_PHYSICAL_COLD_TWO_BOOK_ARTIFACT_BINDING_SHA256"])
        let target = try XCTUnwrap(environment["READER_PHYSICAL_TARGET_UDID"])
        let operationID = "0ad35be2-67cd-43a0-b4b4-34e98814e40d"
        let sourceID = "https://dushu.baidu.com/"
        let bookID = "https://boxnovel.baidu.com/boxnovel/wiseapi/chapterList?bookid=4345127024&pageNum=1&order=asc&site="
        let originalBookID = "https://boxnovel.baidu.com/boxnovel/wiseapi/chapterList?bookid=4305547728&pageNum=1&order=asc&site="
        let expectedShelf = [originalBookID, bookID].sorted()
        func isSHA(_ value: String) -> Bool { value.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil }
        let bytes = Data(raw.utf8)
        try sourceToolsRequire(bytes.count <= 24 * 1024 && isSHA(expectedSHA)
            && SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() == expectedSHA,
            "Require exact external completed-admission preproof bytes before any target App launch", app: nil)
        let proof = try JSONDecoder().decode(Preproof.self, from: bytes)
        let timestamp = ISO8601DateFormatter(); timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let captured = timestamp.date(from: proof.capturedAtUTC) ?? ISO8601DateFormatter().date(from: proof.capturedAtUTC)
        let protectedKeys: Set<String> = ["library", "files", "sources", "ledger", "originalBook", "originalProgress",
            "originalTasks", "originalBodies", "hostCommands", "candidate", "completedAdmission", "r5Lineage", "pairInstallation"]
        try sourceToolsRequire(UIDevice.current.userInterfaceIdiom == .phone && environment["SIMULATOR_UDID"] == nil
            && target.range(of: #"^(?:[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40})$"#, options: .regularExpression) != nil
            && proof.targetUDID == target && proof.bundleID == "io.reader.minliny.free"
            && proof.schemaVersion == 1 && proof.policy == "physical-completed-baidu-admission-cold-two-book-v1"
            && !proof.historicalDraft && captured.map { (0...1800).contains(Date().timeIntervalSince($0)) } == true
            && proof.stoppedPhysicalApp && proof.preserveDataUpdateVerified && proof.allBaselineProtectedDataExact
            && isSHA(snapshotSHA) && proof.snapshotSHA256 == snapshotSHA && isSHA(artifactSHA) && proof.artifactBindingSHA256 == artifactSHA
            && isSHA(proof.captureFactsSHA256) && proof.independentFullPostproofRequired
            && protectedKeys.isSubset(of: Set(proof.protectedSHA256.keys)) && proof.protectedSHA256.values.allSatisfy(isSHA)
            && proof.artifactSchemaVersion == 3 && proof.sameSourceAppAndRunner && proof.newAppInstalled && proof.newRunnerInstalled
            && isSHA(proof.appSignedTreeSHA256) && isSHA(proof.runnerSignedTreeSHA256) && isSHA(proof.sourceManifestSHA256)
            && proof.r5BaselineSnapshotSHA256 == "6623f54988af533df45a9174a02da98996e1ae34178f5ef25de4f32b018a39e0"
            && proof.r5CaptureFactsSHA256 == "00823198b858c9b1cb5991648a659f8948596f24702ad2cc7ea928ab089b1de9"
            && proof.r5TestExitSHA256 == "e9ab066082c77a4fbcd4ea7b0d9c0deee63d550bf134af8a3d6a8bdaff75d187"
            && proof.r5CaptureResultSHA256 == "25c5e84c12fa530de1fc4ff7e30852974443e68894b627ca6d095b98bdf6a3f4"
            && proof.r5TestExitCode == 65,
            "Bind this same wired iPhone, newly installed same-source signed r6 App and Runner, exact fresh r5-success data baseline and immutable r5 FAIL receipt", app: nil)
        let knownSources: [String: String] = [sourceID: "百度小说", "https://m.idejian.com": "得间小说", "http://199.33.126.51": "👍 同人圈"]
        let candidate = proof.candidate, original = proof.original, host = proof.host
        try sourceToolsRequire(proof.sourcePackageSHA256 == "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322"
            && proof.sourcePackageBytes == 5606 && proof.sources.count == 3 && Set(proof.sources.map(\.id)).count == 3
            && proof.sources.allSatisfy { knownSources[$0.id] == $0.name && $0.enabled == ($0.id != "http://199.33.126.51") }
            && proof.expectedShelfBookIds.sorted() == expectedShelf
            && candidate.sourceId == sourceID && candidate.bookId == bookID && candidate.title == "等到鸢尾纯白"
            && candidate.chapterIndex == 0 && candidate.chapterTitle == "第一章 年少惊鸿" && candidate.scalarOffset == 0
            && candidate.chapterURL.hasPrefix("https://dushu.baidu.com/api/pc/getChapterContent?")
            && candidate.cachedIndexes == [0] && candidate.taskCount == 0 && !candidate.hasReadingProgress
            && candidate.bodyRowSHA256 == "a64a2a5e720f77fcd99ceb8da4ed6d5c6803763c91085da07e0b84738224c1c6"
            && candidate.contentSHA256 == "b4aa9f3c6a4c4c1f1674d28281c3e00b442eb33973096ef03f209bb133a08443" && isSHA(candidate.catalogSHA256)
            && original.sourceId == sourceID && original.bookId == originalBookID && original.title == "剑来"
            && original.chapterIndex == 40 && original.chapterTitle == "第四十一章 练拳" && original.scalarOffset == 0
            && original.chapterURL.hasPrefix("https://dushu.baidu.com/api/pc/getChapterContent?")
            && original.cachedIndexes == Array(UInt32(0)..<UInt32(50)) && original.taskCount == 50 && original.hasReadingProgress
            && original.bodyRowSHA256 == "652a8d869068ce253c72ec14d62c606d0bd7fc58e5f3186bccde74483e46c6eb"
            && original.contentSHA256 == "36e66ec921e42e5c639bf92ea29ceed557781d567b059f3443c782b6fb78d0c1" && isSHA(original.catalogSHA256)
            && proof.originalCompletedTaskCount == 50 && proof.originalFailedTaskCount == 1 && proof.physicalBodyCount == 57,
            "Require the two actual Baidu books, original exact stored 40/0 position, candidate chapter0 cache and all protected source/task/body facts", app: nil)
        try sourceToolsRequire(host.count == 584 && host.rawMapSHA256 == "be2b42d752204aaf9a441de43aa720b26ee7cfc6298ff0ce8a7f2b42d85e4031"
            && host.all584BaselineCommandsRawExact && host.historicalCount == 581
            && host.historicalSHA256 == "90c64359624b004e9b5ca0f09c5c585a1f700eb01df21cad899e59518814c3a1"
            && host.pendingOperationIDs == [operationID] && host.originalOperationID == operationID && host.originalStillUnknown
            && host.originalCommandSHA256 == "b8da0dd291ca82d63ba2afb88a9e371a280cfd130317c6d7e5e167f0e93a8f82"
            && host.childOperationID == operationID + ":continuation:v1" && host.childCompleted && host.childCreated
            && host.childCommandSHA256 == "7a29f2a81e74a04fb7e7d83e121baf0f213e01db77c6e0ef013381a2fbb87199"
            && host.childOriginalParameterBytesExact && host.onlyOneContinuationChild
            && host.descriptorSHA256 == "b00559c3fda92b5515e69a4a577e0a50a2c0f3062ced7b1eaa2d92d72ec91e83"
            && host.descriptorCompletionKind == "continued" && host.candidateIntentRevision == 2
            && host.candidateIntentReason == "read" && host.candidateIntentState == "active" && host.candidateIntentPendingAddAbsent
            && host.candidateIntentSourceVersion == "47ff0e3312f354175e488ce582fcf699d0dc7a486a6f69903a0bb2b7f5894ce3"
            && host.originalIntentRevision == 17 && host.originalIntentReason == "suppressed" && host.originalIntentState == "cancelled",
            "Require the completed child ACK and descriptor beside the unchanged original unknown; no continuation, reconciliation or admission is selected", app: nil)
        let preproof = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        preproof.name = "physical-completed-admission-cold-two-book-external-preproof"; preproof.lifetime = .keepAlways; add(preproof)
        let app = XCUIApplication(bundleIdentifier: proof.bundleID)
        var startupAppState = "unobserved", startupNormalizationAttempted = false
        var coldLaunchCount = 0, candidateEntryTapCount = 0, originalEntryTapCount = 0
        var candidateBodyObserved = false, originalBodyObserved = false
        var originalShelfLabel: String?
        func buttons(_ identifier: String) -> XCUIElementQuery { app.buttons.matching(NSPredicate(format: "identifier == %@", identifier)) }
        func tap(_ identifier: String) throws {
            let values = buttons(identifier)
            try sourceToolsRequire(values.count == 1 && values.element.isEnabled && values.element.isHittable,
                "Require one exact native read action without coordinate or alternate-action fallback: " + identifier, app: app)
            values.element.tap()
        }
        func shelfBookIds() -> [String] {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "book-"))
                .allElementsBoundByIndex.map { String($0.identifier.dropFirst("book-".count)) }.sorted()
        }
        func requireShelf(_ name: String) throws {
            try sourceToolsWait("Require the complete original and admitted shelf entries without opening a reader", timeout: 30) {
                app.buttons["更多书架操作"].exists && !app.textFields["shelf-filter"].exists
                    && shelfBookIds() == expectedShelf && !app.textViews["reading-body"].exists
                    && !app.staticTexts["原操作待核对"].exists
                    && buttons("continue-admission-" + operationID).count == 0
                    && buttons("resume-feature-" + operationID).count == 0
            }
            let first = buttons("book-" + originalBookID), second = buttons("book-" + bookID)
            try sourceToolsRequire(first.count == 1 && second.count == 1 && first.element.label.contains(original.title)
                && second.element.label.contains(candidate.title), "Both original Baidu identities must have their real titles", app: app)
            if let originalShelfLabel {
                try sourceToolsRequire(first.element.label == originalShelfLabel, "The original shelf projection must remain exact", app: app)
            } else { originalShelfLabel = first.element.label }
            keepScreenshot(app, name: name)
        }
        func coldLaunch() throws {
            try sourceToolsRequire(app.wait(for: .notRunning, timeout: 10), "The target App must be stopped before each explicit cold launch", app: nil)
            app.launch(); coldLaunchCount += 1
            try sourceToolsRequire(app.wait(for: .runningForeground, timeout: 20), "The newly installed same-source r6 App must reach the foreground", app: nil)
        }
        func read(_ book: Book, name: String) throws {
            try tap("book-" + book.bookId)
            if book.bookId == bookID { candidateEntryTapCount += 1 } else { originalEntryTapCount += 1 }
            let body = app.textViews["reading-body"]
            assertNativeBody(body, in: app, timeout: 180)
            // Capture the visible body before opening controls hides its AX.
            keepScreenshot(app, name: name + "-visible-body")
            let leaveRows = buttons("leave-reader")
            if leaveRows.count != 1 || !leaveRows.element.isHittable {
                body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
            }
            let bookRows = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "reading-book:" + book.sourceId + "|" + book.bookId))
            let chapters = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "reading-chapter:"))
            try sourceToolsWait("The native controls must identify this exact real source, book and retained chapter", timeout: 15) {
                bookRows.count == 1 && bookRows.element.label == book.title && chapters.count == 1
                    && chapters.element.identifier == "reading-chapter:" + String(book.chapterIndex)
                    && chapters.element.label.hasPrefix(book.chapterTitle + " · ") && leaveRows.count == 1 && leaveRows.element.isHittable
            }
            keepScreenshot(app, name: name + "-exact-reading-identity")
            try tap("leave-reader")
            try requireShelf(name + "-normal-returned-two-book-shelf")
        }
        addTeardownBlock {
            defer {
                if app.state != .notRunning { app.terminate() }
                XCTAssertTrue(app.wait(for: .notRunning, timeout: 10), "Stop the original App for independent full postproof after every outcome")
            }
            let facts: [String: Any] = ["preproofSHA256": expectedSHA, "snapshotSHA256": snapshotSHA, "artifactBindingSHA256": artifactSHA,
                "r5TestExitCode": 65, "r5ResultRewritten": false, "targetUDID": target, "bundleID": proof.bundleID,
                "originalOperationID": operationID, "childOperationID": host.childOperationID,
                "startupAppState": startupAppState, "startupNormalizationAttempted": startupNormalizationAttempted,
                "coldLaunchCount": coldLaunchCount, "candidateEntryTapCount": candidateEntryTapCount, "originalEntryTapCount": originalEntryTapCount,
                "candidateChapter0BodyObserved": candidateBodyObserved, "originalChapter40BodyObserved": originalBodyObserved,
                "continuationTapCount": 0, "originalResumeTapCount": 0, "newAdmissionTapCount": 0,
                "independentFullPostproofRequired": true,
                "boundary": "Two cold launches, one candidate chapter0 entry, one original chapter40 entry and normal exits only. No page turn, scroll, seek, source change, admission/reconciliation, download, cleanup or state injection. Exact original scalar0 and original/candidate body, source, task, file and all584 retained Host bytes require independent stopped App+Runner postproof. Candidate chapter0/scalar0 progress may be created by its first normal exit; normal reading preparations/window cache and completed reading-time ACKs must be attributed separately. Opening the original may update its preparation from suppressed/cancelled; this must not be mistaken for replaying the original pending add. Container evidence does not measure production Keychain bytes or replace user acceptance."]
            let data = try JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys])
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "physical-completed-admission-cold-two-book-attempt-and-postproof-boundary"
            attachment.lifetime = .keepAlways; self.add(attachment)
        }
        let startup = app.state; startupAppState = String(describing: startup)
        if startup != .notRunning { startupNormalizationAttempted = true; app.terminate() }
        try coldLaunch()
        try requireShelf("physical-completed-admission-first-cold-two-book-shelf")
        try read(candidate, name: "physical-completed-admission-cold-candidate-chapter0")
        candidateBodyObserved = true
        app.terminate()
        try coldLaunch()
        try requireShelf("physical-completed-admission-second-cold-two-book-shelf")
        try read(original, name: "physical-completed-admission-cold-original-chapter40")
        originalBodyObserved = true
        try sourceToolsRequire(coldLaunchCount == 2 && candidateEntryTapCount == 1 && originalEntryTapCount == 1,
            "Only the two explicitly selected cold reader entries may occur", app: app)
        app.terminate()
        try sourceToolsRequire(app.wait(for: .notRunning, timeout: 10), "Leave the original App stopped for exact independent postproof", app: nil)
    }

    /// Runner-only preproof binds the stopped original phone library. This
    /// selects one real re-search, never a candidate or source-definition edit.
    /// UI PASS covers the returned tap and scrolled terminal projection only.
    /// The optional same-snapshot trace witness binds the visible projection;
    /// real acquisition and persisted source versions still require external proof.
    func testPhysicalExistingRealBaiduSwitchSheetResearchPreservesScrolledCandidateTerminalProjection() throws {
        struct Source: Decodable { let id: String; let name: String; let enabled: Bool }
        struct PendingOperation: Decodable {
            let operationID: String
            let method: String
            let scope: String
            let commandSHA256: String
            let completed: Bool
            let resultPresent: Bool
            let failurePresent: Bool
            let sourceId: String
            let bookId: String
            let title: String
        }
        struct Preproof: Decodable {
            let schemaVersion: Int
            let policy: String
            let capturedAtUTC: String
            let targetUDID: String
            let bundleID: String
            let snapshotSHA256: String
            let protectedSHA256: [String: String]
            let sourcePackageSHA256: String
            let sourcePackageBytes: Int
            let sources: [Source]
            let sourceId: String
            let bookId: String
            let title: String
            let originalChapterIndex: UInt32
            let originalScalarOffset: UInt64
            let originalProgressLabel: String
            let originalShelfBookIds: [String]
            let originalCompletedTaskCount: Int
            let originalFailedTaskCount: Int
            let originalPhysicalBodyCount: Int
            let pendingOperationCount: Int
            let pendingOperationIDs: [String]
            let pendingOperations: [PendingOperation]
            let independentFullPostproofRequired: Bool
        }
#if targetEnvironment(simulator)
        XCTFail("This re-search requires the original physical iPhone library")
        throw SourceToolsFailure.prerequisite
#endif
        let environment = ProcessInfo.processInfo.environment
        let raw = try XCTUnwrap(environment["READER_PHYSICAL_SWITCH_RESEARCH_PREPROOF_JSON"])
        let expectedSHA = try XCTUnwrap(environment["READER_PHYSICAL_SWITCH_RESEARCH_PREPROOF_SHA256"])
        let snapshotSHA = try XCTUnwrap(environment["READER_PHYSICAL_SWITCH_RESEARCH_SNAPSHOT_SHA256"])
        let target = try XCTUnwrap(environment["READER_PHYSICAL_TARGET_UDID"])
        let sourceID = "https://dushu.baidu.com/"
        let bookID = "https://boxnovel.baidu.com/boxnovel/wiseapi/chapterList?bookid=4305547728&pageNum=1&order=asc&site="
        let identity = sourceID + "|" + bookID
        let pendingOperationID = "0ad35be2-67cd-43a0-b4b4-34e98814e40d"
        let pendingBookID = "https://boxnovel.baidu.com/boxnovel/wiseapi/chapterList?bookid=4345127024&pageNum=1&order=asc&site="
        let bytes = Data(raw.utf8)
        func isSHA(_ value: String) -> Bool {
            value.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil
        }
        try sourceToolsRequire(bytes.count <= 32 * 1024 && isSHA(expectedSHA)
            && SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() == expectedSHA,
            "Require the exact fresh external re-search preproof before launching the original App", app: nil)
        let proof = try JSONDecoder().decode(Preproof.self, from: bytes)
        let timestamp = ISO8601DateFormatter()
        timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let captured = timestamp.date(from: proof.capturedAtUTC)
            ?? ISO8601DateFormatter().date(from: proof.capturedAtUTC)
        let protectedKeys: Set<String> = ["library", "files", "sources", "ledger", "originalBook",
            "originalProgress", "originalTasks", "originalBodies", "sourceBooks", "readingDocuments", "sourceSwitchTransactions"]
        let knownSources: [String: String] = [sourceID: "百度小说", "https://m.idejian.com": "得间小说", "http://199.33.126.51": "👍 同人圈"]
        let enabledSources = proof.sources.filter(\.enabled)
        let enabledSourceIDs = Set(enabledSources.map(\.id))
        try sourceToolsRequire(UIDevice.current.userInterfaceIdiom == .phone && environment["SIMULATOR_UDID"] == nil
            && proof.schemaVersion == 2 && proof.policy == "physical-real-baidu-switch-research-v2"
            && captured.map { (0...1800).contains(Date().timeIntervalSince($0)) } == true
            && target.range(of: #"^(?:[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40})$"#, options: .regularExpression) != nil
            && proof.targetUDID == target && proof.bundleID == "io.reader.minliny.free"
            && isSHA(snapshotSHA) && proof.snapshotSHA256 == snapshotSHA
            && Set(proof.protectedSHA256.keys) == protectedKeys && proof.protectedSHA256.values.allSatisfy(isSHA)
            && proof.sourcePackageBytes == 5606
            && proof.sourcePackageSHA256 == "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322"
            && proof.sources.count == 3 && Set(proof.sources.map(\.id)).count == proof.sources.count
            && enabledSourceIDs == Set([sourceID, "https://m.idejian.com"])
            && enabledSources.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            && proof.sources.allSatisfy({ knownSources[$0.id] == $0.name && $0.enabled == ($0.id != "http://199.33.126.51") })
            && proof.sourceId == sourceID && proof.bookId == bookID && proof.title == "剑来"
            && proof.originalChapterIndex == 40 && proof.originalScalarOffset == 0
            && proof.originalProgressLabel.range(of: #"^(?:[0-9]{1,2}|100)%$"#, options: .regularExpression) != nil
            && proof.originalShelfBookIds.contains(bookID)
            && Set(proof.originalShelfBookIds).count == proof.originalShelfBookIds.count
            && proof.originalCompletedTaskCount == 50 && proof.originalFailedTaskCount == 1
            && proof.originalPhysicalBodyCount == 57
            && proof.pendingOperationCount == 1 && proof.pendingOperationIDs == [pendingOperationID]
            && proof.pendingOperations.count == 1 && proof.pendingOperations.allSatisfy({ pending in
                pending.operationID == pendingOperationID && pending.method == "bookshelf.add"
                    && pending.scope == "shelf-add:" + sourceID + "|" + pendingBookID
                    && pending.commandSHA256 == "b8da0dd291ca82d63ba2afb88a9e371a280cfd130317c6d7e5e167f0e93a8f82"
                    && !pending.completed && !pending.resultPresent && !pending.failurePresent
                    && pending.sourceId == sourceID && pending.bookId == pendingBookID && pending.title == "等到鸢尾纯白"
            })
            && proof.independentFullPostproofRequired,
            "Bind the fresh stopped original sources, admitted Baidu book, exact original position and all protected data, retaining only the exact original unknown Host add and its raw command SHA; never provision, settle, clear or repair these prerequisites", app: nil)
        let preproof = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        preproof.name = "physical-real-switch-research-external-preproof"; preproof.lifetime = .keepAlways; add(preproof)
        let app = XCUIApplication(bundleIdentifier: proof.bundleID)
        #if DEBUG
        let traceRunID = UUID().uuidString.lowercased()
        app.launchEnvironment["READER_V4_SEARCH_TRACE_MODE"] = "physical-v4-04-search-trace-v1"
        app.launchEnvironment["READER_V4_SEARCH_TRACE_RUN_ID"] = traceRunID
        #endif
        try sourceToolsRequire(app.state == .notRunning, "Capture the external original-library proof with the App stopped", app: app)
        func button(_ identifier: String) throws -> XCUIElement {
            let matches = app.buttons.matching(NSPredicate(format: "identifier == %@", identifier))
            try sourceToolsRequire(matches.count == 1, "Require one exact native action: " + identifier, app: app)
            return matches.element
        }
        func tap(_ value: XCUIElement) throws {
            try sourceToolsRequire(value.isEnabled && value.isHittable,
                "The exact native action must be enabled and hittable; no alternate action or coordinate fallback", app: app)
            value.tap()
        }
        func controls() throws {
            if !app.buttons["reader-more"].isHittable {
                app.textViews["reading-body"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
            }
            try sourceToolsWait("The original reading session must expose its normal controls", timeout: 10) { app.buttons["reader-more"].isHittable }
        }
        func shelfBookIds() -> [String] {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "book-"))
                .allElementsBoundByIndex.map { String($0.identifier.dropFirst("book-".count)) }.sorted()
        }
        func hideControls() throws {
            let hide = app.buttons["收起阅读控制"]
            if hide.exists { try tap(hide) }
            try sourceToolsWait("Hide reading controls before observing the actual body and progress footer", timeout: 10) {
                !hide.exists && !app.buttons["reader-more"].isHittable
            }
        }
        func requireOriginalReadingIdentity() throws {
            let book = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "reading-book:" + identity))
            let chapter = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "reading-chapter:"))
            try sourceToolsRequire(book.count == 1 && book.element.label == proof.title && chapter.count == 1
                && chapter.element.identifier == "reading-chapter:" + String(proof.originalChapterIndex),
                "Visible reading controls must expose the exact original source/book/chapter identity", app: app)
        }
        func originalVisibleBody() throws -> String {
            try hideControls()
            let body = app.textViews["reading-body"]
            assertNativeBody(body, in: app, timeout: 180)
            let footer = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "reading-progress"))
            try sourceToolsRequire(footer.count == 1 && footer.element.isHittable
                && footer.element.label == proof.originalProgressLabel,
                "With controls hidden, the exact visible original percentage must match the external baseline; scalar comparison remains external", app: app)
            return try XCTUnwrap(body.value as? String)
        }
        var observations = [[String: Any]]()
        var researchTapCount = 0
        var nativeScrollCount = 0
        var observationPhase = "before-native-scroll"
        var observedSearching = false
        var observedPreviousCandidateDuringSearch = false
        var researchReturnedUptime: TimeInterval?
        func attachObservations(_ name: String) throws {
            var facts: [String: Any] = ["preproofSHA256": expectedSHA, "snapshotSHA256": snapshotSHA,
                "originalIdentity": identity, "researchTapCount": researchTapCount, "nativeScrollCount": nativeScrollCount,
                "observations": observations, "uiPassScope": "USER_TAP_AND_TERMINAL_PROJECTION_ONLY",
                "observedSearching": observedSearching, "observedPreviousCandidateDuringSearch": observedPreviousCandidateDuringSearch,
                "instantaneousRetainedCandidateBoundary": observedPreviousCandidateDuringSearch ? "Observed in a public snapshot; not an atomic callback trace" : "OPEN: no intermediate previous-candidate state was naturally observed",
                "independentFullOriginalDataPostproofRequired": true,
                "boundary": "One real native candidate scroll followed by one explicit native re-search tap. UI PASS proves only the returned tap and scrolled terminal candidate/timing projection. Source search uses non-durable Core reads, so the durable Host journal cannot prove one new request per source or the generation of displayed milliseconds. Without a separately captured real transport/request trace, per-source fresh acquisition and timing generation remain OPEN; equal old/new ms cannot prove freshness. Native position checks cover chapter, percentage and visible body; exact scalar retention requires external snapshots. Reading lifecycle/time metadata and source_books discovery publications may change; every difference requires full external database/file attribution, retaining any strict-comparison FAIL. No candidate selection, source switch, source-definition mutation, delay, response injection or re-search retry."]
            if let researchReturnedUptime { facts["researchTapReturnedUptime"] = researchReturnedUptime }
            let value = try JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys])
            let attachment = XCTAttachment(data: value, uniformTypeIdentifier: "public.json")
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        addTeardownBlock {
            try attachObservations("physical-real-switch-research-observation-and-postproof-boundary")
            // Close only known read hosts. A failed method never taps a candidate,
            // repeats a re-search or uses an uncertain pending action to recover.
            let close = app.buttons.matching(NSPredicate(format: "identifier == %@", "online-switch-close"))
            if app.state == .runningForeground, close.count == 1, close.element.isEnabled, close.element.isHittable { close.element.tap() }
            if app.state == .runningForeground, app.textViews["reading-body"].exists,
               !app.buttons["online-switch-close"].exists { self.leaveReader(app.textViews["reading-body"], in: app) }
            if app.state != .notRunning { app.terminate() }
        }
        app.launch()
        try sourceToolsWait("Require the complete original unfiltered shelf; never admit another book for this method", timeout: 25) {
            app.buttons["更多书架操作"].exists && !app.textFields["shelf-filter"].exists
                && shelfBookIds() == proof.originalShelfBookIds.sorted()
        }
        try tap(try button("book-" + bookID))
        let body = app.textViews["reading-body"]
        try sourceToolsWait("The original reading route must appear before observing its two accessibility states", timeout: 180) {
            body.exists || app.buttons["reader-more"].isHittable
        }
        let originalBody = try originalVisibleBody()
        try controls(); try requireOriginalReadingIdentity()
        try tap(try button("reader-more"))
        let route = app.buttons.matching(NSPredicate(format: "label == %@", "切换书源"))
        try sourceToolsRequire(route.count == 1, "Open only the original reading session's source-switch sheet", app: app)
        try tap(route.element)

        struct SearchTraceProof: Decodable {
            let r: String; let g: String; let n: Int; let e: Int; let f: Int
            let s: String; let h: String; let v: Int
            var fields: [String: Any] {
                ["r": r, "g": g, "n": n, "e": e, "f": f, "s": s, "h": h, "v": v]
            }
        }
        struct Row {
            let identifier: String
            let sourceID: String
            let label: String
            let milliseconds: Int?
            let previous: Bool
            let frame: CGRect
        }
        struct Observation {
            let snapshotOrdinal: Int
            let snapshotBeganUptime: TimeInterval
            let snapshotReturnedUptime: TimeInterval
            let rows: [Row]
            let viewport: CGRect
            let searching: Bool
            let settled: Bool
            let traceProof: SearchTraceProof?
            let traceProofBytes: Data?
            var anchor: Row? { rows.first { $0.frame.intersection(viewport).height >= 12 } }
        }
        let timingPattern = try NSRegularExpression(pattern: #"[0-9]+ ms"#)
        func capture() throws -> Observation? {
            let began = ProcessInfo.processInfo.systemUptime
            let tree = try app.snapshot()
            var nodes: [(snapshot: any XCUIElementSnapshot, path: String)] = []
            func collect(_ snapshot: any XCUIElementSnapshot, path: String) {
                nodes.append((snapshot, path))
                for (index, child) in snapshot.children.enumerated() { collect(child, path: path + "/" + String(index)) }
            }
            collect(tree, path: "root")
            let prefix = "online-switch-candidate:"
            let candidates = nodes.filter { $0.snapshot.elementType == .button && $0.snapshot.identifier.hasPrefix(prefix) }
            let scrolls = nodes.filter { node in
                node.snapshot.elementType == .scrollView && node.snapshot.frame.width > 100 && node.snapshot.frame.height > 100
                    && candidates.contains { $0.path.hasPrefix(node.path + "/") }
            }
            guard let viewport = scrolls.map({ $0.snapshot.frame.intersection(tree.frame) }).filter({ !$0.isNull && !$0.isInfinite && $0.width > 100 && $0.height > 100 }).min(by: { $0.height < $1.height }) else { return nil }
            let fields = nodes.filter { $0.snapshot.elementType == .textField }
            let close = nodes.filter { $0.snapshot.elementType == .button && $0.snapshot.identifier == "online-switch-close" }
            let owners = nodes.filter { $0.snapshot.identifier.hasPrefix("online-switch-owner:") }
            var traceProof: SearchTraceProof?
            var traceProofBytes: Data?
            #if DEBUG
            // Read only this tree's owner value. A later AX query cannot bind
            // the candidate milliseconds or anchor captured by this snapshot.
            if owners.count == 1, let raw = owners[0].snapshot.value as? String,
               let data = raw.data(using: .utf8), data.count <= 256,
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               Set(object.keys) == Set(["r", "g", "n", "e", "f", "s", "h", "v"]),
               let value = try? JSONDecoder().decode(SearchTraceProof.self, from: data),
               value.r == traceRunID, UUID(uuidString: value.g)?.uuidString.lowercased() == value.g,
               (1...2).contains(value.n), (0...value.n).contains(value.f),
               (1...4096).contains(value.e), value.v > 0,
               ["captured", "incomplete"].contains(value.s), isSHA(value.h) {
                traceProof = value; traceProofBytes = data
            }
            #endif
            let stopCount = nodes.filter { $0.snapshot.elementType == .button && $0.snapshot.label == "停止" }.count
            let researchCount = nodes.filter { $0.snapshot.elementType == .button && $0.snapshot.label == "重新搜索" }.count
            let searching = stopCount == 1 && researchCount == 0
            let settled = stopCount == 0 && researchCount == 1
                && !nodes.contains { $0.snapshot.label == "正在查找其他来源" }
            var rows: [Row] = []
            for node in candidates {
                let candidate = node.snapshot
                let candidateIdentity = String(candidate.identifier.dropFirst(prefix.count))
                guard let separator = candidateIdentity.firstIndex(of: "|") else { return nil }
                let candidateSource = String(candidateIdentity[..<separator])
                let candidateBook = String(candidateIdentity[candidateIdentity.index(after: separator)...])
                guard let source = enabledSources.first(where: { $0.id == candidateSource }),
                      let url = URL(string: candidateBook), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil,
                      candidateIdentity != identity, candidate.isEnabled, candidate.label.contains(source.name),
                      candidate.frame.width > 0, candidate.frame.height > 0 else { return nil }
                let matches = timingPattern.matches(in: candidate.label, range: NSRange(candidate.label.startIndex..., in: candidate.label))
                let previous = candidate.label.contains("上次候选")
                let milliseconds: Int?
                if previous {
                    guard matches.isEmpty && candidate.label.contains(searching ? "上次候选 · 本次搜索中" : "上次候选 · 本次未确认") else { return nil }
                    milliseconds = nil
                } else {
                    guard matches.count == 1, let range = Range(matches[0].range, in: candidate.label),
                          let elapsed = Int(candidate.label[range].dropLast(3)) else { return nil }
                    milliseconds = elapsed
                }
                rows.append(Row(identifier: candidate.identifier, sourceID: candidateSource, label: candidate.label,
                    milliseconds: milliseconds, previous: previous, frame: candidate.frame))
            }
            rows.sort { $0.frame.minY == $1.frame.minY ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY }
            let valid = app.state == .runningForeground && fields.count == 1 && fields[0].snapshot.value as? String == proof.title
                && close.count == 1 && close[0].snapshot.isEnabled && owners.count == 1
                && owners[0].snapshot.identifier == "online-switch-owner:settled"
                && !nodes.contains { $0.snapshot.elementType == .keyboard || $0.snapshot.elementType == .alert }
                && rows.count >= 2 && Set(rows.map(\.identifier)).count == rows.count && (searching || settled)
            let ordinal = observations.count + 1
            let returned = ProcessInfo.processInfo.systemUptime
            let observation = Observation(snapshotOrdinal: ordinal, snapshotBeganUptime: began, snapshotReturnedUptime: returned,
                rows: rows, viewport: viewport, searching: searching, settled: settled,
                traceProof: traceProof, traceProofBytes: traceProofBytes)
            var observationFacts: [String: Any] = ["snapshotOrdinal": ordinal,
                "snapshotBeganUptime": began, "snapshotReturnedUptime": returned,
                "phase": observationPhase, "valid": valid, "searching": searching, "settled": settled,
                "viewport": String(describing: viewport), "anchorIdentifier": observation.anchor?.identifier ?? "<absent>",
                "anchorViewportOffsetY": observation.anchor.map { $0.frame.minY - viewport.minY } ?? 0,
                "rows": rows.map { row -> [String: Any] in ["identifier": row.identifier, "sourceId": row.sourceID,
                    "label": row.label, "currentMilliseconds": row.milliseconds.map { $0 as Any } ?? NSNull(), "previousCandidate": row.previous,
                    "viewportRelativeFrame": String(describing: row.frame.offsetBy(dx: -viewport.minX, dy: -viewport.minY))] }]
            observationFacts["traceProofSameSnapshot"] = traceProof.map { $0.fields as Any } ?? NSNull()
            observations.append(observationFacts)
            if researchTapCount == 1 && valid && searching {
                observedSearching = true
                observedPreviousCandidateDuringSearch = observedPreviousCandidateDuringSearch || rows.contains(where: \.previous)
            }
            return valid ? observation : nil
        }
        func settled(_ name: String) throws -> Observation {
            observationPhase = name
            var result: Observation?
            var observationFailure: String?
            func observe() -> Bool {
                do {
                    if let current = try capture(), current.settled { result = current; return true }
                } catch { observationFailure = String(describing: error); return true }
                return false
            }
            if !observe() {
                let condition = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in observe() }, object: nil)
                try sourceToolsRequire(XCTWaiter.wait(for: [condition], timeout: 180) == .completed,
                    "Require the actual real-source re-search terminal: " + name, app: app)
            }
            try sourceToolsRequire(observationFailure == nil && result != nil,
                "The public AX observation must finish without substituting malformed or missing candidates: " + name, app: app)
            keepScreenshot(app, name: name)
            return try XCTUnwrap(result)
        }
        func requireCurrentSourceTimings(_ value: Observation, name: String) throws {
            let current = value.rows.filter { !$0.previous }
            try sourceToolsRequire(Set(current.map(\.sourceID)) == enabledSourceIDs,
                name + ": require actual currently confirmed candidates from both original enabled sources", app: app)
            for source in enabledSources {
                let sourceRows = current.filter { $0.sourceID == source.id }
                try sourceToolsRequire(!sourceRows.isEmpty && sourceRows.allSatisfy { $0.milliseconds != nil }
                    && Set(sourceRows.compactMap(\.milliseconds)).count == 1,
                    name + ": require one consistent displayed elapsed-time projection for exact current candidate/source identities; freshness is external", app: app)
            }
        }
        let initial = try settled("physical-real-switch-before-native-scroll")
        try sourceToolsRequire(initial.rows.allSatisfy { !$0.previous },
            "Require a complete current baseline before selecting the one explicit real re-search", app: app)
        try requireCurrentSourceTimings(initial, name: "before-scroll")
        let initialAnchor = try XCTUnwrap(initial.anchor)
        let nativeScrolls = app.scrollViews.allElementsBoundByIndex.filter { scroll in
            let frame = scroll.frame.intersection(app.frame)
            return !frame.isNull && scroll.isHittable
                && abs(frame.minX - initial.viewport.minX) <= 2 && abs(frame.minY - initial.viewport.minY) <= 2
                && abs(frame.width - initial.viewport.width) <= 2 && abs(frame.height - initial.viewport.height) <= 2
                && scroll.buttons.matching(NSPredicate(format: "identifier == %@", initialAnchor.identifier)).count == 1
        }
        try sourceToolsRequire(nativeScrolls.count == 1,
            "Require the exact visible native candidate scroll host before one bounded real scroll", app: app)
        let nativeScroll = nativeScrolls[0]
        let scrollHeight = nativeScroll.frame.height
        let distance = min(CGFloat(120), max(CGFloat(50), initialAnchor.frame.height * 0.45))
        try sourceToolsRequire(scrollHeight > 100 && distance < scrollHeight * 0.5,
            "The live candidate viewport must contain the complete bounded native drag", app: app)
        let start = nativeScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let end = nativeScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72 - distance / scrollHeight))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        nativeScrollCount = 1
        let scrolled = try settled("physical-real-switch-after-one-native-scroll")
        let scrolledAnchor = try XCTUnwrap(scrolled.anchor)
        let before = try settled("physical-real-switch-stable-scrolled-before-explicit-research")
        try sourceToolsRequire(before.rows.allSatisfy { !$0.previous },
            "The same real search must remain settled after the one candidate scroll", app: app)
        try requireCurrentSourceTimings(before, name: "scrolled-before-research")
        let beforeAnchor = try XCTUnwrap(before.anchor)
        try sourceToolsRequire(beforeAnchor.identifier == scrolledAnchor.identifier
            && abs((beforeAnchor.frame.minY - before.viewport.minY) - (scrolledAnchor.frame.minY - scrolled.viewport.minY)) <= 0.25,
            "Two independent public snapshots must show the same settled scrolled anchor within 0.25pt before re-search; a moving or bouncing viewport is insufficient", app: app)
        let movedOriginalRow = initial.rows.contains { old in
            guard let current = before.rows.first(where: { $0.identifier == old.identifier }) else { return false }
            return (old.frame.minY - initial.viewport.minY) - (current.frame.minY - before.viewport.minY) >= 12
        }
        let movedAnchor = beforeAnchor.identifier != initialAnchor.identifier
            || abs((beforeAnchor.frame.minY - before.viewport.minY) - (initialAnchor.frame.minY - initial.viewport.minY)) >= 12
        try sourceToolsRequire(movedOriginalRow && movedAnchor,
            "Real results must produce a genuine nonzero native scroll and moved candidate anchor; short lists or an unmoved viewport fail the prerequisite, with no second drag or manufactured geometry", app: app)
        let research = app.buttons.matching(NSPredicate(format: "label == %@", "重新搜索"))
        try sourceToolsRequire(research.count == 1, "Only one exact native re-search action may be selected", app: app)
        try tap(research.element)
        researchTapCount = 1
        researchReturnedUptime = ProcessInfo.processInfo.systemUptime
        let after = try settled("physical-real-switch-after-one-explicit-research")
        let beforeIDs = before.rows.map(\.identifier)
        let beforeIDSet = Set(beforeIDs)
        try sourceToolsRequire(after.rows.filter { beforeIDSet.contains($0.identifier) }.map(\.identifier) == beforeIDs,
            "Every observed original candidate must retain its complete exact source/book identity and relative order after real re-search", app: app)
        try requireCurrentSourceTimings(after, name: "after")
        let afterAnchor = try XCTUnwrap(after.anchor)
        try sourceToolsRequire(afterAnchor.identifier == beforeAnchor.identifier
            && abs((afterAnchor.frame.minY - after.viewport.minY) - (beforeAnchor.frame.minY - before.viewport.minY)) <= 2,
            "The same actual viewport anchor and intra-row offset must survive explicit re-search within 2pt; never scroll to repair it", app: app)
        for identifier in beforeIDs {
            let matches = app.buttons.matching(NSPredicate(format: "identifier == %@", identifier))
            try sourceToolsRequire(matches.count == 1 && matches.element.isEnabled,
                "Repeated exact selector lookup must resolve one retained candidate without tapping it: " + identifier, app: app)
        }
        #if DEBUG
        func digest(_ value: String) -> String {
            SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
        }
        func frameFields(_ frame: CGRect) -> [String: Double] {
            ["x": Double(frame.minX), "y": Double(frame.minY), "width": Double(frame.width), "height": Double(frame.height)]
        }
        let baseline = [before, scrolled, initial].first { value in
            value.traceProof.map { $0.n == 1 && $0.f == 1 } ?? false
        }
        let generationBound = after.traceProof.map { current in
            guard let original = baseline?.traceProof else { return false }
            return current.n == 2 && current.f == 2 && current.g != original.g && current.v > original.v
        } ?? false
        let sourceTimings = enabledSourceIDs.sorted().compactMap { source -> [String: Any]? in
            guard let milliseconds = after.rows.first(where: { $0.sourceID == source && !$0.previous })?.milliseconds else { return nil }
            return ["sourceIDUTF8SHA256": digest(source), "milliseconds": milliseconds]
        }
        let candidateRows = after.rows.map { row -> [String: Any] in
            ["candidateIdentifierUTF8SHA256": digest(row.identifier), "sourceIDUTF8SHA256": digest(row.sourceID),
             "milliseconds": row.milliseconds.map { $0 as Any } ?? NSNull(), "previousCandidate": row.previous,
             "viewportRelativeFrame": frameFields(row.frame.offsetBy(dx: -after.viewport.minX, dy: -after.viewport.minY))]
        }
        var witness: [String: Any] = ["schemaVersion": 1, "policy": "physical-v4-04-ui-snapshot-timing-witness-v1",
            "timingGenerationBinding": generationBound ? "BOUND" : "INCOMPLETE", "runID": traceRunID,
            "snapshotOrdinal": after.snapshotOrdinal, "snapshotBeganUptime": after.snapshotBeganUptime,
            "snapshotReturnedUptime": after.snapshotReturnedUptime, "researchTapCount": researchTapCount,
            "traceProof": after.traceProof.map { $0.fields as Any } ?? NSNull(),
            "sourceTimings": sourceTimings, "candidateRows": candidateRows, "viewport": frameFields(after.viewport),
            "anchor": ["candidateIdentifierUTF8SHA256": digest(afterAnchor.identifier),
                       "sourceIDUTF8SHA256": digest(afterAnchor.sourceID),
                       "milliseconds": afterAnchor.milliseconds.map { $0 as Any } ?? NSNull(),
                       "previousCandidate": afterAnchor.previous,
                       "viewportOffsetY": Double(afterAnchor.frame.minY - after.viewport.minY)],
            "independentExactTraceSHARequired": true,
            "boundary": "One AX tree supplies the final owner compact, visible source milliseconds, candidate identities and anchor. BOUND requires an earlier same-run n=f=1 compact and this tree's n=f=2 compact with a different g and increasing v. Missing or late compact evidence is INCOMPLETE without changing the candidate/anchor UI result. External trace bytes must match this exact h and v and contain g as the final generation; a later metrics revision with a different SHA cannot substitute. Real network acquisition and Core's persisted source version remain external requirements."]
        if let baseline, let baselineProof = baseline.traceProof {
            witness["baseline"] = ["snapshotOrdinal": baseline.snapshotOrdinal, "traceProof": baselineProof.fields]
        } else { witness["baseline"] = NSNull() }
        let witnessBytes = try JSONSerialization.data(withJSONObject: witness, options: [.sortedKeys])
        let timingWitness = XCTAttachment(data: witnessBytes, uniformTypeIdentifier: "public.json")
        timingWitness.name = "physical-real-switch-research-same-snapshot-timing-witness"
        timingWitness.lifetime = .keepAlways; add(timingWitness)
        if let traceProofBytes = after.traceProofBytes {
            let traceReceipt = XCTAttachment(data: traceProofBytes, uniformTypeIdentifier: "public.json")
            traceReceipt.name = "physical-real-switch-research-private-snapshot-proof"; traceReceipt.lifetime = .keepAlways; add(traceReceipt)
        }
        let traceBoundary = XCTAttachment(string: "Export tmp/ReaderSwitchSearchTrace-" + traceRunID + "/trace.json from the App container after stopping it. A timing-generation witness is accepted only when BOUND and the exported bytes exactly match its same-snapshot h and v, with g as the final generation. Missing compact evidence, a later metrics revision/SHA mismatch, incomplete trace, source-ordinal attribution, fresh acquisition or Core persisted source-version gaps remain INCOMPLETE externally; they do not change this method's candidate/anchor UI result. Fresh v2 preproof must bind the exact retained original unknown bookshelf.add pending operation and every protected identity.")
        traceBoundary.name = "physical-real-switch-research-trace-export-boundary"; traceBoundary.lifetime = .keepAlways; add(traceBoundary)
        #endif
        try tap(try button("online-switch-close"))
        try sourceToolsWait("Close only the read-only candidate sheet", timeout: 10) { !app.buttons["online-switch-close"].exists }
        let returnedBody = try originalVisibleBody()
        try sourceToolsRequire(returnedBody == originalBody,
            "Returning from discovery must retain the original visible body without source admission or chapter navigation", app: app)
        keepScreenshot(app, name: "physical-real-switch-research-returned-original-baidu-body")
        try controls(); try requireOriginalReadingIdentity()
        leaveReader(body, in: app)
        try sourceToolsWait("Return to the complete original shelf without adding or switching any book", timeout: 20) {
            app.buttons["更多书架操作"].exists && !app.textFields["shelf-filter"].exists
                && shelfBookIds() == proof.originalShelfBookIds.sorted()
        }
        app.terminate()
        try sourceToolsRequire(app.wait(for: .notRunning, timeout: 10),
            "Leave the original App stopped for the required independent full-data postproof", app: app)
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
        let exportButton = export.element
        try sourceToolsRequire(export.count == 1 && exportButton.isEnabled && exportButton.frame.width > 0
                               && exportButton.frame.height > 0 && app.frame.intersects(exportButton.frame),
                               "Use one actual source export action; no background file creation", app: app)
        if exportButton.isHittable {
            exportButton.tap()
        } else {
            // SwiftUI can report this visible toolbar control as non-hittable
            // while its native screen coordinate remains actionable.
            exportButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
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
        let sourceFileButton = app.buttons["online-source-file"]
        try sourceToolsWait("Return from actual native export without replacing a file", timeout: 30) {
            let frame = sourceFileButton.frame
            let visible = sourceFileButton.exists && sourceFileButton.isEnabled && frame.width > 0
                && frame.height > 0 && app.frame.intersects(frame)
            return (names.count == 0 && visible) || app.alerts.firstMatch.exists
        }
        let sourceFileFrame = sourceFileButton.frame
        try sourceToolsRequire(!app.alerts.firstMatch.exists && sourceFileButton.exists && sourceFileButton.isEnabled
                               && sourceFileFrame.width > 0 && sourceFileFrame.height > 0
                               && app.frame.intersects(sourceFileFrame),
                               "Never accept a file-overwrite or unexpected save confirmation", app: app)
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == originalSources, "Export must not change source facts", app: app)
        if sourceFileButton.isHittable {
            sourceFileButton.tap()
        } else {
            sourceFileButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
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
    private struct SourceToolsSourceState: Equatable {
        let revision: Int
        let read: String
        let operation: String
        let operationID: String
    }
    private func sourceToolsSourceState(_ app: XCUIApplication) -> SourceToolsSourceState? {
        // The existing filter projects the persisted-read and original write
        // owners. A native toggle value by itself cannot prove completion.
        let prefix = "online-source-state:"
        let states = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        guard states.count == 1 else { return nil }
        let fields = states.element.identifier.dropFirst(prefix.count).split(separator: "|", omittingEmptySubsequences: false)
        guard fields.count == 4, let revision = Int(fields[0]), revision >= 0,
              ["loading", "ready", "failed"].contains(String(fields[1])),
              ["busy", "pending", "terminal"].contains(String(fields[2])),
              (fields[2] == "terminal") == fields[3].isEmpty else { return nil }
        return SourceToolsSourceState(revision: revision, read: String(fields[1]), operation: String(fields[2]), operationID: String(fields[3]))
    }
    private func sourceToolsObservedSourceValues(_ app: XCUIApplication, sourceIDs: Set<String>) -> [String: String]? {
        let toggles = app.switches.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-source-enabled:"))
            .allElementsBoundByIndex
        let expectedIDs = Set(sourceIDs.map { "online-source-enabled:" + $0 })
        guard toggles.count == expectedIDs.count && Set(toggles.map(\.identifier)) == expectedIDs else { return nil }
        var values: [String: String] = [:]
        for sourceID in sourceIDs {
            let matches = app.switches.matching(identifier: "online-source-enabled:" + sourceID)
            guard matches.count == 1, let value = matches.element.value as? String, value == "0" || value == "1" else { return nil }
            values[sourceID] = value
        }
        return values
    }
    private func sourceToolsSourceValues(_ app: XCUIApplication, sourceIDs: Set<String>) throws -> [String: String] {
        let observed = sourceToolsObservedSourceValues(app, sourceIDs: sourceIDs)
        try sourceToolsRequire(observed != nil, "Require exactly the original unambiguous source toggles and native enabled values", app: app)
        return try XCTUnwrap(observed)
    }
    private struct SourceToolsVisibleSourceToggle {
        let toggle: XCUIElement
        let frame: CGRect
        let viewport: CGRect
        let rowBand: CGRect
    }
    private func sourceToolsVisibleSourceToggle(_ app: XCUIApplication, sourceID: String, sourceIDs: Set<String>) -> SourceToolsVisibleSourceToggle? {
        guard app.state == .runningForeground, app.alerts.count == 0, app.sheets.count == 0, app.keyboards.count == 0,
              !app.textViews["online-source-draft"].exists else { return nil }
        let close = app.buttons.matching(identifier: "online-close-sources")
        guard close.count == 1, close.element.isEnabled, close.element.isHittable else { return nil }
        let toggleID = "online-source-enabled:" + sourceID
        let windows = app.windows.containing(.switch, identifier: toggleID)
        guard windows.count == 1 else { return nil }
        let scrolls = windows.element.scrollViews.matching(identifier: "online-source-scroll")
        guard scrolls.count == 1, scrolls.element.isEnabled else { return nil }
        let scroll = scrolls.element
        let toggles = scroll.switches.matching(identifier: toggleID)
        let headers = scroll.staticTexts.matching(identifier: "online-source:" + sourceID)
        let edits = scroll.buttons.matching(identifier: "online-source-edit:" + sourceID)
        guard toggles.count == 1, headers.count == 1, edits.count == 1, toggles.element.isEnabled else { return nil }
        let frame = toggles.element.frame, header = headers.element.frame, edit = edits.element.frame
        func valid(_ rect: CGRect) -> Bool {
            !rect.isNull && !rect.isInfinite && rect.width > 0 && rect.height > 0
                && [rect.minX, rect.minY, rect.maxX, rect.maxY].allSatisfy(\.isFinite)
        }
        let viewport = app.frame.intersection(windows.element.frame).intersection(scroll.frame)
        guard valid(frame), valid(header), valid(edit), valid(viewport),
              viewport.insetBy(dx: 1, dy: 1).contains(frame), viewport.contains(header), viewport.contains(edit),
              abs(frame.midY - header.midY) <= 2, frame.minX > header.maxX, frame.maxY < edit.minY else { return nil }
        // SwiftUI flattens the source cards in AX. Bind the visible switch to
        // its exact source header/edit band, never to a generic Other ancestor.
        let top = min(frame.minY, header.minY)
        let rowBand = CGRect(x: viewport.minX, y: top, width: viewport.width, height: edit.maxY - top)
        guard valid(rowBand), rowBand.contains(frame), rowBand.contains(header), rowBand.contains(edit) else { return nil }
        for otherID in sourceIDs where otherID != sourceID {
            let otherHeaders = scroll.staticTexts.matching(identifier: "online-source:" + otherID)
            let otherToggles = scroll.switches.matching(identifier: "online-source-enabled:" + otherID)
            guard otherHeaders.count == 1, otherToggles.count == 1,
                  valid(otherHeaders.element.frame), valid(otherToggles.element.frame),
                  !rowBand.intersects(otherHeaders.element.frame), !rowBand.intersects(otherToggles.element.frame) else { return nil }
        }
        return SourceToolsVisibleSourceToggle(toggle: toggles.element, frame: frame, viewport: viewport, rowBand: rowBand)
    }
    private func sourceToolsDisableExactVisibleSource(_ app: XCUIApplication, sourceID: String, labels: [String: String],
        values: [String: String], readRevision: Int, tapCount: inout Int, beforeTap: () -> Void) throws {
        let sourceIDs = Set(values.keys)
        let expectedState = SourceToolsSourceState(revision: readRevision, read: "ready", operation: "terminal", operationID: "")
        try sourceToolsRequire(tapCount == 0 && readRevision > 0 && values[sourceID] == "1"
            && sourceToolsSourceState(app) == expectedState,
            "A sole disable requires the exact terminal source owner and its successful current read", app: app)
        try sourceToolsRequire(try sourceToolsSourceLabels(app) == labels && sourceToolsSourceValues(app, sourceIDs: sourceIDs) == values,
            "The sole disable must preserve every exact original source identity and enabled value", app: app)
        try sourceToolsRequire(sourceToolsVisibleSourceToggle(app, sourceID: sourceID, sourceIDs: sourceIDs) != nil,
            "The exact source toggle must be fully visible in its source-bound row, list and window", app: app)
        let selection = try XCTUnwrap(sourceToolsVisibleSourceToggle(app, sourceID: sourceID, sourceIDs: sourceIDs))
        let facts = XCTAttachment(string: "sourceId=\(sourceID)\nsourceReadRevision=\(readRevision)\nnativeHittable=\(selection.toggle.isHittable)\nswitchFrame=\(selection.frame)\nsourceViewport=\(selection.viewport)\nexactHeaderEditBand=\(selection.rowBand)\nOnly this exact switch may receive one tap; a coordinate fallback uses its current native center.")
        facts.name = "exact-original-source-disable-selection"; facts.lifetime = .keepAlways; add(facts)
        // Recheck after recording selection, then derive the action from fresh
        // geometry. Neither an offscreen frame nor a stale read can be tapped.
        try sourceToolsRequire(sourceToolsSourceState(app) == expectedState
            && sourceToolsSourceLabels(app) == labels && sourceToolsSourceValues(app, sourceIDs: sourceIDs) == values,
            "The original source state must remain unchanged immediately before its sole disable", app: app)
        let current = try XCTUnwrap(sourceToolsVisibleSourceToggle(app, sourceID: sourceID, sourceIDs: sourceIDs))
        beforeTap(); tapCount += 1
        if current.toggle.isHittable {
            current.toggle.tap()
        } else {
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: current.frame.midX - app.frame.minX,
                dy: current.frame.midY - app.frame.minY)).tap()
        }
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
        let inputURL: URL
        if inputPath.hasPrefix("bundle:") {
            let resourceName = String(inputPath.dropFirst("bundle:".count))
            inputURL = try XCTUnwrap(Bundle(for: ReaderOnlineJourneyTests.self).url(forResource: resourceName, withExtension: nil))
        } else {
            inputURL = URL(fileURLWithPath: inputPath)
        }
        try sourceToolsRequire((inputPath.hasPrefix("/") || inputPath.hasPrefix("bundle:"))
                               && expectedSHA == "f7bc4ad5b7a28101e81b48d1d321a32e31346505aab85c02efd2509ba3c16d41",
                               "Only the Root-bound original real response file is admitted", app: nil)
        let raw = try Data(contentsOf: inputURL)
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
        let responsesBefore = responses.value as? String ?? ""
        let isEmptyDraft = (keyBefore.isEmpty || keyBefore == key.placeholderValue) && responsesBefore == "{}"
        let isOwnedRealDraft = keyBefore == "剑来" && responsesBefore == originalInput
        try sourceToolsRequire((isEmptyDraft || isOwnedRealDraft) && run.label == "运行" && !result.exists,
                               "Never overwrite an existing user debug key/response draft or pending run", app: app)
        if isOwnedRealDraft {
            let reused = XCTAttachment(string: "reusedPreviouslyVerifiedRealDraft=true\nkey=剑来\ninputUTF8Bytes=\(raw.count)\ninputSHA256=\(expectedSHA)")
            reused.name = "source-debug-real-draft-reused-without-overwrite"; reused.lifetime = .keepAlways; add(reused)
        } else {
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
            // SwiftUI's TextEditor can expose a cleared native value as nil while
            // its actual visible text is empty. Treat nil and "" as the same
            // empty state; the exact real response assertion below remains strict.
            let clearedValue = responses.value as? String
            try sourceToolsRequire(clearedValue == nil || clearedValue == "", "Only the observed default two-character JSON may be cleared", app: app)
            responses.typeText(originalInput) // One normal input; no clipboard, route or App-state injection.
        }
        try sourceToolsRequire((responses.value as? String) == originalInput, "Require the entire exact actual HTTP replay JSON after native input", app: app)
        let input = XCTAttachment(string: "sourceID=\(sourceID)\nkey=剑来\ninputUTF8Bytes=\(raw.count)\ninputSHA256=\(expectedSHA)\ninputOrigin=\(inputPath)\nOriginal capture only searchResponse; omitted inner sourceId must be bound by Host, never inserted into the user's editor. L3-L5 are explicitly not supplied.")
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

    /// Native read/review/Cancel only. Root binds the real stopped-library
    /// snapshot and separately compares raw preferences/Core after this method;
    /// AX field equality is not a proof of private JSON-byte preservation.
    func testExistingRealSubscriptionDraftReadOnlyReviewConfirmationCancelAndColdRetentionPreservesOriginalState() throws {
#if targetEnvironment(simulator)
        XCTFail("This journey requires the bound physical iPhone")
        throw SourceToolsFailure.prerequisite
#endif
        struct Proof: Decodable {
            let schemaVersion: Int
            let policy: String
            let runID: String
            let capturedAtUnixSeconds: Double
            let targetDeviceUDID: String
            let bundleIdentifier: String
            let installedAppSHA256: String
            let installedRunnerSHA256: String
            let snapshotSHA256: String
            let pendingSubscriptionOperationIDs: [String]
            let acceptedIntentAbsent: Bool
            let sourceLabels: [String: String]
            let subscriptionRawBase64: String
            let subscriptionSHA256: String
            let draftRawBase64: String?
            let draftSHA256: String?
            let draftIdentityRawBase64: String?
            let draftIdentitySHA256: String?
        }
        struct Subscription: Decodable {
            let id: Int64; let name: String; let url: String; let type: Int32
            let customOrder: Int32; let autoUpdate: Bool; let update: Int64
        }
        struct Draft: Decodable {
            let isPresent: Bool; let id: Int64; let name: String; let url: String
            let type: Int32; let order: String; let autoUpdate: Bool; let update: Int64
        }
        func sha(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
        func validSHA(_ value: String) -> Bool {
            value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
        }
        func boundBytes(_ encoded: String?, _ expectedSHA: String?) throws -> Data? {
            if encoded == nil && expectedSHA == nil { return nil }
            guard let encoded, let expectedSHA, let bytes = Data(base64Encoded: encoded),
                  !bytes.isEmpty, bytes.count <= 32 * 1024, validSHA(expectedSHA), sha(bytes) == expectedSHA else {
                try sourceToolsRequire(false, "Require complete original bytes and their exact SHA-256; never infer an empty draft", app: nil)
                throw SourceToolsFailure.prerequisite
            }
            return bytes
        }
        let environment = ProcessInfo.processInfo.environment
        let encoded = try XCTUnwrap(environment["READER_SUBSCRIPTION_REVIEW_PREPROOF_B64"])
        let expectedProofSHA = try XCTUnwrap(environment["READER_SUBSCRIPTION_REVIEW_PREPROOF_SHA256"])
        let proofBytes = try XCTUnwrap(Data(base64Encoded: encoded))
        try sourceToolsRequire(proofBytes.count <= 128 * 1024 && validSHA(expectedProofSHA) && sha(proofBytes) == expectedProofSHA,
            "Bind the exact private same-run preproof", app: nil)
        let proof = try JSONDecoder().decode(Proof.self, from: proofBytes)
        let age = Date().timeIntervalSince1970 - proof.capturedAtUnixSeconds
        try sourceToolsRequire(UIDevice.current.userInterfaceIdiom == .phone && proof.schemaVersion == 1
            && proof.policy == "physical-real-subscription-draft-review-cancel-v1"
            && UUID(uuidString: proof.runID) != nil && !proof.targetDeviceUDID.isEmpty
            && proof.bundleIdentifier == "io.reader.minliny.free" && age >= -5 && age <= 600
            && validSHA(proof.installedAppSHA256) && validSHA(proof.installedRunnerSHA256) && validSHA(proof.snapshotSHA256)
            && proof.pendingSubscriptionOperationIDs.isEmpty && proof.acceptedIntentAbsent && !proof.sourceLabels.isEmpty,
            "Require the fresh physical target/artifact/snapshot binding and no accepted or unknown subscription writes", app: nil)
        let subscriptionBytes = try XCTUnwrap(try boundBytes(proof.subscriptionRawBase64, proof.subscriptionSHA256))
        let original = try JSONDecoder().decode(Subscription.self, from: subscriptionBytes)
        let originalURL = try XCTUnwrap(URLComponents(string: original.url))
        try sourceToolsRequire(["http", "https"].contains(originalURL.scheme?.lowercased() ?? "")
            && !(originalURL.host ?? "").isEmpty, "Use only the original real saved HTTP(S) subscription DTO", app: nil)
        let originalDraftBytes = try boundBytes(proof.draftRawBase64, proof.draftSHA256)
        let originalIdentityBytes = try boundBytes(proof.draftIdentityRawBase64, proof.draftIdentitySHA256)
        let wasAbsent = originalDraftBytes == nil
        let expected: Draft
        if let originalDraftBytes {
            expected = try JSONDecoder().decode(Draft.self, from: originalDraftBytes)
            let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: originalDraftBytes) as? [String: Any])
            let baseline = raw["baseline"] as? [String: Any]
            try sourceToolsRequire(expected.isPresent && expected.id == original.id && baseline?["absent"] == nil,
                "An existing user draft must belong to this exact saved subscription; never replace an unrelated or new-row draft", app: nil)
        } else {
            try sourceToolsRequire(originalIdentityBytes == nil, "Only genuinely absent draft/identity keys authorize an owned temporary editor draft", app: nil)
            // These are the real Core DTO's fields, exactly as the normal Edit
            // action copies them. No subscription, source or body is generated.
            expected = Draft(isPresent: true, id: original.id, name: original.name, url: original.url,
                type: original.type, order: String(original.customOrder), autoUpdate: original.autoUpdate, update: original.update)
        }
        let app = XCUIApplication(bundleIdentifier: proof.bundleIdentifier)
        let deadline = ProcessInfo.processInfo.systemUptime + 180
        var cleanupDeadline: TimeInterval?
        var createdDraft = false, discardedCreatedDraft = false
        func require(_ condition: Bool, _ message: String) throws { try sourceToolsRequire(condition, message, app: app) }
        func wait(_ message: String, timeout: TimeInterval = 12, _ condition: @escaping () -> Bool) throws {
            let remaining = (cleanupDeadline ?? deadline) - ProcessInfo.processInfo.systemUptime
            try require(remaining > 0, "Bounded native review deadline: " + message)
            try sourceToolsWait(message, timeout: min(timeout, remaining), condition)
        }
        func button(_ id: String) throws -> XCUIElement {
            let matches = app.buttons.matching(NSPredicate(format: "identifier == %@", id))
            try require(matches.count == 1, "One exact actual button: " + id)
            return matches.element
        }
        func labeledButton(_ label: String) throws -> XCUIElement {
            let matches = app.buttons.matching(NSPredicate(format: "label == %@", label))
            try require(matches.count == 1, "One exact actual native action: " + label)
            return matches.element
        }
        func tap(_ element: XCUIElement) throws {
            try require(element.exists && element.isEnabled && element.isHittable,
                "Use the actual visible enabled control, without coordinate fallback: " + element.identifier)
            element.tap()
        }
        func reveal(_ element: XCUIElement, in scroll: XCUIElement, towardTop: Bool = false) throws {
            let until = min(cleanupDeadline ?? deadline, ProcessInfo.processInfo.systemUptime + 24)
            var previous: CGRect?
            for _ in 0..<8 {
                try require(ProcessInfo.processInfo.systemUptime < until && scroll.exists,
                    "Bounded actual scroll host must remain available")
                if element.exists {
                    let frame = element.frame
                    if element.isHittable && frame.intersection(scroll.frame).height > 8 { return }
                    try require(previous != frame, "Stop a non-progressing viewport; do not retry another scope")
                    previous = frame
                }
                if towardTop { scroll.swipeDown() } else { scroll.swipeUp() }
            }
            try require(false, "The exact real control was not reached within eight native scrolls: " + element.identifier)
        }
        func editorScroll() throws -> XCUIElement {
            let matches = app.scrollViews.containing(.textField, identifier: "subscription-name")
            try require(matches.count == 1, "Use the one actual editor ScrollView")
            return matches.element
        }
        func fieldValue(_ field: XCUIElement) -> String {
            let value = field.value as? String ?? ""
            return value == field.placeholderValue ? "" : value
        }
        func requireFields() throws {
            let names = app.textFields.matching(identifier: "subscription-name")
            let urls = app.textFields.matching(identifier: "subscription-url")
            try require(names.count == 1 && urls.count == 1, "One real retained draft editor")
            let scroll = try editorScroll()
            let orders = scroll.textFields.allElementsBoundByIndex.filter { $0.placeholderValue == "排序值" }
            let toggles = scroll.switches.matching(NSPredicate(format: "label == %@", "允许自动更新"))
            try require(orders.count == 1 && toggles.count == 1, "Observe the actual order and auto-update controls without changing them")
            try require(fieldValue(names.element) == expected.name && fieldValue(urls.element) == expected.url
                && fieldValue(orders[0]) == expected.order && toggles.element.value as? String == (expected.autoUpdate ? "1" : "0"),
                "Every visible raw input must equal the bound original draft, including whitespace")
            let kind = expected.type == 0 ? "书源包" : "现有包类型 \(expected.type)"
            try require(scroll.staticTexts.matching(NSPredicate(format: "label == %@", kind)).count >= 1,
                "Preserve the draft's original package type")
            try require(try button("subscription-save").isEnabled && !app.staticTexts["正在核对订阅操作"].exists,
                "No pending subscription write may be consumed or replaced")
        }
        func requireOriginalRow() throws {
            let name = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "subscription:\(original.id)"))
            let url = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "subscription-url:\(original.id)"))
            try require(name.count == 1 && url.count == 1 && name.element.label == (original.name.isEmpty ? "未命名订阅" : original.name)
                && url.element.label == original.url, "Retain the exact original saved subscription identity/name/URL")
        }
        func openSubscriptions() throws {
            try wait("The same real shelf must load") { app.buttons["更多书架操作"].exists }
            try tap(try labeledButton("更多书架操作"))
            try wait("Open the real search/source route") { app.buttons["搜索与书源"].exists }
            try tap(try labeledButton("搜索与书源"))
            try wait("Open existing source management") { app.buttons["online-open-sources"].exists }
            try tap(try button("online-open-sources"))
            try wait("Read the original sources") { app.buttons["online-source-file"].exists }
            try require(try sourceToolsSourceLabels(app) == proof.sourceLabels, "Original source identities remain unchanged")
            let entry = try button("online-rule-subscriptions")
            try reveal(entry, in: app.scrollViews["online-source-scroll"], towardTop: true); try tap(entry)
            try wait("Read the original subscription list") {
                app.buttons["subscription-add"].exists && app.buttons["subscription-add"].isEnabled
                    && !app.staticTexts["正在读取订阅"].exists
            }
            try requireOriginalRow()
        }
        func openRetainedDraft() throws {
            let entry = try button("subscription-add")
            try require(entry.label == "继续草稿", "Reopen only the retained same-ID draft; never create a replacement")
            try tap(entry)
            try wait("The original raw draft must reopen") { app.textFields["subscription-name"].exists }
            try requireFields()
        }
        func closeEditor() throws {
            try tap(try labeledButton("保留草稿并关闭"))
            try wait("Normal editor close must preserve its draft") {
                !app.textFields["subscription-name"].exists && app.buttons["subscription-add"].label == "继续草稿"
            }
        }
        func closeReadHosts() throws {
            try tap(try labeledButton("关闭订阅管理"))
            try wait("Return to the original source host") { app.buttons["online-close-sources"].isHittable }
            try require(try sourceToolsSourceLabels(app) == proof.sourceLabels, "Read/review cannot replace the original sources")
            try tap(try button("online-close-sources"))
            try wait("Return to the original workspace") { app.buttons["online-close-workspace"].isHittable }
            try tap(try button("online-close-workspace"))
            try wait("Normal return to the original shelf") { app.buttons["更多书架操作"].isHittable }
        }
        func discardOwnedDraft() throws {
            try require(wasAbsent && createdDraft && !discardedCreatedDraft,
                "Never discard an original user draft")
            if !app.textFields["subscription-name"].exists { try openRetainedDraft() }
            try requireFields()
            let discard = try labeledButton("放弃草稿")
            try reveal(discard, in: try editorScroll()); try tap(discard)
            let alert = app.alerts["放弃这个草稿？"]
            try wait("The actual owned-draft discard confirmation must appear") { alert.exists }
            try require(alert.staticTexts["已保存的订阅不受影响。"].exists
                && alert.buttons["放弃"].isHittable && alert.buttons["取消"].exists,
                "Discard only this method's editor draft, never the saved subscription")
            keepScreenshot(app, name: "subscription-review-owned-draft-discard-confirmation")
            alert.buttons["放弃"].tap()
            try wait("The test-created draft must be withdrawn through its normal UI") {
                !app.textFields["subscription-name"].exists && app.buttons["subscription-add"].label == "添加"
            }
            discardedCreatedDraft = true
            try requireOriginalRow()
        }
        addTeardownBlock {
            if createdDraft && !discardedCreatedDraft {
                cleanupDeadline = ProcessInfo.processInfo.systemUptime + 45
                do {
                    try require(app.state == .runningForeground, "Owned draft cleanup requires its known foreground App; no relaunch fallback")
                    let reviewAlert = app.alerts["使用本次核对的编辑基线？"]
                    if reviewAlert.exists { try tap(reviewAlert.buttons["取消"]) }
                    try require(!app.alerts.firstMatch.exists, "Never accept an unknown alert during owned cleanup")
                    try discardOwnedDraft()
                } catch {
                    let result = XCTAttachment(string: "OWNED_DRAFT_CLEANUP_NOT_COMPLETED\nrunID=\(proof.runID)\nDo not discard any other draft or alter preferences externally. Root must inspect the same-run stopped snapshot before further work.")
                    result.name = "subscription-review-owned-cleanup-required"; result.lifetime = .keepAlways; self.add(result)
                    XCTFail("The method-created draft could not be safely withdrawn through native UI: \(error)")
                }
            }
        }
        app.launch()
        try openSubscriptions()
        let entry = try button("subscription-add")
        try require(entry.label == (wasAbsent ? "添加" : "继续草稿"), "UI draft presence must agree with the exact stopped-state bytes")
        if wasAbsent {
            let check = try button("subscription-check:\(original.id)")
            let scroll = app.scrollViews["subscription-scroll"]
            try reveal(check, in: scroll)
            let edits = scroll.buttons.matching(NSPredicate(format: "label == %@", "编辑")).allElementsBoundByIndex.filter {
                $0.isHittable && $0.isEnabled && abs($0.frame.midY - check.frame.midY) < 24
            }
            try require(edits.count == 1, "The Edit action must belong to this exact original subscription's control row")
            createdDraft = true // Ownership starts before the one real Edit tap.
            try tap(edits[0])
            try wait("Only the original DTO's editor draft may be created") { app.textFields["subscription-name"].exists }
            try requireFields()
        } else { try openRetainedDraft() }
        keepScreenshot(app, name: "subscription-review-original-raw-editor-fields")
        let review = try button("subscription-review-draft")
        try reveal(review, in: try editorScroll()); try tap(review)
        let editor = try editorScroll()
        // The comparison VStack's identifier is inherited by its AX children,
        // including the confirmation button. Bind real labels/types to this editor.
        let heading = editor.staticTexts.matching(NSPredicate(format: "label == %@", "当前订阅与保留草稿"))
        let identifierRows = editor.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "订阅编号："))
        let confirmButtons = editor.buttons.matching(NSPredicate(format: "label == %@", "确认核对，保留草稿"))
        try wait("Render the real local Core subscription/draft comparison without a provider request") {
            heading.count == 1 && identifierRows.count == 1 && confirmButtons.count == 1
        }
        let displayedID = String(identifierRows.element.label.dropFirst("订阅编号：".count))
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = .current
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 0
        numberFormatter.generatesDecimalNumbers = true
        numberFormatter.isLenient = false
        let originalNumber = NSNumber(value: original.id)
        // Require the entire locale-formatted value as well as its exact integer
        // meaning; a numeric prefix or another subscription cannot pass.
        try require(numberFormatter.number(from: displayedID)?.decimalValue == originalNumber.decimalValue
            && numberFormatter.string(from: originalNumber) == displayedID
            && !editor.staticTexts["未找到原订阅"].exists,
            "The comparison must belong to the same actual saved subscription")
        let pairs = [(original.name, expected.name), (original.url, expected.url),
            (original.type == 0 ? "书源包" : "现有包类型 \(original.type)", expected.type == 0 ? "书源包" : "现有包类型 \(expected.type)"),
            (String(original.customOrder), expected.order), (original.autoUpdate ? "允许" : "关闭", expected.autoUpdate ? "允许" : "关闭")]
        for pair in pairs {
            try require(editor.staticTexts.matching(NSPredicate(format: "label == %@", "当前：" + pair.0)).count >= 1
                && editor.staticTexts.matching(NSPredicate(format: "label == %@", "草稿：" + pair.1)).count >= 1,
                "Every full current/draft field must be shown, without truncating its AX value")
        }
        try reveal(heading.element, in: editor)
        keepScreenshot(app, name: "subscription-review-actual-current-and-retained-fields")
        let confirmReview = confirmButtons.element
        try reveal(confirmReview, in: editor); try tap(confirmReview)
        let alert = app.alerts["使用本次核对的编辑基线？"]
        try wait("The production native baseline confirmation must appear") { alert.exists }
        try require(alert.buttons["确认核对"].exists && alert.buttons["取消"].isHittable
            && alert.staticTexts["全部草稿输入都会保留。本次确认不保存；之后另点保存会用草稿的全部配置更新订阅。"].exists,
            "The actual confirmation must explicitly separate baseline confirmation from Save")
        keepScreenshot(app, name: "subscription-review-native-baseline-confirmation-before-cancel")
        let actualAX = XCTAttachment(string: app.debugDescription); actualAX.name = "subscription-review-native-confirmation-actual-AX"
        actualAX.lifetime = .keepAlways; add(actualAX)
        alert.buttons["取消"].tap()
        try wait("Cancel must return to the same unchanged comparison") {
            !alert.exists && heading.count == 1 && confirmButtons.count == 1
        }
        try requireFields()
        try closeEditor(); try requireOriginalRow(); try closeReadHosts()
        app.terminate(); app.launch()
        try openSubscriptions(); try openRetainedDraft()
        let coldEditor = try editorScroll()
        try require(coldEditor.staticTexts.matching(NSPredicate(format: "label == %@", "当前订阅与保留草稿")).count == 0
            && coldEditor.buttons.matching(NSPredicate(format: "label == %@", "确认核对，保留草稿")).count == 0,
            "A cold editor must retain input without reviving the old read comparison")
        keepScreenshot(app, name: "subscription-review-cold-retained-original-fields")
        if createdDraft { try discardOwnedDraft() } else { try closeEditor() }
        try closeReadHosts()
        let facts: [String: Any] = ["schemaVersion": 1, "runID": proof.runID, "preproofSHA256": expectedProofSHA,
            "targetDeviceUDID": proof.targetDeviceUDID, "installedAppSHA256": proof.installedAppSHA256,
            "installedRunnerSHA256": proof.installedRunnerSHA256, "snapshotSHA256": proof.snapshotSHA256,
            "subscriptionSHA256": proof.subscriptionSHA256, "originalDraftSHA256": (proof.draftSHA256 as Any?) ?? NSNull(),
            "originalDraftIdentitySHA256": (proof.draftIdentitySHA256 as Any?) ?? NSNull(), "originalDraftAbsent": wasAbsent,
            "createdEditorDraft": createdDraft, "discardedOnlyCreatedDraft": discardedCreatedDraft,
            "reviewTapCount": 1, "baselineConfirmationCancelCount": 1, "coldLaunchCount": 1,
            "saveTapCount": 0, "applyTapCount": 0, "subscriptionDeleteTapCount": 0, "providerCheckTapCount": 0,
            "boundary": "Actual native read/review/Cancel and cold raw-field retention only. No baseline confirmation or Core write. Original private draft/companion JSON bytes, hidden id/type/update/baseline/revision, full subscription DTO, source definitions, original commands and user library require Root's independent same-run stopped postproof. New editor draft is discarded only when both original keys were absent. Artifact/target hashes are external preproof bindings, not bytes read by this UI method. No upstream freshness, authentication or full visual-parity claim."]
        let result = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        result.name = "subscription-review-native-cancel-cold-retention-and-external-postproof-boundary"
        result.lifetime = .keepAlways; add(result)
    }

    /// Uses the exact existing subscription bound from a fresh, read-only
    /// device snapshot through the UI test runner. This method never
    /// creates/edits/deletes a subscription, changes a toggle or applies sources.
    /// Real HTTP/admission failures stay FAIL; an empty diff is not a new release.
    func testExistingRealSubscriptionPreviewForegroundInvalidationAndExplicitRecheckPreserveOriginalState() throws {
        let environment = ProcessInfo.processInfo.environment
        let subscriptionID = try XCTUnwrap(environment["READER_SUBSCRIPTION_OWNED_ID"],
                                            "Bind the current real Core subscription ID before running")
        let expectedName = try XCTUnwrap(environment["READER_SUBSCRIPTION_OWNED_NAME"],
                                         "Bind the current real Core subscription name before running")
        let expectedURL = try XCTUnwrap(environment["READER_REAL_SUBSCRIPTION_URL"],
                                        "Bind the current real saved URL before running")
        XCTAssertNotNil(Int64(subscriptionID), "The bound subscription ID must be a Core integer identity")
        XCTAssertTrue(expectedName.hasPrefix("原生订阅-"), "Use the existing owned subscription")
        XCTAssertEqual(expectedURL, "https://shuyuan-api.yiove.com/import/book-source-collection/3d9f811b-0831-4203-9fcb-3e8020f8aa2d",
                       "Use the original real provider URL, not a replacement package")
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
