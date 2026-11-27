import Foundation
import ReaderCoreBridge

@MainActor
final class DownloadCoordinator {
    enum Failure: Error {
        case operationInFlight
        case invalidOperationIdentity
        case originalUnresolved(M2CacheDownloadOperationQueryParams)
    }

    private struct Scope: Hashable {
        let sourceId: String
        let bookId: String
    }

    private struct JournalEntry: Codable {
        let prefetch: M2CacheBookPrefetchParams
        var reports: [M2CacheChapterMaterializationReportParams] = []
    }

    private let runtime: CoreRuntimeActor
    // The file holds original RPC parameters only. Core supplies task states and receipts.
    private let journal: URL?
    private var owners: [Scope: Task<CoreOperation<M2CacheBookPrefetchData>, any Error>] = [:]
    private var recovering: Set<Scope> = []
    private var taskControls: Set<ControlScope> = []
    private(set) var panelGeneration = 0

    init(runtime: CoreRuntimeActor, journal: URL? = nil) {
        self.runtime = runtime
        self.journal = journal
    }

    func retirePanel() { panelGeneration += 1 }

    func isWorking(sourceId: String, bookId: String) -> Bool {
        let scope = Scope(sourceId: sourceId, bookId: bookId)
        return owners[scope] != nil || recovering.contains(scope)
    }

    func pendingOperations() throws -> [M2CacheBookPrefetchParams] {
        try saved().map(\.prefetch)
    }

    func begin(_ draft: M2CacheBookPrefetchParams) throws -> Task<CoreOperation<M2CacheBookPrefetchData>, any Error> {
        let scope = Scope(sourceId: draft.sourceId, bookId: draft.bookId)
        guard owners[scope] == nil, !recovering.contains(scope) else { throw Failure.operationInFlight }
        let owner = Task {
            defer { owners.removeValue(forKey: scope) }
            let params = try await bind(draft)
            let original = try prefetchQuery(params)
            try remember(params)
            let terminal = try await runtime.request(ReaderM2.cacheBookPrefetch, params)
            let receipt = try await confirm(original)
            try await materialize(receipt, original: params)
            try forget(params)
            return terminal
        }
        owners[scope] = owner
        return owner
    }

    func queryPrefetch(_ params: M2CacheBookPrefetchParams) async throws -> M2DownloadOperationQueryData {
        try await query(prefetchQuery(params))
    }

    func recoverPrefetch(_ params: M2CacheBookPrefetchParams) async throws -> M2DownloadOperationReceipt {
        let scope = Scope(sourceId: params.sourceId, bookId: params.bookId)
        guard owners[scope] == nil, recovering.insert(scope).inserted else { throw Failure.operationInFlight }
        defer { recovering.remove(scope) }
        return try await recoverPrefetchOwner(params)
    }

    func recoverSavedPrefetches() async throws -> [M2DownloadOperationReceipt] {
        var receipts: [M2DownloadOperationReceipt] = []
        for entry in try saved() {
            receipts.append(try await recoverPrefetch(entry.prefetch))
        }
        return receipts
    }

    func status(_ params: M2CacheBookStatusParams) async throws -> M2CacheBookStatusData {
        try await runtime.request(ReaderM2.cacheBookStatus, params).value
    }

    func query(_ params: M2CacheDownloadOperationQueryParams) async throws -> M2DownloadOperationQueryData {
        try await runtime.request(ReaderM2.cacheDownloadOperationQuery, params).value
    }

    func settle(_ params: M2CacheDownloadOperationSettleParams) async throws -> M2DownloadOperationReceipt {
        try await runtime.request(ReaderM2.cacheDownloadOperationSettle, params).value
    }

    func summary(_ params: M2CacheStorageParams) async throws -> M2CacheStorageData {
        try await runtime.request(ReaderM2.cacheStorageSummary, params).value
    }

    func cleanup(_ params: M2CacheStorageParams) async throws -> M2CacheStorageData {
        try await runtime.request(ReaderM2.cacheStorageCleanup, params).value
    }

    func pause(_ params: M2CacheDownloadTaskParams) async throws -> M2CacheDownloadTaskResult {
        try await control(ReaderM2.cacheDownloadPause, .pause, params)
    }

    func resume(_ params: M2CacheDownloadTaskParams) async throws -> M2CacheDownloadTaskResult {
        try await control(ReaderM2.cacheDownloadResume, .resume, params)
    }

    func cancel(_ params: M2CacheDownloadTaskParams) async throws -> M2CacheDownloadTaskResult {
        try await control(ReaderM2.cacheDownloadCancel, .cancel, params)
    }

    private func bind(_ draft: M2CacheBookPrefetchParams) async throws -> M2CacheBookPrefetchParams {
        if draft.operationId != nil, draft.sequence != nil { return draft }
        guard draft.operationId == nil, draft.sequence == nil else { throw Failure.invalidOperationIdentity }
        let latest = try await query(.init(sourceId: draft.sourceId, bookId: draft.bookId, action: .prefetch))
        let sequence = (latest.head?.sequence ?? 0) + 1
        return .init(preparationRevision: draft.preparationRevision, sourceId: draft.sourceId, bookId: draft.bookId,
                     chapterRange: draft.chapterRange, priority: draft.priority, requestedAt: draft.requestedAt,
                     contentKind: draft.contentKind,
                     operationId: "\(UUID().uuidString.lowercased())/\(sequence)", sequence: sequence)
    }

    private func prefetchQuery(_ params: M2CacheBookPrefetchParams) throws -> M2CacheDownloadOperationQueryParams {
        guard let operationId = params.operationId, let sequence = params.sequence else {
            throw Failure.invalidOperationIdentity
        }
        return .init(sourceId: params.sourceId, bookId: params.bookId, operationId: operationId,
                     expected: .prefetch(.init(params: .init(
                         preparationRevision: params.preparationRevision, sourceId: params.sourceId,
                         bookId: params.bookId, chapterRange: params.chapterRange, priority: params.priority,
                         requestedAt: params.requestedAt,
                         contentKind: params.contentKind.flatMap {
                             M2DownloadOperationExpectedPrefetchParamsContentKind(rawValue: $0.rawValue)
                         },
                         operationId: operationId, sequence: sequence
                     ))), action: .prefetch)
    }

    private func recoverPrefetchOwner(_ params: M2CacheBookPrefetchParams) async throws -> M2DownloadOperationReceipt {
        let original = try prefetchQuery(params)
        let prior = try await query(original)
        let neverAdmitted = prior.receipt == nil && (prior.head?.sequence ?? 0) < (params.sequence ?? 0)
        if prior.canResumeOriginal || neverAdmitted {
            _ = try await runtime.request(ReaderM2.cacheBookPrefetch, params)
        }
        let receipt = try await confirm(original)
        try await materialize(receipt, original: params)
        try forget(params)
        return receipt
    }

    /// A text lease moves the queue to its terminal only after the Core's
    /// cache-only projection proves the body and all offline resources.
    private func materialize(_ receipt: M2DownloadOperationReceipt,
                             original: M2CacheBookPrefetchParams) async throws {
        guard case .prefetch(let result) = receipt.data, result.sourceId == original.sourceId,
              result.bookId == original.bookId, result.chapterRange == original.chapterRange,
              let batchId = original.operationId else { throw CoreBridgeFailure.endpointMismatch }
        for lease in result.materializations {
            guard lease.manga == nil else { throw OnlineReadingCoordinator.Failure.unsupportedContent }
            let scope = ControlScope(book: .init(sourceId: result.sourceId, bookId: result.bookId),
                                     chapter: lease.chapterIndex)
            guard taskControls.insert(scope).inserted else { throw Failure.operationInFlight }
            defer { taskControls.remove(scope) }
            let savedReport = try saved().first(where: { $0.prefetch.operationId == batchId })?
                .reports.first { $0.chapterIndex == lease.chapterIndex && $0.token == lease.token }
            let input: M2CacheChapterMaterializationReportParams
            if let savedReport {
                input = savedReport
            } else {
                input = try await reportInput(lease, result: result)
                try rememberReport(input, for: batchId)
            }
            try await reportMaterialization(input)
        }
    }

    private func reportInput(_ lease: M2CacheChapterMaterializationData, result: M2CacheBookPrefetchData) async throws
        -> M2CacheChapterMaterializationReportParams {
        let scope = M2CacheDownloadOperationQueryParams(sourceId: result.sourceId, bookId: result.bookId,
                                                       action: .report, chapterIndex: lease.chapterIndex)
        let head = try await query(scope).head
        let sequence = (head?.sequence ?? 0) + 1
        let cached = try await OnlineReadingCoordinator(runtime: runtime).chapter(.init(
            cacheOnly: true, sourceId: result.sourceId, bookId: result.bookId, chapterIndex: lease.chapterIndex
        ))
        let error: String?
        if case .string(let text) = cached.content, !text.isEmpty, cached.bodyVersion != nil,
           cached.processingVersion != nil, cached.contentRefreshRequired != true,
           cached.sourceCorrectionRequired != true, let blocks = cached.blocks, !blocks.isEmpty {
            error = blocks.allSatisfy { block in
                guard case .image(let image) = block else { return true }
                let parts = image.source.split(separator: ",", maxSplits: 1)
                guard parts.count == 2, parts[0].hasPrefix("data:image/"), parts[0].hasSuffix(";base64")
                else { return false }
                return Data(base64Encoded: String(parts[1]))?.isEmpty == false
            } ? nil : "OFFLINE_IMAGE_BYTES_UNAVAILABLE"
        } else {
            error = "OFFLINE_BODY_PROJECTION_UNAVAILABLE"
        }
        return .init(sourceId: result.sourceId, bookId: result.bookId, chapterIndex: lease.chapterIndex,
                     token: lease.token, outcome: error == nil ? .completed : .failed, errorCode: error,
                     operationId: "\(UUID().uuidString.lowercased())/\(sequence)", sequence: sequence)
    }

    private func reportMaterialization(_ input: M2CacheChapterMaterializationReportParams) async throws {
        guard let id = input.operationId, let sequence = input.sequence,
              let outcome = M2DownloadOperationExpectedReportParamsOutcome(rawValue: input.outcome.rawValue)
        else { throw Failure.invalidOperationIdentity }
        let original = M2CacheDownloadOperationQueryParams(
            sourceId: input.sourceId, bookId: input.bookId, operationId: id, expected: .report(.init(params: .init(
                sourceId: input.sourceId, bookId: input.bookId, chapterIndex: input.chapterIndex,
                token: input.token, outcome: outcome, errorCode: input.errorCode, reportedAt: input.reportedAt,
                operationId: id, sequence: sequence
            ))), action: .report, chapterIndex: input.chapterIndex
        )
        if try await query(original).receipt == nil {
            _ = try await runtime.request(ReaderM2.cacheChapterMaterializationReport, input)
        }
        let receipt = try await confirm(original)
        guard case .report(let report) = receipt.data, report.sourceId == input.sourceId,
              report.bookId == input.bookId, report.chapterIndex == input.chapterIndex,
              report.state == .paused || report.state == .cancelled ||
              (report.retainedCachedBody && report.state.rawValue == input.outcome.rawValue)
        else { throw CoreBridgeFailure.endpointMismatch }
    }

    private func confirm(_ original: M2CacheDownloadOperationQueryParams) async throws -> M2DownloadOperationReceipt {
        guard let receipt = try await query(original).receipt, receipt.phase != .pending,
              let action = M2CacheDownloadOperationSettleParamsAction(rawValue: original.action.rawValue) else {
            throw Failure.originalUnresolved(original)
        }
        if receipt.phase == .settled { return receipt }
        return try await settle(.init(
            operationId: receipt.binding.operationId, sequence: receipt.binding.sequence,
            payloadFingerprint: receipt.binding.payloadFingerprint, sourceId: original.sourceId,
            bookId: original.bookId, action: action, chapterIndex: original.chapterIndex
        ))
    }

    private struct ControlScope: Hashable {
        let book: Scope
        let chapter: Int64
    }

    private func control(_ rpc: ReaderRPC<M2CacheDownloadTaskParams, M2CacheDownloadTaskResult>,
                         _ action: M2CacheDownloadOperationQueryParamsAction,
                         _ draft: M2CacheDownloadTaskParams) async throws -> M2CacheDownloadTaskResult {
        let scope = ControlScope(book: .init(sourceId: draft.sourceId, bookId: draft.bookId),
                                 chapter: draft.chapterIndex)
        guard taskControls.insert(scope).inserted else { throw Failure.operationInFlight }
        defer { taskControls.remove(scope) }
        let latest = try await query(.init(sourceId: draft.sourceId, bookId: draft.bookId, action: action,
                                           chapterIndex: draft.chapterIndex))
        guard (draft.operationId == nil) == (draft.sequence == nil) else { throw Failure.invalidOperationIdentity }
        let sequence = draft.sequence ?? ((latest.head?.sequence ?? 0) + 1)
        let id = draft.operationId ?? "\(UUID().uuidString.lowercased())/\(sequence)"
        let params = M2CacheDownloadTaskParams(sourceId: draft.sourceId, bookId: draft.bookId,
                                               chapterIndex: draft.chapterIndex, now: draft.now,
                                               operationId: id, sequence: sequence)
        let expected = try controlExpected(action, params, id: id, sequence: sequence)
        let original = M2CacheDownloadOperationQueryParams(
            sourceId: params.sourceId, bookId: params.bookId, operationId: id,
            expected: expected, action: action, chapterIndex: params.chapterIndex
        )
        let result = try await runtime.request(rpc, params).value
        _ = try await confirm(original)
        return result
    }

    private func controlExpected(_ action: M2CacheDownloadOperationQueryParamsAction, _ params: M2CacheDownloadTaskParams,
                                 id: String, sequence: Int64) throws -> M2DownloadOperationExpected {
        switch action {
        case .pause:
            .pause(.init(params: .init(sourceId: params.sourceId, bookId: params.bookId,
                                       chapterIndex: params.chapterIndex, now: params.now,
                                       operationId: id, sequence: sequence)))
        case .resume:
            .resume(.init(params: .init(sourceId: params.sourceId, bookId: params.bookId,
                                        chapterIndex: params.chapterIndex, now: params.now,
                                        operationId: id, sequence: sequence)))
        case .cancel:
            .cancel(.init(params: .init(sourceId: params.sourceId, bookId: params.bookId,
                                        chapterIndex: params.chapterIndex, now: params.now,
                                        operationId: id, sequence: sequence)))
        case .prefetch, .report: throw Failure.invalidOperationIdentity
        }
    }

    private func saved() throws -> [JournalEntry] {
        guard let journal else { return [] }
        do {
            return try JSONDecoder().decode([JournalEntry].self, from: Data(contentsOf: journal))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        }
    }

    private func remember(_ params: M2CacheBookPrefetchParams) throws {
        guard let journal else { return }
        var entries = try saved()
        guard !entries.contains(where: {
            $0.prefetch.sourceId == params.sourceId && $0.prefetch.bookId == params.bookId
        }) else { throw Failure.operationInFlight }
        entries.append(.init(prefetch: params))
        try write(entries, to: journal)
    }

    private func rememberReport(_ params: M2CacheChapterMaterializationReportParams, for batchId: String) throws {
        guard let journal else { return }
        var entries = try saved()
        guard let index = entries.firstIndex(where: { $0.prefetch.operationId == batchId }) else {
            throw Failure.invalidOperationIdentity
        }
        entries[index].reports.append(params)
        try write(entries, to: journal)
    }

    private func forget(_ params: M2CacheBookPrefetchParams) throws {
        guard let journal else { return }
        try write(saved().filter { $0.prefetch.operationId != params.operationId }, to: journal)
    }

    private func write(_ entries: [JournalEntry], to journal: URL) throws {
        try FileManager.default.createDirectory(at: journal.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(entries).write(to: journal, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
