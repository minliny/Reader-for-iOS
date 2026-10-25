import Combine
import CryptoKit
import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import Reader

/// Controlled DTOs below exercise Host lifetime/ownership only. They are not
/// Core books, real source packages, HTTP responses or subscription acceptance.
@MainActor
final class ReaderRuleSubscriptionLifecycleTests: XCTestCase {
    func testProductionPanelInvalidatesRetainedPreviewWithoutAutomaticCheckOrWrite() async throws {
        let service = SubscriptionLifecycleService()
        let domain = "ReaderSubscriptionLifecycle-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain); service.release() }
        let state = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
        let scheduler = ReaderRuleSubscriptionScheduler(checkDue: { ["Controlled partial opportunity failure"] })
        let mount = try mountPanel(state: state, scheduler: scheduler)
        defer { mount.unmount() }
        await waitUntil("Production Panel activated", { state.loaded && state.canCheckPreview })

        state.check(service.subscription)
        await waitUntil("Explicit original check entered", { service.checks == 1 })
        let first = service.plan("first")
        try service.completeCheck(0, plan: first)
        await waitUntil("Original preview published", { state.plan == first })
        state.selectedSourceIDs = [first.changes[0].sourceId]
        let originalSelection = state.selectedSourceIDs
        let readsBeforeOpportunity = service.listReads
        await scheduler.foregroundOpportunity()
        await waitUntil("Production completion observer invalidated the original preview and refreshed the current subscription projection", {
            state.previewInvalidation != nil && service.listReads == readsBeforeOpportunity + 1 && !state.loading
        })
        XCTAssertEqual(state.plan, first); XCTAssertEqual(state.selectedSourceIDs, originalSelection)
        XCTAssertFalse(state.canApplyPreview); XCTAssertEqual(service.checks, 1)
        state.applySelection()
        XCTAssertTrue(service.writes.isEmpty, "Invalidation must not create or retry an apply")

        // Only this explicit user-action entry obtains another preview.
        state.check(service.subscription)
        await waitUntil("Explicit recheck entered", { service.checks == 2 })
        let second = service.plan("second")
        try service.completeCheck(1, plan: second)
        await waitUntil("User-requested preview published", { state.plan == second && state.canApplyPreview })
        XCTAssertNil(state.previewInvalidation); XCTAssertTrue(service.writes.isEmpty)
        state.selectedSourceIDs = [second.changes[1].sourceId]
        let secondSelection = state.selectedSourceIDs
        service.rejectApply = true
        // This test-only owner fact is controlled. The separate real Core method
        // proves where production can construct the exact-receipt marker.
        state.actions.pendingChecker = { _ in false }
        state.applySelection()
        await waitUntil("Confirmed rejection retired only the read preview", {
            state.previewInvalidation != nil && !state.actions.busy && !state.actions.hasPending
        })
        XCTAssertEqual(service.writes.count, 1)
        XCTAssertEqual(state.plan, second); XCTAssertEqual(state.selectedSourceIDs, secondSelection)
        XCTAssertFalse(state.canApplyPreview); XCTAssertNil(state.pendingIntent)
        state.applySelection()
        XCTAssertEqual(service.writes.count, 1, "A rejected old preview cannot repeatedly allocate new operations")

        state.check(service.subscription)
        await waitUntil("Third explicit check entered before scene suspension", { service.checks == 3 })
        let late = service.plan("late")
        mount.setPhase(.inactive)
        await waitUntil("Actual Panel scene observer retired only the pending read", {
            state.previewInvalidation != nil && !state.canCheckPreview && state.checkingID == nil
        })
        let unexpected = expectation(description: "Cancelled check cannot publish a late preview")
        unexpected.isInverted = true
        let observation = state.$plan.dropFirst().sink { value in if value != nil { unexpected.fulfill() } }
        defer { observation.cancel() }
        try service.completeCheck(2, plan: late)
        mount.setPhase(.active)
        await waitUntil("Foreground restores only the explicit check action", { state.canCheckPreview })
        await fulfillment(of: [unexpected], timeout: 0.3)
        XCTAssertNil(state.plan); XCTAssertNotNil(state.previewInvalidation)
        XCTAssertEqual(service.checks, 3); XCTAssertEqual(service.writes.count, 1)
    }

    func testPreviewLifecycleDoesNotReplaceAcceptedSaveOrUnknownApplyIdentity() async throws {
        for isApply in [false, true] {
            let service = SubscriptionLifecycleService()
            let domain = "ReaderSubscriptionUnknown-" + UUID().uuidString
            let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
            defer { defaults.removePersistentDomain(forName: domain); service.release() }
            let state = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
            let scheduler = ReaderRuleSubscriptionScheduler(checkDue: { [] })
            let mount = try mountPanel(state: state, scheduler: scheduler)
            defer { mount.unmount() }
            await waitUntil("Production Panel active for original intent", { state.loaded && state.canCheckPreview })
            if isApply {
                state.check(service.subscription)
                await waitUntil("Original apply preview check entered", { service.checks == 1 })
                let plan = service.plan("accepted")
                try service.completeCheck(0, plan: plan)
                await waitUntil("Original apply preview visible", { state.plan == plan })
                state.selectedSourceIDs = [plan.changes[0].sourceId]
                state.applySelection()
            } else {
                state.draft = ReaderSubscriptionDraft(service.subscription)
                state.saveDraft()
            }
            await waitUntil("Original write remains unknown in its actual action owner", {
                service.writes.count == 1 && state.actions.hasPending && !state.actions.busy
            })
            let original = try XCTUnwrap(state.pendingIntent)
            let frozenIntent = try encode(original)
            let frozenDraft = try encode(state.draft)
            let frozenSelection = state.selectedSourceIDs
            let frozenPlan = state.plan
            let originalHostJournal = defaults.data(forKey: "reader.ruleSubscriptions.intent.v1")
            XCTAssertEqual(state.actions.pendingOperationID, original.operationID)
            XCTAssertNotNil(state.actions.recovery)

            mount.setPhase(.inactive)
            await waitUntil("Scene inactivation observed", { !state.canCheckPreview })
            await scheduler.foregroundOpportunity()
            mount.setPhase(.active)
            mount.unmount()
            state.check(service.subscription); state.applySelection(); state.saveDraft()
            XCTAssertEqual(service.writes.count, 1, "Read lifetime signals cannot resend an unknown accepted write")
            XCTAssertEqual(service.checks, isApply ? 1 : 0)
            XCTAssertEqual(try encode(try XCTUnwrap(state.pendingIntent)), frozenIntent)
            XCTAssertEqual(try encode(state.draft), frozenDraft)
            XCTAssertEqual(state.plan, frozenPlan); XCTAssertEqual(state.selectedSourceIDs, frozenSelection)
            XCTAssertEqual(defaults.data(forKey: "reader.ruleSubscriptions.intent.v1"), originalHostJournal)
            XCTAssertEqual(state.actions.pendingOperationID, original.operationID)
            XCTAssertTrue(state.actions.hasPending); XCTAssertNotNil(state.actions.recovery)
            XCTAssertEqual(service.writes[0].operationID, original.operationID)
            XCTAssertEqual(try encode(service.writes[0].mutation), try encode(original.mutation))
        }
    }

    /// Uses the existing unmodified 5,606-byte Harmony Git source-package copy.
    /// No URL is fetched; this proves original Core receipt eligibility only,
    /// not an actual remotely published subscription update or native UI journey.
    func testOriginalSourcePackageCoreRejectionRequiresExactCompletedFrozenReceipt() async throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let packageURL = documents.appendingPathComponent("Reader-real-sources.json")
        let package = try Data(contentsOf: packageURL)
        XCTAssertEqual(package.count, 5606)
        XCTAssertEqual(SHA256.hash(data: package).map { String(format: "%02x", $0) }.joined(),
            "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322")
        let originalJSON = try XCTUnwrap(String(data: package, encoding: .utf8))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderOriginalSubscriptionReceipt-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        do {
            let subscription = ReaderSourceSubscription(id: 941006, name: "Original source package receipt boundary",
                url: "https://shuyuan-api.yiove.com/import/book-source-collection/3d9f811b-0831-4203-9fcb-3e8020f8aa2d",
                type: 0, customOrder: 0, autoUpdate: false, update: 0)
            let saveID = UUID().uuidString
            _ = try await service.saveRuleSubscription(subscription, operationID: saveID)
            let params = try JSONSerialization.data(withJSONObject: ["subscriptionId": subscription.id, "remoteJson": originalJSON])
            let first = try JSONDecoder().decode(ReaderSubscriptionPlan.self,
                from: await service.performCoreCommand(method: "rule-sub.update.preview.v1", parameters: params))
            let second = try JSONDecoder().decode(ReaderSubscriptionPlan.self,
                from: await service.performCoreCommand(method: "rule-sub.update.preview.v1", parameters: params))
            XCTAssertNotEqual(first.planId, second.planId); XCTAssertEqual(first.remoteDigest, second.remoteDigest)
            let selected = [try XCTUnwrap(first.changes.first(where: \.safeToApply)).sourceId]
            let operationID = UUID().uuidString
            do {
                _ = try await service.applyRuleSubscription(first, sourceIDs: selected, operationID: operationID)
                XCTFail("Core must reject the original plan after its real single slot was replaced")
            } catch let rejection as ReaderSubscriptionPreviewRejected {
                XCTAssertEqual(rejection.operationID, operationID); XCTAssertEqual(rejection.planID, first.planId)
                let original = try await service.confirmedRuleSubscriptionRejection(operationID: operationID,
                    planID: first.planId, sourceIDs: selected)
                XCTAssertEqual(original, rejection.originalError)
                if case .core(let code, _, _, _) = rejection.originalError { XCTAssertEqual(code, "INVALID_PARAMS") }
                else { XCTFail("Only the exact original Core rejection may mark this preview") }
            }
            let wrongID = try await service.confirmedRuleSubscriptionRejection(operationID: UUID().uuidString,
                planID: first.planId, sourceIDs: selected)
            let wrongPlan = try await service.confirmedRuleSubscriptionRejection(operationID: operationID,
                planID: second.planId, sourceIDs: selected)
            let wrongSelection = try await service.confirmedRuleSubscriptionRejection(operationID: operationID,
                planID: first.planId, sourceIDs: [])
            let wrongMethod = try await service.confirmedRuleSubscriptionRejection(operationID: saveID,
                planID: first.planId, sourceIDs: selected)
            XCTAssertNil(wrongID); XCTAssertNil(wrongPlan); XCTAssertNil(wrongSelection); XCTAssertNil(wrongMethod)
            let sources = try await service.onlineSources()
            let subscriptions = try await service.ruleSubscriptions()
            let pending = try await service.pendingCoreCommands()
            XCTAssertTrue(sources.isEmpty); XCTAssertEqual(subscriptions, [subscription]); XCTAssertTrue(pending.isEmpty)
            XCTAssertEqual(try Data(contentsOf: packageURL), package)
            try await service.close()
        } catch { try? await service.close(); throw error }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private func waitUntil(_ message: String, _ predicate: @escaping () -> Bool) async {
        let condition = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in predicate() }, object: nil)
        await fulfillment(of: [condition], timeout: 3)
        XCTAssertTrue(predicate(), message)
    }

    private func mountPanel(state: ReaderRuleSubscriptionPanelModel, scheduler: ReaderRuleSubscriptionScheduler) throws
        -> (setPhase: @MainActor (ScenePhase) -> Void, unmount: @MainActor () -> Void) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = try XCTUnwrap(scenes.flatMap(\.windows).first {
            $0.isKeyWindow && !$0.isHidden && $0.windowLevel == .normal
        }, "This Host method requires the actual foreground test App window")
        var parent = try XCTUnwrap(window.rootViewController)
        while let presented = parent.presentedViewController { parent = presented }
        func content(_ phase: ScenePhase) -> AnyView {
            AnyView(ReaderRuleSubscriptionPanel(state: state, subscriptionScheduler: scheduler).environment(\.scenePhase, phase))
        }
        let host = UIHostingController(rootView: content(.active))
        parent.addChild(host); host.view.frame = parent.view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.beginAppearanceTransition(true, animated: false)
        parent.view.addSubview(host.view); host.didMove(toParent: parent); host.endAppearanceTransition()
        host.view.layoutIfNeeded(); XCTAssertTrue(host.view.window === window)
        return ({ phase in host.rootView = content(phase) }, {
            guard host.parent != nil else { return }
            host.beginAppearanceTransition(false, animated: false)
            host.willMove(toParent: nil); host.view.removeFromSuperview(); host.removeFromParent(); host.endAppearanceTransition()
        })
    }
}

@MainActor
private final class SubscriptionLifecycleService: ReaderRuleSubscriptionServing {
    enum Failure: Error { case forbidden, missingContinuation, teardown }
    struct Write { let operationID: String; let mutation: ReaderSubscriptionMutation }
    let subscription = ReaderSourceSubscription(id: 810, name: "Host lifetime DTO", url: "https://subscription-host-boundary.invalid/package.json",
        type: 0, customOrder: 0, autoUpdate: true, update: 0)
    private(set) var checks = 0
    private(set) var listReads = 0
    private(set) var writes: [Write] = []
    var rejectApply = false
    private var pending: [Int: CheckedContinuation<ReaderSubscriptionPlan, Error>] = [:]
    func plan(_ nonce: String) -> ReaderSubscriptionPlan {
        .init(planId: "host-plan-" + nonce, subscriptionId: subscription.id, remoteDigest: String(repeating: "0", count: 64),
            expiresAt: Int64(Date().timeIntervalSince1970 * 1000) + 900_000,
            changes: [.init(sourceId: "host-change-a", name: "Host A", kind: "added"),
                      .init(sourceId: "host-change-b", name: "Host B", kind: "update")])
    }
    func ruleSubscriptions() async throws -> [ReaderSourceSubscription] { listReads += 1; return [subscription] }
    func checkRuleSubscription(_ subscription: ReaderSourceSubscription) async throws -> ReaderSubscriptionPlan {
        let index = checks; checks += 1
        return try await withCheckedThrowingContinuation { pending[index] = $0 }
    }
    func completeCheck(_ index: Int, plan: ReaderSubscriptionPlan) throws {
        guard let continuation = pending.removeValue(forKey: index) else { throw Failure.missingContinuation }
        continuation.resume(returning: plan)
    }
    func saveRuleSubscription(_ subscription: ReaderSourceSubscription, operationID: String) async throws -> ReaderSourceSubscription {
        writes.append(.init(operationID: operationID, mutation: .save(subscription)))
        throw ReaderLibraryError.operationPending(operationID)
    }
    func deleteRuleSubscription(_ subscription: ReaderSourceSubscription, operationID: String) async throws {
        XCTFail("Read lifetime must not delete subscriptions"); throw Failure.forbidden
    }
    func applyRuleSubscription(_ plan: ReaderSubscriptionPlan, sourceIDs: [String], operationID: String) async throws -> ReaderSubscriptionApplied {
        writes.append(.init(operationID: operationID, mutation: .apply(plan, sourceIDs)))
        if rejectApply {
            // A controlled marker tests only the Panel's response to this typed
            // boundary; the actual Core method above proves production provenance.
            throw ReaderSubscriptionPreviewRejected(operationID: operationID, planID: plan.planId,
                originalError: .core(code: "INVALID_PARAMS", message: "Controlled original rejection", retryable: false, reason: nil))
        }
        throw ReaderLibraryError.operationPending(operationID)
    }
    func checkDueRuleSubscriptions() async -> [String] { XCTFail("The Panel must not start automatic checks"); return [] }
    func resumeRuleSubscriptionUpdates() async throws -> [ReaderSubscriptionApplied] { try forbidden("resumeRuleSubscriptionUpdates") }
    func release() { let values = Array(pending.values); pending.removeAll(); values.forEach { $0.resume(throwing: Failure.teardown) } }
    private func forbidden<T>(_ name: String) throws -> T { XCTFail("Unselected boundary: " + name); throw Failure.forbidden }
    func listBooks() async throws -> [ReaderBook] { try forbidden("listBooks") }
    func importBook(at url: URL) async throws -> ReaderImportResult { try forbidden("importBook") }
    func chapters(for book: ReaderBook) async throws -> [ReaderChapter] { try forbidden("chapters") }
    func content(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderChapterContent { try forbidden("content") }
    func progress(for book: ReaderBook) async throws -> ReaderProgressSnapshot { try forbidden("progress") }
    func saveProgress(for book: ReaderBook, content: ReaderChapterContent, scalarOffset: UInt64, expectedRevision: String?) async throws -> ReaderProgressSnapshot { try forbidden("saveProgress") }
    func flush() async throws { let _: Void = try forbidden("flush") }
    func close() async throws { let _: Void = try forbidden("close") }
    func pendingImports() async throws -> [ReaderPendingImport] { try forbidden("pendingImports") }
    func recoverPendingImports() async throws -> [ReaderPendingImport] { try forbidden("recoverPendingImports") }
    func onlineSources() async throws -> [ReaderOnlineSource] { try forbidden("onlineSources") }
    func importSources(_ data: Data, operationID: String) async throws -> [ReaderSourceImportItem] { try forbidden("importSources") }
    func validateSources(_ data: Data) async throws -> [ReaderSourceImportItem] { try forbidden("validateSources") }
    func exportSources(_ identities: [String]?) async throws -> Data { try forbidden("exportSources") }
    func updateSource(_ sourceID: String, enabled: Bool, operationID: String) async throws { let _: Void = try forbidden("updateSource") }
    func deleteSource(_ sourceID: String, operationID: String) async throws { let _: Void = try forbidden("deleteSource") }
    func searchSource(_ sourceID: String, keyword: String, page: Int) async throws -> ReaderSourceSearchResult { try forbidden("searchSource") }
    func onlineDetail(_ candidate: ReaderOnlineCandidate) async throws -> ReaderOnlineDetail { try forbidden("onlineDetail") }
    func refreshOnlineCatalog(for book: ReaderBook) async throws -> ReaderOnlineDetail { try forbidden("refreshOnlineCatalog") }
    func addOnlineBook(_ detail: ReaderOnlineDetail, chapterIndex: UInt32, operationID: String) async throws -> ReaderBook { try forbidden("addOnlineBook") }
    func onlineDiagnostic(_ sourceID: String, keyword: String) async throws -> Data { try forbidden("onlineDiagnostic") }
    func onlineFetch(_ url: URL) async throws -> Data { try forbidden("onlineFetch") }
    func onlineCommand(_ method: String, parameters: Data, operationID: String?) async throws -> Data { try forbidden("onlineCommand") }
    func prepareLogin(_ sourceID: String) async throws -> [HTTPCookie] { try forbidden("prepareLogin") }
    func completeLogin(_ sourceID: String, cookies: [HTTPCookie], originalCookies: [HTTPCookie]) async throws { let _: Void = try forbidden("completeLogin") }
}
