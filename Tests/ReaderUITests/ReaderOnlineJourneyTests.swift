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
        try sourceToolsRequire(UIDevice.current.userInterfaceIdiom == .phone,
            "Require the original physical phone and its existing source library", app: nil)
        let app = XCUIApplication()
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
            if app.state == .notRunning { app.launch() }
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
