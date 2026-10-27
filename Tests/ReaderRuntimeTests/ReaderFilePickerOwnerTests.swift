import Foundation
import XCTest
@testable import Reader

@MainActor
final class ReaderFilePickerOwnerTests: XCTestCase {
    private let first = URL(fileURLWithPath: "/selection/first.txt")
    private let second = URL(fileURLWithPath: "/selection/second.txt")

    func testSelectionThenDismissDeliversExactlyOneReadyURL() async {
        let owner = ReaderFilePickerOwner()
        let id = owner.begin()
        XCTAssertTrue(owner.presented.wrappedValue)
        XCTAssertNil(owner.select(first, operationID: id))
        XCTAssertFalse(owner.presented.wrappedValue)
        XCTAssertEqual(owner.didDismiss(), first)
        XCTAssertNil(owner.operationID)
        XCTAssertNil(owner.didDismiss(operationID: id))
        XCTAssertNil(owner.select(first, operationID: id))
    }

    func testDismissThenSelectionDeliversTheLateDelegateURLExactlyOnce() async {
        let owner = ReaderFilePickerOwner()
        let id = owner.begin()
        XCTAssertNil(owner.didDismiss())
        XCTAssertFalse(owner.isPresented)
        XCTAssertEqual(owner.operationID, id, "Dismissal must retain ownership until selection or cancellation arrives")
        XCTAssertNil(owner.didDismiss(operationID: id), "A duplicate dismissal cannot consume the still-awaited selection")
        XCTAssertEqual(owner.select(first, operationID: id), first)
        XCTAssertNil(owner.select(first, operationID: id))
        XCTAssertNil(owner.didDismiss())
    }

    func testSystemBindingCloseDoesNotCancelASelectionWhoseDelegateHasNotArrived() async {
        let owner = ReaderFilePickerOwner()
        let id = owner.begin()
        owner.presented.wrappedValue = false
        XCTAssertNil(owner.didDismiss())
        XCTAssertEqual(owner.operationID, id)
        XCTAssertEqual(owner.select(first, operationID: id), first)
    }

    func testDuplicateSelectionCannotReplaceTheOriginalIntentBeforeDismissal() async {
        let owner = ReaderFilePickerOwner()
        let id = owner.begin()
        XCTAssertNil(owner.select(first, operationID: id))
        XCTAssertNil(owner.select(second, operationID: id))
        XCTAssertEqual(owner.didDismiss(operationID: id), first)
        XCTAssertNil(owner.didDismiss(operationID: id))
    }

    func testCancelAfterSelectionPreventsDeliveryAndOldCallbacksCannotAffectTheNextPicker() async {
        let owner = ReaderFilePickerOwner()
        let old = owner.begin()
        XCTAssertNil(owner.select(first, operationID: old))
        owner.cancel(operationID: old)
        let current = owner.begin()
        XCTAssertNotEqual(current, old)
        XCTAssertNil(owner.didDismiss(), "The older closing identity must not dismiss the new presentation")
        XCTAssertTrue(owner.isPresented)
        XCTAssertEqual(owner.operationID, current)
        XCTAssertNil(owner.select(first, operationID: old))
        owner.cancel(operationID: old)
        XCTAssertEqual(owner.operationID, current)
        XCTAssertNil(owner.select(second, operationID: current))
        XCTAssertEqual(owner.didDismiss(operationID: current), second)
    }

    func testCancelAfterDismissPreventsLateSelectionFromStartingAnImport() async {
        let owner = ReaderFilePickerOwner()
        let old = owner.begin()
        XCTAssertNil(owner.didDismiss(operationID: old))
        owner.cancel(operationID: old)
        let current = owner.begin()
        XCTAssertNil(owner.select(first, operationID: old))
        XCTAssertNil(owner.didDismiss(operationID: old))
        owner.cancel(operationID: old)
        XCTAssertTrue(owner.isPresented)
        XCTAssertEqual(owner.operationID, current)
        XCTAssertNil(owner.didDismiss(operationID: current))
        XCTAssertEqual(owner.select(second, operationID: current), second)
    }

    func testNewExplicitRequestSupersedesAnOldDismissedOperationAwaitingSelection() async {
        let owner = ReaderFilePickerOwner()
        let old = owner.begin()
        XCTAssertNil(owner.didDismiss(operationID: old))
        let current = owner.begin()
        XCTAssertNotEqual(current, old)
        XCTAssertNil(owner.select(first, operationID: old))
        XCTAssertNil(owner.select(second, operationID: current))
        XCTAssertEqual(owner.didDismiss(), second)
    }

    func testRepeatedBeginDuringPresentationKeepsTheAlreadyCreatedDelegateIdentity() async {
        let owner = ReaderFilePickerOwner()
        let id = owner.begin()
        XCTAssertEqual(owner.begin(), id)
        XCTAssertNil(owner.select(first, operationID: id))
        XCTAssertEqual(owner.didDismiss(), first)
    }
}

@MainActor
final class ReaderDownloadReadOwnerTests: XCTestCase {
    private struct Projection: Equatable {
        let status: UUID
        let storage: UUID?
    }
    private enum ReadFailure: String, LocalizedError {
        case old, current, storage
        var errorDescription: String? { rawValue }
    }
    @MainActor private final class HeldRead {
        let entered = XCTestExpectation(description: "read reached controlled completion boundary")
        private var continuation: CheckedContinuation<Void, Never>?
        private var released = false

        func hold() async {
            guard !released else { return }
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                entered.fulfill()
            }
        }
        func release() {
            released = true
            let pending = continuation; continuation = nil
            pending?.resume()
        }
    }

    /// Inventory is a separate presentation read. A delayed inventory result
    /// may enrich only the latest same-entity status, and retirement drops it.
    func testSlowInventoryDoesNotBlockStatusOrReviveRetiredProjection() async throws {
        let owner = ReaderDownloadReadOwner<UUID, Projection>()
        let entity = UUID(), replacement = UUID()
        let initial = Projection(status: UUID(), storage: nil)
        let newer = Projection(status: UUID(), storage: nil)
        let inventory = UUID()
        let replacementValue = Projection(status: UUID(), storage: nil)
        let slow = HeldRead(), retired = HeldRead()
        defer { slow.release(); retired.release() }

        owner.activate(identity: entity)
        let first = try XCTUnwrap(owner.invalidate(identity: entity) { publish in publish(initial) })
        await first.value
        let slowInventory = try XCTUnwrap(owner.invalidateSupplement(identity: entity) {
            await slow.hold()
            return { current in Projection(status: current.status, storage: inventory) }
        })
        await fulfillment(of: [slow.entered], timeout: 3)
        let freshStatus = try XCTUnwrap(owner.invalidate(identity: entity) { publish in publish(newer) })
        await freshStatus.value
        XCTAssertEqual(owner.value, newer, "The primary status read must finish while inventory is held")
        slow.release()
        await slowInventory.value
        XCTAssertEqual(owner.value, Projection(status: newer.status, storage: inventory),
                       "Inventory merges into the latest status rather than replaying the earlier one")

        var staleFollowupCount = 0
        let retiringInventory = try XCTUnwrap(owner.invalidateSupplement(identity: entity) {
            await retired.hold()
            return { current in Projection(status: current.status, storage: UUID()) }
        })
        await fulfillment(of: [retired.entered], timeout: 3)
        XCTAssertNotNil(owner.invalidateSupplement(identity: entity) {
            staleFollowupCount += 1
            return { current in current }
        })
        owner.retire()
        owner.activate(identity: replacement)
        let replacementStatus = try XCTUnwrap(owner.invalidate(identity: replacement) { publish in
            publish(replacementValue)
        })
        await replacementStatus.value
        retired.release()
        await retiringInventory.value
        XCTAssertEqual(staleFollowupCount, 0)
        XCTAssertEqual(owner.identity, replacement)
        XCTAssertEqual(owner.value, replacementValue)
        XCTAssertNil(owner.failure)
    }

    /// Production presentation scheduling only. UUIDs mark publications; this
    /// creates no source, book, HTTP response, Core ACK or download task state.
    func testBurstInvalidationsDrainOneLatestReadAndRetirementRejectsOldEntityWork() async throws {
        let owner = ReaderDownloadReadOwner<UUID, Projection>()
        let entity = UUID(), replacement = UUID()
        let first = Projection(status: UUID(), storage: nil)
        let latest = Projection(status: UUID(), storage: UUID())
        let stale = Projection(status: UUID(), storage: UUID())
        let replacementPartial = Projection(status: UUID(), storage: nil)
        let replacementComplete = Projection(status: replacementPartial.status, storage: UUID())
        let active = HeldRead(), retiring = HeldRead(), current = HeldRead()
        defer { active.release(); retiring.release(); current.release() }
        var started: [Int] = []
        var activeWasCancelled = false

        owner.activate(identity: entity)
        let burst = try XCTUnwrap(owner.invalidate(identity: entity) { publish in
            started.append(0)
            await active.hold()
            activeWasCancelled = Task.isCancelled
            publish(first)
        })
        await fulfillment(of: [active.entered], timeout: 3)
        for marker in 1...20 {
            XCTAssertNotNil(owner.invalidate(identity: entity) { publish in
                started.append(marker)
                publish(latest)
            })
        }
        XCTAssertEqual(started, [0], "Hints cannot start another read while the original read is active")
        XCTAssertTrue(owner.loading)
        active.release()
        await burst.value
        XCTAssertFalse(activeWasCancelled, "A burst must preserve its in-flight read")
        XCTAssertEqual(started, [0, 20], "Only the latest invalidation gets one trailing read")
        XCTAssertEqual(owner.value, latest)
        XCTAssertFalse(owner.loading)
        XCTAssertNil(owner.failure)

        var retiredFollowupCount = 0
        let old = try XCTUnwrap(owner.invalidate(identity: entity) { publish in
            await retiring.hold()
            publish(stale)
            throw ReadFailure.old
        })
        await fulfillment(of: [retiring.entered], timeout: 3)
        XCTAssertNotNil(owner.invalidate(identity: entity) { _ in retiredFollowupCount += 1 })
        owner.retire()
        XCTAssertNil(owner.invalidate(identity: entity) { _ in retiredFollowupCount += 1 })
        owner.activate(identity: replacement)
        XCTAssertNil(owner.value)
        XCTAssertNil(owner.invalidate(identity: entity) { _ in retiredFollowupCount += 1 })
        let new = try XCTUnwrap(owner.invalidate(identity: replacement) { publish in
            publish(replacementPartial)
            await current.hold()
            publish(replacementComplete)
        })
        await fulfillment(of: [current.entered], timeout: 3)
        retiring.release()
        await old.value
        XCTAssertEqual(retiredFollowupCount, 0, "Retirement discards queued work for the old entity")
        XCTAssertEqual(owner.identity, replacement)
        XCTAssertEqual(owner.value, replacementPartial)
        XCTAssertNil(owner.failure, "A late old error cannot replace the current read")
        XCTAssertTrue(owner.loading, "Old cleanup cannot end the replacement read")
        current.release()
        await new.value
        XCTAssertEqual(owner.value, replacementComplete)
        XCTAssertFalse(owner.loading)
    }

    /// Pure presentation scheduling: UUIDs mark publications, not books,
    /// sources, Core ACKs, network responses or download task states.
    func testCurrentGenerationOwnsPartialResultsErrorsAndRetirementWithoutRevivingOldEntity() async throws {
        let owner = ReaderDownloadReadOwner<UUID, Projection>()
        let entity = UUID(), replacement = UUID()
        let first = Projection(status: UUID(), storage: nil)
        let complete = Projection(status: first.status, storage: UUID())
        let stale = Projection(status: UUID(), storage: UUID())
        let old = HeldRead(), storage = HeldRead()
        defer { old.release(); storage.release() }
        owner.activate(identity: entity)
        let oldTask = try XCTUnwrap(owner.refresh(identity: entity) { publish in
            await old.hold()
            publish(stale)
            throw ReadFailure.old
        })
        await fulfillment(of: [old.entered], timeout: 3)
        let currentTask = try XCTUnwrap(owner.refresh(identity: entity) { publish in
            publish(first)
            await storage.hold()
            publish(complete)
        })
        await fulfillment(of: [storage.entered], timeout: 3)
        XCTAssertEqual(owner.value, first, "Status is usable before storage finishes")
        XCTAssertTrue(owner.loading)
        old.release(); await oldTask.value
        XCTAssertEqual(owner.value, first, "An older success cannot replace the current partial status")
        XCTAssertNil(owner.failure, "An older error cannot replace the current request")
        XCTAssertTrue(owner.loading, "Old task cleanup cannot end a newer read")
        storage.release(); await currentTask.value
        XCTAssertEqual(owner.value, complete)
        XCTAssertFalse(owner.loading)

        // Preserve partial status when this generation's storage query fails.
        let partial = Projection(status: UUID(), storage: nil)
        let failedStorage = try XCTUnwrap(owner.refresh(identity: entity) { publish in
            publish(partial)
            throw ReadFailure.storage
        })
        await failedStorage.value
        XCTAssertEqual(owner.value, partial)
        XCTAssertEqual(owner.failure, ReadFailure.storage.localizedDescription)

        // A late success must not erase the newer error or storage projection.
        let olderSuccess = HeldRead()
        defer { olderSuccess.release() }
        let olderSuccessTask = try XCTUnwrap(owner.refresh(identity: entity) { publish in
            await olderSuccess.hold(); publish(stale)
        })
        await fulfillment(of: [olderSuccess.entered], timeout: 3)
        let newerFailure = try XCTUnwrap(owner.refresh(identity: entity) { _ in throw ReadFailure.current })
        await newerFailure.value
        olderSuccess.release(); await olderSuccessTask.value
        XCTAssertEqual(owner.value, partial)
        XCTAssertEqual(owner.failure, ReadFailure.current.localizedDescription)

        // A page retirement rejects both in-flight publication and a late
        // post-write refresh. Only a presentation activation admits reads again.
        let retired = HeldRead()
        defer { retired.release() }
        let retiredTask = try XCTUnwrap(owner.refresh(identity: entity) { publish in
            await retired.hold(); publish(stale); throw ReadFailure.old
        })
        await fulfillment(of: [retired.entered], timeout: 3)
        owner.retire()
        var lateReadCount = 0
        XCTAssertNil(owner.refresh(identity: entity) { _ in lateReadCount += 1 })
        retired.release(); await retiredTask.value
        XCTAssertEqual(owner.value, partial)
        XCTAssertNil(owner.failure)
        XCTAssertFalse(owner.loading)
        XCTAssertEqual(lateReadCount, 0)

        owner.activate(identity: entity)
        let resumed = try XCTUnwrap(owner.refresh(identity: entity) { publish in publish(complete) })
        await resumed.value
        XCTAssertEqual(owner.value, complete)

        // The identity includes the session/current-chapter protection context
        // in production. An old context cannot reactivate itself after a switch.
        let previousEntity = HeldRead()
        defer { previousEntity.release() }
        let previousTask = try XCTUnwrap(owner.refresh(identity: entity) { publish in
            await previousEntity.hold(); publish(stale); throw ReadFailure.old
        })
        await fulfillment(of: [previousEntity.entered], timeout: 3)
        owner.activate(identity: replacement)
        XCTAssertNil(owner.value)
        XCTAssertNil(owner.refresh(identity: entity) { _ in lateReadCount += 1 })
        let replacementTask = try XCTUnwrap(owner.refresh(identity: replacement) { publish in publish(first) })
        await replacementTask.value
        previousEntity.release(); await previousTask.value
        XCTAssertEqual(owner.identity, replacement)
        XCTAssertEqual(owner.value, first)
        XCTAssertNil(owner.failure)
        XCTAssertEqual(lateReadCount, 0)

        // Retiring read presentation cannot consume an independently accepted
        // business action. Its original identity still owns its completion.
        let actions = ReaderLibraryActionOwner(), accepted = HeldRead()
        defer { accepted.release() }
        var actionIDs: [String] = []
        let actionTask = Task {
            await actions.perform("read retirement ownership boundary", scope: UUID().uuidString) { id in
                actionIDs.append(id); await accepted.hold()
            }
        }
        await fulfillment(of: [accepted.entered], timeout: 3)
        let originalID = try XCTUnwrap(actions.pendingOperationID)
        owner.retire()
        XCTAssertEqual(actions.pendingOperationID, originalID)
        XCTAssertTrue(actions.busy)
        accepted.release()
        let actionCompleted = await actionTask.value
        XCTAssertTrue(actionCompleted)
        XCTAssertEqual(actionIDs, [originalID])
        XCTAssertFalse(actions.hasPending)
    }
}
