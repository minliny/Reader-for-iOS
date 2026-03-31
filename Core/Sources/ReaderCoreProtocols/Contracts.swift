import Foundation
import ReaderCoreModels

public protocol BookSourceRepository: Sendable {
    func save(_ source: BookSource) async throws
    func allSources() async throws -> [BookSource]
    func source(id: String) async throws -> BookSource?
}

public protocol BookSourceDecoder: Sendable {
    func decodeBookSource(from data: Data) throws -> BookSource
}

public protocol SearchService: Sendable {
    func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem]
}

public protocol TOCService: Sendable {
    func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem]
}

public protocol ContentService: Sendable {
    func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage
}
