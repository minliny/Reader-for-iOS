import Foundation
import XCTest

@MainActor
final class M2ProductUITests: XCTestCase {
    private let app = XCUIApplication()
    private let origin = "http://127.0.0.1:18765"
    private let suite = "uiflow" + UUID().uuidString.lowercased().prefix(8)
    private var primary: String { "/books/\(suite)/primary" }
    private var other: String { "/books/\(suite)/other" }
    private var subscription: String { "/books/\(suite)/subscription/package/1" }
    private var sourceID: String { origin + primary }

    func test01SourceV9ThroughProductUI() async throws {
        continueAfterFailure = false
        app.launch()
        importSources()
        editSource()
        checkAndInspectReport()
        try await reconcileSubscription()
        openLogin()
        back()
    }

    func test02SearchReadSwitchAndDownloadThroughProductUI() async throws {
        continueAfterFailure = false
        app.launch()
        importSources()
        back()
        try await searchAndOpenBook()
        try await readSwitchAndDownload()
    }

    private func importSources() {
        tap("reader-online-menu")
        tap("reader-open-sources")
        tap("source.add")
        tapLabel("网址")
        enter(origin + primary + "/import", in: "source.import.url")
        tap("source.import.preview")
        tap("source.import.confirm")
        tap("source.import.apply", within: app.alerts.firstMatch)
        wait("source.import.result", timeout: 20)
        tap("source.import.done")
        enter(String(suite) + "\n", in: "source.search")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 8), "Source filtering kept the keyboard over the catalog")
        wait("source.row.\(sourceID)")
        wait("source.row.\(origin + other)")
        print("M2_UI_SOURCE_IMPORT url→preview→confirm twoRows=true")
    }

    private func editSource() {
        let source = wait("source.row.\(sourceID)")
        source.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.30)).tap()
        let name = wait("source.edit.name")
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()
        let existing = name.value as? String ?? ""
        let reviewed = "Checked \(suite)"
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + reviewed)
        tap("source.edit.save")
        XCTAssertTrue(app.staticTexts[reviewed].waitForExistence(timeout: 20))
        print("M2_UI_SOURCE_EDIT conditionalName=\(reviewed)")
    }

    private func checkAndInspectReport() {
        tap("source.batch")
        tap("source.select.\(sourceID)")
        tap("source.select.\(origin + other)")
        tap("source.batch.actions")
        tap("source.check.selected")
        let keyword = wait("source.check.keyword")
        if (keyword.value as? String ?? "").isEmpty || keyword.value as? String == keyword.placeholderValue {
            keyword.tap()
            keyword.typeText(String(suite))
        }
        tap("source.check.confirm")
        wait("source.reports", timeout: 25)
        tap("source.reports")
        wait("source.report.row.\(origin + other)")
        tap("source.report.row.\(sourceID)")
        wait("source.report.detail")
        wait("source.report.stage.L5")
        attach("M2 原生分层检测报告")
        tap("source.report.detail.close")
        tap("source.reports.close")
        tap("source.batch")
        print("M2_UI_SOURCE_REPORT batch=2 L5=visible")
    }

    private func reconcileSubscription() async throws {
        tap("source.subscriptions")
        let prior = Set(previewButtons.allElementsBoundByIndex.map(\.identifier))
        tap("source.subscription.add")
        enter("Rules \(suite)", in: "source.subscription.name")
        enter(origin + subscription, in: "source.subscription.url")
        tap("source.subscription.save")
        let preview = previewButtons.matching(NSPredicate(format: "NOT (identifier IN %@)", Array(prior))).firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 20), "Missing new subscription preview")
        let previewID = preview.identifier
        tap(previewID)
        tap("source.subscription.apply")
        tap("source.subscription.confirm", within: app.alerts.firstMatch)
        try await configure(subscription, mode: "package2")
        tap(previewID)
        waitLabel("新增来源")
        attach("M2 原生订阅差异预览")
        tap("source.subscription.apply")
        tap("source.subscription.confirm", within: app.alerts.firstMatch)
        tap("source.subscription.close")
        print("M2_UI_SUBSCRIPTION twoPreviews=true addedSourceVisible=true")
    }

    private func openLogin() {
        tap("source.more.\(sourceID)")
        tap("source.login.\(sourceID)")
        wait("source.browser.address")
        XCTAssertTrue(app.webViews.staticTexts["受控书源登录"].waitForExistence(timeout: 20))
        let link = app.webViews.links["查看书目与登录说明"]
        XCTAssertTrue(link.waitForExistence(timeout: 12))
        link.tap()
        XCTAssertTrue(app.webViews.staticTexts["受控回环书"].waitForExistence(timeout: 15))
        tap("source.browser.back")
        XCTAssertTrue(app.webViews.staticTexts["受控书源登录"].waitForExistence(timeout: 15))
        tap("source.browser.forward")
        XCTAssertTrue(app.webViews.staticTexts["受控回环书"].waitForExistence(timeout: 15))
        tap("source.browser.back")
        XCTAssertTrue(app.webViews.staticTexts["受控书源登录"].waitForExistence(timeout: 15))
        tap("source.browser.refresh")
        XCTAssertTrue(app.webViews.staticTexts["受控书源登录"].waitForExistence(timeout: 20))
        attach("M2 原生浏览器式登录")
        tap("source.browser.done")
        wait("source.row.\(sourceID)")
        print("M2_UI_LOGIN WKWebView=true navigationBackForward=true reload=true finished=true")
    }

    private func searchAndOpenBook() async throws {
        tap("reader-online-search")
        enter(String(suite), in: "m2-search-field")
        let primarySearch = primary + "/search"
        let secondarySearch = other + "/search"
        try await configure(primarySearch, mode: "hold")
        try await configure(secondarySearch, mode: "hold")
        tap("m2-search-submit")
        do {
            try await waitForFixtureRequest([primarySearch, secondarySearch])
            tap("m2-search-stop")
            XCTAssertFalse(wait("m2-search-submit").isEnabled)
            try await release(primarySearch)
            try await release(secondarySearch)
        } catch {
            try? await release(primarySearch)
            try? await release(secondarySearch)
            throw error
        }
        tap("m2-search-retry")
        tap("m2-search-result-0")
        wait("m2-detail-page")
        waitLabel("受控回环书")
        tap("m2-detail-add")
        tap("m2-detail-read")
        wait("reader-text-surface", timeout: 25)
        print("M2_UI_SEARCH stoppedOldPublication=true retried=true shelfAdd=true")
    }

    private func readSwitchAndDownload() async throws {
        tap("m2-reader-tools")
        tapLabel("刷新正文")
        waitLabel("正文已刷新")
        try await verifyReaderOfflineState()
        let sourceBeforeSwitch = try XCTUnwrap(wait("m2-reader-tools").value as? String)
        tap("m2-reader-tools")
        tapLabel("换源")
        wait("m2-switch-sheet")
        let primarySource = "回环来源 primary \(suite)"
        let otherSource = "回环来源 other \(suite)"
        XCTAssertTrue([primarySource, otherSource].contains(sourceBeforeSwitch))
        let targetSource = sourceBeforeSwitch == primarySource ? otherSource : primarySource
        switchToFixtureSource(targetSource)
        let tools = wait("m2-reader-tools", timeout: 25)
        let changed = NSPredicate(format: "isHittable == true AND value == %@", targetSource)
        let sourceChanged = XCTNSPredicateExpectation(predicate: changed, object: tools)
        XCTAssertEqual(XCTWaiter.wait(for: [sourceChanged], timeout: 25), .completed)
        tap("m2-reader-tools", timeout: 25)
        tapLabel("下载")
        wait("m2-download-page")
        tap("m2-download-start-0")
        let chapter = wait("m2-download-state-1")
        let completed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "已完成"), object: chapter)
        XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 25), .completed)
        attach("M2 原生下载状态")
        print("M2_UI_READER refresh=true switch=true downloadCompleted=true")
    }

    private func switchToFixtureSource(_ name: String) {
        // Repeated runs keep app data and can contain equally ranked providers
        // from earlier fixture suites. Identify the intended provider by label.
        _ = wait("m2-switch-candidate-0", timeout: 25)
        let match = NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "m2-switch-candidate-", name)
        let candidate = app.buttons.matching(match).firstMatch
        let list = app.scrollViews.firstMatch
        for _ in 0..<12 {
            if candidate.exists, candidate.isHittable { break }
            list.swipeUp()
        }
        let available = NSPredicate(format: "exists == true AND isHittable == true AND isEnabled == true")
        let readiness = XCTNSPredicateExpectation(predicate: available, object: candidate)
        let result = XCTWaiter.wait(for: [readiness], timeout: 15)
        XCTAssertEqual(result, .completed, "Fixture candidate unavailable: \(name)")
        if result == .completed { candidate.tap() }
    }

    private func verifyReaderOfflineState() async throws {
        let blocked = [primary, other].flatMap { ["\($0)/chapter/1", "\($0)/chapter/2"] }
        for path in blocked { try await configure(path, mode: "offline") }
        tap("m2-reader-tools")
        tapLabel("刷新正文")
        waitLabel("正文刷新失败，已保留当前内容和位置")
        let retained = wait("reader-text-surface")
        XCTAssertTrue(retained.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "墨纸青松")).firstMatch.exists)
        tap("m2-reader-tools")
        tapLabel("在线目录")
        tap("directory-chapter-1")
        wait("m2-reader-uncached")
        tap("m2-reader-retain-current")
        wait("reader-text-surface")
        for path in blocked { try await release(path) }
        print("M2_UI_READER_OFFLINE failedRefreshRetained=true uncachedFailure=true returnToCached=true")
    }

    private func enter(_ text: String, in identifier: String) {
        let field = wait(identifier)
        field.tap()
        field.typeText(text)
    }

    @discardableResult
    private func wait(_ identifier: String, within parent: XCUIElement? = nil, timeout: TimeInterval = 12,
                      file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let view = (parent ?? app).descendants(matching: .any).matching(identifier: identifier).firstMatch
        let found = view.exists || view.waitForExistence(timeout: timeout)
        if !found { print("M2_UI_MISSING \(identifier)\n\(app.debugDescription)") }
        XCTAssertTrue(found, "Missing \(identifier)", file: file, line: line)
        return view
    }

    private func tap(_ identifier: String, within parent: XCUIElement? = nil, timeout: TimeInterval = 12,
                     file: StaticString = #filePath, line: UInt = #line) {
        let view = wait(identifier, within: parent, timeout: timeout, file: file, line: line)
        if !view.isEnabled || !view.isHittable {
            let enabled = NSPredicate(format: "isEnabled == true AND isHittable == true")
            let readiness = XCTNSPredicateExpectation(predicate: enabled, object: view)
            let result = XCTWaiter.wait(for: [readiness], timeout: timeout)
            if result != .completed { print("M2_UI_DISABLED \(identifier)\n\(app.debugDescription)") }
            XCTAssertEqual(result, .completed, "Disabled \(identifier)", file: file, line: line)
        }
        view.tap()
    }

    private func tapLabel(_ label: String) {
        let button = app.buttons[label].firstMatch
        let found = button.exists || button.waitForExistence(timeout: 12)
        if !found { print("M2_UI_MISSING_BUTTON \(label)\n\(app.debugDescription)") }
        XCTAssertTrue(found, "Missing button \(label)")
        button.tap()
    }

    private func waitLabel(_ label: String, timeout: TimeInterval = 12) {
        let text = app.staticTexts[label].firstMatch
        let found = text.exists || text.waitForExistence(timeout: timeout)
        if !found { print("M2_UI_MISSING_TEXT \(label)\n\(app.debugDescription)") }
        XCTAssertTrue(found, "Missing text \(label)")
    }

    private var previewButtons: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "source.subscription.preview."))
    }

    private func back() {
        let button = app.navigationBars.firstMatch.buttons.firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 12), "Missing native back action")
        button.tap()
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func configure(_ path: String, mode: String) async throws {
        try await fixtureControl("configure", path: path, mode: mode)
    }

    private func release(_ path: String) async throws {
        try await fixtureControl("release", path: path)
    }

    private func fixtureControl(_ command: String, path: String, mode: String? = nil) async throws {
        var endpoint = try XCTUnwrap(URLComponents(string: origin + "/control/" + command))
        endpoint.queryItems = [URLQueryItem(name: "path", value: path)]
        if let mode { endpoint.queryItems?.append(URLQueryItem(name: "mode", value: mode)) }
        var request = URLRequest(url: try XCTUnwrap(endpoint.url))
        request.httpMethod = "POST"
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    private func waitForFixtureRequest(_ paths: [String]) async throws {
        struct FixtureState: Decodable { let counters: [String: Int] }
        struct HeldRequestTimeout: Error {}
        let stateURL = try XCTUnwrap(URL(string: origin + "/control/state"))
        let deadline = ContinuousClock.now + .seconds(12)
        while ContinuousClock.now < deadline {
            let (bytes, _) = try await URLSession.shared.data(from: stateURL)
            let state = try JSONDecoder().decode(FixtureState.self, from: bytes)
            if paths.contains(where: { state.counters[$0, default: 0] > 0 }) { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("Held loopback request did not arrive")
        throw HeldRequestTimeout()
    }
}
