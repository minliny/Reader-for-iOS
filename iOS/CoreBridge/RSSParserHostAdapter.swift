import Foundation
import ReaderCoreModels
#if !READER_IOS_SHELL_CI
import ReaderCoreParser  // Designated seam (check_ios_boundary.sh whitelist): CoreBridge is the sole permitted import site.
#endif
import ReaderCoreProtocols

public enum RSSParserHostAdapterError: Error, Equatable, LocalizedError, Sendable {
    case parserUnavailableInShellCI

    public var errorDescription: String? {
        switch self {
        case .parserUnavailableInShellCI:
            return "RSS parser host adapter is unavailable in shell CI."
        }
    }
}

/// Host adapter that bridges the Core `RSSParser` (from `ReaderCoreParser`)
/// behind the `ReaderCoreFeedParserAdapter` protocol so that iOS layers under
/// the boundary gate (`CoreIntegration`, `Features`, `Shell`, `Tests`, etc.)
/// can consume feed parsing without directly importing `ReaderCoreParser`.
///
/// This file lives in `iOS/CoreBridge`, which is outside the boundary-gated
/// paths enforced by `scripts/check_ios_boundary.sh`, so it is the designated
/// seam where Core parser imports are permitted on the iOS side.
public struct RSSParserHostAdapter: ReaderCoreFeedParserAdapter {
    public let descriptor: ReaderCorePlatformAdapterDescriptor

    public init(
        descriptor: ReaderCorePlatformAdapterDescriptor = ReaderCorePlatformAdapterDescriptor(
            adapterIdentifier: "reader-ios.rss-parser-host",
            adapterVersion: "0.1.0",
            kind: .feedParser,
            supportedFeatureIDs: ["feed.rss", "feed.atom", "feed.json", "feed.default", "feed.pagination.nextURL"],
            platformFamilies: ["iOS"],
            isAvailable: true,
            failClosedByDefault: true,
            cleanRoomMaintained: true
        )
    ) {
        self.descriptor = descriptor
    }

    public func parseFeed(_ request: ReaderCoreFeedParseRequest) async throws -> ReaderCoreFeedParseResult {
        #if READER_IOS_SHELL_CI
        throw RSSParserHostAdapterError.parserUnavailableInShellCI
        #else
        return RSSParser().parseFeed(request)
        #endif
    }
}
