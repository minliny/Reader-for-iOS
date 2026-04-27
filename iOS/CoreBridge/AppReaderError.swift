import Foundation
import ReaderCoreModels

public struct AppReaderError: Error, Sendable {
    public enum Code: Sendable {
        case unknown
        case network
        case parser
        case jsRequired
        case loginRequired
        case unsupported
        case partial
        case timeout
        case notFound
        case invalidResponse
    }

    public let code: Code
    public let message: String
    public let stage: String?
    public let underlyingError: Error?

    public init(
        code: Code,
        message: String,
        stage: String? = nil,
        underlyingError: Error? = nil
    ) {
        self.code = code
        self.message = message
        self.stage = stage
        self.underlyingError = underlyingError
    }
}

extension AppReaderError: CustomStringConvertible {
    public var description: String {
        var result = "AppReaderError.\(code)"
        if !message.isEmpty {
            result += ": \(message)"
        }
        if let stage = stage {
            result += " [\(stage)]"
        }
        return result
    }
}
