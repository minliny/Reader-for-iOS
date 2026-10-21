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
}
