import Foundation
import ReaderCoreBridge
import ReaderHost

extension LocalImportCoordinator {
    func verifyPending() async {
        guard let pending = try? await journal.pending() else { return }
        for var entry in pending where entry.phase == .shelfDispatched || entry.phase == .shelfCommitted {
            do {
                // Match the original Core operation and retained SHA before requesting cleanup.
                // A missing shelf acknowledgement leaves the journal visible.
                guard let token = entry.rollbackToken else { continue }
                let lookup = try await runtime.request(ReaderM1.bookshelfGet,
                    .init(sourceId: "local", bookId: entry.bookId)).value
                guard lookup.book?.bookId == entry.bookId, lookup.original?.sha256 == entry.sha256 else { continue }
                _ = try await files.retained(sha256: entry.sha256)
                let result = try await runtime.request(ReaderM1.importFinalize, .init(rollbackToken: token)).value
                guard result.data.finalized, result.data.bookId == entry.bookId else { continue }
                try await files.discardJournalStage(path: entry.stagedPath)
                entry.phase = .completed
                try await journal.record(entry)
            } catch {
                continue
            }
        }
    }
}
