import XCTest
import Foundation
@testable import Reader

/// Production loader plus controlled asynchronous reads and method-only Data.
/// No archive, generated novel, parser, Core, WK navigation or App state.
@MainActor
final class ReaderEbookResourceBudgetTests: XCTestCase {
    private let mib = 1024 * 1024

    func testQueuedShortReadsWaitWithoutTransientResourceLimitAndRefundOnlyUnusedBytes() async throws {
        let reads = ControlledEbookEntryReads()
        let loader = ReaderEbookResourceLoader(readEntry: { entry, maximum in
            try await reads.read(entry, maximumBytes: maximum)
        })
        let firstEntered = expectation(description: "first original read")
        reads.expect("first", firstEntered)
        let first = Task { try await loader.load("first", mime: "text/css") }
        defer { first.cancel(); reads.failAll() }
        await fulfillment(of: [firstEntered], timeout: 2)
        let noQueuedRead = expectation(description: "queued reads cannot overlap first")
        let noQueuedReturn = expectation(description: "temporary allowance cannot reject a caller")
        noQueuedRead.isInverted = true; noQueuedReturn.isInverted = true
        reads.expect("second", noQueuedRead); reads.expect("third", noQueuedRead)
        reads.automaticallySucceed("second", count: mib)
        reads.automaticallySucceed("third", count: 32 * mib)
        let secondRequested = expectation(description: "second caller started")
        let thirdRequested = expectation(description: "third caller started")
        let secondNotice = CompletionNotice(noQueuedReturn)
        let thirdNotice = CompletionNotice(noQueuedReturn)
        let second = Task {
            secondRequested.fulfill(); defer { secondNotice.fulfill() }
            return try await loader.load("second", mime: "text/css")
        }
        let third = Task {
            thirdRequested.fulfill(); defer { thirdNotice.fulfill() }
            return try await loader.load("third", mime: "text/css")
        }
        defer { second.cancel(); third.cancel() }
        await fulfillment(of: [secondRequested, thirdRequested], timeout: 2)
        await fulfillment(of: [noQueuedRead, noQueuedReturn], timeout: 0.05)
        XCTAssertEqual(reads.calls.map(\.entry), ["first"])
        let queuedEntered = expectation(description: "both queued reads eventually enter")
        let queuedReturned = expectation(description: "both queued callers finish without missing resource")
        queuedEntered.expectedFulfillmentCount = 2; queuedReturned.expectedFulfillmentCount = 2
        reads.expect("second", queuedEntered); reads.expect("third", queuedEntered)
        secondNotice.replace(with: queuedReturned); thirdNotice.replace(with: queuedReturned)
        reads.succeed("first", Data(count: mib))
        _ = try await first.value
        await fulfillment(of: [queuedEntered, queuedReturned], timeout: 2)
        let secondValue = try await second.value
        let thirdValue = try await third.value
        XCTAssertEqual(secondValue.0.count, mib)
        XCTAssertEqual(thirdValue.0.count, 32 * mib)
        XCTAssertEqual(Set(reads.calls.map(\.entry)), Set(["first", "second", "third"]))
        // Task-to-actor arrival order is not promised. The exact cumulative
        // 1+1+32MiB is invariant whichever queued caller reaches the gate first.
        let restEntered = expectation(description: "only unused allowance remains")
        reads.expect("rest", restEntered)
        let rest = Task { try await loader.load("rest", mime: "text/css") }
        defer { rest.cancel() }
        await fulfillment(of: [restEntered], timeout: 2)
        XCTAssertEqual(reads.calls.last?.maximumBytes, 30 * mib)
        reads.succeed("rest", Data(count: 30 * mib))
        _ = try await rest.value
        await requireRejectedBeforeRead(loader, reads: reads, entry: "only-after-actual64MiB")
    }

    func testTwoFull32MiBReadsExhaustActualBudgetBeforeThirdReaderCall() async throws {
        let reads = ControlledEbookEntryReads()
        let loader = ReaderEbookResourceLoader(readEntry: { entry, maximum in
            try await reads.read(entry, maximumBytes: maximum)
        })
        let firstEntered = expectation(description: "first32 entered")
        reads.expect("first32", firstEntered)
        let first = Task { try await loader.load("first32", mime: "text/css") }
        defer { first.cancel(); reads.failAll() }
        await fulfillment(of: [firstEntered], timeout: 2)
        let noQueuedRead = expectation(description: "no queued read overlaps first")
        let noQueuedReturn = expectation(description: "neither caller fails on temporary reservation")
        noQueuedRead.isInverted = true; noQueuedReturn.isInverted = true
        reads.expect("queued-a", noQueuedRead); reads.expect("queued-b", noQueuedRead)
        reads.automaticallySucceed("queued-a", count: 32 * mib)
        reads.automaticallySucceed("queued-b", count: 32 * mib)
        let aRequested = expectation(description: "queued-a caller")
        let bRequested = expectation(description: "queued-b caller")
        let aNotice = CompletionNotice(noQueuedReturn)
        let bNotice = CompletionNotice(noQueuedReturn)
        let a = Task {
            aRequested.fulfill(); defer { aNotice.fulfill() }
            return try await loader.load("queued-a", mime: "text/css")
        }
        let b = Task {
            bRequested.fulfill(); defer { bNotice.fulfill() }
            return try await loader.load("queued-b", mime: "text/css")
        }
        defer { a.cancel(); b.cancel() }
        await fulfillment(of: [aRequested, bRequested], timeout: 2)
        await fulfillment(of: [noQueuedRead, noQueuedReturn], timeout: 0.05)
        let oneQueuedRead = expectation(description: "one further32MiB read allowed")
        let bothReturned = expectation(description: "one succeeds and one sees actual spent limit")
        bothReturned.expectedFulfillmentCount = 2
        reads.expect("queued-a", oneQueuedRead); reads.expect("queued-b", oneQueuedRead)
        aNotice.replace(with: bothReturned); bNotice.replace(with: bothReturned)
        reads.succeed("first32", Data(count: 32 * mib))
        _ = try await first.value
        await fulfillment(of: [oneQueuedRead, bothReturned], timeout: 2)
        let results = [await a.result, await b.result]
        var successes = 0
        var limits = 0
        for result in results {
            switch result {
            case .success(let value): XCTAssertEqual(value.0.count, 32 * mib); successes += 1
            case .failure(let error): XCTAssertEqual(error as? ReaderEbookError, .resourceLimit); limits += 1
            }
        }
        XCTAssertEqual(successes, 1)
        XCTAssertEqual(limits, 1)
        XCTAssertEqual(reads.calls.count, 2, "Third physical read must never start after actual64MiB spend")
        XCTAssertTrue(reads.calls.allSatisfy { $0.maximumBytes == 32 * mib })
        await requireRejectedBeforeRead(loader, reads: reads, entry: "spent-remains-spent")
    }

    func testReadFailureAndActiveCancellationReleaseOnlyAfterOriginalReadTerminates() async throws {
        for cancel in [false, true] {
            let reads = ControlledEbookEntryReads()
            let loader = ReaderEbookResourceLoader(readEntry: { entry, maximum in
                try await reads.read(entry, maximumBytes: maximum)
            })
            let originalEntered = expectation(description: "original read entered cancel=\(cancel)")
            reads.expect("original", originalEntered)
            let original = Task { try await loader.load("original", mime: "text/css") }
            defer { original.cancel(); reads.failAll() }
            await fulfillment(of: [originalEntered], timeout: 2)
            let noNext = expectation(description: "next cannot overlap original cancel=\(cancel)")
            noNext.isInverted = true
            reads.expect("next", noNext)
            let nextRequested = expectation(description: "next caller")
            let next = Task { nextRequested.fulfill(); return try await loader.load("next", mime: "text/css") }
            defer { next.cancel() }
            await fulfillment(of: [nextRequested], timeout: 2)
            if cancel { original.cancel() }
            await fulfillment(of: [noNext], timeout: 0.05)
            XCTAssertEqual(reads.calls.map(\.entry), ["original"])
            let nextEntered = expectation(description: "next after real original termination")
            reads.expect("next", nextEntered)
            if cancel { reads.succeed("original", Data(count: mib)) }
            else { reads.failIfPending("original", error: .read) }
            switch await original.result {
            case .success: XCTFail("Original failure/cancellation must propagate")
            case .failure(let error):
                if cancel { XCTAssertTrue(error is CancellationError) }
                else { XCTAssertEqual(error as? ControlledEbookEntryReads.Failure, .read) }
            }
            await fulfillment(of: [nextEntered], timeout: 2)
            XCTAssertEqual(reads.calls.last?.maximumBytes, 32 * mib)
            reads.succeed("next", Data(count: 32 * mib))
            _ = try await next.value
            let final = await completedLoad(loader, reads: reads, entry: "last32", mime: "text/css", data: Data(count: 32 * mib))
            _ = try final.get()
            await requireRejectedBeforeRead(loader, reads: reads, entry: "no-refund-twice")
        }
    }

    func testCancelledWaiterAndRetirementDrainWithoutWaitingForActiveRead() async throws {
        let reads = ControlledEbookEntryReads()
        let loader = ReaderEbookResourceLoader(readEntry: { entry, maximum in
            try await reads.read(entry, maximumBytes: maximum)
        })
        let activeEntered = expectation(description: "noncooperative active read")
        reads.expect("active", activeEntered)
        let active = Task { try await loader.load("active", mime: "text/css") }
        defer { active.cancel(); reads.failAll() }
        await fulfillment(of: [activeEntered], timeout: 2)
        let waitingRequested = expectation(description: "waiting caller started")
        let waitingEnded = expectation(description: "cancelled waiter ends before active return")
        let waiting = Task {
            waitingRequested.fulfill()
            defer { waitingEnded.fulfill() }
            return try await loader.load("cancel-waiter", mime: "text/css")
        }
        defer { waiting.cancel() }
        await fulfillment(of: [waitingRequested], timeout: 2)
        waiting.cancel()
        await fulfillment(of: [waitingEnded], timeout: 2)
        requireCancellation(await waiting.result)
        XCTAssertEqual(reads.calls.map(\.entry), ["active"])
        let retiredRequested = expectation(description: "another waiting caller started")
        let retiredEnded = expectation(description: "retire drains waiter before active return")
        let retired = Task {
            retiredRequested.fulfill()
            defer { retiredEnded.fulfill() }
            return try await loader.load("retire-waiter", mime: "text/css")
        }
        defer { retired.cancel() }
        await fulfillment(of: [retiredRequested], timeout: 2)
        await loader.retire()
        await loader.retire()
        await fulfillment(of: [retiredEnded], timeout: 2)
        requireCancellation(await retired.result)
        XCTAssertEqual(reads.calls.map(\.entry), ["active"])
        do {
            _ = try await loader.load("after-retire", mime: "text/css")
            XCTFail("Retired document cannot accept new work")
        } catch { XCTAssertTrue(error is CancellationError) }
        reads.succeed("active", Data(count: mib))
        requireCancellation(await active.result)
        XCTAssertEqual(reads.calls.map(\.entry), ["active"])
    }

    func testPixelFailuresKeepCommittedByteChargesAndPreviouslySpentPixels() async throws {
        let reads = ControlledEbookEntryReads()
        let loader = ReaderEbookResourceLoader(readEntry: { entry, maximum in
            try await reads.read(entry, maximumBytes: maximum)
        })
        defer { reads.failAll() }
        let invalid = Data([0])
        requireResourceLimit(await completedLoad(loader, reads: reads, entry: "invalid-image", mime: "image/png", data: invalid))
        let svg = Data("<svg xmlns=\"http://www.w3.org/2000/svg\"/>".utf8)
        for index in 0..<5 {
            let result = await completedLoad(loader, reads: reads, entry: "svg-\(index)", mime: "image/svg+xml", data: svg)
            if index < 3 {
                let value = try result.get()
                XCTAssertEqual(value.0, svg)
                XCTAssertEqual(value.1, "image/svg+xml")
            } else { requireResourceLimit(result) }
        }
        let charged = invalid.count + 5 * svg.count
        let bodyFirst = await completedLoad(loader, reads: reads, entry: "body-first", mime: "text/css", data: Data(count: 32 * mib))
        _ = try bodyFirst.get()
        XCTAssertEqual(reads.calls.last?.maximumBytes, 32 * mib)
        let bodyRest = await completedLoad(loader, reads: reads, entry: "body-rest", mime: "text/css", data: Data(count: 32 * mib - charged))
        _ = try bodyRest.get()
        XCTAssertEqual(reads.calls.last?.maximumBytes, 32 * mib - charged)
        await requireRejectedBeforeRead(loader, reads: reads, entry: "processing-charges-still-spent")
    }

    private func requireCancellation(_ result: Result<(Data, String), Error>,
                                     file: StaticString = #filePath, line: UInt = #line) {
        switch result {
        case .success: XCTFail("Expected original cancellation", file: file, line: line)
        case .failure(let error): XCTAssertTrue(error is CancellationError, file: file, line: line)
        }
    }

    private func requireRejectedBeforeRead(_ loader: ReaderEbookResourceLoader, reads: ControlledEbookEntryReads,
                                          entry: String, file: StaticString = #filePath, line: UInt = #line) async {
        let calls = reads.calls
        let returned = expectation(description: "budget rejection before read: \(entry)")
        let attempt = Task {
            defer { returned.fulfill() }
            return try await loader.load(entry, mime: "text/css")
        }
        await fulfillment(of: [returned], timeout: 2)
        // If admission regresses, release that unexpected read after recording
        // the bounded wait failure. Do not leave a continuation/test hung.
        reads.failIfPending(entry, error: ControlledEbookEntryReads.Failure.cleanup)
        let result = await attempt.result
        XCTAssertEqual(reads.calls, calls, "Rejected entry must never call the reader", file: file, line: line)
        requireResourceLimit(result, file: file, line: line)
    }

    private func completedLoad(_ loader: ReaderEbookResourceLoader, reads: ControlledEbookEntryReads,
                               entry: String, mime: String, data: Data) async -> Result<(Data, String), Error> {
        let entered = expectation(description: "read entered: \(entry)")
        reads.expect(entry, entered)
        let task = Task { try await loader.load(entry, mime: mime) }
        await fulfillment(of: [entered], timeout: 2)
        reads.succeed(entry, data)
        return await task.result
    }

    private func requireResourceLimit(_ result: Result<(Data, String), Error>,
                                      file: StaticString = #filePath, line: UInt = #line) {
        switch result {
        case .success: XCTFail("Expected production resource limit", file: file, line: line)
        case .failure(let error): XCTAssertEqual(error as? ReaderEbookError, .resourceLimit, file: file, line: line)
        }
    }
}

@MainActor
private final class ControlledEbookEntryReads {
    enum Failure: Error, Equatable { case read, cleanup }
    struct Call: Equatable { let entry: String; let maximumBytes: Int }
    private(set) var calls: [Call] = []
    private var notices: [String: XCTestExpectation] = [:]
    private var pending: [String: CheckedContinuation<Data, Error>] = [:]
    private var automaticByteCounts: [String: Int] = [:]

    func expect(_ entry: String, _ notice: XCTestExpectation) { notices[entry] = notice }
    func automaticallySucceed(_ entry: String, count: Int) { automaticByteCounts[entry] = count }

    func read(_ entry: String, maximumBytes: Int) async throws -> Data {
        calls.append(.init(entry: entry, maximumBytes: maximumBytes))
        if let count = automaticByteCounts.removeValue(forKey: entry) {
            notices.removeValue(forKey: entry)?.fulfill()
            return Data(count: count)
        }
        return try await withCheckedThrowingContinuation { continuation in
            precondition(pending[entry] == nil)
            pending[entry] = continuation
            notices.removeValue(forKey: entry)?.fulfill()
        }
    }

    func succeed(_ entry: String, _ data: Data, file: StaticString = #filePath, line: UInt = #line) {
        guard let continuation = pending.removeValue(forKey: entry) else {
            XCTFail("Expected original pending read: \(entry)", file: file, line: line)
            return
        }
        continuation.resume(returning: data)
    }

    func failIfPending(_ entry: String, error: Failure) {
        pending.removeValue(forKey: entry)?.resume(throwing: error)
    }

    func failAll() {
        let originals = Array(pending.values)
        pending.removeAll()
        originals.forEach { $0.resume(throwing: Failure.cleanup) }
    }
}

/// Test-only completion routing; no production state or gate is introduced.
@MainActor
private final class CompletionNotice {
    private var notice: XCTestExpectation
    init(_ notice: XCTestExpectation) { self.notice = notice }
    func replace(with notice: XCTestExpectation) { self.notice = notice }
    func fulfill() { notice.fulfill() }
}
