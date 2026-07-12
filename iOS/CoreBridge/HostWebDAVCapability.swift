import Foundation
import ReaderUIContract

public struct HostWebDAVCredentialOverride: Equatable, Sendable {
    public let serverURL: String
    public let username: String
    public let password: String

    public init(serverURL: String, username: String, password: String) {
        self.serverURL = serverURL
        self.username = username
        self.password = password
    }
}

public struct HostWebDAVConnectionResult: Equatable, Sendable {
    public let statusCode: Int
    public let serverURL: String

    public init(statusCode: Int, serverURL: String) {
        self.statusCode = statusCode
        self.serverURL = serverURL
    }
}

public struct HostWebDAVBackupResult: Equatable, Sendable {
    public let statusCode: Int
    public let remoteURL: String
    public let byteCount: Int
    public let itemCount: Int

    public init(statusCode: Int, remoteURL: String, byteCount: Int, itemCount: Int) {
        self.statusCode = statusCode
        self.remoteURL = remoteURL
        self.byteCount = byteCount
        self.itemCount = itemCount
    }
}

public struct HostWebDAVRestoreResult: Equatable, Sendable {
    public let statusCode: Int
    public let remoteURL: String
    public let restoredItemCount: Int

    public init(statusCode: Int, remoteURL: String, restoredItemCount: Int) {
        self.statusCode = statusCode
        self.remoteURL = remoteURL
        self.restoredItemCount = restoredItemCount
    }
}

/// App-target seam that deliberately reuses the existing WebDAV exporter,
/// URLSession client, Keychain credential store and restorer. CoreBridge does
/// not create a second backup business implementation.
public protocol HostWebDAVExecuting: Sendable {
    func connect(credentials: HostWebDAVCredentialOverride?) async throws -> HostWebDAVConnectionResult
    func backup(credentials: HostWebDAVCredentialOverride?) async throws -> HostWebDAVBackupResult
    func restore(
        remoteURL: String,
        credentials: HostWebDAVCredentialOverride?
    ) async throws -> HostWebDAVRestoreResult
}

public struct HostWebDAVCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [
        .webdav_connect, .webdav_backup, .webdav_restore,
    ]
    public let tier: HostCapabilityTier = .simulatorProof

    private let executorProvider: @Sendable () async -> (any HostWebDAVExecuting)?

    public init(
        executorProvider: @escaping @Sendable () async -> (any HostWebDAVExecuting)?
    ) {
        self.executorProvider = executorProvider
    }

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        if request.type == .webdav_connect,
           request.payload["url"] != nil,
           request.payload["serverURL"] == nil {
            return .failure(.notImplemented(
                .webdav_connect,
                "anonymous URL-only WebDAV connect is not supported by the credential-backed executor"
            ))
        }
        let credentials: HostWebDAVCredentialOverride?
        switch Self.credentials(from: request.payload) {
        case .success(let parsed):
            credentials = parsed
        case .failure(let error):
            return .failure(error)
        }

        var remoteURL: String?
        if request.type == .webdav_restore {
            guard let value = request.payload["remoteURL"]?.value as? String,
                  Self.isHTTPURL(value) else {
                return .failure(.invalidParams(
                    "webdav.restore requires an absolute http(s) `remoteURL`"
                ))
            }
            remoteURL = value
        }

        guard let executor = await executorProvider() else {
            return .failure(.notImplemented(
                request.type,
                "WebDAV executor is unavailable; app services were not injected"
            ))
        }

        do {
            switch request.type {
            case .webdav_connect:
                let result = try await executor.connect(credentials: credentials)
                return .success([
                    "connected": AnyCodable(true),
                    "statusCode": AnyCodable(result.statusCode),
                    "message": AnyCodable(HTTPURLResponse.localizedString(forStatusCode: result.statusCode)),
                ])
            case .webdav_backup:
                let result = try await executor.backup(credentials: credentials)
                return .success([
                    "backedUp": AnyCodable(true),
                    "statusCode": AnyCodable(result.statusCode),
                    "remoteURL": AnyCodable(result.remoteURL),
                    "resourceCount": AnyCodable(result.itemCount),
                ])
            case .webdav_restore:
                let result = try await executor.restore(
                    remoteURL: remoteURL!,
                    credentials: credentials
                )
                return .success([
                    "restored": AnyCodable(true),
                    "statusCode": AnyCodable(result.statusCode),
                    "remoteURL": AnyCodable(result.remoteURL),
                    "applied": AnyCodable(true),
                ])
            default:
                return .failure(.notImplemented(
                    request.type,
                    "HostWebDAVCapability does not handle \(request.type.rawValue)"
                ))
            }
        } catch {
            return .failure(.underlying("\(request.type.rawValue) failed: \(error.localizedDescription)"))
        }
    }

    /// Credentials are either omitted entirely (the app executor loads the
    /// existing Keychain record) or supplied as one complete override. Partial
    /// credentials are rejected before network dispatch.
    private static func credentials(
        from payload: [String: AnyCodable]
    ) -> Result<HostWebDAVCredentialOverride?, HostCapabilityError> {
        let server = payload["serverURL"]?.value as? String
        let username = payload["username"]?.value as? String
        let password = payload["password"]?.value as? String
        if server == nil, username == nil, password == nil { return .success(nil) }
        guard let server, isHTTPURL(server),
              let username, !username.isEmpty,
              let password, !password.isEmpty else {
            return .failure(.invalidParams(
                "WebDAV credentials must provide valid `serverURL`, non-empty `username` and `password` together"
            ))
        }
        return .success(HostWebDAVCredentialOverride(
            serverURL: server,
            username: username,
            password: password
        ))
    }

    private static func isHTTPURL(_ value: String) -> Bool {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return false
        }
        return true
    }
}
