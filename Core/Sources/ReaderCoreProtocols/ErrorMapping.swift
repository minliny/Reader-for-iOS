import Foundation

// MARK: - ReaderErrorCode
// Fine-grained, stable error codes for the mapping contract layer.
// Distinct from ReaderCoreModels.ReaderErrorCode (coarse-grained legacy type).
// Use these values in test assertions instead of message strings.

public enum ReaderErrorCode: String, Codable, Equatable, Sendable {
    case NETWORK_TIMEOUT
    case NETWORK_UNREACHABLE
    case HTTP_STATUS_INVALID
    case REDIRECT_NOT_HANDLED
    case HEADER_REQUIRED
    case COOKIE_REQUIRED
    case RESPONSE_EMPTY
    case RESPONSE_DECODING_FAILED
    case SEARCH_PARSE_FAILED
    case TOC_PARSE_FAILED
    case CONTENT_PARSE_FAILED
    case RULE_UNSUPPORTED
    case POLICY_REJECTED
    case UNKNOWN
}

// MARK: - ReaderFailureStage

public enum ReaderFailureStage: String, Codable, Equatable, Sendable {
    case request_build
    case network_transport
    case response_validation
    case decode
    case search_parse
    case toc_parse
    case content_parse
    case policy_check
    case cache_lookup
    case cache_store
}

// MARK: - ReaderErrorContext

public struct ReaderErrorContext: Codable, Equatable, Sendable {
    public var sampleId: String?
    public var sourceURL: String?
    public var statusCode: Int?
    public var details: [String: String]

    public init(
        sampleId: String? = nil,
        sourceURL: String? = nil,
        statusCode: Int? = nil,
        details: [String: String] = [:]
    ) {
        self.sampleId = sampleId
        self.sourceURL = sourceURL
        self.statusCode = statusCode
        self.details = details
    }
}

// MARK: - MappedReaderError
// Contract-level error type. Carries a stable fine-grained ReaderErrorCode
// that can be asserted in tests without relying on message strings.
//
// Named MappedReaderError (not ReaderError) to avoid ambiguity with the
// legacy ReaderCoreModels.ReaderError that coexists in the same process.

public struct MappedReaderError: Error, Codable, Equatable, Sendable {
    public var code: ReaderErrorCode
    public var stage: ReaderFailureStage
    public var message: String
    public var context: ReaderErrorContext

    public init(
        code: ReaderErrorCode,
        stage: ReaderFailureStage,
        message: String,
        context: ReaderErrorContext = ReaderErrorContext()
    ) {
        self.code = code
        self.stage = stage
        self.message = message
        self.context = context
    }
}
