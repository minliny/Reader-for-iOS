import Foundation
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
}
