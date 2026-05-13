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
}
