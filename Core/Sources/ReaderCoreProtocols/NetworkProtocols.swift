import Foundation
import ReaderCoreModels

public struct HTTPRequest: Sendable, Equatable {
    public var url: String
    public var method: String
    public var headers: [String: String]
    public var body: Data?
    public var timeout: TimeInterval
    public var useCookieJar: Bool

    public init(
        url: String,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 15,
        useCookieJar: Bool = false
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.useCookieJar = useCookieJar
    }
}

public struct HTTPResponse: Sendable, Equatable {
    public var statusCode: Int
    public var headers: [String: String]
    public var data: Data

    public init(statusCode: Int, headers: [String: String], data: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }
}

public protocol HTTPClient: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public protocol RequestBuilder: Sendable {
    func makeSearchRequest(source: BookSource, query: SearchQuery) throws -> HTTPRequest
    func makeTOCRequest(source: BookSource, detailURL: String) throws -> HTTPRequest
    func makeContentRequest(source: BookSource, chapterURL: String) throws -> HTTPRequest
}
