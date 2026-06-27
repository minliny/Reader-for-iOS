import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreServices
#if canImport(ReaderCoreNativeAdapter)
import ReaderCoreNativeAdapter
#endif

public enum ServiceMode: Sendable {
    case mock
    case offlineReplay
    case controlledOnlineDryRun
    case controlledOnline
    case real
    case rustCore
}

@MainActor
public final class ReaderCoreServiceProvider: @unchecked Sendable {
    public static let shared = ReaderCoreServiceProvider()

    private var mode: ServiceMode = .mock
    private let lock = NSLock()
    private let mockService: MockReaderCoreService
    private let offlineReplayService: OfflineReplayService
    private let networkController: NetworkAccessController
    private let snapshotStore: SnapshotStore

    private var realSearchService: (any SearchService)?
    private var realTOCService: (any TOCService)?
    private var realContentService: (any ContentService)?
    #if canImport(ReaderCoreNativeAdapter)
    private var rustCoreSearchService: (any SearchService)?
    private var rustCoreTOCService: (any TOCService)?
    private var rustCoreContentService: (any ContentService)?
    #endif

    private init() {
        self.mockService = MockReaderCoreService.shared
        self.offlineReplayService = OfflineReplayService.shared
        let snapRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ReaderApp/Snapshots", isDirectory: true)
        self.snapshotStore = SnapshotStore(snapshotRoot: snapRoot)
        self.networkController = NetworkAccessController()
    }

    /// 切换到 offline replay 模式
    public func enableOfflineReplay() {
        lock.lock()
        defer { lock.unlock() }
        self.mode = .offlineReplay
    }

    /// 切换到 controlledOnlineDryRun 模式（dry-run，不执行真实网络）
    public func enableControlledOnlineDryRun() {
        lock.lock()
        defer { lock.unlock() }
        self.mode = .controlledOnlineDryRun
    }

    /// 切换到 controlledOnline 模式（通过 NetworkAccessController + real service）
    public func enableControlledOnline() {
        lock.lock()
        defer { lock.unlock() }
        self.mode = .controlledOnline
    }

    /// 为 controlledOnline 注入 real search service（测试用 fake/spy）
    public func setControlledOnlineSearchService(_ service: any SearchService) {
        lock.lock()
        defer { lock.unlock() }
        self.realSearchService = service
    }

    /// 为 controlledOnline 注入 real TOC service（测试用 fake/spy）
    public func setControlledOnlineTOCService(_ service: any TOCService) {
        lock.lock()
        defer { lock.unlock() }
        self.realTOCService = service
    }

    /// 为 controlledOnline 注入 real content service（测试用 fake/spy）
    public func setControlledOnlineContentService(_ service: any ContentService) {
        lock.lock()
        defer { lock.unlock() }
        self.realContentService = service
    }

    /// M2: 通过 NetworkAccessController 创建全部 real service（不走 RealNetworkGate）
    public func prepareControlledOnlineAllServices() -> Bool {
        let policy = SourceNetworkPolicy.m1Candidate
        let userPref = UserNetworkPreference.productDefault
        let decision = networkController.evaluate(userPreference: userPref, sourcePolicy: policy, operation: .search)
        guard case .allowed = decision else {
            print("[M2] controlledOnline services denied: \(decision)")
            return false
        }
        let httpClient = URLSessionHTTPClient()
        let factory = ReaderCoreServiceFactory(httpClient: httpClient)
        lock.lock()
        realSearchService = factory.makeSearchService()
        realTOCService = factory.makeTOCService()
        realContentService = factory.makeContentService()
        lock.unlock()
        return realSearchService != nil && realTOCService != nil && realContentService != nil
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

    #if canImport(ReaderCoreNativeAdapter)
    /// S6.1: Boot Rust Core runtime and wire RustCore*Service adapters.
    /// Returns true if rustCore mode is ready.
    @discardableResult
    public func configureRustCoreMode() -> Bool {
        if !RustCoreRuntimeHolder.shared.isBooted {
            do {
                try RustCoreRuntimeHolder.shared.boot()
            } catch {
                print("[RustCore] boot failed: \(error)")
                return false
            }
        }
        guard let runtime = RustCoreRuntimeHolder.shared.current else {
            return false
        }
        lock.lock()
        rustCoreSearchService = RustCoreSearchService(runtime: runtime)
        rustCoreTOCService = RustCoreTOCService(runtime: runtime)
        rustCoreContentService = RustCoreContentService(runtime: runtime)
        mode = .rustCore
        lock.unlock()
        return rustCoreSearchService != nil
    }
    #endif

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
        #if canImport(ReaderCoreNativeAdapter)
        if mode == .rustCore, let service = rustCoreSearchService, let source {
            do {
                let results = try await service.search(source: source, query: SearchQuery(keyword: keyword, page: page))
                return results.isEmpty ? .empty : .loaded(results)
            } catch let error as AppReaderError {
                return .failed(error)
            } catch {
                return .failed(AppReaderError(code: .unknown, message: error.localizedDescription, stage: "SEARCH"))
            }
        }
        #endif
        if canUseRealService, let service = realSearchService {
            return await performRealSearch(service: service, keyword: keyword, page: page, source: source)
        }
        if mode == .controlledOnline {
            return await performControlledOnlineSearch(keyword: keyword, page: page, source: source, useRealService: true)
        }
        if mode == .controlledOnlineDryRun {
            return await performControlledOnlineSearch(keyword: keyword, page: page, source: source, useRealService: false)
        }
        if mode == .offlineReplay {
            return await offlineReplayService.searchBooks(keyword: keyword, page: page)
        }
        return await mockService.searchBooks(keyword: keyword, page: page)
    }

    /// controlledOnline / controlledOnlineDryRun: 通过 NetworkAccessController 检查
    private func performControlledOnlineSearch(keyword: String, page: Int, source: BookSource?, useRealService: Bool) async -> LoadState<[SearchResultItem]> {
        let sourcePolicy = networkPolicy(for: source, fallback: .m1Candidate)
        let userPref = useRealService ? UserNetworkPreference.productDefault : UserNetworkPreference.safeDefault
        let decision = networkController.evaluate(userPreference: userPref, sourcePolicy: sourcePolicy, operation: .search)
        switch decision {
        case .allowed:
            if useRealService, let svc = realSearchService {
                do {
                    let resolvedSource = source ?? bookSource(from: sourcePolicy)
                    let results = try await svc.search(source: resolvedSource, query: SearchQuery(keyword: keyword, page: page))
                    // M1.3: Save search snapshot
                    if !results.isEmpty {
                        let snapItems = results.map { SearchSnapshotItem(from: $0) }
                        _ = snapshotStore.saveSearchSnapshot(
                            sourceId: sourcePolicy.sourceId, sourceName: sourcePolicy.sourceName,
                            host: sourcePolicy.host, keyword: keyword,
                            results: snapItems, networkTriggered: true
                        )
                    }
                    return results.isEmpty ? .empty : .loaded(results)
                } catch {
                    return .failed(AppReaderError(code: .unknown, message: error.localizedDescription, stage: "SEARCH"))
                }
            }
            return await offlineReplayService.searchBooks(keyword: keyword, page: page)
        case .fallbackToCache:
            return await offlineReplayService.searchBooks(keyword: keyword, page: page)
        case .denied(_, let fallback):
            if fallback == .offlineReplay || fallback == .mock {
                return await offlineReplayService.searchBooks(keyword: keyword, page: page)
            }
            return await mockService.searchBooks(keyword: keyword, page: page)
        }
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
        if mode == .controlledOnline, realSearchService != nil {
            let policy = networkPolicy(for: source, fallback: .m1Candidate)
            let decision = networkController.evaluate(userPreference: .productDefault, sourcePolicy: policy, operation: .detail)
            if case .allowed = decision {
                let result = await performRealBookDetail(bookURL: bookURL, source: source ?? bookSource(from: policy))
                if case .loaded(let detail) = result {
                    _ = snapshotStore.saveDetailSnapshot(sourceId: policy.sourceId, sourceName: policy.sourceName, host: policy.host, bookURL: bookURL, title: detail.title, author: detail.author, intro: detail.intro, coverURL: detail.coverURL)
                }
                return result
            }
        }
        if mode == .controlledOnlineDryRun || mode == .controlledOnline || mode == .offlineReplay {
            return await offlineReplayService.getBookDetail(bookURL: bookURL)
        }
        return await mockService.getBookDetail(bookURL: bookURL)
    }

    private func performRealBookDetail(bookURL: String, source: BookSource) async -> LoadState<SearchResultItem> {
        // Book detail is a search result item from the search list. A dedicated
        // book info fetch can be introduced here once that Core API is wired.
        return .loaded(SearchResultItem(
            title: source.bookSourceName,
            detailURL: bookURL,
            author: nil,
            coverURL: nil,
            intro: nil
        ))
    }

    // MARK: - Chapter List (TOC)

    public func getChapterList(bookURL: String, source: BookSource? = nil) async -> LoadState<[TOCItem]> {
        #if canImport(ReaderCoreNativeAdapter)
        if mode == .rustCore, let service = rustCoreTOCService, let source {
            do {
                let items = try await service.fetchTOC(source: source, detailURL: bookURL)
                return items.isEmpty ? .empty : .loaded(items)
            } catch let error as AppReaderError {
                return .failed(error)
            } catch {
                return .failed(AppReaderError(code: .unknown, message: error.localizedDescription, stage: "TOC"))
            }
        }
        #endif
        if canUseRealService, let service = realTOCService {
            guard let source else {
                return .failed(AppReaderError(code: .unsupported, message: "No book source selected for real TOC", stage: "TOC"))
            }
            return await performRealTOC(service: service, bookURL: bookURL, source: source)
        }
        if mode == .controlledOnline, let service = realTOCService {
            let policy = networkPolicy(for: source, fallback: .m1Candidate)
            let decision = networkController.evaluate(userPreference: .productDefault, sourcePolicy: policy, operation: .toc)
            if case .allowed = decision {
                let result = await performRealTOC(service: service, bookURL: bookURL, source: source ?? bookSource(from: policy))
                if case .loaded(let chapters) = result, !chapters.isEmpty {
                    let items = chapters.map { TOCSnapshotItem(chapterTitle: $0.chapterTitle, chapterURL: $0.chapterURL, index: $0.chapterIndex) }
                    _ = snapshotStore.saveTOCSnapshot(sourceId: policy.sourceId, sourceName: policy.sourceName, host: policy.host, bookURL: bookURL, chapters: items)
                }
                return result
            }
        }
        if mode == .controlledOnlineDryRun || mode == .controlledOnline || mode == .offlineReplay {
            return await offlineReplayService.getChapterList(bookURL: bookURL)
        }
        return await mockService.getChapterList(bookURL: bookURL)
    }

    private func performRealTOC(service: any TOCService, bookURL: String, source: BookSource) async -> LoadState<[TOCItem]> {
        do {
            let items = try await service.fetchTOC(
                source: source,
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

    public func getChapterContent(chapterURL: String, source: BookSource? = nil) async -> LoadState<ContentPage> {
        #if canImport(ReaderCoreNativeAdapter)
        if mode == .rustCore, let service = rustCoreContentService, let source {
            do {
                let page = try await service.fetchContent(source: source, chapterURL: chapterURL)
                return .loaded(page)
            } catch let error as AppReaderError {
                return .failed(error)
            } catch {
                return .failed(AppReaderError(code: .unknown, message: error.localizedDescription, stage: "CONTENT"))
            }
        }
        #endif
        if canUseRealService, let service = realContentService {
            guard let source else {
                return .failed(AppReaderError(code: .unsupported, message: "No book source selected for real content", stage: "CONTENT"))
            }
            return await performRealContent(service: service, chapterURL: chapterURL, source: source)
        }
        if mode == .controlledOnline, let service = realContentService {
            let policy = networkPolicy(for: source, fallback: .m1Candidate)
            let decision = networkController.evaluate(userPreference: .productDefault, sourcePolicy: policy, operation: .content)
            if case .allowed = decision {
                let result = await performRealContent(service: service, chapterURL: chapterURL, source: source ?? bookSource(from: policy))
                if case .loaded(let page) = result {
                    _ = snapshotStore.saveContentSnapshot(sourceId: policy.sourceId, sourceName: policy.sourceName, host: policy.host, chapterURL: page.chapterURL, chapterTitle: page.title, content: page.content, nextChapterURL: page.nextChapterURL)
                }
                return result
            }
        }
        if mode == .controlledOnlineDryRun || mode == .controlledOnline || mode == .offlineReplay {
            return await offlineReplayService.getChapterContent(chapterURL: chapterURL)
        }
        return await mockService.getChapterContent(chapterURL: chapterURL)
    }

    private func performRealContent(service: any ContentService, chapterURL: String, source: BookSource) async -> LoadState<ContentPage> {
        do {
            let page = try await service.fetchContent(
                source: source,
                chapterURL: chapterURL
            )
            return .loaded(page)
        } catch let error as AppReaderError {
            return .failed(error)
        } catch {
            return .failed(AppReaderError(code: .unknown, message: error.localizedDescription, stage: "CONTENT"))
        }
    }

    private func networkPolicy(for source: BookSource?, fallback: SourceNetworkPolicy) -> SourceNetworkPolicy {
        guard let source else { return fallback }
        return SourceNetworkPolicy(
            sourceId: source.id?.isEmpty == false ? source.id! : fallback.sourceId,
            sourceName: source.bookSourceName.isEmpty ? fallback.sourceName : source.bookSourceName,
            host: host(for: source) ?? fallback.host,
            isEnabled: source.enabled,
            allowSearch: true,
            allowDetail: true,
            allowTOC: true,
            allowContent: true,
            cooldownSeconds: fallback.cooldownSeconds,
            lastRequestAt: nil,
            riskLevel: fallback.riskLevel
        )
    }

    private func bookSource(from policy: SourceNetworkPolicy) -> BookSource {
        BookSource(
            id: policy.sourceId,
            bookSourceName: policy.sourceName,
            bookSourceUrl: "https://\(policy.host)",
            enabled: policy.isEnabled
        )
    }

    private func host(for source: BookSource) -> String? {
        guard let sourceURL = source.bookSourceUrl, !sourceURL.isEmpty else { return nil }
        if let host = URL(string: sourceURL)?.host, !host.isEmpty {
            return host
        }
        return sourceURL
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .split(separator: "/")
            .first
            .map(String.init)
    }

    // MARK: - Mock Scenario Control

    public func setMockScenario(_ scenario: MockScenario) {
        mockService.setScenario(scenario)
    }

    public func resetMock() {
        mockService.reset()
    }
}
