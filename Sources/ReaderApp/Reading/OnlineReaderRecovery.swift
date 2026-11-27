import Foundation
import Observation
import ReaderCoreBridge
import ReaderDesign

struct OnlineReadingContext {
    let session: M2AppSession
    var switchOnOpen = false
    var initialTarget: M2DirectoryTargetResolveParamsV2?
    var onBookChanged: (OnlineBookReference) -> Void = { _ in }
}

@MainActor
@Observable
final class OnlineReaderRecovery {
    struct Operation {
        let query: M2SourceSwitchTransactionQueryParams
        let from: M2SourceSwitchBookKey
        let target: M2SourceSwitchBookKey
        let generation: Int
    }

    private(set) var operation: Operation?
    private(set) var verifying = false
    private var generation = 0

    func inspect(_ book: OnlineBookReference, online: OnlineReadingCoordinator) async {
        guard operation == nil else { return }
        let expected = generation
        guard let pending = try? await online.pendingSwitches().pending, expected == generation,
              let original = pending.first(where: { matches(book, $0.from) || matches(book, $0.target) }) else { return }
        retain(.init(operationId: original.transactionId), from: original.from, target: original.target)
    }

    func retain(_ query: M2SourceSwitchTransactionQueryParams, from: M2SourceSwitchBookKey,
                target: M2SourceSwitchBookKey) {
        generation += 1
        operation = .init(query: query, from: from, target: target, generation: generation)
    }

    func verify(expected: Int, action: Int, online: OnlineReadingCoordinator) async throws -> BookshelfEntryData? {
        guard let operation, operation.generation == expected, action == expected, !verifying else { return nil }
        verifying = true
        defer { verifying = false }
        var receipt = try await exactReceipt(operation, online: online)
        if receipt.phase == .pending {
            let rollback = try await online.rollbackSwitch(.init(transactionId: operation.query.operationId))
            guard rollback.transactionId == operation.query.operationId else { throw CoreBridgeFailure.endpointMismatch }
            // The rollback intentionally retires canonical progress. Read by
            // exact operation and verify both recorded book identities again.
            receipt = try await exactReceipt(operation, online: online, afterRollback: true)
            guard receipt.phase == .rolledBack else { throw CoreBridgeFailure.endpointMismatch }
        }
        let book = receipt.phase == .finalized ? receipt.target : receipt.from
        let entry = try await online.runtime.request(ReaderM1.bookshelfGet,
            .init(sourceId: book.sourceId, bookId: book.bookId)).value.book
        guard let entry, operation.generation == generation else { throw CoreBridgeFailure.endpointMismatch }
        self.operation = nil
        return entry
    }

    private func exactReceipt(_ original: Operation, online: OnlineReadingCoordinator, afterRollback: Bool = false)
        async throws -> M2SourceSwitchTransactionReceiptData {
        let query = afterRollback ? M2SourceSwitchTransactionQueryParams(operationId: original.query.operationId,
            expected: original.query.expected) : original.query
        let result = try await online.querySwitch(query).transaction
        guard let result, result.operationId == query.operationId,
              result.from.sourceId == original.from.sourceId, result.from.bookId == original.from.bookId,
              result.target.sourceId == original.target.sourceId, result.target.bookId == original.target.bookId else {
            throw CoreBridgeFailure.endpointMismatch
        }
        return result
    }

    private func matches(_ book: OnlineBookReference, _ key: M2SourceSwitchBookKey) -> Bool {
        book.sourceId == key.sourceId && book.bookId == key.bookId
    }
}

extension OnlineReadingCoordinator {
    func switchDraft(book: OnlineBookReference, chapter: ReadingChapter,
                     candidate: SourceSwitchCandidate) async throws -> M2SourceSwitchCommitParams {
        let target = try await detail(candidate.book.detailParams)
        let directory = try await refreshDirectory(.init(sourceId: target.sourceId, bookId: target.book.bookId,
                                                         tocUrl: target.tocUrl, variables: target.variables))
        return .init(from: .init(sourceId: book.sourceId, bookId: book.bookId),
            target: .init(sourceId: target.sourceId, bookId: target.book.bookId, title: target.book.title,
                          author: target.book.author, coverUrl: target.book.coverUrl, intro: target.book.intro,
                          kind: target.book.kind, lastChapter: target.book.lastChapter),
            newToc: directory.chapters.map { .init(chapterId: $0.url, chapterTitle: $0.title,
                                                   chapterUrl: $0.url, order: $0.index) },
            currentChapterTitle: chapter.title, currentChapterIndex: chapter.index,
            updatedAt: Int64(Date().timeIntervalSince1970 * 1_000))
    }
}
