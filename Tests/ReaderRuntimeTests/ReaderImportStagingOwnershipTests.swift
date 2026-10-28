import Foundation
import CryptoKit
import Darwin
import XCTest
import SQLite3
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
        XCTAssertEqual(fixture.client.count("import.local.persist.v2"), 0)
        XCTAssertEqual(fixture.client.count("import.local.publish.v2"), 0)
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
        XCTAssertEqual(fixture.client.count("import.local.persist.v2"), 0)
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
        XCTAssertEqual(fixture.client.count("import.local.persist.v2"), 0)
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
        XCTAssertEqual(fixture.client.count("import.local.persist.v2"), 0)
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
            XCTAssertEqual(fixture.client.count("import.local.persist.v2"), 0)
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
            for method in ["import.parse", "import.local.persist.v2", "import.local.publish.v2", "import.local.finalize.v2", "import.local.rollback.v2"] {
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
        fixture.client.hold("import.local.persist.v2", advanceObserverDeadline: true)
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("The original persist envelope is held") }
        catch ReaderLibraryError.operationPending(_) {}
        let journalURL = try fixture.onlyBusinessJournal()
        let journal = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: journalURL)) as? [String: Any])
        XCTAssertEqual(journal["phase"] as? String, "v2PersistAwaiting")
        XCTAssertEqual(journal["protocolGeneration"] as? Int, 2)
        XCTAssertEqual(journal["requiredCapability"] as? String, "import.local.receipts.v2")
        XCTAssertNil(journal["rollbackToken"]); XCTAssertNil(journal["shelfParameters"])
        let owner = try JSONDecoder().decode(ReaderImportStagingOwner.self, from: try XCTUnwrap(receipt.bytes))
        XCTAssertEqual(journal["id"] as? String, owner.transactionID)
        XCTAssertEqual(journal["hash"] as? String, owner.sha256)
        XCTAssertEqual(try Data(contentsOf: fixture.sources.appendingPathComponent(".staging/" + owner.stagedName)), fixture.original)
        // Query obtains the actual stored original ACK in a new envelope. It
        // need not wait for the lost transport, nor redispatch materialization.
        let completed = try await fixture.service.recoverPendingImports()
        XCTAssertTrue(completed.isEmpty)
        XCTAssertEqual(fixture.client.count("import.local.persist.v2"), 1)
        XCTAssertEqual(fixture.client.count("import.local.publish.v2"), 1)
        XCTAssertEqual(fixture.client.count("import.local.finalize.v2"), 1)
        XCTAssertEqual(fixture.client.count("import.local.settle.v2"), 1)
        XCTAssertEqual(try fixture.ownerReceipts(), []); XCTAssertEqual(try fixture.businessJournals(), [])
        let late = await fixture.service.unresolvedWrites.count
        XCTAssertEqual(late, 1, "The unobserved original transport keeps its durable-confirmed RAM proof")
        fixture.client.release()
        do { let pending = try await fixture.service.recoverPendingImports(); XCTAssertTrue(pending.isEmpty) }
        let afterLate = await fixture.service.unresolvedWrites.count
        XCTAssertEqual(afterLate, 0)
        XCTAssertEqual(fixture.client.count("import.local.persist.v2"), 1)
        let stable = fixture.sources.appendingPathComponent(StagingFixture.sha(fixture.original) + ".source")
        XCTAssertEqual(try Data(contentsOf: stable), fixture.original)
        try fixture.assertOriginalPreserved(); try await fixture.service.close()
    }

    func testRealOriginalFreshV2NonAdmissionRetiresItsExactStageEvenWithoutOwnerMetadata() async throws {
        let capture = StagingHandoffCapture()
        let fixture = try StagingFixture(observer: { try capture.capture($0, payload: $1) })
        defer { fixture.cleanUp() }
        fixture.client.beforeFirstSend("import.local.persist.v2") {
            let owner = try JSONDecoder().decode(ReaderImportStagingOwner.self, from: try XCTUnwrap(capture.bytes))
            let payload = fixture.sources.appendingPathComponent(".staging/" + owner.stagedName)
            let writer = try FileHandle(forUpdating: payload)
            defer { try? writer.close() }
            let first = try XCTUnwrap(try writer.read(upToCount: 1)?.first)
            try writer.seek(toOffset: 0); try writer.write(contentsOf: Data([first ^ 0xff])); try writer.synchronize()
            try FileManager.default.removeItem(at: try XCTUnwrap(capture.url))
        }
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("A first transport preflight refusal is not an import") }
        catch let completion as ReaderImportRollbackCompletion { XCTAssertFalse(completion.operationId.isEmpty) }
        let sent = try XCTUnwrap(fixture.client.originalRequest("import.local.persist.v2"))
        let terminal = try XCTUnwrap(fixture.client.originalTerminal("import.local.persist.v2"))
        XCTAssertEqual(terminal.requestId, sent.requestID); XCTAssertEqual(terminal.type, "error")
        XCTAssertEqual(try stagingErrorDetails(terminal)["localImportDisposition"] as? String, "nonAdmitted")
        XCTAssertEqual(fixture.client.count("import.local.persist.v2"), 1)
        XCTAssertEqual(fixture.client.count("import.local.settle.v2"), 0)
        XCTAssertEqual(fixture.client.count("import.local.publish.v2"), 0)
        XCTAssertEqual(try fixture.stagePayloads(), []); XCTAssertEqual(try fixture.ownerReceipts(), [])
        XCTAssertEqual(try fixture.businessJournals(), [])
        try fixture.assertOriginalPreserved(); try await fixture.service.close()
    }

    func testRealOriginalColdV2PersistLossQueriesFrozenPreviewWithoutReparseOrRedispatch() async throws {
        let fixture = try StagingFixture()
        defer { fixture.cleanUp() }
        fixture.client.hold("import.local.persist.v2", advanceObserverDeadline: true)
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("Original persist envelope is lost") }
        catch ReaderLibraryError.operationPending(_) {}
        let journal = try stagingObject(Data(contentsOf: fixture.onlyBusinessJournal()))
        let state = try XCTUnwrap(journal["localV2"] as? [String: Any])
        let preview = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(state["preview"] as? String)))
        let binding = try stagingBinding(journal)
        let summary = try XCTUnwrap(stagingObject(preview)["summary"] as? [String: Any])
        XCTAssertEqual(binding["format"] as? String, summary["format"] as? String)
        XCTAssertEqual((binding["sourceBytes"] as? NSNumber)?.uint64Value, UInt64(fixture.original.count))
        let staged = fixture.sources.appendingPathComponent(".staging/" + (try XCTUnwrap(journal["stagedName"] as? String)))
        let identity = try stagingFileIdentity(staged)
        fixture.client.destroy() // The only lost fact is this process's wire envelope.
        let (gate, reopened) = try fixture.reopen()
        defer { gate.destroy() }
        let remaining = try await reopened.recoverPendingImports()
        XCTAssertTrue(remaining.isEmpty, "One cold pass consumes Core's original persist ACK and finishes")
        let query = try stagingObject(XCTUnwrap(gate.originalRequest("import.local.query.v2")).parameters)
        XCTAssertEqual(query["stage"] as? String, "persist")
        XCTAssertEqual(try stagingJSON(XCTUnwrap(query["parsed"] as? [String: Any])), preview)
        XCTAssertEqual(try stagingJSON(XCTUnwrap(query["binding"] as? [String: Any])), try stagingJSON(stagingBinding(journal)))
        for method in ["import.parse", "import.local.persist.v2", "bookshelf.add", "import.persist"] { XCTAssertEqual(gate.count(method), 0) }
        for method in ["import.local.publish.v2", "import.local.finalize.v2", "import.local.settle.v2"] { XCTAssertEqual(gate.count(method), 1) }
        let stable = fixture.stableSource
        XCTAssertEqual(try stagingFileIdentity(stable), identity); XCTAssertEqual(try Data(contentsOf: stable), fixture.original)
        XCTAssertEqual(try fixture.ownerReceipts(), []); XCTAssertEqual(try fixture.businessJournals(), [])
        try fixture.assertOriginalPreserved(); try await reopened.close()
    }

    func testRealOriginalColdV2LostPublishRefusalRollsBackInOnePassAfterExactMetadataRestore() async throws {
        let terminalCapture = StagingJournalCapture(point: .localV2TerminalDurable)
        let fixture = try StagingFixture()
        defer { fixture.cleanUp() }
        let fault = StagingMetadataCapture()
        fixture.client.beforeFirstSend("import.local.publish.v2") { try fault.change(fixture) }
        fixture.client.hold("import.local.publish.v2", advanceObserverDeadline: true)
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("Original business refusal envelope is lost") }
        catch ReaderLibraryError.operationPending(_) {}
        let negative = try stagingReceipt(XCTUnwrap(fixture.client.originalTerminal("import.local.publish.v2")), stage: "publish")
        XCTAssertEqual(negative["outcome"] as? String, "rejected")
        XCTAssertTrue(negative["data"] is NSNull); XCTAssertNotNil(negative["error"] as? [String: Any])
        try fault.restore(fixture) // Restore exact original bytes before opening a new runtime.
        fixture.client.destroy()
        let (gate, reopened) = try fixture.reopen(observer: { try terminalCapture.observe($0, url: $1) })
        defer { gate.destroy() }
        do { _ = try await reopened.recoverPendingImports(); XCTFail("Original rollback must report the original rejected import") }
        catch let completion as ReaderImportRollbackCompletion { XCTAssertFalse(completion.operationId.isEmpty) }
        let terminalJournal = try stagingObject(XCTUnwrap(terminalCapture.bytes))
        XCTAssertEqual(try stagingStoredReceipt(terminalJournal, stage: "publish"), try stagingJSON(negative))
        XCTAssertEqual(try stagingObject(stagingStoredReceipt(terminalJournal, stage: "rollback"))["outcome"] as? String, "applied")
        XCTAssertEqual(gate.count("import.local.rollback.v2"), 1); XCTAssertEqual(gate.count("import.local.settle.v2"), 1)
        for method in ["import.parse", "import.local.persist.v2", "import.local.publish.v2", "import.local.finalize.v2", "bookshelf.add"] { XCTAssertEqual(gate.count(method), 0) }
        XCTAssertEqual(try fixture.businessJournals(), []); XCTAssertEqual(try fixture.ownerReceipts(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.stableSource.path))
        try fixture.assertOriginalPreserved(); try await reopened.close()
    }

    func testRealOriginalV2TerminalDurableColdRecoveryUsesRetiredSettleWithoutReplayingBusiness() async throws {
        let capture = StagingJournalCapture(point: .localV2TerminalDurable, stopOnce: true)
        let fixture = try StagingFixture(observer: { try capture.observe($0, url: $1) })
        defer { fixture.cleanUp() }
        let imported = try await fixture.service.importBook(at: fixture.input)
        XCTAssertTrue(imported.finalizationPending)
        let journal = try stagingObject(XCTUnwrap(capture.bytes))
        let terminal = try stagingObject(stagingStoredReceipt(journal, stage: "finalize"))
        let identity = try stagingFileIdentity(fixture.stableSource)
        let actual = try fixture.client.directRequest("import.local.settle.v2", params: ["binding": try stagingBinding(journal),
            "terminalStage": "finalize", "terminalReceiptFingerprint": try XCTUnwrap(terminal["ackFingerprint"] as? String)])
        XCTAssertEqual(actual.type, "result"); XCTAssertEqual(actual.data?["state"] as? String, "settled")
        fixture.client.destroy()
        let (gate, reopened) = try fixture.reopen()
        defer { gate.destroy() }
        let remaining = try await reopened.recoverPendingImports()
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertEqual(try gate.originalTerminal("import.local.settle.v2")?.data?["state"] as? String, "retired")
        XCTAssertEqual(gate.count("import.local.settle.v2"), 1)
        for method in ["import.parse", "import.local.persist.v2", "import.local.publish.v2", "import.local.finalize.v2", "import.local.rollback.v2"] { XCTAssertEqual(gate.count(method), 0) }
        XCTAssertEqual(try stagingFileIdentity(fixture.stableSource), identity)
        XCTAssertEqual(try Data(contentsOf: fixture.stableSource), fixture.original)
        XCTAssertEqual(try fixture.ownerReceipts(), []); XCTAssertEqual(try fixture.businessJournals(), [])
        try fixture.assertOriginalPreserved(); try await reopened.close()
    }

    func testRealOriginalV2FreshNonAdmissionDurableCrashRetiresOnlyItsOwnerOnColdReentry() async throws {
        let handoff = StagingHandoffCapture()
        let capture = StagingJournalCapture(point: .localV2NonAdmissionDurable, stopOnce: true)
        let fixture = try StagingFixture(observer: { point, url in
            try handoff.capture(point, payload: url); try capture.observe(point, url: url)
        })
        defer { fixture.cleanUp() }
        fixture.client.beforeFirstSend("import.local.persist.v2") { try stagingCorruptOwnedPayload(handoff, sources: fixture.sources) }
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("Stop after durable original non-admission proof") }
        catch ReaderLibraryError.operationPending(_) {}
        let journal = try stagingObject(XCTUnwrap(capture.bytes))
        XCTAssertEqual(journal["phase"] as? String, "v2NotAdmitted")
        let state = try XCTUnwrap(journal["localV2"] as? [String: Any])
        XCTAssertNotNil(state["nonAdmission"] as? [String: Any])
        XCTAssertEqual(try fixture.ownerReceipts().count, 1)
        fixture.client.destroy()
        let (gate, reopened) = try fixture.reopen()
        defer { gate.destroy() }
        do { _ = try await reopened.recoverPendingImports(); XCTFail("Known original refusal is reported after exact resource retirement") }
        catch is ReaderImportRollbackCompletion {}
        for method in ["import.parse", "import.local.query.v2", "import.local.persist.v2", "import.local.settle.v2"] { XCTAssertEqual(gate.count(method), 0) }
        XCTAssertEqual(try fixture.stagePayloads(), []); XCTAssertEqual(try fixture.ownerReceipts(), [])
        XCTAssertEqual(try fixture.businessJournals(), [])
        try fixture.assertOriginalPreserved(); try await reopened.close()
    }

    func testRealOriginalV2SameTupleReplayRetiresLateOriginalErrorAfterJournalRemoval() async throws {
        let fixture = try StagingFixture()
        defer { fixture.cleanUp() }
        fixture.client.deferFirstNativeSend("import.local.persist.v2")
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("Original transport delivery is deferred") }
        catch ReaderLibraryError.operationPending(_) {}
        let originalRequest = try XCTUnwrap(fixture.client.originalRequest("import.local.persist.v2"))
        let original = try stagingObject(originalRequest.parameters)
        XCTAssertEqual(fixture.client.nativeCount("import.local.persist.v2"), 0)
        let recovered = try await fixture.service.recoverPendingImports()
        XCTAssertTrue(recovered.isEmpty)
        XCTAssertEqual(fixture.client.count("import.local.persist.v2"), 2)
        XCTAssertEqual(fixture.client.nativeCount("import.local.persist.v2"), 1)
        let replay = try stagingObject(XCTUnwrap(fixture.client.lastRequest("import.local.persist.v2")).parameters)
        XCTAssertEqual(try stagingJSON(original), try stagingJSON(replay), "Replay keeps the original binding, semantic preview and locator")
        XCTAssertEqual(try fixture.businessJournals(), [])
        let pendingTransport = await fixture.service.unresolvedWrites.count
        XCTAssertEqual(pendingTransport, 1)
        let identity = try stagingFileIdentity(fixture.stableSource)
        let methods = ["import.parse", "import.local.authority.v2", "import.local.query.v2", "import.local.persist.v2",
            "import.local.publish.v2", "import.local.finalize.v2", "import.local.rollback.v2", "import.local.settle.v2"]
        let beforeLate = methods.map { fixture.client.count($0) }
        try fixture.client.deliverDeferredOriginal() // Real Core now returns retired, not a synthesized ACK.
        let deadline = ProcessInfo.processInfo.systemUptime + 10
        var late: ReaderCoreEvent?
        repeat {
            // No business journal remains. Observe only the original transport;
            // this does not recover/query/replay any business phase.
            try await fixture.service.drainUnresolvedReplies(importsOnly: true)
            late = try fixture.client.terminal(requestID: originalRequest.requestID)
            if late != nil || ProcessInfo.processInfo.systemUptime >= deadline { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        } while true
        let originalTerminal = try XCTUnwrap(late, "The actual original request must terminate within ten seconds")
        XCTAssertEqual(originalTerminal.requestId, originalRequest.requestID)
        XCTAssertEqual(originalTerminal.type, "error")
        let evidence = XCTAttachment(data: originalTerminal.rawData, uniformTypeIdentifier: "public.json")
        evidence.name = "local-import-v2-late-original-terminal.private"; evidence.lifetime = .keepAlways; add(evidence)
        let remainingTransport = await fixture.service.unresolvedWrites.count
        XCTAssertEqual(remainingTransport, 0)
        XCTAssertEqual(methods.map { fixture.client.count($0) }, beforeLate, "Late observation cannot dispatch any new business phase or query")
        XCTAssertEqual(fixture.client.nativeCount("import.local.persist.v2"), 2)
        XCTAssertEqual(fixture.client.count("import.parse"), 1)
        XCTAssertEqual(try fixture.businessJournals(), []); XCTAssertEqual(try fixture.ownerReceipts(), [])
        XCTAssertEqual(try stagingFileIdentity(fixture.stableSource), identity)
        XCTAssertEqual(try Data(contentsOf: fixture.stableSource), fixture.original)
        try fixture.assertOriginalPreserved(); try await fixture.service.close()
    }

    func testRealOriginalV2ColdReplayNonAdmissionCannotEraseTheUnknownOriginalIntent() async throws {
        let handoff = StagingHandoffCapture()
        let fixture = try StagingFixture(observer: { try handoff.capture($0, payload: $1) })
        defer { fixture.cleanUp() }
        fixture.client.deferFirstNativeSend("import.local.persist.v2")
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("Original delivery is unknown") }
        catch ReaderLibraryError.operationPending(_) {}
        let journalURL = try fixture.onlyBusinessJournal()
        let originalJournal = try stagingObject(Data(contentsOf: journalURL))
        fixture.client.destroy()
        let (gate, reopened) = try fixture.reopen()
        defer { gate.destroy() }
        gate.beforeFirstSend("import.local.persist.v2") {
            let owner = try JSONDecoder().decode(ReaderImportStagingOwner.self, from: try XCTUnwrap(handoff.bytes))
            let payload = fixture.sources.appendingPathComponent(".staging/" + owner.stagedName)
            let writer = try FileHandle(forWritingTo: payload)
            defer { try? writer.close() }
            XCTAssertEqual(try writer.seekToEnd(), UInt64(fixture.original.count))
            try writer.write(contentsOf: Data([0])); try writer.synchronize()
        }
        let pending = try await reopened.recoverPendingImports()
        XCTAssertEqual(pending.count, 1); XCTAssertEqual(pending.first?.requiresReconciliation, true)
        let event = try XCTUnwrap(gate.originalTerminal("import.local.persist.v2"))
        XCTAssertEqual(event.requestId, try XCTUnwrap(gate.originalRequest("import.local.persist.v2")).requestID)
        XCTAssertEqual(event.type, "error"); XCTAssertEqual(try stagingErrorDetails(event)["localImportDisposition"] as? String, "nonAdmitted")
        XCTAssertEqual(try stagingErrorDetails(event)["reason"] as? String, "transportPreflight")
        let evidence = XCTAttachment(data: event.rawData, uniformTypeIdentifier: "public.json")
        evidence.name = "local-import-v2-cold-non-admission-terminal.private"; evidence.lifetime = .keepAlways; add(evidence)
        let after = try stagingObject(Data(contentsOf: journalURL))
        XCTAssertEqual(after["phase"] as? String, "v2PersistAwaiting")
        XCTAssertEqual(try stagingJSON(stagingBinding(after)), try stagingJSON(stagingBinding(originalJournal)))
        let state = try XCTUnwrap(after["localV2"] as? [String: Any])
        XCTAssertEqual(state["persistOutcomeWasUnknown"] as? Bool, true); XCTAssertNil(state["nonAdmission"])
        XCTAssertEqual(try fixture.ownerReceipts().count, 1); XCTAssertEqual(try fixture.stagePayloads().count, 1)
        XCTAssertEqual(gate.count("import.parse"), 0); XCTAssertEqual(gate.count("import.local.persist.v2"), 1)
        XCTAssertEqual(gate.count("import.local.settle.v2"), 0)
        try fixture.assertOriginalPreserved()
        // Teardown destroys only the private runtime; UNKNOWN is not business completion.
    }

    func testRealOriginalV2RejectedRollbackRemainsPendingWithoutStageRedispatch() async throws {
        let fault = StagingMetadataCapture(), sync = StagingDirectorySyncFault()
        let fixture = try StagingFixture(observer: { try sync.observe($0, url: $1) }, directorySync: { try sync.synchronize($0) })
        defer { fixture.cleanUp() }
        sync.failOnce(in: fixture.sources)
        fixture.client.beforeFirstSend("import.local.rollback.v2") { try fault.change(fixture) }
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("Original rejected rollback is unresolved") }
        catch ReaderLibraryError.operationPending(_) {}
        let original = try stagingReceipt(XCTUnwrap(fixture.client.originalTerminal("import.local.rollback.v2")), stage: "rollback")
        XCTAssertEqual(original["outcome"] as? String, "rejected")
        try fault.restore(fixture)
        let journalURL = try fixture.onlyBusinessJournal()
        let ownerNames = try fixture.ownerReceipts(), identity = try stagingFileIdentity(fixture.stableSource)
        let pending = try await fixture.service.recoverPendingImports()
        XCTAssertEqual(pending.count, 1); XCTAssertEqual(pending.first?.requiresReconciliation, true)
        XCTAssertEqual(try stagingStoredReceipt(stagingObject(Data(contentsOf: journalURL)), stage: "rollback"), try stagingJSON(original))
        XCTAssertEqual(fixture.client.count("import.local.rollback.v2"), 1)
        XCTAssertEqual(fixture.client.count("import.local.settle.v2"), 0)
        XCTAssertEqual(try fixture.ownerReceipts(), ownerNames)
        XCTAssertEqual(try stagingFileIdentity(fixture.stableSource), identity)
        XCTAssertEqual(try Data(contentsOf: fixture.stableSource), fixture.original)
        try fixture.assertOriginalPreserved()
    }

    func testRealOriginalV2ColdRejectedFinalizeKeepsOriginalNegativeAfterExactTOCRestore() async throws {
        let fault = StagingTOCCapture()
        let fixture = try StagingFixture()
        defer { fixture.cleanUp() }
        fixture.client.beforeFirstSend("import.local.finalize.v2") { try fault.change(fixture) }
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("Original finalize afterimage refusal remains unresolved") }
        catch ReaderLibraryError.operationPending(_) {}
        let original = try stagingReceipt(XCTUnwrap(fixture.client.originalTerminal("import.local.finalize.v2")), stage: "finalize")
        XCTAssertEqual(original["outcome"] as? String, "rejected")
        XCTAssertTrue(original["data"] is NSNull); XCTAssertNotNil(original["error"] as? [String: Any])
        try fault.restore(fixture) // Restore exact canonical TOC bytes before the cold query.
        let journalURL = try fixture.onlyBusinessJournal()
        let journal = try stagingObject(Data(contentsOf: journalURL))
        let identity = try stagingFileIdentity(fixture.stableSource), owners = try fixture.ownerReceipts()
        fixture.client.destroy()
        let (gate, reopened) = try fixture.reopen()
        defer { gate.destroy() }
        let pending = try await reopened.recoverPendingImports()
        XCTAssertEqual(pending.count, 1); XCTAssertEqual(pending.first?.requiresReconciliation, true)
        let after = try stagingObject(Data(contentsOf: journalURL))
        XCTAssertEqual(after["phase"] as? String, "v2FinalizeAwaiting")
        XCTAssertEqual(try stagingJSON(stagingBinding(after)), try stagingJSON(stagingBinding(journal)))
        XCTAssertEqual(try stagingStoredReceipt(after, stage: "finalize"), try stagingJSON(original))
        XCTAssertGreaterThan(gate.count("import.local.query.v2"), 0)
        for method in ["import.parse", "import.local.persist.v2", "import.local.publish.v2", "import.local.finalize.v2", "import.local.rollback.v2", "import.local.settle.v2"] { XCTAssertEqual(gate.count(method), 0) }
        XCTAssertEqual(try fixture.ownerReceipts(), owners)
        XCTAssertEqual(try stagingFileIdentity(fixture.stableSource), identity)
        XCTAssertEqual(try Data(contentsOf: fixture.stableSource), fixture.original)
        try fault.assertRestored(fixture); try fixture.assertOriginalPreserved()
    }

    func testRealOriginalV2MoveThenDirectorySyncFailureWaitsForOriginalRollbackAndProtectsPreexistingSameSHA() async throws {
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
            fixture.client.hold("import.local.rollback.v2", advanceObserverDeadline: true)
            do { _ = try await fixture.service.importBook(at: copy); XCTFail("The original rollback ACK is withheld") }
            catch ReaderLibraryError.operationPending(_) {}
            XCTAssertEqual(fault.failureCount, 1, "Fault is at commitSource's actual directory-sync boundary")
            let journalURL = try fixture.onlyBusinessJournal()
            let journalBytes = try Data(contentsOf: journalURL)
            let journal = try XCTUnwrap(JSONSerialization.jsonObject(with: journalBytes) as? [String: Any])
            let id = try XCTUnwrap(journal["id"] as? String)
            XCTAssertEqual(journal["phase"] as? String, "v2RollbackAwaiting")
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
            let sent = try XCTUnwrap(fixture.client.originalRequest("import.local.rollback.v2"))
            let terminal = try XCTUnwrap(fixture.client.originalTerminal("import.local.rollback.v2"))
            XCTAssertEqual(terminal.requestId, sent.requestID)
            let result = try XCTUnwrap(terminal.data)
            let receipts = try XCTUnwrap(result["receipts"] as? [[String: Any]])
            let receipt = try XCTUnwrap(receipts.first { $0["stage"] as? String == "rollback" })
            XCTAssertEqual(receipt["outcome"] as? String, "applied")
            let rollback = try XCTUnwrap(receipt["data"] as? [String: Any])
            XCTAssertEqual(rollback["bookId"] as? String, "local:" + hash)
            XCTAssertEqual(rollback["transactionId"] as? String, id)
            XCTAssertEqual(try Data(contentsOf: stable), fixture.original)
            do { _ = try await fixture.service.recoverPendingImports(); XCTFail("Query must project the actual original rollback failure completion") }
            catch let completion as ReaderImportRollbackCompletion {
                XCTAssertEqual(completion.operationId, id)
                XCTAssertTrue(completion.originalFailure?.contains(NSPOSIXErrorDomain) == true, "The original sync failure is preserved")
            }
            fixture.client.release()
            do { let pending = try await fixture.service.recoverPendingImports(); XCTAssertTrue(pending.isEmpty) }
            XCTAssertEqual(fixture.client.count("import.local.rollback.v2"), 1)
            XCTAssertEqual(fixture.client.count("import.local.persist.v2"), 1)
            XCTAssertEqual(fixture.client.count("import.local.publish.v2"), 0)
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
        XCTAssertEqual(fixture.client.count("import.local.persist.v2"), 0)
        XCTAssertEqual(fixture.client.count("import.local.rollback.v2"), 0)
        XCTAssertEqual(fixture.client.count("import.local.publish.v2"), 0)
        XCTAssertEqual(try fixture.stagePayloads(), [])
        XCTAssertEqual(try fixture.ownerReceipts(), [])
        XCTAssertEqual(try fixture.businessJournals(), [])
        let pending = try await fixture.service.recoverPendingImports()
        XCTAssertTrue(pending.isEmpty, "This proven pre-send failure cannot become a permanent unknown operation")
        XCTAssertEqual(fixture.client.count("import.local.persist.v2"), 0)
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
        XCTAssertEqual(fixture.client.count("import.local.persist.v2"), 0)
        XCTAssertEqual(fixture.client.count("import.local.publish.v2"), 0)
        XCTAssertEqual(try Data(contentsOf: copy), fixture.original)
        try fixture.assertOriginalPreserved()
        try await fixture.service.close()
    }

    func testRealOriginalLateV2PublishACKKeepsSourceOwnershipUntilTheOriginalFinalize() async throws {
        let fixture = try StagingFixture()
        defer { fixture.cleanUp() }
        fixture.client.hold("import.local.publish.v2", advanceObserverDeadline: true)
        do { _ = try await fixture.service.importBook(at: fixture.input); XCTFail("Original publish envelope is held") }
        catch ReaderLibraryError.operationPending(_) {}
        let journalURL = try fixture.onlyBusinessJournal()
        let journal = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: journalURL)) as? [String: Any])
        XCTAssertEqual(journal["phase"] as? String, "v2PublishAwaiting")
        let stable = fixture.sources.appendingPathComponent(StagingFixture.sha(fixture.original) + ".source")
        let identity = try stagingFileIdentity(stable)
        do { let pending = try await fixture.service.recoverPendingImports(); XCTAssertTrue(pending.isEmpty) }
        XCTAssertEqual(fixture.client.count("import.local.publish.v2"), 1)
        XCTAssertEqual(fixture.client.count("import.local.finalize.v2"), 1)
        XCTAssertEqual(try fixture.businessJournals(), [])
        fixture.client.release()
        do { let pending = try await fixture.service.recoverPendingImports(); XCTAssertTrue(pending.isEmpty) }
        XCTAssertEqual(fixture.client.count("import.local.publish.v2"), 1)
        XCTAssertEqual(fixture.client.count("import.local.rollback.v2"), 0)
        XCTAssertEqual(try stagingFileIdentity(stable), identity)
        XCTAssertEqual(try Data(contentsOf: stable), fixture.original)
        XCTAssertEqual(try fixture.ownerReceipts(), [])
        try fixture.assertOriginalPreserved(); try await fixture.service.close()
    }

    func testLegacyRealOriginalColdShelfAwaitingKeepsUnknownOutcomeWithoutRedispatch() async throws {
        let fixture = try StagingFixture()
        defer { fixture.cleanUp() }
        fixture.client.hold("bookshelf.add", advanceObserverDeadline: true)
        do { _ = try await fixture.produceLegacyShelfAwaiting(); XCTFail("Original shelf ACK is held") }
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

    func testRealOriginalLateV2FinalizeACKRetiresOnlyOwnerAndKeepsTheReadableSource() async throws {
        let fixture = try StagingFixture()
        defer { fixture.cleanUp() }
        fixture.client.hold("import.local.finalize.v2", advanceObserverDeadline: true)
        let result = try await fixture.service.importBook(at: fixture.input)
        XCTAssertTrue(result.finalizationPending)
        let stable = try await fixture.service.retainedSourceURL(for: result.book)
        let identity = try stagingFileIdentity(stable)
        let journal = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixture.onlyBusinessJournal())) as? [String: Any])
        XCTAssertEqual(journal["phase"] as? String, "v2FinalizeAwaiting")
        do { let pending = try await fixture.service.recoverPendingImports(); XCTAssertTrue(pending.isEmpty) }
        XCTAssertEqual(fixture.client.count("import.local.finalize.v2"), 1)
        XCTAssertEqual(fixture.client.count("import.local.settle.v2"), 1)
        fixture.client.release()
        do { let pending = try await fixture.service.recoverPendingImports(); XCTAssertTrue(pending.isEmpty) }
        XCTAssertEqual(fixture.client.count("import.local.finalize.v2"), 1)
        XCTAssertEqual(try stagingFileIdentity(stable), identity)
        XCTAssertEqual(try Data(contentsOf: stable), fixture.original)
        XCTAssertEqual(try fixture.ownerReceipts(), [])
        try fixture.assertOriginalPreserved(); try await fixture.service.close()
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
            XCTAssertEqual(otherGate.count("import.local.persist.v2"), 0)
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
        XCTAssertEqual(gate.count("import.local.persist.v2"), 0)
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
        XCTAssertEqual(gate.count("import.local.persist.v2"), 0)
        try fixture.assertOriginalPreserved()
        try await service.close()
        try await fixture.service.close()
    }
}

private enum StagingTestFailure: Error { case missingOriginalTerminal }

private func stagingObject(_ bytes: Data) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
}
private func stagingJSON(_ object: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
}
private func stagingBinding(_ journal: [String: Any]) throws -> [String: Any] {
    let state = try XCTUnwrap(journal["localV2"] as? [String: Any])
    return try XCTUnwrap(state["binding"] as? [String: Any])
}
private func stagingStoredReceipt(_ journal: [String: Any], stage: String) throws -> Data {
    let state = try XCTUnwrap(journal["localV2"] as? [String: Any])
    let receipts = try XCTUnwrap(state["receipts"] as? [String: String])
    return try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(receipts[stage])))
}
private func stagingReceipt(_ event: ReaderCoreEvent, stage: String) throws -> [String: Any] {
    XCTAssertEqual(event.type, "result")
    let receipts = try XCTUnwrap(event.data?["receipts"] as? [[String: Any]])
    return try XCTUnwrap(receipts.first { $0["stage"] as? String == stage })
}
private func stagingErrorDetails(_ event: ReaderCoreEvent) throws -> [String: Any] {
    let wire = try stagingObject(event.rawData)
    return try XCTUnwrap((wire["error"] as? [String: Any])?["details"] as? [String: Any])
}
private func stagingCorruptOwnedPayload(_ capture: StagingHandoffCapture, sources: URL) throws {
    let owner = try JSONDecoder().decode(ReaderImportStagingOwner.self, from: try XCTUnwrap(capture.bytes))
    let writer = try FileHandle(forUpdating: sources.appendingPathComponent(".staging/" + owner.stagedName))
    defer { try? writer.close() }
    let first = try XCTUnwrap(try writer.read(upToCount: 1)?.first)
    try writer.seek(toOffset: 0); try writer.write(contentsOf: Data([first ^ 0xff])); try writer.synchronize()
}

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
    var stableSource: URL { sources.appendingPathComponent(Self.sha(original) + ".source") }
    func reopen(observer: @escaping ReaderImportStagingObserver = { _, _ in }) throws -> (StagingCoreGate, ReaderLibraryService) {
        let core = root.appendingPathComponent("Core")
        let gate = try StagingCoreGate(storage: core)
        let reopened = try ReaderLibraryService(storageURL: core, sourceURL: sources, client: gate,
            timing: gate.timing, importStagingObserver: observer)
        return (gate, reopened)
    }
    /// Explicit compatibility producer, not a normal import route or an old-App
    /// migration claim. Every v1 business value comes from this real Core.
    func produceLegacyShelfAwaiting() async throws {
        let stage = sources.appendingPathComponent(".staging")
        let lease = try ReaderImportStagingLease(stagingURL: stage)
        defer { lease.release() }
        var owner = try lease.copy(input, selection: UUID().uuidString.lowercased(), cancellation: ReaderImportCopyCancellation())
        let payload = lease.payloadURL(owner), hash = try XCTUnwrap(owner.sha256), id = owner.transactionID
        let parsedData = try await service.request("import.parse", ["kind": "localBook", "input": [
            "bookId": "local:" + hash, "fileName": input.lastPathComponent, "filePath": payload.path,
            "title": input.deletingPathExtension().lastPathComponent]], timeout: 120)
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: parsedData) as? [String: Any])
        try lease.parsed(owner)
        var journal: [String: Any] = ["id": id, "fileName": input.lastPathComponent,
            "stagedName": owner.stagedName, "hash": hash, "phase": "persistAwaiting"]
        let journalURL = sources.appendingPathComponent(".operations/" + id + ".json")
        try ReaderImportStagingLease.writeDurably(JSONSerialization.data(withJSONObject: journal), to: journalURL)
        owner = try lease.handoff(owner)
        let persistedData = try await service.request("import.persist", ["transactionId": id, "parsed": parsed],
            mutation: true, timeout: 120, owner: .importOperation(id: id, stage: .persist))
        let persisted = try XCTUnwrap(JSONSerialization.jsonObject(with: persistedData) as? [String: Any])
        let token = try XCTUnwrap(persisted["rollbackToken"] as? [String: Any])
        let result = try XCTUnwrap(persisted["persisted"] as? [String: Any])
        let local = try XCTUnwrap(result["data"] as? [String: Any])
        let metadata = try XCTUnwrap(local["book"] as? [String: Any])
        XCTAssertEqual((token["token"] as? [String: Any])?["transactionId"] as? String, id)
        var shelf: [String: Any] = ["sourceId": "local", "bookId": "local:" + hash,
            "title": metadata["title"] as? String ?? "", "author": metadata["author"] as? String ?? "", "requireReadable": true]
        for key in ["coverUrl", "intro", "kind"] { if let value = metadata[key] { shelf[key] = value } }
        journal["rollbackToken"] = try JSONSerialization.data(withJSONObject: token).base64EncodedString()
        journal["shelfParameters"] = try JSONSerialization.data(withJSONObject: shelf).base64EncodedString()
        journal["phase"] = "persisted"
        try ReaderImportStagingLease.writeDurably(JSONSerialization.data(withJSONObject: journal), to: journalURL)
        await service.finishMutation(.importOperation(id: id, stage: .persist))
        let stable = sources.appendingPathComponent(hash + ".source")
        XCTAssertFalse(FileManager.default.fileExists(atPath: stable.path))
        let identity = try stagingFileIdentity(payload)
        try ReaderImportStagingLease.moveExclusively(payload, to: stable)
        owner.createdSource = .init(name: stable.lastPathComponent, identity: identity)
        try lease.recordCreatedSource(owner)
        try ReaderImportStagingLease.synchronizeDirectory(sources)
        try ReaderImportStagingLease.synchronizeDirectory(stage)
        journal["phase"] = "shelfAwaiting"
        try ReaderImportStagingLease.writeDurably(JSONSerialization.data(withJSONObject: journal), to: journalURL)
        _ = try await service.request("bookshelf.add", shelf, mutation: true, owner: .importOperation(id: id, stage: .shelf))
        XCTFail("This compatibility seam must hold the real original shelf ACK")
    }
    // Explicit test-only metadata fault, confined to this fixture's private DB.
    // No receipt/head/journal/body or shared production database is edited.
    nonisolated func bookMetadata(_ bookID: String) throws -> Data {
        try withMetadataDB { db in
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT book_json FROM books WHERE book_id = ?1", -1, &statement, nil) == SQLITE_OK else { throw CocoaError(.fileReadUnknown) }
            defer { sqlite3_finalize(statement) }
            try bindText(Data(bookID.utf8), to: 1, statement: statement)
            guard sqlite3_step(statement) == SQLITE_ROW, let bytes = sqlite3_column_blob(statement, 0) else { throw CocoaError(.fileReadUnknown) }
            let value = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
            guard sqlite3_step(statement) == SQLITE_DONE else { throw CocoaError(.fileReadUnknown) }
            return value
        }
    }
    nonisolated func replaceBookMetadata(_ bookID: String, expected: Data, replacement: Data) throws {
        try withMetadataDB { db in
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, "UPDATE books SET book_json = ?1 WHERE book_id = ?2 AND book_json = ?3", -1, &statement, nil) == SQLITE_OK else { throw CocoaError(.fileWriteUnknown) }
            defer { sqlite3_finalize(statement) }
            try bindText(replacement, to: 1, statement: statement)
            try bindText(Data(bookID.utf8), to: 2, statement: statement)
            try bindText(expected, to: 3, statement: statement)
            guard sqlite3_step(statement) == SQLITE_DONE, sqlite3_changes(db) == 1 else { throw CocoaError(.fileWriteUnknown) }
        }
        XCTAssertEqual(try bookMetadata(bookID), replacement)
    }
    nonisolated func tocPayload(_ bookID: String) throws -> Data {
        try withMetadataDB { db in
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT payload FROM cache WHERE key = ?1", -1, &statement, nil) == SQLITE_OK else { throw CocoaError(.fileReadUnknown) }
            defer { sqlite3_finalize(statement) }
            try bindText(Data(("local_book.v1.toc:" + bookID).utf8), to: 1, statement: statement)
            guard sqlite3_step(statement) == SQLITE_ROW, sqlite3_column_type(statement, 0) == SQLITE_TEXT else { throw CocoaError(.fileReadUnknown) }
            let count = Int(sqlite3_column_bytes(statement, 0))
            let value = count == 0 ? Data() : Data(bytes: try XCTUnwrap(sqlite3_column_blob(statement, 0)), count: count)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw CocoaError(.fileReadUnknown) }
            return value
        }
    }
    nonisolated func replaceTOCPayload(_ bookID: String, expected: Data, replacement: Data) throws {
        try withMetadataDB { db in
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, "UPDATE cache SET payload = ?1 WHERE key = ?2 AND payload = ?3", -1, &statement, nil) == SQLITE_OK else { throw CocoaError(.fileWriteUnknown) }
            defer { sqlite3_finalize(statement) }
            try bindText(replacement, to: 1, statement: statement)
            try bindText(Data(("local_book.v1.toc:" + bookID).utf8), to: 2, statement: statement)
            try bindText(expected, to: 3, statement: statement)
            guard sqlite3_step(statement) == SQLITE_DONE, sqlite3_changes(db) == 1 else { throw CocoaError(.fileWriteUnknown) }
        }
        XCTAssertEqual(try tocPayload(bookID), replacement)
    }
    nonisolated private func withMetadataDB<T>(_ action: (OpaquePointer) throws -> T) throws -> T {
        let ownedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let directory = root.appendingPathComponent("Core").resolvingSymlinksInPath().standardizedFileURL
        let url = directory.appendingPathComponent("reader-core.sqlite3").standardizedFileURL
        guard root.lastPathComponent.hasPrefix("ReaderImportOwner-"), url.deletingLastPathComponent() == directory,
              ownedRoot.deletingLastPathComponent() == FileManager.default.temporaryDirectory.resolvingSymlinksInPath().standardizedFileURL,
              directory.deletingLastPathComponent() == ownedRoot,
              url.resolvingSymlinksInPath() == url else { throw CocoaError(.fileReadNoPermission) }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            if let db { sqlite3_close(db) }; throw CocoaError(.fileReadUnknown)
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 1_000)
        return try action(db)
    }
    nonisolated private func bindText(_ value: Data, to index: Int32, statement: OpaquePointer?) throws {
        guard value.count <= Int(Int32.max), let text = String(data: value, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let status = text.withCString { bytes in
            sqlite3_bind_text(statement, index, bytes, Int32(value.count), transient)
        }
        guard status == SQLITE_OK else { throw CocoaError(.fileWriteUnknown) }
    }
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
    nonisolated static func sha(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
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

private final class StagingJournalCapture: @unchecked Sendable {
    enum Captured: Error { case stop }
    private let lock = NSLock()
    private let point: ReaderImportStagingCheckpoint
    private var shouldStop: Bool
    private var captured: Data?
    init(point: ReaderImportStagingCheckpoint, stopOnce: Bool = false) { self.point = point; shouldStop = stopOnce }
    var bytes: Data? { lock.lock(); defer { lock.unlock() }; return captured }
    func observe(_ point: ReaderImportStagingCheckpoint, url: URL) throws {
        guard point == self.point else { return }
        let originalJournal = try Data(contentsOf: url)
        lock.lock(); captured = originalJournal; let stop = shouldStop; shouldStop = false; lock.unlock()
        if stop { throw Captured.stop }
    }
}

private final class StagingMetadataCapture: @unchecked Sendable {
    private var bookID: String?
    private var original: Data?
    private var changed: Data?
    func change(_ fixture: StagingFixture) throws {
        let id = "local:" + StagingFixture.sha(fixture.original)
        let bytes = try fixture.bookMetadata(id)
        var value = try stagingObject(bytes)
        value["title"] = (try XCTUnwrap(value["title"] as? String)) + " [owned metadata conflict]"
        let replacement = try stagingJSON(value)
        try fixture.replaceBookMetadata(id, expected: bytes, replacement: replacement)
        bookID = id; original = bytes; changed = replacement
    }
    func restore(_ fixture: StagingFixture) throws {
        try fixture.replaceBookMetadata(XCTUnwrap(bookID), expected: XCTUnwrap(changed), replacement: XCTUnwrap(original))
    }
}

private final class StagingTOCCapture: @unchecked Sendable {
    private var bookID: String?
    private var original: Data?
    func change(_ fixture: StagingFixture) throws {
        let id = "local:" + StagingFixture.sha(fixture.original)
        let bytes = try fixture.tocPayload(id)
        XCTAssertFalse(bytes.isEmpty)
        guard !bytes.isEmpty else { throw CocoaError(.fileReadUnknown) }
        try fixture.replaceTOCPayload(id, expected: bytes, replacement: Data())
        bookID = id; original = bytes
    }
    func restore(_ fixture: StagingFixture) throws {
        try fixture.replaceTOCPayload(XCTUnwrap(bookID), expected: Data(), replacement: XCTUnwrap(original))
        try assertRestored(fixture)
    }
    func assertRestored(_ fixture: StagingFixture) throws {
        XCTAssertEqual(try fixture.tocPayload(XCTUnwrap(bookID)), try XCTUnwrap(original))
    }
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
    private var latestRequests: [String: SentRequest] = [:]
    private var terminals: [String: Data] = [:]
    private var terminalsByRequest: [UInt64: Data] = [:]
    private var heldMethod: String?
    private var heldID: UInt64?
    private var observedCancelIDs: [UInt64] = []
    private var held: Result<ReaderCoreEvent, ReaderCoreClientError>?
    private var ready = false
    private var advancesDeadline = false
    private var clock: TimeInterval = 0
    private var deferredMethod: String?
    private var deferredSend: (method: String, id: UInt64, params: [String: Any])?
    private var deferredDeadlineAdvanced = false
    private var beforeSend: [String: () throws -> Void] = [:]
    private var nativeCounts: [String: Int] = [:]
    private var directID: UInt64 = 8_000_000
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
    func nativeCount(_ name: String) -> Int { lock.lock(); defer { lock.unlock() }; return nativeCounts[name, default: 0] }
    func beforeFirstSend(_ method: String, action: @escaping () throws -> Void) { lock.lock(); beforeSend[method] = action; lock.unlock() }
    func deferFirstNativeSend(_ method: String) { lock.lock(); deferredMethod = method; lock.unlock() }
    func deliverDeferredOriginal() throws {
        lock.lock(); defer { lock.unlock() }
        guard let original = deferredSend else { throw ReaderLibraryError.invalidResponse("no deferred original") }
        _ = try native.send(method: original.method, requestId: original.id, params: original.params)
        nativeCounts[original.method, default: 0] += 1
        deferredSend = nil
    }
    func directRequest(_ method: String, params: [String: Any]) throws -> ReaderCoreEvent {
        lock.lock(); directID += 1; let id = directID; lock.unlock()
        return try native.request(method: method, requestId: id, params: params, timeout: 10)
    }
    func originalRequest(_ method: String) -> SentRequest? { lock.lock(); defer { lock.unlock() }; return requests[method] }
    func lastRequest(_ method: String) -> SentRequest? { lock.lock(); defer { lock.unlock() }; return latestRequests[method] }
    func originalTerminal(_ method: String) throws -> ReaderCoreEvent? {
        lock.lock(); let bytes = terminals[method]; lock.unlock()
        return try bytes.map { try ReaderCoreEvent(data: $0) }
    }
    func terminal(requestID: UInt64) throws -> ReaderCoreEvent? {
        lock.lock(); let bytes = terminalsByRequest[requestID]; lock.unlock()
        return try bytes.map { try ReaderCoreEvent(data: $0) }
    }
    func hold(_ method: String, advanceObserverDeadline: Bool) {
        lock.lock(); defer { lock.unlock() }
        heldMethod = method; advancesDeadline = advanceObserverDeadline
    }
    func release() { lock.lock(); ready = true; lock.unlock() }
    @discardableResult
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        lock.lock(); let hook = beforeSend.removeValue(forKey: method); lock.unlock()
        try hook?()
        lock.lock(); defer { lock.unlock() }
        if method == deferredMethod, deferredSend == nil {
            deferredMethod = nil; deferredSend = (method, requestId, params)
            counts[method, default: 0] += 1; methods[requestId] = method
            requests[method] = .init(requestID: requestId, parameters: try JSONSerialization.data(withJSONObject: params, options: .sortedKeys))
            latestRequests[method] = requests[method]
            return requestId // Transport delivery is deferred; no Core result is invented.
        }
        let id = try native.send(method: method, requestId: requestId, params: params)
        nativeCounts[method, default: 0] += 1
        counts[method, default: 0] += 1
        methods[requestId] = method
        latestRequests[method] = .init(requestID: requestId, parameters: try JSONSerialization.data(withJSONObject: params, options: .sortedKeys))
        if requests[method] == nil {
            requests[method] = .init(requestID: requestId, parameters: try JSONSerialization.data(withJSONObject: params, options: [.sortedKeys]))
        }
        if method == heldMethod && heldID == nil { heldID = requestId }
        return id
    }
    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        lock.lock(); defer { lock.unlock() }
        if deferredSend?.id == requestId {
            if !deferredDeadlineAdvanced { clock += 200; deferredDeadlineAdvanced = true }
            return nil
        }
        guard requestId == heldID else {
            let result = native.pollEvent(requestId: requestId)
            if case .success(let event)? = result, ["result", "error"].contains(event.type), let method = methods[requestId] {
                terminals[method] = event.rawData
                if let terminalID = event.requestId { terminalsByRequest[terminalID] = event.rawData }
            }
            return result
        }
        if held == nil, let event = native.pollEvent(requestId: requestId) {
            if case .success(let value) = event, ["result", "error"].contains(value.type) {
                held = event
                if let terminalID = value.requestId { terminalsByRequest[terminalID] = value.rawData }
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
