import Foundation
import CryptoKit
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif

/// The pinned Core owns all parsing, shelf rows and reading positions. This actor
/// owns one runtime and serializes FFI send/cancel/destroy. Polling suspends the
/// actor instead of blocking MainActor or a cooperative executor in request().
public actor ReaderLibraryService: ReaderLibraryServing {
    public static let coreBaseline = "58a0d4597f7f2dfba3773f34c753c1cc82de7961"
    let client: any ReaderCoreEventClient
    let hostTransport: ReaderIOSHostTransport?
    private let timing: ReaderRequestTiming
    private let sourceExecutionPause: @Sendable (TimeInterval) async throws -> Void
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
    private struct SourceExecutionObservation {
        let id: UUID
        let task: Task<Void, Never>
    }
    private var sourceExecutionObservations: [UInt64: SourceExecutionObservation] = [:]
    // Every concurrent close keeps admission shut until its own attempt ends.
    private var sourceExecutionCloseOwners: Set<UUID> = []
    private var downloadStatusObservers: [UUID: (sourceID: String, bookID: String,
        continuation: AsyncStream<ReaderDownloadStatusInvalidation>.Continuation)] = [:]
    private var isClosed = false
    var importInFlight = false
    var assetMutationInFlight = false
    var sourceSwitchInFlight = false
    var readingCacheWindowInFlight: Set<String> = []
    var onlineAdmissionContinuationsInFlight: Set<String> = []
    var unfencedOnlineContentRefreshes: Set<ReaderOnlineContentRefreshIdentity> = []
    var onlineContentRefreshesInFlight: Set<ReaderOnlineContentRefreshIdentity> = []
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
        self.sourceExecutionPause = { try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) }
        self.importStagingObserver = { _, _ in }
        self.importSourceDirectorySync = { try ReaderImportStagingLease.synchronizeDirectory($0) }
    }

    init(storageURL: URL, sourceURL: URL, client: any ReaderCoreEventClient, timing: ReaderRequestTiming,
         importStagingObserver: @escaping ReaderImportStagingObserver = { _, _ in },
         importSourceDirectorySync: @escaping @Sendable (URL) throws -> Void = { try ReaderImportStagingLease.synchronizeDirectory($0) },
         sourceExecutionPause: @escaping @Sendable (TimeInterval) async throws -> Void = {
             try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000))
         }) throws {
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
        self.sourceExecutionPause = sourceExecutionPause
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
        let closing = UUID()
        sourceExecutionCloseOwners.insert(closing)
        defer { sourceExecutionCloseOwners.remove(closing) }
        let observations = sourceExecutionObservations.values.map(\.task)
        for task in observations { task.cancel() }
        for task in observations { await task.value }
        if isClosed { return }
        try drainUnresolvedReplies(importsOnly: true)
        // Do not destroy the runtime underneath an in-flight durable import/write.
        guard activeRequests.isEmpty, unresolvedWrites.values.allSatisfy({ $0.owner == .flush || $0.localV2Proof != nil }),
              !importInFlight, !recovering, !assetMutationInFlight else { throw ReaderLibraryError.busy }
        try await flush()
        guard activeRequests.isEmpty, unresolvedWrites.values.allSatisfy({ $0.localV2Proof != nil }), !importInFlight, !recovering, !assetMutationInFlight else { throw ReaderLibraryError.busy }
        isClosed = true
        for observer in downloadStatusObservers.values { observer.continuation.finish() }
        downloadStatusObservers.removeAll()
        client.destroy()
        unresolvedWrites.removeAll() // Remaining entries have durable v2 ACK proof; wrapper destruction retires their transports.
    }

    public func downloadStatusInvalidations(for book: ReaderBook) async -> AsyncStream<ReaderDownloadStatusInvalidation> {
        guard !isClosed else { return AsyncStream { $0.finish() } }
        let observerID = UUID()
        // These are coalescible wakeups, never a second queue of task facts.
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            downloadStatusObservers[observerID] = (book.sourceId, book.bookId, continuation)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeDownloadStatusObserver(observerID) }
            }
        }
    }

    private func removeDownloadStatusObserver(_ observerID: UUID) {
        downloadStatusObservers.removeValue(forKey: observerID)
    }

    private func downloadStatusIdentity(method: String, parameters: [String: Any],
                                        owner: PendingMutationOwner?, requestID: UInt64) -> ReaderDownloadStatusInvalidation? {
        guard method == "cache.book.prefetch", case .command(let operationID)? = owner,
              let sourceID = parameters["sourceId"] as? String, !sourceID.isEmpty,
              let bookID = parameters["bookId"] as? String, !bookID.isEmpty,
              let coreOperationID = parameters["operationId"] as? String, !coreOperationID.isEmpty,
              let sequence = parameters["sequence"] as? NSNumber,
              let range = parameters["chapterRange"] as? [UInt32], range.count == 2 else { return nil }
        return .init(sourceID: sourceID, bookID: bookID, operationID: operationID,
                     coreOperationID: coreOperationID, sequence: sequence.uint64Value, requestID: requestID,
                     method: method, chapterRange: range, phase: .submitted)
    }

    private func invalidateDownloadStatus(_ identity: ReaderDownloadStatusInvalidation?,
                                          phase: ReaderDownloadStatusInvalidation.Phase) {
        guard let identity else { return }
        let event = identity.at(phase)
        for observer in downloadStatusObservers.values
        where observer.sourceID == event.sourceID && observer.bookID == event.bookID {
            observer.continuation.yield(event)
        }
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
        var authoritySendAttempted = false
        do {
            guard let hash = stagingOwner.sha256 else { throw ReaderLibraryError.invalidResponse("unsealed import source") }
            let bookID = "local:" + hash
            if let original = try records().first(where: { $0.hash == hash && !$0.hasReadableImportReceipt }) {
                throw ReaderLibraryError.operationPending(original.id)
            }
            if let existing = try await shelfBook(bookID) {
                _ = try commitSource(staged, hash: hash)
                return ReaderImportResult(book: existing, created: false)
            }
            struct Capabilities: Decodable { let capabilities: [String] }
            let capabilities = try decode(Capabilities.self, await request("core.info", [:]))
            guard capabilities.capabilities.contains(HostLocalImportV2.requiredCapability) else {
                throw ReaderLibraryError.invalidResponse("local import v2 capability is required")
            }
            let input: [String: Any] = [
                "bookId": bookID, "fileName": url.lastPathComponent,
                "filePath": staged.path, "title": url.deletingPathExtension().lastPathComponent
            ]
            let parsed = try await request("import.parse", ["kind": "localBook", "input": input], timeout: 120)
            let parsedObject = try object(parsed)
            guard let preview = parsedObject["preview"] as? [String: Any],
                  let summary = preview["summary"] as? [String: Any],
                  let format = summary["format"] as? String, !format.isEmpty,
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
                                      phase: .v2Preparing, rollbackToken: nil, shelfParameters: nil)
            record?.protocolGeneration = 2
            record?.requiredCapability = HostLocalImportV2.requiredCapability
            record?.localV2 = HostLocalImportV2(preview: try JSONSerialization.data(withJSONObject: preview, options: .sortedKeys),
                sourceBytes: UInt64(stagingOwner.expectedBytes), format: format)
            try writeRecord(record!)
            liveImportResources[transactionID] = stagingOwner
            liveImportResources[transactionID] = try stagingLease.handoff(stagingOwner)
            record?.localV2?.resourceOwner = liveImportResources[transactionID]
            try writeRecord(record!)
            var prepared = record!
            try await bootstrapLocalImportV2(&prepared, onSend: { authoritySendAttempted = true })
            record = prepared
            return try await continueLocalImportV2(prepared, using: stagingLease, firstPersist: true)
        } catch let completed as ReaderImportRollbackCompletion {
            throw completed
        } catch {
            if let current = record, !authoritySendAttempted {
                // No v2 authority request was attempted by this invocation.
                liveImportResources[current.id] = liveImportResources[current.id] ?? stagingOwner
                try retireImportResources(current, authority: .notDispatched, using: stagingLease)
                do { try removeRecord(current.id) }
                catch let failure as CocoaError where failure.code == .fileNoSuchFile {}
                liveImportResources.removeValue(forKey: current.id)
                throw error
            }
            if let record { throw ReaderLibraryError.operationPending(record.id) }
            // The private owner defer retires only a proved precommit inode.
            throw error
        }
    }

    /// Host records contain only opaque Core receipts and file-operation intent.
    /// They are not a second shelf/progress database. Unknown persist outcomes
    /// remain visible until the matching protocol's original receipt is known.
    public func pendingImports() async throws -> [ReaderPendingImport] {
        guard !isClosed else { throw ReaderLibraryError.closed }
        return try records().map { ReaderPendingImport(id: $0.reprocessOperationID ?? $0.id, fileName: $0.fileName,
                                               requiresReconciliation: !$0.hasReadableImportReceipt) }
    }

    private func localV2(_ record: HostImportRecord) throws -> HostLocalImportV2 {
        guard record.protocolGeneration == 2, record.requiredCapability == HostLocalImportV2.requiredCapability,
              record.rollbackToken == nil, record.shelfParameters == nil, record.reprocessOperationID == nil,
              record.phase.rawValue.hasPrefix("v2"), let value = record.localV2,
              value.sourceBytes > 0, value.sourceBytes <= UInt64(ReaderImportStagingLease.maximumInputBytes) else {
            throw ReaderLibraryError.invalidResponse("local import v2 journal")
        }
        guard !value.format.isEmpty,
              value.binding != nil || record.phase == .v2Preparing || record.phase == .v2AuthorityAwaiting,
              !value.settled || record.phase == .v2Terminal,
              value.terminalStage == nil || (record.phase == .v2Terminal && value.receipts[value.terminalStage!] != nil) else {
            throw ReaderLibraryError.invalidResponse("local import v2 journal phase proof")
        }
        if let binding = value.binding {
            guard binding.transactionId == record.id, binding.sourceId == "local", binding.bookId == "local:" + record.hash,
                  binding.sourceSha256 == record.hash, binding.sourceBytes == value.sourceBytes,
                  binding.format == value.format, !binding.authorityEpoch.isEmpty, binding.sequence > 0 else {
                throw ReaderLibraryError.invalidResponse("local import v2 original binding")
            }
        }
        return value
    }

    private func finishLocalV2NonAdmission(_ record: HostImportRecord, using lease: ReaderImportStagingLease) throws -> Never {
        let state = try localV2(record)
        guard record.phase == .v2NotAdmitted, state.persistAttempts == 1, !state.persistOutcomeWasUnknown,
              state.receipts.isEmpty, let proof = state.nonAdmission,
              proof.method == "import.local.persist.v2", let rawBinding = try object(proof.parameters)["binding"] as? [String: Any],
              try decode(LocalImportV2Binding.self, JSONSerialization.data(withJSONObject: rawBinding)) == state.binding else {
            throw ReaderLibraryError.invalidResponse("fresh non-admission proof")
        }
        let event = try ReaderCoreEvent(data: proof.event)
        guard event.requestId == proof.requestID, event.type == "error",
              Self.coreErrorDetails(from: event)?["localImportDisposition"] as? String == "nonAdmitted" else {
            throw ReaderLibraryError.invalidResponse("original non-admission envelope")
        }
        if let pending = unresolvedWrites[proof.requestID] {
            guard pending.owner == .importOperation(id: record.id, stage: .persist),
                  case .success(let original)? = pending.terminal, original.rawData == proof.event else {
                throw ReaderLibraryError.invalidResponse("non-admission original transport")
            }
            unresolvedWrites.removeValue(forKey: proof.requestID)
        }
        try retireImportResources(record, authority: .persistRejected, using: lease)
        try removeRecord(record.id); liveImportResources.removeValue(forKey: record.id)
        throw ReaderImportRollbackCompletion(operationId: record.id, originalFailure: record.rejection?.message)
    }

    private func finishLocalV2Undispatched(_ record: HostImportRecord, using lease: ReaderImportStagingLease) throws -> Never {
        let state = try localV2(record)
        guard record.phase == .v2Undispatched, state.receipts.isEmpty, !state.persistOutcomeWasUnknown,
              state.persistAttempts <= 1, !hasPendingImport(record.id) else {
            throw ReaderLibraryError.invalidResponse("original undispatched v2 intent")
        }
        try retireImportResources(record, authority: .notDispatched, using: lease)
        try removeRecord(record.id); liveImportResources.removeValue(forKey: record.id)
        throw ReaderImportRollbackCompletion(operationId: record.id, originalFailure: record.originalFailure)
    }

    private func validateLocalV2Authority(_ authority: LocalImportV2Authority, binding: LocalImportV2Binding? = nil) throws {
        guard authority.protocolGeneration == 2, authority.baseSchemaVersion == 38, authority.extensionSchema == 2,
              !authority.authorityEpoch.isEmpty, authority.activeLimit == 8, authority.activeCount <= authority.activeLimit,
              binding == nil || authority.authorityEpoch == binding?.authorityEpoch else {
            throw ReaderLibraryError.invalidResponse("local import v2 authority")
        }
    }

    private func applyLocalV2Authority(_ data: Data, record: inout HostImportRecord) throws {
        var state = try localV2(record)
        let authority = try decode(LocalImportV2Authority.self, data)
        try validateLocalV2Authority(authority)
        if let binding = state.binding {
            // A late metadata ACK can never re-freeze an admitted sequence.
            try validateLocalV2Authority(authority, binding: binding)
            return
        }
        guard authority.headSequence < UInt64.max, authority.activeCount < authority.activeLimit else {
            throw ReaderLibraryError.operationPending(record.id)
        }
        let binding = LocalImportV2Binding(authorityEpoch: authority.authorityEpoch, sequence: authority.headSequence + 1,
            transactionId: record.id, sourceId: "local", bookId: "local:" + record.hash,
            sourceSha256: record.hash, sourceBytes: state.sourceBytes, format: state.format)
        guard state.binding == nil || state.binding == binding else { throw ReaderLibraryError.invalidResponse("changed original authority") }
        state.binding = binding; record.localV2 = state
        if record.phase == .v2Preparing || record.phase == .v2AuthorityAwaiting { record.phase = .v2PersistAwaiting }
        try writeRecord(record)
    }

    private func bootstrapLocalImportV2(_ record: inout HostImportRecord, onSend: (() -> Void)? = nil) async throws {
        _ = try localV2(record)
        record.phase = .v2AuthorityAwaiting; try writeRecord(record)
        let reply = try await request("import.local.authority.v2", [:], mutation: true,
            owner: .importOperation(id: record.id, stage: .localV2Authority), onSendAttempt: onSend,
            localImportV2Replay: true)
        try applyLocalV2Authority(reply, record: &record)
        try confirmLocalV2Transports(record, stage: .localV2Authority)
    }

    private func localV2Receipt(_ record: HostImportRecord, stage: String) throws -> [String: Any]? {
        guard let data = try localV2(record).receipts[stage] else { return nil }
        return try object(data)
    }

    private func localV2ReceiptError(_ receipt: [String: Any]) throws -> ReaderLibraryError {
        guard receipt["outcome"] as? String == "rejected", let error = receipt["error"] as? [String: Any],
              let code = error["code"] as? String, let message = error["message"] as? String,
              let retryable = error["retryable"] as? Bool else {
            throw ReaderLibraryError.invalidResponse("original local import rejection")
        }
        let details = error["details"] as? [String: Any]
        return .core(code: code, message: message, retryable: retryable, reason: details?["reason"] as? String)
    }

    /// A transport replay/query contains the original business receipts, not
    /// the original wire envelope. Persist every accepted receipt before release.
    private func applyLocalV2Snapshot(_ data: Data, record: inout HostImportRecord, expectedStage: String? = nil) throws {
        var state = try localV2(record)
        let hadTerminal = state.terminalStage != nil
        let snapshot = try object(data)
        guard let rawBinding = snapshot["binding"] as? [String: Any],
              try decode(LocalImportV2Binding.self, JSONSerialization.data(withJSONObject: rawBinding)) == state.binding,
              let phase = snapshot["phase"] as? String, let terminal = snapshot["terminal"] as? Bool,
              let receipts = snapshot["receipts"] as? [[String: Any]] else {
            throw ReaderLibraryError.invalidResponse("original local import snapshot")
        }
        var observed = Set<String>()
        for receipt in receipts {
            guard let stage = receipt["stage"] as? String, ["persist", "publish", "finalize", "rollback"].contains(stage),
                  observed.insert(stage).inserted, let outcome = receipt["outcome"] as? String,
                  let semantic = receipt["semanticFingerprint"] as? String, !semantic.isEmpty,
                  let ack = receipt["ackFingerprint"] as? String, !ack.isEmpty else {
                throw ReaderLibraryError.invalidResponse("original local import receipt")
            }
            if outcome == "rejected" { _ = try localV2ReceiptError(receipt); guard receipt["data"] is NSNull else { throw ReaderLibraryError.invalidResponse("rejected receipt data") } }
            else if outcome != "applied" || !(receipt["error"] is NSNull) || receipt["data"] is NSNull || receipt["data"] == nil {
                throw ReaderLibraryError.invalidResponse("applied local import receipt")
            }
            let raw = try JSONSerialization.data(withJSONObject: receipt, options: .sortedKeys)
            if let original = state.receipts[stage], original != raw { throw ReaderLibraryError.invalidResponse("changed original local import receipt") }
            state.receipts[stage] = raw
        }
        guard expectedStage == nil || observed.contains(expectedStage!) else { throw ReaderLibraryError.invalidResponse("missing requested local import receipt") }
        func outcome(_ stage: String) -> String? {
            guard let raw = state.receipts[stage], let value = try? object(raw) else { return nil }
            return value["outcome"] as? String
        }
        switch phase {
        case "rejected":
            guard terminal, outcome("persist") == "rejected" else { throw ReaderLibraryError.invalidResponse("persist rejection terminal") }
            state.terminalStage = "persist"; record.phase = .v2Terminal
        case "finalized", "rolledBack":
            let stage = phase == "finalized" ? "finalize" : "rollback"
            guard terminal, outcome(stage) == "applied", let raw = state.receipts[stage],
                  let receipt = try object(raw)["data"] as? [String: Any],
                  receipt["transactionId"] as? String == record.id,
                  receipt["bookId"] as? String == "local:" + record.hash, receipt["stage"] as? String == stage else {
                throw ReaderLibraryError.invalidResponse("local import terminal identity")
            }
            state.terminalStage = stage; record.phase = .v2Terminal
        case "published":
            guard !terminal, outcome("persist") == "applied", outcome("publish") == "applied" else { throw ReaderLibraryError.invalidResponse("published local import") }
            record.phase = .v2FinalizeAwaiting
        case "persisted":
            guard !terminal, outcome("persist") == "applied" else { throw ReaderLibraryError.invalidResponse("persisted local import") }
            if outcome("publish") == "rejected" || record.phase == .v2RollbackAwaiting { record.phase = .v2RollbackAwaiting }
            else if record.phase == .v2PublishAwaiting { record.phase = .v2PublishAwaiting }
            else { record.phase = .v2Persisted }
        default: throw ReaderLibraryError.invalidResponse("local import v2 phase")
        }
        // A late, earlier-stage snapshot can add its immutable receipt, never
        // regress a later durable ACK or completed settlement.
        if state.terminalStage != nil { record.phase = .v2Terminal }
        else if outcome("publish") == "applied" { record.phase = .v2FinalizeAwaiting }
        else if outcome("publish") == "rejected" { record.phase = .v2RollbackAwaiting }
        record.localV2 = state
        if let rejected = try localV2Receipt(record, stage: state.terminalStage == "persist" ? "persist" : "publish"), rejected["outcome"] as? String == "rejected" {
            record.rejection = StoredImportRejection(try localV2ReceiptError(rejected))
        }
        try writeRecord(record)
        if !hadTerminal, state.terminalStage != nil {
            try importStagingObserver(.localV2TerminalDurable, operationsURL.appendingPathComponent(record.id + ".json"))
        }
    }

    private func localV2Stage(_ record: HostImportRecord) throws -> (String, ImportMutationStage) {
        switch record.phase {
        case .v2PersistAwaiting: return ("persist", .persist)
        case .v2PublishAwaiting: return ("publish", .shelf)
        case .v2FinalizeAwaiting: return ("finalize", .finalize)
        case .v2RollbackAwaiting: return ("rollback", .rollback)
        default: throw ReaderLibraryError.invalidResponse("local import stage intent")
        }
    }

    private func localV2OwnerStage(_ stage: String) throws -> ImportMutationStage {
        switch stage {
        case "persist": return .persist
        case "publish": return .shelf
        case "finalize": return .finalize
        case "rollback": return .rollback
        default: throw ReaderLibraryError.invalidResponse("local import original stage")
        }
    }

    private func permitsLocalV2Replay(_ method: String, parameters: [String: Any], owner: PendingMutationOwner) throws -> Bool {
        guard case .importOperation(let id, let stage) = owner,
              let record = try records().first(where: { $0.id == id }), record.protocolGeneration == 2 else { return false }
        let state = try localV2(record)
        if stage == .localV2Authority {
            return method == "import.local.authority.v2" && parameters.isEmpty && state.binding == nil
                && (record.phase == .v2Preparing || record.phase == .v2AuthorityAwaiting)
        }
        guard let raw = parameters["binding"] as? [String: Any],
              try decode(LocalImportV2Binding.self, JSONSerialization.data(withJSONObject: raw)) == state.binding else { return false }
        if stage == .localV2Settle {
            guard method == "import.local.settle.v2", record.phase == .v2Terminal,
                  let terminal = state.terminalStage, parameters["terminalStage"] as? String == terminal,
                  let receipt = try localV2Receipt(record, stage: terminal) else { return false }
            return parameters["terminalReceiptFingerprint"] as? String == receipt["ackFingerprint"] as? String
        }
        let (name, expectedOwner) = try localV2Stage(record)
        guard stage == expectedOwner, method == "import.local.\(name).v2" else { return false }
        if name == "persist" {
            guard let preview = parameters["parsed"] as? [String: Any] else { return false }
            return try JSONSerialization.data(withJSONObject: preview, options: .sortedKeys) == state.preview
        }
        return parameters.count == 1
    }

    private func confirmLocalV2Transports(_ record: HostImportRecord, stage: ImportMutationStage) throws {
        let state = try localV2(record)
        guard let binding = state.binding else { throw ReaderLibraryError.invalidResponse("unbound original reply proof") }
        let receipt: Data?
        switch stage {
        case .localV2Authority: receipt = nil
        case .localV2Settle:
            guard state.settled, let terminal = state.terminalStage else { throw ReaderLibraryError.invalidResponse("settlement not durable") }
            receipt = state.receipts[terminal]
        default:
            let name = stage == .shelf ? "publish" : stage == .persist ? "persist" : stage == .finalize ? "finalize" : "rollback"
            guard let original = state.receipts[name] else { throw ReaderLibraryError.invalidResponse("stage ACK not durable") }
            receipt = original
        }
        let proof = LocalImportV2TransportProof(binding: binding, stage: stage, receipt: receipt)
        for id in unresolvedWrites.keys.sorted() {
            guard var pending = unresolvedWrites[id], pending.owner == .importOperation(id: record.id, stage: stage) else { continue }
            guard stage == .localV2Authority || pending.localV2RequestBinding == binding else { throw ReaderLibraryError.invalidResponse("original transport binding") }
            pending.localV2Proof = proof
            if let terminal = pending.terminal {
                try validateLocalV2Transport(terminal, pending: pending, requestID: id)
                unresolvedWrites.removeValue(forKey: id)
            } else { unresolvedWrites[id] = pending }
        }
    }

    private func validateLocalV2Transport(_ reply: Result<ReaderCoreEvent, ReaderCoreClientError>, pending: PendingMutation, requestID: UInt64) throws {
        guard let proof = pending.localV2Proof else { throw ReaderLibraryError.invalidResponse("unconfirmed local import transport") }
        let event = try reply.get()
        guard event.requestId == requestID else { throw ReaderLibraryError.invalidResponse("original local import wire request") }
        if proof.stage != .localV2Authority, pending.localV2RequestBinding != proof.binding { throw ReaderLibraryError.invalidResponse("late original binding") }
        // A transport error is not a business rejection. Its original business
        // outcome was separately obtained and durably stored before this proof.
        if event.type == "error" { return }
        let data = try responseData(reply, method: pending.method, requestID: requestID)
        if proof.stage == .localV2Authority {
            try validateLocalV2Authority(decode(LocalImportV2Authority.self, data), binding: proof.binding)
            return
        }
        let value = try object(data)
        if proof.stage == .localV2Settle {
            guard let authority = value["authority"] as? [String: Any], ["settled", "retired"].contains(value["state"] as? String ?? "") else { throw ReaderLibraryError.invalidResponse("late original settlement") }
            try validateLocalV2Authority(decode(LocalImportV2Authority.self, JSONSerialization.data(withJSONObject: authority)), binding: proof.binding)
            return
        }
        guard let binding = value["binding"] as? [String: Any],
              try decode(LocalImportV2Binding.self, JSONSerialization.data(withJSONObject: binding)) == proof.binding,
              let expected = proof.receipt, let original = try object(expected)["stage"] as? String,
              let receipts = value["receipts"] as? [[String: Any]],
              let receipt = receipts.first(where: { $0["stage"] as? String == original }),
              try JSONSerialization.data(withJSONObject: receipt, options: .sortedKeys) == expected else {
            throw ReaderLibraryError.invalidResponse("late original local import ACK")
        }
    }

    private func localV2Parameters(_ record: HostImportRecord, stage: String) throws -> [String: Any] {
        let state = try localV2(record)
        guard let binding = state.binding else { throw ReaderLibraryError.invalidResponse("missing original local import binding") }
        var params: [String: Any] = ["binding": try object(JSONEncoder().encode(binding))]
        if stage == "persist" {
            params["parsed"] = try object(state.preview)
            // Only the transport locator changes after container relocation.
            let staged = stagingURL.appendingPathComponent(record.stagedName)
            let source = FileManager.default.fileExists(atPath: staged.path) ? staged : stableSource(record.hash)
            let verified = try ReaderImportStagingLease.verifiedFile(at: source)
            guard verified.sha256 == record.hash,
                  try source.resourceValues(forKeys: [.fileSizeKey]).fileSize == Int(state.sourceBytes) else {
                throw ReaderLibraryError.invalidResponse("original local import source locator")
            }
            params["sourcePath"] = source.path
        }
        return params
    }

    private func queryLocalV2Stage(_ record: inout HostImportRecord, stage: String) async throws -> Bool {
        let state = try localV2(record)
        guard let binding = state.binding else { throw ReaderLibraryError.invalidResponse("unbound local import query") }
        var params: [String: Any] = ["binding": try object(JSONEncoder().encode(binding)), "stage": stage]
        if let receipt = try localV2Receipt(record, stage: stage), let fingerprint = receipt["semanticFingerprint"] as? String { params["fingerprint"] = fingerprint }
        else if stage == "persist" { params["parsed"] = try object(state.preview) }
        let response = try object(await request("import.local.query.v2", params))
        guard let rawAuthority = response["authority"] as? [String: Any] else { throw ReaderLibraryError.operationPending(record.id) }
        let authority = try decode(LocalImportV2Authority.self, JSONSerialization.data(withJSONObject: rawAuthority))
        try validateLocalV2Authority(authority, binding: binding)
        guard let queryState = response["state"] as? String else { throw ReaderLibraryError.invalidResponse("local import query state") }
        if queryState == "active", let operation = response["operation"] as? [String: Any] {
            try applyLocalV2Snapshot(JSONSerialization.data(withJSONObject: operation), record: &record)
            if let receipt = response["receipt"] as? [String: Any] {
                guard receipt["stage"] as? String == stage, let original = record.localV2?.receipts[stage],
                      try JSONSerialization.data(withJSONObject: receipt, options: .sortedKeys) == original else {
                    throw ReaderLibraryError.invalidResponse("query original stage receipt")
                }
            }
            if record.localV2?.receipts[stage] != nil {
                try confirmLocalV2Transports(record, stage: localV2OwnerStage(stage))
            }
            return true
        }
        // Absence is not an ACK or proof an old worker exited. Reissuing only
        // this exact binding lets Core atomically arbitrate a pending original.
        return queryState == "absent" && stage == "persist" && authority.headSequence < UInt64.max
            && binding.sequence == authority.headSequence + 1
    }

    private func localV2Result(_ record: HostImportRecord, pending: Bool) throws -> ReaderImportResult {
        guard let persist = try localV2Receipt(record, stage: "persist"), persist["outcome"] as? String == "applied",
              let persisted = persist["data"] as? [String: Any], persisted["kind"] as? String == "localBook",
              let local = persisted["data"] as? [String: Any], let metadata = local["book"] as? [String: Any],
              let published = try localV2Receipt(record, stage: "publish"), published["outcome"] as? String == "applied",
              let add = published["data"] as? [String: Any], let created = add["created"] as? Bool else {
            throw ReaderLibraryError.invalidResponse("original readable local import receipts")
        }
        let book = ReaderBook(bookId: "local:" + record.hash, title: metadata["title"] as? String ?? "",
            author: metadata["author"] as? String ?? "", chapterCount: (local["chapterCount"] as? NSNumber)?.uint32Value ?? 0)
        return ReaderImportResult(book: book, created: created, finalizationPending: pending)
    }

    private func applyLocalV2Settlement(_ data: Data, record: inout HostImportRecord) throws {
        var state = try localV2(record)
        guard record.phase == .v2Terminal, let binding = state.binding, let stage = state.terminalStage,
              let receipt = try localV2Receipt(record, stage: stage), !(receipt["ackFingerprint"] as? String ?? "").isEmpty else {
            throw ReaderLibraryError.invalidResponse("durable local import terminal required")
        }
        let response = try object(data)
        guard let rawAuthority = response["authority"] as? [String: Any],
              ["settled", "retired"].contains(response["state"] as? String ?? "") else { throw ReaderLibraryError.invalidResponse("local import settlement") }
        try validateLocalV2Authority(decode(LocalImportV2Authority.self, JSONSerialization.data(withJSONObject: rawAuthority)), binding: binding)
        state.settled = true; record.localV2 = state; try writeRecord(record)
    }

    private func continueLocalImportV2(_ original: HostImportRecord, using lease: ReaderImportStagingLease, firstPersist: Bool = false) async throws -> ReaderImportResult {
        var record = original
        var directPersist = firstPersist
        var dispatched = Set<String>()
        var persistSendAttemptedThisPass = false
        do {
            for _ in 0..<8 {
                var state = try localV2(record)
                if record.phase == .v2NotAdmitted { try finishLocalV2NonAdmission(record, using: lease) }
                if record.phase == .v2Undispatched { try finishLocalV2Undispatched(record, using: lease) }
                if state.binding == nil {
                    guard dispatched.insert("authority").inserted else { throw ReaderLibraryError.operationPending(record.id) }
                    try await bootstrapLocalImportV2(&record); continue
                }
                if record.phase == .v2Terminal {
                    guard let binding = state.binding, let stage = state.terminalStage,
                          let receipt = try localV2Receipt(record, stage: stage), let fingerprint = receipt["ackFingerprint"] as? String else {
                        throw ReaderLibraryError.invalidResponse("original terminal receipt")
                    }
                    if !state.settled {
                        guard dispatched.insert("settle").inserted else { throw ReaderLibraryError.operationPending(record.id) }
                        // terminalStage + full original receipt are already durable.
                        let reply = try await request("import.local.settle.v2", ["binding": try object(JSONEncoder().encode(binding)),
                            "terminalStage": stage, "terminalReceiptFingerprint": fingerprint], mutation: true,
                            owner: .importOperation(id: record.id, stage: .localV2Settle), localImportV2Replay: true)
                        try applyLocalV2Settlement(reply, record: &record)
                        try confirmLocalV2Transports(record, stage: .localV2Settle)
                        state = try localV2(record)
                    }
                    let authority: ReaderImportStagingLease.RetirementAuthority = stage == "finalize" ? .finalized : stage == "rollback" ? .rolledBack : .persistRejected
                    try retireImportResources(record, authority: authority, using: lease)
                    try removeRecord(record.id); liveImportResources.removeValue(forKey: record.id)
                    if stage != "finalize" { throw ReaderImportRollbackCompletion(operationId: record.id, originalFailure: record.rejection?.message ?? record.originalFailure) }
                    return try localV2Result(record, pending: false)
                }
                if record.phase == .v2Persisted {
                    do {
                        let proof = try importResourceProof(for: record, using: lease)
                        _ = try commitSource(stagingURL.appendingPathComponent(record.stagedName), hash: record.hash) { created in
                            guard let proof else { throw ReaderLibraryError.invalidResponse("missing v2 source ownership") }
                            try registerSourceCreation(created, owner: proof, using: lease)
                        }
                        record.phase = .v2PublishAwaiting
                    } catch {
                        record.originalFailure = String(describing: error); record.phase = .v2RollbackAwaiting
                    }
                    try writeRecord(record); continue
                }
                let (stage, ownerStage) = try localV2Stage(record)
                let queried = !(directPersist && stage == "persist")
                if queried {
                    guard try await queryLocalV2Stage(&record, stage: stage) else { throw ReaderLibraryError.operationPending(record.id) }
                    if record.phase == .v2Terminal || record.phase == .v2Persisted { continue }
                    if try localV2Stage(record).0 != stage { continue }
                }
                directPersist = false
                if let receipt = try localV2Receipt(record, stage: stage) {
                    if receipt["outcome"] as? String == "rejected" { throw ReaderLibraryError.operationPending(record.id) }
                    continue
                }
                guard dispatched.insert(stage).inserted else { throw ReaderLibraryError.operationPending(record.id) }
                let parameters = try localV2Parameters(record, stage: stage)
                if stage == "persist" { record.localV2?.persistAttempts += 1; try writeRecord(record) }
                let reply: Data
                do {
                    reply = try await request("import.local.\(stage).v2", parameters, mutation: true,
                        timeout: stage == "persist" ? 120 : 30, owner: .importOperation(id: record.id, stage: ownerStage),
                        onSendAttempt: { if stage == "persist" { persistSendAttemptedThisPass = true } }, localImportV2Replay: queried)
                } catch let failure as LocalImportV2WireFailure {
                    if firstPersist, !queried, stage == "persist", record.localV2?.persistAttempts == 1,
                       record.localV2?.persistOutcomeWasUnknown == false, failure.disposition == "nonAdmitted" {
                        record.localV2?.nonAdmission = .init(method: failure.method, requestID: failure.requestID,
                            parameters: try JSONSerialization.data(withJSONObject: parameters, options: .sortedKeys), event: failure.event)
                        record.phase = .v2NotAdmitted; record.rejection = StoredImportRejection(failure.underlying)
                        try writeRecord(record)
                        try importStagingObserver(.localV2NonAdmissionDurable, operationsURL.appendingPathComponent(record.id + ".json"))
                        try finishLocalV2NonAdmission(record, using: lease)
                    }
                    if stage == "persist" { record.localV2?.persistOutcomeWasUnknown = true; try writeRecord(record) }
                    throw failure
                } catch {
                    if stage == "persist" { record.localV2?.persistOutcomeWasUnknown = true; try writeRecord(record) }
                    throw error
                }
                try applyLocalV2Snapshot(reply, record: &record, expectedStage: stage)
                try confirmLocalV2Transports(record, stage: ownerStage)
            }
            throw ReaderLibraryError.operationPending(record.id)
        } catch let completed as ReaderImportRollbackCompletion { throw completed }
        catch {
            if firstPersist, !persistSendAttemptedThisPass, record.localV2?.receipts["persist"] == nil {
                record.phase = .v2Undispatched; record.originalFailure = error.localizedDescription
                try writeRecord(record)
                try finishLocalV2Undispatched(record, using: lease)
            }
            if record.hasReadableImportReceipt { return try localV2Result(record, pending: true) }
            throw ReaderLibraryError.operationPending(record.id)
        }
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
        var completedRejections: [ReaderImportRollbackCompletion] = []
        for var record in try records() {
            if record.protocolGeneration != nil {
                guard record.protocolGeneration == 2 else { continue }
                do { _ = try await continueLocalImportV2(record, using: stagingLease) }
                catch let completed as ReaderImportRollbackCompletion { completedRejections.append(completed) }
                catch { /* Preserve the original v2 record and source. */ }
                continue
            }
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
                    completedRejections.append(rollbackCompletion(record))
                    continue
                }
                if record.phase != .finalize {
                    // Only persisted proves the shelf request was not dispatched.
                    // A cold shelfAwaiting journal has no original reply owner;
                    // another add is a new write, never confirmation of that ACK.
                    guard record.phase == .persisted, let shelf = record.shelfParameters else { continue }
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
        if completedRejections.count == 1, let completed = completedRejections.first { throw completed }
        if completedRejections.count > 1 { throw ReaderImportRollbackCompletions(completions: completedRejections) }
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
                         onSendAttempt: (() -> Void)? = nil,
                         onReadPublicationFence: ((Bool) -> Void)? = nil,
                         localImportV2Replay: Bool = false,
                         searchTraceAttempt: ReaderSearchTraceAttempt? = nil,
                         sourceExecutionObservationID: UUID? = nil) async throws -> Data {
        guard !isClosed else { throw ReaderLibraryError.closed }
        if let observationID = sourceExecutionObservationID {
            guard sourceExecutionCloseOwners.isEmpty,
                  sourceExecutionObservations.values.contains(where: { $0.id == observationID }) else { throw CancellationError() }
        }
        if !mutation { try Task.checkCancellation() }
        if mutation {
            guard let owner else { throw ReaderLibraryError.invalidResponse("missing mutation owner") }
            if unresolvedWrites.values.contains(where: { $0.owner == owner && $0.localV2Proof == nil }) {
                var permitted = false
                if localImportV2Replay { permitted = try permitsLocalV2Replay(method, parameters: params, owner: owner) }
                guard permitted else { throw ReaderLibraryError.operationPending(method) }
            }
        }
        requestID += 1
        let id = requestID
        let downloadIdentity = mutation
            ? downloadStatusIdentity(method: method, parameters: params, owner: owner, requestID: id) : nil
        let searchTrace = !mutation && method == "book.search"
            ? searchTraceAttempt?.bind(requestID: id, sourceID: params["sourceId"] as? String) : nil
        hostTransport?.bind(requestID: id, sourceID: params["sourceId"] as? String, searchTrace: searchTrace)
        if mutation, let owner {
            // Reserve the owner before the first suspension, not only after a
            // deadline: actor reentrancy cannot dispatch a competing write.
            var pending = PendingMutation(method: method, owner: owner, terminal: nil, downloadStatusIdentity: downloadIdentity)
            if method.hasPrefix("import.local."), method.hasSuffix(".v2"), let raw = params["binding"] as? [String: Any] {
                pending.localV2RequestBinding = try decode(LocalImportV2Binding.self, JSONSerialization.data(withJSONObject: raw))
            }
            unresolvedWrites[id] = pending
        }
        do {
            onSendAttempt?() // Infallible: after reservation, immediately before the actual send attempt.
            searchTrace?.emit(.coreSendAttempt)
            try client.send(method: method, requestId: id, params: params)
            searchTrace?.emit(.coreSent)
            invalidateDownloadStatus(downloadIdentity, phase: .submitted)
        }
        catch {
            searchTrace?.emit(.coreSendFailed, outcome: .failure(error))
            unresolvedWrites.removeValue(forKey: id)
            hostTransport?.finish(requestID: id)
            throw error
        }
        activeRequests.insert(id)
        var terminalSeen = false
        var cancellationConfirmed = false
        defer {
            searchTrace?.emit(.coreObservationEnded, outcome: Task.isCancelled ? .cancelled : nil)
            activeRequests.remove(id)
            if !mutation {
                if !terminalSeen {
                    client.retireReadRequest(requestId: id)
                    searchTrace?.emit(.coreReadRetired)
                }
                // The transport retains cancellation until any queued/running
                // Host work has actually exited, then releases this read ID.
                hostTransport?.retireRead(requestID: id)
            } else if terminalSeen { hostTransport?.finish(requestID: id) }
            else { startPendingHostPump(requestID: id) }
            if !mutation { onReadPublicationFence?(terminalSeen || cancellationConfirmed) }
            if let searchTrace { startSourceExecutionObservation(searchTrace) }
        }
        let deadline = timing.now() + timeout
        var cancellationSent = false
        while true {
            // A write deadline ends this observer, not the already dispatched
            // Core job. Check before polling so even timeout:0 has one owner.
            if mutation && timing.now() >= deadline { throw ReaderLibraryError.operationPending(method) }
            if !mutation && Task.isCancelled && !cancellationSent {
                try cancelObservedRead(client: client, requestID: id, searchTrace: searchTrace)
                cancellationConfirmed = true
                hostTransport?.cancel(requestID: id)
                cancellationSent = true
            }
            if let result = client.pollEvent(requestId: id) {
                if case .success(let event) = result, event.requestId == id,
                   ["result", "error"].contains(event.type) {
                    let outcome: ReaderSearchTraceEvent.Outcome = event.type == "result" ? .succeeded
                        : event.coreError?.code == "CANCELLED" ? .cancelled : .failed
                    searchTrace?.emit(.coreTerminal, outcome: outcome)
                    invalidateDownloadStatus(downloadIdentity, phase: .terminal)
                }
                if case .success(let event) = result, event.requestId == id,
                   ["result", "error"].contains(event.type) { terminalSeen = true }
                if cancellationSent { throw CancellationError() }
                if case .success(let event) = result, event.type == "host.request" {
                    if mutation {
                        queuePendingHostRequest(event, requestID: id)
                        _ = try await handleQueuedMutationHostRequest(requestID: id, late: false)
                    } else {
                        guard let transport = hostTransport, let native = client as? ReaderCoreClient else {
                            throw ReaderLibraryError.invalidResponse("Host capability is not configured")
                        }
                        do {
                            // Host work is an awaited continuation. A structured
                            // task group would wait for an uncooperative Host
                            // child while leaving its scope, so the expired
                            // read must be released through an unstructured
                            // continuation and cancel the child independently.
                            try await awaitReadHostRequest(event: event, requestID: id,
                                                           deadline: deadline, transport: transport,
                                                           client: native, timing: timing, searchTrace: searchTrace)
                        } catch is ReaderRequestDeadlineExceeded {
                            // Reads are cancellable observations. Stop the
                            // in-flight Host request and Core read together;
                            // unlike a mutation this cannot discard an
                            // unknown durable write.
                            do {
                                try cancelObservedRead(client: client, requestID: id, searchTrace: searchTrace)
                                cancellationConfirmed = true
                            } catch { }
                            hostTransport?.cancel(requestID: id)
                            throw ReaderLibraryError.invalidResponse("timeout: " + method)
                        }
                    }
                    continue
                }
                if case .success(let event) = result, !["result", "error"].contains(event.type) { continue }
                if mutation, let owner, case .success(let event) = result,
                   event.requestId == id, ["result", "error"].contains(event.type) {
                    // Retain successful ACKs until their business owner has
                    // persisted/applied them, including Host journal I/O errors.
                    var pending = unresolvedWrites[id] ?? PendingMutation(method: method, owner: owner, terminal: nil,
                                                                          downloadStatusIdentity: downloadIdentity)
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
                try cancelObservedRead(client: client, requestID: id, searchTrace: searchTrace)
                cancellationConfirmed = true
                hostTransport?.cancel(requestID: id)
                cancellationSent = true
            }
            if timing.now() >= deadline {
                // A timeout after dispatch is not a write rejection. Do not cancel,
                // delete assets, or report rollback without an authoritative receipt.
                if mutation { throw ReaderLibraryError.operationPending(method) }
                do {
                    try cancelObservedRead(client: client, requestID: id, searchTrace: searchTrace)
                    cancellationConfirmed = true
                } catch { }
                hostTransport?.cancel(requestID: id)
                throw ReaderLibraryError.invalidResponse("timeout: " + method)
            }
            await timing.suspend()
        }
    }

    /// The original read's observer can end before Core's accepted execution
    /// scopes do. This optional observer owns only fresh runtime.status replies.
    private func startSourceExecutionObservation(_ trace: ReaderSearchTraceBinding) {
        guard sourceExecutionObservations[trace.requestID] == nil else { return }
        trace.emit(.coreExecutionObservationStarted)
        guard !isClosed, sourceExecutionCloseOwners.isEmpty else {
            trace.emit(.coreExecutionObservationEnded, coreExecutionObservationOutcome: .runtimeClosing)
            return
        }
        guard sourceExecutionObservations.count < 4, trace.recording.admitSourceExecutionObservation() else {
            trace.emit(.coreExecutionObservationEnded, coreExecutionObservationOutcome: .limited)
            return
        }
        let id = UUID(), deadline = timing.now() + 2
        let task = Task(priority: .utility) { [weak self] in
            guard let self else {
                trace.recording.endSourceExecutionObservation()
                trace.emit(.coreExecutionObservationEnded, coreExecutionObservationOutcome: .runtimeClosing)
                return
            }
            await self.observeSourceExecution(trace, id: id, deadline: deadline)
        }
        sourceExecutionObservations[trace.requestID] = .init(id: id, task: task)
    }

    private func observeSourceExecution(_ trace: ReaderSearchTraceBinding, id: UUID, deadline: TimeInterval) async {
        var outcome: ReaderSearchTraceEvent.CoreExecutionObservationOutcome = .limited
        var last: ReaderSearchTraceEvent.CoreExecutionSummary?
        defer {
            if sourceExecutionObservations[trace.requestID]?.id == id { sourceExecutionObservations[trace.requestID] = nil }
            trace.recording.endSourceExecutionObservation()
            trace.emit(.coreExecutionObservationEnded, coreExecutionSummary: last, coreExecutionObservationOutcome: outcome)
        }
        for sample in 0..<20 {
            guard !isClosed, sourceExecutionCloseOwners.isEmpty, !Task.isCancelled else { outcome = .runtimeClosing; return }
            let remaining = deadline - timing.now()
            guard remaining > 0 else { outcome = .timedOut; return }
            guard trace.recording.reserveSourceExecutionSample() else { outcome = .limited; return }
            let data: Data
            do {
                // Neither this request nor its cancellation inherits a search
                // attempt. Only its own request ID is polled by the normal router.
                data = try await ReaderSearchTraceContext.$attempt.withValue(nil) {
                    try await request("runtime.status", ["includeSourceExecution": true],
                                      timeout: min(0.25, remaining), searchTraceAttempt: nil,
                                      sourceExecutionObservationID: id)
                }
            } catch {
                if isClosed || !sourceExecutionCloseOwners.isEmpty || Task.isCancelled { outcome = .runtimeClosing }
                else if timing.now() >= deadline { outcome = .timedOut }
                else { outcome = .failed }
                return
            }
            guard !isClosed, sourceExecutionCloseOwners.isEmpty, !Task.isCancelled else { outcome = .runtimeClosing; return }
            guard timing.now() < deadline else { outcome = .timedOut; return }
            let snapshot: ReaderSourceExecutionStatus
            do { snapshot = try JSONDecoder().decode(ReaderSourceExecutionStatus.self, from: data) }
            catch { outcome = .invalidSnapshot; return }
            guard snapshot.sourceExecution.trackedMethods == ["book.search"] else { outcome = .invalidSnapshot; return }
            let matches = snapshot.sourceExecution.requests.filter { $0.requestId == trace.requestID }
            guard matches.count == 1, let current = matches.first else { outcome = .unknown; return }
            guard current.isCoherent, !current.retired || current.isStrictlyRetired else { outcome = .invalidSnapshot; return }
            trace.emit(.coreExecutionSnapshotObserved, coreExecutionSummary: current)
            if let previous = last, previous.generation != current.generation { outcome = .generationChanged; return }
            last = current
            if current.isStrictlyRetired { outcome = .retired; return }
            if sample == 19 { return }
            let pause = min(0.1, max(0, deadline - timing.now()))
            do { try await sourceExecutionPause(pause) }
            catch { outcome = .runtimeClosing; return }
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
        invalidateDownloadStatus(pending.downloadStatusIdentity, phase: .hostRequest)
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
        do { try await transport.handle(event, client: native, cancellableRead: false) }
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
                            invalidateDownloadStatus(current.downloadStatusIdentity, phase: .terminal)
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
            // Older binding projections expose code/message/retryability but
            // may omit structured details from the typed error dictionary.
            // The raw event is the authoritative wire record for stable
            // categories such as CACHE_MISSING.
            let details = Self.coreErrorDetails(from: event)
            if details?["originalPending"] as? Bool == true { throw ReaderCoreOriginalOperationPending() }
            // Core uses `category` for stable product-level outcomes such as
            // CACHE_MISSING and NETWORK_ENVIRONMENT. Preserve it when a
            // lower-level reason is absent so Host/UI can distinguish a
            // missing offline body from a retryable network failure without
            // parsing localized error messages.
            let reason = details?["reason"] as? String ?? details?["category"] as? String
            let failure = ReaderLibraryError.core(code: error?.code ?? "INTERNAL", message: error?.message ?? "",
                retryable: error?.retryable ?? false, reason: reason)
            if ["authority", "persist", "publish", "finalize", "rollback", "query", "settle"].contains(where: { method == "import.local.\($0).v2" }),
               let disposition = details?["localImportDisposition"] as? String, ["nonAdmitted", "unknown"].contains(disposition) {
                throw LocalImportV2WireFailure(method: method, requestID: requestID, disposition: disposition,
                    event: event.rawData, underlying: failure)
            }
            throw failure
        }
        guard event.type == "result", let data = event.data else { throw ReaderLibraryError.invalidResponse(method) }
        return try JSONSerialization.data(withJSONObject: data)
    }

    private static func coreErrorDetails(from event: ReaderCoreEvent) -> [String: Any]? {
        if let details = event.error?["details"] as? [String: Any] { return details }
        guard let object = try? JSONSerialization.jsonObject(with: event.rawData) as? [String: Any] else { return nil }
        if let details = object["details"] as? [String: Any] { return details }
        return (object["error"] as? [String: Any])?["details"] as? [String: Any]
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
            if pending.localV2Proof != nil { return false }
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
                    invalidateDownloadStatus(pending.downloadStatusIdentity, phase: .terminal)
                    hostTransport?.finish(requestID: id)
                }
            }
            if pending.terminal == nil { startPendingHostPump(requestID: id) }
            if pending.localV2Proof != nil {
                if let terminal = pending.terminal {
                    try validateLocalV2Transport(terminal, pending: pending, requestID: id)
                    unresolvedWrites.removeValue(forKey: id)
                }
                continue
            }
            guard case .importOperation(let recordID, let stage) = pending.owner,
                  let terminal = pending.terminal,
                  var record = try records().first(where: { $0.id == recordID }) else { continue }
            if record.protocolGeneration != nil {
                guard record.protocolGeneration == 2 else { continue }
                do {
                    let data = try responseData(terminal, method: pending.method, requestID: id)
                    switch stage {
                    case .localV2Authority: try applyLocalV2Authority(data, record: &record)
                    case .localV2Settle: try applyLocalV2Settlement(data, record: &record)
                    case .persist, .shelf, .finalize, .rollback:
                        let name = stage == .shelf ? "publish" : stage == .persist ? "persist" : stage == .finalize ? "finalize" : "rollback"
                        try applyLocalV2Snapshot(data, record: &record, expectedStage: name)
                    }
                    try confirmLocalV2Transports(record, stage: stage)
                } catch {
                    if case .success(let event) = terminal, event.requestId == id, event.type == "error" {
                        // This envelope ended, but it is not a stored business
                        // rejection. Keep the journal and query its old binding.
                        unresolvedWrites.removeValue(forKey: id)
                    } else { throw error }
                }
                continue
            }
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
            case .localV2Authority, .localV2Settle:
                throw ReaderLibraryError.invalidResponse("v2 transport cannot enter legacy recovery")
            }
            unresolvedWrites.removeValue(forKey: id)
            if stage == .rollback { throw rollbackCompletion(record) }
        }
    }

    private func rollbackCompletion(_ record: HostImportRecord) -> ReaderImportRollbackCompletion {
        let failure = record.rejection?.error.localizedDescription ?? record.originalFailure
        return ReaderImportRollbackCompletion(operationId: record.id, originalFailure: failure)
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
        let proof = try liveImportResources[record.id] ?? lease.owner(for: record.id) ?? record.localV2?.resourceOwner
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

private struct ReaderSourceExecutionStatus: Decodable {
    struct Snapshot: Decodable {
        let trackedMethods: [String]
        let requests: [ReaderSearchTraceEvent.CoreExecutionSummary]
        let evictedRetiredGenerationCount: UInt64
        let untrackedGenerationCount: UInt64
    }
    let sourceExecution: Snapshot
}

private struct HostImportRecord: Codable {
    enum Phase: String, Codable {
        case preparing, persistAwaiting, persisted, shelfAwaiting, finalize, rollback, completed, rejected
        // An older Host must fail decoding these phases, never recover them as v1.
        case v2Preparing, v2AuthorityAwaiting, v2PersistAwaiting, v2Persisted, v2PublishAwaiting
        case v2FinalizeAwaiting, v2RollbackAwaiting, v2Terminal, v2NotAdmitted, v2Undispatched
    }
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
    var protocolGeneration: UInt32? = nil
    var requiredCapability: String? = nil
    var localV2: HostLocalImportV2? = nil

    var hasReadableImportReceipt: Bool {
        if protocolGeneration == nil { return phase == .finalize }
        guard protocolGeneration == 2, requiredCapability == HostLocalImportV2.requiredCapability,
              rollbackToken == nil, shelfParameters == nil, let state = localV2, let binding = state.binding,
              binding.transactionId == id, binding.sourceId == "local", binding.bookId == "local:" + hash,
              binding.sourceSha256 == hash, binding.sourceBytes == state.sourceBytes, binding.format == state.format,
              phase == .v2FinalizeAwaiting || (phase == .v2Terminal && state.terminalStage == "finalize") else { return false }
        for stage in ["finalize", "rollback"] {
            if let raw = state.receipts[stage], let receipt = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
               receipt["outcome"] as? String == "rejected" { return false }
        }
        guard let receipt = state.receipts["publish"],
              let value = try? JSONSerialization.jsonObject(with: receipt) as? [String: Any] else { return false }
        return value["stage"] as? String == "publish" && value["outcome"] as? String == "applied"
            && !(value["semanticFingerprint"] as? String ?? "").isEmpty && !(value["ackFingerprint"] as? String ?? "").isEmpty
            && value["error"] is NSNull && (value["data"] as? [String: Any])?["created"] is Bool
    }
}

private struct HostLocalImportV2: Codable {
    static let requiredCapability = "import.local.receipts.v2"
    let preview: Data
    let sourceBytes: UInt64
    let format: String
    var binding: LocalImportV2Binding? = nil
    var receipts: [String: Data] = [:]
    var terminalStage: String? = nil
    var settled = false
    var resourceOwner: ReaderImportStagingOwner? = nil
    var persistAttempts = 0
    var persistOutcomeWasUnknown = false
    var nonAdmission: LocalImportV2NonAdmission? = nil
}

private struct LocalImportV2NonAdmission: Codable {
    let method: String
    let requestID: UInt64
    let parameters: Data
    let event: Data
}

private struct LocalImportV2WireFailure: Error, LocalizedError {
    let method: String
    let requestID: UInt64
    let disposition: String
    let event: Data
    let underlying: ReaderLibraryError
    var errorDescription: String? { underlying.localizedDescription }
}

private struct LocalImportV2Authority: Codable {
    let protocolGeneration: UInt32
    let baseSchemaVersion: UInt32
    let extensionSchema: UInt32
    let authorityEpoch: String
    let headSequence: UInt64
    let activeCount: UInt32
    let activeLimit: UInt32
}

fileprivate struct LocalImportV2Binding: Codable, Equatable {
    let authorityEpoch: String
    let sequence: UInt64
    let transactionId: String
    let sourceId: String
    let bookId: String
    let sourceSha256: String
    let sourceBytes: UInt64
    let format: String
}

/// The original import has an authoritative compensation ACK. This is a
/// confirmed import failure, not a claim that the earlier mutation never ran.
public struct ReaderImportRollbackCompletion: Error, Sendable, LocalizedError {
    public let operationId: String
    public let originalFailure: String?
    public var errorDescription: String? { originalFailure }
}

/// Recovery may settle more than one original import while cleanup-only
/// records remain. Keep every Core operation identity so the Host can settle
/// each presentation item independently after a restart.
public struct ReaderImportRollbackCompletions: Error, Sendable, LocalizedError {
    public let completions: [ReaderImportRollbackCompletion]
    public init(completions: [ReaderImportRollbackCompletion]) { self.completions = completions }
    public var errorDescription: String? {
        completions.compactMap(\.errorDescription).joined(separator: "；")
    }
}

enum ImportMutationStage: Hashable { case persist, shelf, finalize, rollback, localV2Authority, localV2Settle }
fileprivate struct LocalImportV2TransportProof {
    let binding: LocalImportV2Binding
    let stage: ImportMutationStage
    let receipt: Data?
}
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
    let downloadStatusIdentity: ReaderDownloadStatusInvalidation?
    var queuedHostRequests: [ReaderCoreEvent] = []
    var seenHostOperations: Set<UInt64> = []
    var executingHostRequest: ReaderCoreEvent?
    var uncertainHostRequests: [ReaderCoreEvent] = []
    var lateHostHandledCount: Int = 0
    fileprivate var localV2RequestBinding: LocalImportV2Binding? = nil
    fileprivate var localV2Proof: LocalImportV2TransportProof? = nil
}
private struct ReaderRequestDeadlineExceeded: Error {}

/// Observes the actual Core cancellation call. Returning from this call is
/// deliberately separate from its terminal event and from worker termination.
private func cancelObservedRead(client: any ReaderCoreEventClient, requestID: UInt64,
                                searchTrace: ReaderSearchTraceBinding?) throws {
    searchTrace?.emit(.coreCancelAttempted)
    do {
        try client.cancel(requestId: requestID)
        searchTrace?.emit(.coreCancelReturned, outcome: .succeeded)
    } catch {
        searchTrace?.emit(.coreCancelReturned, outcome: .failure(error))
        throw error
    }
}

private final class ReaderReadHostDeadlineGate: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private var continuation: CheckedContinuation<Void, Error>?
    private var hostTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private let cancelHostAction: @Sendable () -> Void

    init(cancelHost: @escaping @Sendable () -> Void) { self.cancelHostAction = cancelHost }

    func install(_ continuation: CheckedContinuation<Void, Error>) {
        let cancelled: Bool
        lock.lock()
        cancelled = finished
        if !cancelled { self.continuation = continuation }
        lock.unlock()
        if cancelled { continuation.resume(throwing: CancellationError()) }
    }

    func install(hostTask: Task<Void, Never>, timerTask: Task<Void, Never>) {
        let cancel: Bool
        lock.lock()
        cancel = finished
        if !cancel {
            self.hostTask = hostTask
            self.timerTask = timerTask
        }
        lock.unlock()
        if cancel {
            hostTask.cancel()
            timerTask.cancel()
        }
    }

    func hostFinished(_ result: Result<Void, Error>) { finish(result, cancelHost: false) }
    func timedOut() { finish(.failure(ReaderRequestDeadlineExceeded()), cancelHost: true) }
    func cancelled() { finish(.failure(CancellationError()), cancelHost: true) }

    private func finish(_ result: Result<Void, Error>, cancelHost: Bool) {
        let continuation: CheckedContinuation<Void, Error>?
        let hostTask: Task<Void, Never>?
        let timerTask: Task<Void, Never>?
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        continuation = self.continuation
        hostTask = self.hostTask
        timerTask = self.timerTask
        self.continuation = nil
        self.hostTask = nil
        self.timerTask = nil
        lock.unlock()

        if cancelHost {
            cancelHostAction()
            hostTask?.cancel()
        }
        timerTask?.cancel()
        continuation?.resume(with: result)
    }
}

private func awaitReadHostRequest(event: ReaderCoreEvent, requestID: UInt64,
                                 deadline: TimeInterval, transport: ReaderIOSHostTransport,
                                 client: ReaderCoreClient, timing: ReaderRequestTiming,
                                 searchTrace: ReaderSearchTraceBinding? = nil) async throws {
    let gate = ReaderReadHostDeadlineGate { transport.cancel(requestID: requestID) }
    do {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                gate.install(continuation)
                let hostTask = Task {
                    do {
                        try await transport.handle(event, client: client, cancellableRead: true, searchTrace: searchTrace)
                        gate.hostFinished(.success(()))
                    } catch {
                        gate.hostFinished(.failure(error))
                    }
                }
                let timerTask = Task {
                    while !Task.isCancelled && timing.now() < deadline { await timing.suspend() }
                    guard !Task.isCancelled else { return }
                    gate.timedOut()
                }
                gate.install(hostTask: hostTask, timerTask: timerTask)
            }
        }, onCancel: { gate.cancelled() })
    } catch is CancellationError {
        // The cancellation handler releases the Host worker, but the Core
        // read also needs its own cancellation receipt before this observer
        // leaves. Deadline handling already performs this in its caller.
        try? cancelObservedRead(client: client, requestID: requestID, searchTrace: searchTrace)
        throw CancellationError()
    }
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
