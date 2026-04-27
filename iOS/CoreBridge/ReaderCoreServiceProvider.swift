import Foundation
import ReaderCoreModels

public enum ServiceMode: Sendable {
    case mock
    case real
}

public final class ReaderCoreServiceProvider: @unchecked Sendable {
    public static let shared = ReaderCoreServiceProvider()

    private var mode: ServiceMode = .mock
    private let lock = NSLock()
    private let mockService: MockReaderCoreService

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

    public func validateBookSource(from data: Data) async -> LoadState<BookSource> {
        await mockService.validateBookSource(from: data)
    }

    public func searchBooks(keyword: String, page: Int) async -> LoadState<[SearchResultItem]> {
        await mockService.searchBooks(keyword: keyword, page: page)
    }

    public func getBookDetail(bookURL: String) async -> LoadState<SearchResultItem> {
        await mockService.getBookDetail(bookURL: bookURL)
    }

    public func getChapterList(bookURL: String) async -> LoadState<[TOCItem]> {
        await mockService.getChapterList(bookURL: bookURL)
    }

    public func getChapterContent(chapterURL: String) async -> LoadState<ContentPage> {
        await mockService.getChapterContent(chapterURL: chapterURL)
    }

    public func setMockScenario(_ scenario: MockScenario) {
        mockService.setScenario(scenario)
    }

    public func resetMock() {
        mockService.reset()
    }
}
