import CryptoKit
import Foundation
import XCTest
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

final class ReaderRealSubscriptionTests: XCTestCase {
    /// This is the only remote input. The frozen repository records a real
    /// 2026-05-01 HTTP 200 response, 2,455,074 bytes, for this 424-source collection:
    /// Reader-Core/legacy/swift/samples/booksources/remote_yiove/
    /// collection_3d9f811b/fetch_log.json and analysis/parser_gap_report.md.
    /// The larger e618 collection historically exceeded Core's 8 MiB admission
    /// limit. Do not trim either package or change URLs after a failed request.
    private let subscriptionURL = "https://shuyuan-api.yiove.com/import/book-source-collection/3d9f811b-0831-4203-9fcb-3e8020f8aa2d"

    func testRealSubscriptionFetchPreviewSafeApplyAndColdReplayPreserveLocalChanges() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("ReaderRealSubscription-" + UUID().uuidString, isDirectory: true)
        let core = root.appendingPathComponent("Core", isDirectory: true)
        let sources = root.appendingPathComponent("Sources", isDirectory: true)
        defer { try? manager.removeItem(at: root) }

        var active: ReaderLibraryService?
        var phase = "create isolated library"
        var facts: [String: Any] = [
            "subscriptionURL": subscriptionURL,
            "remoteInput": "actual Host fetch; complete unmodified provider JSON",
            "remoteReleaseClaim": false
        ]
        do {
            // This initializer creates the actual native HTTP Host and real
            // pinned Core. No test client, transport, response, or remoteJson.
            let service = try ReaderLibraryService(storageURL: core, sourceURL: sources)
            active = service
            let initialSources = try await service.onlineSources()
            XCTAssertTrue(initialSources.isEmpty, "Only this temporary library may be changed")
            let subscription = ReaderSourceSubscription(id: 941005, name: "真实 Yiove 书源集合", url: subscriptionURL,
                type: 0, customOrder: 0, autoUpdate: false, update: 0)
            let saved = try await service.saveRuleSubscription(subscription, operationID: UUID().uuidString)
            XCTAssertEqual(saved, subscription)

            phase = "first real Host fetch and Core preview"
            let firstPlan = try await service.checkRuleSubscription(saved)
            assertOriginalPlan(firstPlan, subscription: saved)
            try attach(firstPlan, name: "Actual-subscription-first-plan")
            facts["firstRemoteDigest"] = firstPlan.remoteDigest
            let afterPreview = try await service.onlineSources()
            let subscriptionsAfterPreview = try await service.ruleSubscriptions()
            XCTAssertTrue(afterPreview.isEmpty, "Preview must not import the provider's sources")
            XCTAssertEqual(subscriptionsAfterPreview, [saved], "Preview must not advance the subscription timestamp")
            let firstChange = try XCTUnwrap(firstPlan.changes.filter { $0.safeToApply && isHTTPSource($0.sourceId) }
                .sorted { $0.sourceId < $1.sourceId }.first, "The real provider must supply an admissible safe source; no fixture or fallback")
            XCTAssertEqual(firstChange.kind, "added")
            let firstOperation = UUID().uuidString
            facts["firstSourceId"] = firstChange.sourceId
            facts["firstOperationId"] = firstOperation

            phase = "apply one original safe source"
            let firstApplied = try await service.applyRuleSubscription(firstPlan, sourceIDs: [firstChange.sourceId], operationID: firstOperation)
            assertOriginalApply(firstApplied, plan: firstPlan, selectedID: firstChange.sourceId)
            try attach(firstApplied, name: "Actual-subscription-first-original-ACK")
            let firstSources = try await service.onlineSources()
            XCTAssertEqual(firstSources.map(\.id), [firstChange.sourceId], "Only the selected real source is admitted")
            let firstSource = try XCTUnwrap(firstSources.first)
            XCTAssertEqual(firstSource.name, firstChange.name)
            XCTAssertFalse(firstSource.version.isEmpty)
            try assertDefinitionIdentity(firstSource)

            phase = "local user edit of the admitted real source"
            // The public source-management operation changes only the local
            // library. The remote package is never edited or reconstructed.
            try await service.updateSource(firstSource.id, enabled: !firstSource.enabled, operationID: UUID().uuidString)
            let editedSources = try await service.onlineSources()
            let edited = try XCTUnwrap(editedSources.first(where: { $0.id == firstSource.id }))
            XCTAssertEqual(edited.enabled, !firstSource.enabled)
            XCTAssertNotEqual(edited.version, firstSource.version)

            phase = "second real Host fetch and protected-local diff"
            let currentSubscriptions = try await service.ruleSubscriptions()
            let currentSubscription = try XCTUnwrap(currentSubscriptions.first(where: { $0.id == saved.id }))
            let secondPlan = try await service.checkRuleSubscription(currentSubscription)
            assertOriginalPlan(secondPlan, subscription: saved)
            try attach(secondPlan, name: "Actual-subscription-second-plan")
            facts["secondRemoteDigest"] = secondPlan.remoteDigest
            facts["sameRemoteBytes"] = firstPlan.remoteDigest == secondPlan.remoteDigest
            let localChange = try XCTUnwrap(secondPlan.changes.first(where: { $0.sourceId == edited.id }))
            facts["localChangeKind"] = localChange.kind
            XCTAssertFalse(localChange.safeToApply, "A local edit must not become an automatic replacement")
            if firstPlan.remoteDigest == secondPlan.remoteDigest {
                XCTAssertEqual(localChange.kind, "localOnly", "Unchanged remote bytes are not a newly published provider update")
            } else {
                XCTAssertTrue(["localOnly", "conflict", "removedRemote", "unchanged"].contains(localChange.kind),
                    "A real provider change must still preserve the locally edited source")
            }
            let secondChange = try XCTUnwrap(secondPlan.changes.filter {
                $0.safeToApply && $0.sourceId != edited.id && isHTTPSource($0.sourceId)
            }.sorted { $0.sourceId < $1.sourceId }.first, "A second real safe source is required to exercise selective apply")
            let secondOperation = UUID().uuidString
            facts["secondSourceId"] = secondChange.sourceId
            facts["secondOperationId"] = secondOperation

            phase = "selective safe apply preserves the local edit"
            let secondApplied = try await service.applyRuleSubscription(secondPlan, sourceIDs: [secondChange.sourceId], operationID: secondOperation)
            assertOriginalApply(secondApplied, plan: secondPlan, selectedID: secondChange.sourceId)
            XCTAssertTrue(secondApplied.skippedSourceIds.contains(edited.id))
            try attach(secondApplied, name: "Actual-subscription-second-original-ACK")
            let beforeCold = try await service.onlineSources().sorted { $0.id < $1.id }
            XCTAssertEqual(Set(beforeCold.map(\.id)), Set([firstChange.sourceId, secondChange.sourceId]))
            XCTAssertEqual(beforeCold.first(where: { $0.id == edited.id }), edited)
            let secondSource = try XCTUnwrap(beforeCold.first(where: { $0.id == secondChange.sourceId }))
            XCTAssertEqual(secondSource.name, secondChange.name)
            try assertDefinitionIdentity(secondSource)
            let subscriptionsBeforeCold = try await service.ruleSubscriptions()
            let subscriptionBeforeCold = try XCTUnwrap(subscriptionsBeforeCold.first(where: { $0.id == saved.id }))
            XCTAssertEqual(subscriptionBeforeCold.url, subscriptionURL)
            XCTAssertEqual(subscriptionBeforeCold.update, secondApplied.updatedAt)
            try await service.close()
            active = nil

            phase = "cold reopen and replay the two original operation IDs"
            let reopened = try ReaderLibraryService(storageURL: core, sourceURL: sources)
            active = reopened
            let coldSources = try await reopened.onlineSources().sorted { $0.id < $1.id }
            let coldSubscriptions = try await reopened.ruleSubscriptions()
            XCTAssertEqual(coldSources, beforeCold)
            XCTAssertEqual(coldSubscriptions, subscriptionsBeforeCold)
            // These calls reuse the frozen plans, selection and operation IDs.
            // They must return the old ACK, even after a later local mutation;
            // they do not fetch, create a new plan, or infer ACKs from source.list.
            let firstReplay = try await reopened.applyRuleSubscription(firstPlan, sourceIDs: [firstChange.sourceId], operationID: firstOperation)
            let secondReplay = try await reopened.applyRuleSubscription(secondPlan, sourceIDs: [secondChange.sourceId], operationID: secondOperation)
            XCTAssertEqual(firstReplay, firstApplied)
            XCTAssertEqual(secondReplay, secondApplied)
            let afterReplay = try await reopened.onlineSources().sorted { $0.id < $1.id }
            let subscriptionsAfterReplay = try await reopened.ruleSubscriptions()
            let pending = try await reopened.pendingCoreCommands()
            XCTAssertEqual(afterReplay, beforeCold, "Old apply replay must not replace the local edit or duplicate a source")
            XCTAssertEqual(subscriptionsAfterReplay, subscriptionsBeforeCold, "Replay must retain the original update timestamp")
            XCTAssertTrue(pending.isEmpty)
            facts["coldSourceIds"] = afterReplay.map(\.id)
            facts["retainedLocalSourceId"] = edited.id
            facts["originalUpdatedAt"] = secondApplied.updatedAt
            try attachFacts(facts, name: "Actual-subscription-fetch-diff-apply-cold-replay")
            try await reopened.close()
            active = nil
        } catch {
            facts["failedPhase"] = phase
            facts["failure"] = error.localizedDescription
            try? attachFacts(facts, name: "Actual-subscription-failure")
            if let active { try? await active.close() }
            // URL, status, encoding, admission and plan failures are failures.
            // Never skip, change URL, or substitute a historical/local response.
            throw error
        }
    }

    /// Uses the existing, complete 2026-10-22 Yiove download selected by its
    /// actual filesystem path. No HTTP response, source or package is invented.
    /// Controlled mutation placement proves the local fetch/preview boundary;
    /// it does not establish a new provider release or OS background execution.
    func testOriginalProviderPackageCheckRejectsChangedSubscriptionAndABAWithoutSourceWrites() async throws {
        let package = try originalProviderPackage()
        enum Change: CaseIterable, Equatable, Sendable { case unchanged, staleSnapshot, disableAutoUpdate, providerURL, aba }
        let alternateURL = "https://shuyuan-api.yiove.com/import/book-source-collection/e61838fa-9a13-4137-b68a-192313eade0c"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderSubscriptionCheckOwnership-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        do {
            for (index, change) in Change.allCases.enumerated() {
                let original = ReaderSourceSubscription(id: 941007 + Int64(index), name: "真实订阅检查归属",
                    url: subscriptionURL, type: 0, customOrder: 0, autoUpdate: true, update: 0)
                let changesProvider = change == .providerURL || change == .aba
                let changed = ReaderSourceSubscription(id: original.id, name: original.name,
                    url: changesProvider ? alternateURL : original.url, type: original.type,
                    customOrder: original.customOrder, autoUpdate: changesProvider, update: original.update)
                _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString)
                if change == .staleSnapshot { _ = try await service.saveRuleSubscription(changed, operationID: UUID().uuidString) }
                do {
                    let plan = try await service.checkRuleSubscription(original, fetch: { url in
                        XCTAssertEqual(url.absoluteString, original.url)
                        XCTAssertNotEqual(change, .staleSnapshot, "A stale caller must be rejected before requesting its provider")
                        if change != .unchanged {
                            _ = try await service.saveRuleSubscription(changed, operationID: UUID().uuidString)
                            if change == .aba { _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString) }
                        }
                        return package
                    })
                    XCTAssertEqual(change, .unchanged, "An intervening accepted configuration change must not publish a preview")
                    XCTAssertEqual(plan.subscriptionId, original.id)
                    XCTAssertFalse(plan.changes.isEmpty)
                } catch {
                    guard change != .unchanged else { throw error }
                    guard error is ReaderSubscriptionCheckChanged else { throw error }
                }
                let expected = change == .unchanged || change == .aba ? original : changed
                let subscriptions = try await service.ruleSubscriptions()
                let retained = try XCTUnwrap(subscriptions.first(where: { $0.id == original.id }))
                XCTAssertEqual(retained, expected)
                let sources = try await service.onlineSources()
                let pending = try await service.pendingCoreCommands()
                XCTAssertTrue(sources.isEmpty, "Check rejection cannot import, replace or remove sources")
                XCTAssertTrue(pending.isEmpty, "A read rejection cannot allocate an apply operation")
                XCTAssertEqual(retained.update, original.update, "Only an original apply ACK may advance the subscription clock")
            }
            try await service.close()
        } catch {
            try? await service.close()
            throw error
        }
    }

    /// The original complete download exercises Core's real replaceable plan
    /// slot. The newer configuration keeps the same provider and changes only
    /// auto-update permission; no HTTP response or source package is invented.
    func testOriginalProviderPackageStaleFetchCannotReplaceCurrentConfigurationPreview() async throws {
        actor CapturedPlan {
            var plan: ReaderSubscriptionPlan?
            func store(_ plan: ReaderSubscriptionPlan) { self.plan = plan }
        }
        let package = try originalProviderPackage()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderSubscriptionCurrentPreview-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        let original = ReaderSourceSubscription(id: 941012, name: "真实订阅预览槽归属",
            url: subscriptionURL, type: 0, customOrder: 0, autoUpdate: true, update: 0)
        let current = ReaderSourceSubscription(id: original.id, name: original.name, url: original.url,
            type: original.type, customOrder: original.customOrder, autoUpdate: false, update: original.update)
        let captured = CapturedPlan()
        do {
            _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString)
            do {
                _ = try await service.checkRuleSubscription(original, fetch: { url in
                    XCTAssertEqual(url.absoluteString, original.url)
                    _ = try await service.saveRuleSubscription(current, operationID: UUID().uuidString)
                    let plan = try await service.checkRuleSubscription(current, fetch: { currentURL in
                        XCTAssertEqual(currentURL.absoluteString, current.url)
                        return package
                    })
                    await captured.store(plan)
                    return package
                })
                XCTFail("The old fetch must be rejected before replacing the current configuration's preview")
            } catch is ReaderSubscriptionCheckChanged { }

            let storedPlan = await captured.plan
            let currentPlan = try XCTUnwrap(storedPlan, "The current configuration must have created its real Core preview")
            assertOriginalPlan(currentPlan, subscription: current)
            let beforeApply = try await service.onlineSources()
            let beforeSubscriptions = try await service.ruleSubscriptions()
            let beforePending = try await service.pendingCoreCommands()
            XCTAssertTrue(beforeApply.isEmpty, "Neither check may import the provider's sources")
            XCTAssertEqual(beforeSubscriptions, [current])
            XCTAssertTrue(beforePending.isEmpty, "The stale check cannot allocate an apply operation")
            let selected = try XCTUnwrap(currentPlan.changes.filter { $0.safeToApply && isHTTPSource($0.sourceId) }
                .sorted { $0.sourceId < $1.sourceId }.first, "Use one actual safe HTTP source from the original complete package")
            let applied = try await service.applyRuleSubscription(currentPlan, sourceIDs: [selected.sourceId], operationID: UUID().uuidString)
            assertOriginalApply(applied, plan: currentPlan, selectedID: selected.sourceId)
            let sources = try await service.onlineSources()
            XCTAssertEqual(sources.map(\.id), [selected.sourceId], "The newer preview must remain usable after the old fetch is rejected")
            let source = try XCTUnwrap(sources.first)
            XCTAssertEqual(source.name, selected.name)
            try assertDefinitionIdentity(source)
            let subscriptions = try await service.ruleSubscriptions()
            let retained = try XCTUnwrap(subscriptions.first)
            XCTAssertEqual(retained.id, current.id); XCTAssertEqual(retained.url, current.url)
            XCTAssertFalse(retained.autoUpdate); XCTAssertEqual(retained.update, applied.updatedAt)
            let pending = try await service.pendingCoreCommands()
            XCTAssertTrue(pending.isEmpty)
            try await service.close()
        } catch {
            try? await service.close()
            throw error
        }
    }

    /// Places a configuration change after the old caller's final head read,
    /// immediately before preview admission. Uses the unchanged downloaded
    /// package and Core's real single plan slot, without network or delays.
    func testOriginalProviderPackageAtomicPreviewAdmissionRetainsCurrentPlanAfterFinalHeadReadAndABA() async throws {
        let package = try originalProviderPackage()
        let remoteJSON = try XCTUnwrap(String(data: package, encoding: .utf8))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderSubscriptionAtomicAdmission-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for aba in [false, true] {
            let directory = root.appendingPathComponent(aba ? "aba" : "changed")
            let service = try ReaderLibraryService(storageURL: directory.appendingPathComponent("Core"), sourceURL: directory.appendingPathComponent("Sources"))
            do {
                let original = ReaderSourceSubscription(id: 941013, name: "真实订阅原子预览准入",
                    url: subscriptionURL, type: 0, customOrder: 0, autoUpdate: true, update: 0)
                let changed = ReaderSourceSubscription(id: original.id, name: original.name, url: original.url,
                    type: original.type, customOrder: original.customOrder, autoUpdate: false, update: original.update)
                _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString)
                let query = try await service.coreRead("rules.mutation.query", [:])
                let originalHead = try XCTUnwrap(JSONSerialization.jsonObject(with: query) as? [String: Any])["head"] ?? NSNull()
                let snapshot = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original))
                let expected: [String: Any] = ["subscription": snapshot, "rulesHead": originalHead]

                _ = try await service.saveRuleSubscription(changed, operationID: UUID().uuidString)
                if aba { _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString) }
                let current = aba ? original : changed
                let currentPlan = try await service.checkRuleSubscription(current, fetch: { url in
                    XCTAssertEqual(url.absoluteString, current.url)
                    return package
                })
                do {
                    _ = try await service.coreRead("rule-sub.update.preview.v1", [
                        "subscriptionId": original.id, "remoteJson": remoteJSON, "expected": expected
                    ])
                    XCTFail("A changed fetch owner must be rejected before it replaces the newer plan")
                } catch ReaderLibraryError.core(let code, _, _, let reason) {
                    XCTAssertEqual(code, "INVALID_PARAMS")
                    XCTAssertEqual(reason, "SUBSCRIPTION_CHECK_CHANGED")
                }
                let beforeApply = try await service.onlineSources()
                let beforeSubscriptions = try await service.ruleSubscriptions()
                let pending = try await service.pendingCoreCommands()
                XCTAssertTrue(beforeApply.isEmpty)
                XCTAssertEqual(beforeSubscriptions, [current])
                XCTAssertTrue(pending.isEmpty, "A stale preview rejection cannot allocate a mutation")
                let selected = try XCTUnwrap(currentPlan.changes.filter { $0.safeToApply && isHTTPSource($0.sourceId) }
                    .sorted { $0.sourceId < $1.sourceId }.first)
                let applied = try await service.applyRuleSubscription(currentPlan, sourceIDs: [selected.sourceId], operationID: UUID().uuidString)
                assertOriginalApply(applied, plan: currentPlan, selectedID: selected.sourceId)
                let sources = try await service.onlineSources()
                XCTAssertEqual(sources.map(\.id), [selected.sourceId], "The exact newer plan must remain usable")
                try await service.close()
            } catch { try? await service.close(); throw error }
        }
    }

    private func originalProviderPackage() throws -> Data {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["READER_REAL_SUBSCRIPTION_PACKAGE_PATH"],
            "Select the existing complete Yiove response.body; do not create or replace package input")
        let inputURL: URL
        if path.hasPrefix("bundle:") {
            inputURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: String(path.dropFirst("bundle:".count)), withExtension: nil),
                                     "Copy the unmodified downloaded response into this signed test bundle")
        } else {
            guard path.hasPrefix("/") else {
                XCTFail("The local runner must provide an absolute original input path")
                throw ReaderLibraryError.invalidResponse("original subscription corpus path")
            }
            inputURL = URL(fileURLWithPath: path)
        }
        let package = try Data(contentsOf: inputURL)
        let digest = SHA256.hash(data: package).map { String(format: "%02x", $0) }.joined()
        guard package.count == 2_309_841,
              digest == "3356dc7a114b50076897873758482ed07fc45b7a1f55bdeced870e1db5fdd663" else {
            XCTFail("The selected input must be the complete unmodified original Yiove download")
            throw ReaderLibraryError.invalidResponse("original subscription corpus identity")
        }
        return package
    }

    private func isHTTPSource(_ identity: String) -> Bool {
        guard let url = URL(string: identity), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme), let host = url.host else { return false }
        return !host.isEmpty
    }

    private func assertOriginalPlan(_ plan: ReaderSubscriptionPlan, subscription: ReaderSourceSubscription,
                                    file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(plan.subscriptionId, subscription.id, file: file, line: line)
        XCTAssertTrue(plan.planId.hasPrefix("\(subscription.id):"), file: file, line: line)
        XCTAssertEqual(plan.remoteDigest.count, 64, file: file, line: line)
        XCTAssertTrue(plan.remoteDigest.allSatisfy { "0123456789abcdef".contains($0) }, file: file, line: line)
        XCTAssertGreaterThan(plan.expiresAt, Int64(Date().timeIntervalSince1970 * 1000), file: file, line: line)
        XCTAssertEqual(Set(plan.changes.map(\.sourceId)).count, plan.changes.count, file: file, line: line)
    }

    private func assertOriginalApply(_ applied: ReaderSubscriptionApplied, plan: ReaderSubscriptionPlan, selectedID: String,
                                     file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(applied.subscriptionId, plan.subscriptionId, file: file, line: line)
        XCTAssertEqual(applied.remoteDigest, plan.remoteDigest, file: file, line: line)
        XCTAssertEqual(applied.appliedSourceIds, [selectedID], file: file, line: line)
        XCTAssertFalse(applied.skippedSourceIds.contains(selectedID), file: file, line: line)
        XCTAssertEqual(Set(applied.appliedSourceIds + applied.skippedSourceIds), Set(plan.changes.map(\.sourceId)), file: file, line: line)
        XCTAssertGreaterThan(applied.updatedAt, 0, file: file, line: line)
    }

    private func assertDefinitionIdentity(_ source: ReaderOnlineSource, file: StaticString = #filePath, line: UInt = #line) throws {
        let definition = try XCTUnwrap(JSONSerialization.jsonObject(with: source.definition) as? [String: Any], file: file, line: line)
        XCTAssertEqual((definition["bookSourceUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), source.id, file: file, line: line)
    }

    private func attach<T: Encodable>(_ value: T, name: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let attachment = XCTAttachment(data: try encoder.encode(value), uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func attachFacts(_ facts: [String: Any], name: String) throws {
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
