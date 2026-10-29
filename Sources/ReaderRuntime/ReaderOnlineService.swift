import Foundation
#if DEBUG
import CryptoKit
#endif
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif

extension ReaderLibraryService: ReaderOnlineServing {
    public func validateSources(_ data: Data) async throws -> [ReaderSourceImportItem] {
        try ReaderSourcePackageInput.validateJSONBytes(data)
        let value = try JSONSerialization.jsonObject(with: data)
        let definitions: [[String: Any]]
        if let array = value as? [[String: Any]] { definitions = array }
        else if let single = value as? [String: Any] { definitions = [single] }
        else { throw ReaderLibraryError.invalidResponse("source JSON shape") }
        guard !definitions.isEmpty, definitions.count <= 5000 else { throw ReaderLibraryError.invalidResponse("source package size") }
        var results: [ReaderSourceImportItem] = []
        for (index, definition) in definitions.enumerated() {
            try Task.checkCancellation()
            let name = definition["bookSourceName"] as? String ?? "第 \(index + 1) 项"
            do {
                let identity = (definition["bookSourceUrl"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard identity != "local" else { throw ReaderLibraryError.core(code: "INVALID_PARAMS", message: "该标识保留给本地书籍", retryable: false, reason: nil) }
                _ = try await coreRead("import.parse", ["kind": "bookSource", "input": ["sourceId": identity, "bookSource": definition]])
                results.append(.init(id: String(index), name: name, succeeded: true, message: "结构校验通过，尚未保存"))
            } catch { results.append(.init(id: String(index), name: name, succeeded: false, message: error.localizedDescription)) }
        }
        return results
    }
    public func onlineSources() async throws -> [ReaderOnlineSource] {
        let page = try object(await coreRead("source.list", [:]))
        return try (page["sources"] as? [[String: Any]] ?? []).map { row in
            guard let identity = row["sourceId"] as? String, let definition = row["bookSource"] as? [String: Any] else { throw ReaderLibraryError.invalidResponse("source identity") }
            return ReaderOnlineSource(sourceId: identity, name: row["name"] as? String ?? identity,
                baseURL: row["baseUrl"] as? String ?? "", enabled: row["enabled"] as? Bool ?? false,
                version: row["sourceVersion"] as? String ?? "", group: definition["bookSourceGroup"] as? String ?? "",
                definition: try JSONSerialization.data(withJSONObject: definition, options: [.prettyPrinted, .sortedKeys]))
        }
    }
    public func importSources(_ data: Data, operationID: String) async throws -> [ReaderSourceImportItem] {
        try ReaderSourcePackageInput.validateJSONBytes(data)
        let value = try JSONSerialization.jsonObject(with: data)
        let definitions: [[String: Any]]
        if let list = value as? [[String: Any]] { definitions = list }
        else if let single = value as? [String: Any] { definitions = [single] }
        else { throw ReaderLibraryError.invalidResponse("source JSON must be an object or array") }
        guard !definitions.isEmpty, definitions.count <= 5000 else { throw ReaderLibraryError.invalidResponse("source package size") }
        var results: [ReaderSourceImportItem] = []
        for (index, definition) in definitions.enumerated() {
            try Task.checkCancellation()
            let id = operationID + ":" + String(index)
            let name = definition["bookSourceName"] as? String ?? "第 \(index + 1) 项"
            guard let rawIdentity = definition["bookSourceUrl"] as? String, !rawIdentity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                results.append(.init(id: id, name: name, succeeded: false, message: "缺少书源地址")); continue
            }
            let sourceID = rawIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
            guard sourceID != "local" else { results.append(.init(id: id, name: name, succeeded: false, message: "该标识保留给本地书籍")); continue }
            do {
                let receipt = try object(await rulesMutation("source.import", ["sourceId": sourceID, "bookSource": definition], operationID: id))
                guard receipt["imported"] as? Bool == true, receipt["sourceId"] as? String == sourceID else { throw ReaderLibraryError.invalidResponse("source import receipt") }
                try await finishCoreOperation(id)
                results.append(.init(id: id, name: name, succeeded: true, message: "已保存"))
            } catch ReaderLibraryError.operationPending { throw ReaderLibraryError.operationPending(id) }
            catch { results.append(.init(id: id, name: name, succeeded: false, message: error.localizedDescription)) }
        }
        return results
    }
    public func exportSources(_ identities: [String]?) async throws -> Data {
        var params: [String: Any] = ["format": "json"]
        if let identities { params["sourceIds"] = identities }
        let result = try object(await coreRead("source.export", params))
        guard let json = result["data"] as? String else { throw ReaderLibraryError.invalidResponse("source export") }
        return Data(json.utf8)
    }
    public func updateSource(_ sourceID: String, enabled: Bool, operationID: String) async throws {
        let response = try object(await rulesMutation("source.update", ["sourceId": sourceID, "enabled": enabled], operationID: operationID))
        guard let source = response["source"] as? [String: Any], source["sourceId"] as? String == sourceID, source["enabled"] as? Bool == enabled else { throw ReaderLibraryError.invalidResponse("source update receipt") }
        try await finishCoreOperation(operationID)
    }
    public func deleteSource(_ sourceID: String, operationID: String) async throws {
        _ = try await rulesMutation("source.delete", ["sourceIds": [sourceID]], operationID: operationID)
        try await finishCoreOperation(operationID)
    }
    public func searchSource(_ sourceID: String, keyword: String, page: Int = 1) async throws -> ReaderSourceSearchResult {
        let start = ContinuousClock.now
        let attempt = ReaderSearchTraceContext.attempt
        let data = try await ReaderSearchTraceContext.$attempt.withValue(nil) {
            try await request("book.search", ["sourceId": sourceID, "keyword": keyword, "page": max(1, page)],
                              searchTraceAttempt: attempt)
        }
        let result = try object(data)
        guard result["sourceId"] as? String == sourceID else { throw ReaderLibraryError.invalidResponse("search source identity") }
        let books = try (result["books"] as? [[String: Any]] ?? []).map { row -> ReaderOnlineCandidate in
            guard let bookID = row["bookId"] as? String, let title = row["title"] as? String else { throw ReaderLibraryError.invalidResponse("search book identity") }
            return .init(sourceId: sourceID, bookId: bookID, title: title, author: row["author"] as? String ?? "", coverUrl: row["coverUrl"] as? String, coreBook: try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]))
        }
        let elapsed = start.duration(to: .now).components
        let timing = try result["searchTiming"].map { try JSONSerialization.data(withJSONObject: $0) }
        return .init(sourceId: sourceID, books: books, elapsedMilliseconds: Int(elapsed.seconds * 1000 + elapsed.attoseconds / 1_000_000_000_000_000), timing: timing)
    }
    public func onlineDetail(_ candidate: ReaderOnlineCandidate) async throws -> ReaderOnlineDetail {
        let base: [String: Any]
        if let raw = candidate.coreBook {
            base = try object(raw)
            guard base["bookId"] as? String == candidate.bookId else { throw ReaderLibraryError.invalidResponse("candidate payload identity") }
        } else { base = ["bookId": candidate.bookId, "title": candidate.title, "author": candidate.author] }
        let response = try object(await coreRead("book.detail", ["sourceId": candidate.sourceId, "book": base, "bookUrl": candidate.bookId]))
        guard response["contentKind"] as? String == "text" else {
            throw ReaderLibraryError.core(code: "INVALID_PARAMS", message: "当前版本仅开放在线文字书阅读", retryable: false, reason: "unsupported_content_kind")
        }
        guard let row = response["book"] as? [String: Any], row["bookId"] as? String == candidate.bookId else { throw ReaderLibraryError.invalidResponse("book detail identity") }
        var tocParams: [String: Any] = ["sourceId": candidate.sourceId, "bookId": candidate.bookId, "variables": response["variables"] as? [String: String] ?? [:]]
        if let tocURL = response["tocUrl"] { tocParams["tocUrl"] = tocURL }
        let toc = try object(await coreRead("book.toc", tocParams))
        let chapters = try onlineChapterRows(toc)
        let readable = (toc["readableChapterIndexes"] as? [UInt32])?.first ?? chapters.first?.index
        guard let readable else { throw ReaderLibraryError.invalidResponse("no readable chapters") }
        let book = ReaderBook(sourceId: candidate.sourceId, bookId: candidate.bookId,
            title: row["title"] as? String ?? candidate.title, author: row["author"] as? String ?? candidate.author,
            chapterCount: UInt32(chapters.count), coverUrl: row["coverUrl"] as? String,
            intro: row["intro"] as? String, kind: row["kind"] as? String)
        return .init(book: book, chapters: chapters, firstReadableIndex: readable)
    }
    public func addOnlineBook(_ detail: ReaderOnlineDetail, chapterIndex: UInt32, operationID: String) async throws -> ReaderBook {
        try await beginOnlineAdmission(detail, chapterIndex: chapterIndex, operationID: operationID)
    }
    public func refreshOnlineCatalog(for book: ReaderBook) async throws -> ReaderOnlineDetail {
        guard book.sourceId != "local" else { throw ReaderLibraryError.unsupportedFile }
        let stored = try object(await coreRead("search-book.get", ["origin": book.sourceId, "bookUrl": book.bookId]))
        guard let row = stored["book"] as? [String: Any], row["bookUrl"] as? String == book.bookId,
              row["origin"] as? String == book.sourceId else { throw ReaderLibraryError.invalidResponse("stored online book identity") }
        guard let tocURL = row["tocUrl"] as? String, !tocURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            _ = try await onlineDetail(.init(sourceId: book.sourceId, bookId: book.bookId, title: book.title, author: book.author, coverUrl: book.coverUrl))
            return try await installedOnlineDetail(book)
        }
        let status = try await readerDownloadStatus(book)
        // A real Core-retained TOC URL forces network refresh. An omitted URL
        // would intentionally return the old cached catalog in this contract.
        let toc = try object(await coreRead("book.toc", ["sourceId": book.sourceId, "bookId": book.bookId,
            "tocUrl": tocURL, "variables": status.continuationVariables ?? [:]]))
        guard toc["sourceId"] as? String == book.sourceId, toc["bookId"] as? String == book.bookId else { throw ReaderLibraryError.invalidResponse("online catalog identity") }
        guard toc["catalogDeferredReason"] == nil else { throw ReaderLibraryError.busy }
        return try await installedOnlineDetail(book)
    }
    private func installedOnlineDetail(_ book: ReaderBook) async throws -> ReaderOnlineDetail {
        // Another refresh may have published a newer catalog while this
        // response was in flight. Only the installed Core projection is used.
        let chapters = try await onlineChapters(for: book)
        guard let first = chapters.first?.index else { throw ReaderLibraryError.invalidResponse("no readable chapters") }
        let projected = try await listBooks().first(where: { $0.id == book.id }) ?? book
        return .init(book: projected, chapters: chapters, firstReadableIndex: first)
    }
    func onlineChapters(for book: ReaderBook) async throws -> [ReaderChapter] {
        // Installed Core catalog is sufficient offline. Refresh is an explicit action.
        let result = try object(await coreRead("cache.book.status", ["sourceId": book.sourceId, "bookId": book.bookId]))
        let rows = result["chapters"] as? [[String: Any]] ?? []
        guard !rows.isEmpty else { throw ReaderLibraryError.invalidResponse("no installed online catalog") }
        return rows.compactMap { row in
            guard row["navigable"] as? Bool != false, let index = (row["chapterIndex"] as? NSNumber)?.uint32Value else { return nil }
            return ReaderChapter(index: index, title: row["title"] as? String ?? "", url: row["url"] as? String ?? "",
                level: (row["level"] as? NSNumber)?.uint32Value, displayTitle: row["displayTitle"] as? String,
                isVip: row["isVip"] as? Bool, isPay: row["isPay"] as? Bool, contextTitle: row["contextTitle"] as? String)
        }
    }
    func onlineContent(for book: ReaderBook, chapterIndex: UInt32, directoryTargetProof: [String: Any]? = nil, preparationRevision: Int64? = nil) async throws -> ReaderChapterContent {
        let result = try await onlineContentResult(for: book, chapterIndex: chapterIndex,
            directoryTargetProof: directoryTargetProof, preparationRevision: preparationRevision)
        return try onlineContentProjection(result, for: book, chapterIndex: chapterIndex)
    }
    /// All indexed reads and explicit refreshes use the same installed chapter
    /// identity and continuation variables. Cache-only reconciliation never
    /// substitutes a fresh source execution for a missing canonical body.
    func onlineContentResult(for book: ReaderBook, chapterIndex: UInt32,
                             directoryTargetProof: [String: Any]? = nil, preparationRevision: Int64? = nil,
                             cacheOnly: Bool = false, forceRefresh: Bool = false,
                             upgradeCachedContent: Bool = false, positionContext: [String: Any]? = nil,
                             onSendAttempt: (() -> Void)? = nil,
                             onReadPublicationFence: ((Bool) -> Void)? = nil) async throws -> [String: Any] {
        let status = try await readerDownloadStatus(book)
        if cacheOnly || forceRefresh || upgradeCachedContent {
            let identity = ReaderOnlineContentRefreshIdentity(sourceId: book.sourceId, bookId: book.bookId,
                chapterIndex: chapterIndex)
            guard !unfencedOnlineContentRefreshes.contains(identity) else { throw ReaderLibraryError.busy }
        }
        guard let chapter = status.chapters.first(where: { $0.chapterIndex == chapterIndex }), !chapter.url.isEmpty else { throw ReaderLibraryError.invalidPosition }
        if let url = directoryTargetProof?["url"] as? String, url != chapter.url { throw ReaderLibraryError.invalidPosition }
        var variables = status.continuationVariables ?? [:]
        variables.merge(chapter.variables) { _, chapterValue in chapterValue }
        var params: [String: Any] = ["sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": chapterIndex,
            "chapterTitle": chapter.title, "chapterUrl": chapter.url, "variables": variables]
        if let directoryTargetProof { params["directoryTargetProof"] = directoryTargetProof }
        if let preparationRevision { params["preparationRevision"] = preparationRevision }
        if cacheOnly { params["cacheOnly"] = true }
        if forceRefresh { params["forceRefresh"] = true }
        if upgradeCachedContent { params["upgradeCachedContent"] = true }
        if let positionContext { params["positionContext"] = positionContext }
        return try object(await coreRead("chapter.content", params, onSendAttempt: onSendAttempt,
            onReadPublicationFence: onReadPublicationFence))
    }
    func onlineContentProjection(_ result: [String: Any], for book: ReaderBook, chapterIndex: UInt32) throws -> ReaderChapterContent {
        guard result["sourceId"] as? String == book.sourceId, result["bookId"] as? String == book.bookId,
              result["content"] is String else { throw ReaderLibraryError.invalidResponse("online content identity") }
        var projected = result
        // chapter.content identifies the chapter through its exact request;
        // its result DTO intentionally has no chapterIndex field.
        projected["chapterIndex"] = chapterIndex
        if projected["chapterTitle"] == nil { projected["chapterTitle"] = "" }
        return try decode(ReaderChapterContent.self, JSONSerialization.data(withJSONObject: projected))
    }
    private func onlineChapterRows(_ result: [String: Any]) throws -> [ReaderChapter] {
        let rows = result["toc"] as? [[String: Any]] ?? []
        return try rows.compactMap { row in
            guard row["navigable"] as? Bool != false else { return nil }
            return try decode(ReaderChapter.self, JSONSerialization.data(withJSONObject: row))
        }
    }
    public func onlineDiagnostic(_ sourceID: String, keyword: String) async throws -> Data {
        try await coreRead("source.check.run", ["sourceIds": [sourceID], "keyword": keyword, "timeoutMs": 60000, "levels": ["L1", "L2", "L3", "L4", "L5"], "reportVersion": 2], timeout: 65)
    }
    public func onlineFetch(_ url: URL) async throws -> Data {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), let transport = hostTransport else { throw ReaderLibraryError.invalidResponse("source URL") }
        let response = try await transport.fetchPackage(at: url)
        guard (200..<300).contains(response.status) else { throw ReaderLibraryError.core(code: "INTERNAL", message: "来源地址返回 HTTP \(response.status)", retryable: true, reason: nil) }
        return Data(response.body.utf8)
    }
    public func onlineCommand(_ method: String, parameters: Data, operationID: String?) async throws -> Data {
        let reads: Set<String> = ["cache.book.status", "cache.storage.summary", "rule-sub.list", "rule-sub.get", "source.debug", "source.switch.pending.list", "source.switch.transaction.query"]
        let writes: Set<String> = ["cache.book.prefetch", "cache.download.pause", "cache.download.resume", "cache.download.cancel", "cache.clear", "cache.storage.cleanup"]
        let params = try object(parameters)
        if reads.contains(method), operationID == nil { return try await coreRead(method, params, timeout: 60) }
        guard writes.contains(method), let operationID else { throw ReaderLibraryError.invalidResponse("online command lane") }
        let result = try await coreMutation(method, params, operationID: operationID, scope: "online:" + method)
        // Original terminal ACK is retained by the Host journal after consumption.
        try await finishCoreOperation(operationID)
        return result
    }
    public func prepareLogin(_ sourceID: String) async throws -> [HTTPCookie] {
        guard let hostTransport else { throw ReaderLibraryError.invalidResponse("login transport") }
        return try hostTransport.cookies(sourceID: sourceID)
    }
    public func completeLogin(_ sourceID: String, cookies: [HTTPCookie], originalCookies: [HTTPCookie]) async throws {
        guard let hostTransport else { throw ReaderLibraryError.invalidResponse("login transport") }
        try hostTransport.commitCookieChanges(sourceID: sourceID, originalCookies: originalCookies, updatedCookies: cookies)
    }
}

/// Opt-in observation only. The sink receives fixed enums and scalar values;
/// source URLs, search text, books, response data and credentials are excluded.
/// A sink may be called concurrently. It must be nonblocking and must not call
/// back into the observed owner. No stage asserts origin freshness or acceptance.
typealias ReaderSearchTraceSink = @Sendable (ReaderSearchTraceEvent) -> Void

struct ReaderSearchTraceEvent: Codable, Sendable {
    enum Stage: String, Codable, Sendable {
        case generationStarted, generationStopped, generationFinished
        case sourceAttemptStarted, sourceAttemptFinished, sourceResultApplied, sourceResultDiscarded
        case coreSendAttempt, coreSent, coreSendFailed, coreTerminal, coreObservationEnded
        case coreCancelAttempted, coreCancelReturned, coreReadRetired
        case coreExecutionObservationStarted, coreExecutionSnapshotObserved, coreExecutionObservationEnded
        case hostOperationStarted, hostOperationFinished, hostOperationRejected
        case hostCancellationRequested, hostTransportDrained
        case httpTaskResumeAttempted, httpTaskCompleted, httpTaskMetricsCollected, httpTaskMetricsUnavailable
        case httpTaskCancelAttempted, httpTaskCancelReturned, httpSessionInvalidated
        case webViewRunStarted, webViewNavigationStarted, webViewNavigationFinished, webViewRunCompleted
        case traceLimitReached
    }
    enum Outcome: String, Codable, Sendable {
        case succeeded, failed, cancelled, timedOut, superseded, presentationRetired

        static func failure(_ error: Error) -> Self {
            if error is CancellationError { return .cancelled }
            let value = error as NSError
            if value.domain == NSURLErrorDomain {
                if value.code == URLError.cancelled.rawValue { return .cancelled }
                if value.code == URLError.timedOut.rawValue { return .timedOut }
            }
            return .failed
        }
    }
    enum Transport: String, Codable, Sendable { case http, webView, other }
    struct HTTPFetchSummary: Codable, Sendable {
        let transactionCount: Int
        let networkLoadCount: Int
        let localCacheCount: Int
        let serverPushCount: Int
        let unknownCount: Int
    }
    /// Registered Host work only. Zero does not prove a Core worker has exited
    /// or a URLSession has finished delivering its invalidation callback.
    struct HostWorkSummary: Codable, Sendable {
        let activeHandlerCount: Int
        let jobCount: Int
        let cookieOperationCount: Int
        var isEmpty: Bool { activeHandlerCount == 0 && jobCount == 0 && cookieOperationCount == 0 }
    }
    enum CoreExecutionObservationOutcome: String, Codable, Sendable {
        case retired, unknown, generationChanged, invalidSnapshot, failed, timedOut, limited, runtimeClosing
    }
    /// A Core-owned request generation, not a URLSession or socket state.
    struct CoreExecutionSummary: Codable, Sendable {
        let requestId: UInt64
        let generation: UInt64
        let queuedWorkItemCount: UInt64
        let runningWorkItemCount: UInt64
        let continuationScopeCount: UInt64
        let callbackScopeCount: UInt64
        let retainedOwnerCount: UInt64
        let startedWorkItemCount: UInt64
        let finishedWorkItemCount: UInt64
        let discardedWorkItemCount: UInt64
        let retired: Bool

        var isCoherent: Bool {
            guard requestId > 0, generation > 0, finishedWorkItemCount <= startedWorkItemCount else { return false }
            // Core samples these counters under one lock. Compare by safe
            // subtraction; temporary owner-only scope gaps remain admissible.
            return runningWorkItemCount == startedWorkItemCount - finishedWorkItemCount
        }
        var isStrictlyRetired: Bool {
            isCoherent && retired && queuedWorkItemCount == 0 && runningWorkItemCount == 0
                && continuationScopeCount == 0 && callbackScopeCount == 0 && retainedOwnerCount == 0
                && startedWorkItemCount == finishedWorkItemCount
        }
    }
    /// An anonymous binding of the workspace's source snapshot for one ordinal.
    /// It does not assert that Core read the same persisted version at dispatch.
    struct SourceBinding: Codable, Sendable {
        enum Contract: String, Codable, Sendable {
            case sourceProjectionSHA256V1 = "reader-search-source-projection-sha256-v1"
        }
        let contract: Contract
        let sha256: String

        /// SHA256 of UTF-8 "io.reader.minliny.search-source-binding.v1" + NUL,
        /// then three length-prefixed byte fields in this exact order:
        /// sourceId UTF-8, sourceVersion UTF-8, and source.list bookSource
        /// projected by JSONSerialization [.prettyPrinted, .sortedKeys].
        /// Each length is an unsigned 64-bit big-endian byte count. No Unicode
        /// normalization, trimming or URL rewriting is performed. The definition
        /// bytes are the existing ReaderOnlineSource projection, not the source
        /// package's original formatting. External real-source preproofs must
        /// independently recreate that same Foundation projection and framing.
        static func observing(_ source: ReaderOnlineSource) -> Self? {
            #if DEBUG
            var hash = SHA256()
            hash.update(data: Data("io.reader.minliny.search-source-binding.v1\0".utf8))
            for bytes in [Data(source.id.utf8), Data(source.version.utf8), source.definition] {
                var length = UInt64(bytes.count).bigEndian
                withUnsafeBytes(of: &length) { hash.update(data: Data($0)) }
                hash.update(data: bytes)
            }
            return Self(contract: .sourceProjectionSHA256V1,
                        sha256: hash.finalize().map { String(format: "%02x", $0) }.joined())
            #else
            return nil
            #endif
        }
    }
    let searchID: UUID // The workspace's actual generation, never a second identity.
    let sequence: UInt32
    let elapsedNanoseconds: UInt64
    let stage: Stage
    let sourceOrdinal: UInt32?
    let coreRequestID: UInt64?
    let hostOperationID: UInt64?
    let transport: Transport?
    let transportAttempt: UInt8?
    let taskIdentifier: Int?
    let navigationGeneration: UInt64?
    let outcome: Outcome?
    let count: Int? // Source/book count, or received byte count at HTTP completion.
    let durationMilliseconds: Int?
    let httpStatus: Int?
    let httpFetchSummary: HTTPFetchSummary?
    let hostWorkSummary: HostWorkSummary?
    let sourceBinding: SourceBinding?
    let coreExecutionSummary: CoreExecutionSummary?
    let coreExecutionObservationOutcome: CoreExecutionObservationOutcome?
}

/// One generation has a hard event budget, including its overflow marker.
/// There is no global recorder, disk output or retention when the sink is nil.
final class ReaderSearchTraceRecording: @unchecked Sendable {
    private let searchID: UUID
    private let sink: ReaderSearchTraceSink
    private let origin = DispatchTime.now().uptimeNanoseconds
    private let lock = NSLock()
    private var sequence: UInt32 = 0
    private let limit: UInt32 = 2048
    private var sourceExecutionSamples = 0
    private var sourceExecutionObservers = 0

    init(searchID: UUID, sink: @escaping ReaderSearchTraceSink) {
        self.searchID = searchID; self.sink = sink
    }

    func admitSourceExecutionObservation() -> Bool {
        lock.withLock {
            guard sequence < limit, sourceExecutionSamples < 64, sourceExecutionObservers < 4 else { return false }
            sourceExecutionObservers += 1
            return true
        }
    }
    func reserveSourceExecutionSample() -> Bool {
        lock.withLock {
            guard sequence < limit, sourceExecutionSamples < 64 else { return false }
            sourceExecutionSamples += 1
            return true
        }
    }
    func endSourceExecutionObservation() { lock.withLock { sourceExecutionObservers -= 1 } }

    func emit(_ stage: ReaderSearchTraceEvent.Stage, sourceOrdinal: UInt32? = nil,
              coreRequestID: UInt64? = nil, hostOperationID: UInt64? = nil,
              transport: ReaderSearchTraceEvent.Transport? = nil, transportAttempt: UInt8? = nil,
              taskIdentifier: Int? = nil, navigationGeneration: UInt64? = nil,
              outcome: ReaderSearchTraceEvent.Outcome? = nil, count: Int? = nil,
              durationMilliseconds: Int? = nil, httpStatus: Int? = nil,
              httpFetchSummary: ReaderSearchTraceEvent.HTTPFetchSummary? = nil,
              hostWorkSummary: ReaderSearchTraceEvent.HostWorkSummary? = nil,
              sourceBinding: ReaderSearchTraceEvent.SourceBinding? = nil,
              coreExecutionSummary: ReaderSearchTraceEvent.CoreExecutionSummary? = nil,
              coreExecutionObservationOutcome: ReaderSearchTraceEvent.CoreExecutionObservationOutcome? = nil) {
        let stamp: (UInt32, UInt64)? = lock.withLock {
            guard sequence < limit else { return nil }
            sequence += 1
            // A timestamp sampled before this lock can run backwards after
            // concurrent emitters acquire their sequence numbers in reverse.
            return (sequence, DispatchTime.now().uptimeNanoseconds - origin)
        }
        guard let (next, elapsed) = stamp else { return }
        sink(.init(searchID: searchID, sequence: next, elapsedNanoseconds: elapsed,
            stage: next == limit ? .traceLimitReached : stage, sourceOrdinal: sourceOrdinal,
            coreRequestID: coreRequestID, hostOperationID: hostOperationID, transport: transport,
            transportAttempt: transportAttempt, taskIdentifier: taskIdentifier,
            navigationGeneration: navigationGeneration, outcome: outcome, count: count,
            durationMilliseconds: durationMilliseconds, httpStatus: httpStatus,
            httpFetchSummary: httpFetchSummary, hostWorkSummary: hostWorkSummary, sourceBinding: sourceBinding,
            coreExecutionSummary: coreExecutionSummary, coreExecutionObservationOutcome: coreExecutionObservationOutcome))
    }
}

/// The raw identity is used only to admit the exact book.search dispatch. It is
/// deliberately absent from the immutable binding handed to Host work.
struct ReaderSearchTraceAttempt: Sendable {
    let recording: ReaderSearchTraceRecording
    let sourceOrdinal: UInt32
    let sourceID: String
    private let sourceBinding: ReaderSearchTraceEvent.SourceBinding?

    init(recording: ReaderSearchTraceRecording, sourceOrdinal: UInt32, source: ReaderOnlineSource) {
        self.recording = recording; self.sourceOrdinal = sourceOrdinal; sourceID = source.id
        sourceBinding = .observing(source)
    }

    func bind(requestID: UInt64, sourceID: String?) -> ReaderSearchTraceBinding? {
        guard self.sourceID == sourceID else { return nil }
        return .init(recording: recording, sourceOrdinal: sourceOrdinal, requestID: requestID,
                     operationID: nil, transport: nil)
    }
    func emit(_ stage: ReaderSearchTraceEvent.Stage, outcome: ReaderSearchTraceEvent.Outcome? = nil,
              count: Int? = nil, durationMilliseconds: Int? = nil) {
        recording.emit(stage, sourceOrdinal: sourceOrdinal, outcome: outcome,
                       count: count, durationMilliseconds: durationMilliseconds,
                       sourceBinding: stage == .sourceAttemptStarted ? sourceBinding : nil)
    }
}

enum ReaderSearchTraceContext {
    // Consumed by searchSource before dispatch. Request allocation and queued
    // Host work receive explicit immutable values, with this TaskLocal cleared.
    @TaskLocal static var attempt: ReaderSearchTraceAttempt?
}

struct ReaderSearchTraceBinding: Sendable {
    let recording: ReaderSearchTraceRecording
    let sourceOrdinal: UInt32
    let requestID: UInt64
    let operationID: UInt64?
    let transport: ReaderSearchTraceEvent.Transport?

    func host(operationID: UInt64, capability: String) -> Self {
        .init(recording: recording, sourceOrdinal: sourceOrdinal, requestID: requestID,
              operationID: operationID,
              transport: capability == "http.execute" ? .http : capability == "webview.evaluateJavaScript" ? .webView : .other)
    }
    func emit(_ stage: ReaderSearchTraceEvent.Stage, outcome: ReaderSearchTraceEvent.Outcome? = nil,
              transportAttempt: UInt8? = nil, taskIdentifier: Int? = nil,
              navigationGeneration: UInt64? = nil, count: Int? = nil, httpStatus: Int? = nil,
              httpFetchSummary: ReaderSearchTraceEvent.HTTPFetchSummary? = nil,
              hostWorkSummary: ReaderSearchTraceEvent.HostWorkSummary? = nil,
              coreExecutionSummary: ReaderSearchTraceEvent.CoreExecutionSummary? = nil,
              coreExecutionObservationOutcome: ReaderSearchTraceEvent.CoreExecutionObservationOutcome? = nil) {
        recording.emit(stage, sourceOrdinal: sourceOrdinal, coreRequestID: requestID,
            hostOperationID: operationID, transport: transport, transportAttempt: transportAttempt,
            taskIdentifier: taskIdentifier, navigationGeneration: navigationGeneration,
            outcome: outcome, count: count, httpStatus: httpStatus,
            httpFetchSummary: httpFetchSummary, hostWorkSummary: hostWorkSummary,
            coreExecutionSummary: coreExecutionSummary, coreExecutionObservationOutcome: coreExecutionObservationOutcome)
    }
}
