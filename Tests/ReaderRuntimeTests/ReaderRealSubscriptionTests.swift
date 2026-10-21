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
            let secondPlan = try await service.checkRuleSubscription(saved)
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
