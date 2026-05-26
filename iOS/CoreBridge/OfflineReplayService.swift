import Foundation
import ReaderCoreModels

/// Phase 4B: Offline Replay Service — 本地 fixture 驱动的离线重放，不接网络
public final class OfflineReplayService: Sendable {
    public static let shared = OfflineReplayService()

    private init() {}

    // MARK: - Search

    public func searchBooks(keyword: String, page: Int) async -> LoadState<[SearchResultItem]> {
        // 模拟网络延迟
        try? await Task.sleep(nanoseconds: 200_000_000)

        let results = OfflineReplayFixtures.searchResults
        if results.isEmpty { return .empty }
        return .loaded(results)
    }

    // MARK: - Book Detail

    public func getBookDetail(bookURL: String) async -> LoadState<SearchResultItem> {
        try? await Task.sleep(nanoseconds: 150_000_000)

        // 按 bookURL 匹配，或返回第一条
        let match = OfflineReplayFixtures.searchResults.first { $0.detailURL == bookURL }
            ?? OfflineReplayFixtures.bookDetail
        return .loaded(match)
    }

    // MARK: - Chapter List (TOC)

    public func getChapterList(bookURL: String) async -> LoadState<[TOCItem]> {
        try? await Task.sleep(nanoseconds: 150_000_000)
        let items = OfflineReplayFixtures.tocItems
        return items.isEmpty ? .empty : .loaded(items)
    }

    // MARK: - Chapter Content

    public func getChapterContent(chapterURL: String) async -> LoadState<ContentPage> {
        try? await Task.sleep(nanoseconds: 200_000_000)

        if let page = OfflineReplayFixtures.contentPage(for: chapterURL) {
            return .loaded(page)
        }
        // 未匹配时返回第一章作为 fallback
        if let fallback = OfflineReplayFixtures.contentPage(for: "offline://chapter/1") {
            return .loaded(fallback)
        }
        return .failed(AppReaderError(code: .parser, message: "Replay: no content for \(chapterURL)", stage: "CONTENT"))
    }

    // MARK: - Book Source Validation

    public func validateBookSource(from data: Data) async -> LoadState<BookSource> {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return .loaded(OfflineReplayFixtures.bookSource)
    }
}
