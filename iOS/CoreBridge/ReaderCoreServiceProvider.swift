import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreServices

public enum ServiceMode: Sendable {
    case mock
    case real
}

@MainActor
public final class ReaderCoreServiceProvider: @unchecked Sendable {
    public static let shared = ReaderCoreServiceProvider()

    private var mode: ServiceMode = .mock
    private let lock = NSLock()
    private let mockService: MockReaderCoreService

    private var realSearchService: (any SearchService)?
    private var realTOCService: (any TOCService)?
    private var realContentService: (any ContentService)?

    private init() {
        self.mockService = MockReaderCoreService.shared
    }

    public var currentMode: ServiceMode {
        lock.lock()
        defer { lock.unlock() }
        return mode
    }

    public func setMode(_ newMode: ServiceMode) {
        lock.lock()
        defer { lock.unlock() }
        self.mode = newMode
    }

    // MARK: - Real Mode Initialization

    /// 尝试启用 real mode。必须先通过 RealNetworkGate 检查。
    /// 返回 true 表示 real service 已配置并可用。
    public func configureRealMode() -> Bool {
        let gate = DefaultRealNetworkGate()
        let policy = RealNetworkPolicyStore.shared.current
        guard case .allowed = gate.evaluate(policy) else {
            print("[RealNetworkGate] configureRealMode denied: \(policy.denialReason ?? "disabled")")
            return false
        }
        let httpClient = URLSessionHTTPClient()
        let factory = ReaderCoreServiceFactory(httpClient: httpClient)
        lock.lock()
        realSearchService = factory.makeSearchService()
        realTOCService = factory.makeTOCService()
        realContentService = factory.makeContentService()
        mode = .real
        lock.unlock()
        return realSearchService != nil && realTOCService != nil && realContentService != nil
    }

    public var isRealModeAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return realSearchService != nil && realTOCService != nil && realContentService != nil
    }

    /// 当前是否允许使用 real service（需要 mode == .real 且 gate 允许）
    private var canUseRealService: Bool {
        guard mode == .real, isRealModeAvailable else { return false }
        let gate = DefaultRealNetworkGate()
        let policy = RealNetworkPolicyStore.shared.current
        return gate.evaluate(policy) == .allowed
    }

    // MARK: - Book Source Validation

    public func validateBookSource(from data: Data) async -> LoadState<BookSource> {
        do {
            var source = try JSONDecoder().decode(BookSource.self, from: data)
            if source.id == nil || source.id?.isEmpty == true {
                source.id = UUID().uuidString
            }
            return .loaded(source)
        } catch let error as DecodingError {
            return .failed(AppReaderError(
                code: .unsupported,
                message: "Invalid book source JSON: \(error.localizedDescription)",
                stage: "VALIDATE"
            ))
        } catch {
            return .failed(AppReaderError(
                code: .unknown,
                message: error.localizedDescription,
                stage: "VALIDATE"
            ))
        }
    }

    // MARK: - Search

    public func searchBooks(keyword: String, page: Int, source: BookSource? = nil) async -> LoadState<[SearchResultItem]> {
        if canUseRealService, let service = realSearchService {
            return await performRealSearch(service: service, keyword: keyword, page: page, source: source)
        }
        return await mockService.searchBooks(keyword: keyword, page: page)
    }

    private func performRealSearch(service: any SearchService, keyword: String, page: Int, source: BookSource?) async -> LoadState<[SearchResultItem]> {
        guard let source else {
            return .failed(AppReaderError(code: .unsupported, message: "No book source selected for real search", stage: "SEARCH"))
        }
        do {
            let results = try await service.search(
                source: source,
                query: SearchQuery(keyword: keyword, page: page)
            )
            if results.isEmpty {
                return .empty
            }
            return .loaded(results)
        } catch let error as AppReaderError {
            return .failed(error)
        } catch {
            return .failed(AppReaderError(code: .unknown, message: error.localizedDescription, stage: "SEARCH"))
        }
    }

    // MARK: - Book Detail

    public func getBookDetail(bookURL: String, source: BookSource? = nil) async -> LoadState<SearchResultItem> {
        if canUseRealService, let source {
            return await performRealBookDetail(bookURL: bookURL, source: source)
        }
        return await mockService.getBookDetail(bookURL: bookURL)
    }

    private func performRealBookDetail(bookURL: String, source: BookSource) async -> LoadState<SearchResultItem> {
        do {
            // Book detail is a search result item from the search list.
            // Real detail page fetch would use BookInfoParser, but for now
            // the SearchResultItem from search results carries enough metadata.
            // If a dedicated book info fetch is needed, it goes here.
            return .loaded(SearchResultItem(
                title: source.bookSourceName,
                detailURL: bookURL,
                author: nil,
                coverURL: nil,
                intro: nil
            ))
        } catch {
            return .failed(AppReaderError(code: .unknown, message: error.localizedDescription, stage: "DETAIL"))
        }
    }

    // MARK: - Chapter List (TOC)

    public func getChapterList(bookURL: String) async -> LoadState<[TOCItem]> {
        if canUseRealService, let service = realTOCService {
            return await performRealTOC(service: service, bookURL: bookURL)
        }
        return await mockService.getChapterList(bookURL: bookURL)
    }

    private func performRealTOC(service: any TOCService, bookURL: String) async -> LoadState<[TOCItem]> {
        do {
            let items = try await service.fetchTOC(
                source: BookSource(bookSourceName: "", bookSourceUrl: ""),
                detailURL: bookURL
            )
            if items.isEmpty {
                return .empty
            }
            return .loaded(items)
        } catch let error as AppReaderError {
            return .failed(error)
        } catch {
            return .failed(AppReaderError(code: .unknown, message: error.localizedDescription, stage: "TOC"))
        }
    }

    // MARK: - Chapter Content

    public func getChapterContent(chapterURL: String) async -> LoadState<ContentPage> {
        if canUseRealService, let service = realContentService {
            return await performRealContent(service: service, chapterURL: chapterURL)
        }
        return await mockService.getChapterContent(chapterURL: chapterURL)
    }

    private func performRealContent(service: any ContentService, chapterURL: String) async -> LoadState<ContentPage> {
        do {
            let page = try await service.fetchContent(
                source: BookSource(bookSourceName: "", bookSourceUrl: ""),
                chapterURL: chapterURL
            )
            return .loaded(page)
        } catch let error as AppReaderError {
            return .failed(error)
        } catch {
            return .failed(AppReaderError(code: .unknown, message: error.localizedDescription, stage: "CONTENT"))
        }
    }

    // MARK: - Mock Scenario Control

    public func setMockScenario(_ scenario: MockScenario) {
        mockService.setScenario(scenario)
    }

    public func resetMock() {
        mockService.reset()
    }
}
