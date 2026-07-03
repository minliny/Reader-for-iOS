import Foundation
import SwiftUI

public struct WebDAVSettingsView: View {
    @StateObject private var viewModel = WebDAVSettingsViewModel()

    public init() {}

    public var body: some View {
        DemoBackScreen(title: "WebDAV 备份") {
            overviewCard
            serverSection
            credentialSection
            backupSection
            progressSyncSection
            restoreSection
            connectionSection
        } trailing: {
            Button {
                Task { await viewModel.saveCredentials() }
            } label: {
                ReaderIcon(viewModel.isSaving ? .refresh : .check, size: 20, accessibilityLabel: "保存 WebDAV 配置")
                    .frame(width: ReaderDesignTokens.topBarIconButtonSize, height: ReaderDesignTokens.topBarIconButtonSize)
                    .foregroundColor(viewModel.isSaving ? .secondary : ReaderDesignTokens.Color.primaryDark)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSaving)
            .accessibilityLabel("保存 WebDAV 配置")
        }
    }

    private var overviewCard: some View {
        ReaderCard {
            HStack(alignment: .center, spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(.cloud, size: ReaderDesignTokens.rssSourceListIconSize, accessibilityLabel: "WebDAV 备份")
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                VStack(alignment: .leading, spacing: 4) {
                    Text("备份与阅读进度同步")
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    Text("配置保存在本机；上传、恢复和连接测试仅在点击对应操作时执行。")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var serverSection: some View {
        webdavSection(icon: .link, title: "服务器") {
            inputRow(
                icon: .link,
                title: "服务器地址",
                placeholder: "https://example.com/webdav",
                text: $viewModel.serverURL
            )
        }
    }

    private var credentialSection: some View {
        webdavSection(icon: .shield, title: "账号凭据") {
            inputRow(
                icon: .people,
                title: "用户名",
                placeholder: "Username",
                text: $viewModel.username
            )
            secureInputRow(
                icon: .shield,
                title: "密码",
                placeholder: "Password",
                text: $viewModel.password
            )
        }
    }

    private var backupSection: some View {
        webdavSection(icon: .cloud, title: "备份计划") {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                Text("备份频率")
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("备份频率", selection: $viewModel.backupSchedule) {
                    ForEach(BackupSchedule.allCases, id: \.self) { schedule in
                        Text(scheduleTitle(schedule)).tag(schedule)
                    }
                }
                .pickerStyle(.segmented)
            }

            Stepper(value: $viewModel.retentionCount, in: 1...30) {
                rowLabel(icon: .storage, title: "保留备份", detail: "\(viewModel.retentionCount) 份")
            }

            if let lastBackupDate = viewModel.lastBackupDate {
                valueRow(icon: .clock, title: "上次备份") {
                    Text(lastBackupDate, style: .date)
                }
            }

            actionButton(
                icon: .upload,
                title: "立即上传备份",
                isBusy: isTesting(viewModel.exportResult),
                disabled: !viewModel.isValid
            ) {
                Task { await viewModel.exportBackup() }
            }

            resultRow(viewModel.exportResult, loadingMessage: "正在上传备份...")
        }
    }

    private var progressSyncSection: some View {
        webdavSection(icon: .sync, title: "阅读进度同步") {
            actionButton(
                icon: .sync,
                title: "立即同步阅读进度",
                isBusy: isTesting(viewModel.progressSyncResult),
                disabled: !viewModel.isValid
            ) {
                Task { await viewModel.syncReadingProgress() }
            }

            resultRow(viewModel.progressSyncResult, loadingMessage: "正在同步阅读进度...")

            ForEach(viewModel.progressSyncConflicts) { conflict in
                conflictRow(conflict)
            }
        }
    }

    private var restoreSection: some View {
        webdavSection(icon: .download, title: "恢复备份") {
            actionButton(
                icon: .folder,
                title: "加载远程备份",
                isBusy: isTesting(viewModel.listBackupsResult),
                disabled: !viewModel.isValid
            ) {
                Task { await viewModel.loadRemoteBackups() }
            }

            if !viewModel.remoteBackups.isEmpty {
                Picker("远程备份", selection: $viewModel.selectedRemoteBackupID) {
                    ForEach(viewModel.remoteBackups) { backup in
                        Text(remoteBackupTitle(backup))
                            .tag(Optional(backup.id))
                    }
                }

                actionButton(
                    icon: .download,
                    title: "恢复所选备份",
                    isBusy: isTesting(viewModel.restoreResult),
                    disabled: viewModel.selectedRemoteBackupID == nil
                ) {
                    Task { await viewModel.restoreSelectedBackup() }
                }

                actionButton(
                    icon: .trash,
                    title: "删除所选备份",
                    isBusy: isTesting(viewModel.deleteBackupResult),
                    disabled: viewModel.selectedRemoteBackupID == nil,
                    isDestructive: true
                ) {
                    Task { await viewModel.deleteSelectedBackup() }
                }
            }

            resultRow(viewModel.listBackupsResult, loadingMessage: "正在加载远程备份...")
            resultRow(viewModel.deleteBackupResult, loadingMessage: "正在删除备份...")

            inputRow(
                icon: .link,
                title: "手动恢复 URL",
                placeholder: "Manual backup URL",
                text: $viewModel.restoreURL
            )

            actionButton(
                icon: .download,
                title: "恢复手动 URL",
                isBusy: isTesting(viewModel.restoreResult),
                disabled: viewModel.restoreURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await viewModel.restoreBackup() }
            }

            resultRow(viewModel.restoreResult, loadingMessage: "正在恢复备份...")
        }
    }

    private var connectionSection: some View {
        webdavSection(icon: .wifi, title: "连接测试") {
            actionButton(
                icon: connectionStatusIcon,
                title: "测试连接",
                isBusy: isTesting(viewModel.connectionTestResult),
                disabled: viewModel.serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await viewModel.testConnection() }
            }

            resultRow(viewModel.connectionTestResult, loadingMessage: "正在测试连接...")
        }
    }

    private var connectionStatusIcon: ReaderAssetIcon {
        switch viewModel.connectionTestResult {
        case .idle:
            return .refresh
        case .testing:
            return .refresh
        case .success:
            return .check
        case .failed:
            return .warning
        }
    }

    private func webdavSection<Content: View>(
        icon: ReaderAssetIcon,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                    ReaderIcon(icon, size: 18, accessibilityLabel: title)
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)

                    Text(title)
                        .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                content()
            }
        }
    }

    private func inputRow(
        icon: ReaderAssetIcon,
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            rowLabel(icon: icon, title: title, detail: nil)

            TextField(placeholder, text: text)
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .frame(minHeight: 36)
                .background(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                        .fill(ReaderDesignTokens.Color.controlBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                                .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                        )
                )
#if os(iOS)
                .autocapitalization(.none)
                .disableAutocorrection(true)
#endif
        }
    }

    private func secureInputRow(
        icon: ReaderAssetIcon,
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            rowLabel(icon: icon, title: title, detail: nil)

            SecureField(placeholder, text: text)
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .frame(minHeight: 36)
                .background(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                        .fill(ReaderDesignTokens.Color.controlBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                                .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                        )
                )
        }
    }

    private func valueRow<Content: View>(
        icon: ReaderAssetIcon,
        title: String,
        @ViewBuilder value: () -> Content
    ) -> some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(icon, size: 16, accessibilityLabel: title)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .frame(width: ReaderDesignTokens.settingsRowIconColumn)

            Text(title)
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)

            Spacer()

            value()
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: ReaderDesignTokens.settingsRowMinHeight)
    }

    private func rowLabel(icon: ReaderAssetIcon, title: String, detail: String?) -> some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(icon, size: 16, accessibilityLabel: title)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .frame(width: ReaderDesignTokens.settingsRowIconColumn)

            Text(title)
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let detail {
                Text(detail)
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 32)
    }

    private func actionButton(
        icon: ReaderAssetIcon,
        title: String,
        isBusy: Bool,
        disabled: Bool,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ReaderIcon(isBusy ? .refresh : icon, size: 16, accessibilityLabel: title)
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .lineLimit(1)
            }
            .foregroundColor(disabled ? ReaderDesignTokens.Color.primaryDark : .white)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssImportPanelLabelMinHeight)
            .background(
                Capsule()
                    .fill(disabled ? ReaderDesignTokens.Color.chipBackground : actionColor(isDestructive: isDestructive))
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(title)
    }

    private func actionColor(isDestructive: Bool) -> Color {
        isDestructive ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.primaryDark
    }

    @ViewBuilder
    private func resultRow(_ result: ConnectionTestResult, loadingMessage: String) -> some View {
        switch result {
        case .idle:
            EmptyView()
        case .testing:
            inlineStatusRow(icon: .refresh, message: loadingMessage)
        case .success(let message):
            inlineStatusRow(icon: .check, message: message)
        case .failed(let message):
            inlineStatusRow(icon: .warning, message: message)
        }
    }

    private func inlineStatusRow(icon: ReaderAssetIcon, message: String) -> some View {
        HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(icon, size: 16, accessibilityLabel: message)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

            Text(message)
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .frame(minHeight: ReaderDesignTokens.settingsRowMinHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.controlBackground)
        )
    }

    private func conflictRow(_ conflict: WebDAVProgressSyncConflict) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            rowLabel(icon: .warning, title: conflict.resolved.chapterTitle, detail: nil)

            Text(progressConflictResolutionTitle(conflict.resolution))
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                .foregroundStyle(.secondary)

            HStack {
                Text("本机 \(progressPercent(conflict.local.progressRatio))")
                Spacer()
                Text("远端 \(progressPercent(conflict.remote.progressRatio))")
            }
            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.controlBackground)
        )
    }

    private func scheduleTitle(_ schedule: BackupSchedule) -> String {
        switch schedule {
        case .daily:
            return "每日"
        case .weekly:
            return "每周"
        case .manual:
            return "手动"
        }
    }

    private func isTesting(_ result: ConnectionTestResult) -> Bool {
        if case .testing = result {
            return true
        }
        return false
    }

    private func progressConflictResolutionTitle(_ resolution: WebDAVProgressConflictResolution) -> String {
        switch resolution {
        case .localKept:
            return "保留本机进度"
        case .remoteApplied:
            return "应用远端进度"
        }
    }

    private func progressPercent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value * 100))%"
    }

    private func remoteBackupTitle(_ backup: WebDAVRemoteBackup) -> String {
        guard let byteCount = backup.byteCount else { return backup.filename }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(backup.filename) (\(formatter.string(fromByteCount: byteCount)))"
    }
}
