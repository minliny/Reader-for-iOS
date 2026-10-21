import Combine
import XCTest
@testable import Reader

@MainActor
final class ReaderDownloadControlOwnerTests: XCTestCase {
    @MainActor
    private final class HeldAction {
        let entered: XCTestExpectation
        private var continuation: CheckedContinuation<Void, Never>?
        private var released = false

        init(_ description: String) { entered = XCTestExpectation(description: description) }
        func hold() async {
            guard !released else { return }
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                entered.fulfill()
            }
        }
        func release() {
            released = true
            let current = continuation
            continuation = nil
            current?.resume()
        }
    }

    /// Presentation scheduling only: no book, Core ACK, HTTP response or
    /// download state is fabricated, and this is not native acceptance.
    func testPendingOriginalResumeAllowsIndependentPauseCancelAndLateResultKeepsNewControlOwner() async throws {
        let owner = ReaderDownloadControlOwner()
        var presentationChanges = 0
        let observation = owner.objectWillChange.sink { presentationChanges += 1 }
        defer { observation.cancel() }
        let originalResume = HeldAction("original resume awaits its own outcome")
        let continuedResume = HeldAction("same resume intent awaits acquisition again")
        let pause = HeldAction("independent pause admitted")
        let cancel = HeldAction("new independent cancel admitted")
        defer { originalResume.release(); continuedResume.release(); pause.release(); cancel.release() }
        var resumeIDs: [String] = []
        var controlIDs: [String] = []

        let resumeTask = Task {
            await owner.performResume(scope: "download-owner-boundary") { id in
                resumeIDs.append(id)
                if resumeIDs.count == 1 {
                    await originalResume.hold()
                    throw ReaderLibraryError.operationPending(id)
                }
                await continuedResume.hold()
            }
        }
        await fulfillment(of: [originalResume.entered], timeout: 3)
        let resumeID = try XCTUnwrap(owner.resumeActions.pendingOperationID)
        XCTAssertTrue(owner.resumeActions.busy)
        XCTAssertGreaterThan(presentationChanges, 0,
                             "The View's real aggregate owner must publish nested owner changes")
        XCTAssertFalse(owner.canResume)
        XCTAssertFalse(owner.canClear)
        XCTAssertTrue(owner.canControl)
        let duplicateResume = await owner.performResume(scope: "download-owner-boundary") { _ in
            XCTFail("A new resume cannot replace the retained original")
        }
        let prematureClear = await owner.performClear(scope: "download-owner-boundary") { _ in
            XCTFail("Clearing cannot run under a retained resume/acquisition")
        }
        XCTAssertFalse(duplicateResume)
        XCTAssertFalse(prematureClear)

        let pauseTask = Task {
            await owner.performControl(scope: "download-owner-boundary") { id in
                controlIDs.append(id)
                await pause.hold()
            }
        }
        await fulfillment(of: [pause.entered], timeout: 3)
        let pauseID = try XCTUnwrap(owner.controlActions.pendingOperationID)
        XCTAssertNotEqual(pauseID, resumeID)
        XCTAssertEqual(owner.resumeActions.pendingOperationID, resumeID)
        pause.release()
        let paused = await pauseTask.value
        XCTAssertTrue(paused)
        XCTAssertTrue(owner.canControl)

        // An unresolved result retains the original resume and its closure.
        // Recovery reuses its ID; no fresh read or replacement is an ACK.
        originalResume.release()
        let firstResumeFinished = await resumeTask.value
        XCTAssertFalse(firstResumeFinished)
        XCTAssertFalse(owner.resumeActions.busy)
        XCTAssertEqual(owner.resumeActions.pendingOperationID, resumeID)
        XCTAssertNotNil(owner.resumeActions.recovery)
        XCTAssertFalse(owner.canResume)
        XCTAssertFalse(owner.canClear)
        XCTAssertTrue(owner.canControl)
        let retryResume = Task { await owner.resumeActions.resumeOriginal() }
        await fulfillment(of: [continuedResume.entered], timeout: 3)
        XCTAssertEqual(resumeIDs, [resumeID, resumeID])

        let cancelTask = Task {
            await owner.performControl(scope: "download-owner-boundary") { id in
                controlIDs.append(id)
                await cancel.hold()
            }
        }
        await fulfillment(of: [cancel.entered], timeout: 3)
        let cancelID = try XCTUnwrap(owner.controlActions.pendingOperationID)
        XCTAssertNotEqual(cancelID, pauseID)
        XCTAssertNotEqual(cancelID, resumeID)
        XCTAssertFalse(owner.canControl)

        // The late resume result may consume only its own presentation owner.
        // The newer cancel remains pending with the exact ID it dispatched.
        continuedResume.release()
        let resumed = await retryResume.value
        XCTAssertTrue(resumed)
        XCTAssertFalse(owner.resumeActions.hasPending)
        XCTAssertEqual(owner.controlActions.pendingOperationID, cancelID)
        XCTAssertTrue(owner.controlActions.busy)
        XCTAssertFalse(owner.canResume)
        XCTAssertFalse(owner.canClear)
        XCTAssertEqual(controlIDs, [pauseID, cancelID])
        cancel.release()
        let cancelled = await cancelTask.value
        XCTAssertTrue(cancelled)
        XCTAssertTrue(owner.canControl)
        XCTAssertTrue(owner.canResume)
        XCTAssertTrue(owner.canClear)
    }

    private enum ObserverFailure: Error { case unavailable }

    /// This controls only presentation-owner outcomes. It fabricates no Core
    /// reply, book, source or download state; terminal success is not a Core ACK.
    func testOrdinaryErrorsKeepExactOriginalIDsForPendingOrUnknownQueriesAcrossIndependentDownloadLanes() async throws {
        var pendingAnswer: Bool? = true
        var checkedIDs: [String] = []
        let owner = ReaderDownloadControlOwner(pendingChecker: { id in
            checkedIDs.append(id)
            return pendingAnswer
        })
        var resumeIDs: [String] = []
        var controlIDs: [String] = []
        let firstResume = await owner.performResume(scope: "download-owner-query-boundary") { id in
            resumeIDs.append(id)
            if resumeIDs.count < 3 { throw ObserverFailure.unavailable }
        }
        XCTAssertFalse(firstResume)
        let resumeID = try XCTUnwrap(owner.resumeActions.pendingOperationID)
        XCTAssertEqual(checkedIDs, [resumeID])
        XCTAssertNotNil(owner.resumeActions.recovery)
        XCTAssertFalse(owner.canResume)
        XCTAssertFalse(owner.canClear)
        XCTAssertTrue(owner.canControl, "An unresolved resume must leave the short control lane available")

        let firstControl = await owner.performControl(scope: "download-owner-query-boundary") { id in
            controlIDs.append(id)
            if controlIDs.count < 3 { throw ObserverFailure.unavailable }
        }
        XCTAssertFalse(firstControl)
        let controlID = try XCTUnwrap(owner.controlActions.pendingOperationID)
        XCTAssertNotEqual(controlID, resumeID)
        XCTAssertEqual(checkedIDs, [resumeID, controlID])
        XCTAssertNotNil(owner.controlActions.recovery)
        XCTAssertFalse(owner.canControl)

        pendingAnswer = nil
        let unknownResume = await owner.resumeActions.resumeOriginal()
        let unknownControl = await owner.controlActions.resumeOriginal()
        XCTAssertFalse(unknownResume)
        XCTAssertFalse(unknownControl)
        XCTAssertEqual(owner.resumeActions.pendingOperationID, resumeID)
        XCTAssertEqual(owner.controlActions.pendingOperationID, controlID)
        XCTAssertEqual(resumeIDs, [resumeID, resumeID])
        XCTAssertEqual(controlIDs, [controlID, controlID])
        XCTAssertEqual(checkedIDs, [resumeID, controlID, resumeID, controlID],
                       "Both true and nil are about each exact retained original ID")
        let replacementResume = await owner.performResume(scope: "download-owner-query-boundary") { _ in
            XCTFail("An unknown original resume cannot be replaced")
        }
        let replacementControl = await owner.performControl(scope: "download-owner-query-boundary") { _ in
            XCTFail("An unknown original control cannot be replaced")
        }
        let prematureClear = await owner.performClear(scope: "download-owner-query-boundary") { _ in
            XCTFail("An unknown original download cannot be cleared")
        }
        XCTAssertFalse(replacementResume)
        XCTAssertFalse(replacementControl)
        XCTAssertFalse(prematureClear)

        // The unchanged original closures now return. One child's terminal
        // presentation cannot clear the other child's distinct original owner.
        let resumed = await owner.resumeActions.resumeOriginal()
        XCTAssertTrue(resumed)
        XCTAssertFalse(owner.resumeActions.hasPending)
        XCTAssertEqual(owner.controlActions.pendingOperationID, controlID)
        XCTAssertFalse(owner.canResume)
        XCTAssertFalse(owner.canClear)
        let controlled = await owner.controlActions.resumeOriginal()
        XCTAssertTrue(controlled)
        XCTAssertEqual(resumeIDs, [resumeID, resumeID, resumeID])
        XCTAssertEqual(controlIDs, [controlID, controlID, controlID])
        XCTAssertTrue(owner.canControl)
        XCTAssertTrue(owner.canResume)
        XCTAssertTrue(owner.canClear)
        XCTAssertEqual(checkedIDs, [resumeID, controlID, resumeID, controlID])
    }

    func testOnlyExactNegativeQueryReleasesOrdinaryFailureAndMissingCheckerRetainsOriginalClear() async throws {
        var checkedIDs: [String] = []
        var attemptedIDs: [String] = []
        let definite = ReaderDownloadControlOwner(pendingChecker: { id in
            checkedIDs.append(id)
            return false
        })
        let resume = await definite.performResume(scope: "download-owner-negative-query") { id in
            attemptedIDs.append(id); throw ObserverFailure.unavailable
        }
        let control = await definite.performControl(scope: "download-owner-negative-query") { id in
            attemptedIDs.append(id); throw ObserverFailure.unavailable
        }
        let clear = await definite.performClear(scope: "download-owner-negative-query") { id in
            attemptedIDs.append(id); throw ObserverFailure.unavailable
        }
        XCTAssertFalse(resume)
        XCTAssertFalse(control)
        XCTAssertFalse(clear)
        XCTAssertEqual(checkedIDs, attemptedIDs)
        XCTAssertEqual(Set(attemptedIDs).count, 3)
        XCTAssertFalse(definite.resumeActions.hasPending)
        XCTAssertFalse(definite.controlActions.hasPending)
        XCTAssertTrue(definite.canResume)
        XCTAssertTrue(definite.canControl)
        XCTAssertTrue(definite.canClear)

        let unknown = ReaderDownloadControlOwner()
        var clearIDs: [String] = []
        let first = await unknown.performClear(scope: "download-owner-missing-query") { id in
            clearIDs.append(id); throw ObserverFailure.unavailable
        }
        XCTAssertFalse(first)
        let originalID = try XCTUnwrap(unknown.controlActions.pendingOperationID)
        XCTAssertNotNil(unknown.controlActions.recovery)
        XCTAssertFalse(unknown.canControl)
        XCTAssertFalse(unknown.canResume)
        XCTAssertFalse(unknown.canClear)
        let continued = await unknown.controlActions.resumeOriginal()
        XCTAssertFalse(continued)
        XCTAssertEqual(unknown.controlActions.pendingOperationID, originalID)
        XCTAssertEqual(clearIDs, [originalID, originalID])
    }
}
