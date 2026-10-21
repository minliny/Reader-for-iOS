import XCTest
import UIKit

/// Actual remote input and normal native controls only. Runner environment
/// selects the already approved real URL; nothing is injected into the App.
final class ReaderRuleSubscriptionJourneyTests: XCTestCase {
    private enum Prerequisite: Error { case absent(String), invalid(String) }
    private let realURL = "https://shuyuan-api.yiove.com/import/book-source-collection/3d9f811b-0831-4203-9fcb-3e8020f8aa2d"
    private let initialRealSourceIDs: Set<String> = ["https://dushu.baidu.com/", "https://m.idejian.com"]

    override func setUpWithError() throws { continueAfterFailure = false }

    func testRealSubscriptionSafeSingleSourceApplyLocalEnableEditAndColdRetention() throws {
        guard let input = ProcessInfo.processInfo.environment["READER_REAL_SUBSCRIPTION_URL"], !input.isEmpty else {
            XCTFail("The UITest runner must select the approved actual Yiove URL; no replacement JSON or source is accepted")
            throw Prerequisite.absent("READER_REAL_SUBSCRIPTION_URL")
        }
        guard input == realURL else {
            XCTFail("Keep the same actual 424-source URL as the passed real subscription service journey")
            throw Prerequisite.invalid("READER_REAL_SUBSCRIPTION_URL")
        }
        let retained = try retainedOwnedSubscription()
        let app = XCUIApplication(); app.launch()
        openSources(app)
        let before = try sourceValues(app)
        XCTAssertTrue(initialRealSourceIDs.isSubset(of: Set(before.keys)),
                      "Reuse the actual two-source library; do not provision or replace sources in this journey")
        openSubscriptions(app)
        let addSubscription = app.buttons["subscription-add"]
        wait("Read the existing subscription list before creating a new owned record", timeout: 25) {
            addSubscription.exists && addSubscription.isEnabled && !app.staticTexts["正在读取订阅"].exists
        }
        // Never continue, replace or discard another user's retained draft or
        // accepted intent. These prerequisites FAIL rather than clearing data.
        XCTAssertEqual(addSubscription.label, "添加", "An existing subscription draft must be preserved")
        let ownedName: String
        let subscriptionID: String
        if let retained {
            ownedName = retained.name; subscriptionID = retained.id
            let subscription = exactText("subscription:" + subscriptionID, app: app)
            reveal(subscription, in: app.scrollViews["subscription-scroll"], app: app)
            XCTAssertEqual(subscription.label, ownedName, "Reuse only the exact original owned Core record selected in the runner")
            XCTAssertEqual(exactText("subscription-url:" + subscriptionID, app: app).label, input,
                           "Do not edit an existing record to make its URL match")
        } else {
            let priorOwned = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "subscription:", "原生订阅-"))
            XCTAssertEqual(priorOwned.count, 0, "An earlier owned record exists: select its exact ID/name in the runner rather than creating a duplicate")
            ownedName = "原生订阅-" + UUID().uuidString.lowercased()
            addSubscription.tap()
            let name = app.textFields["subscription-name"]
            let url = app.textFields["subscription-url"]
            XCTAssertTrue(name.waitForExistence(timeout: 10)); XCTAssertTrue(url.exists)
            name.tap(); name.typeText(ownedName)
            url.tap(); url.typeText(input)
            let save = app.buttons["subscription-save"]
            XCTAssertTrue(save.exists && save.isEnabled); save.tap()
            wait("Only the original typed save ACK closes this owned draft", timeout: 90) { !save.exists }
            let subscription = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "subscription:", ownedName)).firstMatch
            reveal(subscription, in: app.scrollViews["subscription-scroll"], app: app)
            subscriptionID = String(subscription.identifier.dropFirst("subscription:".count))
            XCTAssertEqual(subscription.label, ownedName)
        }
        XCTAssertNotNil(Int64(subscriptionID), "Use the actual saved Core subscription ID")
        facts(["subscriptionID": subscriptionID, "subscriptionName": ownedName, "subscriptionURL": input,
               "selection": retained == nil ? "created through normal UI" : "reuse exact original owned Core record"],
              name: "actual-owned-subscription-selected-before-provider-check")
        let check = exactButton("subscription-check:" + subscriptionID, app: app)
        reveal(check, in: app.scrollViews["subscription-scroll"], app: app)
        XCTAssertTrue(check.isEnabled); check.tap()
        let none = app.buttons["subscription-select-none"]
        XCTAssertTrue(none.waitForExistence(timeout: 180), "The real provider fetch and actual Core diff must succeed.\n" + app.debugDescription)
        reveal(none, in: app.scrollViews["subscription-scroll"], app: app)
        XCTAssertTrue(none.isEnabled); none.tap()
        let apply = app.buttons["subscription-apply-selection"]
        XCTAssertEqual(apply.label, "应用所选 0 项"); XCTAssertFalse(apply.isEnabled)

        let addedPrefix = "subscription-change:" + subscriptionID + ":added:"
        let added = try firstActualAdded(addedPrefix, excluding: Set(before.keys), app: app)
        let sourceID = String(added.identifier.dropFirst(addedPrefix.count))
        guard let sourceURL = URL(string: sourceID), ["http", "https"].contains(sourceURL.scheme?.lowercased() ?? ""), sourceURL.host != nil else {
            XCTFail("The chosen Core added row must identify an actual HTTP source")
            throw Prerequisite.invalid("actual added source identity")
        }
        XCTAssertFalse(before.keys.contains(sourceID), "Never edit an existing source")
        XCTAssertFalse(initialRealSourceIDs.contains(sourceID))
        XCTAssertEqual(try switchValue(added), false, "All sources were cleared through the actual selection control")
        tapNativeSwitch(added, apply: apply, app: app, name: "actual-subscription-select-one")
        wait("Select exactly this actual safe-added source", timeout: 10) { (added.value as? String) == "1" }
        reveal(apply, in: app.scrollViews["subscription-scroll"], app: app, towardTop: true)
        XCTAssertEqual(apply.label, "应用所选 1 项"); XCTAssertTrue(apply.isEnabled); apply.tap()
        let result = app.staticTexts["subscription-apply-result"]
        let appliedID = "subscription-applied-source:" + subscriptionID + ":" + sourceID
        let appliedSource = exactText(appliedID, app: app)
        wait("The original Core apply ACK must confirm this one selected source; pending is not success", timeout: 120) {
            result.exists && result.label.hasPrefix("本次已应用 1 项，") && appliedSource.exists && check.isEnabled
        }
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "subscription-applied-source:" + subscriptionID + ":")).count, 1)
        keep(app, name: "actual-subscription-one-original-apply-ACK")
        closeSubscriptions(app)

        // This is the same Workspace. onDismiss refreshes only the projection;
        // the original apply was already confirmed by its typed receipt above.
        let admittedName = exactText("online-source:" + sourceID, app: app)
        XCTAssertTrue(admittedName.waitForExistence(timeout: 30), "Closing the subscription must refresh the existing source management page")
        let actualName = admittedName.label
        let admitted = try sourceValues(app)
        XCTAssertEqual(Set(admitted.keys), Set(before.keys).union([sourceID]), "Exactly one new source may enter this library")
        for (id, value) in before { XCTAssertEqual(admitted[id], value, "Existing source enable state must be preserved: " + id) }
        let enabledID = "online-source-enabled:" + sourceID
        let enabled = exactSwitch(enabledID, app: app)
        reveal(enabled, in: app.scrollViews["online-source-scroll"], app: app)
        let originalEnabled = try switchValue(enabled), editedEnabled = !originalEnabled
        XCTAssertTrue(enabled.isEnabled)
        tapNativeSwitch(enabled, app: app, name: "actual-owned-source-enable-edit")
        wait("The real source edit must leave its busy operation before continuing", timeout: 90) {
            enabled.exists && enabled.isEnabled && (enabled.value as? String) == (editedEnabled ? "1" : "0")
        }
        // Recreate the native Toggle from the Workspace's immutable source DTO.
        // That DTO is refreshed by mutate only after the original update ACK;
        // an optimistic UIKit switch animation cannot satisfy this assertion.
        app.buttons["online-close-sources"].tap()
        XCTAssertTrue(app.buttons["online-open-sources"].waitForExistence(timeout: 10)); app.buttons["online-open-sources"].tap()
        let edited = exactSwitch(enabledID, app: app)
        XCTAssertTrue(edited.waitForExistence(timeout: 30))
        wait("The confirmed source projection must contain the actual saved enable value", timeout: 90) {
            (edited.value as? String) == (editedEnabled ? "1" : "0")
        }
        let afterEdit = try sourceValues(app)
        XCTAssertEqual(afterEdit[sourceID], editedEnabled)
        for (id, value) in before { XCTAssertEqual(afterEdit[id], value) }
        facts(["subscriptionID": subscriptionID, "subscriptionName": ownedName, "subscriptionURL": input,
               "sourceID": sourceID, "sourceName": actualName,
               "originalEnabled": String(originalEnabled), "editedEnabled": String(editedEnabled)],
              name: "actual-owned-subscription-and-locally-edited-source")

        openSubscriptions(app)
        let recheck = exactButton("subscription-check:" + subscriptionID, app: app)
        reveal(recheck, in: app.scrollViews["subscription-scroll"], app: app)
        XCTAssertTrue(recheck.isEnabled); recheck.tap()
        XCTAssertTrue(none.waitForExistence(timeout: 180), "Recheck must use the actual provider and Core plan")
        let localOnly = exactText("subscription-change-kind:" + subscriptionID + ":localOnly:" + sourceID, app: app)
        let conflict = exactText("subscription-change-kind:" + subscriptionID + ":conflict:" + sourceID, app: app)
        let retainedChange = try revealRetained(localOnly: localOnly, conflict: conflict, app: app)
        XCTAssertTrue(["仅本机", "存在冲突"].contains(retainedChange.label), "The actual Core diff must protect the local edit")
        XCTAssertFalse(exactSwitch("subscription-change:" + subscriptionID + ":added:" + sourceID, app: app).exists)
        XCTAssertFalse(exactSwitch("subscription-change:" + subscriptionID + ":update:" + sourceID, app: app).exists)
        facts(["sourceID": sourceID, "actualCoreChangeID": retainedChange.identifier,
               "actualCoreChangeLabel": retainedChange.label], name: "actual-subscription-protected-local-diff")
        keep(app, name: "actual-subscription-local-change-retained")
        closeSubscriptions(app)
        let retainedSource = exactSwitch(enabledID, app: app)
        XCTAssertTrue(retainedSource.waitForExistence(timeout: 30))
        XCTAssertEqual(try switchValue(retainedSource), editedEnabled)
        app.buttons["online-close-workspace"].tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 15))
        app.terminate(); app.launch()

        openSources(app)
        let cold = try sourceValues(app)
        XCTAssertEqual(cold, afterEdit, "Cold startup must retain the new enable value and every original source value")
        XCTAssertEqual(exactText("online-source:" + sourceID, app: app).label, actualName)
        openSubscriptions(app)
        let coldSubscription = exactText("subscription:" + subscriptionID, app: app)
        reveal(coldSubscription, in: app.scrollViews["subscription-scroll"], app: app)
        XCTAssertEqual(coldSubscription.label, ownedName)
        XCTAssertEqual(exactText("subscription-url:" + subscriptionID, app: app).label, input)
        XCTAssertTrue(exactButton("subscription-check:" + subscriptionID, app: app).isEnabled)
        XCTAssertEqual(app.buttons["subscription-add"].label, "添加", "No owned accepted intent or draft may remain pending")
        keep(app, name: "actual-subscription-and-source-value-after-cold-start")
        closeSubscriptions(app)
        app.buttons["online-close-workspace"].tap()
        XCTAssertTrue(app.buttons["更多书架操作"].waitForExistence(timeout: 15))
        // Keep the newly owned subscription/source as attributable evidence.
        // Existing sources, editor drafts, books and downloaded originals are
        // never deleted, rewritten, provisioned or used as cleanup targets.
    }

    private func openSources(_ app: XCUIApplication) {
        let menu = app.buttons["更多书架操作"]
        XCTAssertTrue(menu.waitForExistence(timeout: 25)); menu.tap()
        let online = app.buttons["搜索与书源"]
        XCTAssertTrue(online.waitForExistence(timeout: 5)); online.tap()
        let sources = app.buttons["online-open-sources"]
        XCTAssertTrue(sources.waitForExistence(timeout: 10)); sources.tap()
        XCTAssertTrue(app.buttons["online-rule-subscriptions"].waitForExistence(timeout: 15))
        wait("Read the actual existing source projection", timeout: 30) {
            app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "online-source:")).count >= 2
                && !app.staticTexts["正在加载书源"].exists
        }
    }
    private func openSubscriptions(_ app: XCUIApplication) {
        let button = app.buttons["online-rule-subscriptions"]
        reveal(button, in: app.scrollViews["online-source-scroll"], app: app, towardTop: true)
        button.tap()
        XCTAssertTrue(app.buttons["subscription-add"].waitForExistence(timeout: 15))
    }
    private func closeSubscriptions(_ app: XCUIApplication) {
        let close = app.buttons["关闭订阅管理"]
        XCTAssertTrue(close.waitForExistence(timeout: 5)); close.tap()
        XCTAssertTrue(app.buttons["online-rule-subscriptions"].waitForExistence(timeout: 15))
    }
    private func sourceValues(_ app: XCUIApplication) throws -> [String: Bool] {
        let prefix = "online-source:"
        let rows = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).allElementsBoundByIndex
        XCTAssertFalse(rows.isEmpty)
        var values: [String: Bool] = [:]
        for row in rows {
            let id = String(row.identifier.dropFirst(prefix.count))
            XCTAssertNil(values[id], "A source identity must be unambiguous")
            values[id] = try switchValue(exactSwitch("online-source-enabled:" + id, app: app))
        }
        return values
    }
    private func firstActualAdded(_ prefix: String, excluding existing: Set<String>, app: XCUIApplication) throws -> XCUIElement {
        let scroll = app.scrollViews["subscription-scroll"]
        var skippedNonHTTP = Set<String>()
        for _ in 0..<80 {
            let rows = app.switches.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).allElementsBoundByIndex
            for row in rows where row.isHittable && row.isEnabled {
                let sourceID = String(row.identifier.dropFirst(prefix.count))
                guard let url = URL(string: sourceID), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                      let host = url.host, !host.isEmpty else {
                    // Real packages may include legitimate non-HTTP source IDs
                    // such as DQuestQBall. Preserve that Core diff unchanged;
                    // this journey selects a real HTTP source for local edit.
                    skippedNonHTTP.insert(sourceID); continue
                }
                guard !existing.contains(sourceID) else { continue }
                facts(["sourceID": sourceID, "actualCoreChangeID": row.identifier,
                       "visibleNonHTTPIDsNotSelected": skippedNonHTTP.sorted().joined(separator: "\n")],
                      name: "actual-subscription-safe-HTTP-added-selection")
                return row
            }
            scroll.swipeUp()
        }
        XCTFail("The actual provider must contain an independently selectable safe-added source outside the existing library.\n" + app.debugDescription)
        throw Prerequisite.absent("actual safe-added source")
    }
    private func retainedOwnedSubscription() throws -> (id: String, name: String)? {
        let values = ProcessInfo.processInfo.environment
        let id = values["READER_SUBSCRIPTION_OWNED_ID"], name = values["READER_SUBSCRIPTION_OWNED_NAME"]
        if id == nil && name == nil { return nil }
        let prefix = "原生订阅-"
        guard let id, let name, let numericID = Int64(id), numericID > 0,
              name.hasPrefix(prefix), UUID(uuidString: String(name.dropFirst(prefix.count))) != nil else {
            XCTFail("An existing owned subscription requires the original Core ID and full UUID-owned name together; never infer or replace either")
            throw Prerequisite.invalid("READER_SUBSCRIPTION_OWNED_ID/READER_SUBSCRIPTION_OWNED_NAME")
        }
        return (id, name)
    }
    private func revealRetained(localOnly: XCUIElement, conflict: XCUIElement, app: XCUIApplication) throws -> XCUIElement {
        let scroll = app.scrollViews["subscription-scroll"]
        for _ in 0..<100 {
            if localOnly.exists && localOnly.isHittable { return localOnly }
            if conflict.exists && conflict.isHittable { return conflict }
            scroll.swipeUp()
        }
        XCTFail("The second actual diff must expose the same locally edited source as localOnly/conflict; do not replace a missing result with success.\n" + app.debugDescription)
        throw Prerequisite.absent("actual protected local change")
    }
    private func reveal(_ element: XCUIElement, in scroll: XCUIElement, app: XCUIApplication, towardTop: Bool = false) {
        XCTAssertTrue(scroll.exists)
        for _ in 0..<100 {
            if element.exists && element.isHittable { return }
            if towardTop { scroll.swipeDown() } else { scroll.swipeUp() }
        }
        XCTAssertTrue(element.exists && element.isHittable, "Reach the exact actual UI row through ordinary scrolling.\n" + app.debugDescription)
    }
    private func switchValue(_ element: XCUIElement) throws -> Bool {
        XCTAssertTrue(element.exists)
        guard let value = element.value as? String, value == "0" || value == "1" else {
            XCTFail("Read the actual native Switch value, not its label or an assumed default: " + String(describing: element.value))
            throw Prerequisite.invalid("native switch value")
        }
        return value == "1"
    }
    private func tapNativeSwitch(_ row: XCUIElement, apply: XCUIElement? = nil,
                                 app: XCUIApplication, name: String) {
        // The retained subscription-2 event tapped the outer row centre at
        // (201,767.5), in label space. Its actual UISwitch was at the right
        // edge. Reuse the existing, verified Appearance native-switch driver.
        let native = row.switches.firstMatch
        let control = native.exists ? native : row
        switchEvidence(row, native: native, control: control, apply: apply, app: app, name: name + "-before")
        XCTAssertTrue(control.isEnabled); XCTAssertTrue(control.isHittable)
        XCTAssertTrue(app.frame.contains(control.frame), "Tap the visible native switch, not the row's label-space centre")
        control.tap()
        switchEvidence(row, native: native, control: control, apply: apply, app: app, name: name + "-after")
    }
    private func switchEvidence(_ row: XCUIElement, native: XCUIElement, control: XCUIElement,
                                apply: XCUIElement?, app: XCUIApplication, name: String) {
        let nativePresent = native.exists
        let applyLabel = apply.map { $0.exists ? $0.label : "absent" } ?? "not-applicable"
        let evidence = XCTAttachment(string: [
            "selectedUIID=" + row.identifier,
            "outerValue=" + String(describing: row.value),
            "outerFrame=" + String(describing: row.frame),
            "nativePresent=" + String(nativePresent),
            "nativeValue=" + (nativePresent ? String(describing: native.value) : "absent"),
            "nativeFrame=" + (nativePresent ? String(describing: native.frame) : "absent"),
            "tapTargetFrame=" + String(describing: control.frame),
            "applyLabel=" + applyLabel,
            "applyCountDigits=" + String(applyLabel.filter(\.isNumber)),
            row.debugDescription
        ].joined(separator: "\n"))
        evidence.name = name + "-actual-switch-AX"; evidence.lifetime = .keepAlways; add(evidence)
        keep(app, name: name)
    }
    // Source IDs are full Core identities and may exceed XCTest's 128-byte
    // identifier subscript limit. Exact predicates preserve every byte.
    private func exactText(_ id: String, app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }
    private func exactButton(_ id: String, app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }
    private func exactSwitch(_ id: String, app: XCUIApplication) -> XCUIElement {
        app.switches.matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }
    private func wait(_ fact: String, timeout: TimeInterval, _ condition: @escaping () -> Bool) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: timeout), .completed, fact)
    }
    private func facts(_ fields: [String: String], name: String) {
        let attachment = XCTAttachment(string: fields.keys.sorted().map { $0 + "=" + (fields[$0] ?? "") }.joined(separator: "\n"))
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func keep(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
