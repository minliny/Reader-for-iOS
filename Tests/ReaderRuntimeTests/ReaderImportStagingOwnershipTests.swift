import Foundation
import CryptoKit
import Darwin
import XCTest
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

/// Private, unapplied candidate. Requires the unmodified Downloads original to
/// be provisioned into test-host Documents, as existing real-original methods do.
/// Mutations below touch only newly created test-owned copies, never that input.
@MainActor
final class ReaderImportStagingOwnershipTests: XCTestCase {
    func testRealOriginalOversizeCopyIsRejectedBeforeOwnerPayloadOrCoreParse() async throws {
        let fixture = try StagingFixture()
        defer { fixture.cleanUp() }
        let copy = try fixture.copyInput("oversize.txt")
        let handle = try FileHandle(forWritingTo: copy)
        try handle.truncate(atOffset: UInt64(ReaderImportStagingLease.maximumInputBytes + 1))
        try handle.close()
        do {
            _ = try await fixture.service.importBook(at: copy)
            XCTFail("Sparse extension is a size-admission fault, not a valid substitute book")
        } catch let error as CocoaError { XCTAssertEqual(error.code, .fileReadTooLarge) }
        XCTAssertEqual(try fixture.stagePayloads(), [])
        XCTAssertEqual(try fixture.ownerReceipts(), [])
        XCTAssertEqual(fixture.client.count("import.parse"), 0)
        XCTAssertEqual(fixture.client.count("import.persist"), 0)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
        try fixture.assertOriginalPreserved()
        try await fixture.service.close()
    }

    func testRealOriginalGrowthAfterFDAdmissionCannotCopyOrParseTheExtraBytes() async throws {
        let fault = StagingFault()
        let fixture = try StagingFixture(observer: { point, input in
            guard point == .admitted else { return }
            fault.didRun()
            let writer = try FileHandle(forWritingTo: input)
            defer { try? writer.close() }
            try writer.truncate(atOffset: UInt64(ReaderImportStagingLease.maximumInputBytes + 1))
        })
        defer { fixture.cleanUp() }
        let copy = try fixture.copyInput("growing.txt")
        do { _ = try await fixture.service.importBook(at: copy); XCTFail("The admitted FD changed before EOF") }
        catch ReaderLibraryError.invalidResponse(_) {}
        XCTAssertEqual(fault.count, 1)
        XCTAssertEqual(try fixture.stagePayloads(), [])
        XCTAssertEqual(try fixture.ownerReceipts(), [])
        XCTAssertEqual(fixture.client.count("import.parse"), 0)
        XCTAssertEqual(fixture.client.count("import.persist"), 0)
        try fixture.assertOriginalPreserved()
        try await fixture.service.close()
    }

    func testRealOriginalPathSwapBeforeOpenIsRejectedByNoFollowWithoutTouchingTheTarget() async throws {
        let fault = StagingFault()
        let fixture = try StagingFixture(observer: { point, input in
            guard point == .sourceWillOpen else { return }
            fault.didRun()
            let untouched = input.deletingLastPathComponent().appendingPathComponent("unchanged-original-copy.txt")
            try FileManager.default.copyItem(at: input, to: untouched)
            try FileManager.default.removeItem(at: input) // Only this test-owned selection path.
            try FileManager.default.createSymbolicLink(at: input, withDestinationURL: untouched)
        })
        defer { fixture.cleanUp() }
        let copy = try fixture.copyInput("swapped.txt")
        do { _ = try await fixture.service.importBook(at: copy); XCTFail("Opening the raced symlink must fail") }
        catch let error as NSError { XCTAssertEqual(error.domain, NSPOSIXErrorDomain); XCTAssertEqual(error.code, Int(ELOOP)) }
        XCTAssertEqual(fault.count, 1)
        XCTAssertEqual(try Data(contentsOf: copy.deletingLastPathComponent().appendingPathComponent("unchanged-original-copy.txt")), fixture.original)
        XCTAssertEqual(try fixture.stagePayloads(), [])
        XCTAssertEqual(try fixture.ownerReceipts(), [])
        XCTAssertEqual(fixture.client.count("import.parse"), 0)
        XCTAssertEqual(fixture.client.count("import.persist"), 0)
        try fixture.assertOriginalPreserved()
        try await fixture.service.close()
    }

    func testRealOriginalSameBytesPathReplacementAfterAdmissionCannotMasqueradeAsTheOpenedFD() async throws {
        let fault = StagingFault()
        let fixture = try StagingFixture(observer: { point, input in
            guard point == .admitted else { return }
            fault.didRun()
            let replacement = input.deletingLastPathComponent().appendingPathComponent("same-bytes-new-inode.txt")
            try FileManager.default.copyItem(at: input, to: replacement)
            try FileManager.default.removeItem(at: input) // Only the newly created test-owned selection.
            try FileManager.default.moveItem(at: replacement, to: input)
        })
        defer { fixture.cleanUp() }
        let copy = try fixture.copyInput("same-bytes-replaced.txt")
        do { _ = try await fixture.service.importBook(at: copy); XCTFail("Matching SHA cannot disguise a path/FD identity change") }
        catch ReaderLibraryError.invalidResponse(_) {}
        XCTAssertEqual(fault.count, 1)
        XCTAssertEqual(try Data(contentsOf: copy), fixture.original)
        XCTAssertEqual(try fixture.stagePayloads(), [])
        XCTAssertEqual(try fixture.ownerReceipts(), [])
        XCTAssertEqual(fixture.client.count("import.parse"), 0)
        XCTAssertEqual(fixture.client.count("import.persist"), 0)
        try fixture.assertOriginalPreserved()
        try await fixture.service.close()
    }

    func testRealOriginalPrecommitCrashCheckpointsRetireOnlyTheirActualOwnedInodeWithoutReplay() async throws {
        // Hard-link only a newly created staging inode into the crash snapshot.
        // It preserves the real durable receipt's dev/inode after normal error
        // cleanup unlinks the live name. This models process-crash state, not a
        // power-loss/fsync test and not a hand-written receipt or fake parse.
        for point in [ReaderImportStagingCheckpoint.payloadBound, .firstChunkWritten, .sealed, .parsed] {
            let snapshot = StagingCrashSnapshot(point: point)
            let fixture = try StagingFixture(observer: { try snapshot.capture($0, payload: $1) })
            defer { fixture.cleanUp(); snapshot.cleanUp() }
            do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("Checkpoint must stop before persist") }
            catch StagingCrashSnapshot.Captured.stop {}
            let sourceRoot = try XCTUnwrap(snapshot.sources)
            let capturedPayload = try XCTUnwrap(snapshot.payload)
            let capturedReceipt = try XCTUnwrap(snapshot.receipt)
            let owner = try JSONDecoder().decode(ReaderImportStagingOwner.self, from: Data(contentsOf: capturedReceipt))
            var inode = stat()
            XCTAssertEqual(lstat(capturedPayload.path, &inode), 0)
            XCTAssertEqual(owner.payloadIdentity, ReaderImportStagingOwner.FileIdentity(inode))
            let captured = try Data(contentsOf: capturedPayload)
            if point == .payloadBound { XCTAssertTrue(captured.isEmpty, "The durable inode binding precedes the first copied byte") }
            else if point == .firstChunkWritten {
                XCTAssertEqual(captured, Data(fixture.original.prefix(1024 * 1024)))
            } else { XCTAssertEqual(captured, fixture.original) }
            XCTAssertEqual(fixture.client.count("import.parse"), point == .parsed ? 1 : 0)
            XCTAssertEqual(fixture.client.count("import.persist"), 0)
            let unrelated = sourceRoot.appendingPathComponent(".staging/legacy-unowned.source")
            try fixture.original.write(to: unrelated, options: .atomic)
            let originalReceipt = try Data(contentsOf: capturedReceipt)
            XCTAssertFalse(originalReceipt.isEmpty)
            let reopenedCore = fixture.root.appendingPathComponent("Recovery-" + UUID().uuidString)
            let gate = try StagingCoreGate(storage: reopenedCore)
            defer { gate.destroy() }
            let reopened = try ReaderLibraryService(storageURL: reopenedCore, sourceURL: sourceRoot, client: gate, timing: gate.timing)
            let remaining = try await reopened.recoverPendingImports()
            XCTAssertTrue(remaining.isEmpty)
            XCTAssertFalse(FileManager.default.fileExists(atPath: capturedPayload.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: capturedReceipt.path))
            XCTAssertEqual(try Data(contentsOf: unrelated), fixture.original)
            for method in ["import.parse", "import.persist", "bookshelf.add", "import.finalize", "import.rollback"] {
                XCTAssertEqual(gate.count(method), 0, "Resource recovery cannot replay \(method)")
            }
            try fixture.assertOriginalPreserved()
            try await reopened.close()
            try await fixture.service.close()
        }
    }

    func testRealOriginalDurableHandoffProtectsTheUnknownOriginalJournalUntilItsExactACK() async throws {
        let receipt = StagingHandoffCapture()
        let fixture = try StagingFixture(observer: { try receipt.capture($0, payload: $1) })
        defer { fixture.cleanUp() }
        fixture.client.hold("import.persist", advanceObserverDeadline: true)
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("The actual original persist reply is held") }
        catch ReaderLibraryError.operationPending(_) {}
        let originalJournal = try fixture.onlyBusinessJournal()
        let journalBytes = try Data(contentsOf: originalJournal)
        let journal = try XCTUnwrap(JSONSerialization.jsonObject(with: journalBytes) as? [String: Any])
        XCTAssertEqual(journal["phase"] as? String, "persistAwaiting")
        XCTAssertNil(journal["rollbackToken"])
        let ownerURL = try XCTUnwrap(receipt.url)
        let ownerBytes = try XCTUnwrap(receipt.bytes)
        try ownerBytes.write(to: ownerURL, options: .atomic) // Actual production receipt, crash-at-handoff overlap.
        let owner = try JSONDecoder().decode(ReaderImportStagingOwner.self, from: ownerBytes)
        XCTAssertEqual(owner.phase, .handedOff)
        XCTAssertEqual(journal["id"] as? String, owner.transactionID)
        XCTAssertEqual(journal["stagedName"] as? String, owner.stagedName)
        XCTAssertEqual(journal["hash"] as? String, owner.sha256)
        let payload = fixture.sources.appendingPathComponent(".staging/" + owner.stagedName)
        let before = try Data(contentsOf: payload)
        let pending = try await fixture.service.recoverPendingImports()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(try Data(contentsOf: originalJournal), journalBytes)
        XCTAssertEqual(try Data(contentsOf: payload), before)
        XCTAssertTrue(FileManager.default.fileExists(atPath: ownerURL.path), "Keep exact resource identity until the original business terminal")
        XCTAssertEqual(fixture.client.count("import.persist"), 1)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
        XCTAssertEqual(fixture.client.count("import.rollback"), 0)
        fixture.client.release()
        let settled = try await fixture.service.recoverPendingImports()
        XCTAssertTrue(settled.isEmpty)
        XCTAssertEqual(fixture.client.count("import.persist"), 1)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 1)
        XCTAssertEqual(try fixture.ownerReceipts(), [])
        XCTAssertEqual(try fixture.stagePayloads(), [])
        let books = try await fixture.service.listBooks() // Projection only, never the original ACK.
        let book = try XCTUnwrap(books.first)
        XCTAssertEqual(book.bookId, "local:" + StagingFixture.sha(fixture.original))
        XCTAssertEqual(book.chapterCount, 948)
        let retained = try await fixture.service.retainedSourceURL(for: book)
        XCTAssertEqual(try Data(contentsOf: retained), fixture.original)
        try fixture.assertOriginalPreserved()
        try await fixture.service.close()
    }

    func testRealOriginalHeldPersistRejectionRetiresItsExactStageEvenWithoutOwnerMetadata() async throws {
        let capture = StagingHandoffCapture()
        let fixture = try StagingFixture(observer: { point, payload in
            try capture.capture(point, payload: payload)
            guard point == .handedOff else { return }
            // Change only this new private staging inode after real parse, not
            // selected input, RPC parameters, journal identity or any Core result.
            let writer = try FileHandle(forUpdating: payload)
            let first = try XCTUnwrap(try writer.read(upToCount: 1)?.first)
            try writer.seek(toOffset: 0)
            try writer.write(contentsOf: Data([first ^ 0xff]))
            try writer.synchronize()
            try writer.close()
            try FileManager.default.removeItem(at: try XCTUnwrap(capture.url))
        })
        defer { fixture.cleanUp() }
        let copy = try fixture.copyInput("actual-original-known-rejection.txt")
        fixture.client.hold("import.persist", advanceObserverDeadline: true)
        do { _ = try await fixture.service.importBook(at: copy); XCTFail("The original Core rejection has not been released") }
        catch ReaderLibraryError.operationPending(_) {}
        let journalURL = try fixture.onlyBusinessJournal()
        let journalBytes = try Data(contentsOf: journalURL)
        let journal = try XCTUnwrap(JSONSerialization.jsonObject(with: journalBytes) as? [String: Any])
        let id = try XCTUnwrap(journal["id"] as? String)
        let staged = fixture.sources.appendingPathComponent(".staging/" + (try XCTUnwrap(journal["stagedName"] as? String)))
        let inode = try stagingFileIdentity(staged)
        let changedStage = try Data(contentsOf: staged)
        XCTAssertNotEqual(changedStage, fixture.original)
        let sent = try XCTUnwrap(fixture.client.originalRequest("import.persist"))
        let parameters = try XCTUnwrap(JSONSerialization.jsonObject(with: sent.parameters) as? [String: Any])
        XCTAssertEqual(parameters["transactionId"] as? String, id)
        let terminal = try XCTUnwrap(fixture.client.originalTerminal("import.persist"))
        XCTAssertEqual(terminal.requestId, sent.requestID)
        XCTAssertEqual(terminal.type, "error")
        XCTAssertEqual(terminal.error?["code"] as? String, "INVALID_PARAMS")
        XCTAssertEqual(try Data(contentsOf: journalURL), journalBytes)
        let pending = try await fixture.service.recoverPendingImports()
        XCTAssertEqual(pending.map(\.id), [id], "No fresh read or missing metadata is an original ACK")
        XCTAssertEqual(try Data(contentsOf: journalURL), journalBytes)
        XCTAssertEqual(try stagingFileIdentity(staged), inode)
        XCTAssertEqual(try Data(contentsOf: staged), changedStage)
        XCTAssertEqual(fixture.client.count("import.persist"), 1)
        fixture.client.release()
        do { _ = try await fixture.service.recoverPendingImports(); XCTFail("The exact original Core rejection must be reported") }
        catch ReaderLibraryError.core(let code, _, _, _) { XCTAssertEqual(code, "INVALID_PARAMS") }
        XCTAssertEqual(try fixture.stagePayloads(), [])
        XCTAssertEqual(try fixture.ownerReceipts(), [])
        XCTAssertEqual(try fixture.businessJournals(), [])
        XCTAssertEqual(fixture.client.count("import.persist"), 1)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
        XCTAssertEqual(fixture.client.count("import.rollback"), 0)
        XCTAssertEqual(try Data(contentsOf: copy), fixture.original)
        try fixture.assertOriginalPreserved()
        try await fixture.service.close()
    }

    func testRealOriginalMoveThenDirectorySyncFailureWaitsForOriginalRollbackAndProtectsPreexistingSameSHA() async throws {
        for preexisting in [false, true] {
            let fault = StagingDirectorySyncFault()
            let fixture = try StagingFixture(observer: { try fault.observe($0, url: $1) },
                directorySync: { try fault.synchronize($0) })
            defer { fixture.cleanUp() }
            let copy = try fixture.copyInput("actual-original-fsync-fault.txt")
            let hash = StagingFixture.sha(fixture.original)
            let stable = fixture.sources.appendingPathComponent(hash + ".source")
            if preexisting { try fixture.original.write(to: stable, options: .atomic) }
            let oldIdentity = preexisting ? try stagingFileIdentity(stable) : nil
            fault.failOnce(in: preexisting ? fixture.sources.appendingPathComponent(".staging") : fixture.sources)
            fixture.client.hold("import.rollback", advanceObserverDeadline: true)
            do { _ = try await fixture.service.importBook(at: copy); XCTFail("The original rollback ACK is withheld") }
            catch ReaderLibraryError.operationPending(_) {}
            XCTAssertEqual(fault.failureCount, 1, "Fault is at commitSource's actual directory-sync boundary")
            let journalURL = try fixture.onlyBusinessJournal()
            let journalBytes = try Data(contentsOf: journalURL)
            let journal = try XCTUnwrap(JSONSerialization.jsonObject(with: journalBytes) as? [String: Any])
            let id = try XCTUnwrap(journal["id"] as? String)
            XCTAssertEqual(journal["phase"] as? String, "rollback")
            let sourceIdentity = try stagingFileIdentity(stable)
            let ownerName = try XCTUnwrap(try fixture.ownerReceipts().first)
            let ownerURL = fixture.sources.appendingPathComponent(".staging/.owners/" + ownerName)
            let owner = try JSONDecoder().decode(ReaderImportStagingOwner.self, from: Data(contentsOf: ownerURL))
            XCTAssertEqual(owner.transactionID, id)
            if preexisting {
                XCTAssertNil(owner.createdSource)
                XCTAssertEqual(sourceIdentity, oldIdentity)
                XCTAssertEqual(fault.registeredCount, 0)
            } else {
                let created = try XCTUnwrap(owner.createdSource)
                XCTAssertEqual(created.identity, sourceIdentity)
                XCTAssertEqual(created.name, stable.lastPathComponent)
                XCTAssertEqual(fault.registeredCount, 1, "Creation proof is published before failing directory synchronization")
            }
            let sent = try XCTUnwrap(fixture.client.originalRequest("import.rollback"))
            let terminal = try XCTUnwrap(fixture.client.originalTerminal("import.rollback"))
            XCTAssertEqual(terminal.requestId, sent.requestID)
            let result = try XCTUnwrap(terminal.data)
            let rollback = try XCTUnwrap(result["data"] as? [String: Any])
            XCTAssertEqual(result["kind"] as? String, "localBook")
            XCTAssertEqual(rollback["book_id"] as? String, "local:" + hash)
            XCTAssertEqual(rollback["restored"] as? Bool, true)
            XCTAssertEqual(try Data(contentsOf: stable), fixture.original)
            let stillPending = try await fixture.service.recoverPendingImports()
            XCTAssertEqual(stillPending.map(\.id), [id])
            XCTAssertEqual(try Data(contentsOf: journalURL), journalBytes)
            XCTAssertEqual(try stagingFileIdentity(stable), sourceIdentity)
            XCTAssertEqual(fixture.client.count("import.rollback"), 1)
            fixture.client.release()
            do { _ = try await fixture.service.recoverPendingImports(); XCTFail("Original rollback must project a confirmed import failure") }
            catch let completion as ReaderImportRollbackCompletion {
                XCTAssertEqual(completion.operationId, id)
                XCTAssertTrue(completion.originalFailure?.contains(NSPOSIXErrorDomain) == true, "The original sync failure is preserved")
            }
            XCTAssertEqual(fixture.client.count("import.rollback"), 1)
            XCTAssertEqual(fixture.client.count("import.persist"), 1)
            XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
            XCTAssertEqual(try fixture.stagePayloads(), [])
            XCTAssertEqual(try fixture.ownerReceipts(), [])
            XCTAssertEqual(try fixture.businessJournals(), [])
            if preexisting {
                XCTAssertEqual(try stagingFileIdentity(stable), oldIdentity)
                XCTAssertEqual(try Data(contentsOf: stable), fixture.original)
            } else { XCTAssertFalse(FileManager.default.fileExists(atPath: stable.path)) }
            XCTAssertEqual(try Data(contentsOf: copy), fixture.original)
            try fixture.assertOriginalPreserved()
            try await fixture.service.close()
        }
    }

    func testRealOriginalHandoffObserverIOFailureBeforePersistSendRetiresOnlyThisUndispatchedIntent() async throws {
        let capture = StagingHandoffCapture()
        let fixture = try StagingFixture(observer: { point, payload in
            try capture.capture(point, payload: payload)
            if point == .handedOff { throw NSError(domain: NSPOSIXErrorDomain, code: Int(EIO)) }
        })
        defer { fixture.cleanUp() }
        let copy = try fixture.copyInput("actual-original-handoff-io-fault.txt")
        do { _ = try await fixture.service.importBook(at: copy); XCTFail("The durable handoff observer injects the exact pre-send failure") }
        catch let error as NSError { XCTAssertEqual(error.domain, NSPOSIXErrorDomain); XCTAssertEqual(error.code, Int(EIO)) }
        let owner = try JSONDecoder().decode(ReaderImportStagingOwner.self, from: try XCTUnwrap(capture.bytes))
        XCTAssertEqual(owner.phase, .handedOff, "Production persisted the resource handoff before this observer fault")
        XCTAssertEqual(fixture.client.count("import.parse"), 1)
        XCTAssertEqual(fixture.client.count("import.persist"), 0)
        XCTAssertEqual(fixture.client.count("import.rollback"), 0)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
        XCTAssertEqual(try fixture.stagePayloads(), [])
        XCTAssertEqual(try fixture.ownerReceipts(), [])
        XCTAssertEqual(try fixture.businessJournals(), [])
        let pending = try await fixture.service.recoverPendingImports()
        XCTAssertTrue(pending.isEmpty, "This proven pre-send failure cannot become a permanent unknown operation")
        XCTAssertEqual(fixture.client.count("import.persist"), 0)
        XCTAssertEqual(try Data(contentsOf: copy), fixture.original)
        try fixture.assertOriginalPreserved()
        try await fixture.service.close()
    }

    func testActualTaskCancellationBeforeFirstCopiedByteReleasesOwnedStageLeaseAndBothFDs() async throws {
        let reached = expectation(description: "Actual durable owner and payload inode exist before byte one")
        let gate = StagingCopyCancellationGate(reached: { reached.fulfill() })
        let fixture = try StagingFixture(observer: { try gate.observe($0, url: $1) })
        defer { gate.release(); fixture.cleanUp() }
        let copy = try fixture.copyInput("actual-original-task-cancellation.txt")
        let importing = Task { try await fixture.service.importBook(at: copy) }
        await fulfillment(of: [reached], timeout: 30)
        guard gate.didReach else {
            importing.cancel(); gate.release(); _ = try? await importing.value
            throw StagingTestFailure.missingOriginalTerminal
        }
        importing.cancel() // This is the tested action, not teardown cleanup.
        gate.release()
        do { _ = try await importing.value; XCTFail("Actual Task.cancel must be observed before copying any byte") }
        catch is CancellationError {}
        XCTAssertEqual(gate.firstChunkCount, 0)
        XCTAssertEqual(gate.closedSourceResults, [true], "Observer reports the actual Darwin.close return")
        XCTAssertEqual(gate.closedPayloadResults, [true])
        XCTAssertEqual(try fixture.stagePayloads(), [])
        XCTAssertEqual(try fixture.ownerReceipts(), [])
        let nextLease = try ReaderImportStagingLease(stagingURL: fixture.sources.appendingPathComponent(".staging"))
        nextLease.release()
        let recovered = try await fixture.service.recoverPendingImports()
        XCTAssertTrue(recovered.isEmpty, "The actor's active-import reservation is released too")
        XCTAssertEqual(fixture.client.count("import.parse"), 0)
        XCTAssertEqual(fixture.client.count("import.persist"), 0)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
        XCTAssertEqual(try Data(contentsOf: copy), fixture.original)
        try fixture.assertOriginalPreserved()
        try await fixture.service.close()
    }

    func testRealOriginalLateShelfACKKeepsSourceOwnershipUntilTheOriginalFinalize() async throws {
        let fixture = try StagingFixture()
        defer { fixture.cleanUp() }
        fixture.client.hold("bookshelf.add", advanceObserverDeadline: true)
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("Original shelf ACK is held") }
        catch ReaderLibraryError.operationPending(_) {}
        let journalURL = try fixture.onlyBusinessJournal()
        let bytes = try Data(contentsOf: journalURL)
        let journal = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertEqual(journal["phase"] as? String, "shelfAwaiting")
        let stable = fixture.sources.appendingPathComponent(StagingFixture.sha(fixture.original) + ".source")
        let identity = try stagingFileIdentity(stable)
        XCTAssertEqual(try fixture.ownerReceipts().count, 1)
        let pending = try await fixture.service.recoverPendingImports()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(try Data(contentsOf: journalURL), bytes)
        XCTAssertEqual(try stagingFileIdentity(stable), identity)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 1)
        XCTAssertEqual(fixture.client.count("import.finalize"), 0)
        fixture.client.release()
        let completed = try await fixture.service.recoverPendingImports()
        XCTAssertTrue(completed.isEmpty)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 1)
        XCTAssertEqual(fixture.client.count("import.finalize"), 1)
        XCTAssertEqual(fixture.client.count("import.rollback"), 0)
        XCTAssertEqual(try stagingFileIdentity(stable), identity)
        XCTAssertEqual(try Data(contentsOf: stable), fixture.original)
        XCTAssertEqual(try fixture.ownerReceipts(), [])
        XCTAssertEqual(try fixture.stagePayloads(), [])
        try fixture.assertOriginalPreserved()
        try await fixture.service.close()
    }

    func testRealOriginalColdShelfAwaitingKeepsUnknownOutcomeWithoutRedispatch() async throws {
        let fixture = try StagingFixture()
        defer { fixture.cleanUp() }
        fixture.client.hold("bookshelf.add", advanceObserverDeadline: true)
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("Original shelf ACK is held") }
        catch ReaderLibraryError.operationPending(_) {}
        XCTAssertEqual(try fixture.client.originalTerminal("bookshelf.add")?.type, "result")
        let journalURL = try fixture.onlyBusinessJournal()
        let journalBytes = try Data(contentsOf: journalURL)
        let journal = try XCTUnwrap(JSONSerialization.jsonObject(with: journalBytes) as? [String: Any])
        XCTAssertEqual(journal["phase"] as? String, "shelfAwaiting")
        let originalPending = try await fixture.service.pendingImports()
        XCTAssertEqual(originalPending.count, 1)
        XCTAssertEqual(originalPending.first?.requiresReconciliation, true)
        let stable = fixture.sources.appendingPathComponent(StagingFixture.sha(fixture.original) + ".source")
        let stableIdentity = try stagingFileIdentity(stable)
        let ownerNames = try fixture.ownerReceipts()
        XCTAssertEqual(ownerNames.count, 1)
        let ownerURL = fixture.sources.appendingPathComponent(".staging/.owners")
            .appendingPathComponent(try XCTUnwrap(ownerNames.first))
        let ownerBytes = try Data(contentsOf: ownerURL)
        let ownerIdentity = try stagingFileIdentity(ownerURL)

        // Lose only this private process's in-memory original reply. Reopen the
        // same real Core storage and retained source, never a fabricated record.
        fixture.client.destroy()
        let core = fixture.root.appendingPathComponent("Core")
        let reopenedClient = try StagingCoreGate(storage: core)
        defer { reopenedClient.destroy() }
        let reopened = try ReaderLibraryService(storageURL: core, sourceURL: fixture.sources,
            client: reopenedClient, timing: reopenedClient.timing)
        let remaining = try await reopened.recoverPendingImports()
        XCTAssertEqual(remaining, originalPending)
        for method in ["bookshelf.add", "import.persist", "import.rollback", "import.finalize"] {
            XCTAssertEqual(reopenedClient.count(method), 0, "Cold recovery cannot dispatch \(method) to resolve an unknown shelf ACK")
        }
        XCTAssertEqual(try Data(contentsOf: journalURL), journalBytes)
        XCTAssertEqual(try stagingFileIdentity(stable), stableIdentity)
        XCTAssertEqual(try Data(contentsOf: stable), fixture.original)
        XCTAssertEqual(try fixture.ownerReceipts(), ownerNames)
        XCTAssertEqual(try Data(contentsOf: ownerURL), ownerBytes)
        XCTAssertEqual(try stagingFileIdentity(ownerURL), ownerIdentity)
        try fixture.assertOriginalPreserved()
        try await reopened.close()
    }

    func testRealOriginalLateFinalizeACKRetiresOnlyOwnerAndKeepsTheReadableSource() async throws {
        let fixture = try StagingFixture()
        defer { fixture.cleanUp() }
        fixture.client.hold("import.finalize", advanceObserverDeadline: true)
        let result = try await fixture.service.importBook(at: fixture.input)
        XCTAssertTrue(result.finalizationPending)
        let stable = try await fixture.service.retainedSourceURL(for: result.book)
        let identity = try stagingFileIdentity(stable)
        let journalURL = try fixture.onlyBusinessJournal()
        let bytes = try Data(contentsOf: journalURL)
        let journal = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertEqual(journal["phase"] as? String, "finalize")
        XCTAssertEqual(try fixture.ownerReceipts().count, 1)
        let pending = try await fixture.service.recoverPendingImports()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(fixture.client.count("import.finalize"), 1)
        XCTAssertEqual(try Data(contentsOf: journalURL), bytes)
        XCTAssertEqual(try stagingFileIdentity(stable), identity)
        fixture.client.release()
        let completed = try await fixture.service.recoverPendingImports()
        XCTAssertTrue(completed.isEmpty)
        XCTAssertEqual(fixture.client.count("import.finalize"), 1)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 1)
        XCTAssertEqual(fixture.client.count("import.rollback"), 0)
        XCTAssertEqual(try stagingFileIdentity(stable), identity)
        XCTAssertEqual(try Data(contentsOf: stable), fixture.original)
        XCTAssertEqual(try fixture.ownerReceipts(), [])
        XCTAssertEqual(try fixture.stagePayloads(), [])
        try fixture.assertOriginalPreserved()
        try await fixture.service.close()
    }

    func testRealOriginalLiveImportLeaseBlocksAnotherActorRecoveryUntilTheReadFinishes() async throws {
        let fixture = try StagingFixture()
        defer { fixture.cleanUp() }
        fixture.client.hold("import.parse", advanceObserverDeadline: false)
        let held = expectation(description: "Real Core parse terminal reached the original owner")
        fixture.client.onHeld = { held.fulfill() }
        let importing = Task { try await fixture.service.importBook(at: fixture.input) }
        defer { fixture.client.release() }
        await fulfillment(of: [held], timeout: 30)
        do {
            guard fixture.client.hasHeldTerminal else { throw StagingTestFailure.missingOriginalTerminal }
            let otherCore = fixture.root.appendingPathComponent("OtherCore")
            let otherGate = try StagingCoreGate(storage: otherCore)
            defer { otherGate.destroy() }
            // Separate Core storage: this tests the common resource lease without
            // opening a second runtime against the first runtime's database.
            let other = try ReaderLibraryService(storageURL: otherCore, sourceURL: fixture.sources, client: otherGate, timing: otherGate.timing)
            let names = try fixture.stagePayloads()
            XCTAssertEqual(names.count, 1)
            let name = try XCTUnwrap(names.first)
            let payload = fixture.sources.appendingPathComponent(".staging/" + name)
            let before = try Data(contentsOf: payload)
            do { _ = try await other.recoverPendingImports(); XCTFail("The live process owns the lease across await") }
            catch ReaderLibraryError.busy {}
            XCTAssertEqual(try Data(contentsOf: payload), before)
            XCTAssertEqual(otherGate.count("import.parse"), 0)
            XCTAssertEqual(otherGate.count("import.persist"), 0)
            fixture.client.release()
            let imported = try await importing.value
            let retained = try await fixture.service.retainedSourceURL(for: imported.book)
            XCTAssertEqual(try Data(contentsOf: retained), fixture.original)
            try fixture.assertOriginalPreserved()
            try await other.close()
            try await fixture.service.close()
        } catch {
            fixture.client.release()
            importing.cancel()
            _ = try? await importing.value // Do not destroy the client under an in-flight test task.
            throw error
        }
    }

    func testMalformedOriginalBusinessJournalPreventsOwnedStageRetirementAndAnyReplay() async throws {
        let snapshot = StagingCrashSnapshot(point: .payloadBound)
        let fixture = try StagingFixture(observer: { try snapshot.capture($0, payload: $1) })
        defer { fixture.cleanUp(); snapshot.cleanUp() }
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("Capture the actual owned precommit stage") }
        catch StagingCrashSnapshot.Captured.stop {}
        let sourceRoot = try XCTUnwrap(snapshot.sources)
        let receipt = try XCTUnwrap(snapshot.receipt)
        let payload = try XCTUnwrap(snapshot.payload)
        let receiptBefore = try Data(contentsOf: receipt)
        let payloadBefore = try Data(contentsOf: payload)
        let operations = sourceRoot.appendingPathComponent(".operations")
        try FileManager.default.createDirectory(at: operations, withIntermediateDirectories: true)
        let journal = operations.appendingPathComponent("legacy-unknown.json")
        let originalJournalBytes = Data("{incomplete original journal".utf8)
        try originalJournalBytes.write(to: journal)
        let core = fixture.root.appendingPathComponent("MalformedJournalRecoveryCore")
        let gate = try StagingCoreGate(storage: core)
        defer { gate.destroy() }
        let service = try ReaderLibraryService(storageURL: core, sourceURL: sourceRoot, client: gate, timing: gate.timing)
        do { _ = try await service.recoverPendingImports(); XCTFail("An unreadable original journal is never absence of ownership") }
        catch is DecodingError {}
        XCTAssertEqual(try Data(contentsOf: receipt), receiptBefore)
        XCTAssertEqual(try Data(contentsOf: payload), payloadBefore)
        XCTAssertEqual(try Data(contentsOf: journal), originalJournalBytes)
        XCTAssertEqual(gate.count("import.parse"), 0)
        XCTAssertEqual(gate.count("import.persist"), 0)
        try fixture.assertOriginalPreserved()
        // close() also consults original journals; direct fixture-client destroy
        // is test teardown, never a claim that the business owner was resolved.
    }

    func testRecoveryPreservesLegacyBareStagingMalformedOwnersAndUnboundPayloadIdentity() async throws {
        let snapshot = StagingCrashSnapshot(point: .payloadBound)
        let fixture = try StagingFixture(observer: { try snapshot.capture($0, payload: $1) })
        defer { fixture.cleanUp(); snapshot.cleanUp() }
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("Capture an actual empty bound payload") }
        catch StagingCrashSnapshot.Captured.stop {}
        let sourceRoot = try XCTUnwrap(snapshot.sources)
        let ownerURL = try XCTUnwrap(snapshot.receipt)
        let payload = try XCTUnwrap(snapshot.payload)
        let actualOwner = try Data(contentsOf: ownerURL)
        var unbound = try XCTUnwrap(JSONSerialization.jsonObject(with: actualOwner) as? [String: Any])
        unbound.removeValue(forKey: "payloadIdentity") // Crash in create-before-binding gap must be conservative.
        try JSONSerialization.data(withJSONObject: unbound).write(to: ownerURL, options: .atomic)
        let owners = ownerURL.deletingLastPathComponent()
        let malformed = owners.appendingPathComponent(UUID().uuidString.lowercased() + ".json")
        let malformedBytes = Data("{not a receipt".utf8)
        try malformedBytes.write(to: malformed)
        var unknownVersion = unbound
        let unknownID = UUID().uuidString.lowercased()
        unknownVersion["id"] = unknownID
        unknownVersion["stagedName"] = "../must-not-traverse.source"
        unknownVersion["version"] = 99
        let unknown = owners.appendingPathComponent(unknownID + ".json")
        let unknownBytes = try JSONSerialization.data(withJSONObject: unknownVersion)
        try unknownBytes.write(to: unknown)
        let linked = owners.appendingPathComponent(UUID().uuidString.lowercased() + ".json")
        try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: fixture.input)
        let legacy = sourceRoot.appendingPathComponent(".staging/legacy-no-owner.source")
        try fixture.original.write(to: legacy)
        let gate = try StagingCoreGate(storage: fixture.root.appendingPathComponent("UnknownRecoveryCore"))
        defer { gate.destroy() }
        let service = try ReaderLibraryService(storageURL: fixture.root.appendingPathComponent("UnknownRecoveryCore"),
            sourceURL: sourceRoot, client: gate, timing: gate.timing)
        _ = try await service.recoverPendingImports()
        XCTAssertTrue(FileManager.default.fileExists(atPath: payload.path))
        XCTAssertEqual(try Data(contentsOf: legacy), fixture.original)
        XCTAssertEqual(try Data(contentsOf: malformed), malformedBytes)
        XCTAssertEqual(try Data(contentsOf: unknown), unknownBytes)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: linked.path), fixture.input.path)
        XCTAssertEqual(gate.count("import.parse"), 0)
        XCTAssertEqual(gate.count("import.persist"), 0)
        try fixture.assertOriginalPreserved()
        try await service.close()
        try await fixture.service.close()
    }
}

private enum StagingTestFailure: Error { case missingOriginalTerminal }

@MainActor
private final class StagingFixture {
    let input: URL
    let original: Data
    let root: URL
    let sources: URL
    let client: StagingCoreGate
    let service: ReaderLibraryService
    init(observer: @escaping ReaderImportStagingObserver = { _, _ in },
         directorySync: @escaping @Sendable (URL) throws -> Void = { try ReaderImportStagingLease.synchronizeDirectory($0) }) throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        input = documents.appendingPathComponent("仙子请听我解释.txt")
        original = try Data(contentsOf: input) // Absence fails; never XCTSkip or invented prose.
        guard original.count == 8_871_723, Self.sha(original) == "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5" else {
            throw ReaderLibraryError.invalidResponse("real original fixture identity")
        }
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderImportOwner-" + UUID().uuidString)
        sources = root.appendingPathComponent("Sources")
        client = try StagingCoreGate(storage: root.appendingPathComponent("Core"))
        service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: sources,
            client: client, timing: client.timing, importStagingObserver: observer, importSourceDirectorySync: directorySync)
    }
    func copyInput(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.copyItem(at: input, to: url)
        XCTAssertEqual(try Data(contentsOf: url), original)
        return url
    }
    func assertOriginalPreserved() throws { XCTAssertEqual(try Data(contentsOf: input), original) }
    func stagePayloads() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: sources.appendingPathComponent(".staging").path).filter { $0.hasSuffix(".source") }.sorted()
    }
    func ownerReceipts() throws -> [String] {
        let directory = sources.appendingPathComponent(".staging/.owners")
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".json") }.sorted()
    }
    func businessJournals() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: sources.appendingPathComponent(".operations"), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
    }
    func onlyBusinessJournal() throws -> URL {
        let files = try businessJournals()
        XCTAssertEqual(files.count, 1)
        return try XCTUnwrap(files.first)
    }
    func cleanUp() { client.release(); client.destroy(); try? FileManager.default.removeItem(at: root) }
    static func sha(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
}

private func stagingFileIdentity(_ url: URL) throws -> ReaderImportStagingOwner.FileIdentity {
    var value = stat()
    guard lstat(url.path, &value) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    guard (value.st_mode & S_IFMT) == S_IFREG else { throw ReaderLibraryError.invalidResponse("expected owned regular file") }
    return .init(value)
}

private final class StagingDirectorySyncFault: @unchecked Sendable {
    private let lock = NSLock()
    private var target: URL?
    private var failures = 0
    private var registrations = 0
    var failureCount: Int { lock.lock(); defer { lock.unlock() }; return failures }
    var registeredCount: Int { lock.lock(); defer { lock.unlock() }; return registrations }
    func failOnce(in url: URL) { lock.lock(); target = url.standardizedFileURL; lock.unlock() }
    func observe(_ point: ReaderImportStagingCheckpoint, url: URL) throws {
        if point == .retainedSourceRegistered { lock.lock(); registrations += 1; lock.unlock() }
    }
    func synchronize(_ url: URL) throws {
        lock.lock()
        let fail = target == url.standardizedFileURL && failures == 0
        if fail { failures += 1 }
        lock.unlock()
        if fail { throw NSError(domain: NSPOSIXErrorDomain, code: Int(EIO)) }
        try ReaderImportStagingLease.synchronizeDirectory(url)
    }
}

private final class StagingCopyCancellationGate: @unchecked Sendable {
    private let condition = NSCondition()
    private let reached: @Sendable () -> Void
    private var arrived = false
    private var released = false
    private var chunks = 0
    private var sourceCloses: [Bool] = []
    private var payloadCloses: [Bool] = []
    init(reached: @escaping @Sendable () -> Void) { self.reached = reached }
    var didReach: Bool { condition.lock(); defer { condition.unlock() }; return arrived }
    var firstChunkCount: Int { condition.lock(); defer { condition.unlock() }; return chunks }
    var closedSourceResults: [Bool] { condition.lock(); defer { condition.unlock() }; return sourceCloses }
    var closedPayloadResults: [Bool] { condition.lock(); defer { condition.unlock() }; return payloadCloses }
    func observe(_ point: ReaderImportStagingCheckpoint, url: URL) throws {
        condition.lock(); defer { condition.unlock() }
        switch point {
        case .payloadBound:
            arrived = true
            reached()
            while !released { condition.wait() }
        case .firstChunkWritten: chunks += 1
        case .sourceDescriptorClosed(let succeeded): sourceCloses.append(succeeded)
        case .payloadDescriptorClosed(let succeeded): payloadCloses.append(succeeded)
        default: break
        }
    }
    func release() { condition.lock(); released = true; condition.broadcast(); condition.unlock() }
}

private final class StagingFault: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    func didRun() { lock.lock(); value += 1; lock.unlock() }
}

private final class StagingCrashSnapshot: @unchecked Sendable {
    enum Captured: Error { case stop }
    let point: ReaderImportStagingCheckpoint
    private(set) var sources: URL?
    private(set) var payload: URL?
    private(set) var receipt: URL?
    init(point: ReaderImportStagingCheckpoint) { self.point = point }
    func capture(_ point: ReaderImportStagingCheckpoint, payload original: URL) throws {
        guard point == self.point else { return }
        let snapshot = original.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("CrashSources-" + UUID().uuidString)
        let stage = snapshot.appendingPathComponent(".staging", isDirectory: true)
        let owners = stage.appendingPathComponent(".owners", isDirectory: true)
        try FileManager.default.createDirectory(at: owners, withIntermediateDirectories: true)
        let ownerName = original.deletingPathExtension().lastPathComponent + ".json"
        let sourceReceipt = original.deletingLastPathComponent().appendingPathComponent(".owners/" + ownerName)
        let capturedReceipt = owners.appendingPathComponent(ownerName)
        let capturedPayload = stage.appendingPathComponent(original.lastPathComponent)
        try Data(contentsOf: sourceReceipt).write(to: capturedReceipt, options: .atomic)
        try FileManager.default.linkItem(at: original, to: capturedPayload)
        sources = snapshot; payload = capturedPayload; receipt = capturedReceipt
        throw Captured.stop
    }
    func cleanUp() { if let sources { try? FileManager.default.removeItem(at: sources) } }
}

private final class StagingHandoffCapture: @unchecked Sendable {
    private(set) var url: URL?
    private(set) var bytes: Data?
    func capture(_ point: ReaderImportStagingCheckpoint, payload: URL) throws {
        guard point == .handedOff else { return }
        let name = payload.deletingPathExtension().lastPathComponent + ".json"
        let receipt = payload.deletingLastPathComponent().appendingPathComponent(".owners/" + name)
        url = receipt; bytes = try Data(contentsOf: receipt)
    }
}

/// The actual pinned Core executes every command. Only one original terminal is
/// retained, then released; no response body, book text or ACK is synthesized.
final class StagingCoreGate: ReaderCoreEventClient, @unchecked Sendable {
    private let native: ReaderCoreClient
    private let lock = NSLock()
    struct SentRequest { let requestID: UInt64; let parameters: Data }
    private var counts: [String: Int] = [:]
    private var methods: [UInt64: String] = [:]
    private var requests: [String: SentRequest] = [:]
    private var terminals: [String: Data] = [:]
    private var heldMethod: String?
    private var heldID: UInt64?
    private var observedCancelIDs: [UInt64] = []
    private var held: Result<ReaderCoreEvent, ReaderCoreClientError>?
    private var ready = false
    private var advancesDeadline = false
    private var clock: TimeInterval = 0
    var onHeld: (@Sendable () -> Void)?
    init(storage: URL) throws {
        try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        native = try ReaderCoreClient(configJSON: JSONSerialization.data(withJSONObject: ["dataDirectory": storage.path]))
    }
    var timing: ReaderRequestTiming { .init(now: { self.now }, suspend: { await Task.yield() }) }
    var now: TimeInterval { lock.lock(); defer { lock.unlock() }; return ProcessInfo.processInfo.systemUptime + clock }
    var hasHeldTerminal: Bool { lock.lock(); defer { lock.unlock() }; return held != nil }
    var heldRequestID: UInt64? { lock.lock(); defer { lock.unlock() }; return heldID }
    var cancelRequestIDs: [UInt64] { lock.lock(); defer { lock.unlock() }; return observedCancelIDs }
    func count(_ name: String) -> Int { lock.lock(); defer { lock.unlock() }; return counts[name, default: 0] }
    func originalRequest(_ method: String) -> SentRequest? { lock.lock(); defer { lock.unlock() }; return requests[method] }
    func originalTerminal(_ method: String) throws -> ReaderCoreEvent? {
        lock.lock(); let bytes = terminals[method]; lock.unlock()
        return try bytes.map { try ReaderCoreEvent(data: $0) }
    }
    func hold(_ method: String, advanceObserverDeadline: Bool) {
        lock.lock(); defer { lock.unlock() }
        heldMethod = method; advancesDeadline = advanceObserverDeadline
    }
    func release() { lock.lock(); ready = true; lock.unlock() }
    @discardableResult
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        let id = try native.send(method: method, requestId: requestId, params: params)
        counts[method, default: 0] += 1
        methods[requestId] = method
        if requests[method] == nil {
            requests[method] = .init(requestID: requestId, parameters: try JSONSerialization.data(withJSONObject: params, options: [.sortedKeys]))
        }
        if method == heldMethod && heldID == nil { heldID = requestId }
        return id
    }
    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        lock.lock(); defer { lock.unlock() }
        guard requestId == heldID else {
            let result = native.pollEvent(requestId: requestId)
            if case .success(let event)? = result, ["result", "error"].contains(event.type), let method = methods[requestId] {
                terminals[method] = event.rawData
            }
            return result
        }
        if held == nil, let event = native.pollEvent(requestId: requestId) {
            if case .success(let value) = event, ["result", "error"].contains(value.type) {
                held = event
                if let method = methods[requestId] { terminals[method] = value.rawData }
                if advancesDeadline { clock += 200 }
                onHeld?()
            } else { return event }
        }
        guard ready, let terminal = held else { return nil }
        held = nil; heldID = nil; heldMethod = nil; ready = false
        return terminal
    }
    func retireReadRequest(requestId: UInt64) { lock.lock(); defer { lock.unlock() }; native.retireReadRequest(requestId: requestId) }
    func cancel(requestId: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        try native.cancel(requestId: requestId)
        observedCancelIDs.append(requestId)
    }
    func destroy() { lock.lock(); defer { lock.unlock() }; native.destroy() }
}
