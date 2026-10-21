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
            app.scrollViews["online-detail-scroll"].swipeUp()
        }
        XCTAssertTrue(addAndRead.isHittable, app.debugDescription)
        addAndRead.tap()
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
}
