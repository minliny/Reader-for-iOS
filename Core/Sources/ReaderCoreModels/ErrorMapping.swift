import Foundation

public enum ErrorMappingInput: Equatable, Sendable {
    case httpStatus(Int)
    case networkError(String?)
    case timeout
    case emptyResponse
    case selectorMiss(String)
}

public struct ErrorMappingResult: Equatable, Sendable {
    public var failureType: FailureType
    public var errorCode: ReaderErrorCode
    public var message: String

    public init(failureType: FailureType, errorCode: ReaderErrorCode, message: String) {
        self.failureType = failureType
        self.errorCode = errorCode
        self.message = message
    }
}

public enum ErrorMapper {
    public static func map(_ input: ErrorMappingInput) -> ErrorMappingResult {
        switch input {
        case .httpStatus(401), .httpStatus(403):
            return ErrorMappingResult(
                failureType: .NETWORK_POLICY_MISMATCH,
                errorCode: .networkFailed,
                message: "HTTP status requires authorization or violates network policy."
            )
        case .httpStatus(404):
            return ErrorMappingResult(
                failureType: .CONTENT_FAILED,
                errorCode: .networkFailed,
                message: "HTTP 404 content fetch failed."
            )
        case .httpStatus(let status):
            return ErrorMappingResult(
                failureType: .CONTENT_FAILED,
                errorCode: .networkFailed,
                message: "Unhandled HTTP status: \(status)."
            )
        case .networkError(let detail):
            return ErrorMappingResult(
                failureType: .CONTENT_FAILED,
                errorCode: .networkFailed,
                message: detail.map { "Content fetch failed: \($0)" } ?? "Content fetch failed."
            )
        case .timeout:
            return ErrorMappingResult(
                failureType: .CONTENT_FAILED,
                errorCode: .networkFailed,
                message: "Content fetch timed out."
            )
        case .emptyResponse:
            return ErrorMappingResult(
                failureType: .CONTENT_FAILED,
                errorCode: .parsingFailed,
                message: "Response body is empty."
            )
        case .selectorMiss(let selector):
            return ErrorMappingResult(
                failureType: .RULE_INVALID,
                errorCode: .parsingFailed,
                message: "Selector did not match: \(selector)."
            )
        }
    }

    public static func readerError(for input: ErrorMappingInput) -> ReaderError {
        let mapped = map(input)
        return ReaderError(
            code: mapped.errorCode,
            message: mapped.message,
            failure: FailureRecord(type: mapped.failureType, reason: "error_mapping", detail: mapped.message),
            context: ["contract": "error_mapping"]
        )
    }
}
