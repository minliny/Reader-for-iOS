import SwiftUI

/// WebDAV 配置页：接入 `WebDAVSettingsViewModel`，替换原 demo 占位壳。
///
/// 服务器地址 / 账号 / 密码双向绑定 VM，测试连通性 / 保存配置 / 备份 / 恢复
/// 全部经 VM 异步方法，远程备份列表从 `viewModel.remoteBackups` 渲染。
/// 外壳沿用 `DemoSettingsShell` + `DemoPaperScreen`，与 `SettingsDemoShellView` 视觉一致。
public struct WebDAVSettingsView: View {
    @StateObject private var viewModel = WebDAVSettingsViewModel()
    private let onExit: (() -> Void)?

    public init(onExit: (() -> Void)? = nil) {
        self.onExit = onExit
    }

    public var body: some View {
        DemoSettingsShell(title: "WebDAV 配置", onBack: handleExit) {
            DemoPaperScreen {
                content
            }
        } trailing: {
            EmptyView()
        } bottomActionHost: {
            EmptyView()
        } sheetHost: {
            EmptyView()
        } toastHost: {
            EmptyView()
        } dialogHost: {
            EmptyView()
        } stateHost: {
            EmptyView()
        }
    }

    private func handleExit() {
        if let onExit {
            onExit()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            connectionSection
            connectionTestStatus
            actionsSection
            backupListSection
        }
    }

    // MARK: - 连接信息

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            sectionTitle("连接信息")
            VStack(spacing: 0) {
                inputRow(icon: .link, title: "服务器地址", text: $viewModel.serverURL, placeholder: "https://dav.example.com/reader")
                rowDivider
                inputRow(icon: .people, title: "账号", text: $viewModel.username, placeholder: "reader@example.com")
                rowDivider
                secureRow(icon: .shield, title: "密码", text: $viewModel.password, placeholder: "请输入密码")
            }
            .background(ReaderDesignTokens.Color.controlBackground)
            .cornerRadius(ReaderDesignTokens.Radius.lg)
        }
    }

    @ViewBuilder
    private func inputRow(icon: ReaderAssetIcon, title: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(icon, size: ReaderDesignTokens.settingsRowIconColumn)
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Text(title)
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.ink)
                .frame(width: 64, alignment: .leading)
            TextField(placeholder, text: text)
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.ink)
                #if canImport(UIKit)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .frame(minHeight: ReaderDesignTokens.settingsInputHeight)
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .frame(minHeight: ReaderDesignTokens.settingsInputRowMinHeight, alignment: .leading)
    }

    @ViewBuilder
    private func secureRow(icon: ReaderAssetIcon, title: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(icon, size: ReaderDesignTokens.settingsRowIconColumn)
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Text(title)
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.ink)
                .frame(width: 64, alignment: .leading)
            SecureField(placeholder, text: text)
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.ink)
                #if canImport(UIKit)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .frame(minHeight: ReaderDesignTokens.settingsInputHeight)
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .frame(minHeight: ReaderDesignTokens.settingsInputRowMinHeight, alignment: .leading)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(ReaderDesignTokens.Color.muted.opacity(0.18))
            .frame(height: 0.5)
            .padding(.leading, ReaderDesignTokens.settingsRowHorizontalPadding + ReaderDesignTokens.settingsRowIconColumn + ReaderDesignTokens.settingsRowGap)
    }

    // MARK: - 连通性测试结果

    @ViewBuilder
    private var connectionTestStatus: some View {
        switch viewModel.connectionTestResult {
        case .idle:
            EmptyView()
        case .testing:
            statusRow("正在测试连通性…", tone: .muted)
        case .success(let message):
            statusRow(message, tone: .good)
        case .failed(let message):
            statusRow(message, tone: .warn)
        }
    }

    @ViewBuilder
    private func statusRow(_ text: String, tone: StatusTone) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tone.color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                .foregroundStyle(tone.color)
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
    }

    // MARK: - 操作

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            sectionTitle("操作")
            VStack(spacing: 0) {
                actionRow(title: "测试网络连通性", icon: .refresh, isLoading: isTestingConnection) {
                    Task { await viewModel.testConnection() }
                }
                rowDivider
                actionRow(title: "保存配置", icon: .check, isLoading: viewModel.isSaving) {
                    Task { await viewModel.saveCredentials() }
                }
                rowDivider
                actionRow(title: "立即备份", icon: .upload, isLoading: isExporting) {
                    Task { await viewModel.exportBackup() }
                }
                rowDivider
                actionRow(title: "恢复选中备份", icon: .download, isLoading: isRestoring) {
                    Task { await viewModel.restoreSelectedBackup() }
                }
                rowDivider
                actionRow(title: "刷新远程备份列表", icon: .sync, isLoading: isListingBackups) {
                    Task { await viewModel.loadRemoteBackups() }
                }
            }
            .background(ReaderDesignTokens.Color.controlBackground)
            .cornerRadius(ReaderDesignTokens.Radius.lg)

            if viewModel.isLoaded == false {
                statusRow("尚未加载已保存的配置", tone: .muted)
            }

            exportStatusView
            restoreStatusView
        }
    }

    @ViewBuilder
    private func actionRow(title: String, icon: ReaderAssetIcon, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(icon, size: ReaderDesignTokens.settingsRowIconColumn)
                    .foregroundStyle(ReaderDesignTokens.Color.primary)
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    ReaderIcon(.chevron, size: 16)
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                }
            }
            .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
            .frame(minHeight: ReaderDesignTokens.settingsRowMinHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    @ViewBuilder
    private var exportStatusView: some View {
        switch viewModel.exportResult {
        case .idle, .testing:
            EmptyView()
        case .success(let message):
            statusRow("备份：\(message)", tone: .good)
        case .failed(let message):
            statusRow("备份：\(message)", tone: .warn)
        }
    }

    @ViewBuilder
    private var restoreStatusView: some View {
        switch viewModel.restoreResult {
        case .idle, .testing:
            EmptyView()
        case .success(let message):
            statusRow("恢复：\(message)", tone: .good)
        case .failed(let message):
            statusRow("恢复：\(message)", tone: .warn)
        }
    }

    // MARK: - 远程备份列表

    private var backupListSection: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            HStack {
                sectionTitle("远程备份")
                if !viewModel.remoteBackups.isEmpty {
                    Spacer()
                    Text("\(viewModel.remoteBackups.count) 项")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                }
            }

            if viewModel.remoteBackups.isEmpty {
                Text("暂无远程备份，点击「刷新远程备份列表」加载。")
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.remoteBackups.enumerated()), id: \.element.id) { index, backup in
                        backupRow(backup)
                        if index < viewModel.remoteBackups.count - 1 {
                            rowDivider
                        }
                    }
                }
                .background(ReaderDesignTokens.Color.controlBackground)
                .cornerRadius(ReaderDesignTokens.Radius.lg)
            }

            listBackupsStatusView
        }
    }

    @ViewBuilder
    private func backupRow(_ backup: WebDAVRemoteBackup) -> some View {
        let isSelected = viewModel.selectedRemoteBackupID == backup.id
        Button {
            viewModel.selectedRemoteBackupID = backup.id
            viewModel.restoreURL = backup.remoteURL.absoluteString
        } label: {
            HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(.file, size: ReaderDesignTokens.settingsRowIconColumn)
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(backup.filename)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.ink)
                        .lineLimit(1)
                    Text(backupMetaText(backup))
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    ReaderIcon(.check, size: 18)
                        .foregroundStyle(ReaderDesignTokens.Color.primary)
                }
            }
            .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
            .frame(minHeight: ReaderDesignTokens.settingsRowMinHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func backupMetaText(_ backup: WebDAVRemoteBackup) -> String {
        var parts: [String] = []
        if let modifiedAt = backup.modifiedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            parts.append(formatter.string(from: modifiedAt))
        }
        if let byteCount = backup.byteCount {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            parts.append(formatter.string(fromByteCount: byteCount))
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var listBackupsStatusView: some View {
        switch viewModel.listBackupsResult {
        case .idle, .testing:
            EmptyView()
        case .success(let message):
            statusRow(message, tone: .good)
        case .failed(let message):
            statusRow(message, tone: .warn)
        }
    }

    // MARK: - 辅助

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .semibold))
            .foregroundStyle(ReaderDesignTokens.Color.muted)
            .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
            .padding(.top, 4)
    }

    private var isTestingConnection: Bool {
        if case .testing = viewModel.connectionTestResult { return true }
        return false
    }

    private var isExporting: Bool {
        if case .testing = viewModel.exportResult { return true }
        return false
    }

    private var isRestoring: Bool {
        if case .testing = viewModel.restoreResult { return true }
        return false
    }

    private var isListingBackups: Bool {
        if case .testing = viewModel.listBackupsResult { return true }
        return false
    }
}

// MARK: - StatusTone

private enum StatusTone {
    case good
    case warn
    case muted

    var color: Color {
        switch self {
        case .good:
            return ReaderDesignTokens.Color.primary
        case .warn:
            return ReaderDesignTokens.Color.danger
        case .muted:
            return ReaderDesignTokens.Color.muted
        }
    }
}
