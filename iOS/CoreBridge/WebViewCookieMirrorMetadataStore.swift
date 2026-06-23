import Foundation
import ReaderCoreModels

public protocol WebViewCookieMirrorMetadataWriting: Sendable {
    @discardableResult
    func saveCookieMirrorMetadata(
        request: RuntimeWebViewRequest,
        finalURL: String,
        pageCookies: [RuntimeLoginCookie],
        interactionCookies: [RuntimeLoginCookie]
    ) throws -> WebViewCookieMirrorMetadata?
}

public extension WebViewCookieMirrorMetadataWriting {
    @discardableResult
    func saveCookieMirrorMetadata(
        request: RuntimeWebViewRequest,
        result: RuntimeWebViewResult
    ) throws -> WebViewCookieMirrorMetadata? {
        try saveCookieMirrorMetadata(
            request: request,
            finalURL: result.finalUrl,
            pageCookies: result.updatedCookies,
            interactionCookies: result.interactionResults.flatMap(\.updatedCookies)
        )
    }

    @discardableResult
    func saveCookieMirrorMetadata(
        request: RuntimeWebViewRequest,
        interactionResults: [RuntimeWebViewInteractionResult]
    ) throws -> WebViewCookieMirrorMetadata? {
        try saveCookieMirrorMetadata(
            request: request,
            finalURL: request.url,
            pageCookies: [],
            interactionCookies: interactionResults.flatMap(\.updatedCookies)
        )
    }
}

public struct WebViewCookieMirrorMetadata: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let generatedAt: Date
    public let requestId: String
    public let sourceId: String
    public let stage: RuntimeStage
    public let requestedURL: WebViewCookieMirrorURLMetadata
    public let finalURL: WebViewCookieMirrorURLMetadata
    public let cookieCount: Int
    public let cookies: [WebViewCookieMirrorCookieMetadata]
    public let redaction: WebViewCookieMirrorRedaction
    public let cleanRoom: HostRuntimeCleanRoomStatement

    public init(
        schemaVersion: String = WebViewCookieMirrorMetadataStore.schemaVersion,
        generatedAt: Date,
        requestId: String,
        sourceId: String,
        stage: RuntimeStage,
        requestedURL: WebViewCookieMirrorURLMetadata,
        finalURL: WebViewCookieMirrorURLMetadata,
        cookies: [WebViewCookieMirrorCookieMetadata],
        redaction: WebViewCookieMirrorRedaction = .strict,
        cleanRoom: HostRuntimeCleanRoomStatement = .default
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.requestId = requestId
        self.sourceId = sourceId
        self.stage = stage
        self.requestedURL = requestedURL
        self.finalURL = finalURL
        self.cookieCount = cookies.count
        self.cookies = cookies
        self.redaction = redaction
        self.cleanRoom = cleanRoom
    }
}

public struct WebViewCookieMirrorURLMetadata: Codable, Equatable, Sendable {
    public let scheme: String?
    public let host: String?
    public let pathComponentCount: Int?
    public let queryRedacted: Bool

    public init(urlString: String) {
        let parsed = URL(string: urlString)
        self.scheme = parsed?.scheme
        self.host = parsed?.host
        self.pathComponentCount = parsed?.pathComponents.filter { $0 != "/" }.count
        self.queryRedacted = parsed?.query != nil
    }
}

public enum WebViewCookieMirrorObservationSource: String, Codable, Sendable {
    case pageResult = "page_result"
    case interactionResult = "interaction_result"
}

public struct WebViewCookieMirrorCookieMetadata: Codable, Equatable, Sendable {
    public let name: String
    public let domain: String
    public let path: String
    public let expiresAt: Date?
    public let secure: Bool
    public let httpOnly: Bool
    public let observationSource: WebViewCookieMirrorObservationSource
    public let valueRedacted: Bool

    public init(
        cookie: RuntimeLoginCookie,
        observationSource: WebViewCookieMirrorObservationSource
    ) {
        self.name = cookie.name
        self.domain = cookie.domain
        self.path = cookie.path.isEmpty ? "/" : cookie.path
        self.expiresAt = cookie.expiresAt
        self.secure = cookie.secure
        self.httpOnly = cookie.httpOnly
        self.observationSource = observationSource
        self.valueRedacted = true
    }
}

public struct WebViewCookieMirrorRedaction: Codable, Equatable, Sendable {
    public let applied: Bool
    public let rawCookieValuesIncluded: Bool
    public let setCookieHeadersIncluded: Bool
    public let authorizationHeadersIncluded: Bool
    public let queryStringIncluded: Bool
    public let rawHTMLIncluded: Bool
    public let redactedFields: [String]

    public static let strict = WebViewCookieMirrorRedaction(
        applied: true,
        rawCookieValuesIncluded: false,
        setCookieHeadersIncluded: false,
        authorizationHeadersIncluded: false,
        queryStringIncluded: false,
        rawHTMLIncluded: false,
        redactedFields: [
            "cookie_values",
            "set_cookie_headers",
            "authorization_headers",
            "query_string",
            "html_body"
        ]
    )
}

public final class WebViewCookieMirrorMetadataStore: WebViewCookieMirrorMetadataWriting, @unchecked Sendable {
    public static let schemaVersion = "reader-ios.webview-cookie-mirror-metadata.v1"

    public let outputURL: URL
    private let fileManager: FileManager
    private let clock: @Sendable () -> Date

    public init(
        outputURL: URL = WebViewCookieMirrorMetadataStore.defaultOutputURL(),
        fileManager: FileManager = .default,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.outputURL = outputURL
        self.fileManager = fileManager
        self.clock = clock
    }

    public static func defaultOutputURL() -> URL {
        let supportRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return supportRoot
            .appendingPathComponent("ReaderApp/HostRuntimeEvidence", isDirectory: true)
            .appendingPathComponent("cookie_mirror_metadata.json")
    }

    @discardableResult
    public func saveCookieMirrorMetadata(
        request: RuntimeWebViewRequest,
        finalURL: String,
        pageCookies: [RuntimeLoginCookie],
        interactionCookies: [RuntimeLoginCookie]
    ) throws -> WebViewCookieMirrorMetadata? {
        let cookies = Self.metadataCookies(
            pageCookies: pageCookies,
            interactionCookies: interactionCookies
        )
        guard !cookies.isEmpty else { return nil }

        let metadata = WebViewCookieMirrorMetadata(
            generatedAt: clock(),
            requestId: request.requestId,
            sourceId: request.sourceId,
            stage: request.stage,
            requestedURL: WebViewCookieMirrorURLMetadata(urlString: request.url),
            finalURL: WebViewCookieMirrorURLMetadata(urlString: finalURL),
            cookies: cookies
        )
        try fileManager.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Self.encodedData(metadata).write(to: outputURL, options: .atomic)
        return metadata
    }

    public static func encodedData(_ metadata: WebViewCookieMirrorMetadata) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(metadata)
    }

    private static func metadataCookies(
        pageCookies: [RuntimeLoginCookie],
        interactionCookies: [RuntimeLoginCookie]
    ) -> [WebViewCookieMirrorCookieMetadata] {
        let page = pageCookies.map {
            WebViewCookieMirrorCookieMetadata(cookie: $0, observationSource: .pageResult)
        }
        let interactions = interactionCookies.map {
            WebViewCookieMirrorCookieMetadata(cookie: $0, observationSource: .interactionResult)
        }
        return (page + interactions)
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { lhs, rhs in
                cookieSortKey(lhs) < cookieSortKey(rhs)
            }
    }

    private static func cookieSortKey(_ cookie: WebViewCookieMirrorCookieMetadata) -> String {
        [
            cookie.domain.lowercased(),
            cookie.path,
            cookie.name,
            cookie.observationSource.rawValue
        ].joined(separator: "|")
    }
}
