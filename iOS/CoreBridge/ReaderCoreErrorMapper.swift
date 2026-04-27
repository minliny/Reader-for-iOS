import Foundation
import ReaderCoreModels

public enum ReaderCoreErrorMapper {
    public static func map(_ error: ReaderError) -> AppReaderError {
        AppReaderError.from(readerError: error)
    }

    public static func mapNonJSEngineError(_ error: Error, stage: String?) -> AppReaderError {
        if let readerError = error as? ReaderError {
            return map(readerError)
        }

        let errorCode: AppReaderError.Code
        let errorMessage = error.localizedDescription

        if errorMessage.contains("JS") || errorMessage.contains("JavaScript") {
            errorCode = .jsRequired
        } else if errorMessage.contains("login") || errorMessage.contains("登录") || errorMessage.contains("Unauthorized") {
            errorCode = .loginRequired
        } else if errorMessage.contains("network") || errorMessage.contains("Network") || errorMessage.contains("网络") {
            errorCode = .network
        } else if errorMessage.contains("timeout") || errorMessage.contains("Timeout") || errorMessage.contains("超时") {
            errorCode = .timeout
        } else if errorMessage.contains("parse") || errorMessage.contains("Parse") || errorMessage.contains("解析") {
            errorCode = .parser
        } else {
            errorCode = .unknown
        }

        return AppReaderError(
            code: errorCode,
            message: errorMessage,
            stage: stage,
            underlyingError: error
        )
    }

    public static func mapUnsupportedFeature(_ feature: String) -> AppReaderError {
        AppReaderError(
            code: .unsupported,
            message: "Feature not supported: \(feature)",
            stage: nil,
            underlyingError: nil
        )
    }

    public static func mapPartialResult<T>(_ value: T, warning: String) -> LoadState<T> {
        .partial(value, warning: warning)
    }

    public static func mapToAppError(_ code: AppReaderError.Code, message: String, stage: String?) -> AppReaderError {
        AppReaderError(code: code, message: message, stage: stage, underlyingError: nil)
    }
}
