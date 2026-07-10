import SwiftUI
import ReaderUIContract

// MARK: - Slice 6 Component Views（同步/冲突/离线/设置/about/app-shell）

struct LoadingView: View {
    let props: LoadingProps
    var body: some View {
        VStack(spacing: 12) {
            ProgressView().progressViewStyle(.circular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AppShellStructureView: View {
    let props: AppShellStructureProps
    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            if let title = props.title {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
            }
            Text("（Slice 6 占位：应用壳结构）")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundColor(ReaderDesignTokens.Color.muted)
        }
        .padding(.horizontal, 16)
    }
}

struct OfflineView: View {
    let props: OfflineProps
    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            Image(ReaderAssetIcon.offline.assetName)
                .font(.system(size: 36)) // 图标尺寸，非文字字号
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Text("离线模式")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OfflineStatePageView: View {
    let props: OfflineStatePageProps
    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            Image(ReaderAssetIcon.offline.assetName)
                .font(.system(size: 36)) // 图标尺寸，非文字字号
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Text("当前处于离线状态")
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.ink)
            Text("（Slice 6 占位）")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }
}

struct SettingsHomePageView: View {
    let props: SettingsHomePageProps
    var body: some View {
        Form {
            Section("设置") {
                NavigationLink("通用") { Text("（Slice 6 占位）") }
                NavigationLink("阅读") { Text("（Slice 6 占位）") }
                NavigationLink("备份与同步") { Text("（Slice 6 占位）") }
                NavigationLink("关于") { Text("（Slice 6 占位）") }
            }
        }
    }
}

struct GlobalSettingsPageView: View {
    let props: GlobalSettingsPageProps
    var body: some View {
        Form {
            Section(props.title ?? "全局设置") {
                Text("（Slice 6 占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

struct SettingsGeneralPageView: View {
    let props: SettingsGeneralPageProps
    var body: some View {
        Form {
            Section(props.title ?? "通用设置") {
                Text("（Slice 6 占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

struct ReadingSettingsEntryPageView: View {
    let props: ReadingSettingsEntryPageProps
    var body: some View {
        Form {
            Section(props.title ?? "阅读设置") {
                Text("（Slice 6 占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

struct BackupSettingsPageView: View {
    let props: BackupSettingsPageProps
    var body: some View {
        Form {
            Section(props.title ?? "备份") {
                Text("（Slice 6 占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

struct BookshelfSearchSettingsPageView: View {
    let props: BookshelfSearchSettingsPageProps
    var body: some View {
        Form {
            Section(props.title ?? "书架搜索设置") {
                Text("（Slice 6 占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

struct SyncBackupPageView: View {
    let props: SyncBackupPageProps
    var body: some View {
        Form {
            Section("备份同步") {
                if let variant = props.variant {
                    LabeledRow(label: "类型", value: variant)
                }
                if let status = props.status {
                    LabeledRow(label: "状态", value: status)
                }
                Text("（Slice 6 占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

struct SyncErrorPageView: View {
    let props: SyncErrorPageProps
    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            Image(ReaderAssetIcon.warning.assetName)
                .font(.system(size: 36)) // 图标尺寸，非文字字号
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            if let title = props.title {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
            }
            if let message = props.message {
                Text(message)
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }
}

struct SyncSettingsEntryPageView: View {
    let props: SyncSettingsEntryPageProps
    var body: some View {
        Form {
            Section(props.title ?? "同步设置") {
                Text("（Slice 6 占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

struct RestoreConflictPageView: View {
    let props: RestoreConflictPageProps
    var body: some View {
        Form {
            Section("冲突解决") {
                Text("（Slice 6 占位，后续 slice 接冲突解决界面）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

struct AboutVersionPageView: View {
    let props: AboutVersionPageProps
    var body: some View {
        Form {
            Section("版本信息") {
                if let title = props.title {
                    LabeledRow(label: "应用", value: title)
                }
                if let version = props.version {
                    LabeledRow(label: "版本", value: version)
                }
            }
        }
    }
}

struct AboutFeedbackPageView: View {
    let props: AboutFeedbackPageProps
    var body: some View {
        Form {
            Section(props.title ?? "关于") {
                Text("（Slice 6 占位，后续 slice 接反馈入口）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - Slice 6 Component Registration

extension ComponentRegistry {
    public static func registerSlice6Components() {
        register([
            (.loading, { component in
                let props = LoadingProps(props: component.props) ?? LoadingProps(props: [:])!
                return AnyView(LoadingView(props: props))
            }),
            (.appShellStructure, { component in
                let props = AppShellStructureProps(props: component.props) ?? AppShellStructureProps(props: [:])!
                return AnyView(AppShellStructureView(props: props))
            }),
            (.offline, { component in
                let props = OfflineProps(props: component.props) ?? OfflineProps(props: [:])!
                return AnyView(OfflineView(props: props))
            }),
            (.offlineStatePage, { component in
                let props = OfflineStatePageProps(props: component.props) ?? OfflineStatePageProps(props: [:])!
                return AnyView(OfflineStatePageView(props: props))
            }),
            (.settingsHomePage, { component in
                let props = SettingsHomePageProps(props: component.props) ?? SettingsHomePageProps(props: [:])!
                return AnyView(SettingsHomePageView(props: props))
            }),
            (.globalSettingsPage, { component in
                let props = GlobalSettingsPageProps(props: component.props) ?? GlobalSettingsPageProps(props: [:])!
                return AnyView(GlobalSettingsPageView(props: props))
            }),
            (.settingsGeneralPage, { component in
                let props = SettingsGeneralPageProps(props: component.props) ?? SettingsGeneralPageProps(props: [:])!
                return AnyView(SettingsGeneralPageView(props: props))
            }),
            (.readingSettingsEntryPage, { component in
                let props = ReadingSettingsEntryPageProps(props: component.props) ?? ReadingSettingsEntryPageProps(props: [:])!
                return AnyView(ReadingSettingsEntryPageView(props: props))
            }),
            (.backupSettingsPage, { component in
                let props = BackupSettingsPageProps(props: component.props) ?? BackupSettingsPageProps(props: [:])!
                return AnyView(BackupSettingsPageView(props: props))
            }),
            (.bookshelfSearchSettingsPage, { component in
                let props = BookshelfSearchSettingsPageProps(props: component.props) ?? BookshelfSearchSettingsPageProps(props: [:])!
                return AnyView(BookshelfSearchSettingsPageView(props: props))
            }),
            (.syncBackupPage, { component in
                let props = SyncBackupPageProps(props: component.props) ?? SyncBackupPageProps(props: [:])!
                return AnyView(SyncBackupPageView(props: props))
            }),
            (.syncErrorPage, { component in
                let props = SyncErrorPageProps(props: component.props) ?? SyncErrorPageProps(props: [:])!
                return AnyView(SyncErrorPageView(props: props))
            }),
            (.syncSettingsEntryPage, { component in
                let props = SyncSettingsEntryPageProps(props: component.props) ?? SyncSettingsEntryPageProps(props: [:])!
                return AnyView(SyncSettingsEntryPageView(props: props))
            }),
            (.restoreConflictPage, { component in
                let props = RestoreConflictPageProps(props: component.props) ?? RestoreConflictPageProps(props: [:])!
                return AnyView(RestoreConflictPageView(props: props))
            }),
            (.aboutVersionPage, { component in
                let props = AboutVersionPageProps(props: component.props) ?? AboutVersionPageProps(props: [:])!
                return AnyView(AboutVersionPageView(props: props))
            }),
            (.aboutFeedbackPage, { component in
                let props = AboutFeedbackPageProps(props: component.props) ?? AboutFeedbackPageProps(props: [:])!
                return AnyView(AboutFeedbackPageView(props: props))
            }),
        ])
    }
}
