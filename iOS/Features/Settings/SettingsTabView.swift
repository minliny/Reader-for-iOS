import SwiftUI
import ReaderShellValidation

/// 「设置」主 Tab —— 契约要求的一级主底栏。
///
/// 真源：`docs/cross-platform-ui/CROSS_PLATFORM_UI_BASELINE.md` Primary Modules / Settings
/// 约束：书源管理、WebDAV、备份、阅读进度同步、远程书籍、关于、权限/隐私/日志归入此 Tab；
/// 不作为独立主 Tab。
///
/// 本视图只做 Shell 入口与导航，不复刻业务状态机。
public struct SettingsTabView: View {
    @ObservedObject var coordinator: ReadingFlowCoordinator
    private let showsTopBar: Bool
    @State private var activeDemoRoute: String?
    private let motion = MotionEnvironment()

    static let demoRootRoutes: [String] = SettingsRootEntry.demoEntries.map(\.route)

    public init(coordinator: ReadingFlowCoordinator, showsTopBar: Bool = true) {
        self.coordinator = coordinator
        self.showsTopBar = showsTopBar
    }

    public var body: some View {
        ZStack {
            if let activeDemoRoute {
                SettingsDemoShellView(demoRoute: activeDemoRoute, onExit: {
                    motion.withMotionAnimation(AppMotion.Duration.tabSwitch) {
                        self.activeDemoRoute = nil
                    }
                })
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                rootSettingsList
                    .transition(.opacity)
            }
        }
        .background(ReaderDesignTokens.Color.paperSolid.ignoresSafeArea())
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .animation(
            ReaderMotionAdapter.animation(
                for: MotionRequest(operation: .tabSwitch, containerRole: .mainTabShell),
                motion: motion
            ),
            value: activeDemoRoute
        )
    }

    private var rootSettingsList: some View {
        VStack(spacing: 0) {
            if showsTopBar {
                DemoTopBar(title: AppTab.settings.title)
            }

            DemoPaperScreen(bottomPadding: ReaderDesignTokens.mainTabContentBottomPadding) {
                SettingsSection(title: "设置") {
                    ForEach(SettingsRootEntry.demoEntries) { entry in
                        Button {
                            motion.withMotionAnimation(AppMotion.Duration.tabSwitch) {
                                activeDemoRoute = entry.route
                            }
                        } label: {
                            SettingsRootEntryRow(entry: entry)
                        }
                        .buttonStyle(DemoPressButtonStyle())
                    }
                }
            }
        }
    }
}

private struct SettingsRootEntry: Identifiable, Hashable {
    let icon: ReaderAssetIcon
    let title: String
    let route: String

    var id: String { route }

    static let demoEntries: [SettingsRootEntry] = [
        SettingsRootEntry(icon: .gear, title: "通用设置", route: "settings-general"),
        SettingsRootEntry(icon: .bookshelf, title: "书架与搜索设置", route: "bookshelf-search-settings"),
        SettingsRootEntry(icon: .sourceStack, title: "书源管理", route: "source-management"),
        SettingsRootEntry(icon: .sync, title: "同步与备份", route: "sync-backup"),
        SettingsRootEntry(icon: .info, title: "关于与反馈", route: "about-feedback")
    ]
}

private struct SettingsRootEntryRow: View {
    let entry: SettingsRootEntry

    var body: some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(entry.icon, size: 18, accessibilityLabel: entry.title)
                .frame(width: ReaderDesignTokens.settingsRowIconColumn)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)

            Text(entry.title)
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            ReaderIcon(.chevron, size: 14, accessibilityLabel: "进入\(entry.title)")
                .foregroundStyle(ReaderDesignTokens.Color.muted)
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .frame(minHeight: ReaderDesignTokens.settingsRowMinHeight)
        .contentShape(Rectangle())
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                content
            }
        }
    }
}
