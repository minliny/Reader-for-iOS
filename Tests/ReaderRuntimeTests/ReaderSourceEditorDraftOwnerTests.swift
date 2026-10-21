import Foundation
import CryptoKit
import XCTest
#if canImport(ReaderSourceDraftContract)
@testable import ReaderSourceDraftContract
#else
@testable import Reader
#endif

@MainActor
final class ReaderSourceEditorDraftOwnerTests: XCTestCase {
    private func isolatedDefaults() throws -> (UserDefaults, String) {
        let suite = "ReaderSourceEditorDraftOwnerTests." + UUID().uuidString
        return (try XCTUnwrap(UserDefaults(suiteName: suite)), suite)
    }
    private func replacement(_ value: ReaderSourceEditorDraftOwner.OpenResult,
                             file: StaticString = #filePath, line: UInt = #line) throws -> ReaderSourceEditorDraftOwner.Replacement {
        guard case .confirmation(let intent) = value else {
            XCTFail("Unsaved input must require a captured replacement confirmation", file: file, line: line)
            throw NSError(domain: "SourceDraftPrerequisite", code: 1)
        }
        return intent
    }

    func testLegacyAndImportedDraftsRequireConfirmationButKnownCleanDefinitionDoesNot() async throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("legacy nonempty input", forKey: "reader.source-editor.draft")
        let owner = ReaderSourceEditorDraftOwner(actions: ReaderLibraryActionOwner(), defaults: defaults)
        owner.activate(); owner.resumeDraft()
        XCTAssertTrue(owner.hasUnsavedInput, "A pre-metadata persisted draft has unknown saved state")
        let source = ReaderSourceEditorDraftOwner.Target.savedSource("source-a", version: "core-version-a", name: "A", text: "Core definition A")
        let original = try replacement(owner.offer(source))
        XCTAssertEqual(owner.draft, "legacy nonempty input")
        XCTAssertEqual(defaults.string(forKey: "reader.source-editor.draft"), owner.draft)
        XCTAssertTrue(owner.confirm(original))
        XCTAssertFalse(owner.hasUnsavedInput)
        let imported = ReaderSourceEditorDraftOwner.Target.imported("file input B", label: "文件 B")
        guard case .opened = owner.offer(imported) else { return XCTFail("A known clean definition needs no discard confirmation") }
        XCTAssertTrue(owner.hasUnsavedInput, "Reading/validating imported content is not a save ACK")
        owner.close(); owner.resumeDraft()
        XCTAssertEqual(owner.draft, imported.text)
        _ = try replacement(owner.offer(source))
        owner.retire()
        let restored = ReaderSourceEditorDraftOwner(actions: ReaderLibraryActionOwner(), defaults: defaults)
        restored.activate()
        XCTAssertTrue(restored.hasUnsavedInput)
        _ = try replacement(restored.offer(source))
        let metadata = try XCTUnwrap(defaults.data(forKey: "reader.source-editor.draft.metadata.v1"))
        XCTAssertFalse(String(decoding: metadata, as: UTF8.self).contains(imported.text), "Baseline metadata stores digests, not another full JSON copy")
    }

    func testCancelledStaleAndDuplicateReplacementsCannotOverwriteDraft() async throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = ReaderSourceEditorDraftOwner(actions: ReaderLibraryActionOwner(), defaults: defaults)
        owner.activate(); owner.resumeDraft(); owner.updateDraft("user draft")
        let cancelled = try replacement(owner.offer(.imported("file candidate", label: "文件")))
        owner.dismissConfirmation()
        XCTAssertFalse(owner.confirm(cancelled))
        XCTAssertEqual(owner.draft, "user draft")
        let edited = try replacement(owner.offer(.imported("URL candidate", label: "链接")))
        owner.updateDraft("newer user draft")
        XCTAssertFalse(owner.confirm(edited))
        let closed = try replacement(owner.offer(.imported("another source", label: "另一个书源")))
        owner.close(); owner.resumeDraft()
        XCTAssertFalse(owner.confirm(closed))
        let leftPage = try replacement(owner.offer(.imported("old page candidate", label: "旧页面")))
        owner.retire(); owner.activate(); owner.resumeDraft()
        XCTAssertFalse(owner.confirm(leftPage))
        let replaced = try replacement(owner.offer(.imported("superseded candidate", label: "前一目标")))
        let current = try replacement(owner.offer(.imported("current candidate", label: "当前目标")))
        XCTAssertFalse(owner.confirm(replaced))
        XCTAssertTrue(owner.confirm(current))
        XCTAssertFalse(owner.confirm(current), "A native confirmation consumes the original replacement only once")
        XCTAssertEqual(owner.draft, "current candidate")
        XCTAssertEqual(defaults.string(forKey: "reader.source-editor.draft"), "current candidate")
    }

    func testOriginalPendingSaveRetainsUUIDAndBytesAcrossCloseAndBlocksReplacement() async throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let actions = ReaderLibraryActionOwner()
        let owner = ReaderSourceEditorDraftOwner(actions: actions, defaults: defaults)
        owner.activate(); owner.resumeDraft(); owner.updateDraft("accepted original source input")
        var ids: [String] = [], inputs: [Data] = []
        let first = await owner.save { id, input in
            ids.append(id); inputs.append(input.bytes)
            if ids.count == 1 { throw ReaderLibraryError.operationPending(id) }
            return true
        }
        XCTAssertFalse(first)
        let originalID = try XCTUnwrap(actions.pendingOperationID)
        XCTAssertEqual(ids, [originalID]); XCTAssertTrue(owner.hasUnsavedInput)
        owner.close(); owner.resumeDraft()
        guard case .ignored = owner.offer(.imported("replacement must not enter", label: "文件")) else { return XCTFail("Pending original save blocks replacement") }
        XCTAssertNil(owner.beginRead())
        owner.updateDraft("must not change accepted input")
        XCTAssertEqual(owner.draft, "accepted original source input")
        let duplicate = await owner.save { _, _ in XCTFail("Do not dispatch another save while its original is pending"); return true }
        XCTAssertFalse(duplicate)
        XCTAssertEqual(actions.pendingOperationID, originalID)
        owner.retire()
        let coldActions = ReaderLibraryActionOwner()
        let cold = ReaderSourceEditorDraftOwner(actions: coldActions, defaults: defaults)
        cold.activate(); cold.resumeDraft()
        XCTAssertEqual(cold.acceptedOperationID, originalID)
        XCTAssertFalse(cold.canReplace)
        var coldAttempts = 0
        XCTAssertTrue(cold.restoreSave { id, input in
            ids.append(id); inputs.append(input.bytes); coldAttempts += 1
            if coldAttempts == 1 { throw ReaderLibraryError.operationPending(id) }
            return true
        })
        XCTAssertTrue(cold.restoreSave { _, _ in XCTFail("Duplicate restore cannot replace the frozen closure"); return false })
        let stillUnknown = await coldActions.resumeOriginal()
        XCTAssertFalse(stillUnknown)
        XCTAssertEqual(cold.acceptedOperationID, originalID)
        XCTAssertEqual(coldActions.pendingOperationID, originalID)
        XCTAssertTrue(cold.hasUnsavedInput)

        let occupiedActions = ReaderLibraryActionOwner()
        _ = await occupiedActions.perform("another original owner", scope: "other") { id in throw ReaderLibraryError.operationPending(id) }
        let occupiedID = occupiedActions.pendingOperationID
        let occupied = ReaderSourceEditorDraftOwner(actions: occupiedActions, defaults: defaults)
        occupied.activate()
        XCTAssertFalse(occupied.restoreSave { _, _ in XCTFail("Cold restore cannot replace a different original owner"); return true })
        XCTAssertEqual(occupiedActions.pendingOperationID, occupiedID)

        let resumed = await coldActions.resumeOriginal()
        XCTAssertTrue(resumed)
        XCTAssertEqual(ids, [originalID, originalID, originalID])
        XCTAssertEqual(inputs, Array(repeating: Data("accepted original source input".utf8), count: 3))
        XCTAssertFalse(coldActions.hasPending); XCTAssertFalse(cold.hasUnsavedInput)
        XCTAssertNil(cold.acceptedOperationID)
        XCTAssertFalse(cold.presented, "An ACK closes only the same restored editor lifecycle and unchanged input")
        let restored = ReaderSourceEditorDraftOwner(actions: ReaderLibraryActionOwner(), defaults: defaults)
        restored.activate()
        XCTAssertFalse(restored.hasUnsavedInput, "Only the original successful save ACK supplied this persisted clean baseline")
        restored.resumeDraft(); restored.updateDraft("original rejected input")
        _ = await restored.save { id, _ in throw ReaderLibraryError.operationPending(id) }
        let rejectedID = try XCTUnwrap(restored.acceptedOperationID)
        restored.retire()
        let rejectionActions = ReaderLibraryActionOwner()
        rejectionActions.pendingChecker = { _ in false }
        let rejection = ReaderSourceEditorDraftOwner(actions: rejectionActions, defaults: defaults)
        rejection.activate(); rejection.resumeDraft()
        XCTAssertTrue(rejection.restoreSave { id, input in
            XCTAssertEqual(id, rejectedID); XCTAssertEqual(input.text, "original rejected input")
            throw ReaderLibraryError.core(code: "INVALID_PARAMS", message: "original definite rejection", retryable: false, reason: "original_receipt")
        })
        let rejected = await rejectionActions.resumeOriginal()
        XCTAssertFalse(rejected); XCTAssertFalse(rejectionActions.hasPending)
        XCTAssertNil(rejection.acceptedOperationID)
        XCTAssertEqual(rejection.draft, "original rejected input")
        XCTAssertTrue(rejection.hasUnsavedInput); XCTAssertTrue(rejection.canReplace)
        XCTAssertTrue(rejection.presented, "A definite rejection preserves the draft in its current editor")
        rejection.updateDraft("partial package still unsaved")
        let partial = await rejection.save { _, _ in false }
        XCTAssertTrue(partial, "The existing action owner may finish a package whose item results include definite failures")
        XCTAssertNil(rejection.acceptedOperationID)
        XCTAssertTrue(rejection.hasUnsavedInput, "Partial item success is not an all-saved baseline")
        XCTAssertTrue(rejection.canReplace)
    }

    func testLateReadAndSaveCallbacksCannotReplaceNewerPersistedDraft() async throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let actions = ReaderLibraryActionOwner()
        let owner = ReaderSourceEditorDraftOwner(actions: actions, defaults: defaults)
        owner.activate(); owner.resumeDraft(); owner.updateDraft("draft before read")
        let editedRead = try XCTUnwrap(owner.beginRead())
        owner.updateDraft("edited while URL was loading")
        guard case .ignored = owner.finishRead(editedRead, target: .imported("late URL", label: "链接")) else { return XCTFail("A read cannot replace input edited after dispatch") }
        let oldRead = try XCTUnwrap(owner.beginRead())
        let currentRead = try XCTUnwrap(owner.beginRead())
        guard case .ignored = owner.finishRead(oldRead, target: .imported("late file", label: "文件")) else { return XCTFail("Only the current original read may propose a replacement") }
        XCTAssertTrue(owner.accepts(currentRead))
        owner.retire(); owner.activate(); owner.resumeDraft()
        guard case .ignored = owner.finishRead(currentRead, target: .imported("departed page", label: "旧页面")) else { return XCTFail("A retired read cannot affect the next page lifecycle") }

        let entered = expectation(description: "original save is held")
        let stale = ReaderSourceEditorDraftOwner(actions: ReaderLibraryActionOwner(), defaults: defaults)
        stale.activate(); stale.resumeDraft()
        let staleReader = ReaderSourceEditorDraftOwner(actions: ReaderLibraryActionOwner(), defaults: defaults)
        staleReader.activate()
        var release: CheckedContinuation<Void, Never>?
        let task = Task {
            await owner.save { _, _ in
                await withCheckedContinuation { release = $0; entered.fulfill() }
                return true
            }
        }
        await fulfillment(of: [entered], timeout: 3)
        let acceptedID = try XCTUnwrap(owner.acceptedOperationID)
        let sameText = ReaderSourceEditorDraftOwner.Target.savedSource("source-a", version: "core-version", name: "A", text: owner.draft)
        guard case .ignored = stale.offer(sameText) else { return XCTFail("Reloading another owner's pending marker must recheck canReplace before same-text adoption") }
        XCTAssertEqual(stale.acceptedOperationID, acceptedID)
        XCTAssertNil(staleReader.beginRead(), "Reloading a pending marker cannot admit a new read either")
        XCTAssertEqual(staleReader.acceptedOperationID, acceptedID)
        owner.retire()
        let next = ReaderSourceEditorDraftOwner(actions: ReaderLibraryActionOwner(), defaults: defaults)
        next.activate(); next.resumeDraft(); next.updateDraft("new page's persisted unsaved text")
        XCTAssertEqual(next.draft, "edited while URL was loading", "Cold metadata protects the accepted input before any new edit")
        // A legacy writer outside this owner may still change UserDefaults.
        // The old ACK must not overwrite that newer storage or bless it clean.
        defaults.set("new page's persisted unsaved text", forKey: "reader.source-editor.draft")
        release?.resume()
        let finished = await task.value
        XCTAssertTrue(finished)
        XCTAssertEqual(defaults.string(forKey: "reader.source-editor.draft"), "new page's persisted unsaved text")
        let restored = ReaderSourceEditorDraftOwner(actions: ReaderLibraryActionOwner(), defaults: defaults)
        restored.activate()
        XCTAssertEqual(restored.draft, "new page's persisted unsaved text")
        XCTAssertTrue(restored.hasUnsavedInput, "An old ACK must neither replace new text nor mark that new text clean")
    }

    @MainActor
    private final class HeldLinkRead {
        let entered = XCTestExpectation(description: "Current owned link read entered")
        let cancelled = XCTestExpectation(description: "Original link task received cancellation")
        private var continuation: CheckedContinuation<Void, Never>?
        func hold() async {
            let cancellation = cancelled
            await withTaskCancellationHandler(operation: {
                await withCheckedContinuation { continuation in
                    self.continuation = continuation; entered.fulfill()
                }
            }, onCancel: { cancellation.fulfill() })
        }
        func release() { let original = continuation; continuation = nil; original?.resume() }
    }
    private enum LinkReadProbeError: Error { case unavailable }

    /// Actual Task cancellation and production input-owner scheduling only.
    /// Uses the provisioned source package as input, without HTTP, Core writes,
    /// a new source definition, credentials, file mutation or an import ACK.
    func testOwnedLinkReadCancellationDrainsLateResultsWithoutClearingNewReadOrAcceptedSave() async throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let original = try Data(contentsOf: documents.appendingPathComponent("Reader-real-sources.json"))
        XCTAssertEqual(original.count, 5_606)
        XCTAssertEqual(SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined(),
                       "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322")
        let text = try ReaderSourcePackageInput.decodeUTF8(original)
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let actions = ReaderLibraryActionOwner()
        let owner = ReaderSourceEditorDraftOwner(actions: actions, defaults: defaults)
        owner.activate(); owner.resumeDraft(); owner.updateDraft(text + "\n")
        var completed = 0, failed = 0
        var held: [HeldLinkRead] = []
        defer { held.forEach { $0.release() }; owner.retire() }
        func start(_ request: ReaderSourceEditorDraftOwner.ReadRequest? = nil)
            throws -> (ReaderSourceEditorDraftOwner.ReadRequest, HeldLinkRead, Task<Void, Never>) {
            let request = try request ?? XCTUnwrap(owner.beginRead())
            let gate = HeldLinkRead(); held.append(gate)
            let task = try XCTUnwrap(owner.performRead(request, operation: {
                await gate.hold()
                // Deliberately return after cancellation to exercise the real
                // request-generation guard, without inventing an HTTP response.
                return .imported(text, label: "原书源包的读取边界")
            }, completion: { _ in completed += 1 }, failure: { _ in failed += 1 }))
            return (request, gate, task)
        }
        let beforeDraft = owner.draft
        let beforeMetadata = defaults.data(forKey: "reader.source-editor.draft.metadata.v1")
        let (first, firstGate, firstTask) = try start()
        await fulfillment(of: [firstGate.entered], timeout: 3)
        owner.cancelRead() // The existing URL-field change consumer calls this.
        await fulfillment(of: [firstGate.cancelled], timeout: 3)
        XCTAssertFalse(owner.accepts(first))
        let (second, secondGate, secondTask) = try start()
        await fulfillment(of: [secondGate.entered], timeout: 3)
        firstGate.release(); await firstTask.value
        XCTAssertTrue(owner.accepts(second))
        XCTAssertNil(owner.performRead(second, operation: {
            XCTFail("A late old defer must not clear the newer read task slot")
            throw LinkReadProbeError.unavailable
        }, completion: { _ in XCTFail("No duplicate completion") }, failure: { _ in XCTFail("No duplicate failure") }))
        XCTAssertEqual(owner.draft, beforeDraft)
        XCTAssertEqual(defaults.data(forKey: "reader.source-editor.draft.metadata.v1"), beforeMetadata)

        let third = try XCTUnwrap(owner.beginRead()) // A new read cancels its predecessor.
        await fulfillment(of: [secondGate.cancelled], timeout: 3)
        let (_, thirdGate, thirdTask) = try start(third)
        await fulfillment(of: [thirdGate.entered], timeout: 3)
        secondGate.release(); await secondTask.value
        XCTAssertTrue(owner.accepts(third))
        owner.updateDraft(text + "\n\n")
        await fulfillment(of: [thirdGate.cancelled], timeout: 3)
        let editedDraft = owner.draft
        let editedMetadata = defaults.data(forKey: "reader.source-editor.draft.metadata.v1")
        thirdGate.release(); await thirdTask.value
        XCTAssertEqual(owner.draft, editedDraft)
        XCTAssertEqual(defaults.data(forKey: "reader.source-editor.draft.metadata.v1"), editedMetadata)

        let (_, closedGate, closedTask) = try start()
        await fulfillment(of: [closedGate.entered], timeout: 3)
        owner.close()
        await fulfillment(of: [closedGate.cancelled], timeout: 3)
        closedGate.release(); await closedTask.value
        XCTAssertFalse(owner.presented)
        owner.resumeDraft()
        let (_, retiredGate, retiredTask) = try start()
        await fulfillment(of: [retiredGate.entered], timeout: 3)
        let acceptedID = "09547051-672d-41bf-ac76-af8b6c442508"
        var acceptedExecutions = 0
        XCTAssertTrue(actions.restoreAccepted(id: acceptedID, label: "原保存", scope: "online") { _ in
            acceptedExecutions += 1
            XCTFail("Read retirement cannot execute or replay an accepted save")
        })
        owner.retire()
        await fulfillment(of: [retiredGate.cancelled], timeout: 3)
        let reopened = ReaderSourceEditorDraftOwner(actions: ReaderLibraryActionOwner(), defaults: defaults)
        reopened.activate(); reopened.resumeDraft()
        defer { reopened.retire() }
        retiredGate.release(); await retiredTask.value
        XCTAssertEqual(completed, 0); XCTAssertEqual(failed, 0)
        XCTAssertEqual(actions.pendingOperationID, acceptedID)
        XCTAssertEqual(acceptedExecutions, 0)
        XCTAssertEqual(reopened.draft, editedDraft)
        XCTAssertEqual(defaults.data(forKey: "reader.source-editor.draft.metadata.v1"), editedMetadata)

        let failedRead = try XCTUnwrap(reopened.beginRead())
        let failureTask = try XCTUnwrap(reopened.performRead(failedRead, operation: {
            throw LinkReadProbeError.unavailable
        }, completion: { _ in XCTFail("No result for current failed read") }, failure: { _ in failed += 1 }))
        await failureTask.value
        XCTAssertEqual(failed, 1)
        XCTAssertFalse(reopened.accepts(failedRead))
        let successfulRead = try XCTUnwrap(reopened.beginRead())
        let successTask = try XCTUnwrap(reopened.performRead(successfulRead, operation: {
            .imported(text, label: "原书源包")
        }, completion: { result in
            guard case .confirmation = result else { return XCTFail("Unsaved real input still requires the original replacement confirmation") }
            completed += 1
        }, failure: { _ in XCTFail("No failure for current source input") }))
        await successTask.value
        XCTAssertEqual(completed, 1)
        XCTAssertEqual(reopened.draft, editedDraft)
        reopened.dismissConfirmation()
        // Completion and failure both release the original task slot.
        XCTAssertNotNil(reopened.beginRead())
        XCTAssertEqual(actions.pendingOperationID, acceptedID)
        XCTAssertEqual(acceptedExecutions, 0)
        XCTAssertEqual(try Data(contentsOf: documents.appendingPathComponent("Reader-real-sources.json")), original)
    }
}
