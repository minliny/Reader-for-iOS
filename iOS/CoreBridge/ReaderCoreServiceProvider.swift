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
        lock.lock()
        let currentMode = self.mode
        lock.unlock()

        switch currentMode {
        case .mock:
            return await mockService.validateBookSource(from: data)
        case .real:
            return .unsupported(reason: "Real Core service not available in placeholder implementation")
        }
    }

    public func searchBooks(keyword: String, page: Int) async -> LoadState<[SearchResultItem]> {
        lock.lock()
        let currentMode = self.mode
        lock.unlock()

        switch currentMode {
        case .mock:
            return await mockService.searchBooks(keyword: keyword, page: page)
        case .real:
            return .unsupported(reason: "Real Core service not available in placeholder implementation")
        }
    }

    public func getBookDetail(bookURL: String) async -> LoadState<SearchResultItem> {
        lock.lock()
        let currentMode = self.mode
        lock.unlock()

        switch currentMode {
        case .mock:
            return await mockService.getBookDetail(bookURL: bookURL)
        case .real:
            return .unsupported(reason: "Real Core service not available in placeholder implementation")
        }
    }

    public func getChapterList(bookURL: String) async -> LoadState<[TOCItem]> {
        lock.lock()
        let currentMode = self.mode
        lock.unlock()

        switch currentMode {
        case .mock:
            return await mockService.getChapterList(bookURL: bookURL)
        case .real:
            return .unsupported(reason: "Real Core service not available in placeholder implementation")
        }
    }

    public func getChapterContent(chapterURL: String) async -> LoadState<ContentPage> {
        lock.lock()
        let currentMode = self.mode
        lock.unlock()

        switch currentMode {
        case .mock:
            return await mockService.getChapterContent(chapterURL: chapterURL)
        case .real:
            return .unsupported(reason: "Real Core service not available in placeholder implementation")
        }
    }

    public func setMockScenario(_ scenario: MockScenario) {
        mockService.setScenario(scenario)
    }

    public func resetMock() {
        mockService.reset()
    }
}
