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
    @Published public var searchAllEnabledSources = false
    @Published public var searchState: SearchState = .idle
    @Published public var sources: [BookSource] = []
    @Published public var currentPage = 1
    @Published public var hasMorePages = false

    private let store: BookSourceStore
    private let provider: ReaderCoreServiceProvider
    private var resultSourceBindings: [String: BookSource] = [:]

    public init(
        store: BookSourceStore = .shared,
        provider: ReaderCoreServiceProvider? = nil
    ) {
        self.store = store
        self.provider = provider ?? ReaderCoreServiceProvider.shared
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

        searchState = .loading
        currentPage = 1
        resultSourceBindings = [:]

        do {
            let state: LoadState<[SearchResultItem]>
            if searchAllEnabledSources {
                state = await searchAcrossEnabledSources(keyword: trimmed, page: currentPage)
            } else {
                state = await provider.searchBooks(keyword: trimmed, page: currentPage, source: selectedSource)
            }
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
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let state: LoadState<[SearchResultItem]>
        if searchAllEnabledSources {
            state = await searchAcrossEnabledSources(keyword: trimmed, page: currentPage, existingResults: existing)
        } else {
            state = await provider.searchBooks(keyword: trimmed, page: currentPage, source: selectedSource)
        }

        switch state {
        case .loaded(let results):
            if searchAllEnabledSources {
                searchState = .success(results: results)
                return
            }
            let combined = existing + results
            searchState = .success(results: combined)
            hasMorePages = results.count >= 5
        case .partial(let results, let warning):
            if searchAllEnabledSources {
                searchState = .partial(results: results, warnings: [warning])
                hasMorePages = false
                return
            }
            let combined = existing + results
            searchState = .partial(results: combined, warnings: [warning])
            hasMorePages = false
        default:
            hasMorePages = false
        }
    }

    public func selectSource(_ source: BookSource) {
        searchAllEnabledSources = false
        selectedSource = source
    }

    public func selectAllEnabledSources() {
        searchAllEnabledSources = true
    }

    public var enabledSources: [BookSource] {
        sources.filter(\.enabled)
    }

    public func source(for result: SearchResultItem) -> BookSource? {
        resultSourceBindings[resultBindingKey(for: result)]
    }

    public func sourceName(for result: SearchResultItem) -> String {
        source(for: result)?.displayName ?? selectedSource?.displayName ?? ""
    }

    public func reset() {
        keyword = ""
        searchState = .idle
        resultSourceBindings = [:]
    }

    private func searchAcrossEnabledSources(
        keyword: String,
        page: Int,
        existingResults: [SearchResultItem] = []
    ) async -> LoadState<[SearchResultItem]> {
        let activeSources = enabledSources
        guard !activeSources.isEmpty else {
            return .failed(AppReaderError(code: .unsupported, message: "没有启用的书源", stage: "SEARCH"))
        }

        var boundResults: [(SearchResultItem, BookSource?)] = existingResults.map {
            ($0, source(for: $0))
        }

        let provider = self.provider
        let outcomes = await withTaskGroup(of: MultiSourceSearchOutcome.self, returning: [MultiSourceSearchOutcome].self) { group in
            for (sourceIndex, source) in activeSources.enumerated() {
                group.addTask {
                    let state = await provider.searchBooks(keyword: keyword, page: page, source: source)
                    return MultiSourceSearchOutcome(sourceIndex: sourceIndex, source: source, state: state)
                }
            }

            var collected: [MultiSourceSearchOutcome] = []
            for await outcome in group {
                collected.append(outcome)
            }
            return collected.sorted { $0.sourceIndex < $1.sourceIndex }
        }

        let warnings = outcomes.compactMap(\.warning)
        let successCount = outcomes.filter(\.isSuccessfulSource).count
        let anyHasMorePages = outcomes.contains { $0.returnedResultCount >= 5 }
        boundResults.append(contentsOf: outcomes.flatMap(\.boundResults))

        let deduped = deduplicate(boundResults: boundResults)
        resultSourceBindings = Dictionary(uniqueKeysWithValues: deduped.compactMap { result, source in
            guard let source else { return nil }
            return (resultBindingKey(for: result), source)
        })
        hasMorePages = anyHasMorePages

        let results = deduped.map(\.0)
        if !results.isEmpty, warnings.isEmpty {
            return .loaded(results)
        }
        if !results.isEmpty {
            return .partial(results, warning: warnings.joined(separator: "\n"))
        }
        if successCount > 0 {
            return .empty
        }
        return .failed(AppReaderError(code: .network, message: warnings.joined(separator: "\n"), stage: "SEARCH"))
    }

    private func deduplicate(
        boundResults: [(SearchResultItem, BookSource?)]
    ) -> [(SearchResultItem, BookSource?)] {
        var seen: Set<String> = []
        var output: [(SearchResultItem, BookSource?)] = []
        for pair in boundResults {
            let key = duplicateKey(for: pair.0)
            if seen.insert(key).inserted {
                output.append(pair)
            }
        }
        return output
    }

    private func duplicateKey(for result: SearchResultItem) -> String {
        let title = normalize(result.title)
        let author = normalize(result.author ?? "")
        if !author.isEmpty {
            return "\(title)|\(author)"
        }
        return "\(title)|\(normalize(result.detailURL))"
    }

    private func resultBindingKey(for result: SearchResultItem) -> String {
        "\(normalize(result.title))|\(normalize(result.author ?? ""))|\(normalize(result.detailURL))"
    }

    private func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private struct MultiSourceSearchOutcome: Sendable {
        let sourceIndex: Int
        let source: BookSource
        let results: [SearchResultItem]
        let warning: String?
        let isSuccessfulSource: Bool

        init(sourceIndex: Int, source: BookSource, state: LoadState<[SearchResultItem]>) {
            self.sourceIndex = sourceIndex
            self.source = source
            switch state {
            case .loaded(let results):
                self.results = results
                self.warning = nil
                self.isSuccessfulSource = true
            case .partial(let results, let warning):
                self.results = results
                self.warning = "\(source.displayName): \(warning)"
                self.isSuccessfulSource = true
            case .empty:
                self.results = []
                self.warning = nil
                self.isSuccessfulSource = true
            case .unsupported(let reason):
                self.results = []
                self.warning = "\(source.displayName): \(reason)"
                self.isSuccessfulSource = false
            case .failed(let error):
                self.results = []
                self.warning = "\(source.displayName): \(error.message)"
                self.isSuccessfulSource = false
            case .loading, .idle:
                self.results = []
                self.warning = nil
                self.isSuccessfulSource = false
            }
        }

        var returnedResultCount: Int { results.count }

        var boundResults: [(SearchResultItem, BookSource?)] {
            results.map { ($0, source) }
        }
    }
}
