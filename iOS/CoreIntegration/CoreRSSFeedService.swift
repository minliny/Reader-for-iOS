import Foundation
import ReaderCoreModels
import ReaderCoreParser
import ReaderCoreProtocols

public struct CoreRSSFeedSummary: Equatable, Sendable {
    public var source: RSSSource
    public var format: ReaderCoreFeedFormat
    public var items: [SubscriptionItem]
    public var nextPageURL: String?
    public var diagnostics: [String]
    public var cleanRoomMaintained: Bool
    public var externalGPLCodeCopied: Bool

    public init(
        source: RSSSource,
        format: ReaderCoreFeedFormat,
        items: [SubscriptionItem],
        nextPageURL: String?,
        diagnostics: [String],
        cleanRoomMaintained: Bool = true,
        externalGPLCodeCopied: Bool = false
    ) {
        self.source = source
        self.format = format
        self.items = items
        self.nextPageURL = nextPageURL
        self.diagnostics = diagnostics
        self.cleanRoomMaintained = cleanRoomMaintained
        self.externalGPLCodeCopied = externalGPLCodeCopied
    }
}

public enum CoreRSSFeedBridgeError: Error, Equatable, LocalizedError, Sendable {
    case invalidURL(String)
    case emptyFeed
    case unexpectedHTTPStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Invalid RSS URL: \(value)"
        case .emptyFeed:
            return "RSS feed is empty."
        case .unexpectedHTTPStatus(let status):
            return "RSS feed request failed with HTTP \(status)."
        }
    }
}

public protocol CoreRSSFeedLoading: Sendable {
    func parseFeed(data: Data, source: RSSSource) async throws -> CoreRSSFeedSummary
    func fetchAndParse(source: RSSSource) async throws -> CoreRSSFeedSummary
}

public struct CoreRSSFeedService: CoreRSSFeedLoading {
    public init() {}

    public func parseFeed(data: Data, source: RSSSource) async throws -> CoreRSSFeedSummary {
        guard !data.isEmpty else {
            throw CoreRSSFeedBridgeError.emptyFeed
        }
        let result = RSSParser().parseFeed(
            ReaderCoreFeedParseRequest(
                data: data,
                sourceURL: source.url,
                source: source
            )
        )
        return CoreRSSFeedSummary(
            source: source,
            format: result.format,
            items: result.items,
            nextPageURL: result.nextPageURL,
            diagnostics: result.diagnostics
        )
    }

    public func fetchAndParse(source: RSSSource) async throws -> CoreRSSFeedSummary {
        let trimmed = source.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            throw CoreRSSFeedBridgeError.invalidURL(source.url)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/rss+xml, application/atom+xml, application/feed+json, application/json, text/xml, */*", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw CoreRSSFeedBridgeError.unexpectedHTTPStatus(http.statusCode)
        }
        return try await parseFeed(data: data, source: source)
    }
}
