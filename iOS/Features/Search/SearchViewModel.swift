import Foundation
import ReaderCoreModels
import ReaderAppPersistence
import ReaderShellValidation

public enum SearchState: Equatable {
    case idle
    case loading
    case success(results: [SearchResultItem])
    case empty
    case failed(message: String)
    case unsupported(reason: String)
    case partial(results: [SearchResultItem], warnings: [String])

    public static func == (lhs: SearchState, rhs: SearchState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case (.success(let a), .success(let b)):
            return a.count == b.count && a.allSatisfy { item in
                b.contains { $0.detailURL == item.detailURL }
            }
        case (.empty, .empty):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        case (.unsupported(let a), .unsupported(let b)):
            return a == b
        case (.partial(let a, let w1), .partial(let b, let w2)):
            return a.count == b.count && a.allSatisfy { item in
                b.contains { $0.detailURL == item.detailURL }
            } && w1 == w2
        default:
            return false
        }
    }
}

@MainActor
public final class SearchViewModel: ObservableObject {
    @Published public var keyword = ""
    @Published public var selectedSource: BookSource?
    @Published public var searchState: SearchState = .idle
    @Published public var sources: [BookSource] = []
    @Published public var currentPage = 1
    @Published public var hasMorePages = false

    private let store = BookSourceStore.shared
    private let provider = ReaderCoreServiceProvider.shared

    public init() {
        Task {
            await loadSources()
        }
    }

    public func loadSources() async {
        do {
            sources = try await store.load()
            if sources.isEmpty {
                // M1.4: Pre-populate with M1 candidate for controlledOnline search
                let m1Source = BookSource(
                    id: "candidate-xingxingxsw",
                    bookSourceName: "⭐ 星星小说网",
                    bookSourceUrl: "https://www.xingxingxsw.com",
                    enabled: true
                )
                try? await store.add(m1Source)
                sources = [m1Source]
            }
            selectedSource = sources.first(where: { $0.enabled })
        } catch {
            searchState = .failed(message: "加载书源失败")
        }
    }

    public func search() async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchState = .failed(message: "请输入关键词")
            return
        }

        // Mock mode allows search without a real source; provider routes to mock data
        let source = selectedSource

        searchState = .loading
        currentPage = 1

        do {
            let state = await provider.searchBooks(keyword: trimmed, page: currentPage, source: source)
            switch state {
            case .loaded(let results):
                if results.isEmpty {
                    searchState = .empty
                } else {
                    searchState = .success(results: results)
                    hasMorePages = results.count >= 5
                }

            case .partial(let results, let warning):
                searchState = .partial(results: results, warnings: [warning])
                hasMorePages = results.count >= 5

            case .unsupported(let reason):
                searchState = .unsupported(reason: reason)

            case .failed(let error):
                searchState = .failed(message: error.message)

            case .empty:
                searchState = .empty

            case .loading, .idle:
                break
            }
        } catch {
            searchState = .failed(message: "Search failed: \(error.localizedDescription)")
        }
    }

    public func loadMore() async {
        guard hasMorePages, case .success(let existing) = searchState else { return }

        currentPage += 1
        let state = await provider.searchBooks(keyword: keyword.trimmingCharacters(in: .whitespacesAndNewlines), page: currentPage, source: selectedSource)

        switch state {
        case .loaded(let results):
            let combined = existing + results
            searchState = .success(results: combined)
            hasMorePages = results.count >= 5
        case .partial(let results, let warning):
            let combined = existing + results
            searchState = .partial(results: combined, warnings: [warning])
            hasMorePages = false
        default:
            hasMorePages = false
        }
    }

    public func selectSource(_ source: BookSource) {
        selectedSource = source
    }

    public func reset() {
        keyword = ""
        searchState = .idle
    }
}
