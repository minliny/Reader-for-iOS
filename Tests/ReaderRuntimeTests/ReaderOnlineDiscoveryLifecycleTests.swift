import Combine
import Foundation
import XCTest
@testable import Reader

/// Controlled protocol continuations test only the Host's discovery lifetime.
/// These DTO identities are not a book/source fixture or real network evidence.
@MainActor
final class ReaderOnlineDiscoveryLifecycleTests: XCTestCase {
    func testRetireDiscoveryCancelsOnlyReadsAndPreservesCandidateSnapshot() async throws {
        let service = DiscoveryControlledService()
        var state: ReaderOnlineWorkspaceModel? = ReaderOnlineWorkspaceModel()
        weak var weakState = state
        defer { state?.retireCachedDiscovery(); service.releaseAll() }
        state?.service = service; state?.query = "discovery identity"; state?.sourceFilter = "retained filter"
        let identity = UUID()
        state?.activateDiscoveryPresentation(identity)

        let listed = expectation(description: "Original source-list read entered")
        let firstFour = expectation(description: "Initial four exact search reads entered")
        firstFour.expectedFulfillmentCount = 4
        let fifth = expectation(description: "First result reduced before dispatching the fifth source")
        service.onSourcesEntered = { _ in listed.fulfill() }
        service.onSearchEntered = { count in
            if count <= 4 { firstFour.fulfill() }
            if count == 5 { fifth.fulfill() }
        }
        let listTask = Task { @MainActor [weak model = state] in
            await model?.refreshDiscoverySources(presentationID: identity)
        }
        defer { listTask.cancel() }
        await fulfillment(of: [listed], timeout: 2)
        try service.completeSources(0, with: .success(DiscoveryControlledService.sources(6)))
        await listTask.value
        await fulfillment(of: [firstFour], timeout: 2)
        try service.completeSearch(0)
        await fulfillment(of: [fifth], timeout: 2)
        state?.scrollAnchor = try XCTUnwrap(state?.results.first?.id)
        let snapshot = DiscoverySnapshot(try XCTUnwrap(state))
        XCTAssertEqual(snapshot.results.count, 1)
        XCTAssertEqual(snapshot.timings.count, 1)

        // Reattach an immutable accepted identity without executing a write.
        let originalActions = try XCTUnwrap(state?.actions)
        let originalID = "a33b3ba3-0bbf-4f8e-a1a2-fc042dbfe691"
        let originalScope = "discovery-contract|accepted-write"
        var writeExecutions = 0
        XCTAssertTrue(originalActions.restoreAccepted(id: originalID, label: "原操作", scope: originalScope) { id in
            writeExecutions += 1
            XCTAssertEqual(id, originalID)
            XCTFail("Discovery retirement must never execute the accepted write")
            throw DiscoveryControlledService.Failure.unsupported
        })

        var retainedValuePublications = 0
        let observations = [
            try XCTUnwrap(state).$results.dropFirst().sink { _ in retainedValuePublications += 1 },
            try XCTUnwrap(state).$timings.dropFirst().sink { _ in retainedValuePublications += 1 },
            try XCTUnwrap(state).$sources.dropFirst().sink { _ in retainedValuePublications += 1 },
            try XCTUnwrap(state).$query.dropFirst().sink { _ in retainedValuePublications += 1 },
            try XCTUnwrap(state).$scrollAnchor.dropFirst().sink { _ in retainedValuePublications += 1 },
            try XCTUnwrap(state).$currentResultIDs.dropFirst().sink { _ in retainedValuePublications += 1 }
        ]
        defer { observations.forEach { $0.cancel() } }
        let cancelled = expectation(description: "Every remaining original search read observed cancellation")
        cancelled.expectedFulfillmentCount = 4
        service.onSearchCancelled = { _ in cancelled.fulfill() }
        state?.retireDiscoveryPresentation(identity)
        await fulfillment(of: [cancelled], timeout: 2)
        XCTAssertEqual(service.cancelledSearches, Set(1...4))
        XCTAssertFalse(try XCTUnwrap(state).searching)
        XCTAssertFalse(try XCTUnwrap(state).sourceLoading)
        XCTAssertTrue(try XCTUnwrap(state).stopped)
        XCTAssertEqual(DiscoverySnapshot(try XCTUnwrap(state)), snapshot)

        // Return successful late responses despite cancellation. The actual
        // model must drain them without publishing or dispatching source six.
        state = nil
        try service.completeRemainingSearches()
        let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in weakState == nil }, object: nil)
        await fulfillment(of: [released], timeout: 2)
        XCTAssertNil(weakState, "Completed retired discovery must release its strong Task capture")
        XCTAssertEqual(service.searchCalls.count, 5)
        XCTAssertEqual(retainedValuePublications, 0)
        XCTAssertEqual(originalActions.pendingOperationID, originalID)
        XCTAssertEqual(originalActions.scope, originalScope)
        XCTAssertTrue(originalActions.hasPending)
        XCTAssertFalse(originalActions.busy)
        XCTAssertEqual(writeExecutions, 0)
        XCTAssertTrue(service.writeCalls.isEmpty)
    }

    func testLateSourceListAfterRetirementCannotStartDiscoveryOrPublishFailure() async throws {
        for succeeds in [true, false] {
            let service = DiscoveryControlledService()
            let state = ReaderOnlineWorkspaceModel()
            defer { state.retireCachedDiscovery(); service.releaseAll() }
            state.service = service; state.query = "retained query"
            state.sources = DiscoveryControlledService.sources(1)
            state.results = [ReaderOnlineCandidate(sourceId: "retained", bookId: "candidate", title: "Retained identity")]
            state.timings = ["retained": 17]; state.scrollAnchor = state.results[0].id
            state.sourceReadFailure = "retained source observation"
            let snapshot = DiscoverySnapshot(state)
            let identity = UUID(); state.activateDiscoveryPresentation(identity)
            let entered = expectation(description: "Source read entered before retirement")
            let cancelled = expectation(description: "Original source read received cancellation")
            service.onSourcesEntered = { _ in entered.fulfill() }
            service.onSourcesCancelled = { _ in cancelled.fulfill() }
            let task = Task { await state.refreshDiscoverySources(presentationID: identity) }
            defer { task.cancel() }
            await fulfillment(of: [entered], timeout: 2)
            state.retireDiscoveryPresentation(identity)
            await fulfillment(of: [cancelled], timeout: 2)
            let late: Result<[ReaderOnlineSource], Error> = succeeds
                ? .success(DiscoveryControlledService.sources(2)) : .failure(DiscoveryControlledService.Failure.lateRead)
            try service.completeSources(0, with: late)
            await task.value
            // This is also the stale retry entry: it must not issue a read.
            await state.refreshDiscoverySources(presentationID: identity)
            XCTAssertEqual(service.sourceReadCount, 1)
            XCTAssertTrue(service.searchCalls.isEmpty)
            XCTAssertEqual(DiscoverySnapshot(state), snapshot)
            XCTAssertFalse(state.searched)
            XCTAssertFalse(state.searching)
            XCTAssertFalse(state.sourceLoading)
            XCTAssertTrue(service.writeCalls.isEmpty)
        }
    }

    func testOldPresentationCannotRetireReopenedOwnerAndEvictionReleasesReadLifetime() async throws {
        let service = DiscoveryControlledService()
        var state: ReaderOnlineWorkspaceModel? = ReaderOnlineWorkspaceModel()
        weak var weakState = state
        defer { state?.retireCachedDiscovery(); service.releaseAll() }
        state?.service = service; state?.query = "retained query"; state?.searched = true
        state?.sources = DiscoveryControlledService.sources(1)
        state?.results = [ReaderOnlineCandidate(sourceId: "retained", bookId: "candidate", title: "Retained identity")]
        state?.timings = ["retained": 23]
        let snapshot = DiscoverySnapshot(try XCTUnwrap(state))
        let oldID = UUID(), currentID = UUID()
        let oldEntered = expectation(description: "Old presentation source read entered")
        let currentEntered = expectation(description: "Reopened presentation source read entered")
        let oldCancelled = expectation(description: "Old read cancellation delivered")
        let currentCancelled = expectation(description: "Cache retirement cancelled reopened read")
        service.onSourcesEntered = { index in
            if index == 0 { oldEntered.fulfill() }
            if index == 1 { currentEntered.fulfill() }
        }
        service.onSourcesCancelled = { index in
            if index == 0 { oldCancelled.fulfill() }
            if index == 1 { currentCancelled.fulfill() }
        }
        state?.activateDiscoveryPresentation(oldID)
        let oldTask = Task { @MainActor [weak model = state] in
            await model?.refreshDiscoverySources(presentationID: oldID)
        }
        defer { oldTask.cancel() }
        await fulfillment(of: [oldEntered], timeout: 2)
        state?.retireDiscoveryPresentation(oldID)
        await fulfillment(of: [oldCancelled], timeout: 2)
        state?.activateDiscoveryPresentation(currentID)
        let currentTask = Task { @MainActor [weak model = state] in
            await model?.refreshDiscoverySources(presentationID: currentID)
        }
        defer { currentTask.cancel() }
        await fulfillment(of: [currentEntered], timeout: 2)

        // The MainActor cannot run this queued old activation before cancel().
        let cancelledOldActivation = Task { @MainActor [weak model = state] in
            model?.activateDiscoveryPresentation(oldID)
        }
        cancelledOldActivation.cancel()
        await cancelledOldActivation.value
        try service.completeSources(0, with: .success(DiscoveryControlledService.sources(3)))
        await oldTask.value
        state?.retireDiscoveryPresentation(oldID)
        XCTAssertTrue(try XCTUnwrap(state).isCurrentDiscoveryPresentation(currentID))
        XCTAssertTrue(try XCTUnwrap(state).sourceLoading)
        XCTAssertEqual(service.cancelledSources, [0])
        XCTAssertEqual(service.sourceReadCount, 2)
        XCTAssertEqual(DiscoverySnapshot(try XCTUnwrap(state)), snapshot)

        // This is the production hook used by the bounded presentation cache.
        state?.retireCachedDiscovery()
        await fulfillment(of: [currentCancelled], timeout: 2)
        XCTAssertFalse(try XCTUnwrap(state).isCurrentDiscoveryPresentation(currentID))
        XCTAssertFalse(try XCTUnwrap(state).sourceLoading)
        XCTAssertEqual(DiscoverySnapshot(try XCTUnwrap(state)), snapshot)
        state = nil
        try service.completeSources(1, with: .success(DiscoveryControlledService.sources(4)))
        await currentTask.value
        let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in weakState == nil }, object: nil)
        await fulfillment(of: [released], timeout: 2)
        XCTAssertNil(weakState)
        XCTAssertEqual(service.cancelledSources, [0, 1])
        XCTAssertTrue(service.searchCalls.isEmpty)
        XCTAssertTrue(service.writeCalls.isEmpty)
    }
}

private struct DiscoverySnapshot: Equatable {
    let query: String
    let filter: String
    let sources: [ReaderOnlineSource]
    let results: [ReaderOnlineCandidate]
    let timings: [String: Int]
    let failures: [String: String]
    let currentResultIDs: Set<String>
    let scrollAnchor: String?
    let sourceReadFailure: String?
    let sourceReadFailureID: UUID?
    @MainActor init(_ state: ReaderOnlineWorkspaceModel) {
        query = state.query; filter = state.sourceFilter; sources = state.sources
        results = state.results; timings = state.timings; failures = state.failures
        currentResultIDs = state.currentResultIDs; scrollAnchor = state.scrollAnchor
        sourceReadFailure = state.sourceReadFailure; sourceReadFailureID = state.sourceReadFailureID
    }
}

@MainActor
private final class DiscoveryControlledService: ReaderOnlineServing {
    enum Failure: Error { case unsupported, lateRead, teardown, missingContinuation }
    struct SearchCall { let sourceID: String; let keyword: String; let page: Int }
    private(set) var sourceReadCount = 0
    private(set) var searchCalls: [SearchCall] = []
    private(set) var cancelledSources = Set<Int>()
    private(set) var cancelledSearches = Set<Int>()
    private(set) var writeCalls: [String] = []
    var onSourcesEntered: ((Int) -> Void)?
    var onSourcesCancelled: ((Int) -> Void)?
    var onSearchEntered: ((Int) -> Void)?
    var onSearchCancelled: ((Int) -> Void)?
    private var sourceReads: [Int: CheckedContinuation<[ReaderOnlineSource], Error>] = [:]
    private var searches: [Int: CheckedContinuation<ReaderSourceSearchResult, Error>] = [:]
    private var closed = false

    static func sources(_ count: Int) -> [ReaderOnlineSource] {
        (0..<count).map {
            ReaderOnlineSource(sourceId: "discovery-contract-\($0)", name: "Source identity \($0)",
                baseURL: "", enabled: true, version: "contract-1", group: "", definition: Data())
        }
    }

    func onlineSources() async throws -> [ReaderOnlineSource] {
        guard !closed else { throw Failure.teardown }
        let index = sourceReadCount; sourceReadCount += 1
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                sourceReads[index] = continuation; onSourcesEntered?(index)
            }
        }, onCancel: { [weak self] in
            Task { @MainActor in
                guard let self, self.cancelledSources.insert(index).inserted else { return }
                self.onSourcesCancelled?(index)
            }
        })
    }

    func searchSource(_ sourceID: String, keyword: String, page: Int) async throws -> ReaderSourceSearchResult {
        guard !closed else { throw Failure.teardown }
        let index = searchCalls.count
        searchCalls.append(.init(sourceID: sourceID, keyword: keyword, page: page))
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                searches[index] = continuation; onSearchEntered?(index + 1)
            }
        }, onCancel: { [weak self] in
            Task { @MainActor in
                guard let self, self.cancelledSearches.insert(index).inserted else { return }
                self.onSearchCancelled?(index)
            }
        })
    }

    func completeSources(_ index: Int, with result: Result<[ReaderOnlineSource], Error>) throws {
        guard let continuation = sourceReads.removeValue(forKey: index) else {
            XCTFail("The exact source read has not entered"); throw Failure.missingContinuation
        }
        continuation.resume(with: result)
    }
    func completeSearch(_ index: Int) throws {
        guard let continuation = searches.removeValue(forKey: index) else {
            XCTFail("The exact search read has not entered"); throw Failure.missingContinuation
        }
        let call = searchCalls[index]
        continuation.resume(returning: .init(sourceId: call.sourceID,
            books: [.init(sourceId: call.sourceID, bookId: "candidate-\(index)", title: "Candidate identity \(index)")],
            elapsedMilliseconds: 10 + index, timing: nil))
    }
    func completeRemainingSearches() throws { for index in searches.keys.sorted() { try completeSearch(index) } }
    func releaseAll() {
        closed = true
        onSourcesEntered = nil; onSourcesCancelled = nil; onSearchEntered = nil; onSearchCancelled = nil
        let reads = sourceReads; sourceReads.removeAll()
        let pendingSearches = searches; searches.removeAll()
        for continuation in reads.values { continuation.resume(throwing: Failure.teardown) }
        for continuation in pendingSearches.values { continuation.resume(throwing: Failure.teardown) }
    }

    private func unexpectedRead<T>(_ name: String) throws -> T {
        XCTFail("Unselected read boundary: \(name)"); throw Failure.unsupported
    }
    private func forbiddenWrite<T>(_ name: String) throws -> T {
        writeCalls.append(name); XCTFail("Discovery crossed write boundary: \(name)"); throw Failure.unsupported
    }
    func listBooks() async throws -> [ReaderBook] { try unexpectedRead("listBooks") }
    func chapters(for book: ReaderBook) async throws -> [ReaderChapter] { try unexpectedRead("chapters") }
    func content(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderChapterContent { try unexpectedRead("content") }
    func progress(for book: ReaderBook) async throws -> ReaderProgressSnapshot { try unexpectedRead("progress") }
    func pendingImports() async throws -> [ReaderPendingImport] { try unexpectedRead("pendingImports") }
    func importBook(at url: URL) async throws -> ReaderImportResult { try forbiddenWrite("importBook") }
    func reconcilePendingProgress(for book: ReaderBook) async throws -> ReaderProgressSnapshot? { try forbiddenWrite("reconcilePendingProgress") }
    func saveProgress(for book: ReaderBook, content: ReaderChapterContent, scalarOffset: UInt64,
                      expectedRevision: String?) async throws -> ReaderProgressSnapshot { try forbiddenWrite("saveProgress") }
    func flush() async throws { let _: Void = try forbiddenWrite("flush") }
    func close() async throws { let _: Void = try forbiddenWrite("close") }
    func recoverPendingImports() async throws -> [ReaderPendingImport] { try forbiddenWrite("recoverPendingImports") }
    func importSources(_ data: Data, operationID: String) async throws -> [ReaderSourceImportItem] { try forbiddenWrite("importSources") }
    func updateSource(_ sourceID: String, enabled: Bool, operationID: String) async throws { let _: Void = try forbiddenWrite("updateSource") }
    func deleteSource(_ sourceID: String, operationID: String) async throws { let _: Void = try forbiddenWrite("deleteSource") }
    func addOnlineBook(_ detail: ReaderOnlineDetail, chapterIndex: UInt32, operationID: String) async throws -> ReaderBook { try forbiddenWrite("addOnlineBook") }
    func completeLogin(_ sourceID: String, cookies: [HTTPCookie], originalCookies: [HTTPCookie]) async throws { let _: Void = try forbiddenWrite("completeLogin") }
    func onlineCommand(_ method: String, parameters: Data, operationID: String?) async throws -> Data { try forbiddenWrite("onlineCommand") }
    func validateSources(_ data: Data) async throws -> [ReaderSourceImportItem] { try unexpectedRead("validateSources") }
    func exportSources(_ identities: [String]?) async throws -> Data { try unexpectedRead("exportSources") }
    func onlineDetail(_ candidate: ReaderOnlineCandidate) async throws -> ReaderOnlineDetail { try unexpectedRead("onlineDetail") }
    func refreshOnlineCatalog(for book: ReaderBook) async throws -> ReaderOnlineDetail { try unexpectedRead("refreshOnlineCatalog") }
    func onlineDiagnostic(_ sourceID: String, keyword: String) async throws -> Data { try unexpectedRead("onlineDiagnostic") }
    func onlineFetch(_ url: URL) async throws -> Data { try unexpectedRead("onlineFetch") }
    func prepareLogin(_ sourceID: String) async throws -> [HTTPCookie] { try unexpectedRead("prepareLogin") }
}
