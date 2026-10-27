import XCTest
import UIKit
import Vision
import Network

/// Prerequisite: the existing real package/search/admission native journey has
/// succeeded in this same App library. Process environment selects those exact
/// observed identities; it is never sent to the App or used to inject data.
final class ReaderOnlineContinuationJourneyTests: XCTestCase {
    private enum Prerequisite: Error { case missing(String), invalid(String) }
    // On the physical iPhone one complete public AX viewport observation took
    // about eight seconds. Stability requires two full observations plus the
    // polling interval; the old 10/15-second budgets expired mid-second read.
    private let settledGeometryTimeout: TimeInterval = 20
    private struct Book {
        let source: String
        let id: String
        let title: String
        var identity: String { source + "|" + id }
        var shelfID: String { "book-" + id }
    }

    override func setUpWithError() throws { continueAfterFailure = false }

    /// This proves a normal online cold reopen of an explicitly completed
    /// download. It does NOT claim the OS or source origin was offline.
    func testActualCatalogRefreshPreservesVisibleBodyThenDownloadsOneUncachedChapterAndColdReopens() throws {
        let book = try originalBook()
        let indexText = try required("READER_ONLINE_DOWNLOAD_CHAPTER_INDEX")
        guard let downloadIndex = UInt32(indexText) else {
            XCTFail("The selected real canonical download index must be an unsigned integer")
            throw Prerequisite.invalid("READER_ONLINE_DOWNLOAD_CHAPTER_INDEX")
        }
        let app = XCUIApplication(); app.launch()
        if ProcessInfo.processInfo.environment["READER_ONLINE_OPEN_CONTINUE_CARD"] == "1" {
            openContinue(app: app)
            XCTAssertTrue(element("reading-book:" + book.identity, app: app).waitForExistence(timeout: 20),
                          "The continue card must reopen the selected real source identity")
        } else {
            open(book, app: app)
        }
        let originalChapter = try currentChapter(book, app: app)
        guard abs(Int64(downloadIndex) - Int64(originalChapter)) > 2 else {
            XCTFail("Choose an actual missing chapter outside the current +/-2 reading cache window")
            throw Prerequisite.invalid("download chapter is inside the reading cache window")
        }
        hideControls(app)
        let progress = app.staticTexts["reading-progress"].label
        let originalAnchor = try anchor(app, name: "real-online-before-catalog-refresh")

        downloads(app)
        let update = app.buttons["online-update-catalog"]
        XCTAssertTrue(update.waitForExistence(timeout: 10)); XCTAssertTrue(update.isEnabled); update.tap()
        let feedback = app.staticTexts["online-catalog-feedback"]
        wait("The actual catalog request must finish", timeout: 180) {
            feedback.exists && feedback.label.hasPrefix("已取得目录，共 ") && update.isEnabled
        }
        keep(app, name: "real-online-updated-installed-catalog")
        app.buttons["online-download-close"].tap()
        XCTAssertEqual(try currentChapter(book, app: app), originalChapter)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "real-online-current-body-preserved-after-catalog-refresh")
        XCTAssertEqual(app.staticTexts["reading-progress"].label, progress)

        downloads(app)
        let stateID = "online-download-state:" + book.identity + ":" + String(downloadIndex)
        let state = element(stateID, app: app)
        let select = element("online-download-select:" + book.identity + ":" + String(downloadIndex), app: app)
        try reveal(select, in: app.scrollViews["online-download-scroll"], app: app)
        XCTAssertTrue(state.exists, "The selected index must belong to the actual installed catalog")
        XCTAssertEqual(state.label, "未下载", "A cached/completed chapter cannot satisfy the uncached-download prerequisite")
        XCTAssertTrue(select.isHittable); select.tap()
        let download = app.buttons["online-download-selected"]
        try reveal(download, in: app.scrollViews["online-download-scroll"], app: app, towardTop: true)
        XCTAssertTrue(download.isEnabled); download.tap()
        // The download list is lazy. Observe the same exact chapter in the
        // visible list rather than treating an unbuilt offscreen row as absent.
        try reveal(select, in: app.scrollViews["online-download-scroll"], app: app)
        wait("This exact chapter must complete its original download and materialization", timeout: 300) {
            state.exists && state.label == "已完成"
        }
        keep(app, name: "real-online-exact-uncached-chapter-completed")
        app.buttons["online-download-close"].tap()
        try choose(downloadIndex, app: app)
        XCTAssertEqual(try currentChapter(book, app: app), downloadIndex)
        hideControls(app)
        let downloadedAnchor = try anchor(app, name: "real-online-downloaded-chapter-reading")
        XCTAssertNotEqual(downloadedAnchor, originalAnchor)
        leave(app)

        app.terminate(); app.launch()
        open(book, app: app)
        XCTAssertEqual(try currentChapter(book, app: app), downloadIndex)
        hideControls(app)
        try visible(downloadedAnchor, app: app, name: "real-online-downloaded-body-cold-reopen-NETWORK-NOT-DISABLED")
        downloads(app)
        let retainedState = element(stateID, app: app)
        try reveal(element("online-download-select:" + book.identity + ":" + String(downloadIndex), app: app),
               in: app.scrollViews["online-download-scroll"], app: app)
        XCTAssertEqual(retainedState.label, "已完成")
        keep(app, name: "real-online-completed-download-retained-after-cold-reopen")
        app.buttons["online-download-close"].tap()
        leave(app)
    }

    /// Run only after the user has disabled the physical iPhone's network and
    /// Root has retained a fresh read-only snapshot of this original library.
    /// The environment records those observations in the UITest process only;
    /// it never changes App networking, content, cache, or reading position.
    /// This observes already cached bodies, not automatic-window acquisition
    /// or an uncached failure. Exact scalar retention needs the external
    /// pre/post snapshots; the native UI exposes percentage and visible text.
    func testExistingRealBaiduOSOfflineColdReopenAndCachedCurrentPlusMinusTwo() throws {
        try requirePhysicalOfflinePhone()
        let baseline = try offlineCachedBaseline(requireFreshStoppedCopy: false)
        let offlineEvidence = try required("READER_ONLINE_OS_OFFLINE_EVIDENCE")
        guard try required("READER_ONLINE_OS_OFFLINE_CONFIRMED") == "1" else {
            XCTFail("The manual entry requires the user's actual OS-offline confirmation")
            throw Prerequisite.invalid("manual actual OS-offline confirmation")
        }
        try runOfflineCachedColdRead(baseline, offlineEvidence: offlineEvidence)
    }

    /// The human explicitly authorized changing this physical iPhone's network.
    /// Environment binds that authorization and Root's fresh stopped copy only;
    /// actual Settings values and Network.framework supply the offline facts.
    @MainActor
    func testAuthorizedSettingsOfflineThenExistingRealBaiduCachedWindowColdReopen() throws {
        try requirePhysicalOfflinePhone()
        guard try required("READER_ONLINE_OS_NETWORK_CHANGE_AUTHORIZED") == "1" else {
            XCTFail("Require this run's explicit human authorization before any Settings action")
            throw Prerequisite.invalid("OS network change not authorized")
        }
        let baseline = try offlineCachedBaseline(requireFreshStoppedCopy: true)
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        try requireSettingsForeground(settings)
        let observations = try disableNetworkUsingActualSettings(settings)
        let path = try observeUnsatisfiedSystemPath(settings: settings)
        var actual = observations
        actual["systemPath"] = path
        actual["baselineBindingContract"] = "protected-state-summary-v1; Root retains the actual stopped copy"
        if let capturedAt = baseline.capturedAt { actual["baselineCapturedAtUnix"] = capturedAt }
        actual["authorizationEnvironment"] = "READER_ONLINE_OS_NETWORK_CHANGE_AUTHORIZED=1"
        actual["restoration"] = "NOT_PERFORMED: retain the authorized offline state; original switch values are recorded"
        let bytes = try JSONSerialization.data(withJSONObject: actual, options: [.prettyPrinted, .sortedKeys])
        let evidence = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        evidence.name = "actual-settings-switches-and-unsatisfied-system-path"
        evidence.lifetime = .keepAlways; add(evidence)
        guard let capturedAt = baseline.capturedAt, (0...600).contains(Date().timeIntervalSince1970 - capturedAt) else {
            XCTFail("The original stopped-copy preproof expired before reading; preserve the current OS state")
            throw Prerequisite.invalid("offline baseline no longer fresh")
        }
        try runOfflineCachedColdRead(baseline, offlineEvidence: String(decoding: bytes, as: UTF8.self))
    }

    private struct OfflineCachedBaseline {
        let book: Book
        let snapshotSHA: String
        let baselineChapter: String
        let baselineOffset: String
        let cachedIndexes: String
        let capturedAt: TimeInterval?
    }
    private func requirePhysicalOfflinePhone() throws {
#if targetEnvironment(simulator)
        XCTFail("This journey requires the original physical iPhone; simulator results cannot satisfy it")
        throw Prerequisite.invalid("physical iPhone required")
#endif
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            XCTFail("This journey requires the original physical iPhone")
            throw Prerequisite.invalid("iPhone required")
        }
    }
    private func offlineCachedBaseline(requireFreshStoppedCopy: Bool) throws -> OfflineCachedBaseline {
        let book = try originalBook()
        let snapshotSHA = try required("READER_ONLINE_OFFLINE_BASELINE_SHA256")
        let baselineChapter = try required("READER_ONLINE_OFFLINE_BASELINE_CHAPTER")
        let baselineOffset = try required("READER_ONLINE_OFFLINE_BASELINE_SCALAR_OFFSET")
        let cachedIndexes = try required("READER_ONLINE_OFFLINE_CACHED_INDEXES")
        guard snapshotSHA.count == 64, snapshotSHA.allSatisfy({ "0123456789abcdef".contains($0) }),
              baselineChapter == "40", baselineOffset == "0", cachedIndexes == "38,39,40,41,42",
              book.source == "https://dushu.baidu.com/", book.title == "剑来",
              book.id == "https://boxnovel.baidu.com/boxnovel/wiseapi/chapterList?bookid=4305547728&pageNum=1&order=asc&site=" else {
            XCTFail("Require fresh original Baidu chapter-40/scalar-0 cached-window provenance; never clear cache or move the position to manufacture it")
            throw Prerequisite.invalid("actual OS-offline cached-window prerequisites")
        }
        var capturedAt: TimeInterval?
        if requireFreshStoppedCopy {
            let raw = try required("READER_ONLINE_OFFLINE_BASELINE_CAPTURED_AT_UNIX")
            guard try required("READER_ONLINE_OFFLINE_BASELINE_APP_STOPPED") == "1",
                  let observed = TimeInterval(raw), observed.isFinite,
                  (0...600).contains(Date().timeIntervalSince1970 - observed) else {
                XCTFail("Require Root's actual stopped-copy receipt completed within 600 seconds before Settings; no invented preproof")
                throw Prerequisite.invalid("fresh stopped-copy offline provenance")
            }
            capturedAt = observed
        }
        return OfflineCachedBaseline(book: book, snapshotSHA: snapshotSHA, baselineChapter: baselineChapter,
            baselineOffset: baselineOffset, cachedIndexes: cachedIndexes, capturedAt: capturedAt)
    }
    private func runOfflineCachedColdRead(_ baseline: OfflineCachedBaseline, offlineEvidence: String) throws {
        let book = baseline.book, snapshotSHA = baseline.snapshotSHA
        let baselineChapter = baseline.baselineChapter, baselineOffset = baseline.baselineOffset
        let cachedIndexes = baseline.cachedIndexes
        let provenance = try JSONSerialization.data(withJSONObject: [
            "sourceId": book.source, "bookId": book.id, "title": book.title,
            "readOnlyBaselineSHA256": snapshotSHA, "observedOSOfflineEvidence": offlineEvidence,
            "observedChapterIndex": baselineChapter, "observedScalarOffset": baselineOffset,
            "observedCachedIndexes": cachedIndexes,
            "nativePositionEvidence": "Exact chapter plus unchanged percentage and visible OCR anchor; scalar comparison remains external",
            "uncachedFailureEvidence": "NOT_RUN: original Baidu 0...49 are cached; no content is removed to create a miss",
            "automaticWindowAcquisitionEvidence": "NOT_RUN: the five original bodies already exist"
        ], options: [.prettyPrinted, .sortedKeys])
        let evidence = XCTAttachment(data: provenance, uniformTypeIdentifier: "public.json")
        evidence.name = "actual-os-offline-cached-window-prerequisites-and-boundaries"
        evidence.lifetime = .keepAlways; add(evidence)

        let app = XCUIApplication(); app.launch(); open(book, app: app)
        guard try currentChapter(book, app: app) == 40 else {
            XCTFail("The original admitted book must already be at chapter 40; this method cannot prepare or repair the baseline")
            throw Prerequisite.invalid("original chapter is not 40")
        }
        hideControls(app)
        let footer = app.staticTexts["reading-progress"]
        XCTAssertTrue(footer.waitForExistence(timeout: 10))
        let originalProgress = footer.label
        guard originalProgress == "0%" else {
            XCTFail("The observed scalar-0 baseline must have its unchanged native 0% footer; do not reset a different original position")
            throw Prerequisite.invalid("original visible position differs from the retained baseline")
        }
        let originalAnchor = try anchor(app, name: "actual-os-offline-original-chapter40-before-cold-reopen")
        leave(app)

        app.terminate(); app.launch(); open(book, app: app)
        XCTAssertEqual(try currentChapter(book, app: app), 40)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "actual-os-offline-original-body-first-cold-reopen")
        XCTAssertEqual(footer.label, originalProgress)

        for index in [UInt32(38), 39, 41, 42] {
            try choose(index, app: app)
            XCTAssertEqual(try currentChapter(book, app: app), index)
            hideControls(app)
            _ = try anchor(app, name: "actual-os-offline-cached-window-chapter-\(index)")
        }

        // Normal chapter navigation lands at scalar zero. The genuine retained
        // zero baseline above makes this return preserve the original position.
        try choose(40, app: app)
        XCTAssertEqual(try currentChapter(book, app: app), 40)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "actual-os-offline-original-body-after-cached-window")
        XCTAssertEqual(footer.label, originalProgress)
        leave(app)

        app.terminate(); app.launch(); open(book, app: app)
        XCTAssertEqual(try currentChapter(book, app: app), 40)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "actual-os-offline-original-body-and-position-final-cold-reopen")
        XCTAssertEqual(footer.label, originalProgress)
        leave(app)
    }

    private let airplaneLabels = ["飞行模式", "Airplane Mode"]
    private let wifiLabels = ["Wi-Fi", "无线局域网"]
    private var settingsFallbackNavigationUsed = false
    private struct SettingsSwitchTarget {
        let owner: XCUIElement
        let control: XCUIElement
        let observation: SettingsSwitchObservation
    }
    private struct SettingsSwitchObservation {
        let label: String
        let ownerIdentifier: String
        let controlIdentifier: String
        let controlLabel: String
        let windowIdentifier: String
        let navigationIdentifier: String
        let navigationLabel: String
        let ownerFrame: CGRect
        let controlFrame: CGRect
        let windowFrame: CGRect
        let value: Int
        let uptime: TimeInterval
        var identity: [String] {
            [label, ownerIdentifier, controlIdentifier, controlLabel,
             windowIdentifier, navigationIdentifier, navigationLabel]
        }
        var json: [String: Any] {
            ["label": label, "ownerIdentifier": ownerIdentifier,
             "controlIdentifier": controlIdentifier, "controlLabel": controlLabel,
             "windowIdentifier": windowIdentifier, "navigationIdentifier": navigationIdentifier,
             "navigationLabel": navigationLabel, "value": value, "observedUptime": uptime,
             "ownerFrame": ["x": ownerFrame.minX, "y": ownerFrame.minY, "width": ownerFrame.width, "height": ownerFrame.height],
             "controlFrame": ["x": controlFrame.minX, "y": controlFrame.minY, "width": controlFrame.width, "height": controlFrame.height],
             "windowFrame": ["x": windowFrame.minX, "y": windowFrame.minY, "width": windowFrame.width, "height": windowFrame.height]]
        }
    }
    @MainActor
    private func requireSettingsForeground(_ settings: XCUIApplication) throws {
        let foreground = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in settings.state == .runningForeground }, object: nil)
        guard XCTWaiter.wait(for: [foreground], timeout: 5) == .completed, settings.alerts.count == 0 else {
            captureSettings(settings, name: "settings-not-unobstructed-foreground")
            XCTFail("Require the actual Settings app foreground without an unknown alert; preserve the current OS state")
            throw Prerequisite.invalid("actual Settings foreground unavailable")
        }
    }
    @MainActor
    private func uniqueSettingsSwitch(_ labels: [String], settings: XCUIApplication) -> SettingsSwitchTarget? {
        guard settings.state == .runningForeground,
              labels == airplaneLabels || labels == wifiLabels,
              let tree = try? settings.snapshot() else { return nil }
        func valid(_ frame: CGRect) -> Bool {
            !frame.isNull && !frame.isInfinite && frame.width > 0 && frame.height > 0
                && [frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy(\.isFinite)
        }
        typealias Node = (element: any XCUIElementSnapshot, ancestors: [any XCUIElementSnapshot], path: String, windows: [String])
        var nodes = [Node]()
        func collect(_ element: any XCUIElementSnapshot, ancestors: [any XCUIElementSnapshot], path: String, windows: [String]) {
            let currentWindows = element.elementType == .window ? windows + [path] : windows
            nodes.append((element, ancestors, path, currentWindows))
            for (index, child) in element.children.enumerated() {
                collect(child, ancestors: ancestors + [element], path: path + "/" + String(index), windows: currentWindows)
            }
        }
        collect(tree, ancestors: [], path: "root", windows: [])
        let ownerID = labels == airplaneLabels ? "com.apple.settings.airplaneMode" : nil
        let pageLabels = labels == airplaneLabels ? ["设置", "Settings"] : wifiLabels
        let windows = nodes.filter { $0.element.elementType == .window && valid($0.element.frame) }
        let owners = nodes.filter {
            $0.element.elementType == .switch && labels.contains($0.element.label)
                && (ownerID == nil || $0.element.identifier == ownerID)
        }
        guard valid(tree.frame), windows.count == 1, owners.count == 1,
              let windowNode = windows.first, let row = owners.first,
              row.windows == [windowNode.path] else { return nil }
        let window = windowNode.element
        guard
              tree.frame.contains(window.frame), valid(row.element.frame),
              window.frame.contains(row.element.frame), row.element.isEnabled,
              let cell = row.ancestors.last(where: { $0.elementType == .cell }),
              valid(cell.frame), cell.frame.contains(row.element.frame) else { return nil }
        let bars = nodes.filter {
            $0.element.elementType == .navigationBar
                && $0.windows == [windowNode.path]
                && (pageLabels.contains($0.element.identifier) || pageLabels.contains($0.element.label))
        }
        var controls = [any XCUIElementSnapshot]()
        func collectControls(_ element: any XCUIElementSnapshot) {
            for child in element.children {
                if child.elementType == .switch { controls.append(child) }
                collectControls(child)
            }
        }
        collectControls(row.element)
        guard bars.count == 1, let bar = bars.first?.element,
              valid(bar.frame), window.frame.contains(bar.frame), controls.count == 1,
              let control = controls.first, control.isEnabled, valid(control.frame),
              row.element.frame.contains(control.frame), cell.frame.contains(control.frame),
              window.frame.contains(control.frame),
              let value = settingsSwitchValue(row.element.value),
              settingsSwitchValue(control.value) == value else { return nil }
        // The real iOS Settings AX exposes a labelled, whole-row switch and
        // one nested toggle. Resolve the native control through that owner;
        // geometry validates containment, never chooses a hard-coded size.
        let predicate = ownerID.map {
            NSPredicate(format: "identifier == %@ AND label IN %@", $0, labels as NSArray)
        } ?? NSPredicate(format: "label IN %@", labels as NSArray)
        let owner = settings.windows.containing(predicate).element.switches.matching(predicate).element
        let observation = SettingsSwitchObservation(label: row.element.label,
            ownerIdentifier: row.element.identifier, controlIdentifier: control.identifier,
            controlLabel: control.label, windowIdentifier: window.identifier,
            navigationIdentifier: bar.identifier, navigationLabel: bar.label,
            ownerFrame: row.element.frame, controlFrame: control.frame, windowFrame: window.frame,
            value: value, uptime: ProcessInfo.processInfo.systemUptime)
        return SettingsSwitchTarget(owner: owner, control: owner.descendants(matching: .switch).element,
                                    observation: observation)
    }
    private func settingsSwitchValue(_ value: Any?) -> Int? {
        if let text = value as? String, text == "0" || text == "1" { return Int(text) }
        if let number = value as? NSNumber, number == 0 || number == 1 { return number.intValue }
        return nil
    }
    @MainActor
    private func observeSettingsSwitch(_ labels: [String], settings: XCUIApplication, name: String) throws -> SettingsSwitchObservation {
        try requireSettingsForeground(settings)
        guard let actual = uniqueSettingsSwitch(labels, settings: settings) else {
            captureSettings(settings, name: name + "-unresolved-switch")
            XCTFail("Require one actual visible Settings switch with its observed 0/1 value: " + labels.joined(separator: "/"))
            throw Prerequisite.invalid("ambiguous or unreadable OS network switch")
        }
        let result = actual.observation
        captureSettings(settings, name: name)
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: result.json, options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = name + "-actual-switch-value"; attachment.lifetime = .keepAlways; add(attachment)
        return result
    }
    @MainActor
    private func requireSettingsRoot(_ settings: XCUIApplication) throws {
        var backs = 0, rootScrolls = 0
        for _ in 0..<7 {
            try requireSettingsForeground(settings)
            if uniqueSettingsSwitch(airplaneLabels, settings: settings) != nil { return }
            let back = settings.navigationBars.buttons.matching(NSPredicate(format:
                "label IN %@ OR identifier == %@", ["设置", "Settings", "返回", "Back"] as NSArray, "BackButton"))
                .allElementsBoundByIndex.filter { $0.isHittable }
            if backs < 3, back.count == 1 { back[0].tap(); backs += 1; continue }
            let rootTitles = settings.navigationBars.matching(NSPredicate(format: "label IN %@", ["设置", "Settings"] as NSArray))
            let tables = settings.tables.allElementsBoundByIndex.filter(\.isHittable)
            if rootScrolls < 2, rootTitles.count == 1, tables.count == 1 {
                tables[0].swipeDown(); rootScrolls += 1; continue
            }
            if !settingsFallbackNavigationUsed {
                settingsFallbackNavigationUsed = true
                // Test navigation only. The URL has no success assertion;
                // the actual Settings app and exact switch must still match.
                let route = try XCTUnwrap(URL(string: "App-prefs:"))
                XCUIDevice.shared.system.open(route)
                continue
            }
            break
        }
        captureSettings(settings, name: "settings-root-bounded-navigation-failure")
        XCTFail("Cannot safely locate the actual Settings root with a unique Airplane Mode switch; no blind coordinates or retries")
        throw Prerequisite.invalid("Settings root not safely identifiable")
    }
    @MainActor
    private func openSettingsWiFi(_ settings: XCUIApplication) throws {
        try requireSettingsRoot(settings)
        let routes = settings.staticTexts.matching(NSPredicate(format: "label IN %@", wifiLabels as NSArray))
            .allElementsBoundByIndex.filter { $0.isHittable }
        guard routes.count == 1 else {
            captureSettings(settings, name: "settings-wifi-route-not-unique")
            XCTFail("Require the unique actual Wi-Fi/无线局域网 row in Settings")
            throw Prerequisite.invalid("actual Wi-Fi route unavailable")
        }
        routes[0].tap()
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.uniqueSettingsSwitch(self.wifiLabels, settings: settings) != nil
        }, object: nil)
        guard XCTWaiter.wait(for: [visible], timeout: 5) == .completed else {
            captureSettings(settings, name: "settings-wifi-switch-unavailable")
            XCTFail("The actual Wi-Fi settings page must expose one readable switch")
            throw Prerequisite.invalid("actual Wi-Fi switch unavailable")
        }
    }
    @MainActor
    private func setSettingsSwitch(_ labels: [String], to wanted: Int, settings: XCUIApplication) throws {
        try requireSettingsForeground(settings)
        guard let actual = uniqueSettingsSwitch(labels, settings: settings) else {
            captureSettings(settings, name: "settings-switch-not-safe-to-change")
            XCTFail("Do not change a switch whose current identity and value are unknown")
            throw Prerequisite.invalid("OS network switch change not safe")
        }
        if actual.observation.value != wanted {
            guard let current = uniqueSettingsSwitch(labels, settings: settings),
                  current.observation.identity == actual.observation.identity,
                  current.observation.value == actual.observation.value else {
                captureSettings(settings, name: "settings-switch-owner-changed-before-tap")
                XCTFail("The exact Settings row/control and value must still match immediately before its one native tap")
                throw Prerequisite.invalid("OS network switch owner changed")
            }
            current.control.tap()
        }
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let observed = self.uniqueSettingsSwitch(labels, settings: settings),
                  observed.observation.identity == actual.observation.identity else { return false }
            return observed.observation.value == wanted
        }, object: nil)
        guard XCTWaiter.wait(for: [changed], timeout: 5) == .completed else {
            captureSettings(settings, name: "settings-switch-change-not-observed")
            XCTFail("The actual Settings value did not reach the requested state; preserve the current OS state")
            throw Prerequisite.invalid("OS network switch outcome unconfirmed")
        }
    }
    @MainActor
    private func disableNetworkUsingActualSettings(_ settings: XCUIApplication) throws -> [String: Any] {
        try requireSettingsRoot(settings)
        let originalAirplane = try observeSettingsSwitch(airplaneLabels, settings: settings, name: "settings-original-airplane")
        try openSettingsWiFi(settings)
        let originalWiFi = try observeSettingsSwitch(wifiLabels, settings: settings, name: "settings-original-wifi")
        try requireSettingsRoot(settings)
        try setSettingsSwitch(airplaneLabels, to: 1, settings: settings)
        let enabledAirplane = try observeSettingsSwitch(airplaneLabels, settings: settings, name: "settings-airplane-enabled")
        try openSettingsWiFi(settings)
        try setSettingsSwitch(wifiLabels, to: 0, settings: settings)
        let disabledWiFi = try observeSettingsSwitch(wifiLabels, settings: settings, name: "settings-wifi-disabled")
        try requireSettingsRoot(settings)
        let finalAirplane = try observeSettingsSwitch(airplaneLabels, settings: settings, name: "settings-final-airplane-after-wifi")
        guard enabledAirplane.value == 1, finalAirplane.value == 1, disabledWiFi.value == 0 else {
            XCTFail("Actual Airplane=1 and Wi-Fi=0 observations are required before checking the system network path")
            throw Prerequisite.invalid("OS network switches not confirmed")
        }
        return ["settingsBundleIdentifier": "com.apple.Preferences",
            "originalAirplane": originalAirplane.json, "originalWiFi": originalWiFi.json,
            "airplaneAfterEnable": enabledAirplane.json, "wifiAfterDisable": disabledWiFi.json,
            "airplaneAfterWiFiObservation": finalAirplane.json,
            "privateSettingsFallbackNavigationUsed": settingsFallbackNavigationUsed,
            "observationBoundary": "Exact Settings switch observations at recorded times; these switches alone do not prove system offline"]
    }
    @MainActor
    private func captureSettings(_ settings: XCUIApplication, name: String) {
        keep(settings, name: name)
        let ax = XCTAttachment(string: settings.debugDescription)
        ax.name = name + "-actual-AX"; ax.lifetime = .keepAlways; add(ax)
    }
    private final class OfflinePathCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var observed: [[String: Any]] = []
        private var limited = false
        func receive(_ path: NWPath) -> Bool {
            func interface(_ type: NWInterface.InterfaceType) -> String {
                switch type {
                case .wifi: return "wifi"
                case .cellular: return "cellular"
                case .wiredEthernet: return "wiredEthernet"
                case .loopback: return "loopback"
                case .other: return "other"
                @unknown default: return "unknown"
                }
            }
            let status: String
            switch path.status {
            case .satisfied: status = "satisfied"
            case .unsatisfied: status = "unsatisfied"
            case .requiresConnection: status = "requiresConnection"
            @unknown default: status = "unknown"
            }
            let sample: [String: Any] = ["status": status, "observedUptime": ProcessInfo.processInfo.systemUptime,
                "availableInterfaceTypes": Array(Set(path.availableInterfaces.map { interface($0.type) })).sorted(),
                "usedInterfaceTypes": [NWInterface.InterfaceType.wifi, .cellular, .wiredEthernet, .loopback, .other]
                    .filter { path.usesInterfaceType($0) }.map(interface)]
            lock.lock()
            if observed.count < 16 { observed.append(sample) } else { limited = true }
            lock.unlock()
            return path.status == .unsatisfied
        }
        var samples: [[String: Any]] { lock.lock(); defer { lock.unlock() }; return observed }
        var limitReached: Bool { lock.lock(); defer { lock.unlock() }; return limited }
    }
    @MainActor
    private func observeUnsatisfiedSystemPath(settings: XCUIApplication) throws -> [String: Any] {
        let capture = OfflinePathCapture(), received = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "io.reader.minliny.uitest.offline-path", qos: .utility)
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in if capture.receive(path) { received.signal() } }
        monitor.start(queue: queue)
        let outcome = received.wait(timeout: .now() + 5)
        monitor.cancel()
        queue.sync {}
        let samples = capture.samples
        let result: [String: Any] = ["samples": samples, "waitLimitSeconds": 5,
            "unsatisfiedObservedWithinLimit": outcome == .success,
            "sampleLimitReached": capture.limitReached,
            "boundary": "Network.framework system default path observation only; no URL, IP, SSID, credentials or reachability probe"]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "actual-system-network-path-before-offline-reader"; attachment.lifetime = .keepAlways; add(attachment)
        captureSettings(settings, name: "settings-at-system-path-observation")
        guard outcome == .success, !capture.limitReached, samples.last?["status"] as? String == "unsatisfied" else {
            XCTFail("The actual system default path must be unsatisfied before claiming OS-offline cached reading; keep the current OS switches unchanged")
            throw Prerequisite.invalid("system path not observed unsatisfied")
        }
        return result
    }

    /// Select this method only after an actual alternate candidate has been
    /// observed. Missing candidates or an unexpected outcome FAIL; a bad source
    /// is never manufactured to make the rollback branch run.
    func testActualSelectableSourceSwitchConfirmsTheSelectedOutcomeAndRetainsOriginalIdentityOnFailure() throws {
        let original = try originalBook()
        let target = Book(source: try required("READER_ONLINE_SWITCH_TARGET_SOURCE_ID"),
                          id: try required("READER_ONLINE_SWITCH_TARGET_BOOK_ID"),
                          title: original.title)
        let expected = try required("READER_ONLINE_SWITCH_EXPECTATION")
        guard target.identity != original.identity, ["success", "failure"].contains(expected) else {
            XCTFail("Choose a real alternate candidate and explicitly select its observed success or failure branch")
            throw Prerequisite.invalid("source-switch prerequisites")
        }
        let app = XCUIApplication(); app.launch(); open(original, app: app)
        let originalChapter = try currentChapter(original, app: app)
        hideControls(app)
        let originalProgress = app.staticTexts["reading-progress"].label
        let originalAnchor = try anchor(app, name: "real-online-original-before-switch")
        controls(app)
        app.buttons["reader-more"].tap(); app.buttons["切换书源"].tap()
        let owner = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-switch-owner:")).firstMatch
        XCTAssertTrue(owner.waitForExistence(timeout: 15))
        let candidate = app.buttons.matching(NSPredicate(format: "identifier == %@", "online-switch-candidate:" + target.identity)).firstMatch
        XCTAssertTrue(candidate.waitForExistence(timeout: 180),
                      "A real selectable candidate is required; no-candidate is an OPEN prerequisite, not a simulated rollback.\n" + app.debugDescription)
        let evidence = XCTAttachment(string: "original=" + original.identity + "\ntarget=" + target.identity + "\nexpected=" + expected)
        evidence.name = "actual-source-switch-identity"; evidence.lifetime = .keepAlways; add(evidence)
        candidate.tap()
        if expected == "success" {
            wait("The original switch must finish and close its sheet", timeout: 300) { !owner.exists }
            XCTAssertTrue(app.textViews["reading-body"].waitForExistence(timeout: 20))
            _ = try currentChapter(target, app: app)
            hideControls(app)
            _ = try anchor(app, name: "real-online-target-body-after-direct-source-selection")
            leave(app)
            // A source switch changes the active source of the admitted shelf
            // book; it does not create a second shelf row for the alternate
            // source. Reopen the persisted continue card, then assert that the
            // selected target identity survived the cold launch.
            app.terminate(); app.launch(); openContinue(app: app)
            _ = try currentChapter(target, app: app)
            hideControls(app)
            _ = try anchor(app, name: "real-online-selected-source-after-cold-reopen")
            leave(app)
        } else {
            let outcome = element("online-switch-outcome", app: app)
            wait("The exact source-switch owner must report a definite failure, not pending", timeout: 300) {
                owner.exists && owner.identifier.hasSuffix(":settled") && outcome.exists && !outcome.label.isEmpty && candidate.isEnabled
            }
            keep(app, name: "actual-source-switch-definite-failure")
            app.buttons["online-switch-close"].tap()
            XCTAssertEqual(try currentChapter(original, app: app), originalChapter)
            hideControls(app)
            try visible(originalAnchor, app: app, name: "real-online-old-source-body-preserved-after-actual-switch-failure")
            XCTAssertEqual(app.staticTexts["reading-progress"].label, originalProgress)
            leave(app)
            app.terminate(); app.launch(); open(original, app: app)
            XCTAssertEqual(try currentChapter(original, app: app), originalChapter)
            hideControls(app)
            try visible(originalAnchor, app: app, name: "real-online-original-source-after-failed-switch-and-cold-reopen")
            leave(app)
        }
    }

    /// Real discovery reads only. The same observed candidate identities,
    /// labels/timings and intra-row geometry must survive ordinary sheet closes.
    /// The Runner selects an already admitted real book; no candidate is tapped.
    func testExistingOnlineSourceSwitchSheetReopenPreservesActualScrolledCandidatesWithoutSwitching() throws {
        let book = try originalBook()
        let app = XCUIApplication(); app.launch(); open(book, app: app)
        let originalChapter = try currentChapter(book, app: app)
        hideControls(app)
        let originalProgress = app.staticTexts["reading-progress"].label
        let originalAnchor = try anchor(app, name: "real-switch-viewport-original-body")
        openReadOnlySwitchSheet(app)
        let initial = try stableSwitchSnapshot(app, timeout: 180, name: "initial-real-settled-candidates")
        try keepSwitchGeometry(initial, app: app, name: "initial-real-settled-candidates")

        var scrolled: SwitchSnapshot?
        for attempt in 0..<6 {
            let current = try stableSwitchSnapshot(app, timeout: settledGeometryTimeout, name: "before-owned-drag-\(attempt)")
            let distance = min(CGFloat(120), max(CGFloat(50), current.rows[0].frame.height * 0.45))
            let from = switchCoordinate(CGPoint(x: current.frame.midX, y: current.frame.minY + current.frame.height * 0.72), app: app)
            let to = switchCoordinate(CGPoint(x: current.frame.midX, y: current.frame.minY + current.frame.height * 0.72 - distance), app: app)
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
            let now = try stableSwitchSnapshot(app, timeout: settledGeometryTimeout, name: "after-owned-drag-\(attempt)")
            try keepSwitchGeometry(now, app: app, name: "after-owned-drag-\(attempt)")
            let hasMoved = initial.rows.contains { old in
                guard let current = now.rows.first(where: { $0.id == old.id }) else { return true }
                return abs(current.frame.minY - old.frame.minY) >= min(CGFloat(40), old.frame.height / 3)
            }
            let hasIntraRowOffset = now.rows.contains { row in
                row.frame.minY <= now.frame.minY - 12 && row.frame.maxY >= now.frame.minY + 28
            }
            if hasMoved && hasIntraRowOffset { scrolled = now; break }
        }
        guard let baseline = scrolled else {
            XCTFail("Actual candidates must provide genuine scrolling with a clipped row's interior at the viewport edge; do not manufacture candidates or replace this prerequisite with a top-aligned row")
            throw Prerequisite.invalid("actual intra-row scroll unavailable")
        }
        try keepSwitchGeometry(baseline, app: app, name: "exact-intra-row-baseline")
        closeReadOnlySwitchSheet(app)
        XCTAssertEqual(try currentChapter(book, app: app), originalChapter)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "real-body-preserved-after-first-sheet-close")
        XCTAssertEqual(app.staticTexts["reading-progress"].label, originalProgress)

        openReadOnlySwitchSheet(app)
        try assertSwitchRestored(baseline, query: baseline.query, app: app, name: "same-query-first-reopen")
        closeReadOnlySwitchSheet(app)
        XCTAssertEqual(try currentChapter(book, app: app), originalChapter)
        hideControls(app)
        try visible(originalAnchor, app: app, name: "real-switch-viewport-final-original-body")
        XCTAssertEqual(app.staticTexts["reading-progress"].label, originalProgress)
        leave(app)
    }

    private struct SwitchRow {
        let id: String
        let label: String
        let timing: String
        let frame: CGRect
    }
    private struct SwitchSnapshot {
        let query: String
        let frame: CGRect
        let rows: [SwitchRow]
        let observedUptime: TimeInterval
    }
    private func openReadOnlySwitchSheet(_ app: XCUIApplication) {
        controls(app); app.buttons["reader-more"].tap()
        let route = app.buttons["切换书源"]
        XCTAssertTrue(route.waitForExistence(timeout: 5)); XCTAssertTrue(route.isHittable); route.tap()
        XCTAssertTrue(app.buttons["online-switch-close"].waitForExistence(timeout: 15))
    }
    private func closeReadOnlySwitchSheet(_ app: XCUIApplication) {
        let close = app.buttons["online-switch-close"]
        XCTAssertTrue(close.isHittable); close.tap()
        wait("The real switch sheet and its keyboard must finish dismissing", timeout: 10) {
            !close.exists && !app.keyboards.firstMatch.exists
        }
    }
    private func switchQueryValue(_ app: XCUIApplication) -> String? {
        let fields = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "书名或作者"))
            .allElementsBoundByIndex.filter(\.isHittable)
        guard fields.count == 1, let value = fields[0].value as? String else { return nil }
        return value == "书名或作者" ? "" : value
    }
    private func observedSwitchSnapshot(_ app: XCUIApplication) -> SwitchSnapshot? {
        guard !app.keyboards.firstMatch.exists, app.buttons["online-switch-close"].isHittable,
              let query = switchQueryValue(app) else { return nil }
        let owner = app.staticTexts.matching(NSPredicate(format: "identifier == %@", "online-switch-owner:settled"))
        let settled = app.buttons.matching(NSPredicate(format: "label == %@", "重新搜索"))
        guard owner.count == 1, owner.element.exists, settled.count == 1, settled.element.isHittable,
              !app.buttons.matching(NSPredicate(format: "label == %@", "停止")).firstMatch.exists,
              !app.staticTexts["正在查找其他来源"].exists else { return nil }
        let prefix = "online-switch-candidate:"
        let frames = app.scrollViews.allElementsBoundByIndex.compactMap { scroll -> CGRect? in
            let frame = scroll.frame.intersection(app.frame)
            guard !frame.isNull, frame.width > 100, frame.height > 100,
                  scroll.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
                    .allElementsBoundByIndex.contains(where: { $0.isHittable && frame.intersects($0.frame) }) else { return nil }
            return frame
        }
        guard let viewport = frames.min(by: { $0.height < $1.height }) else { return nil }
        let visible = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .allElementsBoundByIndex.filter { row in
                let frame = row.frame, intersection = frame.intersection(viewport)
                return row.isHittable && !intersection.isNull && intersection.height >= 12 && frame.width > 0 && frame.height > 0
            }
        // Do not silently drop a visible stale/untimed/disabled candidate from
        // the exact geometry group merely because other rows would qualify.
        var rows: [SwitchRow] = []
        for row in visible {
            guard row.isEnabled, let timingRange = row.label.range(of: #"[0-9]+ ms"#, options: .regularExpression),
                  !row.label.contains("上次候选") else { return nil }
            let identity = String(row.identifier.dropFirst(prefix.count))
            guard let split = identity.firstIndex(of: "|"), split != identity.startIndex,
                  identity.index(after: split) != identity.endIndex else { return nil }
            rows.append(SwitchRow(id: row.identifier, label: row.label,
                timing: String(row.label[timingRange]), frame: row.frame))
        }
        rows.sort { $0.frame.minY == $1.frame.minY ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY }
        guard rows.count >= 2, Set(rows.map(\.id)).count == rows.count else { return nil }
        return SwitchSnapshot(query: query, frame: viewport, rows: rows, observedUptime: ProcessInfo.processInfo.systemUptime)
    }

    private func sameSwitchGeometry(_ a: SwitchSnapshot, _ b: SwitchSnapshot, tolerance: CGFloat, compareQuery: Bool) -> Bool {
        func equal(_ x: CGRect, _ y: CGRect) -> Bool {
            [abs(x.minX-y.minX), abs(x.minY-y.minY), abs(x.width-y.width), abs(x.height-y.height)].allSatisfy { $0 <= tolerance }
        }
        guard (!compareQuery || a.query == b.query), equal(a.frame, b.frame),
              a.rows.map(\.id) == b.rows.map(\.id) else { return false }
        return zip(a.rows,b.rows).allSatisfy { x,y in
            x.label == y.label && x.timing == y.timing &&
            equal(x.frame.offsetBy(dx: -a.frame.minX, dy: -a.frame.minY), y.frame.offsetBy(dx: -b.frame.minX, dy: -b.frame.minY))
        }
    }
    private func stableSwitchSnapshot(_ app: XCUIApplication, timeout: TimeInterval, name: String) throws -> SwitchSnapshot {
        var reference: SwitchSnapshot?, since: TimeInterval?, captured: SwitchSnapshot?
        let condition = XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
            guard let now = self.observedSwitchSnapshot(app) else { reference=nil; since=nil; return false }
            let time = ProcessInfo.processInfo.systemUptime
            if let old = reference, self.sameSwitchGeometry(old, now, tolerance: 0.25, compareQuery: true) {
                if let began = since, time-began >= 0.5 { captured=now; return true }
            } else { reference=now; since=time }
            return false
        }, object: nil)
        let outcome = XCTWaiter.wait(for: [condition], timeout: timeout)
        if outcome == .completed, let result = captured {
            try keepSwitchGeometry(result, app: app, name: name+"-actual")
            return result
        }
        if let actual = observedSwitchSnapshot(app) { try keepSwitchGeometry(actual, app: app, name: name+"-actual") }
        keep(app, name: name+"-prerequisite-failure")
        let evidence = XCTAttachment(string: app.debugDescription); evidence.name=name+"-actual-AX"; evidence.lifetime = .keepAlways; add(evidence)
        XCTFail("Require settled real search, >=2 actual candidates with real timings, no keyboard and stable public geometry: "+name)
        throw Prerequisite.invalid("real switch viewport prerequisite")
    }
    private func assertSwitchRestored(_ original: SwitchSnapshot, query: String, app: XCUIApplication, name: String) throws {
        let actual = try stableSwitchSnapshot(app, timeout: settledGeometryTimeout, name: name)
        try keepSwitchGeometry(original, app: app, name: name+"-original-reference", includeScreenshot: false)
        try keepSwitchGeometry(actual, app: app, name: name+"-reopened-actual")
        XCTAssertEqual(actual.query, query, "Preserve the exact visible query intent without starting a new search")
        guard actual.query == query, sameSwitchGeometry(original, actual, tolerance: 2, compareQuery: false) else {
            XCTFail("The same complete candidate IDs/order/labels/timings and each viewport-relative x/y/width/height must survive the real sheet reopen within the original2pt; do not snap to a row or scroll to repair the observation")
            throw Prerequisite.invalid("actual sheet viewport changed")
        }
    }
    private func keepSwitchGeometry(_ snapshot: SwitchSnapshot, app: XCUIApplication, name: String, includeScreenshot: Bool = true) throws {
        func rect(_ value: CGRect) -> [String: Double] {
            ["x":Double(value.minX),"y":Double(value.minY),"width":Double(value.width),"height":Double(value.height)]
        }
        let value: [String: Any] = ["query":snapshot.query,"viewport":rect(snapshot.frame),
            "rows":snapshot.rows.map { row -> [String: Any] in
                ["identifier":row.id,"label":row.label,"timing":row.timing,"frame":rect(row.frame),
                 "viewportRelative":rect(row.frame.offsetBy(dx:-snapshot.frame.minX,dy:-snapshot.frame.minY))]
            },"keyboardVisibleAtAttachment":app.keyboards.firstMatch.exists,"observedUptime":snapshot.observedUptime,
            "attachmentAtUptime":ProcessInfo.processInfo.systemUptime]
        let attachment = XCTAttachment(data:try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]),uniformTypeIdentifier:"public.json")
        attachment.name=name+"-actual-source-book-geometry"; attachment.lifetime = .keepAlways; add(attachment)
        if includeScreenshot { keep(app,name:name) }
    }
    private func switchCoordinate(_ point: CGPoint, app: XCUIApplication) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx:point.x-app.frame.minX,dy:point.y-app.frame.minY))
    }

    private func required(_ key: String) throws -> String {
        guard let value = ProcessInfo.processInfo.environment[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            XCTFail("Required actual-journey provenance is absent from the UITest process: " + key)
            throw Prerequisite.missing(key)
        }
        return value
    }
    private func originalBook() throws -> Book {
        Book(source: try required("READER_ONLINE_SOURCE_ID"), id: try required("READER_ONLINE_BOOK_ID"),
             title: try required("READER_ONLINE_BOOK_TITLE"))
    }
    private func element(_ id: String, app: XCUIApplication) -> XCUIElement {
        // Real source/book URLs can exceed XCTest's string-query limit.
        // A predicate retains exact original identity without truncation.
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }
    private func open(_ book: Book, app: XCUIApplication) {
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 25))
        if app.textFields["shelf-filter"].exists { app.buttons["搜索本地书架"].tap() }
        // SwiftUI can expose the exact shelf button under a nested accessibility
        // container after a cold launch. Direct identifier lookup traverses that
        // container reliably and keeps the original source identity exact.
        let row = app.buttons[book.shelfID]
        XCTAssertTrue(row.waitForExistence(timeout: 20), "Reuse the original real admitted shelf book.\n" + app.debugDescription)
        XCTAssertTrue(row.isHittable); row.tap()
        XCTAssertTrue(app.textViews["reading-body"].waitForExistence(timeout: 180))
        controls(app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier == %@", "reading-book:" + book.identity)).firstMatch.exists, "The opened reader must retain the exact real source and book identity")
    }
    private func openContinue(app: XCUIApplication) {
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 25))
        let card = app.buttons["shelf-continue-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "The admitted shelf book must retain its continue card after a cold launch")
        XCTAssertTrue(card.isHittable); card.tap()
        XCTAssertTrue(app.textViews["reading-body"].waitForExistence(timeout: 180))
        controls(app)
    }
    private func controls(_ app: XCUIApplication) {
        if !app.buttons["reader-more"].isHittable {
            app.textViews["reading-body"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        }
        wait("Normal native reading controls must appear", timeout: 10) { app.buttons["reader-more"].isHittable }
    }
    private func hideControls(_ app: XCUIApplication) {
        let hide = app.buttons["收起阅读控制"]
        if hide.isHittable { hide.tap() }
        wait("Normal reading controls must hide", timeout: 10) { !hide.isHittable }
    }
    private func currentChapter(_ book: Book, app: XCUIApplication) throws -> UInt32 {
        controls(app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier == %@", "reading-book:" + book.identity)).firstMatch.exists)
        let prefix = "reading-chapter:"
        let chapter = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(chapter.waitForExistence(timeout: 10))
        return try XCTUnwrap(UInt32(chapter.identifier.dropFirst(prefix.count)), "Read the real canonical chapter identity without changing its spoken label")
    }
    private func downloads(_ app: XCUIApplication) {
        controls(app); app.buttons["reader-more"].tap()
        XCTAssertTrue(app.buttons["下载管理"].waitForExistence(timeout: 5)); app.buttons["下载管理"].tap()
        XCTAssertTrue(app.buttons["online-update-catalog"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["online-download-selected"].waitForExistence(timeout: 30))
    }
    private func choose(_ index: UInt32, app: XCUIApplication) throws {
        controls(app)
        let prefix = "reading-chapter:"
        let readings = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).allElementsBoundByAccessibilityElement
        guard readings.count == 1, let current = UInt32(readings[0].identifier.dropFirst(prefix.count)) else {
            XCTFail("Require the unique actual current chapter before choosing a directory target")
            throw Prerequisite.invalid("current directory chapter identity unavailable")
        }
        app.buttons["control-module-directory"].tap()
        let grabber = app.buttons["control-grabber"]
        if !grabber.label.hasPrefix("完整控制栏") { grabber.tap() }
        wait("The existing full directory controls must open", timeout: 10) { grabber.label.hasPrefix("完整控制栏") }
        let directory = app.buttons.matching(NSPredicate(format: "label == '目录' AND identifier != 'control-module-directory'")).firstMatch
        XCTAssertTrue(directory.waitForExistence(timeout: 5)); directory.tap()
        let order = app.buttons.matching(NSPredicate(format: "label IN %@", ["正序", "倒序"] as NSArray)).allElementsBoundByAccessibilityElement
        let currentRowID = "chapter-\(current)"
        let owners = app.scrollViews.containing(.button, identifier: currentRowID).allElementsBoundByAccessibilityElement
        guard order.count == 1, owners.count == 1,
              owners[0].buttons[currentRowID].isSelected else {
            XCTFail("Require the actual directory order and its unique scroll owner containing the selected current chapter")
            throw Prerequisite.invalid("directory order or selected-row owner unavailable")
        }
        // The action offers the other order: 正序 means the current list is descending.
        let descending = order[0].label == "正序"
        let scroll = owners[0], row = scroll.buttons["chapter-\(index)"]
        try reveal(row, in: scroll, app: app, towardTop: descending ? index > current : index < current)
        row.tap()
        wait("The actual Core directory target must become selected", timeout: 30) { row.isSelected }
        guard row.isSelected else { throw Prerequisite.invalid("directory target did not become selected") }
    }
    private func reveal(_ target: XCUIElement, in scroll: XCUIElement, app: XCUIApplication, towardTop: Bool = false) throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 30
        var swipes = 0
        while ProcessInfo.processInfo.systemUptime < deadline {
            guard scroll.exists else { break }
            if target.exists {
                let frame = target.frame, viewport = scroll.frame.intersection(app.frame)
                if !frame.isNull, !frame.isInfinite, frame.width > 0, frame.height > 0,
                   [frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy(\.isFinite),
                   viewport.contains(frame), target.isHittable { return }
            }
            guard swipes < 32, ProcessInfo.processInfo.systemUptime < deadline else { break }
            if towardTop { scroll.swipeDown() } else { scroll.swipeUp() }
            swipes += 1
        }
        XCTFail("The exact target was not fully visible in its owned scroll surface within 30 seconds / 32 swipes; stop without tapping or searching again")
        throw Prerequisite.invalid("owned scroll target unavailable within bounds")
    }
    private func leave(_ app: XCUIApplication) {
        controls(app); app.buttons["leave-reader"].tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 30))
    }
    private func wait(_ fact: String, timeout: TimeInterval, _ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, fact)
    }
    private func anchor(_ app: XCUIApplication, name: String) throws -> String {
        var lines: [String] = []
        wait("The actual reading viewport must contain visible body text", timeout: 30) {
            guard let actual = try? self.ocr(app), actual.count >= 4 else { return false }
            lines = actual; return true
        }
        let value = String(normalize(lines.dropFirst().prefix(2).joined()).prefix(24))
        XCTAssertGreaterThanOrEqual(value.count, 18)
        keep(app, name: name)
        let evidence = XCTAttachment(string: value)
        evidence.name = name + "-visible-OCR"; evidence.lifetime = .keepAlways; add(evidence)
        return value
    }
    private func visible(_ anchor: String, app: XCUIApplication, name: String) throws {
        wait("The original visible real-body anchor must remain: " + name, timeout: 30) {
            guard let text = try? self.ocr(app) else { return false }
            return self.normalize(text.joined()).contains(anchor)
        }
        keep(app, name: name)
    }
    private func normalize(_ value: String) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }
    private func ocr(_ app: XCUIApplication) throws -> [String] {
        let source = try XCTUnwrap(app.screenshot().image.cgImage)
        let window = app.frame
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
    private func keep(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
