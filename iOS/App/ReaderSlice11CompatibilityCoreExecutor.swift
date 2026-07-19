import Foundation
import ReaderCoreNativeAdapter
import ReaderShellValidation
import ReaderUIRuntime

private struct ReaderSlice11CompatibilityRawResult: @unchecked Sendable {
    let data: [String: Any]
}

public enum ReaderSlice11CompatibilityExecutorError: Error, Equatable, LocalizedError {
    case duplicateInFlight(String)
    case failedClosed(code: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .duplicateInFlight(let correlationID):
            return "[SLICE11_COMPAT_DUPLICATE_IN_FLIGHT] Core command is already running for \(correlationID)"
        case .failedClosed(let code, let message):
            return "[\(code)] \(message)"
        }
    }
}

/// Real request-scoped executor for Reader-UI's compatibility-only import and
/// RSS commands. The production consumer lock remains unchanged (Shadow); an
/// explicitly admitted Pilot no longer needs a fake executor.
///
/// The adapter rejects embedded source/RSS credentials before dispatch. That
/// keeps the compatibility route aligned with `ReaderSlice11CoreService` even
/// though these composed methods live outside the canonical command schema.
@MainActor
public final class ReaderSlice11CompatibilityCoreExecutor:
    ReaderImportCoreCommandExecuting,
    ReaderRssCoreCommandExecuting
{
    private let runtime: any RustCoreCommandRuntime
    private let router: (any RustCoreHostRequestRouting)?
    private let requestTimeout: TimeInterval
    private var inFlight: [String: RustCoreRequestScopedCommand<ReaderSlice11CompatibilityRawResult>] = [:]

    public init(
        runtime: any RustCoreCommandRuntime,
        router: (any RustCoreHostRequestRouting)? = nil,
        requestTimeout: TimeInterval = 30
    ) {
        self.runtime = runtime
        self.router = router
        self.requestTimeout = requestTimeout
    }

    public convenience init(runtime: ReaderCoreNativeRuntime, requestTimeout: TimeInterval = 30) {
        self.init(
            runtime: runtime,
            router: RustCoreServiceSupport.makeRouter(runtime: runtime),
            requestTimeout: requestTimeout
        )
    }

    public func executeParse(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "import.parse", payload: payload, correlationID: correlationID)
    }

    public func executePersist(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "import.persist", payload: payload, correlationID: correlationID)
    }

    public func executeRollback(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "import.rollback", payload: payload, correlationID: correlationID)
    }

    public func executeFeedRefresh(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "rss.feed.refresh", payload: payload, correlationID: correlationID)
    }

    public func executeSubscriptionPersist(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "rss.subscription.persist", payload: payload, correlationID: correlationID)
    }

    public func executeSubscriptionRemove(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "rss.subscription.remove", payload: payload, correlationID: correlationID)
    }

    public func executeEntryRead(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "rss.entry.read", payload: payload, correlationID: correlationID)
    }

    public func executeFavoritePersist(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "rss.favorite.persist", payload: payload, correlationID: correlationID)
    }

    public func executeFavoriteRemove(
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        try await execute(method: "rss.favorite.remove", payload: payload, correlationID: correlationID)
    }

    public func cancel(correlationID: String) {
        inFlight.removeValue(forKey: correlationID)?.cancel()
    }

    public func finish(correlationID: String) {
        inFlight[correlationID] = nil
    }

    private func execute(
        method: String,
        payload: ReaderUIJSONPayload,
        correlationID: String
    ) async throws -> ReaderUIJSONResult {
        guard inFlight[correlationID] == nil else {
            throw ReaderSlice11CompatibilityExecutorError.duplicateInFlight(correlationID)
        }
        let params = ReaderUIJSONBridge.foundationObject(from: payload)
        try Self.preflight(method: method, params: params)
        let command = try RustCoreRequestScopedCommand<ReaderSlice11CompatibilityRawResult>(
            runtime: runtime,
            router: router,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: method,
            params: params,
            timeout: requestTimeout
        ) { data in
            ReaderSlice11CompatibilityRawResult(data: data ?? [:])
        }
        inFlight[correlationID] = command
        do {
            try command.start()
            let result = try await command.value()
            guard inFlight[correlationID] === command else { throw CancellationError() }
            inFlight[correlationID] = nil
            return try ReaderUIJSONBridge.result(from: result.data)
        } catch {
            if inFlight[correlationID] === command {
                inFlight[correlationID] = nil
            }
            throw error
        }
    }

    private static func preflight(method: String, params: [String: Any]) throws {
        switch method {
        case "import.parse", "import.persist", "import.rollback", "rss.subscription.persist":
            try rejectCredentialMaterial(params, path: method)
        default:
            break
        }
        if method == "rss.subscription.persist",
           let nested = params["params"] as? [String: Any],
           let feedURL = nested["feedUrl"] as? String {
            try validatePublicURL(feedURL, path: "rss.subscription.persist.params.feedUrl")
        }
    }

    private static func rejectCredentialMaterial(_ value: Any, path: String) throws {
        if let dictionary = value as? [String: Any] {
            for (key, nested) in dictionary {
                let normalized = key.lowercased().filter(\.isLetter)
                if sensitiveKeys.contains(normalized), hasNonEmptyValue(nested) {
                    throw ReaderSlice11CompatibilityExecutorError.failedClosed(
                        code: "SLICE11_EMBEDDED_CREDENTIAL_REJECTED",
                        message: "\(path).\(key) contains plaintext credential material"
                    )
                }
                if key.lowercased().contains("url"),
                   let string = nested as? String,
                   string.lowercased().hasPrefix("http") {
                    try validatePublicURL(string, path: "\(path).\(key)")
                }
                if (key.lowercased() == "header" || key.lowercased() == "headers"),
                   let string = nested as? String {
                    let lower = string.lowercased()
                    if ["authorization:", "proxy-authorization:", "cookie:", "bearer ", "basic "]
                        .contains(where: lower.contains) {
                        throw ReaderSlice11CompatibilityExecutorError.failedClosed(
                            code: "SLICE11_EMBEDDED_CREDENTIAL_REJECTED",
                            message: "\(path).\(key) contains plaintext authentication material"
                        )
                    }
                }
                try rejectCredentialMaterial(nested, path: "\(path).\(key)")
            }
        } else if let array = value as? [Any] {
            for (index, nested) in array.enumerated() {
                try rejectCredentialMaterial(nested, path: "\(path)[\(index)]")
            }
        }
    }

    private static func validatePublicURL(_ value: String, path: String) throws {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              components.host?.isEmpty == false else {
            throw ReaderSlice11CompatibilityExecutorError.failedClosed(
                code: "SLICE11_REMOTE_URL_INVALID",
                message: "\(path) must be an absolute HTTP(S) URL"
            )
        }
        let hasSensitiveQuery = components.queryItems?.contains {
            sensitiveQueryNames.contains($0.name.lowercased())
        } ?? false
        guard components.user == nil, components.password == nil, !hasSensitiveQuery else {
            throw ReaderSlice11CompatibilityExecutorError.failedClosed(
                code: "SLICE11_EMBEDDED_CREDENTIAL_REJECTED",
                message: "\(path) embeds credentials; secrets must remain Host-owned"
            )
        }
    }

    private static func hasNonEmptyValue(_ value: Any) -> Bool {
        if value is NSNull { return false }
        if let string = value as? String { return !string.isEmpty }
        if let array = value as? [Any] { return !array.isEmpty }
        if let dictionary = value as? [String: Any] { return !dictionary.isEmpty }
        return true
    }

    private static let sensitiveKeys: Set<String> = [
        "password", "passwd", "pwd", "token", "accesstoken", "refreshtoken",
        "apikey", "secret", "clientsecret", "authorization", "proxyauthorization",
        "cookie", "credentials", "credential", "username", "userid",
    ]

    private static let sensitiveQueryNames: Set<String> = [
        "token", "access_token", "refresh_token", "api_key", "apikey", "key",
        "secret", "password", "passwd", "signature", "auth", "authorization",
        "cookie", "session",
    ]
}
