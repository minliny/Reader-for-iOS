import Foundation
import CryptoKit
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif

/// Core 2a301653 owns all parsing, shelf rows and reading positions. This actor
/// owns one runtime and serializes FFI send/cancel/destroy. Polling suspends the
/// actor instead of blocking MainActor or a cooperative executor in request().
public actor ReaderLibraryService: ReaderLibraryServing {
    public static let coreBaseline = "2a301653c140eef457e786fd6ab3bb9b8e3045c8"
    private let client: any ReaderCoreEventClient
    private let timing: ReaderRequestTiming
    private let sourceURL: URL
    private let stagingURL: URL
    private let operationsURL: URL
    private var requestID: UInt64 = 100
    private var activeRequests: Set<UInt64> = []
    private var unresolvedWrites: [UInt64: PendingMutation] = [:]
    private var isClosed = false
    private var importInFlight = false
    private var recovering = false

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
        self.client = try ReaderCoreClient(configJSON: config)
        self.timing = .live
    }

    init(storageURL: URL, sourceURL: URL, client: any ReaderCoreEventClient, timing: ReaderRequestTiming) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: storageURL, withIntermediateDirectories: true)
        try manager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        self.sourceURL = sourceURL
        self.stagingURL = sourceURL.appendingPathComponent(".staging", isDirectory: true)
        self.operationsURL = sourceURL.appendingPathComponent(".operations", isDirectory: true)
        try manager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        try manager.createDirectory(at: operationsURL, withIntermediateDirectories: true)
        self.client = client
        self.timing = timing
    }

    public func listBooks() async throws -> [ReaderBook] {
        struct Page: Decodable { let books: [ReaderBook]; let total: Int }
        var books: [ReaderBook] = []
        repeat {
            let data = try await request("bookshelf.list", [
                "sourceId": "local", "contentKind": "text", "sortBy": "lastReadAt",
                "sortDirection": "descending", "offset": books.count, "limit": 128
            ])
            let page = try decode(Page.self, data)
            books.append(contentsOf: page.books)
            if page.books.isEmpty || books.count >= page.total { return books }
        } while true
    }

    public func chapters(for book: ReaderBook) async throws -> [ReaderChapter] {
        try requireLocal(book)
        struct Toc: Decodable { let toc: [ReaderChapter] }
        return try decode(Toc.self, await request("local_book.toc", ["bookId": book.bookId])).toc
    }

    public func content(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderChapterContent {
        try requireLocal(book)
        return try decode(ReaderChapterContent.self, await request("local_book.chapter.content", [
            "bookId": book.bookId, "chapterIndex": chapterIndex
        ]))
    }

    public func progress(for book: ReaderBook) async throws -> ReaderProgressSnapshot {
        try requireLocal(book)
        return try decode(ReaderProgressSnapshot.self, await request("reading.progress.get", [
            "sourceId": book.sourceId, "bookId": book.bookId
        ]))
    }

    public func saveProgress(for book: ReaderBook, content: ReaderChapterContent, scalarOffset: UInt64,
                             expectedRevision: String?) async throws -> ReaderProgressSnapshot {
        try requireLocal(book)
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
        try requireLocal(book)
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
              !importInFlight, !recovering else { throw ReaderLibraryError.busy }
        try await flush()
        guard activeRequests.isEmpty, unresolvedWrites.isEmpty, !importInFlight, !recovering else { throw ReaderLibraryError.busy }
        isClosed = true
        client.destroy()
    }

    public func importBook(at url: URL) async throws -> ReaderImportResult {
        guard !isClosed else { throw ReaderLibraryError.closed }
        guard !importInFlight, !recovering else { throw ReaderLibraryError.busy }
        guard url.pathExtension.lowercased() == "txt" else { throw ReaderLibraryError.unsupportedFile }
        try Task.checkCancellation()
        importInFlight = true
        defer { importInFlight = false }
        let selection = UUID().uuidString.lowercased()
        let staged = stagingURL.appendingPathComponent(selection + ".source")
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        try FileManager.default.copyItem(at: url, to: staged)
        var record: HostImportRecord?
        var createdSource = false
        var shelfDispatched = false
        var shelfAcknowledged = false
        do {
            let hash = try Self.sha256(at: staged)
            let bookID = "local:" + hash
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
            try Task.checkCancellation()
            let transactionID = "ios-import-" + selection
            record = HostImportRecord(id: transactionID, fileName: url.lastPathComponent,
                                      stagedName: staged.lastPathComponent, hash: hash,
                                      phase: .persistAwaiting, rollbackToken: nil, shelfParameters: nil)
            try writeRecord(record!)
            let persisted = try await request("import.persist", [
                "transactionId": transactionID, "parsed": parsedObject
            ], mutation: true, timeout: 120, owner: .importOperation(id: transactionID, stage: .persist))
            var persistedRecord = record!
            let local = try applyPersistedReceipt(persisted, record: &persistedRecord)
            record = persistedRecord
            finishMutation(.importOperation(id: transactionID, stage: .persist))
            let token = try object(persistedRecord.rollbackToken!)
            let shelf = try object(persistedRecord.shelfParameters!)
            createdSource = try commitSource(staged, hash: hash)
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
                _ = try await request("import.finalize", ["rollbackToken": token], mutation: true,
                                      owner: .importOperation(id: transactionID, stage: .finalize))
                try removeRecord(transactionID)
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
            if let current = record {
                if current.rollbackToken == nil && unknown {
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
                        _ = try await request("import.rollback", ["rollbackToken": try object(tokenData)], mutation: true,
                                              owner: .importOperation(id: current.id, stage: .rollback))
                    } catch { throw ReaderLibraryError.operationPending(current.id) }
                }
                if createdSource { try? FileManager.default.removeItem(at: stableSource(current.hash)) }
                try removeRecord(current.id)
                finishMutation(.importOperation(id: current.id, stage: .rollback))
            }
            try? FileManager.default.removeItem(at: staged)
            throw error
        }
    }

    /// Host records contain only opaque Core receipts and file-operation intent.
    /// They are not a second shelf/progress database. Unknown persist outcomes
    /// remain visible until Core offers an exact receipt query for that operation.
    public func pendingImports() async throws -> [ReaderPendingImport] {
        guard !isClosed else { throw ReaderLibraryError.closed }
        return try records().map { ReaderPendingImport(id: $0.id, fileName: $0.fileName,
                                               requiresReconciliation: $0.phase != .finalize) }
    }

    public func recoverPendingImports() async throws -> [ReaderPendingImport] {
        guard !isClosed else { throw ReaderLibraryError.closed }
        guard !importInFlight, !recovering else { throw ReaderLibraryError.busy }
        recovering = true
        defer { recovering = false }
        try drainUnresolvedReplies(importsOnly: true)
        var completedRejection: Error?
        for var record in try records() {
            // A live original request owns this phase until its terminal reply
            // is applied. Never race it with a replacement mutation.
            guard !hasPendingImport(record.id) else { continue }
            guard let tokenData = record.rollbackToken else { continue }
            let token = try object(tokenData)
            do {
                if record.phase == .rollback {
                    _ = try await request("import.rollback", ["rollbackToken": token], mutation: true,
                                          owner: .importOperation(id: record.id, stage: .rollback))
                    try removeRecord(record.id)
                    finishMutation(.importOperation(id: record.id, stage: .rollback))
                    try? FileManager.default.removeItem(at: stagingURL.appendingPathComponent(record.stagedName))
                    if completedRejection == nil {
                        completedRejection = rollbackCompletion(record)
                    }
                    continue
                }
                if record.phase != .finalize {
                    guard let shelf = record.shelfParameters else { continue }
                    _ = try commitSource(stagingURL.appendingPathComponent(record.stagedName), hash: record.hash)
                    record.phase = .shelfAwaiting
                    try writeRecord(record)
                    _ = try await request("bookshelf.add", try object(shelf), mutation: true,
                                          owner: .importOperation(id: record.id, stage: .shelf))
                    record.phase = .finalize
                    try writeRecord(record)
                    finishMutation(.importOperation(id: record.id, stage: .shelf))
                }
                _ = try await request("import.finalize", ["rollbackToken": token], mutation: true,
                                      owner: .importOperation(id: record.id, stage: .finalize))
                try removeRecord(record.id)
                finishMutation(.importOperation(id: record.id, stage: .finalize))
            } catch { /* Retain receipt and source on every unresolved recovery. */ }
        }
        if let completedRejection { throw completedRejection }
        return try await pendingImports()
    }

    private func shelfBook(_ bookID: String) async throws -> ReaderBook? {
        struct Entry: Decodable { let book: ReaderBook? }
        return try decode(Entry.self, await request("bookshelf.get", ["sourceId": "local", "bookId": bookID])).book
    }

    private func requireLocal(_ book: ReaderBook) throws {
        guard book.sourceId == "local" else { throw ReaderLibraryError.unsupportedFile }
    }

    private func request(_ method: String, _ params: [String: Any], mutation: Bool = false,
                         timeout: TimeInterval = 30, owner: PendingMutationOwner? = nil) async throws -> Data {
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
        if mutation, let owner {
            // Reserve the owner before the first suspension, not only after a
            // deadline: actor reentrancy cannot dispatch a competing write.
            unresolvedWrites[id] = PendingMutation(method: method, owner: owner, terminal: nil)
        }
        do { try client.send(method: method, requestId: id, params: params) }
        catch { unresolvedWrites.removeValue(forKey: id); throw error }
        activeRequests.insert(id)
        defer { activeRequests.remove(id) }
        let deadline = timing.now() + timeout
        var cancellationSent = false
        while true {
            if let result = client.pollEvent(requestId: id) {
                if cancellationSent { throw CancellationError() }
                if mutation, let owner, case .success(let event) = result,
                   event.requestId == id, ["result", "error"].contains(event.type) {
                    // Retain successful ACKs until their business owner has
                    // persisted/applied them, including Host journal I/O errors.
                    unresolvedWrites[id] = PendingMutation(method: method, owner: owner, terminal: result)
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
                cancellationSent = true
            }
            if timing.now() >= deadline {
                // A timeout after dispatch is not a write rejection. Do not cancel,
                // delete assets, or report rollback without an authoritative receipt.
                if mutation, let owner {
                    unresolvedWrites[id] = PendingMutation(method: method, owner: owner, terminal: nil)
                    throw ReaderLibraryError.operationPending(method)
                }
                try? client.cancel(requestId: id)
                throw ReaderLibraryError.invalidResponse("timeout: " + method)
            }
            await timing.suspend()
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw ReaderLibraryError.invalidResponse(String(describing: type)) }
    }

    private func responseData(_ reply: Result<ReaderCoreEvent, ReaderCoreClientError>, method: String,
                              requestID: UInt64) throws -> Data {
        let event = try reply.get()
        guard event.requestId == requestID else { throw ReaderLibraryError.invalidResponse("reply request identity") }
        if event.type == "error" {
            let error = event.coreError
            let details = event.error?["details"] as? [String: Any]
            throw ReaderLibraryError.core(code: error?.code ?? "INTERNAL", message: error?.message ?? "",
                                          retryable: error?.retryable ?? false, reason: details?["reason"] as? String)
        }
        guard event.type == "result", let data = event.data else { throw ReaderLibraryError.invalidResponse(method) }
        return try JSONSerialization.data(withJSONObject: data)
    }

    private func progressReceipt(_ data: Data, for book: ReaderBook) throws -> ReaderProgressSnapshot {
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
        record.shelfParameters = try JSONSerialization.data(withJSONObject: shelf)
        record.phase = .persisted
        try writeRecord(record)
        return local
    }

    private func finishMutation(_ owner: PendingMutationOwner) {
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
    private func drainUnresolvedReplies(owner: PendingMutationOwner? = nil, importsOnly: Bool = false) throws {
        for id in unresolvedWrites.keys.sorted() {
            guard !activeRequests.contains(id), var pending = unresolvedWrites[id] else { continue }
            if let owner, pending.owner != owner { continue }
            if importsOnly {
                guard case .importOperation = pending.owner else { continue }
            }
            if pending.terminal == nil, let reply = client.pollEvent(requestId: id),
               case .success(let event) = reply, event.requestId == id, ["result", "error"].contains(event.type) {
                pending.terminal = reply
                unresolvedWrites[id] = pending
            }
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
                    try removeRecord(recordID)
                    try? FileManager.default.removeItem(at: stagingURL.appendingPathComponent(record.stagedName))
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
                let receipt = try object(data)
                let body = receipt["data"] as? [String: Any]
                let flag = stage == .finalize ? "finalized" : "restored"
                let identityField = stage == .finalize ? "bookId" : "book_id"
                guard receipt["kind"] as? String == "localBook", body?[identityField] as? String == "local:" + record.hash,
                      body?[flag] as? Bool == true else {
                    throw ReaderLibraryError.invalidResponse("original " + pending.method + " receipt")
                }
                try removeRecord(recordID)
                if stage == .rollback {
                    try? FileManager.default.removeItem(at: stagingURL.appendingPathComponent(record.stagedName))
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

    private func object(_ data: Data) throws -> [String: Any] {
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

    private static func sha256(at url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var digest = SHA256()
        while let chunk = try file.read(upToCount: 1024 * 1024), !chunk.isEmpty { digest.update(data: chunk) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func stableSource(_ hash: String) -> URL { sourceURL.appendingPathComponent(hash + ".source") }

    @discardableResult
    private func commitSource(_ staged: URL, hash: String) throws -> Bool {
        let destination = stableSource(hash)
        if FileManager.default.fileExists(atPath: destination.path) {
            guard try Self.sha256(at: destination) == hash else {
                throw ReaderLibraryError.invalidResponse("source identity mismatch")
            }
            if staged != destination, FileManager.default.fileExists(atPath: staged.path) {
                try FileManager.default.removeItem(at: staged)
            }
            return false
        }
        try FileManager.default.moveItem(at: staged, to: destination)
        return true
    }

    private func writeRecord(_ record: HostImportRecord) throws {
        try JSONEncoder().encode(record).write(to: operationsURL.appendingPathComponent(record.id + ".json"), options: .atomic)
    }

    private func removeRecord(_ id: String) throws {
        try FileManager.default.removeItem(at: operationsURL.appendingPathComponent(id + ".json"))
    }

    private func records() throws -> [HostImportRecord] {
        try FileManager.default.contentsOfDirectory(at: operationsURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { try JSONDecoder().decode(HostImportRecord.self, from: Data(contentsOf: $0)) }
    }
}

private struct HostImportRecord: Codable {
    enum Phase: String, Codable { case persistAwaiting, persisted, shelfAwaiting, finalize, rollback }
    let id: String
    let fileName: String
    let stagedName: String
    let hash: String
    var phase: Phase
    var rollbackToken: Data?
    var shelfParameters: Data?
    var rejection: StoredImportRejection? = nil
    var originalFailure: String? = nil
}

/// The original import has an authoritative compensation ACK. This is a
/// confirmed import failure, not a claim that the earlier mutation never ran.
public struct ReaderImportRollbackCompletion: Error, Sendable {
    public let operationId: String
    public let originalFailure: String?
}

private enum ImportMutationStage: Hashable { case persist, shelf, finalize, rollback }
private enum PendingMutationOwner: Hashable {
    case importOperation(id: String, stage: ImportMutationStage)
    case progress(sourceId: String, bookId: String)
    case flush
}
private struct PendingMutation {
    let method: String
    let owner: PendingMutationOwner
    var terminal: Result<ReaderCoreEvent, ReaderCoreClientError>?
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
