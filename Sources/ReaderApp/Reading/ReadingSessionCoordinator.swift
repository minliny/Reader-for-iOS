import Foundation
import Observation
import ReaderCoreBridge
import ReaderDesign
import ReaderHost

enum ReadingProjectionFailure: Error {
    case invalidChapter
    case obsolete
    case positionNotProven
    case emptyContent
}

struct ReadingChapter {
    let projection: LocalBookChapterContentData
    let ebook: EbookDocument?
    let anchor: Int
    let generation: Int

    var index: Int64 { projection.chapterIndex }
    var title: String { projection.chapterTitle }
}

@MainActor
@Observable
final class ReadingSessionCoordinator {
    let runtime: CoreRuntimeActor
    private let session = UUID().uuidString
    private var pageGeneration = 0
    private var entity: BookIdentity?
    private var book: BookshelfEntryData?
    private var catalog: [BookTocEntryData] = []
    private var original: LocalBookOriginalData?
    private var online: OnlineReadingCoordinator?
    private var onlineDirectoryRevision: String?
    private var presentation: LocalBookPresentationKindData?
    private var files: FileAndAssetHost?
    private var positionRevision: String?
    private var lastSaved: (chapter: Int64, offset: Int)?
    private var inFlight: Task<Bool, Never>?
    private var activeCommand = false
    private var bookmarkCommand = false
    private var bookmarkRecovery = false
    private var ready = false
    private(set) var speechSession: SpeechSessionCoordinator?

    private(set) var onlineFailure: (any Error)?
    private(set) var onlineUnavailableChapter: Int64?
    var onlineBook: OnlineBookReference? { online == nil ? nil : book.map(OnlineBookReference.init(shelfBook:)) }
    func onlineChapterTitle(_ index: Int64) -> String { catalog.first { $0.index == index }?.title ?? "在线章节" }
    private(set) var chapter: ReadingChapter?
    private(set) var position: Int = 0
    private(set) var pageState = ReaderPageState.loading
    private(set) var recovery: ShelfRecovery?
    private(set) var bookmarks: [BookmarkData] = []
    let toast = ReaderToastPresenter()
    var frontmost = true
    var sceneActive = true
    var id: String { session }
    var generation: Int { pageGeneration }

    init(runtime: CoreRuntimeActor) { self.runtime = runtime }

    func begin(book: BookshelfEntryData, chapters: [BookTocEntryData],
               original: LocalBookOriginalData?, files: FileAndAssetHost, startChapter: Int64?) async {
        guard entity == nil else { return }
        entity = BookIdentity(book)
        self.book = book
        catalog = chapters
        self.original = original
        self.files = files
        await reopen(startChapter: startChapter)
        await verifyBookmarkJournal()
    }

    func beginOnline(book: BookshelfEntryData, files: FileAndAssetHost, startChapter: Int64? = nil) async {
        guard entity == nil else { return }
        entity = BookIdentity(book)
        self.book = book
        self.files = files
        online = OnlineReadingCoordinator(runtime: runtime)
        await reopen(startChapter: startChapter)
        await verifyBookmarkJournal()
    }

    func adoptRecoveredOnlineBook(_ entry: BookshelfEntryData) async {
        guard online != nil else { return }
        if BookIdentity(entry) != entity {
            retirePage()
            entity = BookIdentity(entry)
            book = entry
            catalog = []
            onlineDirectoryRevision = nil
            positionRevision = nil
            lastSaved = nil
            ready = false
            chapter = nil
        }
        await reopen()
    }

    func reopen(startChapter: Int64? = nil) async {
        guard let entity else { return }
        retirePage()
        let expected = pageGeneration
        onlineUnavailableChapter = nil
        if chapter == nil { pageState = .loading }
        do {
            let data = try await runtime.request(ReaderM1.readingProgressGet,
                .init(bookId: entity.bookId, sourceId: entity.sourceId)).value
            guard generation == expected else { return }
            positionRevision = data.progressRevision
            if let online {
                let directory: OnlineDirectory
                if let cached = try await online.cachedDirectory(sourceId: entity.sourceId, bookId: entity.bookId) {
                    directory = cached
                } else {
                    directory = try await fetchDirectory(online, entity: entity)
                }
                guard generation == expected else { return }
                catalog = directory.chapters
                onlineDirectoryRevision = directory.revision
                onlineFailure = nil
            } else {
                let kind = try await runtime.request(ReaderM1.localBookPresentationKindV1,
                    .init(bookId: entity.bookId)).value
                guard generation == expected, kind.bookId == entity.bookId,
                      kind.sourceId.rawValue == entity.sourceId else { return }
                presentation = kind
                if kind.kind == .ebook, kind.reimportRequired {
                    feedback("已打开可核对的正文版式", key: "verified-projection")
                }
            }
            let initial = startChapter ?? data.progress?.chapterIndex ?? catalog.first?.index ?? 0
            let stored = startChapter == nil ? data.progress : nil
            if let stored { lastSaved = (stored.chapterIndex, Int(stored.chapterOffset)) }
            if let pending = data.pendingRestore, pending.currentProgressUnverified {
                protectPosition("有待核对的阅读位置，已保留原记录。")
            }
            try await load(index: initial, expected: expected, stored: stored)
        } catch {
            guard generation == expected else { return }
            if online != nil { onlineFailure = error }
            if chapter == nil {
                pageState = .failed("暂时无法打开章节。", actionGeneration: expected)
            } else {
                retainPresentedChapter()
                feedback("暂时无法重新读取章节", key: "reload-chapter")
            }
        }
    }

    func chooseChapter(_ index: Int64, bookmark: BookmarkData? = nil) async {
        guard !activeCommand, catalog.contains(where: { $0.index == index }) || (catalog.isEmpty && index == 0) else {
            return
        }
        activeCommand = true
        defer { activeCommand = false }
        guard await drain() else { return }
        retirePage()
        let expected = pageGeneration
        do {
            try await load(index: index, expected: expected, bookmark: bookmark)
        } catch ReadingProjectionFailure.positionNotProven {
            if generation == expected {
                retainPresentedChapter()
                protectPosition("该书签的正文版本已发生变化，已保留当前位置。")
            }
        } catch {
            if generation == expected {
                retainPresentedChapter()
                if online != nil { onlineFailure = error }
                feedback("无法打开该章节", key: "open-chapter")
            }
        }
    }

    private func retainPresentedChapter() {
        guard let chapter else { return }
        ready = false
        self.chapter = .init(projection: chapter.projection, ebook: chapter.ebook,
                             anchor: position, generation: generation)
    }

    func neighboringChapter(_ direction: Int) -> Int64? {
        guard let chapter, let selected = catalog.firstIndex(where: { $0.index == chapter.index }) else { return nil }
        let next = selected + direction
        return catalog.indices.contains(next) ? catalog[next].index : nil
    }

    private func load(index: Int64, expected: Int, stored: ReadingProgressData? = nil,
                      bookmark: BookmarkData? = nil) async throws {
        guard let entity else { throw ReadingProjectionFailure.invalidChapter }
        onlineUnavailableChapter = nil
        let content: LocalBookChapterContentData
        if let online {
            let result = try await onlineChapter(online, entity: entity, index: index)
            content = try OnlineReadingCoordinator.projection(result, chapterIndex: index)
        } else {
            content = try await runtime.request(ReaderM1.localBookChapterContent,
                .init(bookId: entity.bookId, chapterIndex: index)).value
        }
        guard content.sourceId == entity.sourceId, content.bookId == entity.bookId,
              content.chapterIndex == index else { throw CoreBridgeFailure.endpointMismatch }
        guard !content.content.isEmpty else { throw ReadingProjectionFailure.emptyContent }

        var anchor = 0
        if let bookmark {
            guard let scope = bookmark.positionScope, scope.sourceId == entity.sourceId,
                  scope.bookId == entity.bookId, scope.chapterIndex == index,
                  scope.bodyVersion == content.bodyVersion, scope.processingVersion == content.processingVersion,
                  (0..<Int64(content.content.unicodeScalars.count)).contains(bookmark.chapterPos) else {
                throw ReadingProjectionFailure.positionNotProven
            }
            anchor = Int(bookmark.chapterPos)
        } else if let stored, stored.sourceId == entity.sourceId, stored.bookId == entity.bookId,
                  stored.chapterIndex == index {
            if stored.bodyVersion == content.bodyVersion, stored.processingVersion == content.processingVersion,
               (0..<Int64(content.content.unicodeScalars.count)).contains(stored.chapterOffset) {
                anchor = Int(stored.chapterOffset)
            } else if (generation == expected) {
                protectPosition("已保存的位置与当前正文版本不一致，原记录仍予保留。")
            }
        }

        var ebook: EbookDocument?
        if presentation?.kind == .ebook, presentation?.reimportRequired == false, let files, let original {
            do {
                let source = try await files.retained(sha256: original.sha256)
                let descriptor = try await runtime.request(ReaderM1.localBookChapterPresentationV1,
                    .init(bookId: entity.bookId, chapterIndex: index, localSourcePath: source.path.path)).value
                ebook = try await EbookDocument.open(descriptor: descriptor, chapter: content, source: source)
            } catch {
                if generation == expected { feedback("已切换为可核对的正文版式", key: "epub-projection") }
            }
        }
        guard expected == generation else { throw ReadingProjectionFailure.obsolete }
        ready = false
        position = anchor
        onlineFailure = nil
        chapter = ReadingChapter(projection: content, ebook: ebook, anchor: anchor, generation: expected)
    }

    func measured(_ scalar: Int, expected: Int) {
        guard let chapter, expected == chapter.generation, expected == generation,
              (0..<chapter.projection.content.unicodeScalars.count).contains(scalar) else { return }
        ready = true
        position = scalar
    }

    func useVerifiedText(expected: Int) {
        guard let chapter, expected == chapter.generation, expected == generation, chapter.ebook != nil else { return }
        let content = chapter.projection
        guard !content.content.isEmpty else {
            pageState = .failed("当前章节无可核对的正文。", actionGeneration: expected)
            self.chapter = nil
            return
        }
        pageGeneration += 1
        self.chapter = .init(projection: content, ebook: nil, anchor: position, generation: generation)
        ready = false
        feedback("已切换为可核对的正文版式", key: "fallback-text")
    }

    @discardableResult
    func drain() async -> Bool {
        if let inFlight { _ = await inFlight.value }
        guard ready, let entity, let chapter else { return true }
        if recovery != nil && !bookmarkRecovery { return false }
        let scalar = position
        if let saved = lastSaved, saved.chapter == chapter.index, saved.offset == scalar { return true }
        let content = chapter.projection
        guard let revision = positionRevision, let body = content.bodyVersion,
              let processing = content.processingVersion else {
            protectPosition("当前章节无法确认保存条件，已保留上次位置。")
            return false
        }
        let ratio = Double(scalar) / Double(max(1, content.content.unicodeScalars.count))
        let params = TextReadingProgressUpdateParams(
            expectedProgressRevision: revision, bookId: entity.bookId, sourceId: entity.sourceId,
            chapterIndex: chapter.index, chapterOffset: Int64(scalar), chapterProgress: ratio,
            chapterTitle: chapter.title,
            expectedBodyVersion: body, expectedProcessingVersion: processing
        )
        let owner = save(params, publish: { _ in })
        let expected = generation
        let operation = Task { [self] in await settle(owner, chapter: chapter.index, scalar: scalar, expected: expected) }
        inFlight = operation
        return await operation.value
    }

    private func settle(_ owner: Task<CoreOperation<ReadingProgressUpdateData>, any Error>,
                        chapter: Int64, scalar: Int, expected: Int) async -> Bool {
        defer { inFlight = nil }
        do {
            let receipt = try await owner.value.value
            guard receipt.stored, receipt.chapterIndex == chapter, receipt.chapterOffset == Int64(scalar) else {
                throw CoreBridgeFailure.endpointMismatch
            }
            positionRevision = receipt.progressRevision
            lastSaved = (chapter, scalar)
            return true
        } catch {
            if expected == generation { protectPosition("未能核对原保存操作，已保留上次确认的位置。") }
            return false
        }
    }

    func verifyPosition(expected: Int, action: Int) async {
        guard frontmost, sceneActive, expected == recovery?.generation,
              action == recovery?.action?.generation else { return }
        if bookmarkRecovery {
            await verifyBookmarkJournal()
        } else {
            recovery = nil
            await reopen()
        }
    }

    private func protectPosition(_ message: String) {
        bookmarkRecovery = false
        recovery = ShelfRecovery(title: "阅读位置待核对", message: message, generation: generation,
                                 action: ReaderRecoveryAction(title: "重新读取", generation: generation))
    }

    func feedback(_ message: String, key: String) {
        _ = toast.show(message: message, key: key, feedbackEnabled: frontmost, sceneActive: sceneActive)
    }

    func save(
        _ params: TextReadingProgressUpdateParams,
        onDispatched: (@Sendable (CoreOperationID) -> Void)? = nil,
        publish: @escaping @MainActor (ReadingProgressUpdateData) -> Void
    ) -> Task<CoreOperation<ReadingProgressUpdateData>, any Error> {
        let observed = pageGeneration
        return Task { [runtime, weak self] in
            let result = try await runtime.request(ReaderM1.readingProgressUpdate, params, onDispatched: onDispatched)
            if self?.pageGeneration == observed { publish(result.value) }
            return result
        }
    }

    func retirePage() {
        pageGeneration += 1
        speechSession?.retire()
    }

    func startSpeech(engine: SpeechSessionCoordinator.Engine, ratePercent: Int64 = 100) async throws {
        guard let chapter, let entity, chapter.generation == generation, ready,
              let bodyVersion = chapter.projection.bodyVersion,
              let processingVersion = chapter.projection.processingVersion else {
            throw SpeechSessionCoordinator.Failure.anchorUnproven
        }
        let coordinator = speechSession ?? SpeechSessionCoordinator(runtime: runtime, media: .shared)
        speechSession = coordinator
        try await coordinator.start(chapter: .init(
            sourceId: entity.sourceId, bookId: entity.bookId, chapterIndex: chapter.index, chapterTitle: chapter.title
        ), content: chapter.projection.content, bodyVersion: bodyVersion, processingVersion: processingVersion,
           title: book?.title ?? chapter.title, scalar: position, engine: engine, ratePercent: ratePercent)
    }
}

extension ReadingSessionCoordinator {
    func reloadBookmarks() async {
        guard let book else { return }
        let expected = generation
        do {
            let result = try await runtime.request(ReaderM1.bookmarkList,
                .init(bookName: book.title, bookAuthor: book.author, sortBy: .bookLocation)).value
            guard generation == expected else { return }
            bookmarks = result.bookmarks.filter {
                $0.positionScope?.bookId == book.bookId && $0.positionScope?.sourceId == book.sourceId
            }
        } catch {
            feedback("暂时无法读取书签", key: "bookmarks-read")
        }
    }

    func addBookmark() async {
        guard !bookmarkCommand, ready, let book, let files, let chapter, let body = chapter.projection.bodyVersion,
              let processing = chapter.projection.processingVersion else { return }
        bookmarkCommand = true
        defer { bookmarkCommand = false }
        let expected = generation
        let scalar = position
        let scope = RemoteContentPositionScope(sourceId: book.sourceId, bookId: book.bookId,
            chapterIndex: chapter.index, bodyVersion: body, processingVersion: processing)
        let coordinates = ScalarCoordinates(chapter.projection.content)
        let preview = coordinates.string(scalar..<min(coordinates.scalarCount, scalar + 32)) ?? ""
        do {
            let owner = BookmarkTransaction(runtime: runtime, files: files)
            let sequence = try await owner.nextSequence()
            let operation = BookmarkOperationExpected.create(.init(params: .init(
                bookName: book.title, bookAuthor: book.author, chapterIndex: chapter.index,
                chapterPos: Int64(scalar), chapterName: chapter.title, bookText: preview, positionScope: scope,
                operationId: "\(UUID().uuidString)/\(sequence)", sequence: sequence
            )))
            try await owner.execute(operation)
            if expected == generation { await reloadBookmarks(); feedback("已添加书签", key: "bookmark-added") }
        } catch {
            if expected == generation { await reportBookmarkFailure() }
        }
    }

    func deleteBookmark(_ bookmark: BookmarkData) async {
        guard !bookmarkCommand, let files, bookmarks.contains(where: { $0.time == bookmark.time }) else { return }
        bookmarkCommand = true
        defer { bookmarkCommand = false }
        let expected = generation
        do {
            let owner = BookmarkTransaction(runtime: runtime, files: files)
            let sequence = try await owner.nextSequence()
            let operation = BookmarkOperationExpected.delete(.init(params: .init(
                time: bookmark.time, operationId: "\(UUID().uuidString)/\(sequence)", sequence: sequence
            )))
            try await owner.execute(operation)
            if expected == generation { await reloadBookmarks() }
        } catch {
            if expected == generation { await reportBookmarkFailure() }
        }
    }

    private func verifyBookmarkJournal() async {
        guard let files else { return }
        do {
            if let pending = try await files.pendingBookmark() {
                try await BookmarkTransaction(runtime: runtime, files: files).confirm(pending)
                await reloadBookmarks()
            }
            if bookmarkRecovery { recovery = nil; bookmarkRecovery = false }
        } catch {
            if recovery == nil || bookmarkRecovery {
                bookmarkRecovery = true
                recovery = ShelfRecovery(title: "书签操作待核对", message: "原操作记录仍保留。",
                    generation: generation, action: ReaderRecoveryAction(title: "重新读取", generation: generation))
            }
        }
    }

    private func reportBookmarkFailure() async {
        await verifyBookmarkJournal()
        if !bookmarkRecovery { feedback("暂时无法确认书签结果", key: "bookmark-write-error") }
    }
}

extension ReadingSessionCoordinator {
    private func fetchDirectory(_ online: OnlineReadingCoordinator, entity: BookIdentity) async throws -> OnlineDirectory {
        let snapshot = book
        let detail = try await online.detail(.init(
            sourceId: entity.sourceId, book: .init(bookId: entity.bookId, title: snapshot?.title, author: snapshot?.author),
            bookUrl: entity.bookId
        ))
        return try await online.refreshDirectory(.init(sourceId: entity.sourceId, bookId: entity.bookId,
                                                       tocUrl: detail.tocUrl, variables: detail.variables))
    }

    private func onlineChapter(_ online: OnlineReadingCoordinator, entity: BookIdentity,
                               index: Int64, proof: M2DirectoryTargetProof? = nil) async throws -> M2ChapterContentData {
        let entry = catalog.first(where: { $0.index == index })
        let current = try await online.cachedDirectory(sourceId: entity.sourceId, bookId: entity.bookId)
        guard current?.revision == onlineDirectoryRevision,
              current?.chapters.first(where: { $0.index == index })?.url == entry?.url else {
            throw OnlineReadingCoordinator.Failure.directoryChanged
        }
        do {
            return try await online.chapter(.init(directoryTargetProof: proof, cacheOnly: true,
                sourceId: entity.sourceId, bookId: entity.bookId, chapterTitle: entry?.title, chapterIndex: index))
        } catch let error as CoreRequestFailure where error.m2Value.details?.category == "CACHE_MISSING" {
            let requestGeneration = generation
            do {
                return try await online.chapter(.init(directoryTargetProof: proof, sourceId: entity.sourceId,
                    bookId: entity.bookId, chapterTitle: entry?.title, chapterIndex: index,
                    chapterUrl: entry?.url, variables: entry?.variables))
            } catch {
                if generation == requestGeneration { onlineUnavailableChapter = index }
                throw error
            }
        }
    }

    @discardableResult
    func refreshOnlineDirectory() async -> Bool {
        guard !activeCommand, let online, let entity else { return false }
        activeCommand = true
        defer { activeCommand = false }
        let expected = generation
        do {
            let result = try await fetchDirectory(online, entity: entity)
            guard generation == expected else { return false }
            catalog = result.chapters
            onlineDirectoryRevision = result.revision
            onlineFailure = nil
            return true
        } catch {
            if generation == expected { onlineFailure = error }
            return false
        }
    }

    @discardableResult
    func refreshOnlineChapter() async -> Bool {
        guard !activeCommand, let online, let entity, let chapter,
              let previousBody = chapter.projection.bodyVersion,
              let previousProcessing = chapter.projection.processingVersion else { return false }
        activeCommand = true
        defer { activeCommand = false }
        guard await drain() else { return false }
        let expected = generation
        let oldPosition = position
        let entry = catalog.first(where: { $0.index == chapter.index })
        do {
            guard try await online.cachedDirectory(sourceId: entity.sourceId, bookId: entity.bookId)?.revision
                    == onlineDirectoryRevision else { throw OnlineReadingCoordinator.Failure.directoryChanged }
            let refreshed = try await online.chapter(.init(
                forceRefresh: true, sourceId: entity.sourceId, bookId: entity.bookId,
                chapterTitle: chapter.title, chapterIndex: chapter.index, chapterUrl: entry?.url,
                variables: entry?.variables, positionContext: .init(
                    bodyVersion: previousBody, processingVersion: previousProcessing,
                    anchors: [.init(id: "visible", offset: Int64(oldPosition))]
                )
            ))
            let projection = try OnlineReadingCoordinator.projection(refreshed, chapterIndex: chapter.index)
            guard generation == expected, position == oldPosition else { return false }
            let anchor: Int
            if projection.bodyVersion == previousBody, projection.processingVersion == previousProcessing {
                anchor = oldPosition
            } else {
                guard let migrated = refreshed.positionMigration, migrated.status == .committed,
                      migrated.previousBodyVersion == previousBody,
                      migrated.previousProcessingVersion == previousProcessing,
                      migrated.bodyVersion == projection.bodyVersion,
                      migrated.processingVersion == projection.processingVersion,
                      let mapped = migrated.anchors.first(where: { $0.id == "visible" &&
                          $0.previousOffset == Int64(oldPosition) }) else {
                    throw OnlineReadingCoordinator.Failure.refreshCannotProvePosition
                }
                guard (0..<Int64(projection.content.unicodeScalars.count)).contains(mapped.offset) else {
                    throw OnlineReadingCoordinator.Failure.refreshCannotProvePosition
                }
                anchor = Int(mapped.offset)
            }
            let progress = try await runtime.request(ReaderM1.readingProgressGet, entity.queryAsProgress).value
            guard generation == expected, position == oldPosition else { return false }
            retirePage()
            positionRevision = progress.progressRevision
            lastSaved = progress.progress.map { ($0.chapterIndex, Int($0.chapterOffset)) }
            position = anchor
            ready = false
            self.chapter = .init(projection: projection, ebook: nil, anchor: anchor, generation: generation)
            onlineFailure = nil
            return true
        } catch {
            if generation == expected { onlineFailure = error }
            return false
        }
    }

    @discardableResult
    func chooseOnlineTarget(_ params: M2DirectoryTargetResolveParamsV2) async -> Bool {
        guard !activeCommand, let online, let entity, params.sourceId == entity.sourceId, params.bookId == entity.bookId
        else { return false }
        activeCommand = true
        defer { activeCommand = false }
        guard await drain() else { return false }
        let expected = generation
        onlineUnavailableChapter = nil
        do {
            let target = try await online.resolveTarget(params)
            let rendered = try await onlineChapter(online, entity: entity, index: target.chapterIndex,
                                                   proof: target.directoryTargetProof)
            let projection = try OnlineReadingCoordinator.projection(rendered, chapterIndex: target.chapterIndex)
            let requested = target.chapterOffsetScalar ?? 0
            if let scope = target.positionScope {
                guard scope.bodyVersion == projection.bodyVersion, scope.processingVersion == projection.processingVersion
                else { throw ReadingProjectionFailure.positionNotProven }
            }
            guard generation == expected, (0..<Int64(projection.content.unicodeScalars.count)).contains(requested)
            else { return false }
            retirePage()
            position = Int(requested)
            ready = false
            chapter = .init(projection: projection, ebook: nil, anchor: position, generation: generation)
            onlineFailure = nil
            return true
        } catch {
            if generation == expected {
                onlineFailure = error
                if onlineUnavailableChapter != nil {
                    retirePage()
                    retainPresentedChapter()
                }
            }
            return false
        }
    }

    func switchOnlineSource(_ draft: M2SourceSwitchCommitParams) async throws -> M2SourceSwitchCommitData {
        guard !activeCommand, let online, let entity, let chapter, draft.from.sourceId == entity.sourceId,
              draft.from.bookId == entity.bookId, draft.currentChapterIndex == chapter.index else {
            throw ReadingProjectionFailure.invalidChapter
        }
        activeCommand = true
        defer { activeCommand = false }
        guard await drain() else { throw ReadingProjectionFailure.positionNotProven }
        let expected = generation
        let oldPosition = position
        let original = try await online.bindSwitch(draft)
        let commit = try await online.switchSource(original)
        guard commit.phase == .pending else { throw CoreBridgeFailure.endpointMismatch }
        let target = commit.book
        let index = commit.matchedChapter.order
        let query = TextReadingProgressGetParams(bookId: target.bookId, sourceId: target.sourceId)
        let staged: (OnlineDirectory, BookshelfEntryData, LocalBookChapterContentData, String, Int)
        do {
            guard let directory = try await online.cachedDirectory(sourceId: target.sourceId, bookId: target.bookId),
                  let entry = directory.chapters.first(where: { $0.index == index }),
                  entry.url == commit.matchedChapter.chapterUrl else {
                throw OnlineReadingCoordinator.Failure.directoryChanged
            }
            let data = try await online.chapter(.init(sourceId: target.sourceId, bookId: target.bookId,
                chapterTitle: entry.title, chapterIndex: index, chapterUrl: entry.url, variables: entry.variables))
            let projection = try OnlineReadingCoordinator.projection(data, chapterIndex: index)
            let progress = try await runtime.request(ReaderM1.readingProgressGet, query).value
            let shelf = try await runtime.request(ReaderM1.bookshelfGet,
                .init(sourceId: target.sourceId, bookId: target.bookId)).value
            guard let revision = progress.progressRevision, let book = shelf.book else {
                throw ReadingProjectionFailure.positionNotProven
            }
            // Identical canonical text has identical scalar coordinates. A different
            // body only inherits the chapter chosen by Core, at its opening scalar.
            let sameText = projection.content.utf8.elementsEqual(chapter.projection.content.utf8)
            let anchor = sameText && index == chapter.index ? oldPosition : 0
            staged = (directory, book, projection, revision, anchor)
        } catch {
            do {
                _ = try await online.rollbackSwitch(.init(transactionId: commit.transactionId))
            } catch {
                throw OnlineReadingCoordinator.Failure.switchUnresolved(.init(
                    operationId: commit.transactionId, expected: original
                ))
            }
            throw error
        }
        let revision = try await online.confirmSwitchPosition(original: original, target: staged.2,
                                                              position: staged.4, revision: staged.3)
        if generation == expected {
            retirePage()
            book = staged.1
            self.entity = BookIdentity(staged.1)
            catalog = staged.0.chapters
            onlineDirectoryRevision = staged.0.revision
            positionRevision = revision
            lastSaved = (index, staged.4)
            position = staged.4
            ready = false
            onlineFailure = nil
            self.chapter = .init(projection: staged.2, ebook: nil, anchor: staged.4, generation: generation)
        }
        return commit
    }
}

private extension BookIdentity {
    var queryAsProgress: TextReadingProgressGetParams { .init(bookId: bookId, sourceId: sourceId) }
}
