import Foundation
import CryptoKit
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif

/// The pinned Core owns all parsing, shelf rows and reading positions. This actor
/// owns one runtime and serializes FFI send/cancel/destroy. Polling suspends the
/// actor instead of blocking MainActor or a cooperative executor in request().
public actor ReaderLibraryService: ReaderLibraryServing {
    public static let coreBaseline = "b6a5bb9294279acda508b1492f1ed3592907d427"
    let client: any ReaderCoreEventClient
    let hostTransport: ReaderIOSHostTransport?
    private let timing: ReaderRequestTiming
    private let importStagingObserver: ReaderImportStagingObserver
    private let importSourceDirectorySync: @Sendable (URL) throws -> Void
    private var liveImportResources: [String: ReaderImportStagingOwner] = [:]
    let sourceURL: URL
    private let stagingURL: URL
    let operationsURL: URL
    private var requestID: UInt64 = 100
    var activeRequests: Set<UInt64> = []
    var unresolvedWrites: [UInt64: PendingMutation] = [:]
    private var pendingHostPumps: [UInt64: Task<Void, Never>] = [:]
    private var isClosed = false
    var importInFlight = false
    var assetMutationInFlight = false
    var sourceSwitchInFlight = false
    var readingCacheWindowInFlight: Set<String> = []
    var recovering = false

    public init(storageURL: URL, sourceURL: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: storageURL, withIntermediateDirectories: true)
        try manager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        self.sourceURL = sourceURL
        self.stagingURL = sourceURL.appendingPathComponent(".staging", isDirectory: true)
        self.operationsURL = sourceURL.appendingPathComponent(".operations", isDirectory: true)
        try manager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        try manager.createDirectory(at: operationsURL, withIntermediateDirectories: true)
        let config = try JSONSerialization.data(withJSONObject: ["dataDirectory": storageURL.path])
        let transport = ReaderIOSHostTransport(namespace: try ReaderHostLibraryIdentity.loadOrCreate(in: operationsURL))
        let native = try ReaderCoreClient(configJSON: config, hostTransport: transport)
        transport.configure(native)
        self.client = native
        self.hostTransport = transport
        self.timing = .live
        self.importStagingObserver = { _, _ in }
        self.importSourceDirectorySync = { try ReaderImportStagingLease.synchronizeDirectory($0) }
    }

    init(storageURL: URL, sourceURL: URL, client: any ReaderCoreEventClient, timing: ReaderRequestTiming,
         importStagingObserver: @escaping ReaderImportStagingObserver = { _, _ in },
         importSourceDirectorySync: @escaping @Sendable (URL) throws -> Void = { try ReaderImportStagingLease.synchronizeDirectory($0) }) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: storageURL, withIntermediateDirectories: true)
        try manager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        self.sourceURL = sourceURL
        self.stagingURL = sourceURL.appendingPathComponent(".staging", isDirectory: true)
        self.operationsURL = sourceURL.appendingPathComponent(".operations", isDirectory: true)
        try manager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        try manager.createDirectory(at: operationsURL, withIntermediateDirectories: true)
        self.client = client
        self.hostTransport = nil
        self.timing = timing
        self.importStagingObserver = importStagingObserver
        self.importSourceDirectorySync = importSourceDirectorySync
    }

    public func listBooks() async throws -> [ReaderBook] {
        struct Page: Decodable { let books: [ReaderBook]; let total: Int }
        var books: [ReaderBook] = []
        repeat {
            let data = try await request("bookshelf.list", [
                "contentKind": "text", "sortBy": "lastReadAt",
                "sortDirection": "descending", "offset": books.count, "limit": 128
            ])
            let page = try decode(Page.self, data)
            books.append(contentsOf: page.books)
            if page.books.isEmpty || books.count >= page.total { return books }
        } while true
    }

    public func chapters(for book: ReaderBook) async throws -> [ReaderChapter] {
        if book.sourceId != "local" { return try await onlineChapters(for: book) }
        struct Toc: Decodable { let toc: [ReaderChapter] }
        return try decode(Toc.self, await request("local_book.toc", ["bookId": book.bookId])).toc
    }

    public func content(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderChapterContent {
        if book.sourceId != "local" { return try await onlineContent(for: book, chapterIndex: chapterIndex) }
        return try decode(ReaderChapterContent.self, await request("local_book.chapter.content", [
            "bookId": book.bookId, "chapterIndex": chapterIndex
        ]))
    }

    public func progress(for book: ReaderBook) async throws -> ReaderProgressSnapshot {
        return try decode(ReaderProgressSnapshot.self, await request("reading.progress.get", [
            "sourceId": book.sourceId, "bookId": book.bookId
        ]))
    }

    public func saveProgress(for book: ReaderBook, content: ReaderChapterContent, scalarOffset: UInt64,
                             expectedRevision: String?) async throws -> ReaderProgressSnapshot {
        guard content.sourceId == book.sourceId, content.bookId == book.bookId,
              scalarOffset <= content.scalarCount,
              let bodyVersion = content.bodyVersion, let processingVersion = content.processingVersion else {
            throw ReaderLibraryError.invalidPosition
        }
        var params: [String: Any] = [
            "sourceId": book.sourceId, "bookId": book.bookId,
            "chapterIndex": content.chapterIndex, "chapterOffset": scalarOffset,
            "chapterProgress": content.scalarCount == 0 ? 0 : Double(scalarOffset) / Double(content.scalarCount),
            "expectedBodyVersion": bodyVersion, "expectedProcessingVersion": processingVersion
        ]
        // First reads return an observation revision even when no progress row exists.
        // Require that observation so delayed old sessions cannot overwrite a new one.
        guard let expectedRevision, !expectedRevision.isEmpty else { throw ReaderLibraryError.invalidPosition }
        params["expectedProgressRevision"] = expectedRevision
        let data = try await request("reading.progress.update", params, mutation: true,
                                     owner: .progress(sourceId: book.sourceId, bookId: book.bookId))
        let receipt = try progressReceipt(data, for: book)
        finishMutation(.progress(sourceId: book.sourceId, bookId: book.bookId))
        return receipt
    }

    /// Returns only the terminal receipt of the original timed-out update.
    /// A fresh progress.get is never used to acknowledge that mutation.
    public func reconcilePendingProgress(for book: ReaderBook) async throws -> ReaderProgressSnapshot? {
        guard !isClosed else { throw ReaderLibraryError.closed }
        let owner = PendingMutationOwner.progress(sourceId: book.sourceId, bookId: book.bookId)
        try drainUnresolvedReplies(owner: owner)
        guard let (id, pending) = unresolvedWrites.first(where: { $0.value.owner == owner }) else { return nil }
        guard let terminal = pending.terminal else { throw ReaderLibraryError.operationPending(pending.method) }
        let data: Data
        do { data = try responseData(terminal, method: pending.method, requestID: id) }
        catch {
            // The original terminal rejection is delivered to its owner, once.
            if Self.isDefiniteMutationRejection(error) { unresolvedWrites.removeValue(forKey: id) }
            throw error
        }
        let receipt = try progressReceipt(data, for: book)
        unresolvedWrites.removeValue(forKey: id)
        return receipt
    }

    public func flush() async throws {
        try drainUnresolvedReplies(owner: .flush)
        if let (id, pending) = unresolvedWrites.first(where: { $0.value.owner == .flush }) {
            guard let terminal = pending.terminal else { throw ReaderLibraryError.operationPending(pending.method) }
            do {
                _ = try responseData(terminal, method: pending.method, requestID: id)
                unresolvedWrites.removeValue(forKey: id)
            } catch {
                unresolvedWrites.removeValue(forKey: id)
                throw error
            }
        }
        _ = try await request("runtime.storage.flush", [:], mutation: true, owner: .flush)
        finishMutation(.flush)
    }

    public func close() async throws {
        if isClosed { return }
        try drainUnresolvedReplies(importsOnly: true)
        // Do not destroy the runtime underneath an in-flight durable import/write.
        guard activeRequests.isEmpty, unresolvedWrites.values.allSatisfy({ $0.owner == .flush }),
              !importInFlight, !recovering, !assetMutationInFlight else { throw ReaderLibraryError.busy }
        try await flush()
        guard activeRequests.isEmpty, unresolvedWrites.isEmpty, !importInFlight, !recovering, !assetMutationInFlight else { throw ReaderLibraryError.busy }
        isClosed = true
        client.destroy()
    }

    public func importBook(at url: URL) async throws -> ReaderImportResult {
        guard !isClosed else { throw ReaderLibraryError.closed }
        guard !importInFlight, !recovering, !assetMutationInFlight else { throw ReaderLibraryError.busy }
        guard try !hasPendingAssetRemoval() else { throw ReaderLibraryError.operationPending("source cleanup") }
        guard ["txt", "epub", "mobi", "azw", "azw3", "kf8"].contains(url.pathExtension.lowercased()) else { throw ReaderLibraryError.unsupportedFile }
        try Task.checkCancellation()
        let stagingLease = try ReaderImportStagingLease(stagingURL: stagingURL, observe: importStagingObserver)
        defer { stagingLease.release() }
        importInFlight = true
        defer { importInFlight = false }
        let selection = UUID().uuidString.lowercased()
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let copyCancellation = ReaderImportCopyCancellation()
        let stagingOwner = try await withTaskCancellationHandler(operation: {
            try stagingLease.copy(url, selection: selection, cancellation: copyCancellation)
        }, onCancel: { copyCancellation.cancel() })
        let staged = stagingLease.payloadURL(stagingOwner)
        defer {
            // A malformed or unreadable business journal makes cleanup unsafe.
            // Existing original mutations, including unknown outcomes, win.
            if let protections = try? stagingProtections() {
                try? stagingLease.retirePrecommit(stagingOwner, protections: protections)
            }
        }
        var record: HostImportRecord?
        var persistSendAttempted = false
        var shelfDispatched = false
        var shelfAcknowledged = false
        do {
            guard let hash = stagingOwner.sha256 else { throw ReaderLibraryError.invalidResponse("unsealed import source") }
            let bookID = "local:" + hash
            if let original = try records().first(where: { $0.hash == hash && $0.phase != .finalize }) {
                throw ReaderLibraryError.operationPending(original.id)
            }
            if let existing = try await shelfBook(bookID) {
                _ = try commitSource(staged, hash: hash)
                return ReaderImportResult(book: existing, created: false)
            }
            let input: [String: Any] = [
                "bookId": bookID, "fileName": url.lastPathComponent,
                "filePath": staged.path, "title": url.deletingPathExtension().lastPathComponent
            ]
            let parsed = try await request("import.parse", ["kind": "localBook", "input": input], timeout: 120)
            let parsedObject = try object(parsed)
            guard let preview = parsedObject["preview"] as? [String: Any],
                  let summary = preview["summary"] as? [String: Any],
                  let integrity = summary["integrity"] as? [String: Any],
                  (integrity["schemaVersion"] as? Int) == 1,
                  ["complete", "recoverable"].contains(integrity["readability"] as? String ?? "") else {
                throw ReaderLibraryError.invalidResponse("unreadable local import")
            }
            try stagingLease.parsed(stagingOwner)
            try Task.checkCancellation()
            let transactionID = "ios-import-" + selection
            record = HostImportRecord(id: transactionID, fileName: url.lastPathComponent,
                                      stagedName: staged.lastPathComponent, hash: hash,
                                      phase: .persistAwaiting, rollbackToken: nil, shelfParameters: nil)
            try writeRecord(record!)
            liveImportResources[transactionID] = stagingOwner
            liveImportResources[transactionID] = try stagingLease.handoff(stagingOwner)
            let persisted = try await request("import.persist", [
                "transactionId": transactionID, "parsed": parsedObject
            ], mutation: true, timeout: 120, owner: .importOperation(id: transactionID, stage: .persist),
               onSendAttempt: { persistSendAttempted = true })
            var persistedRecord = record!
            let local = try applyPersistedReceipt(persisted, record: &persistedRecord)
            record = persistedRecord
            finishMutation(.importOperation(id: transactionID, stage: .persist))
            let token = try object(persistedRecord.rollbackToken!)
            let shelf = try object(persistedRecord.shelfParameters!)
            _ = try commitSource(staged, hash: hash) { created in
                try registerSourceCreation(created, owner: stagingOwner, using: stagingLease)
            }
            record?.phase = .shelfAwaiting
            try writeRecord(record!)
            shelfDispatched = true
            let addedData = try await request("bookshelf.add", shelf, mutation: true,
                                              owner: .importOperation(id: transactionID, stage: .shelf))
            struct Add: Decodable { let created: Bool }
            let added = try decode(Add.self, addedData)
            shelfAcknowledged = true
            record?.phase = .finalize
            // Once the shelf ACK arrives, cleanup failure cannot undo a readable import.
            var pending = true
            do {
                try writeRecord(record!)
                finishMutation(.importOperation(id: transactionID, stage: .shelf))
                let finalized = try await request("import.finalize", ["rollbackToken": token], mutation: true,
                                      owner: .importOperation(id: transactionID, stage: .finalize))
                try validateImportTerminal(finalized, record: record!, stage: .finalize)
                try retireImportResources(record!, authority: .finalized, using: stagingLease)
                try removeRecord(transactionID)
                liveImportResources.removeValue(forKey: transactionID)
                finishMutation(.importOperation(id: transactionID, stage: .finalize))
                pending = false
            } catch { /* Keep the opaque receipt for explicit startup recovery. */ }
            let fallback = ReaderBook(bookId: bookID, title: shelf["title"] as? String ?? "",
                                      author: shelf["author"] as? String ?? "",
                                      chapterCount: (local["chapterCount"] as? NSNumber)?.uint32Value ?? 0)
            let book = (try? await shelfBook(bookID)) ?? fallback
            return ReaderImportResult(book: book, created: added.created, finalizationPending: pending)
        } catch {
            if shelfAcknowledged { throw ReaderLibraryError.operationPending(record?.id ?? selection) }
            if let record, hasPendingImport(record.id) { throw ReaderLibraryError.operationPending(record.id) }
            let unknown = isUnknownOutcome(error)
            if let current = record, !persistSendAttempted {
                // This same invocation has not entered client.send for persist.
                // Local record/handoff I/O failure is not an unknown Core write.
                liveImportResources[current.id] = liveImportResources[current.id] ?? stagingOwner
                try retireImportResources(current, authority: .notDispatched, using: stagingLease)
                do { try removeRecord(current.id) }
                catch let failure as CocoaError where failure.code == .fileNoSuchFile {}
                liveImportResources.removeValue(forKey: current.id)
                throw error
            }
            if let current = record {
                if current.rollbackToken == nil && !Self.isDefiniteMutationRejection(error) {
                    throw ReaderLibraryError.operationPending(current.id)
                }
                if shelfDispatched && unknown { throw ReaderLibraryError.operationPending(current.id) }
                if let tokenData = current.rollbackToken {
                    do {
                        var rollbackRecord = current
                        rollbackRecord.phase = .rollback
                        rollbackRecord.rejection = StoredImportRejection(error)
                        rollbackRecord.originalFailure = String(describing: error)
                        try writeRecord(rollbackRecord)
                        let rolledBack = try await request("import.rollback", ["rollbackToken": try object(tokenData)], mutation: true,
                                              owner: .importOperation(id: current.id, stage: .rollback))
                        try validateImportTerminal(rolledBack, record: rollbackRecord, stage: .rollback)
                        try retireImportResources(rollbackRecord, authority: .rolledBack, using: stagingLease)
                    } catch { throw ReaderLibraryError.operationPending(current.id) }
                } else {
                    // Only this actual persist rejection permits cleanup. An
                    // owner-file absence is not loss of the live inode proof.
                    try retireImportResources(current, authority: .persistRejected, using: stagingLease)
                }
                try removeRecord(current.id)
                liveImportResources.removeValue(forKey: current.id)
                finishMutation(.importOperation(id: current.id, stage: .rollback))
            }
            // The private owner defer retires only a proved precommit inode.
            throw error
        }
    }

    /// Host records contain only opaque Core receipts and file-operation intent.
    /// They are not a second shelf/progress database. Unknown persist outcomes
    /// remain visible until Core offers an exact receipt query for that operation.
    public func pendingImports() async throws -> [ReaderPendingImport] {
        guard !isClosed else { throw ReaderLibraryError.closed }
        return try records().map { ReaderPendingImport(id: $0.reprocessOperationID ?? $0.id, fileName: $0.fileName,
                                               requiresReconciliation: $0.phase != .finalize) }
    }

    /// Reuses the original raw source and Core's atomic position migration.
    /// Rule saving is a separate operation; duplicate-import fast paths and
    /// bookshelf.add are deliberately absent from this explicit operation.
    public func reprocessLocalBook(_ book: ReaderBook, operationID: String) async throws -> ReaderImportResult {
        guard !isClosed else { throw ReaderLibraryError.closed }
        guard book.sourceId == "local", !operationID.isEmpty else { throw ReaderLibraryError.unsupportedFile }
        guard !importInFlight, !recovering, !assetMutationInFlight else { throw ReaderLibraryError.busy }
        guard try !hasPendingAssetRemoval() else { throw ReaderLibraryError.operationPending("source cleanup") }
        let stagingLease = try ReaderImportStagingLease(stagingURL: stagingURL)
        defer { stagingLease.release() }
        importInFlight = true
        defer { importInFlight = false }
        let transactionID = "ios-reprocess-" + SHA256.hash(data: Data(operationID.utf8)).map { String(format: "%02x", $0) }.joined()
        try drainUnresolvedReplies(importsOnly: true, resourceLease: stagingLease)
        var record: HostImportRecord
        if let original = try records(includeCompleted: true).first(where: { $0.id == transactionID }) {
            guard original.reprocessOperationID == operationID, "local:" + original.hash == book.bookId else {
                throw ReaderLibraryError.invalidResponse("reprocess operation identity")
            }
            record = original
        } else {
            guard try !records().contains(where: { "local:" + $0.hash == book.bookId }) else {
                throw ReaderLibraryError.operationPending(operationID)
            }
            let source = try retainedSourceURL(for: book)
            guard let current = try await shelfBook(book.bookId) else { throw ReaderLibraryError.invalidResponse("reprocess shelf identity") }
            // Raw-byte detection stays Core-owned. A .source sandbox suffix is
            // not converted into a fabricated file format or original name.
            let input: [String: Any] = ["bookId": book.bookId, "filePath": source.path,
                "title": current.title, "author": current.author]
            record = HostImportRecord(id: transactionID, fileName: current.title, stagedName: source.lastPathComponent,
                hash: String(book.bookId.dropFirst("local:".count)), phase: .preparing, rollbackToken: nil, shelfParameters: nil)
            record.reprocessOperationID = operationID
            record.reprocessInput = try JSONSerialization.data(withJSONObject: input, options: [.sortedKeys])
            try writeRecord(record)
        }
        if record.phase == .completed {
            guard let result = record.reprocessResult else { throw ReaderLibraryError.invalidResponse("completed reprocess receipt") }
            return result
        }
        if record.phase == .rejected { throw reprocessRejection(record) }
        guard !hasPendingImport(record.id) else { throw ReaderLibraryError.operationPending(operationID) }
        if record.phase == .preparing {
            do {
                guard let frozen = record.reprocessInput else { throw ReaderLibraryError.invalidResponse("reprocess input") }
                var input = try object(frozen)
                let authorized = try retainedSourceURL(for: book)
                guard input["bookId"] as? String == book.bookId else { throw ReaderLibraryError.invalidResponse("reprocess input identity") }
                // A pure preparing intent may survive a data-container move.
                // Reauthorize only the same SHA source; no dispatched mutation
                // payload is ever rewritten or replayed during this rebinding.
                input["filePath"] = authorized.path
                record.reprocessInput = try JSONSerialization.data(withJSONObject: input, options: [.sortedKeys])
                try writeRecord(record)
                let parsed = try object(await request("import.parse", ["kind": "localBook", "input": input], timeout: 120))
                guard let preview = parsed["preview"] as? [String: Any], let summary = preview["summary"] as? [String: Any],
                      let integrity = summary["integrity"] as? [String: Any],
                      (integrity["schemaVersion"] as? NSNumber)?.intValue == 1,
                      ["complete", "recoverable"].contains(integrity["readability"] as? String ?? "") else {
                    throw ReaderLibraryError.invalidResponse("unreadable reprocess preview")
                }
                try Task.checkCancellation()
                record.phase = .persistAwaiting
                try writeRecord(record)
                let persisted = try await request("import.persist", ["transactionId": record.id, "parsed": parsed],
                    mutation: true, timeout: 120, owner: .importOperation(id: record.id, stage: .persist))
                _ = try applyPersistedReceipt(persisted, record: &record)
                finishMutation(.importOperation(id: record.id, stage: .persist))
            } catch {
                if record.phase == .preparing || (Self.isDefiniteMutationRejection(error) && !hasPendingImport(record.id)) {
                    record.phase = .rejected
                    record.rejection = StoredImportRejection(error)
                    record.originalFailure = error.localizedDescription
                    try writeRecord(record)
                    throw error
                }
                throw ReaderLibraryError.operationPending(operationID)
            }
        }
        guard record.phase == .finalize else { throw ReaderLibraryError.operationPending(operationID) }
        return try await finishLocalReprocess(record)
    }

    func pendingLocalReprocessOperations() throws -> [ReaderPendingCoreCommand] {
        try records().compactMap { record in
            guard let id = record.reprocessOperationID else { return nil }
            return ReaderPendingCoreCommand(id: id, method: "local_book.reprocess", scope: "local-reprocess:local:" + record.hash,
                acknowledged: record.rollbackToken != nil)
        }
    }

    func resumeLocalReprocessOperation(_ operationID: String) async throws -> ReaderFeatureRecoveryResult? {
        guard let original = try records(includeCompleted: true).first(where: { $0.reprocessOperationID == operationID }) else { return nil }
        let book = ReaderBook(bookId: "local:" + original.hash, title: original.fileName)
        do {
            _ = try await reprocessLocalBook(book, operationID: operationID)
            return .init(operationID: operationID, status: .completed)
        } catch {
            let current = try records(includeCompleted: true).first(where: { $0.id == original.id })
            if current?.phase == .rejected {
                return .init(operationID: operationID, status: .rejected, message: error.localizedDescription)
            }
            return .init(operationID: operationID, status: .pending, message: error.localizedDescription)
        }
    }

    private func finishLocalReprocess(_ original: HostImportRecord) async throws -> ReaderImportResult {
        var record = original
        guard let id = record.reprocessOperationID, record.phase == .finalize,
              !hasPendingImport(record.id), let token = record.rollbackToken else {
            throw ReaderLibraryError.operationPending(record.reprocessOperationID ?? record.id)
        }
        // A sent finalization with no retained terminal cannot be replayed
        // after process death: Core 2a has no exact finalization receipt query.
        guard record.reprocessFinalizationDispatched != true else { throw ReaderLibraryError.operationPending(id) }
        if record.reprocessResult == nil {
            guard let book = try await shelfBook("local:" + record.hash) else { throw ReaderLibraryError.operationPending(id) }
            record.reprocessResult = ReaderImportResult(book: book, created: false)
        }
        record.reprocessFinalizationDispatched = true
        try writeRecord(record)
        do {
            let receipt = try await request("import.finalize", ["rollbackToken": try object(token)], mutation: true,
                owner: .importOperation(id: record.id, stage: .finalize))
            try validateImportTerminal(receipt, record: record, stage: .finalize)
            record.phase = .completed
            try writeRecord(record)
            finishMutation(.importOperation(id: record.id, stage: .finalize))
            return record.reprocessResult!
        } catch { throw ReaderLibraryError.operationPending(id) }
    }

    private func reprocessRejection(_ record: HostImportRecord) -> Error {
        if let rejection = record.rejection { return rejection.error }
        return ReaderLibraryError.invalidResponse(record.originalFailure ?? "reprocess was rejected before dispatch")
    }

    public func recoverPendingImports() async throws -> [ReaderPendingImport] {
        guard !isClosed else { throw ReaderLibraryError.closed }
        guard !importInFlight, !recovering, !assetMutationInFlight else { throw ReaderLibraryError.busy }
        let stagingLease = try ReaderImportStagingLease(stagingURL: stagingURL)
        defer { stagingLease.release() }
        recovering = true
        defer { recovering = false }
        // Read every original journal before resource recovery. An unknown or
        // malformed old journal is never interpreted as an absent Core owner.
        try stagingLease.recoverPrecommit(protections: stagingProtections())
        try drainUnresolvedReplies(importsOnly: true, resourceLease: stagingLease)
        var completedRejection: Error?
        for var record in try records() {
            // A live original request owns this phase until its terminal reply
            // is applied. Never race it with a replacement mutation.
            guard !hasPendingImport(record.id) else { continue }
            if record.reprocessOperationID != nil {
                // Explicit reprocessing never republishes a shelf row. Pure
                // preparing intents wait for their original explicit owner.
                if record.phase == .finalize { _ = try? await finishLocalReprocess(record) }
                continue
            }
            guard let tokenData = record.rollbackToken else { continue }
            let token = try object(tokenData)
            do {
                if record.phase == .rollback {
                    let rolledBack = try await request("import.rollback", ["rollbackToken": token], mutation: true,
                                          owner: .importOperation(id: record.id, stage: .rollback))
                    try validateImportTerminal(rolledBack, record: record, stage: .rollback)
                    try retireImportResources(record, authority: .rolledBack, using: stagingLease)
                    try removeRecord(record.id)
                    liveImportResources.removeValue(forKey: record.id)
                    finishMutation(.importOperation(id: record.id, stage: .rollback))
                    if completedRejection == nil {
                        completedRejection = rollbackCompletion(record)
                    }
                    continue
                }
                if record.phase != .finalize {
                    guard let shelf = record.shelfParameters else { continue }
                    let ownership = try importResourceProof(for: record, using: stagingLease)
                    _ = try commitSource(stagingURL.appendingPathComponent(record.stagedName), hash: record.hash) { created in
                        if let ownership { try registerSourceCreation(created, owner: ownership, using: stagingLease) }
                    }
                    record.phase = .shelfAwaiting
                    try writeRecord(record)
                    _ = try await request("bookshelf.add", try object(shelf), mutation: true,
                                          owner: .importOperation(id: record.id, stage: .shelf))
                    record.phase = .finalize
                    try writeRecord(record)
                    finishMutation(.importOperation(id: record.id, stage: .shelf))
                }
                let finalized = try await request("import.finalize", ["rollbackToken": token], mutation: true,
                                      owner: .importOperation(id: record.id, stage: .finalize))
                try validateImportTerminal(finalized, record: record, stage: .finalize)
                try retireImportResources(record, authority: .finalized, using: stagingLease)
                try removeRecord(record.id)
                liveImportResources.removeValue(forKey: record.id)
                finishMutation(.importOperation(id: record.id, stage: .finalize))
            } catch { /* Retain receipt and source on every unresolved recovery. */ }
        }
        if let completedRejection { throw completedRejection }
        return try await pendingImports()
    }

    func hasPendingImportAsset(_ bookIDs: Set<String>) throws -> Bool {
        try records().contains { bookIDs.contains("local:" + $0.hash) }
    }

    private func shelfBook(_ bookID: String) async throws -> ReaderBook? {
        struct Entry: Decodable { let book: ReaderBook? }
        return try decode(Entry.self, await request("bookshelf.get", ["sourceId": "local", "bookId": bookID])).book
    }

    private func requireLocal(_ book: ReaderBook) throws {
        guard book.sourceId == "local" else { throw ReaderLibraryError.unsupportedFile }
    }

    func request(_ method: String, _ params: [String: Any], mutation: Bool = false,
                         timeout: TimeInterval = 30, owner: PendingMutationOwner? = nil,
                         onSendAttempt: (() -> Void)? = nil) async throws -> Data {
        guard !isClosed else { throw ReaderLibraryError.closed }
        if !mutation { try Task.checkCancellation() }
        if mutation {
            guard let owner else { throw ReaderLibraryError.invalidResponse("missing mutation owner") }
            if unresolvedWrites.values.contains(where: { $0.owner == owner }) {
                throw ReaderLibraryError.operationPending(method)
            }
        }
        requestID += 1
        let id = requestID
        hostTransport?.bind(requestID: id, sourceID: params["sourceId"] as? String)
        if mutation, let owner {
            // Reserve the owner before the first suspension, not only after a
            // deadline: actor reentrancy cannot dispatch a competing write.
            unresolvedWrites[id] = PendingMutation(method: method, owner: owner, terminal: nil)
        }
        do {
            onSendAttempt?() // Infallible: after reservation, immediately before the actual send attempt.
            try client.send(method: method, requestId: id, params: params)
        }
        catch {
            unresolvedWrites.removeValue(forKey: id)
            hostTransport?.finish(requestID: id)
            throw error
        }
        activeRequests.insert(id)
        var terminalSeen = false
        defer {
            activeRequests.remove(id)
            if !mutation {
                if !terminalSeen { client.retireReadRequest(requestId: id) }
                // The transport retains cancellation until any queued/running
                // Host work has actually exited, then releases this read ID.
                hostTransport?.retireRead(requestID: id)
            } else if terminalSeen { hostTransport?.finish(requestID: id) }
            else { startPendingHostPump(requestID: id) }
        }
        let deadline = timing.now() + timeout
        var cancellationSent = false
        while true {
            // A write deadline ends this observer, not the already dispatched
            // Core job. Check before polling so even timeout:0 has one owner.
            if mutation && timing.now() >= deadline { throw ReaderLibraryError.operationPending(method) }
            if !mutation && Task.isCancelled && !cancellationSent {
                try client.cancel(requestId: id)
                hostTransport?.cancel(requestID: id)
                cancellationSent = true
            }
            if let result = client.pollEvent(requestId: id) {
                if case .success(let event) = result, ["result", "error"].contains(event.type) { terminalSeen = true }
                if cancellationSent { throw CancellationError() }
                if case .success(let event) = result, event.type == "host.request" {
                    if mutation {
                        queuePendingHostRequest(event, requestID: id)
                        _ = try await handleQueuedMutationHostRequest(requestID: id, late: false)
                    } else {
                        guard let transport = hostTransport, let native = client as? ReaderCoreClient else {
                            throw ReaderLibraryError.invalidResponse("Host capability is not configured")
                        }
                        try await withTaskCancellationHandler(operation: {
                            try await transport.handle(event, client: native)
                        }, onCancel: { transport.cancel(requestID: id) })
                    }
                    continue
                }
                if case .success(let event) = result, !["result", "error"].contains(event.type) { continue }
                if mutation, let owner, case .success(let event) = result,
                   event.requestId == id, ["result", "error"].contains(event.type) {
                    // Retain successful ACKs until their business owner has
                    // persisted/applied them, including Host journal I/O errors.
                    var pending = unresolvedWrites[id] ?? PendingMutation(method: method, owner: owner, terminal: nil)
                    pending.terminal = result
                    unresolvedWrites[id] = pending
                }
                let data: Data
                do { data = try responseData(result, method: method, requestID: id) }
                catch {
                    if Self.isDefiniteMutationRejection(error) { unresolvedWrites.removeValue(forKey: id) }
                    throw error
                }
                return data
            }
            if !mutation && Task.isCancelled && !cancellationSent {
                try client.cancel(requestId: id)
                hostTransport?.cancel(requestID: id)
                cancellationSent = true
            }
            if timing.now() >= deadline {
                // A timeout after dispatch is not a write rejection. Do not cancel,
                // delete assets, or report rollback without an authoritative receipt.
                if mutation { throw ReaderLibraryError.operationPending(method) }
                try? client.cancel(requestId: id)
                hostTransport?.cancel(requestID: id)
                throw ReaderLibraryError.invalidResponse("timeout: " + method)
            }
            await timing.suspend()
        }
    }

    /// Queues a consumed original Host envelope before any suspension. The
    /// operation ID is deduplicated within this exact request/owner lifetime.
    private func queuePendingHostRequest(_ event: ReaderCoreEvent, requestID: UInt64) {
        guard var pending = unresolvedWrites[requestID], pending.terminal == nil else { return }
        guard event.requestId == requestID else {
            pending.uncertainHostRequests.append(event)
            unresolvedWrites[requestID] = pending
            return
        }
        if let operationID = event.operationId,
           !pending.seenHostOperations.insert(operationID).inserted { return }
        pending.queuedHostRequests.append(event)
        unresolvedWrites[requestID] = pending
    }

    private func handleQueuedMutationHostRequest(requestID: UInt64, late: Bool) async throws -> Bool {
        guard var pending = unresolvedWrites[requestID], !pending.queuedHostRequests.isEmpty else { return false }
        // A test client or missing capability does not authorize consuming and
        // losing the envelope. Keep it available to its original owner.
        guard let transport = hostTransport, let native = client as? ReaderCoreClient else {
            throw ReaderLibraryError.invalidResponse("Host capability is not configured")
        }
        let event = pending.queuedHostRequests.removeFirst()
        pending.executingHostRequest = event
        unresolvedWrites[requestID] = pending
        do { try await transport.handle(event, client: native) }
        catch {
            if var current = unresolvedWrites[requestID] {
                current.executingHostRequest = nil
                // handle may already have performed HTTP before a control ACK
                // failed. Retain that uncertainty; never rerun its I/O blindly.
                current.uncertainHostRequests.append(event)
                unresolvedWrites[requestID] = current
            }
            throw error
        }
        if var current = unresolvedWrites[requestID] {
            current.executingHostRequest = nil
            if late { current.lateHostHandledCount += 1 }
            unresolvedWrites[requestID] = current
        }
        return true
    }

    private func startPendingHostPump(requestID: UInt64) {
        guard !isClosed, !activeRequests.contains(requestID), pendingHostPumps[requestID] == nil,
              unresolvedWrites[requestID]?.terminal == nil, unresolvedWrites[requestID] != nil,
              hostTransport != nil, client is ReaderCoreClient else { return }
        // Reserve synchronously, before Task can run: the sync drain and every
        // owner reconciliation must see exactly one poller for this request.
        activeRequests.insert(requestID)
        pendingHostPumps[requestID] = Task { [weak self] in
            guard let self else { return }
            await self.pumpPendingHostRequests(requestID: requestID)
        }
    }

    private func pumpPendingHostRequests(requestID: UInt64) async {
        defer {
            activeRequests.remove(requestID)
            pendingHostPumps[requestID] = nil
        }
        var idleDeadline = timing.now() + 30
        while !isClosed, let pending = unresolvedWrites[requestID], pending.terminal == nil {
            if !pending.queuedHostRequests.isEmpty {
                do { _ = try await handleQueuedMutationHostRequest(requestID: requestID, late: true) }
                catch { return }
                idleDeadline = timing.now() + 30
                continue
            }
            if let reply = client.pollEvent(requestId: requestID) {
                if case .success(let event) = reply {
                    if event.type == "host.request" {
                        queuePendingHostRequest(event, requestID: requestID)
                    } else if event.requestId == requestID, ["result", "error"].contains(event.type) {
                        if var current = unresolvedWrites[requestID] {
                            current.terminal = reply
                            unresolvedWrites[requestID] = current
                        }
                        hostTransport?.finish(requestID: requestID)
                        return
                    }
                }
                continue
            }
            // Idle retirement neither cancels Core nor acknowledges the job.
            // Its original journal and any queued envelopes survive; a later
            // original-owner drain can resume this same request ID.
            if timing.now() >= idleDeadline { return }
            await timing.suspend()
        }
    }

    func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw ReaderLibraryError.invalidResponse(String(describing: type)) }
    }

    func responseData(_ reply: Result<ReaderCoreEvent, ReaderCoreClientError>, method: String,
                              requestID: UInt64) throws -> Data {
        let event = try reply.get()
        guard event.requestId == requestID else { throw ReaderLibraryError.invalidResponse("reply request identity") }
        if event.type == "error" {
            let error = event.coreError
            let details = event.error?["details"] as? [String: Any]
            if details?["originalPending"] as? Bool == true { throw ReaderCoreOriginalOperationPending() }
            // Core uses `category` for stable product-level outcomes such as
            // CACHE_MISSING and NETWORK_ENVIRONMENT. Preserve it when a
            // lower-level reason is absent so Host/UI can distinguish a
            // missing offline body from a retryable network failure without
            // parsing localized error messages.
            let reason = details?["reason"] as? String ?? details?["category"] as? String
            throw ReaderLibraryError.core(code: error?.code ?? "INTERNAL", message: error?.message ?? "",
                                          retryable: error?.retryable ?? false, reason: reason)
        }
        guard event.type == "result", let data = event.data else { throw ReaderLibraryError.invalidResponse(method) }
        return try JSONSerialization.data(withJSONObject: data)
    }

    func progressReceipt(_ data: Data, for book: ReaderBook) throws -> ReaderProgressSnapshot {
        struct Receipt: Decodable { let stored: Bool; let progressRevision: String? }
        let receipt = try decode(Receipt.self, data)
        let progress = try decode(ReaderProgress.self, data)
        guard receipt.stored, let revision = receipt.progressRevision, !revision.isEmpty,
              progress.sourceId == book.sourceId, progress.bookId == book.bookId else {
            throw ReaderLibraryError.invalidResponse("progress receipt identity")
        }
        return ReaderProgressSnapshot(found: true, progressRevision: revision, progress: progress)
    }

    /// Shared by the immediate and late persist paths. This is the original
    /// persist response, never reconstructed from bookshelf/progress reads.
    private func applyPersistedReceipt(_ data: Data, record: inout HostImportRecord) throws -> [String: Any] {
        let persisted = try object(data)
        guard let token = persisted["rollbackToken"] as? [String: Any], token["kind"] as? String == "localBook",
              let tokenBody = token["token"] as? [String: Any], tokenBody["transactionId"] as? String == record.id,
              let value = persisted["persisted"] as? [String: Any], value["kind"] as? String == "localBook",
              let local = value["data"] as? [String: Any], let metadata = local["book"] as? [String: Any] else {
            throw ReaderLibraryError.invalidResponse("original import.persist receipt")
        }
        var shelf: [String: Any] = ["sourceId": "local", "bookId": "local:" + record.hash,
                                  "title": metadata["title"] as? String ?? "",
                                  "author": metadata["author"] as? String ?? "", "requireReadable": true]
        for key in ["coverUrl", "intro", "kind"] { if let value = metadata[key] { shelf[key] = value } }
        record.rollbackToken = try JSONSerialization.data(withJSONObject: token)
        if record.reprocessOperationID != nil {
            record.shelfParameters = nil
            record.phase = .finalize
            try writeRecord(record)
            return local
        }
        record.shelfParameters = try JSONSerialization.data(withJSONObject: shelf)
        record.phase = .persisted
        try writeRecord(record)
        return local
    }

    func finishMutation(_ owner: PendingMutationOwner) {
        for id in unresolvedWrites.keys.filter({ unresolvedWrites[$0]?.owner == owner }) {
            unresolvedWrites.removeValue(forKey: id)
        }
    }

    private func hasPendingImport(_ recordID: String) -> Bool {
        unresolvedWrites.values.contains { pending in
            if case .importOperation(let id, _) = pending.owner { return id == recordID }
            return false
        }
    }

    /// pollEvent consumes an event. Retain it first, then retire it only after
    /// its original owner has durably applied the corresponding phase.
    func drainUnresolvedReplies(owner: PendingMutationOwner? = nil, importsOnly: Bool = false,
                               resourceLease: ReaderImportStagingLease? = nil) throws {
        for id in unresolvedWrites.keys.sorted() {
            guard !activeRequests.contains(id), var pending = unresolvedWrites[id] else { continue }
            if let owner, pending.owner != owner { continue }
            if importsOnly {
                guard case .importOperation = pending.owner else { continue }
            }
            if pending.terminal == nil, let reply = client.pollEvent(requestId: id), case .success(let event) = reply {
                if event.type == "host.request" {
                    queuePendingHostRequest(event, requestID: id)
                    pending = unresolvedWrites[id] ?? pending
                } else if event.requestId == id, ["result", "error"].contains(event.type) {
                    pending.terminal = reply
                    unresolvedWrites[id] = pending
                    hostTransport?.finish(requestID: id)
                }
            }
            if pending.terminal == nil { startPendingHostPump(requestID: id) }
            guard case .importOperation(let recordID, let stage) = pending.owner,
                  let terminal = pending.terminal,
                  var record = try records().first(where: { $0.id == recordID }) else { continue }
            let data: Data
            do { data = try responseData(terminal, method: pending.method, requestID: id) }
            catch {
                // Unknown post-dispatch failures remain unresolved. An explicit
                // rejection is applied to the original import, never to a read.
                guard !isUnknownOutcome(error) else { continue }
                if stage == .persist {
                    if record.reprocessOperationID != nil {
                        record.phase = .rejected
                        record.rejection = StoredImportRejection(error)
                        record.originalFailure = error.localizedDescription
                        try writeRecord(record)
                        unresolvedWrites.removeValue(forKey: id)
                        throw error
                    }
                    try retireImportResources(record, authority: .persistRejected, using: resourceLease)
                    try removeRecord(recordID)
                    liveImportResources.removeValue(forKey: recordID)
                    unresolvedWrites.removeValue(forKey: id)
                    throw error
                }
                if stage == .shelf {
                    record.phase = .rollback
                    record.rejection = StoredImportRejection(error)
                    try writeRecord(record)
                }
                unresolvedWrites.removeValue(forKey: id)
                continue
            }
            switch stage {
            case .persist:
                _ = try applyPersistedReceipt(data, record: &record)
            case .shelf:
                struct ShelfReceipt: Decodable { let created: Bool }
                _ = try decode(ShelfReceipt.self, data)
                record.phase = .finalize
                try writeRecord(record)
            case .finalize, .rollback:
                try validateImportTerminal(data, record: record, stage: stage)
                if record.reprocessOperationID != nil {
                    guard stage == .finalize, record.reprocessResult != nil else {
                        throw ReaderLibraryError.invalidResponse("reprocess completion receipt")
                    }
                    record.phase = .completed
                    try writeRecord(record)
                } else {
                    try retireImportResources(record, authority: stage == .rollback ? .rolledBack : .finalized, using: resourceLease)
                    try removeRecord(recordID)
                    liveImportResources.removeValue(forKey: recordID)
                }
            }
            unresolvedWrites.removeValue(forKey: id)
            if stage == .rollback { throw rollbackCompletion(record) }
        }
    }

    private func rollbackCompletion(_ record: HostImportRecord) -> Error {
        if let rejection = record.rejection { return rejection.error }
        return ReaderImportRollbackCompletion(operationId: record.id, originalFailure: record.originalFailure)
    }

    private func validateImportTerminal(_ data: Data, record: HostImportRecord, stage: ImportMutationStage) throws {
        let receipt = try object(data)
        let body = receipt["data"] as? [String: Any]
        let flag = stage == .finalize ? "finalized" : "restored"
        let identityField = stage == .finalize ? "bookId" : "book_id"
        guard receipt["kind"] as? String == "localBook", body?[identityField] as? String == "local:" + record.hash,
              body?[flag] as? Bool == true else { throw ReaderLibraryError.invalidResponse("original import terminal receipt") }
    }

    func object(_ data: Data) throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ReaderLibraryError.invalidResponse("object")
        }
        return value
    }

    /// Only explicit Core admission/validation rejections prove no mutation was
    /// accepted. INTERNAL, timeout, I/O and fresh read success prove neither side.
    public static func isDefiniteMutationRejection(_ error: Error) -> Bool {
        if let failure = error as? ReaderLibraryError, case .core(let code, _, _, _) = failure {
            return ["INVALID_PARAMS", "INVALID_MESSAGE", "UNKNOWN_METHOD", "INVALID_PROTOCOL_VERSION",
                    "BUSY", "RESOURCE_EXHAUSTED", "BOOK_ALREADY_ON_SHELF"].contains(code)
        }
        return false
    }

    private func isUnknownOutcome(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        return !Self.isDefiniteMutationRejection(error)
    }

    static func sha256(at url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var digest = SHA256()
        while let chunk = try file.read(upToCount: 1024 * 1024), !chunk.isEmpty { digest.update(data: chunk) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func stableSource(_ hash: String) -> URL { sourceURL.appendingPathComponent(hash + ".source") }

    @discardableResult
    private func commitSource(_ staged: URL, hash: String,
                              didCreate: (ReaderImportStagingOwner.CreatedSource) throws -> Void = { _ in }) throws -> Bool {
        let destination = stableSource(hash)
        if FileManager.default.fileExists(atPath: destination.path) {
            guard try ReaderImportStagingLease.verifiedSHA256(at: destination) == hash else {
                throw ReaderLibraryError.invalidResponse("source identity mismatch")
            }
            if staged != destination, FileManager.default.fileExists(atPath: staged.path) {
                guard try ReaderImportStagingLease.verifiedSHA256(at: staged) == hash else {
                    throw ReaderLibraryError.invalidResponse("staged source identity mismatch")
                }
                try FileManager.default.removeItem(at: staged)
                try importSourceDirectorySync(staged.deletingLastPathComponent())
            }
            return false
        }
        let verified = try ReaderImportStagingLease.verifiedFile(at: staged)
        guard verified.sha256 == hash else {
            throw ReaderLibraryError.invalidResponse("staged source identity mismatch")
        }
        try ReaderImportStagingLease.moveExclusively(staged, to: destination)
        // The no-overwrite rename preserves the verified inode. Publish that
        // creation fact BEFORE the callback's durable write or either fsync.
        try didCreate(.init(name: destination.lastPathComponent, identity: verified.identity))
        try importSourceDirectorySync(sourceURL)
        try importSourceDirectorySync(staged.deletingLastPathComponent())
        return true
    }

    private func registerSourceCreation(_ created: ReaderImportStagingOwner.CreatedSource,
                                        owner original: ReaderImportStagingOwner,
                                        using lease: ReaderImportStagingLease) throws {
        var owner = original
        owner.phase = .handedOff
        owner.createdSource = created
        liveImportResources[owner.transactionID] = owner // Infallible before any following I/O.
        try lease.recordCreatedSource(owner)
    }

    private func importResourceProof(for record: HostImportRecord, using lease: ReaderImportStagingLease) throws -> ReaderImportStagingOwner? {
        let proof = try liveImportResources[record.id] ?? lease.owner(for: record.id)
        guard let proof else { return nil } // Legacy bare staging is never guessed to be ours.
        guard proof.transactionID == record.id, proof.stagedName == record.stagedName, proof.sha256 == record.hash else {
            throw ReaderLibraryError.invalidResponse("original import resource identity")
        }
        return proof
    }

    private func retireImportResources(_ record: HostImportRecord,
                                       authority: ReaderImportStagingLease.RetirementAuthority,
                                       using provided: ReaderImportStagingLease? = nil) throws {
        guard record.reprocessOperationID == nil else { return }
        let lease = try provided ?? ReaderImportStagingLease(stagingURL: stagingURL)
        defer { if provided == nil { lease.release() } }
        guard let proof = try importResourceProof(for: record, using: lease) else { return }
        // No other original business owner may claim the exact path being
        // retired. A shared SHA never establishes that we created its source.
        let others = try records(includeCompleted: true).filter { $0.id != record.id }
        guard !others.contains(where: { $0.stagedName == record.stagedName ||
            (authority == .rolledBack && proof.createdSource != nil && $0.hash == record.hash) }) else {
            throw ReaderLibraryError.operationPending(record.id)
        }
        try lease.retireOwned(proof, authority: authority)
    }

    private func writeRecord(_ record: HostImportRecord) throws {
        try ReaderImportStagingLease.writeDurably(try JSONEncoder().encode(record),
            to: operationsURL.appendingPathComponent(record.id + ".json"))
    }

    private func stagingProtections() throws -> [ReaderImportStagingLease.Protection] {
        try records(includeCompleted: true).map {
            .init(transactionID: $0.id, stagedName: $0.stagedName, hash: $0.hash)
        }
    }

    private func removeRecord(_ id: String) throws {
        try FileManager.default.removeItem(at: operationsURL.appendingPathComponent(id + ".json"))
    }

    private func records(includeCompleted: Bool = false) throws -> [HostImportRecord] {
        try FileManager.default.contentsOfDirectory(at: operationsURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { try JSONDecoder().decode(HostImportRecord.self, from: Data(contentsOf: $0)) }
            .filter { includeCompleted || ($0.phase != .completed && $0.phase != .rejected) }
    }
}

private struct HostImportRecord: Codable {
    enum Phase: String, Codable { case preparing, persistAwaiting, persisted, shelfAwaiting, finalize, rollback, completed, rejected }
    let id: String
    let fileName: String
    let stagedName: String
    let hash: String
    var phase: Phase
    var rollbackToken: Data?
    var shelfParameters: Data?
    var rejection: StoredImportRejection? = nil
    var originalFailure: String? = nil
    var reprocessOperationID: String? = nil
    var reprocessInput: Data? = nil
    var reprocessResult: ReaderImportResult? = nil
    var reprocessFinalizationDispatched: Bool? = nil
}

/// The original import has an authoritative compensation ACK. This is a
/// confirmed import failure, not a claim that the earlier mutation never ran.
public struct ReaderImportRollbackCompletion: Error, Sendable {
    public let operationId: String
    public let originalFailure: String?
}

enum ImportMutationStage: Hashable { case persist, shelf, finalize, rollback }
enum PendingMutationOwner: Hashable {
    case importOperation(id: String, stage: ImportMutationStage)
    case progress(sourceId: String, bookId: String)
    case flush
    case command(String)
}
struct PendingMutation {
    let method: String
    let owner: PendingMutationOwner
    var terminal: Result<ReaderCoreEvent, ReaderCoreClientError>?
    var queuedHostRequests: [ReaderCoreEvent] = []
    var seenHostOperations: Set<UInt64> = []
    var executingHostRequest: ReaderCoreEvent?
    var uncertainHostRequests: [ReaderCoreEvent] = []
    var lateHostHandledCount: Int = 0
}
private struct StoredImportRejection: Codable {
    let code: String
    let message: String
    let retryable: Bool
    let reason: String?
    init?(_ error: Error) {
        guard let error = error as? ReaderLibraryError, case .core(let code, let message, let retryable, let reason) = error else { return nil }
        self.code = code; self.message = message; self.retryable = retryable; self.reason = reason
    }
    var error: ReaderLibraryError { .core(code: code, message: message, retryable: retryable, reason: reason) }
}
