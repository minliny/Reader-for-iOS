import Foundation
import XCTest
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

final class ReaderReadCancellationTraceTests: XCTestCase {
    /// A controlled Core request router supplies snapshots and late terminals.
    /// These methods do not establish native Core retirement or network closure.
    func testSourceExecutionTraceBindsExactRequestGenerationAndRejectsUnknownOrAmbiguousSnapshots() async throws {
        let outcomes: [ReaderSearchTraceEvent.CoreExecutionObservationOutcome] = [
            .retired, .unknown, .unknown, .generationChanged, .invalidSnapshot, .invalidSnapshot, .invalidSnapshot, .retired, .timedOut,
            .invalidSnapshot, .invalidSnapshot, .invalidSnapshot, .invalidSnapshot, .invalidSnapshot,
            .invalidSnapshot, .invalidSnapshot, .invalidSnapshot, .retired, .retired
        ]
        for boundary in outcomes.indices {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderScopeTrace-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let ended = expectation(description: "Controlled exact-request scope observation ended")
            let statusEntered = expectation(description: "Controlled status request entered")
            let capture = CancellationTraceCapture { event in
                if event.stage == .coreExecutionObservationEnded { ended.fulfill() }
            }
            let clock = SourceExecutionTraceClock()
            let client = SourceExecutionTraceCoreBoundary(holdStatusCount: boundary == 7 ? 1 : 0,
                onStatus: { sample in if sample == 1 { statusEntered.fulfill() } }, response: { sample, requests in
                    let target = requests[0]
                    var current = sourceExecutionRow(target, generation: 7, retired: sample > 1 || boundary == 7 || boundary == 8)
                    switch boundary {
                    case 1: return sourceExecutionStatus([], evicted: 1)
                    case 2: return sourceExecutionStatus([current, sourceExecutionRow(target, generation: 8, retired: true)])
                    case 3: current["generation"] = sample == 1 ? 7 : 8
                    case 4: current.removeValue(forKey: "continuationScopeCount")
                    case 5: current["retired"] = true; current["retainedOwnerCount"] = 1
                    case 6: return [:] // Older default-wire status cannot prove retirement.
                    case 8: clock.advance(3)
                    case 9: current = sourceExecutionRow(target, generation: 0, retired: true)
                    case 10: current = sourceExecutionRow(target, generation: 0, retired: false)
                    case 11: current["generation"] = sample == 1 ? 7 : 0
                    case 12: current = sourceExecutionRow(target, generation: sample == 1 ? 7 : 0, retired: false)
                    case 13: current["finishedWorkItemCount"] = 2 // Finished cannot exceed started.
                    case 14: current["runningWorkItemCount"] = 2 // Started - finished is only one.
                    case 15: current["runningWorkItemCount"] = 0 // An unfinished work item still has a running scope.
                    case 16:
                        current = sourceExecutionRow(target, generation: 7, retired: true)
                        current["startedWorkItemCount"] = 2 // Clear active counts alone cannot prove retirement.
                    case 17:
                        if sample == 1 {
                            current["runningWorkItemCount"] = 0
                            current["startedWorkItemCount"] = 0 // A legitimate pre-queue/claim owner gap.
                        }
                    case 18:
                        current["startedWorkItemCount"] = UInt64.max
                        current["finishedWorkItemCount"] = sample == 1 ? UInt64.max - 1 : UInt64.max
                    default: break
                    }
                    return sourceExecutionStatus([sourceExecutionRow(target + 10_000, generation: 4, retired: true), current])
                })
            let recording = ReaderSearchTraceRecording(searchID: UUID()) { capture.receive($0) }
            let attempt = scopeTraceAttempt(recording)
            let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                sourceURL: root.appendingPathComponent("Sources"), client: client,
                timing: .init(now: { clock.now }, suspend: { await Task.yield() }),
                sourceExecutionPause: { _ in await Task.yield() })
            _ = try await service.request("book.search", ["sourceId": "method-source"], searchTraceAttempt: attempt)
            await fulfillment(of: [statusEntered], timeout: 2)
            if boundary == 7 {
                recording.emit(.generationStopped, outcome: .presentationRetired)
                client.releaseStatusResponses()
            }
            await fulfillment(of: [ended], timeout: 3)
            let end = try XCTUnwrap(capture.events.first { $0.stage == .coreExecutionObservationEnded })
            let original = try XCTUnwrap(client.searchRequestIDs.first)
            XCTAssertEqual(end.coreRequestID, original); XCTAssertEqual(end.sourceOrdinal, 1)
            XCTAssertEqual(end.coreExecutionObservationOutcome, outcomes[boundary], "boundary=\(boundary)")
            XCTAssertTrue(client.statusRequests.allSatisfy { $0.id != original && $0.optedIn })
            XCTAssertEqual(capture.events.filter { $0.stage == .coreSent }.count, 1, "Status must not inherit or recursively create a search trace")
            XCTAssertEqual(capture.events.filter { $0.stage == .coreObservationEnded }.count, 1)
            XCTAssertEqual(client.polls.filter { $0 == original }.count, 1, "Only the original request owner consumes its terminal")
            XCTAssertTrue(client.polls.allSatisfy { polled in polled == original || client.statusRequests.contains { $0.id == polled } },
                          "The observer must not drain unrelated request events")
            if outcomes[boundary] == .retired {
                XCTAssertTrue(try XCTUnwrap(end.coreExecutionSummary).isStrictlyRetired)
                XCTAssertEqual(end.coreExecutionSummary?.requestId, original)
                XCTAssertEqual(end.coreExecutionSummary?.generation, 7)
            }
            let snapshots = capture.events.filter { $0.stage == .coreExecutionSnapshotObserved }.compactMap(\.coreExecutionSummary)
            XCTAssertTrue(snapshots.allSatisfy { $0.isCoherent && (!$0.retired || $0.isStrictlyRetired) },
                          "Invalid identities or work counters must never be published as valid observations")
            if boundary == 17 {
                let gap = try XCTUnwrap(snapshots.first)
                XCTAssertEqual(gap.retainedOwnerCount, 1); XCTAssertEqual(gap.runningWorkItemCount, 0)
                XCTAssertEqual(gap.startedWorkItemCount, 0); XCTAssertEqual(gap.finishedWorkItemCount, 0)
                XCTAssertFalse(gap.retired, "A retained owner with no current stage is still live")
            }
            if boundary == 18 {
                XCTAssertEqual(end.coreExecutionSummary?.startedWorkItemCount, UInt64.max)
                XCTAssertEqual(end.coreExecutionSummary?.finishedWorkItemCount, UInt64.max)
            }
            XCTAssertFalse(capture.events.contains { $0.stage == .httpSessionInvalidated || $0.stage == .hostTransportDrained })
            try await service.close()
        }

        let zeroRequest = try JSONDecoder().decode(ReaderSearchTraceEvent.CoreExecutionSummary.self,
            from: JSONSerialization.data(withJSONObject: sourceExecutionRow(0, generation: 7, retired: true)))
        XCTAssertFalse(zeroRequest.isCoherent); XCTAssertFalse(zeroRequest.isStrictlyRetired)

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderScopeTraceDisabled-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let client = SourceExecutionTraceCoreBoundary()
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
            sourceURL: root.appendingPathComponent("Sources"), client: client, timing: .live)
        _ = try await service.request("book.search", ["sourceId": "method-source"])
        let recording = ReaderSearchTraceRecording(searchID: UUID()) { _ in XCTFail("A different method cannot inherit a search trace") }
        _ = try await service.request("source.list", [:], searchTraceAttempt: scopeTraceAttempt(recording))
        try await service.close()
        XCTAssertTrue(client.statusRequests.isEmpty, "Disabled trace creates no diagnostic requests")
    }

    func testSourceExecutionTraceBoundsRequestSamplesGenerationBudgetAndConcurrentObservers() async throws {
        for multiple in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderScopeTraceBudget-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let ended = expectation(description: "All bounded scope observers ended")
            ended.expectedFulfillmentCount = multiple ? 5 : 1
            let entered = expectation(description: "Admitted status requests entered")
            entered.expectedFulfillmentCount = multiple ? 4 : 1
            let capture = CancellationTraceCapture { event in
                if event.stage == .coreExecutionObservationEnded { ended.fulfill() }
            }
            let client = SourceExecutionTraceCoreBoundary(holdStatusCount: multiple ? 4 : 0,
                onStatus: { sample in if sample <= (multiple ? 4 : 1) { entered.fulfill() } },
                response: { _, requests in sourceExecutionStatus(requests.map { sourceExecutionRow($0, generation: $0, retired: false) }) })
            let recording = ReaderSearchTraceRecording(searchID: UUID()) { capture.receive($0) }
            let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                sourceURL: root.appendingPathComponent("Sources"), client: client,
                timing: .init(now: { 0 }, suspend: { await Task.yield() }),
                sourceExecutionPause: { _ in await Task.yield() })
            for ordinal in 1...(multiple ? 4 : 1) {
                _ = try await service.request("book.search", ["sourceId": "method-source"],
                                            searchTraceAttempt: scopeTraceAttempt(recording, ordinal: UInt32(ordinal)))
            }
            await fulfillment(of: [entered], timeout: 2)
            if multiple {
                _ = try await service.request("book.search", ["sourceId": "method-source"],
                                            searchTraceAttempt: scopeTraceAttempt(recording, ordinal: 5))
                XCTAssertEqual(client.statusRequests.count, 4, "A fifth observer cannot enter while four status reads are held")
                client.releaseStatusResponses()
            }
            await fulfillment(of: [ended], timeout: 3)
            XCTAssertEqual(client.statusRequests.count, multiple ? 64 : 20)
            let ends = capture.events.filter { $0.stage == .coreExecutionObservationEnded }
            XCTAssertTrue(ends.allSatisfy { $0.coreExecutionObservationOutcome == .limited })
            XCTAssertFalse(ends.contains { $0.coreExecutionSummary?.isStrictlyRetired == true })
            if multiple {
                XCTAssertEqual(ends.filter { $0.sourceOrdinal == 5 }.count, 1)
                XCTAssertNil(ends.first { $0.sourceOrdinal == 5 }?.coreExecutionSummary)
            }
            try await service.close()
        }
    }

    func testSourceExecutionObserversRetireBeforeCloseAndConcurrentCloseKeepsAdmissionClosed() async throws {
        for concurrent in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderScopeTraceClose-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let statusEntered = expectation(description: "Diagnostic status read entered")
            let flushEntered = expectation(description: "Original close flush entered")
            let busyReturned = concurrent ? expectation(description: "Competing close kept the original flush owner") : nil
            let capture = CancellationTraceCapture()
            let client = SourceExecutionTraceCoreBoundary(holdStatusCount: 1, holdFlush: concurrent,
                onStatus: { _ in statusEntered.fulfill() }, onFlush: { flushEntered.fulfill() })
            let recording = ReaderSearchTraceRecording(searchID: UUID()) { capture.receive($0) }
            let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                sourceURL: root.appendingPathComponent("Sources"), client: client,
                timing: .init(now: { 0 }, suspend: { await Task.yield() }))
            _ = try await service.request("book.search", ["sourceId": "method-source"], searchTraceAttempt: scopeTraceAttempt(recording))
            await fulfillment(of: [statusEntered], timeout: 2)
            let first = Task { () -> Bool in
                do { try await service.close(); return true }
                catch ReaderLibraryError.busy { busyReturned?.fulfill(); return false }
                catch { XCTFail("Unexpected close failure"); return false }
            }
            var second: Task<Bool, Never>?
            if let busyReturned {
                second = Task {
                    do { try await service.close(); return true }
                    catch ReaderLibraryError.busy { busyReturned.fulfill(); return false }
                    catch { XCTFail("Unexpected competing close failure"); return false }
                }
                await fulfillment(of: [flushEntered, busyReturned], timeout: 2)
                let before = client.statusRequests.count
                _ = try await service.request("book.search", ["sourceId": "method-source"],
                                            searchTraceAttempt: scopeTraceAttempt(recording, ordinal: 2))
                XCTAssertEqual(client.statusRequests.count, before, "One failed close cannot reopen admission while another close owns its flush")
                XCTAssertEqual(capture.events.last { $0.stage == .coreExecutionObservationEnded && $0.sourceOrdinal == 2 }?.coreExecutionObservationOutcome,
                               .runtimeClosing)
                let polls = client.polls
                client.releaseStatusResponses() // A late positive status cannot revive the retired observer.
                XCTAssertEqual(client.polls, polls)
                client.releaseFlushResponses()
            } else {
                await fulfillment(of: [flushEntered], timeout: 2)
            }
            let firstClosed = await first.value
            if let second {
                let secondClosed = await second.value
                XCTAssertNotEqual(firstClosed, secondClosed, "Exactly one close owns the held flush")
            }
            else { XCTAssertTrue(firstClosed, "Diagnostics must not turn an otherwise idle close into BUSY") }
            let originalEnd = capture.events.first { $0.stage == .coreExecutionObservationEnded && $0.sourceOrdinal == 1 }
            XCTAssertEqual(originalEnd?.coreExecutionObservationOutcome, .runtimeClosing)
            XCTAssertEqual(client.statusRequests.count, 1)
            XCTAssertEqual(client.destroyCount, 1)
            do {
                _ = try await service.request("book.search", ["sourceId": "method-source"], searchTraceAttempt: scopeTraceAttempt(recording))
                XCTFail("A closed runtime cannot dispatch")
            } catch { }
            XCTAssertEqual(client.sendsAfterDestroy, 0)
        }
    }

    private func scopeTraceAttempt(_ recording: ReaderSearchTraceRecording, ordinal: UInt32 = 1) -> ReaderSearchTraceAttempt {
        .init(recording: recording, sourceOrdinal: ordinal, source: .init(sourceId: "method-source", name: "method", baseURL: "",
            enabled: true, version: "method-version", group: "", definition: Data()))
    }

    /// A controlled Core protocol boundary proves only the Host's actual
    /// cancel-call observations. It does not prove a native Core worker exit.
    func testCoreCancelTraceKeepsExactRequestAndSeparatesReturnTerminalAndRetirement() async throws {
        for cancelFails in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderCancelTrace-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let sent = expectation(description: "The original read was actually dispatched")
            let client = CancellationTraceCoreBoundary(cancelFails: cancelFails) { sent.fulfill() }
            let trace = CancellationTraceCapture()
            let recording = ReaderSearchTraceRecording(searchID: UUID()) { trace.receive($0) }
            let source = ReaderOnlineSource(sourceId: "method-source", name: "method", baseURL: "", enabled: true,
                version: "method-version", group: "", definition: Data())
            let attempt = ReaderSearchTraceAttempt(recording: recording, sourceOrdinal: 1, source: source)
            let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                sourceURL: root.appendingPathComponent("Sources"), client: client, timing: .live)
            let read = Task {
                try await service.request("book.search", ["sourceId": source.id], searchTraceAttempt: attempt)
            }
            await fulfillment(of: [sent], timeout: 2)
            read.cancel()
            do { _ = try await read.value; XCTFail("The cancelled original read cannot return a new business result") }
            catch { }
            let events = trace.events
            XCTAssertTrue(zip(events, events.dropFirst()).allSatisfy { pair in pair.0.elapsedNanoseconds <= pair.1.elapsedNanoseconds })
            let requestID = try XCTUnwrap(client.requestID)
            XCTAssertTrue(events.allSatisfy { $0.coreRequestID == requestID && $0.sourceOrdinal == 1 })
            let attempted = try XCTUnwrap(events.first { $0.stage == .coreCancelAttempted })
            let returned = try XCTUnwrap(events.first { $0.stage == .coreCancelReturned })
            XCTAssertEqual(client.cancelCount, 1)
            XCTAssertLessThan(attempted.sequence, returned.sequence)
            XCTAssertEqual(returned.outcome, cancelFails ? .failed : .succeeded)
            XCTAssertEqual(events.filter { $0.stage == .coreObservationEnded }.count, 1)
            if cancelFails {
                XCTAssertTrue(events.contains { $0.stage == .coreReadRetired })
                XCTAssertFalse(events.contains { $0.stage == .coreTerminal })
                XCTAssertEqual(client.retiredIDs, [requestID])
            } else {
                let terminal = try XCTUnwrap(events.first { $0.stage == .coreTerminal })
                XCTAssertEqual(terminal.outcome, .cancelled)
                XCTAssertLessThan(returned.sequence, terminal.sequence)
            }
            XCTAssertFalse(events.contains { $0.stage == .hostTransportDrained || $0.stage == .httpTaskCancelAttempted },
                "A Core call or observer return cannot fabricate Host or HTTP completion")
            try await service.close()
        }
    }

    /// Real Core supplies the Host envelope; the HTTP runner is deliberately
    /// held before returning. This is a registration/worker method, with no
    /// URLSession transfer, real source, Keychain or production library.
    func testRetiredHostDrainWaitsForActualHandlerJobAndCookieOperationRelease() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderHostDrainTrace-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let native = try ReaderCoreClient(configJSON: JSONSerialization.data(withJSONObject: ["dataDirectory": root.path]))
        defer { native.destroy(); try? FileManager.default.removeItem(at: root) }
        let requestID: UInt64 = 1701
        try native.send(method: "runtime.hostSmoke", requestId: requestID, params: [
            "capability": "http.execute", "params": ["url": "https://reader-method.invalid/"]
        ])
        let event = try await cancellationHostEnvelope(native, requestID: requestID)
        XCTAssertEqual(event.type, "host.request")
        let entered = expectation(description: "The registered HTTP worker reached the controlled runner")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let trace = CancellationTraceCapture()
        let recording = ReaderSearchTraceRecording(searchID: UUID()) { trace.receive($0) }
        let binding = ReaderSearchTraceBinding(recording: recording, sourceOrdinal: 1,
            requestID: requestID, operationID: nil, transport: nil)
        let cookies = ReaderSourceCookieStore(load: { _ in [] }, save: { _, _ in })
        let transport = ReaderIOSHostTransport(namespace: UUID().uuidString, cookieStore: cookies, httpRunner: { _, _, _ in
            entered.fulfill()
            guard release.wait(timeout: .now() + 5) == .success else { throw URLError(.timedOut) }
            return ["status": 200, "body": ""]
        })
        transport.bind(requestID: requestID, sourceID: nil, searchTrace: binding)
        let worker = Task { try await transport.handle(event, client: native, cancellableRead: true, searchTrace: binding) }
        await fulfillment(of: [entered], timeout: 2)
        transport.retireRead(requestID: requestID)
        let cancellation = try XCTUnwrap(trace.events.first { $0.stage == .hostCancellationRequested })
        let active = try XCTUnwrap(cancellation.hostWorkSummary)
        XCTAssertEqual(active.activeHandlerCount, 1)
        XCTAssertEqual(active.jobCount, 1)
        XCTAssertEqual(active.cookieOperationCount, 1)
        XCTAssertFalse(trace.events.contains { $0.stage == .hostTransportDrained },
            "Retirement and cancel() returning do not end the held worker")
        try native.cancel(requestId: requestID)
        release.signal()
        try await worker.value
        let events = trace.events
        XCTAssertTrue(zip(events, events.dropFirst()).allSatisfy { pair in pair.0.elapsedNanoseconds <= pair.1.elapsedNanoseconds })
        let drained = try XCTUnwrap(events.first { $0.stage == .hostTransportDrained })
        XCTAssertEqual(events.filter { $0.stage == .hostTransportDrained }.count, 1)
        XCTAssertEqual(drained.coreRequestID, requestID)
        XCTAssertEqual(drained.hostWorkSummary?.activeHandlerCount, 0)
        XCTAssertEqual(drained.hostWorkSummary?.jobCount, 0)
        XCTAssertEqual(drained.hostWorkSummary?.cookieOperationCount, 0)
        let finished = try XCTUnwrap(events.first { $0.stage == .hostOperationFinished })
        XCTAssertEqual(finished.outcome, .cancelled)
        XCTAssertLessThan(finished.sequence, drained.sequence)
        XCTAssertLessThan(cancellation.sequence, drained.sequence)
        XCTAssertFalse(events.contains { [.httpTaskCancelAttempted, .httpTaskCancelReturned, .httpSessionInvalidated].contains($0.stage) },
            "A controlled runner without a URLSession task cannot supply HTTP cancellation evidence")
        transport.cancel(requestID: requestID)
        XCTAssertEqual(trace.events.filter { $0.stage == .hostTransportDrained }.count, 1)
    }
}

private func cancellationHostEnvelope(_ client: ReaderCoreClient, requestID: UInt64) async throws -> ReaderCoreEvent {
    let end = ProcessInfo.processInfo.systemUptime + 2
    while ProcessInfo.processInfo.systemUptime < end {
        if let event = client.pollEvent(requestId: requestID) { return try event.get() }
        try await Task.sleep(nanoseconds: 1_000_000)
    }
    throw ReaderLibraryError.invalidResponse("Original Core method Host envelope missing")
}

private final class CancellationTraceCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [ReaderSearchTraceEvent] = []
    private let onEvent: @Sendable (ReaderSearchTraceEvent) -> Void
    init(onEvent: @escaping @Sendable (ReaderSearchTraceEvent) -> Void = { _ in }) { self.onEvent = onEvent }
    func receive(_ event: ReaderSearchTraceEvent) { lock.withLock { values.append(event) }; onEvent(event) }
    var events: [ReaderSearchTraceEvent] { lock.withLock { values.sorted { $0.sequence < $1.sequence } } }
}

private func sourceExecutionRow(_ requestID: UInt64, generation: UInt64, retired: Bool) -> [String: Any] {
    ["requestId": requestID, "generation": generation, "queuedWorkItemCount": 0,
     "runningWorkItemCount": retired ? 0 : 1, "continuationScopeCount": 0, "callbackScopeCount": 0,
     "retainedOwnerCount": retired ? 0 : 1, "startedWorkItemCount": 1,
     "finishedWorkItemCount": retired ? 1 : 0, "discardedWorkItemCount": 0, "retired": retired]
}
private func sourceExecutionStatus(_ requests: [[String: Any]], evicted: Int = 0) -> [String: Any] {
    ["sourceExecution": ["trackedMethods": ["book.search"], "requests": requests,
                         "evictedRetiredGenerationCount": evicted, "untrackedGenerationCount": 0]]
}
private final class SourceExecutionTraceClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: TimeInterval = 0
    var now: TimeInterval { lock.withLock { value } }
    func advance(_ delta: TimeInterval) { lock.withLock { value += delta } }
}

/// Request-specific replies only; this boundary has no global event consumer.
private final class SourceExecutionTraceCoreBoundary: ReaderCoreEventClient, @unchecked Sendable {
    private let lock = NSLock()
    private let holdStatusCount: Int
    private let holdFlush: Bool
    private let onStatus: @Sendable (Int) -> Void
    private let onFlush: @Sendable () -> Void
    private let response: @Sendable (Int, [UInt64]) -> [String: Any]
    private var searchIDs: [UInt64] = []
    private var statuses: [(id: UInt64, optedIn: Bool)] = []
    private var polledIDs: [UInt64] = []
    private var replies: [UInt64: ReaderCoreEvent] = [:]
    private var heldStatuses: [UInt64: ReaderCoreEvent] = [:]
    private var heldFlushes: [UInt64: ReaderCoreEvent] = [:]
    private var destroys = 0
    private var afterDestroy = 0

    init(holdStatusCount: Int = 0, holdFlush: Bool = false,
         onStatus: @escaping @Sendable (Int) -> Void = { _ in }, onFlush: @escaping @Sendable () -> Void = {},
         response: @escaping @Sendable (Int, [UInt64]) -> [String: Any] = { _, ids in
             sourceExecutionStatus(ids.map { sourceExecutionRow($0, generation: $0, retired: true) })
         }) {
        self.holdStatusCount = holdStatusCount; self.holdFlush = holdFlush
        self.onStatus = onStatus; self.onFlush = onFlush; self.response = response
    }
    var searchRequestIDs: [UInt64] { lock.withLock { searchIDs } }
    var statusRequests: [(id: UInt64, optedIn: Bool)] { lock.withLock { statuses } }
    var polls: [UInt64] { lock.withLock { polledIDs } }
    var destroyCount: Int { lock.withLock { destroys } }
    var sendsAfterDestroy: Int { lock.withLock { afterDestroy } }

    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        let live = lock.withLock { () -> Bool in
            if destroys > 0 { afterDestroy += 1; return false }; return true
        }
        guard live else { throw ReaderLibraryError.closed }
        switch method {
        case "book.search":
            let event = try terminal(requestId, data: ["sourceId": "method-source", "books": []])
            lock.withLock { searchIDs.append(requestId); replies[requestId] = event }
        case "runtime.status":
            let input = lock.withLock { () -> (Int, [UInt64]) in
                statuses.append((requestId, params.count == 1 && params["includeSourceExecution"] as? Bool == true))
                return (statuses.count, searchIDs)
            }
            let event = try terminal(requestId, data: response(input.0, input.1))
            lock.withLock {
                if input.0 <= holdStatusCount { heldStatuses[requestId] = event }
                else { replies[requestId] = event }
            }
            onStatus(input.0)
        case "runtime.storage.flush":
            let event = try terminal(requestId, data: [:])
            lock.withLock {
                if holdFlush { heldFlushes[requestId] = event }
                else { replies[requestId] = event }
            }
            onFlush()
        case "source.list":
            let event = try terminal(requestId, data: ["sources": []])
            lock.withLock { replies[requestId] = event }
        default: throw ReaderLibraryError.invalidResponse("Unexpected controlled scope method")
        }
        return requestId
    }
    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        lock.withLock {
            polledIDs.append(requestId)
            return replies.removeValue(forKey: requestId).map { .success($0) }
        }
    }
    func cancel(requestId: UInt64) throws {
        let event = try ReaderCoreEvent(data: JSONSerialization.data(withJSONObject: [
            "protocolVersion": ReaderCoreClient.protocolVersion, "requestId": requestId, "type": "error",
            "error": ["code": "CANCELLED", "message": "Controlled status cancellation", "retryable": false]
        ]))
        lock.withLock { replies[requestId] = event }
    }
    func retireReadRequest(requestId: UInt64) { lock.withLock { replies[requestId] = nil } }
    func releaseStatusResponses() {
        lock.withLock { for (id, event) in heldStatuses { replies[id] = event }; heldStatuses.removeAll() }
    }
    func releaseFlushResponses() {
        lock.withLock { for (id, event) in heldFlushes { replies[id] = event }; heldFlushes.removeAll() }
    }
    func destroy() { lock.withLock { destroys += 1 } }
    private func terminal(_ id: UInt64, data: [String: Any]) throws -> ReaderCoreEvent {
        try ReaderCoreEvent(data: JSONSerialization.data(withJSONObject: [
            "protocolVersion": ReaderCoreClient.protocolVersion, "requestId": id, "type": "result", "data": data
        ]))
    }
}

private final class CancellationTraceCoreBoundary: ReaderCoreEventClient, @unchecked Sendable {
    private let lock = NSLock()
    private let cancelFails: Bool
    private let onSend: @Sendable () -> Void
    private var selectedRequestID: UInt64?
    private var cancellations = 0
    private var retirements: [UInt64] = []
    private var terminal: ReaderCoreEvent?
    private var flushTerminals: [UInt64: ReaderCoreEvent] = [:]
    init(cancelFails: Bool, onSend: @escaping @Sendable () -> Void) { self.cancelFails = cancelFails; self.onSend = onSend }
    var requestID: UInt64? { lock.withLock { selectedRequestID } }
    var cancelCount: Int { lock.withLock { cancellations } }
    var retiredIDs: [UInt64] { lock.withLock { retirements } }
    @discardableResult
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        switch method {
        case "book.search":
            lock.withLock { selectedRequestID = requestId }
            onSend()
        case "runtime.storage.flush":
            let flushed = try ReaderCoreEvent(data: JSONSerialization.data(withJSONObject: [
                "protocolVersion": ReaderCoreClient.protocolVersion, "requestId": requestId,
                "type": "result", "data": [String: Any]()
            ]))
            lock.withLock { flushTerminals[requestId] = flushed }
        default:
            throw ReaderLibraryError.invalidResponse("Unexpected cancellation method fixture call: " + method)
        }
        return requestId
    }
    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        lock.withLock {
            if let flushed = flushTerminals.removeValue(forKey: requestId) { return .success(flushed) }
            guard requestId == selectedRequestID, let event = terminal else { return nil }
            terminal = nil
            return .success(event)
        }
    }
    func cancel(requestId: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        cancellations += 1
        if cancelFails { throw ReaderCoreClientError.cancelFailed(-1) }
        terminal = try ReaderCoreEvent(data: JSONSerialization.data(withJSONObject: [
            "protocolVersion": ReaderCoreClient.protocolVersion, "requestId": requestId, "type": "error",
            "error": ["code": "CANCELLED", "message": "Controlled original read cancellation", "retryable": false]
        ]))
    }
    func retireReadRequest(requestId: UInt64) { lock.withLock { retirements.append(requestId); terminal = nil } }
    func destroy() {}
}
