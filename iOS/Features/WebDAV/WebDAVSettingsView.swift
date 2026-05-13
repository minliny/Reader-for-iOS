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
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }

    // MARK: - Credential Section

    private var credentialSection: some View {
        Section("Credentials") {
            TextField("Username", text: $viewModel.username)
                .autocapitalization(.none)
                .disableAutocorrection(true)

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
        }
    }

    // MARK: - Connection Test

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
