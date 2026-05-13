import Foundation
import SwiftUI

public enum BackupSchedule: String, CaseIterable, Codable {
    case daily
    case weekly
    case manual
}

public enum ConnectionTestResult: Equatable {
    case idle
    case testing
    case success(message: String)
    case failed(message: String)
}

@MainActor
public final class WebDAVSettingsViewModel: ObservableObject {
    @Published public var serverURL: String = ""
    @Published public var username: String = ""
    @Published public var password: String = ""
    @Published public var backupSchedule: BackupSchedule = .weekly
    @Published public var retentionCount: Int = 5
    @Published public var connectionTestResult: ConnectionTestResult = .idle
    @Published public var lastBackupDate: Date? = nil
    @Published public var isSaving: Bool = false
    @Published public var isLoaded: Bool = false
    @Published public var exportResult: ConnectionTestResult = .idle

    private let keychain: WebDAVKeychainStore
    private let exporter: WebDAVBackupExporter

    public init(
        keychain: WebDAVKeychainStore = .shared,
        exporter: WebDAVBackupExporter = .shared
    ) {
        self.keychain = keychain
        self.exporter = exporter
        loadCredentials()
    }

    public var isValid: Bool {
        guard let url = URL(string: serverURL.trimmingCharacters(in: .whitespaces)) else {
            return false
        }
        return url.scheme == "http" || url.scheme == "https"
    }

    // MARK: - Keychain Persistence

    private func loadCredentials() {
        guard let creds = try? keychain.load() else { return }
        serverURL = creds.serverURL
        username = creds.username
        password = creds.password
        isLoaded = true
    }

    public func saveCredentials() async {
        isSaving = true
        defer { isSaving = false }

        let credentials = WebDAVCredentials(
            serverURL: serverURL.trimmingCharacters(in: .whitespaces),
            username: username.trimmingCharacters(in: .whitespaces),
            password: password
        )

        do {
            try keychain.save(credentials)
        } catch {
            connectionTestResult = .failed(message: "Save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Backup Export (mock)

    public func exportBackup() async {
        exportResult = .testing
        try? await Task.sleep(nanoseconds: 800_000_000)

        do {
            let url = try exporter.exportBackup()
            lastBackupDate = Date()
            exportResult = .success(message: "Exported to \(url.lastPathComponent)")
        } catch {
            exportResult = .failed(message: "Export failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Connection Test (mock)

    public func testConnection() async {
        connectionTestResult = .testing
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        if serverURL.trimmingCharacters(in: .whitespaces).isEmpty {
            connectionTestResult = .failed(message: "Server URL is required")
        } else if !isValid {
            connectionTestResult = .failed(message: "Invalid URL format")
        } else {
            connectionTestResult = .success(message: "Connection successful (mock)")
        }
    }
}
