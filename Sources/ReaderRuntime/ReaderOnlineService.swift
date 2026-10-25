import Foundation
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
        let result = try object(await coreRead("book.search", ["sourceId": sourceID, "keyword": keyword, "page": max(1, page)]))
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
            return ReaderChapter(index: index, title: row["title"] as? String ?? "", url: row["url"] as? String ?? "", level: (row["level"] as? NSNumber)?.uint32Value)
        }
    }
    func onlineContent(for book: ReaderBook, chapterIndex: UInt32, directoryTargetProof: [String: Any]? = nil, preparationRevision: Int64? = nil) async throws -> ReaderChapterContent {
        let status = try await readerDownloadStatus(book)
        guard let chapter = status.chapters.first(where: { $0.chapterIndex == chapterIndex }), !chapter.url.isEmpty else { throw ReaderLibraryError.invalidPosition }
        if let url = directoryTargetProof?["url"] as? String, url != chapter.url { throw ReaderLibraryError.invalidPosition }
        var variables = status.continuationVariables ?? [:]
        variables.merge(chapter.variables) { _, chapterValue in chapterValue }
        var params: [String: Any] = ["sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": chapterIndex,
            "chapterTitle": chapter.title, "chapterUrl": chapter.url, "variables": variables]
        if let directoryTargetProof { params["directoryTargetProof"] = directoryTargetProof }
        if let preparationRevision { params["preparationRevision"] = preparationRevision }
        let result = try object(await coreRead("chapter.content", params))
        guard result["sourceId"] as? String == book.sourceId, result["bookId"] as? String == book.bookId,
              let text = result["content"] as? String else { throw ReaderLibraryError.invalidResponse("online content identity") }
        let blocks = try (result["blocks"] as? [[String: Any]]).map { try decode([ReaderContentBlock].self, JSONSerialization.data(withJSONObject: $0)) } ?? []
        return .init(sourceId: book.sourceId, bookId: book.bookId, chapterIndex: chapterIndex,
            chapterTitle: result["chapterTitle"] as? String ?? "", content: text, bodyVersion: result["bodyVersion"] as? String,
            processingVersion: result["processingVersion"] as? String, blocks: blocks)
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
