import Foundation

public struct ReaderOnlineSource: Identifiable, Hashable, Sendable {
    public let sourceId: String
    public let name: String
    public let baseURL: String
    public let enabled: Bool
    public let version: String
    public let group: String
    public let definition: Data
    public var id: String { sourceId }
}
public struct ReaderOnlineCandidate: Codable, Hashable, Sendable, Identifiable {
    public let sourceId: String
    public let bookId: String
    public let title: String
    public let author: String
    public let coverUrl: String?
    public let coreBook: Data?
    public var id: String { sourceId + "|" + bookId }
    public init(sourceId: String, bookId: String, title: String, author: String = "", coverUrl: String? = nil, coreBook: Data? = nil) {
        self.sourceId = sourceId; self.bookId = bookId; self.title = title; self.author = author; self.coverUrl = coverUrl
        self.coreBook = coreBook
    }
}
public struct ReaderSourceSearchResult: Sendable {
    public let sourceId: String
    public let books: [ReaderOnlineCandidate]
    public let elapsedMilliseconds: Int
    public let timing: Data?
}
public struct ReaderOnlineDetail: Sendable {
    public let book: ReaderBook
    public let chapters: [ReaderChapter]
    public let firstReadableIndex: UInt32
}
public struct ReaderSourceImportItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let succeeded: Bool
    public let message: String
}
public struct ReaderSourceSubscription: Codable, Hashable, Sendable, Identifiable {
    public let id: Int64
    public let name: String
    public let url: String
    public let type: Int32
    public let customOrder: Int32
    public let autoUpdate: Bool
    public let update: Int64
}
public protocol ReaderOnlineServing: ReaderLibraryServing {
    func onlineSources() async throws -> [ReaderOnlineSource]
    func importSources(_ data: Data, operationID: String) async throws -> [ReaderSourceImportItem]
    func validateSources(_ data: Data) async throws -> [ReaderSourceImportItem]
    func exportSources(_ identities: [String]?) async throws -> Data
    func updateSource(_ sourceID: String, enabled: Bool, operationID: String) async throws
    func deleteSource(_ sourceID: String, operationID: String) async throws
    func searchSource(_ sourceID: String, keyword: String, page: Int) async throws -> ReaderSourceSearchResult
    func onlineDetail(_ candidate: ReaderOnlineCandidate) async throws -> ReaderOnlineDetail
    func refreshOnlineCatalog(for book: ReaderBook) async throws -> ReaderOnlineDetail
    func addOnlineBook(_ detail: ReaderOnlineDetail, chapterIndex: UInt32, operationID: String) async throws -> ReaderBook
    func onlineDiagnostic(_ sourceID: String, keyword: String) async throws -> Data
    func onlineFetch(_ url: URL) async throws -> Data
    func onlineCommand(_ method: String, parameters: Data, operationID: String?) async throws -> Data
    func prepareLogin(_ sourceID: String) async throws -> [HTTPCookie]
    func completeLogin(_ sourceID: String, cookies: [HTTPCookie], originalCookies: [HTTPCookie]) async throws
}
