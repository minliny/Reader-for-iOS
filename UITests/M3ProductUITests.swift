import Foundation
import XCTest

@MainActor
final class M3ProductUITests: XCTestCase {
    private let app = XCUIApplication()
    private let origin = "http://127.0.0.1:18765"
    private let suite = "m3" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(10)

    func test01MangaPreviewRetryChaptersAndColdRead() async throws {
        continueAfterFailure = false
        let route = "/m3/product/\(suite)/manga/primary"
        let title = "回环漫画 \(suite)"
        app.launch()
        importRules(route)
        searchAndOpen(title, sourceName: "回环漫画 primary \(suite)")
        tap("m2-detail-add")
        assertValue(element("m2-detail-add"), contains: "已加入书架", property: "label")
        tap("m2-detail-read")
        assertValue(element("m3-manga-page"), contains: "1/3")
        attach("M3 漫画条漫")
        try await control("configure", path: route + "/long.png", mode: "offline")
        tap("m3-manga-next")
        wait("m3-manga-retry")
        assertValue(element("m3-manga-page"), contains: "2/3")
        let placeholder = element("m3-manga-unavailable")
        let failedBounds = placeholder.frame
        let failedID = try XCTUnwrap(placeholder.value as? String)
        tap("m3-manga-retry")
        wait("m3-manga-retry")
        XCTAssertEqual(placeholder.frame, failedBounds)
        XCTAssertEqual(placeholder.value as? String, failedID)
        attach("M3 原图重试占位")
        try await control("release", path: route + "/long.png")
        tap("m3-manga-retry")
        let artwork = wait("m3-manga-page-art", timeout: 30)
        assertValue(artwork, contains: failedID)
        assertValue(artwork, contains: "16 个切片")
        attach("M3 超长图分片绘制")
        tap("m3-manga-horizontal")
        assertValue(element("m3-manga-page"), contains: "2/3")
        tap("m3-manga-directory")
        tap("directory-chapter-1")
        waitText("第二话 · 夜渡")
        assertValue(element("m3-manga-page"), contains: "1/1")
        tap("m3-manga-download")
        tap("m3-manga-download-start-1")
        assertValue(element("m3-manga-download-state-1"), contains: "可离线阅读", property: "label", timeout: 45)
        tapLabel("关闭")
        let retainedPath = route + "/last.png"
        let priorRequests = try await requests(for: retainedPath)
        try await control("configure", path: retainedPath, mode: "offline")
        tap("m3-manga-back")
        wait("m2-detail-page")
        app.terminate()
        app.launch()
        waitText(title).tap()
        tap("m2-detail-read")
        waitText("第二话 · 夜渡")
        wait("m3-manga-page-art")
        let offlineRequests = try await requests(for: retainedPath)
        XCTAssertEqual(offlineRequests, priorRequests, "Downloaded image must reopen without HTTP")
        try await control("release", path: retainedPath)
        print("M3_UI_MANGA_OFFLINE cold=true retainedFile=true imageRequests=0")
        tap("m3-manga-directory")
        tap("directory-chapter-0")
        waitText("第一话 · 晚钟")
        tap("m3-manga-next")
        let restoredArtwork = wait("m3-manga-page-art")
        assertValue(restoredArtwork, contains: failedID)
        restoredArtwork.swipeUp(velocity: .slow)
        tap("m3-manga-back")
        wait("m2-detail-page")
        app.terminate()
        app.launch()
        let onShelf = waitText(title)
        onShelf.tap()
        tap("m2-detail-read")
        assertValue(element("m3-manga-page"), contains: "2/3")
        assertValue(wait("m3-manga-page-art"), contains: failedID)
        attach("M3 独立进程冷启恢复")
        print("M3_UI_MANGA preview=true retryInPlace=true logicalPage=2 tiles=16 direction=true chapters=2 download=true coldSamePage=true")
        tap("m3-manga-switch")
        let candidate = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "m2-switch-candidate-", "回环漫画 other \(suite)"
        )).firstMatch
        XCTAssertTrue(candidate.waitForExistence(timeout: 30), app.debugDescription)
        candidate.tap()
        XCTAssertTrue(element("m2-switch-sheet").waitForNonExistence(timeout: 30))
        assertValue(element("m3-manga-page"), contains: "1/3")
        let switched = wait("m3-manga-page-art")
        XCTAssertFalse((switched.value as? String)?.contains(failedID) ?? true)
        print("M3_UI_MANGA_SWITCH checkedTarget=true proposedFirstPage=true")
        tap("m3-manga-back")
    }

    func test02SpeechHighlightCapsuleAndConfiguration() async throws {
        continueAfterFailure = false
        importAndOpenText()
        tap("reader-controls")
        tap("reader-tts-start")
        let highlight = wait("reader-tts-highlight", timeout: 25)
        let writtenRange = try XCTUnwrap(highlight.value as? String)
        XCTAssertNotNil(writtenRange.wholeMatch(of: /[0-9]+\.\.<[0-9]+/))
        assertValue(element("reader-tts-capsule"), contains: "朗读中")
        attach("M3 正文实时高亮与听书胶囊")
        tap("reader-tts-open-panel")
        wait("reader-tts-panel")
        attach("M3 朗读播控面板")
        tap("reader-tts-panel-close")
        assertValue(element("reader-tts-capsule"), contains: "朗读中")
        wait("reader-tts-highlight")
        tap("reader-tts-open-panel")
        tap("reader-tts-configuration")
        wait("reader-tts-config")
        tap("reader-tts-engine-add")
        enter("M3 Loopback Voice", in: "reader-tts-engine-name")
        enter("https://127.0.0.1:18766/m3/speech/audio.wav", in: "reader-tts-engine-url")
        tap("reader-tts-engine-save")
        waitText("M3 Loopback Voice")
        attach("M3 HttpTTS 配置与编辑回读")
        back()
        tap("reader-tts-panel-close")
        assertValue(element("reader-tts-capsule"), contains: "朗读中")
        back()
        wait("m2-detail-page")
        XCTAssertTrue(element("reader-tts-capsule").waitForNonExistence(timeout: 12))
        tap("m2-detail-read")
        wait("reader-text-surface")
        XCTAssertFalse(element("reader-tts-capsule").exists)
        print("M3_UI_SPEECH coreHighlight=true capsule=true panelDismissContinues=true httpEngineSaved=true exitRetired=true")
    }

    private func importAndOpenText() {
        app.launch()
        let route = "/m3/product/\(suite)/text/primary"
        importRules(route)
        searchAndOpen("回环小说 \(suite)", sourceName: "回环朗读 primary \(suite)")
        tap("m2-detail-read")
        wait("reader-text-surface")
    }

    private func importRules(_ route: String) {
        openSourceMenu()
        tap("reader-open-sources")
        tap("source.add")
        tapLabel("网址")
        enter(origin + route + "/import", in: "source.import.url")
        tap("source.import.preview")
        tap("source.import.confirm")
        tapAlertButton("确认导入")
        wait("source.import.result", timeout: 25)
        tap("source.import.done")
        back()
    }

    private func searchAndOpen(_ title: String, sourceName: String) {
        tap("reader-online-search")
        enter(String(suite), in: "m2-search-field")
        tap("m2-search-submit")
        let matching = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@ AND label CONTAINS %@",
            "m2-search-result-", title, sourceName)).firstMatch
        XCTAssertTrue(matching.waitForExistence(timeout: 25), app.debugDescription)
        matching.tap()
        wait("m2-detail-page")
        waitText(title)
    }

    private func assertValue(_ view: XCUIElement, contains expected: String, property: String = "value",
                             timeout: TimeInterval = 25, file: StaticString = #filePath, line: UInt = #line) {
        let matches = NSPredicate(format: "exists == true AND %K CONTAINS %@", property, expected)
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: matches, object: view)], timeout: timeout)
        if result != .completed { print("M3_UI_MISSING \(property) \(expected)\n\(app.debugDescription)") }
        XCTAssertEqual(result, .completed, file: file, line: line)
    }

    private func enter(_ text: String, in identifier: String) {
        let field = wait(identifier)
        field.tap()
        field.typeText(text)
    }

    private func element(_ identifier: String, within parent: XCUIElement? = nil) -> XCUIElement {
        (parent ?? app).descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @discardableResult
    private func wait(_ identifier: String, within parent: XCUIElement? = nil, timeout: TimeInterval = 20,
                      file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let view = element(identifier, within: parent)
        let found = view.exists || view.waitForExistence(timeout: timeout)
        if !found { print("M3_UI_MISSING \(identifier)\n\(app.debugDescription)") }
        XCTAssertTrue(found, "Missing \(identifier)", file: file, line: line)
        return view
    }

    private func tap(_ identifier: String, within parent: XCUIElement? = nil) {
        let control = wait(identifier, within: parent)
        let button = (parent ?? app).buttons.matching(identifier: identifier).firstMatch
        let view = button.exists && button.isHittable ? button : control
        let enabled = NSPredicate(format: "isEnabled == true AND isHittable == true")
        let state = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: view)], timeout: 20)
        XCTAssertEqual(state, .completed, "Not hittable: \(identifier)")
        view.tap()
    }

    private func openSourceMenu() {
        let menu = wait("reader-online-menu")
        let sources = element("reader-open-sources")
        let menuButton = app.buttons["reader-online-menu"].firstMatch
        let target = menuButton.exists ? menuButton : menu
        let enabled = NSPredicate(format: "isEnabled == true AND isHittable == true")
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: target)], timeout: 20),
            .completed,
            "The shelf's source menu is not ready"
        )
        for _ in 0..<3 {
            if sources.exists { return }
            target.tap()
            if sources.waitForExistence(timeout: 4) { return }
        }
        XCTFail("The shelf's source management menu did not open. \(app.debugDescription)")
    }

    private func tapLabel(_ label: String) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15), "Missing \(label)")
        button.tap()
    }

    private func tapAlertButton(_ label: String) {
        let button = app.alerts.firstMatch.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 15), "Missing alert button \(label)")
        button.tap()
    }

    @discardableResult
    private func waitText(_ label: String) -> XCUIElement {
        let text = app.staticTexts[label].firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 20), "Missing label \(label)")
        return text
    }

    private func back() {
        let button = app.navigationBars.firstMatch.buttons.firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15), "Missing navigation back action")
        button.tap()
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func control(_ command: String, path: String, mode: String? = nil) async throws {
        var endpoint = try XCTUnwrap(URLComponents(string: origin + "/control/" + command))
        endpoint.queryItems = [URLQueryItem(name: "path", value: path)]
        if let mode { endpoint.queryItems?.append(URLQueryItem(name: "mode", value: mode)) }
        var request = URLRequest(url: try XCTUnwrap(endpoint.url))
        request.httpMethod = "POST"
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    private func requests(for path: String) async throws -> Int {
        struct FixtureState: Decodable { let counters: [String: Int] }
        let url = try XCTUnwrap(URL(string: origin + "/control/state"))
        let (bytes, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(FixtureState.self, from: bytes).counters[path, default: 0]
    }
}
