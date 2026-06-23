import Foundation
import ReaderCoreModels

public struct BookshelfItemFactory {
    public static func make(
        from result: SearchResultItem,
        sourceID: String,
        sourceName: String? = nil
    ) -> BookshelfItem {
        BookshelfItem(
            id: UUID().uuidString,
            sourceID: sourceID,
            sourceName: sourceName,
            bookURL: result.detailURL,
            title: result.title,
            author: result.author,
            coverURL: result.coverURL
        )
    }

    public static func makeOrUpdate(
        from result: SearchResultItem,
        sourceID: String,
        sourceName: String? = nil,
        existing: BookshelfItem? = nil
    ) -> BookshelfItem {
        BookshelfItem(
            id: existing?.id ?? UUID().uuidString,
            sourceID: sourceID,
            sourceName: sourceName ?? existing?.sourceName,
            bookURL: result.detailURL,
            title: result.title,
            author: result.author ?? existing?.author,
            coverURL: result.coverURL ?? existing?.coverURL,
            addedAt: existing?.addedAt ?? Date(),
            updatedAt: Date(),
            lastReadChapterTitle: existing?.lastReadChapterTitle,
            lastReadChapterURL: existing?.lastReadChapterURL,
            readingProgress: existing?.readingProgress ?? 0.0
        )
    }

    public static func makeOrUpdate(
        from localBook: LocalBook,
        firstChapterTitle: String? = nil,
        firstChapterURL: String? = nil,
        localChapterList: [TOCItem] = [],
        existing: BookshelfItem? = nil
    ) -> BookshelfItem {
        BookshelfItem(
            id: existing?.id ?? UUID().uuidString,
            sourceID: "local-book",
            sourceName: "Local Book",
            bookURL: localBook.filePath,
            title: localBook.title,
            author: localBook.author ?? existing?.author,
            coverURL: localBook.coverPath ?? existing?.coverURL,
            addedAt: existing?.addedAt ?? localBook.addedAt,
            updatedAt: Date(),
            lastReadChapterTitle: existing?.lastReadChapterTitle ?? firstChapterTitle,
            lastReadChapterURL: existing?.lastReadChapterURL ?? firstChapterURL,
            readingProgress: existing?.readingProgress ?? 0.0,
            localChapterList: localChapterList.isEmpty ? existing?.localChapterList : localChapterList
        )
    }
}
