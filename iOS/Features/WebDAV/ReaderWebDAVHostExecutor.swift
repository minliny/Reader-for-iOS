import Foundation
import ReaderShellValidation

/// Production bridge from Reader-UI 2.5 Host requests to the already-proven
/// WebDAV feature services. No backup/restore logic is duplicated here.
public final class ReaderWebDAVHostExecutor: HostWebDAVExecuting, @unchecked Sendable {
    public static let shared = ReaderWebDAVHostExecutor()

    private let keychain: any WebDAVCredentialStoring
    private let exporter: any WebDAVBackupExporting
    private let restorer: any WebDAVBackupRestoring
    private let client: any WebDAVClienting

    public init(
        keychain: any WebDAVCredentialStoring = WebDAVKeychainStore.shared,
        exporter: any WebDAVBackupExporting = WebDAVBackupExporter.shared,
        restorer: any WebDAVBackupRestoring = WebDAVBackupRestorer.shared,
        client: any WebDAVClienting = URLSessionWebDAVClient()
    ) {
        self.keychain = keychain
        self.exporter = exporter
        self.restorer = restorer
        self.client = client
    }

    public func connect(
        credentials override: HostWebDAVCredentialOverride?
    ) async throws -> HostWebDAVConnectionResult {
        let credentials = try resolvedCredentials(override)
        let result = try await client.testConnection(credentials: credentials)
        return HostWebDAVConnectionResult(
            statusCode: result.statusCode,
            serverURL: result.serverURL
        )
    }

    public func backup(
        credentials override: HostWebDAVCredentialOverride?
    ) async throws -> HostWebDAVBackupResult {
        let credentials = try resolvedCredentials(override)
        let exported = try await exporter.exportBackup()
        let uploaded = try await client.uploadBackup(
            fileURL: exported.fileURL,
            credentials: credentials
        )
        return HostWebDAVBackupResult(
            statusCode: uploaded.statusCode,
            remoteURL: uploaded.remoteURL.absoluteString,
            byteCount: uploaded.byteCount,
            itemCount: exported.itemCount
        )
    }

    public func restore(
        remoteURL: String,
        credentials override: HostWebDAVCredentialOverride?
    ) async throws -> HostWebDAVRestoreResult {
        guard let url = URL(string: remoteURL) else {
            throw WebDAVClientError.invalidURL(remoteURL)
        }
        let credentials = try resolvedCredentials(override)
        let downloaded = try await client.downloadBackup(
            remoteURL: url,
            credentials: credentials
        )
        let restored = try await restorer.restoreBackup(
            data: downloaded.data,
            overridePolicy: nil
        )
        return HostWebDAVRestoreResult(
            statusCode: downloaded.statusCode,
            remoteURL: downloaded.remoteURL.absoluteString,
            restoredItemCount: restored.restoredItemCount
        )
    }

    private func resolvedCredentials(
        _ override: HostWebDAVCredentialOverride?
    ) throws -> WebDAVCredentials {
        if let override {
            return WebDAVCredentials(
                serverURL: override.serverURL,
                username: override.username,
                password: override.password
            )
        }
        guard let stored = try keychain.load() else {
            throw WebDAVClientError.missingCredentials
        }
        return stored
    }
}
