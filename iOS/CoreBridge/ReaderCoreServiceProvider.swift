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

    public func configureRealMode() -> Bool {
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

    public func searchBooks(keyword: String, page: Int) async -> LoadState<[SearchResultItem]> {
        if mode == .real, let service = realSearchService {
            return await performRealSearch(service: service, keyword: keyword, page: page)
        }
        return await mockService.searchBooks(keyword: keyword, page: page)
    }

    private func performRealSearch(service: any SearchService, keyword: String, page: Int) async -> LoadState<[SearchResultItem]> {
        do {
            let results = try await service.search(
                source: BookSource(bookSourceName: "", bookSourceUrl: ""),
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

    public func getBookDetail(bookURL: String) async -> LoadState<SearchResultItem> {
        await mockService.getBookDetail(bookURL: bookURL)
    }

    // MARK: - Chapter List (TOC)

    public func getChapterList(bookURL: String) async -> LoadState<[TOCItem]> {
        if mode == .real, let service = realTOCService {
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
        if mode == .real, let service = realContentService {
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
