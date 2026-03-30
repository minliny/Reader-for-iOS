import Foundation

public enum ReaderErrorCode: String, Codable, Sendable {
    case invalidInput
    case decodeFailed
    case networkFailed
    case parsingFailed
    case unsupported
    case unknown
}

public struct ReaderError: Error, Codable, Equatable, Sendable {
    public var code: ReaderErrorCode
    public var message: String
    public var failure: FailureRecord?
    public var context: [String: String]

    public init(
        code: ReaderErrorCode,
        message: String,
        failure: FailureRecord? = nil,
        context: [String: String] = [:]
    ) {
        self.code = code
        self.message = message
        self.failure = failure
        self.context = context
    }

    public static func network(
        failureType: FailureType,
        stage: String,
        message: String,
        underlyingError: Error? = nil
    ) -> ReaderError {
        var ctx: [String: String] = [:]
        if let err = underlyingError {
            ctx["underlying"] = String(describing: err)
        }
        return ReaderError(
            code: .networkFailed,
            message: message,
            failure: FailureRecord(type: failureType, reason: stage, detail: message),
            context: ctx
        )
    }

    public static func config(
        failureType: FailureType,
        stage: String,
        ruleField: String? = nil,
        message: String,
        underlyingError: Error? = nil
    ) -> ReaderError {
        var ctx: [String: String] = [:]
        if let f = ruleField {
            ctx["ruleField"] = f
        }
        if let err = underlyingError {
            ctx["underlying"] = String(describing: err)
        }
        return ReaderError(
            code: .invalidInput,
            message: message,
            failure: FailureRecord(type: failureType, reason: stage, detail: message),
            context: ctx
        )
    }
}
