import Foundation
import SwiftUI

public enum BackupSchedule: String, CaseIterable, Codable, Sendable {
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
    @Published public var restoreURL: String = ""
    @Published public var isSaving: Bool = false
    @Published public var isLoaded: Bool = false
    @Published public var exportResult: ConnectionTestResult = .idle
    @Published public var restoreResult: ConnectionTestResult = .idle
    @Published public var listBackupsResult: ConnectionTestResult = .idle
    @Published public var deleteBackupResult: ConnectionTestResult = .idle
    @Published public var progressSyncResult: ConnectionTestResult = .idle
    @Published public var progressSyncConflicts: [WebDAVProgressSyncConflict] = []
    @Published public var remoteBackups: [WebDAVRemoteBackup] = []
    @Published public var selectedRemoteBackupID: String?

    private let keychain: any WebDAVCredentialStoring
    private let configurationStore: any WebDAVBackupConfigurationStoring
    private let exporter: any WebDAVBackupExporting
    private let restorer: any WebDAVBackupRestoring
    private let webDAVClient: any WebDAVClienting
    private let progressSyncer: any WebDAVProgressSyncing
    private let now: @Sendable () -> Date

    public init(
        keychain: any WebDAVCredentialStoring = WebDAVKeychainStore.shared,
        configurationStore: any WebDAVBackupConfigurationStoring = WebDAVBackupConfigurationStore.shared,
        exporter: any WebDAVBackupExporting = WebDAVBackupExporter.shared,
        restorer: any WebDAVBackupRestoring = WebDAVBackupRestorer.shared,
        webDAVClient: any WebDAVClienting = URLSessionWebDAVClient(),
        progressSyncer: any WebDAVProgressSyncing = WebDAVProgressSyncService.shared,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.keychain = keychain
        self.configurationStore = configurationStore
        self.exporter = exporter
        self.restorer = restorer
        self.webDAVClient = webDAVClient
        self.progressSyncer = progressSyncer
        self.now = now
        loadCredentials()
        loadConfiguration()
    }

    public var isValid: Bool {
        guard let url = URL(string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
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

    private func loadConfiguration() {
        guard let configuration = try? configurationStore.load() else { return }
        backupSchedule = configuration.schedule
        retentionCount = configuration.retentionCount
        lastBackupDate = configuration.lastBackupDate
        isLoaded = true
    }

    public func saveCredentials() async {
        isSaving = true
        defer { isSaving = false }

        let credentials = currentCredentials()

        do {
            try keychain.save(credentials)
            try saveConfiguration()
        } catch {
            connectionTestResult = .failed(message: "Save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Backup Export

    public func exportBackup() async {
        exportResult = .testing

        do {
            let credentials = currentCredentials()
            let result = try await exporter.exportBackup()
            let upload = try await webDAVClient.uploadBackup(fileURL: result.fileURL, credentials: credentials)
            let deletedCount = try await enforceRetention(credentials: credentials, preserving: upload.remoteURL)
            lastBackupDate = now()
            try saveConfiguration()
            let retentionSuffix = deletedCount > 0 ? "; pruned \(deletedCount) old backups" : ""
            exportResult = .success(
                message: "Uploaded \(result.itemCount) items to \(upload.remoteURL.lastPathComponent)\(retentionSuffix)"
            )
        } catch {
            exportResult = .failed(message: "Export failed: \(error.localizedDescription)")
        }
    }

    public func isScheduledBackupDue(at date: Date? = nil) -> Bool {
        scheduledBackupDueDate(referenceDate: date ?? now()) != nil
    }

    @discardableResult
    public func runScheduledBackupIfNeeded() async -> Bool {
        guard isScheduledBackupDue() else { return false }
        await exportBackup()
        if case .success = exportResult {
            return true
        }
        return false
    }

    private func scheduledBackupDueDate(referenceDate: Date) -> Date? {
        switch backupSchedule {
        case .manual:
            return nil
        case .daily:
            return dueDate(referenceDate: referenceDate, interval: 24 * 60 * 60)
        case .weekly:
            return dueDate(referenceDate: referenceDate, interval: 7 * 24 * 60 * 60)
        }
    }

    private func dueDate(referenceDate: Date, interval: TimeInterval) -> Date? {
        guard let lastBackupDate else { return referenceDate }
        let next = lastBackupDate.addingTimeInterval(interval)
        return next <= referenceDate ? next : nil
    }

    private func saveConfiguration() throws {
        try configurationStore.save(
            WebDAVBackupConfiguration(
                schedule: backupSchedule,
                retentionCount: retentionCount,
                lastBackupDate: lastBackupDate
            )
        )
    }

    // MARK: - Reading Progress Sync

    public func syncReadingProgress() async {
        progressSyncResult = .testing

        do {
            let summary = try await progressSyncer.syncAll(credentials: currentCredentials())
            progressSyncConflicts = summary.conflicts
            let conflictSuffix = summary.conflictCount > 0 ? "; \(summary.conflictCount) conflicts" : ""
            progressSyncResult = .success(
                message: "Synced \(summary.uploadedRecordCount) progress records\(conflictSuffix)"
            )
        } catch {
            progressSyncConflicts = []
            progressSyncResult = .failed(message: "Progress sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Backup Restore

    public func restoreBackup() async {
        restoreResult = .testing

        guard let remoteURL = URL(string: restoreURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = remoteURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            restoreResult = .failed(message: "Invalid backup URL")
            return
        }

        await restoreBackup(from: remoteURL)
    }

    public func loadRemoteBackups() async {
        listBackupsResult = .testing

        do {
            let backups = try await webDAVClient.listBackups(credentials: currentCredentials())
            remoteBackups = backups
            selectedRemoteBackupID = selectedRemoteBackupID.flatMap { id in
                backups.contains { $0.id == id } ? id : nil
            } ?? backups.first?.id
            if restoreURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let selectedRemoteBackup {
                restoreURL = selectedRemoteBackup.remoteURL.absoluteString
            }
            listBackupsResult = .success(message: "Found \(backups.count) backups")
        } catch {
            listBackupsResult = .failed(message: "Load failed: \(error.localizedDescription)")
        }
    }

    public func restoreSelectedBackup() async {
        guard let selectedRemoteBackup else {
            restoreResult = .failed(message: "Select a backup first")
            return
        }
        restoreURL = selectedRemoteBackup.remoteURL.absoluteString
        await restoreBackup(from: selectedRemoteBackup.remoteURL)
    }

    public func deleteSelectedBackup() async {
        guard let selectedRemoteBackup else {
            deleteBackupResult = .failed(message: "Select a backup first")
            return
        }
        deleteBackupResult = .testing

        do {
            let summary = try await webDAVClient.deleteBackup(
                remoteURL: selectedRemoteBackup.remoteURL,
                credentials: currentCredentials()
            )
            remoteBackups.removeAll { $0.id == selectedRemoteBackup.id }
            selectedRemoteBackupID = remoteBackups.first?.id
            restoreURL = selectedRemoteBackupID.flatMap { id in
                remoteBackups.first { $0.id == id }?.remoteURL.absoluteString
            } ?? ""
            deleteBackupResult = .success(message: "Deleted \(summary.remoteURL.lastPathComponent)")
        } catch {
            deleteBackupResult = .failed(message: "Delete failed: \(error.localizedDescription)")
        }
    }

    public var selectedRemoteBackup: WebDAVRemoteBackup? {
        guard let selectedRemoteBackupID else { return nil }
        return remoteBackups.first { $0.id == selectedRemoteBackupID }
    }

    private func restoreBackup(from remoteURL: URL) async {
        restoreResult = .testing

        do {
            let credentials = currentCredentials()
            let download = try await webDAVClient.downloadBackup(remoteURL: remoteURL, credentials: credentials)
            let result = try await restorer.restoreBackup(data: download.data, overridePolicy: nil)
            restoreResult = .success(message: "Restored \(result.restoredItemCount) items")
        } catch {
            restoreResult = .failed(message: "Restore failed: \(error.localizedDescription)")
        }
    }

    private func enforceRetention(credentials: WebDAVCredentials, preserving remoteURL: URL) async throws -> Int {
        let listedBackups = try await webDAVClient.listBackups(credentials: credentials)
        let sortedBackups = listedBackups.sorted(by: sortRemoteBackups)
        let retentionLimit = max(1, retentionCount)
        var retainedCount = 0
        var retainedBackups: [WebDAVRemoteBackup] = []
        var deletedCount = 0

        for backup in sortedBackups {
            if backup.remoteURL.absoluteString == remoteURL.absoluteString {
                retainedCount += 1
                retainedBackups.append(backup)
                continue
            }
            if retainedCount < retentionLimit {
                retainedCount += 1
                retainedBackups.append(backup)
                continue
            }
            _ = try await webDAVClient.deleteBackup(remoteURL: backup.remoteURL, credentials: credentials)
            deletedCount += 1
        }

        remoteBackups = retainedBackups
        selectedRemoteBackupID = selectedRemoteBackupID.flatMap { id in
            retainedBackups.contains { $0.id == id } ? id : nil
        } ?? retainedBackups.first?.id
        return deletedCount
    }

    private func sortRemoteBackups(_ lhs: WebDAVRemoteBackup, _ rhs: WebDAVRemoteBackup) -> Bool {
        if lhs.modifiedAt != rhs.modifiedAt {
            switch (lhs.modifiedAt, rhs.modifiedAt) {
            case let (left?, right?):
                return left > right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }
        }
        return lhs.filename > rhs.filename
    }

    // MARK: - Connection Test

    public func testConnection() async {
        connectionTestResult = .testing

        if serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            connectionTestResult = .failed(message: "Server URL is required")
            return
        }

        do {
            let summary = try await webDAVClient.testConnection(credentials: currentCredentials())
            connectionTestResult = .success(message: "Connection OK (\(summary.statusCode))")
        } catch {
            connectionTestResult = .failed(message: error.localizedDescription)
        }
    }

    private func currentCredentials() -> WebDAVCredentials {
        WebDAVCredentials(
            serverURL: serverURL.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
    }
}
