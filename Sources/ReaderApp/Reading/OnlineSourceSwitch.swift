import Foundation
import ReaderCoreBridge

extension OnlineReadingCoordinator {
    func switchCandidates(_ params: M2ChangeBookSourceParams) async throws -> M2ChangeBookSourceData {
        try await runtime.request(ReaderM2.changeBookSource, params).value
    }

    func bindSwitch(_ draft: M2SourceSwitchCommitParams) async throws -> M2SourceSwitchCommitParams {
        if draft.operationId != nil, draft.sequence != nil { return draft }
        guard draft.operationId == nil, draft.sequence == nil else { throw CoreBridgeFailure.endpointMismatch }
        let head = try await querySwitch(.init(operationId: "\(UUID().uuidString.lowercased())/1")).head
        let next = (head?.sequence ?? 0) + 1
        return .init(operationId: "\(UUID().uuidString.lowercased())/\(next)", sequence: next,
                     from: draft.from, target: draft.target, newToc: draft.newToc,
                     currentChapterTitle: draft.currentChapterTitle, currentChapterIndex: draft.currentChapterIndex,
                     updatedAt: draft.updatedAt)
    }

    func switchSource(_ draft: M2SourceSwitchCommitParams) async throws -> M2SourceSwitchCommitData {
        let params = try await bindSwitch(draft)
        guard let id = params.operationId else { throw CoreBridgeFailure.endpointMismatch }
        let result: M2SourceSwitchCommitData
        let query = M2SourceSwitchTransactionQueryParams(operationId: id, expected: params)
        do {
            result = try await runtime.request(ReaderM2.sourceSwitchCommit, params).value
        } catch {
            guard let observed = try? await querySwitch(query), let original = observed.transaction?.commit else {
                throw Failure.switchUnresolved(query)
            }
            result = original
        }
        guard result.transactionId == id, result.book.bookId == params.target.bookId,
              result.book.sourceId == params.target.sourceId else { throw CoreBridgeFailure.endpointMismatch }
        return result
    }

    func querySwitch(_ params: M2SourceSwitchTransactionQueryParams) async throws -> M2SourceSwitchTransactionQueryData {
        try await runtime.request(ReaderM2.sourceSwitchTransactionQuery, params).value
    }

    func pendingSwitches() async throws -> M2SourceSwitchPendingListData {
        try await runtime.request(ReaderM2.sourceSwitchPendingList, .init()).value
    }

    func finalizeSwitch(_ params: M2SourceSwitchTransactionParams) async throws -> M2SourceSwitchFinalizeData {
        try await runtime.request(ReaderM2.sourceSwitchFinalize, params).value
    }

    func rollbackSwitch(_ params: M2SourceSwitchTransactionParams) async throws -> M2SourceSwitchRollbackData {
        try await runtime.request(ReaderM2.sourceSwitchRollback, params).value
    }

    func recoverSwitches() async throws -> M2SourceSwitchRecoverData {
        try await runtime.request(ReaderM2.sourceSwitchRecover, .init()).value
    }

    /// Body and position were verified against the target. This write and
    /// finalization share the Core transaction boundary.
    func confirmSwitchPosition(
        original: M2SourceSwitchCommitParams, target: LocalBookChapterContentData,
        position: Int, revision: String
    ) async throws -> String {
        guard let id = original.operationId, let body = target.bodyVersion,
              let processing = target.processingVersion else { throw ReadingProjectionFailure.positionNotProven }
        let ratio = Double(position) / Double(max(1, target.content.unicodeScalars.count))
        let params = TextReadingProgressUpdateParams(
            expectedProgressRevision: revision, bookId: target.bookId, sourceId: target.sourceId,
            updatedAt: original.updatedAt, chapterIndex: target.chapterIndex,
            chapterOffset: Int64(position), chapterProgress: ratio, chapterTitle: target.chapterTitle,
            transactionId: id, expectedBodyVersion: body, expectedProcessingVersion: processing
        )
        let exact = M2SourceSwitchTransactionQueryParams(
            operationId: id, expected: original, expectedCanonical: .text(.init(
                expectedProgressRevision: revision, bookId: target.bookId, sourceId: target.sourceId,
                updatedAt: original.updatedAt, chapterIndex: target.chapterIndex,
                chapterOffset: Int64(position), chapterProgress: ratio, chapterTitle: target.chapterTitle,
                transactionId: id, expectedBodyVersion: body, expectedProcessingVersion: processing
            ))
        )
        do {
            let terminal = try await runtime.request(ReaderM1.readingProgressUpdate, params).value
            guard terminal.transactionId == id, terminal.stored, terminal.sourceSwitchFinalized == true,
                  terminal.chapterIndex == target.chapterIndex, terminal.chapterOffset == Int64(position),
                  let finalRevision = terminal.progressRevision else { throw CoreBridgeFailure.endpointMismatch }
            return finalRevision
        } catch {
            guard let current = try? await querySwitch(exact), let originalTerminal = current.transaction?.canonicalProgress,
                  originalTerminal.transactionId == id, originalTerminal.sourceSwitchFinalized == true,
                  originalTerminal.chapterIndex == target.chapterIndex,
                  originalTerminal.chapterOffset == Int64(position),
                  let finalRevision = originalTerminal.progressRevision else { throw Failure.switchUnresolved(exact) }
            return finalRevision
        }
    }
}
