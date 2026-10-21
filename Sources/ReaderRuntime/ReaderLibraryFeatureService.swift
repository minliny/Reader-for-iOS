import Foundation

extension ReaderLibraryService: ReaderLibraryFeatures {
    public func pendingFeatureOperations() async throws -> [ReaderPendingCoreCommand] {
        try (pendingFeatureCommands() + pendingLocalReprocessOperations() + pendingOnlineAdmissions())
            .sorted { $0.id < $1.id }
    }
    public func localPresentationKind(for book: ReaderBook) async throws -> ReaderLocalPresentationKind {
        guard book.sourceId == "local" else { throw ReaderLibraryError.unsupportedFile }
        let result = try decode(ReaderLocalPresentationKind.self, await coreRead("local_book.presentation.kind.v1", ["bookId": book.bookId]))
        guard result.sourceId == "local", result.bookId == book.bookId, !result.format.isEmpty else {
            throw ReaderLibraryError.invalidResponse("local presentation identity")
        }
        return result
    }
    public func listBooks(query: ReaderShelfQuery) async throws -> [ReaderBook] {
        struct Page: Decodable { let books: [ReaderBook]; let total: Int }
        var books: [ReaderBook] = []
        repeat {
            var parameters: [String: Any] = ["contentKind": "text", "sortBy": query.sortBy.rawValue,
                "sortDirection": query.descending ? "descending" : "ascending", "offset": books.count, "limit": 128]
            if let source = query.sourceId { parameters["sourceId"] = source }
            if let keyword = query.keyword?.trimmingCharacters(in: .whitespacesAndNewlines), !keyword.isEmpty { parameters["keyword"] = keyword }
            if let group = query.group?.trimmingCharacters(in: .whitespacesAndNewlines) {
                if group.isEmpty { parameters["hasGroup"] = false }
                else { parameters["group"] = group }
            }
            let page = try decode(Page.self, await coreRead("bookshelf.list", parameters))
            books.append(contentsOf: page.books)
            if page.books.isEmpty || books.count >= page.total { return books }
        } while true
    }

    public func bookDetails(for book: ReaderBook) async throws -> ReaderBook? {
        struct Result: Decodable { let book: ReaderBook? }
        return try decode(Result.self, await coreRead("bookshelf.get", ["sourceId": book.sourceId, "bookId": book.bookId])).book
    }

    public func importBooks(at urls: [URL]) async -> [ReaderBatchImportItem] {
        var results: [ReaderBatchImportItem] = []
        var blocked = false
        for url in urls {
            if Task.isCancelled || blocked {
                results.append(ReaderBatchImportItem(id: UUID(), fileName: url.lastPathComponent, result: nil,
                    failure: blocked ? "前一项结果待确认，尚未派发" : nil, cancelled: Task.isCancelled, unresolved: false))
                continue
            }
            do {
                let value = try await importBook(at: url)
                results.append(ReaderBatchImportItem(id: UUID(), fileName: url.lastPathComponent,
                    result: value, failure: nil, cancelled: false, unresolved: false))
            } catch {
                let pending: Bool
                if case ReaderLibraryError.operationPending = error { pending = true } else { pending = false }
                results.append(ReaderBatchImportItem(id: UUID(), fileName: url.lastPathComponent, result: nil,
                    failure: error.localizedDescription, cancelled: error is CancellationError, unresolved: pending))
                if pending { blocked = true }
            }
        }
        return results
    }

    public func groups() async throws -> [ReaderBookGroup] {
        struct Result: Decodable { let groups: [ReaderBookGroup] }
        return try decode(Result.self, await coreRead("book-group.list", [:])).groups
    }
    public func createGroup(name: String, operationID: String) async throws -> ReaderBookGroup {
        struct Result: Decodable { let group: ReaderBookGroup }
        let result = try decode(Result.self, await shelfMutation("book-group.create", ["groupName": name], operationID: operationID)).group
        try await finishCoreOperation(operationID)
        return result
    }
    public func updateGroup(_ group: ReaderBookGroup, operationID: String) async throws -> ReaderBookGroup {
        struct Result: Decodable { let group: ReaderBookGroup }
        var params: [String: Any] = ["groupId": group.groupId, "groupName": group.groupName,
            "order": group.order, "enableRefresh": group.enableRefresh, "show": group.show]
        if let cover = group.cover { params["cover"] = cover }
        let result = try decode(Result.self, await shelfMutation("book-group.update", params, operationID: operationID)).group
        guard result.groupId == group.groupId else { throw ReaderLibraryError.invalidResponse("group identity") }
        try await finishCoreOperation(operationID)
        return result
    }
    public func deleteGroup(_ group: ReaderBookGroup, operationID: String) async throws {
        struct Result: Decodable { let groupId: Int64; let deleted: Bool }
        let result = try decode(Result.self, await shelfMutation("book-group.delete", ["groupId": group.groupId], operationID: operationID))
        guard result.groupId == group.groupId else { throw ReaderLibraryError.invalidResponse("group deletion identity") }
        try await finishCoreOperation(operationID)
    }
    public func assignGroup(_ group: ReaderBookGroup?, to book: ReaderBook, operationID: String) async throws -> ReaderBook {
        struct Result: Decodable { let book: ReaderBook }
        let result = try decode(Result.self, await shelfMutation("bookshelf.group.assign", [
            "sourceId": book.sourceId, "bookId": book.bookId, "group": group?.groupName ?? ""
        ], operationID: operationID)).book
        guard ReaderBookIdentity(result) == ReaderBookIdentity(book) else { throw ReaderLibraryError.invalidResponse("assignment identity") }
        try await finishCoreOperation(operationID)
        return result
    }
    public func removeBooks(_ books: [ReaderBook], operationID: String) async throws -> ReaderRemovalReceipt {
        guard !assetMutationInFlight, !importInFlight, !recovering else { throw ReaderLibraryError.busy }
        guard !books.isEmpty else { throw ReaderLibraryError.invalidResponse("empty shelf selection") }
        // A dispatched progress update owns the book until its original ACK is consumed.
        let selected = Set(books.map(ReaderBookIdentity.init))
        guard try !hasPendingImportAsset(Set(books.filter { $0.sourceId == "local" }.map(\.bookId))) else {
            throw ReaderLibraryError.operationPending("import asset owner")
        }
        guard !unresolvedWrites.values.contains(where: { value in
            if case .progress(let source, let bookID) = value.owner {
                return selected.contains(ReaderBookIdentity(sourceId: source, bookId: bookID))
            }
            return false
        }) else { throw ReaderLibraryError.operationPending(operationID) }
        assetMutationInFlight = true
        defer { assetMutationInFlight = false }
        let targets = books.map { ["sourceId": $0.sourceId, "bookId": $0.bookId] }
        let data = try await shelfMutation("bookshelf.removeBatch", ["targets": targets], operationID: operationID)
        let receipt = try decode(ReaderRemovalReceipt.self, data)
        guard receipt.requestedCount == UInt64(books.count),
              Set(receipt.removedTargets + receipt.missingTargets) == selected,
              receipt.removedTargets.allSatisfy({ selected.contains($0) }) else {
            throw ReaderLibraryError.invalidResponse("remove receipt selection identity")
        }
        // A completed old remove receipt must never delete a newly reimported
        // same-SHA asset. Cleanup belongs to its original unfinished owner.
        if try isCoreOperationCompleted(operationID) { return receipt }
        try cleanupRemovedLocalSources(receipt.removedTargets)
        try await finishCoreOperation(operationID)
        return receipt
    }

    func cleanupRemovedLocalSources(_ identities: [ReaderBookIdentity]) throws {
        for identity in identities where identity.sourceId == "local" {
            let hash = try localSourceHash(identity.bookId)
            let original = stableSource(hash)
            if FileManager.default.fileExists(atPath: original.path) {
                guard try Self.sha256(at: original) == hash else { throw ReaderLibraryError.invalidResponse("cleanup source identity") }
                try FileManager.default.removeItem(at: original)
            }
        }
    }

    public func bookmarks(for book: ReaderBook, query: String?) async throws -> [ReaderBookmark] {
        struct Result: Decodable { let bookmarks: [ReaderBookmark] }
        var params: [String: Any] = ["bookName": book.title, "bookAuthor": book.author, "sortBy": "bookLocation"]
        if let query, !query.isEmpty { params["query"] = query }
        let result = try decode(Result.self, await coreRead("bookmark.list", params))
        // Legacy same-name rows have no provable book identity; never attach them by guess.
        return result.bookmarks.filter { $0.positionScope?.sourceId == book.sourceId && $0.positionScope?.bookId == book.bookId }
    }
    public func createBookmark(for book: ReaderBook, content: ReaderChapterContent, scalarOffset: UInt64,
                               text: String, note: String, operationID: String) async throws -> ReaderBookmark {
        struct Result: Decodable { let bookmark: ReaderBookmark }
        guard scalarOffset <= content.scalarCount, scalarOffset <= UInt64(Int32.max), content.chapterIndex <= UInt32(Int32.max) else {
            throw ReaderLibraryError.invalidPosition
        }
        let scope = try ReaderContentPositionScope(book: book, content: content)
        let params: [String: Any] = ["bookName": book.title, "bookAuthor": book.author,
            "chapterIndex": content.chapterIndex, "chapterPos": scalarOffset, "chapterName": content.chapterTitle,
            "bookText": text, "content": note, "positionScope": try object(JSONEncoder().encode(scope))]
        let bookmark = try decode(Result.self, await bookmarkMutation("bookmark.create", params, operationID: operationID)).bookmark
        guard bookmark.positionScope == scope, bookmark.scalarOffset == scalarOffset else { throw ReaderLibraryError.invalidResponse("bookmark receipt identity") }
        try await finishCoreOperation(operationID)
        return bookmark
    }
    public func updateBookmark(_ bookmark: ReaderBookmark, note: String, operationID: String) async throws -> ReaderBookmark {
        struct Result: Decodable { let bookmark: ReaderBookmark }
        guard let scope = bookmark.positionScope else { throw ReaderLibraryError.invalidPosition }
        let value = try decode(Result.self, await coreMutation("bookmark.update", ["time": bookmark.time, "content": note,
            "positionScope": try object(JSONEncoder().encode(scope))], operationID: operationID, scope: "bookmarks")).bookmark
        guard value.time == bookmark.time, value.positionScope == scope else { throw ReaderLibraryError.invalidResponse("bookmark update identity") }
        try await finishCoreOperation(operationID)
        return value
    }
    public func deleteBookmark(_ bookmark: ReaderBookmark, operationID: String) async throws {
        struct Result: Decodable { let time: Int64; let deleted: Bool }
        let value = try decode(Result.self, await bookmarkMutation("bookmark.delete", ["time": bookmark.time], operationID: operationID))
        guard value.time == bookmark.time else { throw ReaderLibraryError.invalidResponse("bookmark delete identity") }
        try await finishCoreOperation(operationID)
    }

    public func retainedSourceURL(for book: ReaderBook) throws -> URL {
        guard book.sourceId == "local" else { throw ReaderLibraryError.unsupportedFile }
        let hash = try localSourceHash(book.bookId)
        let source = stableSource(hash)
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              try Self.sha256(at: source) == hash else { throw ReaderLibraryError.invalidResponse("retained source identity") }
        return source
    }
    private func localSourceHash(_ bookID: String) throws -> String {
        let prefix = "local:"
        guard bookID.hasPrefix(prefix) else { throw ReaderLibraryError.invalidResponse("local book identity") }
        let hash = String(bookID.dropFirst(prefix.count))
        guard hash.count == 64, hash.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
            throw ReaderLibraryError.invalidResponse("local content hash")
        }
        return hash
    }
}
