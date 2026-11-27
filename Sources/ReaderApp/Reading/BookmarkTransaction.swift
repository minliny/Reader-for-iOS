import ReaderCoreBridge
import ReaderHost

/// Uses the Core ledger's sequence and exact argument fingerprint. The Host
/// retains only the original input until the Core receipt is settled.
struct BookmarkTransaction: Sendable {
    let runtime: CoreRuntimeActor
    let files: FileAndAssetHost

    func nextSequence() async throws -> Int64 {
        if let operation = try await files.pendingBookmark() { try await confirm(operation) }
        let ledger = try await runtime.request(ReaderM1.bookmarkOperationQuery, .init()).value
        let previous = ledger.head?.sequence ?? 0
        guard (0..<9_007_199_254_740_991).contains(previous) else { throw CoreBridgeFailure.endpointMismatch }
        return previous + 1
    }

    func execute(_ operation: BookmarkOperationExpected) async throws {
        try await files.recordBookmark(operation)
        do {
            switch operation {
            case .create(let create):
                _ = try await runtime.request(ReaderM1.bookmarkCreate, create.params)
            case .delete(let delete):
                _ = try await runtime.request(ReaderM1.bookmarkDelete, delete.params)
            }
        } catch {
            // A request error is not evidence that the original write did not commit.
            try await confirm(operation)
            return
        }
        try await confirm(operation)
    }

    func confirm(_ operation: BookmarkOperationExpected) async throws {
        let operationID = switch operation {
        case .create(let create): create.params.operationId
        case .delete(let delete): delete.params.operationId
        }
        guard let operationID else { throw CoreBridgeFailure.endpointMismatch }
        let result = try await runtime.request(ReaderM1.bookmarkOperationQuery,
            .init(operationId: operationID, expected: operation)).value
        guard let receipt = result.receipt, receipt.binding.operationId == operationID,
              confirms(receipt, operation: operation) else { throw CoreBridgeFailure.endpointMismatch }
        if receipt.phase == .committed {
            let settled = try await runtime.request(ReaderM1.bookmarkOperationSettle, receipt.binding).value
            guard settled.phase == .settled, confirms(settled, operation: operation) else {
                throw CoreBridgeFailure.endpointMismatch
            }
        }
        try await files.clearBookmark(operationID)
    }

    private func confirms(_ receipt: BookmarkOperationReceipt, operation: BookmarkOperationExpected) -> Bool {
        switch (operation, receipt.outcome) {
        case (.create(let expected), .create(let created)):
            let bookmark = created.result.bookmark
            return bookmark.positionScope?.bookId == expected.params.positionScope?.bookId &&
                bookmark.positionScope?.sourceId == expected.params.positionScope?.sourceId &&
                bookmark.chapterIndex == expected.params.chapterIndex && bookmark.chapterPos == expected.params.chapterPos
        case (.delete(let expected), .delete(let deleted)):
            return expected.params.time == deleted.result.time && deleted.result.deleted
        default: return false
        }
    }
}
