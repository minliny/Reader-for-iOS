import Foundation

public enum FailureType: String, Codable, CaseIterable, Sendable {
    case JSON_INVALID
    case FIELD_MISSING
    case RULE_INVALID
    case RULE_UNSUPPORTED
    case SEARCH_FAILED
    case TOC_FAILED
    case CONTENT_FAILED
    case NETWORK_POLICY_MISMATCH
    case COOKIE_REQUIRED
    case LOGIN_REQUIRED
    case JS_DEGRADED
    case JS_UNSUPPORTED
    case OUTPUT_MISMATCH
    case CRASH
}

public enum Stage: String, Codable, Sendable {
    case NETWORK
    case REQUEST_BUILD
    case RESPONSE_PARSE
    case SEARCH_PARSE
    case TOC_PARSE
    case CONTENT_PARSE
}

public struct FailureRecord: Codable, Equatable, Sendable {
    public var type: FailureType
    public var reason: String
    public var sampleId: String?
    public var detail: String?

    public init(type: FailureType, reason: String, sampleId: String? = nil, detail: String? = nil) {
        self.type = type
        self.reason = reason
        self.sampleId = sampleId
        self.detail = detail
    }
}
