import Foundation
import ReaderCoreBridge

struct OnlineDirectory {
    let revision: String
    let chapters: [BookTocEntryData]
}

struct OnlineReadingCoordinator: Sendable {
    enum Failure: Error {
        case directoryUnavailable
        case directoryChanged
        case unsupportedContent
        case cacheOnlyMiss
        case refreshCannotProvePosition
        case switchUnresolved(M2SourceSwitchTransactionQueryParams)
    }

    let runtime: CoreRuntimeActor

    func detail(_ params: M2BookDetailParams) async throws -> M2BookDetailData {
        let detail = try await runtime.request(ReaderM2.bookDetail, params).value
        guard detail.sourceId == params.sourceId, detail.book.bookId == params.book.bookId else {
            throw CoreBridgeFailure.endpointMismatch
        }
        guard detail.contentKind != .manga else { throw Failure.unsupportedContent }
        return detail
    }

    func addToShelf(_ detail: M2BookDetailData) async throws -> BookshelfAddData {
        let book = detail.book
        let result = try await runtime.request(ReaderM1.bookshelfAdd, .init(
            sourceId: detail.sourceId, bookId: book.bookId, title: book.title, author: book.author,
            coverUrl: book.coverUrl, intro: book.intro, kind: book.kind, lastChapter: book.lastChapter
        )).value
        guard result.sourceId == detail.sourceId, result.bookId == book.bookId else {
            throw CoreBridgeFailure.endpointMismatch
        }
        return result
    }

    func directory(_ params: M2BookTocParams) async throws -> M2BookTocData {
        let toc = try await runtime.request(ReaderM2.bookToc, params).value
        guard toc.sourceId == params.sourceId, toc.bookId == params.bookId else {
            throw CoreBridgeFailure.endpointMismatch
        }
        guard !toc.toc.isEmpty else { throw Failure.directoryUnavailable }
        return toc
    }

    func cachedDirectory(sourceId: String, bookId: String) async throws -> OnlineDirectory? {
        let cache = try await runtime.request(ReaderM2.cacheBookStatus, .init(
            sourceId: sourceId, bookId: bookId, includeGlobalStats: false, includeChapterStates: true
        )).value
        guard cache.sourceId == sourceId, cache.bookId == bookId else { throw CoreBridgeFailure.endpointMismatch }
        guard cache.tocAvailable, let revision = cache.catalogVersion, !revision.isEmpty else { return nil }
        let entries = cache.chapters.filter { $0.navigable != false && !$0.url.isEmpty }.map {
            BookTocEntryData(displayTitle: $0.displayTitle, contextTitle: $0.contextTitle,
                             isVip: $0.isVip, isPay: $0.isPay, index: $0.chapterIndex,
                             title: $0.title, url: $0.url, level: $0.level)
        }
        guard !entries.isEmpty else { return nil }
        return .init(revision: revision, chapters: entries)
    }

    func refreshDirectory(_ params: M2BookTocParams) async throws -> OnlineDirectory {
        let refreshed = try await directory(params)
        guard let cached = try await cachedDirectory(sourceId: params.sourceId, bookId: params.bookId),
              refreshed.catalogInstalled != false, refreshed.catalogVersion == cached.revision else { throw Failure.directoryChanged }
        // The TOC response carries per-chapter continuation variables which are
        // omitted from the download status projection.
        var entries: [Int64: M2BookTocEntryData] = [:]
        for entry in refreshed.toc {
            guard entries.updateValue(entry, forKey: entry.index) == nil else { throw Failure.directoryChanged }
        }
        let chapters = try cached.chapters.map { baseline in
            guard let fresh = entries[baseline.index], fresh.url == baseline.url else {
                throw Failure.directoryChanged
            }
            return BookTocEntryData(displayTitle: fresh.displayTitle, contextTitle: fresh.contextTitle,
                                    isVip: fresh.isVip, isPay: fresh.isPay, index: fresh.index,
                                    title: fresh.title, url: fresh.url, level: fresh.level, variables: fresh.variables)
        }
        return .init(revision: cached.revision, chapters: chapters)
    }

    func openDirectory(_ params: M2DirectoryViewOpenParamsV2) async throws -> M2DirectoryViewOpenDataV2 {
        try await runtime.request(ReaderM2.readingDirectoryViewOpenV2, params).value
    }

    func pageDirectory(_ params: M2DirectoryViewPageParamsV2) async throws -> M2DirectoryViewPageDataV2 {
        try await runtime.request(ReaderM2.readingDirectoryViewPageV2, params).value
    }

    func resolveTarget(_ params: M2DirectoryTargetResolveParamsV2) async throws -> M2DirectoryTargetResolveDataV2 {
        let target = try await runtime.request(ReaderM2.readingDirectoryTargetResolveV2, params).value
        guard target.sourceId == params.sourceId, target.bookId == params.bookId,
              target.viewId == params.viewId, target.nodeId == params.nodeId,
              target.catalogRevision == params.catalogRevision,
              target.structureRevision == params.structureRevision else { throw Failure.directoryChanged }
        return target
    }

    func chapter(_ params: M2ChapterContentParams) async throws -> M2ChapterContentData {
        let chapter = try await runtime.request(ReaderM2.chapterContent, params).value
        guard chapter.sourceId == params.sourceId, chapter.bookId == params.bookId else {
            throw CoreBridgeFailure.endpointMismatch
        }
        if params.cacheOnly == true && chapter.via != .cache { throw Failure.cacheOnlyMiss }
        return chapter
    }

    static func projection(_ content: M2ChapterContentData, chapterIndex: Int64) throws -> LocalBookChapterContentData {
        guard case .string(let text) = content.content else { throw Failure.unsupportedContent }
        guard !text.isEmpty else { throw ReadingProjectionFailure.emptyContent }
        let blocks: [ReadingDocumentBlockData]? = content.blocks?.map { block in
            switch block {
            case .text(let text):
                .text(.init(text: text.text, startScalar: text.startScalar, endScalar: text.endScalar))
            case .image(let image):
                .image(.init(source: image.source, imageWidthBasisPoints: image.imageWidthBasisPoints,
                             imageIntrinsicWidth: image.imageIntrinsicWidth,
                             imageIntrinsicHeight: image.imageIntrinsicHeight, startScalar: image.startScalar,
                             endScalar: image.endScalar))
            }
        }
        return .init(bodyVersion: content.bodyVersion, processingVersion: content.processingVersion,
                     sourceId: content.sourceId, bookId: content.bookId, chapterIndex: chapterIndex,
                     chapterTitle: content.chapterTitle, content: text, blocks: blocks)
    }
}
