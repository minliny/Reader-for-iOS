import Foundation
import ReaderCoreProtocols

// MARK: - NetworkErrorMapper
// Maps system errors and HTTP status codes to fine-grained MappedReaderError values.
//
// Design constraints:
//   - Only imports ReaderCoreProtocols (not ReaderCoreModels) to avoid name ambiguity.
//   - All factory methods return a stable ReaderErrorCode; never expose raw NSError text
//     as the sole discriminator.
//   - Every entry point for a given failure class returns the same errorCode.

public enum NetworkErrorMapper {

    // MARK: - URLError / generic Error mapping

    /// Maps any Error to a MappedReaderError.
    /// URLError subtypes are classified precisely; all others become .UNKNOWN.
    public static func map(
        error: Error,
        stage: ReaderFailureStage,
        context: ReaderErrorContext = ReaderErrorContext()
    ) -> MappedReaderError {
        if let urlError = error as? URLError {
            return mapURLError(urlError, stage: stage, context: context)
        }
        return MappedReaderError(
            code: .UNKNOWN,
            stage: stage,
            message: error.localizedDescription,
            context: context
        )
    }

    // MARK: - HTTP status mapping

    /// Returns nil for 2xx responses; non-2xx → .HTTP_STATUS_INVALID with statusCode in context.
    public static func mapHTTPStatus(
        statusCode: Int,
        stage: ReaderFailureStage = .response_validation,
        context: ReaderErrorContext = ReaderErrorContext()
    ) -> MappedReaderError? {
        guard !(200...299).contains(statusCode) else { return nil }
        let enriched = ReaderErrorContext(
            sampleId: context.sampleId,
            sourceURL: context.sourceURL,
            statusCode: statusCode,
            details: context.details
        )
        return MappedReaderError(
            code: .HTTP_STATUS_INVALID,
            stage: stage,
            message: "HTTP \(statusCode) is not a success response.",
            context: enriched
        )
    }

    // MARK: - Policy-layer factories

    /// Missing required request header.
    public static func headerRequired(
        headerName: String,
        stage: ReaderFailureStage = .policy_check,
        context: ReaderErrorContext = ReaderErrorContext()
    ) -> MappedReaderError {
        MappedReaderError(
            code: .HEADER_REQUIRED,
            stage: stage,
            message: "Required header '\(headerName)' is missing from the request.",
            context: context
        )
    }

    /// Cookie jar required but no cookies were available.
    public static func cookieRequired(
        stage: ReaderFailureStage = .policy_check,
        context: ReaderErrorContext = ReaderErrorContext()
    ) -> MappedReaderError {
        MappedReaderError(
            code: .COOKIE_REQUIRED,
            stage: stage,
            message: "Cookie jar is required but no cookies were present for this request.",
            context: context
        )
    }

    // MARK: - Private URLError dispatch

    private static func mapURLError(
        _ urlError: URLError,
        stage: ReaderFailureStage,
        context: ReaderErrorContext
    ) -> MappedReaderError {
        switch urlError.code {
        case .timedOut:
            return MappedReaderError(
                code: .NETWORK_TIMEOUT,
                stage: stage,
                message: "The network request timed out.",
                context: context
            )
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed:
            return MappedReaderError(
                code: .NETWORK_UNREACHABLE,
                stage: stage,
                message: "The network is unreachable or the host cannot be reached.",
                context: context
            )
        default:
            return MappedReaderError(
                code: .UNKNOWN,
                stage: stage,
                message: urlError.localizedDescription,
                context: context
            )
        }
    }
}
