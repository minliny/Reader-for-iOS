import Foundation
import ReaderCoreBridge

struct NetworkHostFailure: Error {
    enum Category: String {
        case networkEnvironment = "NETWORK_ENVIRONMENT"
        case sourceHTTPFailed = "SOURCE_HTTP_FAILED"
    }

    let code: M2HostErrorCode
    let phase: M2HostErrorPhase
    let message: String
    var retryable = false
    var status: Int64?
    var category: Category?

    static func classified(_ error: any Error) -> Self {
        if let failure = error as? Self { return failure }
        if error is CancellationError {
            return .init(code: .cancelled, phase: .runtime, message: "Host operation cancelled")
        }
        if let error = error as? URLError {
            switch error.code {
            case .cancelled:
                return .init(code: .cancelled, phase: .transport, message: "Network operation cancelled")
            case .timedOut:
                return .init(code: .timeout, phase: .transport, message: "Network operation timed out", retryable: true)
            case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
                    .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .clientCertificateRejected,
                    .clientCertificateRequired:
                return .init(code: .tlsError, phase: .transport, message: "TLS validation failed")
            case .appTransportSecurityRequiresSecureConnection, .noPermissionsToReadFile:
                return .init(code: .permissionDenied, phase: .transport, message: "System refused the network request")
            case .badURL, .unsupportedURL:
                return .init(code: .invalidResponse, phase: .request, message: "Unsupported network URL")
            case .notConnectedToInternet, .internationalRoamingOff, .dataNotAllowed:
                return .init(code: .networkError, phase: .transport, message: "Network connection unavailable",
                             retryable: true, category: .networkEnvironment)
            default:
                return .init(code: .networkError, phase: .transport,
                             message: "Network operation failed (\(error.code.rawValue))", retryable: true)
            }
        }
        return .init(code: .internal, phase: .runtime, message: "Host operation failed")
    }

    static func status(_ status: Int) -> Self {
        .init(code: .httpError, phase: .response, message: "status=\(status)",
              retryable: status == 408 || status == 429 || status >= 500,
              status: Int64(status), category: .sourceHTTPFailed)
    }

    static func invalid(_ message: String) -> Self {
        .init(code: .invalidResponse, phase: .response, message: message)
    }

    func reply(operationId: Int64) -> CoreHostReply {
        let wire: ReaderErrorCode
        switch code {
        case .timeout: wire = .timeout
        case .cancelled: wire = .cancelled
        default: wire = .internal
        }
        var details: [String: ReaderM1JSONValue] = [:]
        if let status { details["status"] = .integer(status) }
        if let category { details["category"] = .string(category.rawValue) }
        return .networkFailure(.init(
            operationId: operationId, error: .init(code: wire, message: message, retryable: retryable),
            diagnostics: .init(code: code, phase: phase, message: message,
                               details: details.isEmpty ? nil : details)
        ))
    }
}

func hostHTTPURL(_ raw: String) throws -> URL {
    guard let url = URL(string: raw), let host = url.host(), !host.isEmpty,
          let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
          url.user() == nil, url.password() == nil else {
        throw NetworkHostFailure(code: .invalidResponse, phase: .request, message: "Invalid HTTP URL")
    }
    return url
}

func hostHeaderValue(_ value: ReaderM1JSONValue) throws -> String {
    if case .string(let text) = value { return text }
    if case .array(let list) = value {
        return try list.map(hostHeaderValue).joined(separator: ", ")
    }
    throw NetworkHostFailure(code: .invalidResponse, phase: .request, message: "Invalid HTTP header value")
}
