import SwiftUI
import ReaderShellValidation

/// 「我的」Tab 最小生产 Shell — 设置/WebDAV/备份/同步归入此 Tab
/// Debug-only 入口仅在 #if DEBUG 下可见
public struct MineTabView: View {
    @AppStorage("useRealServices") private var useRealServices = false
    public init() {}

    private var serviceModeText: String {
        switch ReaderCoreServiceProvider.shared.currentMode {
        case .mock: return "mock"
        case .offlineReplay: return "offlineReplay"
        case .controlledOnlineDryRun: return "controlledOnlineDryRun"
        case .controlledOnline: return "controlledOnline"
        case .real: return "real"
        case .rustCore: return "rustCore"
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DemoTopBar(title: "我的")

                DemoPaperScreen {
                    MineDemoSection(title: "个人") {
                        MineNavigationRow(icon: .gear, title: "设置", subtitle: "WebDAV、备份和同步配置") {
                            mineDestination(WebDAVSettingsView())
                        }
                        MineStaticRow(icon: .clock, title: "阅读记录", subtitle: "最近阅读章节和进度")
                        MineStaticRow(icon: .activity, title: "阅读统计", subtitle: "阅读时长、章节数和来源概览")
                        MineStaticRow(icon: .bookmark, title: "收藏/书签", subtitle: "跨书籍的重点片段")
                    }

                    MineDemoSection(title: "备份与同步") {
                        MineNavigationRow(icon: .cloud, title: "WebDAV 备份", subtitle: "连接、测试、导出和恢复") {
                            mineDestination(WebDAVSettingsView())
                        }
                        MineStaticRow(icon: .storage, title: "备份设置", subtitle: "保留策略、自动备份和冲突处理")
                        MineStaticRow(icon: .sync, title: "同步进度", subtitle: "书架、阅读记录和远程备份状态")
                    }

                    MineDemoSection(title: "关于") {
                        MineStaticRow(icon: .info, title: "关于 Reader", subtitle: "版本、反馈和开源信息")
                        MineStaticRow(icon: .badge, title: "版本", subtitle: "当前测试壳版本", detail: "1.0.0")
                    }

                    #if DEBUG
                    developerSection
                    #endif
                }
            }
            .background(ReaderDesignTokens.Color.paperSolid.ignoresSafeArea())
#if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
#endif
        }
    }

    @ViewBuilder
    private func mineDestination<Content: View>(_ content: Content) -> some View {
        content
#if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
#endif
    }

#if DEBUG
    private var developerSection: some View {
        MineDemoSection(title: "Developer Tools") {
            DemoToggleRow(
                icon: .settings,
                title: "Use Real Services",
                subtitle: "切换 ReaderCoreServiceProvider 调用模式",
                isOn: $useRealServices
            )
            MineStatusRow(icon: .code, title: "Service Mode", subtitle: "ReaderCoreServiceProvider", value: serviceModeText)
            MineStatusRow(
                icon: .signal,
                title: "Real Mode Available",
                subtitle: "真实服务适配器可用性",
                value: ReaderCoreServiceProvider.shared.isRealModeAvailable ? "yes" : "no",
                isPositive: ReaderCoreServiceProvider.shared.isRealModeAvailable
            )

            #if canImport(WebKit) && canImport(UIKit)
            MineStatusRow(icon: .globe, title: "WebView Adapter", subtitle: "WebKit / UIKit bridge", value: "available", isPositive: true)
            #else
            MineStatusRow(icon: .globe, title: "WebView Adapter", subtitle: "WebKit / UIKit bridge", value: "unavailable", isPositive: false)
            #endif

            MineNavigationRow(icon: .bug, title: "[DEBUG] Prototype Gallery", subtitle: "查看 demo route 和组件状态") {
                mineDestination(PrototypeGalleryView())
            }
            MineNavigationRow(icon: .monitor, title: "WebView Harness", subtitle: "验证 WebView runtime 能力") {
                mineDestination(WebViewRuntimeHarnessView())
            }
            #if canImport(ReaderCoreNativeAdapter)
            MineNavigationRow(icon: .sourceStack, title: "Native Core Evidence", subtitle: "ReaderCoreNativeAdapter 证据面板") {
                mineDestination(NativeCoreEvidenceView())
            }
            #endif
            MineNavigationRow(icon: .bookOpen, title: "[DEBUG] ReaderView Fixture", subtitle: "验证阅读页隐藏主底栏") {
                mineDestination(ReaderView(
                    fixtureChapterTitle: "测试章节",
                    fixtureContent: "这是一个测试章节。\n\n用于验证阅读页是否隐藏主底栏。\n\n进入此页面后，底部主底栏应不可见。\n\n测试通过标准：底栏已隐藏。"
                ))
            }
            MineNavigationRow(icon: .wifi, title: "[验证] 星星小说网真实搜索", subtitle: "真实网络搜索验证入口") {
                mineDestination(RealNetworkVerifyView())
            }
            MineNavigationRow(icon: .source, title: "[验证] M6 书源导入链路", subtitle: "书源导入和解析验证入口") {
                mineDestination(M6BookSourceImportVerificationView())
            }
        }
    }
#endif
}

private struct MineDemoSection<Content: View>: View {
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
                    .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                VStack(spacing: 0) {
                    content
                }
            }
        }
    }
}

private struct MineNavigationRow<Destination: View>: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String
    let destination: Destination

    init(
        icon: ReaderAssetIcon,
        title: String,
        subtitle: String,
        @ViewBuilder destination: () -> Destination
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.destination = destination()
    }

    var body: some View {
        NavigationLink(destination: destination) {
            DemoIconRow(icon: icon, title: title, subtitle: subtitle, detail: nil) {
                ReaderIcon(.chevron, size: 14, accessibilityLabel: "进入\(title)")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct MineStaticRow: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String
    var detail: String? = nil

    var body: some View {
        DemoIconRow(icon: icon, title: title, subtitle: subtitle, detail: detail) {
            EmptyView()
        }
    }
}

private struct MineStatusRow: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String
    let value: String
    var isPositive: Bool? = nil

    var body: some View {
        DemoIconRow(icon: icon, title: title, subtitle: subtitle, detail: nil) {
            Text(value)
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .heavy, design: .monospaced))
                .foregroundColor(valueColor)
                .lineLimit(1)
        }
    }

    private var valueColor: Color {
        guard let isPositive else {
            return ReaderDesignTokens.Color.primaryDark.opacity(0.74)
        }
        return isPositive ? ReaderDesignTokens.Color.primary : SwiftUI.Color(red: 0.62, green: 0.18, blue: 0.14)
    }
}
