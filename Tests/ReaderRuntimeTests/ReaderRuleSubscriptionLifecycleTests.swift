import Combine
import BackgroundTasks
import CryptoKit
import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import Reader

/// Controlled DTOs exercise Host lifetime/ownership and Core metadata lineage. They are not
/// Core books, real source packages, HTTP responses or subscription acceptance.
@MainActor
final class ReaderRuleSubscriptionLifecycleTests: XCTestCase {
    #if DEBUG
    func testPhysicalIsolatedUnitHostRejectsSharedProductionLibrary() async throws {
        guard ReaderIsolatedUnitTestLaunch.isRequested else {
            throw XCTSkip("This method requires the explicitly selected physical isolated unit-test host")
        }
        guard ReaderIsolatedUnitTestLaunch.isAdmitted else {
            XCTFail("The requested isolated unit-test host failed its physical identity or input checks")
            return
        }
        XCTAssertTrue(ReaderNativeCleanupLaunch.backgroundHandlerRegistered,
                      "The isolated host must reject any delivered background opportunity")
        do {
            _ = try await ReaderAppRuntimeStore.shared.library()
            XCTFail("The isolated unit host must not open the shared production library")
        } catch ReaderLibraryError.invalidResponse(let message) {
            XCTAssertEqual(message, "An isolated test launch cannot open the shared App library")
        }
    }
    #endif

    func testAutomaticSubscriptionDueCheckHandlesTimestampExtremesAndDisabledRows() {
        let day: Int64 = 86_400_000
        let now: Int64 = 1_800_000_000_000
        let threshold: Int64 = 1_799_913_600_000
        let highestThreshold: Int64 = 9_223_372_036_768_375_807
        let scenarios: [(now: Int64, update: Int64, due: Bool, label: String)] = [
            (now, .min, true, "oldest imported timestamp"),
            (now, .max, false, "latest imported timestamp"),
            (now, now + 1, false, "future timestamp"),
            (now, now, false, "current timestamp"),
            (now, threshold - 1, true, "just before threshold"),
            (now, threshold, true, "exactly one day old"),
            (now, threshold + 1, false, "just after threshold"),
            (.min, .min, false, "minimum now has no representable due timestamp"),
            (.min, .max, false, "minimum now with maximum update"),
            (.min + day - 1, .min, false, "threshold still below representable range"),
            (.min + day, .min, true, "first representable threshold"),
            (.min + day, .min + 1, false, "one tick after first threshold"),
            (.max, .min, true, "maximum now with minimum update"),
            (.max, .max, false, "maximum now with current update"),
            (.max, highestThreshold - 1, true, "before maximum-now threshold"),
            (.max, highestThreshold, true, "maximum-now exact threshold"),
            (.max, highestThreshold + 1, false, "after maximum-now threshold"),
            (0, -day, true, "epoch exact threshold"),
            (0, -day + 1, false, "epoch after threshold")
        ]
        let original = SubscriptionLifecycleService().subscription
        for enabled in [true, false] {
            for scenario in scenarios {
                let value = ReaderSourceSubscription(id: original.id, name: original.name, url: original.url,
                    type: original.type, customOrder: original.customOrder, autoUpdate: enabled, update: scenario.update)
                XCTAssertEqual(value.isDueForAutomaticUpdate(at: scenario.now), enabled && scenario.due, scenario.label)
                XCTAssertEqual(value.update, scenario.update, "Due checks must not rewrite imported timestamps")
                XCTAssertEqual(value.autoUpdate, enabled, "Manual subscriptions must remain disabled")
            }
        }
    }

    func testDraftKeepsOriginalBaselineAndLegacyInputCannotCreateANewSave() async throws {
        let service = SubscriptionLifecycleService()
        let domain = "ReaderSubscriptionDraftBaseline-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain); service.release() }
        let state = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
        state.edit(service.subscription)
        state.draft.name = "User retained edit"
        let retained = state.draft
        XCTAssertEqual(retained.baseline, .existing(service.subscription))
        state.editorPresented = false
        let restored = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
        XCTAssertEqual(restored.draft, retained)
        service.rejectSave = true
        restored.actions.pendingChecker = { _ in false }
        restored.saveDraft()
        await waitUntil("A definite baseline conflict settles through the existing action owner", {
            !restored.actions.busy && !restored.actions.hasPending && restored.actions.feedback != nil
        })
        XCTAssertEqual(restored.draft, retained)
        XCTAssertNil(restored.pendingIntent)
        XCTAssertEqual(restored.actions.feedback, ReaderSubscriptionCheckChanged().errorDescription)
        service.rejectSave = false

        // Simulate the old on-disk format by removing only the newly introduced
        // baseline key. It must not silently adopt a current-row snapshot.
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(retained)) as? [String: Any])
        legacy.removeValue(forKey: "baseline")
        let bytes = try JSONSerialization.data(withJSONObject: legacy, options: [.sortedKeys])
        defaults.set(bytes, forKey: "reader.ruleSubscriptions.draft.v1")
        let old = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
        XCTAssertNil(old.draft.baseline)
        old.saveDraft()
        XCTAssertEqual(old.draft.name, retained.name)
        XCTAssertEqual(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"), bytes)
        XCTAssertEqual(old.draftFailure, "旧草稿缺少原订阅基线。请先核对当前订阅并确认，再保存；原输入已保留。")
        XCTAssertNil(old.pendingIntent); XCTAssertNil(old.actions.pendingOperationID)
        XCTAssertTrue(service.writes.isEmpty)

        let newDefaults = try XCTUnwrap(UserDefaults(suiteName: domain + "-new"))
        defer { newDefaults.removePersistentDomain(forName: domain + "-new") }
        let new = ReaderRuleSubscriptionPanelModel(service: service, defaults: newDefaults)
        new.newOrContinueDraft()
        XCTAssertEqual(new.draft.baseline, .absent)
        let reopened = ReaderRuleSubscriptionPanelModel(service: service, defaults: newDefaults)
        XCTAssertEqual(reopened.draft.baseline, .absent)
    }

    func testSaveACKClearsOnlySubmittedDraftAndRetainsRawEditsAndABAOnOriginalRetry() async throws {
        for retry in [false, true] {
            for edit in 0..<3 {
                let service = SubscriptionLifecycleService()
                let domain = "ReaderSubscriptionSaveDraftACK-" + UUID().uuidString
                let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
                defer { defaults.removePersistentDomain(forName: domain); service.release() }
                let state = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
                defer { state.retire() }
                state.activate(); state.edit(service.subscription)
                let submitted = state.draft
                let submittedValue = try submitted.subscription()
                service.holdSaveReplies = !retry
                state.saveDraft()
                await waitUntil("The exact original save entered", {
                    service.writes.count == 1 && (retry ? state.actions.hasPending && !state.actions.busy : service.pendingSaveReplyCount == 1)
                })
                let accepted = try XCTUnwrap(state.pendingIntent)
                XCTAssertEqual(accepted.saveDraft, submitted)
                XCTAssertNotNil(accepted.saveDraftRevision)
                let frozenIntent = try encode(accepted)
                switch edit {
                case 1:
                    state.draft.name = "  " + submitted.name + "  "
                    state.draft.url = "  " + submitted.url + "  "
                    state.draft.order = " 000 "
                case 2:
                    state.draft.name = submitted.name + " changed"
                    state.draft.name = submitted.name
                default: break
                }
                let retained = state.draft
                let retainedBytes = defaults.data(forKey: "reader.ruleSubscriptions.draft.v1")
                XCTAssertEqual(try retained.subscription(), submittedValue, "The DTO alone cannot identify newer raw input or A -> B -> A")
                var retryTask: Task<Bool, Never>?
                if retry {
                    service.holdSaveReplies = true
                    retryTask = Task { await state.actions.resumeOriginal() }
                    await waitUntil("The original owner's retry is awaiting its controlled ACK", { service.pendingSaveReplyCount == 1 })
                }
                let storedIntent = try JSONDecoder().decode(ReaderSubscriptionIntent.self,
                    from: XCTUnwrap(defaults.data(forKey: "reader.ruleSubscriptions.intent.v1")))
                XCTAssertEqual(try encode(storedIntent), frozenIntent)
                try service.completeSaveReply()
                await waitUntil("The successful original save settles its own owner and journal", {
                    !state.actions.busy && !state.actions.hasPending && state.pendingIntent == nil
                })
                if let retryTask {
                    let succeeded = await retryTask.value
                    XCTAssertTrue(succeeded)
                }
                XCTAssertNil(defaults.data(forKey: "reader.ruleSubscriptions.intent.v1"))
                XCTAssertEqual(service.writes.count, retry ? 2 : 1)
                XCTAssertTrue(service.writes.allSatisfy { $0.operationID == accepted.operationID })
                if edit == 0 {
                    XCTAssertFalse(state.draft.isPresent); XCTAssertFalse(state.editorPresented)
                    XCTAssertNil(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"))
                } else {
                    XCTAssertEqual(state.draft, retained); XCTAssertTrue(state.editorPresented)
                    XCTAssertEqual(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"), retainedBytes)
                }
            }
        }
    }

    func testColdSaveACKRetainsChangedRawDraftAndLegacyIntentWithoutSubmittedSnapshot() async throws {
        // One unedited positive control, then raw edits, ABA, rejected identity
        // writes, missing/legacy metadata and an independently changed draft key.
        for boundary in 0..<12 {
            let service = SubscriptionLifecycleService()
            let domain = "ReaderSubscriptionColdSaveDraftACK-" + UUID().uuidString
            let defaults = try XCTUnwrap(SubscriptionDraftDefaults(suiteName: domain))
            defer { defaults.removePersistentDomain(forName: domain); service.release() }
            let original = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
            defaults.dropDraftIdentityWrites = boundary == 3
            original.edit(service.subscription); original.saveDraft()
            await waitUntil("An unknown original save is retained in its Host journal", {
                service.writes.count == 1 && original.actions.hasPending && !original.actions.busy
            })
            let accepted = try XCTUnwrap(original.pendingIntent)
            let originalIdentity = defaults.data(forKey: "reader.ruleSubscriptions.draftIdentity.v1")
            XCTAssertEqual(accepted.saveDraftRevision == nil, boundary == 3)
            switch boundary {
            case 1:
                original.draft.name = "  " + original.draft.name + "  "
                original.draft.order = " 000 "
            case 2, 4:
                defaults.dropDraftIdentityWrites = boundary == 4
                let rejectedWrites = defaults.rejectedDraftIdentityWrites
                let rejectedRemovals = defaults.rejectedDraftIdentityRemovals
                let name = original.draft.name
                original.draft.name = name + " changed"
                original.draft.name = name
                if boundary == 4 {
                    // This fault rejects both replacement and set(nil) used by
                    // removal. The old companion really remains; the new raw
                    // inline generation must prevent its later reuse after ABA.
                    XCTAssertNotNil(originalIdentity)
                    XCTAssertEqual(defaults.rejectedDraftIdentityWrites, rejectedWrites + 2)
                    XCTAssertEqual(defaults.rejectedDraftIdentityRemovals, rejectedRemovals + 2)
                    XCTAssertEqual(defaults.data(forKey: "reader.ruleSubscriptions.draftIdentity.v1"), originalIdentity)
                    let data = try XCTUnwrap(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"))
                    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                    let revision = try XCTUnwrap((object["_readerDraftRevision"] as? String).flatMap(UUID.init(uuidString:)))
                    XCTAssertNotEqual(revision, try XCTUnwrap(accepted.saveDraftRevision))
                }
            case 5:
                var encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(accepted)) as? [String: Any])
                encoded.removeValue(forKey: "saveDraft")
                encoded.removeValue(forKey: "saveDraftRevision")
                defaults.set(try JSONSerialization.data(withJSONObject: encoded), forKey: "reader.ruleSubscriptions.intent.v1")
            case 6:
                defaults.removeObject(forKey: "reader.ruleSubscriptions.draftIdentity.v1")
            case 7, 8, 11:
                var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original.draft)) as? [String: Any])
                if boundary == 7 { raw["name"] = "  " + original.draft.name + "  " }
                else if boundary == 8 { raw.removeValue(forKey: "baseline") }
                // JSONEncoder's original flat draft format has no private
                // inline identity; unchanged legacy input is still unowned.
                defaults.set(try JSONSerialization.data(withJSONObject: raw), forKey: "reader.ruleSubscriptions.draft.v1")
            default: break
            }
            let beforeRecoveryBytes = try XCTUnwrap(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"))
            let beforeRecovery = try JSONDecoder().decode(ReaderSubscriptionDraft.self, from: beforeRecoveryBytes)
            XCTAssertEqual(try beforeRecovery.subscription(), service.subscription)
            original.retire()
            service.holdSaveReplies = true
            let restored = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
            defer { restored.retire() }
            restored.activate()
            await waitUntil("Cold recovery consumes the frozen original save", { service.pendingSaveReplyCount == 1 })
            XCTAssertEqual(restored.pendingIntent?.operationID, accepted.operationID)
            XCTAssertEqual(restored.pendingIntent?.saveDraft, boundary == 5 ? nil : accepted.saveDraft)
            if boundary == 9 {
                var otherDraft = restored.draft
                otherDraft.name = "Another owner's retained input"
                defaults.set(try JSONEncoder().encode(otherDraft), forKey: "reader.ruleSubscriptions.draft.v1")
            } else if boundary == 10 {
                defaults.removeObject(forKey: "reader.ruleSubscriptions.draftIdentity.v1")
            }
            let retainedBytes = try XCTUnwrap(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"))
            let retainedMemory = restored.draft
            try service.completeSaveReply()
            await waitUntil("Cold recovery settles the exact accepted write", {
                !restored.actions.busy && !restored.actions.hasPending && restored.pendingIntent == nil
            })
            if boundary == 0 {
                XCTAssertFalse(restored.draft.isPresent)
                XCTAssertNil(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"))
                XCTAssertNil(defaults.data(forKey: "reader.ruleSubscriptions.draftIdentity.v1"))
            } else {
                XCTAssertEqual(restored.draft, retainedMemory)
                XCTAssertEqual(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"), retainedBytes)
            }
            XCTAssertNil(defaults.data(forKey: "reader.ruleSubscriptions.intent.v1"))
            XCTAssertEqual(service.writes.count, 2)
            XCTAssertTrue(service.writes.allSatisfy { $0.operationID == accepted.operationID })
        }
    }

    func testDeleteACKRetainsDraftAcrossLateReplyOriginalRetryAndColdRecovery() async throws {
        // Controlled typed ACKs exercise only the production Panel's ownership.
        // Saved-row deletion and source retention have separate real Core tests.
        for recovery in 0..<3 {
            for edit in 0..<3 {
                let service = SubscriptionLifecycleService()
                service.allowDelete = true
                service.holdDeleteReplies = recovery == 0
                let domain = "ReaderSubscriptionDeleteDraftACK-" + UUID().uuidString
                let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
                defer { defaults.removePersistentDomain(forName: domain); service.release() }
                let original = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
                defer { original.retire() }
                original.activate(); original.edit(service.subscription)
                // The native UI can retain normalized-equivalent raw input,
                // close the editor and then delete the saved row from its card.
                original.draft.order = " 000 "
                original.editorPresented = false
                original.delete(service.subscription)
                await waitUntil("The exact original delete entered", {
                    service.writes.count == 1 && (recovery == 0 ? service.pendingDeleteReplyCount == 1 : original.actions.hasPending && !original.actions.busy)
                })
                let accepted = try XCTUnwrap(original.pendingIntent)
                switch edit {
                case 1:
                    original.draft.name = "  " + original.draft.name + "  "
                    original.draft.url = "  " + original.draft.url + "  "
                case 2:
                    let name = original.draft.name
                    original.draft.name = name + " changed"
                    original.draft.name = name
                default: break
                }
                let retained = original.draft
                let retainedBytes = defaults.data(forKey: "reader.ruleSubscriptions.draft.v1")
                let retainedIdentity = defaults.data(forKey: "reader.ruleSubscriptions.draftIdentity.v1")
                XCTAssertEqual(try retained.subscription(), service.subscription)
                service.holdDeleteReplies = true
                let target: ReaderRuleSubscriptionPanelModel
                var retryTask: Task<Bool, Never>?
                if recovery == 2 {
                    original.retire()
                    target = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
                    target.activate()
                } else {
                    target = original
                    if recovery == 1 { retryTask = Task { await original.actions.resumeOriginal() } }
                }
                defer { target.retire() }
                await waitUntil("The original delete awaits its controlled reply", { service.pendingDeleteReplyCount == 1 })
                XCTAssertEqual(target.pendingIntent?.operationID, accepted.operationID)
                try service.completeDeleteReply()
                await waitUntil("The original delete ACK settles without claiming the retained draft", {
                    !target.actions.busy && !target.actions.hasPending && target.pendingIntent == nil
                })
                if let retryTask {
                    let succeeded = await retryTask.value
                    XCTAssertTrue(succeeded)
                }
                XCTAssertEqual(target.draft, retained)
                XCTAssertEqual(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"), retainedBytes)
                XCTAssertEqual(defaults.data(forKey: "reader.ruleSubscriptions.draftIdentity.v1"), retainedIdentity)
                XCTAssertNil(defaults.data(forKey: "reader.ruleSubscriptions.intent.v1"))
                XCTAssertEqual(service.writes.count, recovery == 0 ? 1 : 2)
                XCTAssertTrue(service.writes.allSatisfy { $0.operationID == accepted.operationID })
                let deleteBytes = try encode(ReaderSubscriptionMutation.delete(service.subscription))
                for write in service.writes { XCTAssertEqual(try encode(write.mutation), deleteBytes) }

                target.newOrContinueDraft()
                XCTAssertEqual(target.draft, retained)
                target.reviewDraft()
                await waitUntil("Retained input can explicitly review the now-missing original", { target.draftReview != nil })
                let review = try XCTUnwrap(target.draftReview)
                XCTAssertNil(review.current)
                target.confirmDraftReview(review)
                XCTAssertEqual(target.draft, retained)
                XCTAssertEqual(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"), retainedBytes)
                XCTAssertEqual(service.checks, 0)
                XCTAssertEqual(service.writes.count, recovery == 0 ? 1 : 2, "Reviewing a missing original must not recreate it")
            }
        }
    }

    func testLegacyAndConflictedDraftReviewPreservesEveryInputAndRequiresSeparateSave() async throws {
        for legacy in [true, false] {
            let service = SubscriptionLifecycleService()
            let domain = "ReaderSubscriptionExplicitReview-" + UUID().uuidString
            let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
            defer { defaults.removePersistentDomain(forName: domain); service.release() }
            let current = ReaderSourceSubscription(id: service.subscription.id, name: "Current saved name",
                url: service.subscription.url + "?current=1", type: 1, customOrder: 2, autoUpdate: false, update: 7000)
            service.listedSubscriptions = [current]
            let state = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
            defer { state.retire() }
            state.activate(); state.edit(service.subscription)
            state.draft.name = "  Retained raw name  "
            state.draft.url = "  " + service.subscription.url + "?draft=1  "
            state.draft.order = " 007 "
            state.draft.autoUpdate = true
            if legacy { state.draft.baseline = nil }
            await waitUntil("The normal metadata projection is ready", { state.loaded })
            if !legacy {
                state.actions.pendingChecker = { _ in false }
                state.saveDraft()
                await waitUntil("A changed saved configuration preserves its draft and exposes review", {
                    state.draftFailure != nil && !state.actions.busy && !state.actions.hasPending && state.pendingIntent == nil
                })
            }
            let captured = state.draft
            let originalBytes = defaults.data(forKey: "reader.ruleSubscriptions.draft.v1")
            XCTAssertTrue(service.writes.isEmpty)
            let readsBeforeReview = service.listReads
            service.failNextListRead = true
            state.reviewDraft()
            await waitUntil("A failed metadata read releases the explicit retry without replacing its draft", {
                state.draftReviewFailure != nil && !state.reviewingDraft
            })
            XCTAssertEqual(state.draft, captured)
            XCTAssertEqual(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"), originalBytes)
            XCTAssertNil(state.draftReview); XCTAssertTrue(state.canReviewDraft)
            XCTAssertEqual(service.listReads, readsBeforeReview + 1, "A failed review must not automatically retry")
            XCTAssertTrue(service.writes.isEmpty); XCTAssertEqual(service.checks, 0)
            state.reviewDraft()
            await waitUntil("Explicit metadata review returned its current row", { state.draftReview != nil })
            let review = try XCTUnwrap(state.draftReview)
            XCTAssertEqual(service.listReads, readsBeforeReview + 2)
            XCTAssertNil(state.draftReviewFailure)
            XCTAssertEqual(review.current, current); XCTAssertEqual(review.draft, captured)
            XCTAssertEqual(state.draft, captured)
            XCTAssertEqual(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"), originalBytes)
            XCTAssertTrue(service.writes.isEmpty); XCTAssertEqual(service.checks, 0)
            XCTAssertNil(state.pendingIntent); XCTAssertNil(state.actions.pendingOperationID)

            // This is the production native-confirmation callback. Cancelling
            // that alert invokes no callback and leaves this read-only snapshot.
            state.confirmDraftReview(review)
            var expected = captured; expected.baseline = .existing(current)
            XCTAssertEqual(state.draft, expected, "Only baseline metadata may change; raw fields and update survive")
            XCTAssertNil(state.draftReview)
            XCTAssertTrue(service.writes.isEmpty); XCTAssertNil(state.pendingIntent)
            let reopened = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
            XCTAssertEqual(reopened.draft, expected)

            // A user's acknowledgement is only a baseline. A later current-row
            // edit or deletion must still be rejected by a separate Save.
            let later = ReaderSourceSubscription(id: current.id, name: current.name + " changed again",
                url: current.url, type: current.type, customOrder: current.customOrder + 1,
                autoUpdate: current.autoUpdate, update: current.update)
            state.actions.pendingChecker = { _ in false }
            for laterRows in [[later], []] {
                service.listedSubscriptions = laterRows
                let attempts = service.guardedSaveAttempts
                state.saveDraft()
                await waitUntil("Save rejects the changed or deleted row without silently replacing it", {
                    service.guardedSaveAttempts == attempts + 1 && state.pendingIntent == nil
                        && !state.actions.busy && !state.actions.hasPending
                })
                XCTAssertEqual(service.listedSubscriptions, laterRows)
                XCTAssertEqual(state.draft, expected)
                XCTAssertEqual(try JSONDecoder().decode(ReaderSubscriptionDraft.self,
                    from: XCTUnwrap(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"))), expected)
                XCTAssertNotNil(state.draftFailure)
                XCTAssertTrue(service.writes.isEmpty); XCTAssertTrue(service.savedBaselines.isEmpty)
                XCTAssertEqual(service.checks, 0)
            }
            // Restore the controlled current row to the acknowledged snapshot;
            // this does not retry. Only another explicit Save may dispatch.
            service.listedSubscriptions = [current]
            XCTAssertTrue(service.writes.isEmpty)
            state.saveDraft()
            await waitUntil("Only a separate Save dispatches the user's original intent", { service.writes.count == 1 })
            XCTAssertEqual(service.savedBaselines, [.existing(current)])
            XCTAssertEqual(state.draft, expected)
            XCTAssertEqual(service.checks, 0)
        }
    }

    func testDraftReviewRejectsLateReadsAndConfirmationsAfterDraftABAOrPresentationRetirement() async throws {
        for confirmStage in [false, true] {
            // Input ABA, editor close/reopen, background/foreground, panel
            // retire/reactivate, and a separately accepted unresolved operation.
            for boundary in 0..<5 {
                let service = SubscriptionLifecycleService()
                let domain = "ReaderSubscriptionReviewRetirement-" + UUID().uuidString
                let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
                defer { defaults.removePersistentDomain(forName: domain); service.release() }
                let state = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
                defer { state.retire() }
                state.activate(); state.edit(service.subscription); state.draft.baseline = nil
                await waitUntil("The initial panel read completed", { state.loaded && !state.loading })
                service.holdListReads = !confirmStage
                state.reviewDraft()
                var review: ReaderSubscriptionDraftReview?
                if confirmStage {
                    await waitUntil("A comparison is ready for a captured alert callback", { state.draftReview != nil })
                    review = state.draftReview
                } else {
                    await waitUntil("The explicit review is held before publishing", { service.pendingListReadCount == 1 })
                }
                service.holdListReads = false
                switch boundary {
                case 0:
                    let original = state.draft.name
                    state.draft.name = original + " changed"
                    state.draft.name = original
                case 1: state.editorPresented = false; state.editorPresented = true
                case 2: state.setForeground(false); state.setForeground(true)
                case 3: state.retire(); state.activate()
                default:
                    XCTAssertTrue(state.actions.restoreAccepted(id: UUID().uuidString, label: "Unresolved original",
                        scope: "rule-subscriptions/810", action: { id in throw ReaderLibraryError.operationPending(id) }))
                }
                let retained = state.draft
                let bytes = defaults.data(forKey: "reader.ruleSubscriptions.draft.v1")
                if let review {
                    state.confirmDraftReview(review)
                    await waitUntil("The retired confirmation cannot remain actionable", { state.draftReview == nil })
                } else {
                    let unexpected = expectation(description: "Retired metadata cannot publish even if its read completes")
                    unexpected.isInverted = true
                    let observation = state.$draftReview.dropFirst().sink { value in
                        if value != nil { unexpected.fulfill() }
                    }
                    try service.completeListRead(rows: [service.subscription])
                    await fulfillment(of: [unexpected], timeout: 0.1)
                    observation.cancel()
                }
                XCTAssertNil(state.draftReview)
                XCTAssertEqual(state.draft, retained); XCTAssertNil(state.draft.baseline)
                XCTAssertEqual(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"), bytes)
                XCTAssertTrue(service.writes.isEmpty); XCTAssertEqual(service.checks, 0)
            }
        }
    }

    func testDiscardDraftConfirmationRejectsABAAndRetiredEditor() async throws {
        // Exercise the real registered alert callback and persisted draft. A
        // subscription DTO here is controlled metadata, not a remote package.
        for boundary in 0..<10 {
            let service = SubscriptionLifecycleService()
            let domain = "ReaderSubscriptionDiscard-" + UUID().uuidString
            let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
            defer { defaults.removePersistentDomain(forName: domain); service.release() }
            let state = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
            defer { state.retire() }
            state.activate(); state.edit(service.subscription)
            state.draft.name = "User retained input"
            await waitUntil("The initial panel read completed", { state.loaded && !state.loading })
            let confirmation = ReaderNativeAlertOwner()
            confirmation.confirm("放弃这个草稿？", message: "已保存的订阅不受影响。",
                actionTitle: "放弃", destructive: true,
                action: try XCTUnwrap(state.makeDiscardDraftConfirmation()))
            let request = try XCTUnwrap(confirmation.request)
            switch boundary {
            case 0: break // The same live editor may discard its own draft.
            case 1:
                let original = state.draft.name
                state.draft.name = original + " changed"; state.draft.name = original
            case 2: state.draft.name += " changed"
            case 3: state.editorPresented = false; state.editorPresented = true
            case 4: state.setForeground(false); state.setForeground(true)
            case 5: state.retire(); state.activate()
            case 6: state.setForeground(false)
            case 7: state.editorPresented = false
            case 8: state.retire()
            default:
                XCTAssertTrue(state.actions.restoreAccepted(id: UUID().uuidString, label: "Unresolved original",
                    scope: "rule-subscriptions/810", action: { id in throw ReaderLibraryError.operationPending(id) }))
            }
            let retained = state.draft, presented = state.editorPresented
            let bytes = defaults.data(forKey: "reader.ruleSubscriptions.draft.v1")
            let identity = defaults.data(forKey: "reader.ruleSubscriptions.draftIdentity.v1")
            request.action()
            if boundary == 0 {
                XCTAssertFalse(state.draft.isPresent); XCTAssertFalse(state.editorPresented)
                XCTAssertNil(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"))
                XCTAssertNil(defaults.data(forKey: "reader.ruleSubscriptions.draftIdentity.v1"))
            } else {
                XCTAssertEqual(state.draft, retained, "A retired confirmation must not clear current input")
                XCTAssertEqual(state.editorPresented, presented)
                XCTAssertEqual(defaults.data(forKey: "reader.ruleSubscriptions.draft.v1"), bytes)
                XCTAssertEqual(defaults.data(forKey: "reader.ruleSubscriptions.draftIdentity.v1"), identity)
                let restored = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
                XCTAssertEqual(restored.draft, retained, "Rejected stale confirmation preserves cold restoration")
            }
            XCTAssertTrue(service.writes.isEmpty); XCTAssertEqual(service.checks, 0)
            XCTAssertNil(state.pendingIntent)
        }
    }

    func testMissingOriginalReviewCannotResurrectSubscriptionAndNewDraftDoesNotReview() async throws {
        let service = SubscriptionLifecycleService()
        let domain = "ReaderSubscriptionMissingReview-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain); service.release() }
        service.listedSubscriptions = []
        let state = ReaderRuleSubscriptionPanelModel(service: service, defaults: defaults)
        defer { state.retire() }
        state.activate(); state.edit(service.subscription); state.draft.baseline = nil
        await waitUntil("The absent row is projected", { state.loaded })
        let captured = state.draft
        state.reviewDraft()
        await waitUntil("The explicit absent-row result is ready", { state.draftReview != nil })
        let review = try XCTUnwrap(state.draftReview)
        XCTAssertNil(review.current)
        state.confirmDraftReview(review)
        XCTAssertEqual(state.draft, captured); XCTAssertNil(state.draft.baseline)
        XCTAssertTrue(service.writes.isEmpty); XCTAssertNil(state.pendingIntent)
        try XCTUnwrap(state.makeDiscardDraftConfirmation())()
        state.newOrContinueDraft()
        XCTAssertEqual(state.draft.baseline, .absent)
        XCTAssertFalse(state.supportsDraftReview); XCTAssertFalse(state.canReviewDraft)
        let reads = service.listReads
        state.reviewDraft()
        XCTAssertEqual(service.listReads, reads)
        XCTAssertNil(state.draftReview)
        XCTAssertTrue(service.writes.isEmpty); XCTAssertEqual(service.checks, 0)
    }

    /// Controlled subscription metadata exercises the real pinned Core's row
    /// and lineage boundary. No provider is fetched or source package created.
    func testGuardedSavePreservesCurrentUpdateAndRejectsChangedBaselineConfiguration() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderSubscriptionSaveBaseline-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        let original = SubscriptionLifecycleService().subscription
        func value(_ field: Int, update: Int64 = 4000) -> ReaderSourceSubscription {
            .init(id: original.id, name: field == 0 ? "Other name" : original.name,
                url: field == 1 ? original.url + "?changed=1" : original.url,
                type: field == 2 ? 1 : original.type, customOrder: field == 3 ? 1 : original.customOrder,
                autoUpdate: field == 4 ? !original.autoUpdate : original.autoUpdate, update: update)
        }
        do {
            for field in 0..<5 {
                let current = value(field)
                _ = try await service.saveRuleSubscription(current, operationID: UUID().uuidString)
                let rejectedID = UUID().uuidString
                do {
                    _ = try await service.saveRuleSubscription(original, baseline: .existing(original), operationID: rejectedID)
                    XCTFail("A stale original configuration must not replace the current row")
                } catch is ReaderSubscriptionCheckChanged { }
                let rows = try await service.ruleSubscriptions()
                XCTAssertEqual(rows, [current])
                let record = try await service.existingCoreParameters(operationID: rejectedID, method: "rules.mutation.apply")
                XCTAssertNil(record, "A baseline conflict is rejected before allocating a Core write")
            }
            let current = value(-1)
            _ = try await service.saveRuleSubscription(current, operationID: UUID().uuidString)
            let desired = ReaderSourceSubscription(id: original.id, name: "Retained user name", url: original.url,
                type: original.type, customOrder: 7, autoUpdate: false, update: original.update)
            let saved = try await service.saveRuleSubscription(desired, baseline: .existing(original), operationID: UUID().uuidString)
            XCTAssertTrue(saved.hasSameConfiguration(as: desired))
            XCTAssertEqual(saved.update, current.update, "A retained draft cannot roll back Core's newer update clock")

            let missingOrAbsent: [ReaderSubscriptionBaseline?] = [.absent, nil]
            for baseline in missingOrAbsent {
                do {
                    _ = try await service.saveRuleSubscription(desired, baseline: baseline, operationID: UUID().uuidString)
                    XCTFail("An existing row cannot be treated as new or silently adopt a missing baseline")
                } catch is ReaderSubscriptionCheckChanged { }
            }
            let fresh = ReaderSourceSubscription(id: original.id + 1, name: original.name, url: original.url,
                type: 0, customOrder: 0, autoUpdate: false, update: 9000)
            let added = try await service.saveRuleSubscription(fresh, baseline: .absent, operationID: UUID().uuidString)
            XCTAssertEqual(added.update, 0, "A new editor cannot invent an acknowledged update timestamp")
            try await service.close()
        } catch { try? await service.close(); throw error }
    }

    func testCapturedSaveSequenceRejectsInterveningConfigurationAndABAWithoutReplacingCurrentRow() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderSubscriptionSaveSequence-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        let original = SubscriptionLifecycleService().subscription
        let changed = ReaderSourceSubscription(id: original.id, name: original.name, url: original.url + "?new=1",
            type: original.type, customOrder: original.customOrder, autoUpdate: original.autoUpdate, update: 5000)
        let desired = ReaderSourceSubscription(id: original.id, name: "Draft name", url: original.url,
            type: original.type, customOrder: original.customOrder, autoUpdate: original.autoUpdate, update: 0)
        do {
            for aba in [false, true] {
                _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString)
                let prepared = try await service.prepareRuleSubscriptionSave(desired, baseline: .existing(original))
                _ = try await service.saveRuleSubscription(changed, operationID: UUID().uuidString)
                if aba { _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString) }
                let parameters = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(prepared.subscription)) as? [String: Any])
                do {
                    // This is the production dispatch boundary after its final
                    // awaited head read. The captured sequence must not rebase.
                    _ = try await service.rulesMutation("rule-sub.put", parameters,
                        operationID: UUID().uuidString, nextSequence: prepared.nextSequence)
                    XCTFail("Core must reject an intervening write, including A -> B -> A")
                } catch ReaderLibraryError.core(let code, _, _, let reason) {
                    XCTAssertEqual(code, "INVALID_PARAMS"); XCTAssertEqual(reason, "rules_mutation_rejected")
                }
                let rows = try await service.ruleSubscriptions()
                XCTAssertEqual(rows, [aba ? original : changed])
                let pending = try await service.pendingCoreCommands()
                XCTAssertTrue(pending.isEmpty)
            }
            try await service.close()
        } catch { try? await service.close(); throw error }
    }

    func testColdAcceptedSaveReusesOriginalWrapperAndUpdateWithoutBaselineReadOrRedispatch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderSubscriptionSaveReplay-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = root.appendingPathComponent("Core"), sources = root.appendingPathComponent("Sources")
        var gate = try StagingCoreGate(storage: storage)
        defer { gate.release(); gate.destroy() }
        var service = try ReaderLibraryService(storageURL: storage, sourceURL: sources, client: gate, timing: gate.timing)
        let original = SubscriptionLifecycleService().subscription
        let current = ReaderSourceSubscription(id: original.id, name: original.name, url: original.url,
            type: original.type, customOrder: original.customOrder, autoUpdate: original.autoUpdate, update: 6000)
        let desired = ReaderSourceSubscription(id: original.id, name: "Accepted user edit", url: original.url,
            type: original.type, customOrder: original.customOrder, autoUpdate: original.autoUpdate, update: 0)
        let operationID = UUID().uuidString
        _ = try await service.saveRuleSubscription(current, operationID: UUID().uuidString)
        gate.hold("rules.mutation.apply", advanceObserverDeadline: true)
        do {
            _ = try await service.saveRuleSubscription(desired, baseline: .existing(original), operationID: operationID)
            XCTFail("The real original Core terminal is held")
        } catch ReaderLibraryError.operationPending(_) { }
        let originalParameters = try await service.existingCoreParameters(operationID: operationID, method: "rules.mutation.apply")
        let frozen = try XCTUnwrap(originalParameters)
        let bytes = try JSONSerialization.data(withJSONObject: frozen, options: [.sortedKeys])
        gate.destroy()
        gate = try StagingCoreGate(storage: storage)
        service = try ReaderLibraryService(storageURL: storage, sourceURL: sources, client: gate, timing: gate.timing)
        do {
            // An accepted legacy Host intent may lack baseline metadata. Only
            // its exact pre-existing journal is eligible for this recovery.
            let recovered = try await service.saveRuleSubscription(desired, baseline: nil, operationID: operationID)
            XCTAssertTrue(recovered.hasSameConfiguration(as: desired)); XCTAssertEqual(recovered.update, current.update)
            XCTAssertEqual(gate.count("rule-sub.list"), 0, "Accepted retry must not fetch a new row or rebase its parameters")
            XCTAssertEqual(gate.count("rules.mutation.apply"), 0, "Consume the original receipt without another write")
            let retainedParameters = try await service.existingCoreParameters(operationID: operationID, method: "rules.mutation.apply")
            let retained = try XCTUnwrap(retainedParameters)
            XCTAssertEqual(try JSONSerialization.data(withJSONObject: retained, options: [.sortedKeys]), bytes)
            let pending = try await service.pendingCoreCommands()
            XCTAssertTrue(pending.isEmpty)
            try await service.close()
        } catch { try? await service.close(); throw error }
    }

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
        // The action often settled on the current or next main-actor turn.
        // Check that directly before XCTest's slower predicate polling; keep
        // the existing bounded waiter for real asynchronous work.
        if predicate() { return }
        for _ in 0..<16 {
            await Task.yield()
            if predicate() { return }
        }
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

/// Controlled pending-request copies exercise scheduling policy only. These
/// methods never register with BGTaskScheduler or launch a background task.
@MainActor
final class ReaderRuleSubscriptionSchedulingTests: XCTestCase {
    func testExistingEarlierOrUndelayedRequestSurvivesRepeatedForegroundScheduling() async throws {
        let origin = Date(timeIntervalSince1970: 1_000_000)
        for date in [nil, origin.addingTimeInterval(-1), origin.addingTimeInterval(12 * 60 * 60),
                     origin.addingTimeInterval(24 * 60 * 60)] as [Date?] {
            let queue = SubscriptionSchedulingQueue()
            let original = BGAppRefreshTaskRequest(identifier: ReaderRuleSubscriptionScheduler.identifier)
            original.earliestBeginDate = date
            queue.pending = [original]
            var current = origin
            let scheduler = ReaderRuleSubscriptionScheduler(checkDue: {
                XCTFail("Scheduling must not check or apply subscriptions"); return []
            }, scheduling: queue, now: { current })
            scheduler.register()
            let revision = scheduler.completedOpportunityRevision
            let first = try XCTUnwrap(scheduler.requestNextOpportunity())
            await first.value
            current = origin.addingTimeInterval(6 * 60 * 60)
            let second = try XCTUnwrap(scheduler.requestNextOpportunity())
            await second.value
            XCTAssertEqual(queue.lookups, 2)
            XCTAssertTrue(queue.submitted.isEmpty, "A later foreground visit cannot postpone the existing request")
            XCTAssertEqual(queue.pending.first?.earliestBeginDate, date)
            XCTAssertEqual(scheduler.completedOpportunityRevision, revision)
        }
    }

    func testMissingOrLaterMatchingRequestGetsOneEarlierRefreshRequest() async throws {
        let origin = Date(timeIntervalSince1970: 1_000_000)
        let later = BGAppRefreshTaskRequest(identifier: ReaderRuleSubscriptionScheduler.identifier)
        later.earliestBeginDate = origin.addingTimeInterval(48 * 60 * 60)
        let unrelated = BGAppRefreshTaskRequest(identifier: "other-owner")
        let wrongType = BGProcessingTaskRequest(identifier: ReaderRuleSubscriptionScheduler.identifier)
        for pending in [[], [later], [unrelated], [wrongType]] as [[BGTaskRequest]] {
            let queue = SubscriptionSchedulingQueue()
            queue.pending = pending
            let scheduler = ReaderRuleSubscriptionScheduler(checkDue: {
                XCTFail("Scheduling must not check or apply subscriptions"); return []
            }, scheduling: queue, now: { origin })
            scheduler.register()
            let flight = try XCTUnwrap(scheduler.requestNextOpportunity())
            await flight.value
            XCTAssertEqual(queue.submitted.count, 1)
            let submitted = try XCTUnwrap(queue.submitted.first)
            XCTAssertEqual(submitted.identifier, ReaderRuleSubscriptionScheduler.identifier)
            XCTAssertEqual(submitted.earliestBeginDate, origin.addingTimeInterval(24 * 60 * 60))
            if pending.contains(where: { $0.identifier == unrelated.identifier }) {
                XCTAssertTrue(queue.pending.contains(where: { $0.identifier == unrelated.identifier }))
            }
        }
    }

    func testOverlappingRequestsShareLookupAndSubmissionThenKeepOriginalDate() async throws {
        let origin = Date(timeIntervalSince1970: 1_000_000)
        var current = origin
        let queue = SubscriptionSchedulingQueue()
        queue.suspendLookup = true
        queue.suspendSubmission = true
        let entered = expectation(description: "Pending lookup suspended before submission")
        let submitting = expectation(description: "Submission suspended until its completion")
        queue.onLookup = { entered.fulfill() }
        queue.onSubmission = { submitting.fulfill() }
        let scheduler = ReaderRuleSubscriptionScheduler(checkDue: {
            XCTFail("Scheduling must not check or apply subscriptions"); return []
        }, scheduling: queue, now: { current })
        scheduler.register()
        let first = try XCTUnwrap(scheduler.requestNextOpportunity())
        await fulfillment(of: [entered], timeout: 2)
        current = origin.addingTimeInterval(6 * 60 * 60)
        let joined = try XCTUnwrap(scheduler.requestNextOpportunity())
        XCTAssertEqual(queue.lookups, 1)
        XCTAssertTrue(queue.submitted.isEmpty)
        queue.onLookup = nil
        queue.releaseLookup()
        await fulfillment(of: [submitting], timeout: 2)
        let joinedDuringSubmit = try XCTUnwrap(scheduler.requestNextOpportunity())
        XCTAssertEqual(queue.lookups, 1, "A pending submission remains part of the same scheduling flight")
        XCTAssertEqual(queue.submitted.count, 1)
        queue.onSubmission = nil
        queue.releaseSubmission()
        await first.value
        await joined.value
        await joinedDuringSubmit.value
        XCTAssertEqual(queue.submitted.count, 1, "Overlapping callers cannot both replace the pending request")
        XCTAssertEqual(queue.submitted.first?.earliestBeginDate, origin.addingTimeInterval(24 * 60 * 60))
        let later = try XCTUnwrap(scheduler.requestNextOpportunity())
        await later.value
        XCTAssertEqual(queue.lookups, 2)
        XCTAssertEqual(queue.submitted.count, 1)
    }

    func testRejectedSubmissionReleasesSchedulingFlightWithoutAutomaticRetry() async throws {
        let queue = SubscriptionSchedulingQueue()
        let scheduler = ReaderRuleSubscriptionScheduler(checkDue: {
            XCTFail("Scheduling must not check or apply subscriptions"); return []
        }, scheduling: queue)
        XCTAssertNil(scheduler.requestNextOpportunity(), "Unregistered schedulers cannot submit requests")
        XCTAssertEqual(queue.lookups, 0)
        scheduler.register()
        let revision = scheduler.completedOpportunityRevision
        queue.rejectSubmission = true
        let first = try XCTUnwrap(scheduler.requestNextOpportunity())
        await first.value
        XCTAssertEqual(queue.submitted.count, 1)
        XCTAssertTrue(queue.pending.isEmpty)
        XCTAssertEqual(scheduler.completedOpportunityRevision, revision)
        queue.rejectSubmission = false
        let explicitLaterRequest = try XCTUnwrap(scheduler.requestNextOpportunity())
        await explicitLaterRequest.value
        XCTAssertEqual(queue.lookups, 2)
        XCTAssertEqual(queue.submitted.count, 2)
        XCTAssertEqual(queue.pending.count, 1)
        XCTAssertEqual(scheduler.completedOpportunityRevision, revision)
    }
}

@MainActor
private final class SubscriptionSchedulingQueue: ReaderRuleSubscriptionScheduling {
    enum Failure: Error { case submissionRejected }
    var pending: [BGTaskRequest] = []
    var suspendLookup = false
    var suspendSubmission = false
    var rejectSubmission = false
    var onLookup: (() -> Void)?
    var onSubmission: (() -> Void)?
    private(set) var lookups = 0
    private(set) var submitted: [BGAppRefreshTaskRequest] = []
    private var continuation: CheckedContinuation<[BGTaskRequest], Never>?
    private var submissionContinuation: CheckedContinuation<Void, Never>?

    func register(identifier: String, launchHandler: @escaping (BGTask) -> Void) -> Bool {
        XCTAssertEqual(identifier, ReaderRuleSubscriptionScheduler.identifier)
        // The launch handler is deliberately never invoked by these methods.
        return true
    }
    func pendingRequests() async -> [BGTaskRequest] {
        lookups += 1
        if suspendLookup {
            return await withCheckedContinuation { continuation in
                self.continuation = continuation
                onLookup?()
            }
        }
        onLookup?()
        return pending
    }
    func releaseLookup() {
        suspendLookup = false
        let waiting = continuation; continuation = nil
        waiting?.resume(returning: pending)
    }
    func releaseSubmission() {
        suspendSubmission = false
        let waiting = submissionContinuation; submissionContinuation = nil
        waiting?.resume()
    }
    func submit(_ request: BGAppRefreshTaskRequest) async throws {
        submitted.append(request)
        if suspendSubmission {
            await withCheckedContinuation { continuation in
                submissionContinuation = continuation
                onSubmission?()
            }
        } else { onSubmission?() }
        if rejectSubmission { throw Failure.submissionRejected }
        pending.removeAll { $0.identifier == request.identifier }
        pending.append(request)
    }
}

private final class SubscriptionDraftDefaults: UserDefaults, @unchecked Sendable {
    var dropDraftIdentityWrites = false
    private(set) var rejectedDraftIdentityWrites = 0
    private(set) var rejectedDraftIdentityRemovals = 0
    override func set(_ value: Any?, forKey defaultName: String) {
        if dropDraftIdentityWrites, defaultName == "reader.ruleSubscriptions.draftIdentity.v1" {
            rejectedDraftIdentityWrites += 1; return
        }
        super.set(value, forKey: defaultName)
    }
    override func removeObject(forKey defaultName: String) {
        // Refuse deletion explicitly, independently of Foundation routing its
        // implementation through set(nil). This is the exact failure boundary.
        if dropDraftIdentityWrites, defaultName == "reader.ruleSubscriptions.draftIdentity.v1" {
            rejectedDraftIdentityRemovals += 1; return
        }
        super.removeObject(forKey: defaultName)
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
    private(set) var savedBaselines: [ReaderSubscriptionBaseline?] = []
    private(set) var guardedSaveAttempts = 0
    var listedSubscriptions: [ReaderSourceSubscription]?
    var holdListReads = false
    var failNextListRead = false
    private var pendingListReads: [CheckedContinuation<[ReaderSourceSubscription], Error>] = []
    var pendingListReadCount: Int { pendingListReads.count }
    var rejectApply = false
    var rejectSave = false
    var holdSaveReplies = false
    private var pendingSaveReplies: [(ReaderSourceSubscription, CheckedContinuation<ReaderSourceSubscription, Error>)] = []
    var pendingSaveReplyCount: Int { pendingSaveReplies.count }
    var allowDelete = false
    var holdDeleteReplies = false
    private var pendingDeleteReplies: [CheckedContinuation<Void, Error>] = []
    var pendingDeleteReplyCount: Int { pendingDeleteReplies.count }
    private var pending: [Int: CheckedContinuation<ReaderSubscriptionPlan, Error>] = [:]
    func plan(_ nonce: String) -> ReaderSubscriptionPlan {
        .init(planId: "host-plan-" + nonce, subscriptionId: subscription.id, remoteDigest: String(repeating: "0", count: 64),
            expiresAt: Int64(Date().timeIntervalSince1970 * 1000) + 900_000,
            changes: [.init(sourceId: "host-change-a", name: "Host A", kind: "added"),
                      .init(sourceId: "host-change-b", name: "Host B", kind: "update")])
    }
    func ruleSubscriptions() async throws -> [ReaderSourceSubscription] {
        listReads += 1
        if failNextListRead { failNextListRead = false; throw Failure.forbidden }
        if holdListReads {
            return try await withCheckedThrowingContinuation { pendingListReads.append($0) }
        }
        return listedSubscriptions ?? [subscription]
    }
    func completeListRead(rows: [ReaderSourceSubscription]) throws {
        guard !pendingListReads.isEmpty else { throw Failure.missingContinuation }
        pendingListReads.removeFirst().resume(returning: rows)
    }
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
        if holdSaveReplies {
            return try await withCheckedThrowingContinuation { pendingSaveReplies.append((subscription, $0)) }
        }
        throw ReaderLibraryError.operationPending(operationID)
    }
    func completeSaveReply() throws {
        guard !pendingSaveReplies.isEmpty else { throw Failure.missingContinuation }
        let (subscription, continuation) = pendingSaveReplies.removeFirst()
        continuation.resume(returning: subscription)
    }
    func saveRuleSubscription(_ subscription: ReaderSourceSubscription, baseline: ReaderSubscriptionBaseline?, operationID: String) async throws -> ReaderSourceSubscription {
        guardedSaveAttempts += 1
        let current = (listedSubscriptions ?? [self.subscription]).first { $0.id == subscription.id }
        guard let baseline, baseline == current.map(ReaderSubscriptionBaseline.existing) || baseline == .absent else { throw ReaderSubscriptionCheckChanged() }
        if rejectSave { throw ReaderSubscriptionCheckChanged() }
        savedBaselines.append(baseline)
        return try await saveRuleSubscription(subscription, operationID: operationID)
    }
    func deleteRuleSubscription(_ subscription: ReaderSourceSubscription, operationID: String) async throws {
        guard allowDelete else { XCTFail("Read lifetime must not delete subscriptions"); throw Failure.forbidden }
        writes.append(.init(operationID: operationID, mutation: .delete(subscription)))
        if holdDeleteReplies {
            return try await withCheckedThrowingContinuation { pendingDeleteReplies.append($0) }
        }
        throw ReaderLibraryError.operationPending(operationID)
    }
    func completeDeleteReply() throws {
        guard !pendingDeleteReplies.isEmpty else { throw Failure.missingContinuation }
        listedSubscriptions = []
        pendingDeleteReplies.removeFirst().resume(returning: ())
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
    func release() {
        let values = Array(pending.values); pending.removeAll(); values.forEach { $0.resume(throwing: Failure.teardown) }
        let reads = pendingListReads; pendingListReads.removeAll(); reads.forEach { $0.resume(throwing: Failure.teardown) }
        let saves = pendingSaveReplies; pendingSaveReplies.removeAll(); saves.forEach { $0.1.resume(throwing: Failure.teardown) }
        let deletes = pendingDeleteReplies; pendingDeleteReplies.removeAll(); deletes.forEach { $0.resume(throwing: Failure.teardown) }
    }
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
