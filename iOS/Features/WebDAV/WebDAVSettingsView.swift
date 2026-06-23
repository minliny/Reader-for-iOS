import Foundation
import SwiftUI

public struct WebDAVSettingsView: View {
    @StateObject private var viewModel = WebDAVSettingsViewModel()
    @SwiftUI.Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                serverSection
                credentialSection
                backupSection
                progressSyncSection
                restoreSection
                connectionSection
            }
            .navigationTitle("WebDAV Backup")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await viewModel.saveCredentials() }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }

    // MARK: - Server Section

    private var serverSection: some View {
        Section("Server") {
            TextField("https://example.com/webdav", text: $viewModel.serverURL)
#if os(iOS)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
#endif
        }
    }

    // MARK: - Credential Section

    private var credentialSection: some View {
        Section("Credentials") {
            TextField("Username", text: $viewModel.username)
#if os(iOS)
                .autocapitalization(.none)
                .disableAutocorrection(true)
#endif

            SecureField("Password", text: $viewModel.password)
        }
    }

    // MARK: - Backup Section

    private var backupSection: some View {
        Section("Backup Schedule") {
            Picker("Schedule", selection: $viewModel.backupSchedule) {
                ForEach(BackupSchedule.allCases, id: \.self) { schedule in
                    Text(schedule.rawValue.capitalized).tag(schedule)
                }
            }
            .pickerStyle(.segmented)

            Stepper(
                "Retention: \(viewModel.retentionCount) copies",
                value: $viewModel.retentionCount,
                in: 1...30
            )

            if let lastBackup = viewModel.lastBackupDate {
                HStack {
                    Text("Last Backup")
                    Spacer()
                    Text(lastBackup, style: .date)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task { await viewModel.exportBackup() }
            } label: {
                HStack {
                    Text("Upload Backup Now")
                    Spacer()
                    if case .testing = viewModel.exportResult {
                        ProgressView()
                    }
                }
            }
            .disabled(!viewModel.isValid)

            switch viewModel.exportResult {
            case .idle:
                EmptyView()
            case .testing:
                HStack {
                    ProgressView()
                    Text("Uploading...")
                        .foregroundStyle(.secondary)
                }
            case .success(let message):
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Progress Sync Section

    private var progressSyncSection: some View {
        Section("Progress Sync") {
            Button {
                Task { await viewModel.syncReadingProgress() }
            } label: {
                HStack {
                    Text("Sync Reading Progress Now")
                    Spacer()
                    if case .testing = viewModel.progressSyncResult {
                        ProgressView()
                    }
                }
            }
            .disabled(!viewModel.isValid)

            switch viewModel.progressSyncResult {
            case .idle:
                EmptyView()
            case .testing:
                HStack {
                    ProgressView()
                    Text("Syncing progress...")
                        .foregroundStyle(.secondary)
                }
            case .success(let message):
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }

            if !viewModel.progressSyncConflicts.isEmpty {
                ForEach(viewModel.progressSyncConflicts) { conflict in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(conflict.resolved.chapterTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(progressConflictResolutionTitle(conflict.resolution))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("Local \(progressPercent(conflict.local.progressRatio))")
                            Spacer()
                            Text("Remote \(progressPercent(conflict.remote.progressRatio))")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func progressConflictResolutionTitle(_ resolution: WebDAVProgressConflictResolution) -> String {
        switch resolution {
        case .localKept:
            return "Kept local progress"
        case .remoteApplied:
            return "Applied remote progress"
        }
    }

    private func progressPercent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value * 100))%"
    }

    // MARK: - Connection Test

    private var restoreSection: some View {
        Section("Restore") {
            Button {
                Task { await viewModel.loadRemoteBackups() }
            } label: {
                HStack {
                    Text("Load Remote Backups")
                    Spacer()
                    if case .testing = viewModel.listBackupsResult {
                        ProgressView()
                    }
                }
            }
            .disabled(!viewModel.isValid)

            if !viewModel.remoteBackups.isEmpty {
                Picker("Remote Backup", selection: $viewModel.selectedRemoteBackupID) {
                    ForEach(viewModel.remoteBackups) { backup in
                        Text(remoteBackupTitle(backup))
                            .tag(Optional(backup.id))
                    }
                }

                Button {
                    Task { await viewModel.restoreSelectedBackup() }
                } label: {
                    HStack {
                        Text("Restore Selected Backup")
                        Spacer()
                        if case .testing = viewModel.restoreResult {
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.selectedRemoteBackupID == nil)

                Button(role: .destructive) {
                    Task { await viewModel.deleteSelectedBackup() }
                } label: {
                    HStack {
                        Text("Delete Selected Backup")
                        Spacer()
                        if case .testing = viewModel.deleteBackupResult {
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.selectedRemoteBackupID == nil)
            }

            switch viewModel.listBackupsResult {
            case .idle:
                EmptyView()
            case .testing:
                HStack {
                    ProgressView()
                    Text("Loading backups...")
                        .foregroundStyle(.secondary)
                }
            case .success(let message):
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }

            switch viewModel.deleteBackupResult {
            case .idle:
                EmptyView()
            case .testing:
                HStack {
                    ProgressView()
                    Text("Deleting backup...")
                        .foregroundStyle(.secondary)
                }
            case .success(let message):
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }

            TextField("Manual backup URL", text: $viewModel.restoreURL)
#if os(iOS)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
#endif

            Button {
                Task { await viewModel.restoreBackup() }
            } label: {
                HStack {
                    Text("Restore Manual URL")
                    Spacer()
                    if case .testing = viewModel.restoreResult {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.restoreURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            switch viewModel.restoreResult {
            case .idle:
                EmptyView()
            case .testing:
                HStack {
                    ProgressView()
                    Text("Restoring...")
                        .foregroundStyle(.secondary)
                }
            case .success(let message):
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    private func remoteBackupTitle(_ backup: WebDAVRemoteBackup) -> String {
        guard let byteCount = backup.byteCount else { return backup.filename }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(backup.filename) (\(formatter.string(fromByteCount: byteCount)))"
    }

    private var connectionSection: some View {
        Section("Connection Test") {
            Button {
                Task { await viewModel.testConnection() }
            } label: {
                HStack {
                    Text("Test Connection")
                    Spacer()
                    connectionStatusIcon
                }
            }
            .disabled(viewModel.serverURL.trimmingCharacters(in: .whitespaces).isEmpty)

            switch viewModel.connectionTestResult {
            case .idle:
                EmptyView()
            case .testing:
                HStack {
                    ProgressView()
                    Text("Testing...")
                        .foregroundStyle(.secondary)
                }
            case .success(let message):
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var connectionStatusIcon: some View {
        switch viewModel.connectionTestResult {
        case .idle:
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(.secondary)
        case .testing:
            ProgressView()
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
