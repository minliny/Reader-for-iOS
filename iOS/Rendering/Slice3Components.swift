import SwiftUI
import ReaderUIContract

/// Slice 3 Component Views — 阅读控制层（P0-06）
///
/// 对齐 `view-state.fixtures.json` 的 9 个 control-layer route：
/// - `control-layer-base-v2`：ReaderBase + ReaderTopArea + ReaderControlSheet + ReaderBottomBar
/// - `reader-directory-overlay-v2`：ReaderBase + ReaderTopArea + ReaderDirectoryPanel + ReaderBottomBar
/// - `reader-appearance-overlay-v2`：ReaderBase + ReaderTopArea + ReaderAppearancePanel + ReaderBottomBar
/// - `reader-tts-overlay-v2`：ReaderBase + ReaderTopArea + ReaderTtsPanel + ReaderBottomBar
/// - `reader-settings-overlay-v2`：ReaderBase + ReaderTopArea + ReaderSettingsPanel + ReaderBottomBar
/// - `reader-search-overlay-v2`：ReaderBase + ReaderTopArea + ReaderSearchPanel + ReaderBottomBar
/// - `reader-replace-overlay-v2`：ReaderBase + ReaderTopArea + ReaderReplacePanel + ReaderBottomBar
/// - `reader-auto-scroll-overlay-v2`：ReaderBase + ReaderTopArea + ReaderAutoScrollPanel + ReaderBottomBar
/// - `reader-night-state-v2`：ReaderBase(theme:"night") + ReaderTopArea + ReaderBottomBar + NightToast
///
/// P0-06 验收：控制层显隐不能 remount reader context，也不能改变正文布局。
/// 这些 view 是轻量 overlay/panel，不含 reader context（ReaderBase + 正文流由 Slice 2 注册的
/// ReaderBaseView / ReadingTextFlowView 提供，保持稳定挂载）。

// MARK: - ReaderTopArea

public struct ReaderTopAreaView: View {
    private let props: ReaderTopAreaProps
    public init(props: ReaderTopAreaProps) { self.props = props }
    public var body: some View {
        HStack {
            if let title = props.title {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ReaderDesignTokens.Color.primary)
            }
            Spacer()
            if let chapter = props.chapterLabel {
                Text(chapter)
                    .font(.system(size: 12))
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
        .padding(.horizontal, ReaderDesignTokens.demoContentHorizontalPadding)
        .frame(height: ReaderDesignTokens.topBarMinHeight)
        .accessibilityIdentifier("reader-top-area")
    }
}

// MARK: - ReaderControlSheet

public struct ReaderControlSheetView: View {
    private let props: ReaderControlSheetProps
    public init(props: ReaderControlSheetProps) { self.props = props }
    public var body: some View {
        VStack(spacing: 0) {
            // grabber
            RoundedRectangle(cornerRadius: 2.5)
                .fill(ReaderDesignTokens.Color.muted.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 6)
            HStack {
                Text("阅读控制")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ReaderDesignTokens.Color.primary)
                Spacer()
            }
            .padding(.horizontal, ReaderDesignTokens.demoContentHorizontalPadding)
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: 220)
        .background(ReaderDesignTokens.Color.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.mainNavCornerRadius))
        .accessibilityIdentifier("reader-control-sheet")
    }
}

// MARK: - ReaderBottomBar

public struct ReaderBottomBarView: View {
    private let props: ReaderBottomBarProps
    public init(props: ReaderBottomBarProps) { self.props = props }
    public var body: some View {
        HStack(spacing: 0) {
            bottomItem("目录", icon: "list.bullet", module: "directory")
            bottomItem("朗读", icon: "speaker.wave.2", module: "tts")
            bottomItem("外观", icon: "textformat.size", module: "appearance")
            bottomItem("设置", icon: "gearshape", module: "settings")
        }
        .padding(.horizontal, ReaderDesignTokens.mainNavHorizontalPadding)
        .padding(.vertical, ReaderDesignTokens.mainNavVerticalPadding)
        .frame(height: ReaderDesignTokens.mainNavHeight)
        .background(ReaderDesignTokens.Color.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.mainNavCornerRadius))
        .accessibilityIdentifier("reader-bottom-bar")
    }
    private func bottomItem(_ label: String, icon: String, module: String) -> some View {
        VStack(spacing: ReaderDesignTokens.tabItemGap) {
            Image(systemName: icon)
                .font(.system(size: ReaderDesignTokens.tabItemIconSize, weight: .light))
                .foregroundColor(props.module == module
                    ? ReaderDesignTokens.Color.primary
                    : ReaderDesignTokens.Color.muted)
            Text(label)
                .font(.system(size: ReaderDesignTokens.tabItemFontSize))
                .foregroundColor(props.module == module
                    ? ReaderDesignTokens.Color.primary
                    : ReaderDesignTokens.Color.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ReaderDirectoryPanel

public struct ReaderDirectoryPanelView: View {
    private let props: ReaderDirectoryPanelProps
    public init(props: ReaderDirectoryPanelProps) { self.props = props }
    public var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
            Text("目录")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.primary)
            Text("共 \(props.chapters?.count ?? 0) 章")
                .font(.system(size: 12))
                .foregroundColor(ReaderDesignTokens.Color.muted)
            Spacer(minLength: 0)
        }
        .padding(ReaderDesignTokens.demoContentHorizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderDesignTokens.Color.paperSolidAlt.opacity(0.96))
        .accessibilityIdentifier("reader-directory-panel")
    }
}

// MARK: - ReaderAppearancePanel

public struct ReaderAppearancePanelView: View {
    private let props: ReaderAppearancePanelProps
    public init(props: ReaderAppearancePanelProps) { self.props = props }
    public var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
            Text("外观")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.primary)
            if let theme = props.theme {
                Text("主题：\(theme)")
                    .font(.system(size: 13))
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
            if let size = props.fontSize {
                Text("字号：\(size, specifier: "%.0f")")
                    .font(.system(size: 13))
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(ReaderDesignTokens.demoContentHorizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderDesignTokens.Color.paperSolidAlt.opacity(0.96))
        .accessibilityIdentifier("reader-appearance-panel")
    }
}

// MARK: - ReaderTtsPanel

public struct ReaderTtsPanelView: View {
    private let props: ReaderTtsPanelProps
    public init(props: ReaderTtsPanelProps) { self.props = props }
    public var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
            Text("朗读")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.primary)
            if let state = props.playbackState {
                Text("状态：\(state)")
                    .font(.system(size: 13))
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(ReaderDesignTokens.demoContentHorizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderDesignTokens.Color.paperSolidAlt.opacity(0.96))
        .accessibilityIdentifier("reader-tts-panel")
    }
}

// MARK: - ReaderSettingsPanel

public struct ReaderSettingsPanelView: View {
    private let props: ReaderSettingsPanelProps
    public init(props: ReaderSettingsPanelProps) { self.props = props }
    public var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
            Text("设置")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.primary)
            if let zone = props.tapZone {
                Text("点击翻页：\(zone)")
                    .font(.system(size: 13))
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(ReaderDesignTokens.demoContentHorizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderDesignTokens.Color.paperSolidAlt.opacity(0.96))
        .accessibilityIdentifier("reader-settings-panel")
    }
}

// MARK: - ReaderSearchPanel

public struct ReaderSearchPanelView: View {
    private let props: ReaderSearchPanelProps
    public init(props: ReaderSearchPanelProps) { self.props = props }
    public var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
            Text("搜索")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.primary)
            if let query = props.query, !query.isEmpty {
                Text("查询：\(query)")
                    .font(.system(size: 13))
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(ReaderDesignTokens.demoContentHorizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderDesignTokens.Color.paperSolidAlt.opacity(0.96))
        .accessibilityIdentifier("reader-search-panel")
    }
}

// MARK: - ReaderReplacePanel

public struct ReaderReplacePanelView: View {
    private let props: ReaderReplacePanelProps
    public init(props: ReaderReplacePanelProps) { self.props = props }
    public var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
            Text("内容替换")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.primary)
            if let pattern = props.pattern {
                Text("替换规则：\(pattern)")
                    .font(.system(size: 13))
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(ReaderDesignTokens.demoContentHorizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderDesignTokens.Color.paperSolidAlt.opacity(0.96))
        .accessibilityIdentifier("reader-replace-panel")
    }
}

// MARK: - ReaderAutoScrollPanel

public struct ReaderAutoScrollPanelView: View {
    private let props: ReaderAutoScrollPanelProps
    public init(props: ReaderAutoScrollPanelProps) { self.props = props }
    public var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
            Text("自动滚动")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.primary)
            if let interval = props.interval {
                Text("间隔：\(interval, specifier: "%.1f")s")
                    .font(.system(size: 13))
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(ReaderDesignTokens.demoContentHorizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderDesignTokens.Color.paperSolidAlt.opacity(0.96))
        .accessibilityIdentifier("reader-auto-scroll-panel")
    }
}

// MARK: - NightToast

public struct NightToastView: View {
    private let props: NightToastProps
    public init(props: NightToastProps) { self.props = props }
    public var body: some View {
        if props.visible != false {
            Text(props.message ?? "夜间模式")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.7))
                .clipShape(Capsule())
                .accessibilityIdentifier("night-toast")
        } else {
            EmptyView()
        }
    }
}

// MARK: - Slice 3 Component Registration

extension ComponentRegistry {

    /// 注册 Slice 3 的 11 个阅读控制层 component。
    /// 应在 App 启动时调用（如 ReaderApp.init），与 registerSlice2Components() 一起调用。
    public static func registerSlice3Components() {
        register([
            (.readerTopArea, { component in
                let props = ReaderTopAreaProps(props: [:])!
                    ?? ReaderTopAreaProps(props: [:])!
                return AnyView(ReaderTopAreaView(props: props))
            }),
            (.readerControlSheet, { component in
                let props = ReaderControlSheetProps(props: [:])!
                    ?? ReaderControlSheetProps(props: [:])!
                return AnyView(ReaderControlSheetView(props: props))
            }),
            (.readerBottomBar, { component in
                let props = ReaderBottomBarProps(props: [:])!
                    ?? ReaderBottomBarProps(props: [:])!
                return AnyView(ReaderBottomBarView(props: props))
            }),
            (.readerDirectoryPanel, { component in
                let props = ReaderDirectoryPanelProps(props: [:])!
                    ?? ReaderDirectoryPanelProps(props: [:])!
                return AnyView(ReaderDirectoryPanelView(props: props))
            }),
            (.readerAppearancePanel, { component in
                let props = ReaderAppearancePanelProps(props: [:])!
                    ?? ReaderAppearancePanelProps(props: [:])!
                return AnyView(ReaderAppearancePanelView(props: props))
            }),
            (.readerTtsPanel, { component in
                let props = ReaderTtsPanelProps(props: [:])!
                    ?? ReaderTtsPanelProps(props: [:])!
                return AnyView(ReaderTtsPanelView(props: props))
            }),
            (.readerSettingsPanel, { component in
                let props = ReaderSettingsPanelProps(props: [:])!
                    ?? ReaderSettingsPanelProps(props: [:])!
                return AnyView(ReaderSettingsPanelView(props: props))
            }),
            (.readerSearchPanel, { component in
                let props = ReaderSearchPanelProps(props: [:])!
                    ?? ReaderSearchPanelProps(props: [:])!
                return AnyView(ReaderSearchPanelView(props: props))
            }),
            (.readerReplacePanel, { component in
                let props = ReaderReplacePanelProps(props: [:])!
                    ?? ReaderReplacePanelProps(props: [:])!
                return AnyView(ReaderReplacePanelView(props: props))
            }),
            (.readerAutoScrollPanel, { component in
                let props = ReaderAutoScrollPanelProps(props: [:])!
                    ?? ReaderAutoScrollPanelProps(props: [:])!
                return AnyView(ReaderAutoScrollPanelView(props: props))
            }),
            (.nightToast, { component in
                let props = NightToastProps(props: [:])!
                    ?? NightToastProps(props: [:])!
                return AnyView(NightToastView(props: props))
            })
        ])
    }
}
