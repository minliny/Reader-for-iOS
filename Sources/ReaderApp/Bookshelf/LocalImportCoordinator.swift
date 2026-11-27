import Foundation
import ReaderCoreBridge
import ReaderHost

/// Orders the original Core transactions and asks Host to durably stage bytes
/// and mark the physical operation journal.
struct LocalImportCoordinator: Sendable {
    struct Receipt: Sendable {
        let bookId: String
        let source: RetainedSource
        let shelf: BookshelfAddData
        let cleanupDeferred: Bool
    }

    let runtime: CoreRuntimeActor
    let files: FileAndAssetHost
    let journal: ImportJournal

    func importSelectedFile(_ url: URL) async throws -> Receipt {
        let staged = try await files.stageSelectedFile(url)
        let bookId = "local:\(staged.sha256)"
        let parsed: ImportLocalBookParseData
        do {
            parsed = try await runtime.request(ReaderM1.importParse, ImportLocalBookParseParams(
                input: LocalBookParseParams(bookId: bookId, fileName: staged.name, filePath: staged.path.path)
            )).value
            // The preview digest identifies the parsed transaction payload;
            // the Core book variable identifies the original file bytes.
            guard parsed.preview.summary.book.variables?["localBookSourceSha256"] == staged.sha256,
                  let readability = parsed.preview.summary.integrity?.readability,
                  readability == .complete || readability == .recoverable else {
                throw FileAndAssetFailure.corruptSource
            }
        } catch {
            try? await files.discard(staged)
            throw error
        }

        // The owner is independent of the picker or page's observation task.
        return try await Task.detached {
            try await commit(bookId: bookId, staged: staged, parsed: parsed)
        }.value
    }

    private func commit(bookId: String, staged: StagedSource, parsed: ImportLocalBookParseData) async throws -> Receipt {
        var entry = ImportJournal.Entry(transactionId: UUID().uuidString, bookId: bookId, staged: staged)
        do {
            try await journal.record(entry)
        } catch {
            try? await files.discard(staged)
            throw error
        }

        let persisted = try await runtime.request(
            ReaderM1.importPersist,
            ImportLocalBookPersistParams(transactionId: entry.transactionId, parsed: parsed)
        ).value
        entry.rollbackToken = persisted.rollbackToken
        entry.phase = .persisted
        try await journal.record(entry)

        let retained: RetainedSource
        do {
            retained = try await files.retain(staged)
        } catch {
            await compensate(entry, staged: staged)
            throw error
        }

        let book = persisted.persisted.data.book
        entry.phase = .shelfDispatched
        try await journal.record(entry)
        let shelf: BookshelfAddData
        do {
            shelf = try await runtime.request(ReaderM1.bookshelfAdd, BookshelfAddParams(
                sourceId: "local", bookId: book.bookId, title: book.title, author: book.author,
                coverUrl: book.coverUrl, intro: book.intro, kind: book.kind, lastChapter: book.lastChapter,
                requireReadable: true
            )).value
        } catch let rejection as CoreRequestFailure where rejection.value.code == .invalidParams {
            await compensate(entry, staged: staged)
            throw rejection
        }
        do {
            entry.phase = .shelfCommitted
            try await journal.record(entry)
            let finalized = try await runtime.request(
                ReaderM1.importFinalize, ImportLocalBookFinalizeParams(rollbackToken: persisted.rollbackToken)
            ).value
            guard finalized.data.finalized, finalized.data.bookId == bookId else {
                return Receipt(bookId: bookId, source: retained, shelf: shelf, cleanupDeferred: true)
            }
            try await files.discard(staged)
            entry.phase = .completed
            try await journal.record(entry)
            return Receipt(bookId: bookId, source: retained, shelf: shelf, cleanupDeferred: false)
        } catch {
            // Core has already acknowledged adding the book. Preserve the
            // original token and do not compensate a confirmed shelf write.
            return Receipt(bookId: bookId, source: retained, shelf: shelf, cleanupDeferred: true)
        }
    }

    private func compensate(_ entry: ImportJournal.Entry, staged: StagedSource) async {
        guard let token = entry.rollbackToken else { return }
        guard let result = try? await runtime.request(
            ReaderM1.importRollback, ImportLocalBookRollbackParams(rollbackToken: token)
        ).value, result.data.bookId == entry.bookId else { return }
        try? await files.discard(staged)
        var rolledBack = entry
        rolledBack.phase = .rolledBack
        try? await journal.record(rolledBack)
    }
}
