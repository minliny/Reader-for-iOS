import SwiftUI
import ReaderAppSupport

struct ReaderDemoShellView: View {
    @State private var state: ReaderDemoRouteState
    @State private var session: ReaderDemoSession = .none
    @State private var displaySettings = ReaderDisplaySettings.default
    private let motion = MotionEnvironment()

    init(demoRoute: String) {
        self._state = State(initialValue: ReaderDemoRouteState(route: demoRoute))
    }

    var body: some View {
        GeometryReader { proxy in
            shellBody(layout: ReaderResponsiveLayout.make(size: proxy.size))
        }
        .toolbar(.hidden, for: .tabBar)
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
    }

    @ViewBuilder
    private func shellBody(layout: ReaderResponsiveLayout) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    SwiftUI.Color(red: 1.0, green: 0.97, blue: 0.91),
                    SwiftUI.Color(red: 0.96, green: 0.90, blue: 0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ReaderDemoReadingSurface()
                .padding(layout.readingInsets.edgeInsets)

            VStack(spacing: 0) {
                ReaderDemoTopBar(state: state, style: topBarStyle(for: layout))
                    .padding(.horizontal, topBarHorizontalInset(for: layout))
                    .padding(.top, topBarTopInset(for: layout))
                Spacer(minLength: 0)
            }

            controlChrome(layout: layout)
        }
    }

    @ViewBuilder
    private func controlChrome(layout: ReaderResponsiveLayout) -> some View {
        if layout.usesTrailingDock, state.presentation == .compact {
            VStack(spacing: 10) {
                Spacer(minLength: 0)
                VStack(spacing: layout.dockNavGap) {
                    panel(layout: layout)
                        .frame(width: layout.dockWidth, height: layout.dockSheetHeight)
                    ReaderDemoModuleNav(
                        activeModule: state.module,
                        style: layout.compactModuleNav ? .compactLandscape : .regular,
                        onSelect: switchCompactModule
                    )
                    .frame(width: layout.dockWidth)
                    .frame(minHeight: layout.dockNavHeight)
                }
                .frame(width: layout.dockWidth)
                .padding(.trailing, layout.dockRightInset)
                .padding(.bottom, layout.dockNavBottomInset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        } else {
            VStack(spacing: 10) {
                Spacer(minLength: 0)
                panel(layout: layout)
                    .padding(.horizontal, ReaderDesignTokens.readerControlSheetSideInset)
                    .padding(.bottom, state.presentation == .compact ? ReaderDesignTokens.readerModuleNavBottomInset + 72 : 18)
                if state.presentation == .compact {
                    ReaderDemoModuleNav(activeModule: state.module, onSelect: switchCompactModule)
                        .padding(.horizontal, ReaderDesignTokens.readerModuleNavSideInset)
                        .padding(.bottom, ReaderDesignTokens.readerModuleNavBottomInset)
                }
            }
        }
    }

    private func topBarTopInset(for layout: ReaderResponsiveLayout) -> CGFloat {
        layout.viewportClass == .compactLandscape ? ReaderDesignTokens.readerTopCompactTopInset : ReaderDesignTokens.readerTopTopInset
    }

    private func topBarHorizontalInset(for layout: ReaderResponsiveLayout) -> CGFloat {
        layout.viewportClass == .tabletExpanded ? ReaderDesignTokens.readerTopTabletSideInset : ReaderDesignTokens.readerTopSideInset
    }

    private func topBarStyle(for layout: ReaderResponsiveLayout) -> ReaderProgressSurfaceStyle {
        layout.viewportClass == .compactLandscape ? .compactLandscape : .regular
    }

    private func switchCompactModule(_ module: ReaderDemoModule) {
        guard let route = module.compactRoute, route != state.route else { return }
        switchRoute(route)
    }

    @ViewBuilder
    private func panel(layout: ReaderResponsiveLayout) -> some View {
        switch state.presentation {
        case .compact:
            ReaderDemoCompactPanel(
                state: state,
                displaySettings: $displaySettings,
                session: session,
                maxHeight: layout.dockSheetHeight,
                onExpand: expandModule,
                onSessionAction: handleSessionAction
            )
        case .full:
            ReaderDemoFullPanel(
                state: state,
                displaySettings: $displaySettings,
                session: session,
                maxHeight: 560,
                onCollapse: collapseModule,
                onSessionAction: handleSessionAction
            )
        case .utility:
            ReaderDemoUtilityPanel(state: state, maxHeight: 590)
        }
    }

    private func expandModule(_ module: ReaderDemoModule) {
        guard let route = module.fullRoute, route != state.route else { return }
        switchRoute(route)
    }

    private func collapseModule(_ module: ReaderDemoModule) {
        guard let route = module.compactRoute, route != state.route else { return }
        switchRoute(route)
    }

    private func switchRoute(_ route: String) {
        motion.withMotionAnimation(ReaderMotion.Duration.panel) {
            state = ReaderDemoRouteState(route: route)
        }
    }

    private func handleSessionAction(_ action: ReaderDemoSessionAction) {
        switch action {
        case .startTTS:
            switchSession(.tts(playing: true))
        case .pauseTTS:
            switchSession(.tts(playing: false))
        case .startAutoPage:
            switchSession(.autoPage(playing: true))
        case .pauseAutoPage:
            switchSession(.autoPage(playing: false))
        case .stop:
            switchSession(.none)
        }
    }

    private func switchSession(_ nextSession: ReaderDemoSession) {
        guard nextSession != session else { return }
        motion.withMotionAnimation(ReaderMotion.Duration.capsuleEnter) {
            session = nextSession
        }
    }
}

enum ReaderDemoPresentation: Equatable {
    case compact
    case full
    case utility
}

enum ReaderDemoModule: String, CaseIterable {
    case directory
    case tts
    case appearance
    case settings
    case search
    case autoPage
    case replacement
    case cache
    case debug

    var title: String {
        switch self {
        case .directory: return "目录"
        case .tts: return "朗读"
        case .appearance: return "界面"
        case .settings: return "设置"
        case .search: return "内容搜索"
        case .autoPage: return "自动翻页"
        case .replacement: return "内容替换"
        case .cache: return "书籍缓存"
        case .debug: return "调试信息"
        }
    }

    var icon: ReaderAssetIcon {
        switch self {
        case .directory: return .readerModuleDirectory
        case .tts: return .readerModuleTts
        case .appearance: return .readerModuleAppearance
        case .settings: return .readerModuleSettings
        case .search: return .readerContentSearch
        case .autoPage: return .readerAutoPage
        case .replacement: return .readerContentReplace
        case .cache: return .storage
        case .debug: return .bug
        }
    }

    var compactRoute: String? {
        switch self {
        case .directory:
            return "toc-bookmarks"
        case .tts:
            return "tts"
        case .appearance:
            return "reader-appearance"
        case .settings:
            return "reader-settings"
        case .search, .autoPage, .replacement, .cache, .debug:
            return nil
        }
    }

    var fullRoute: String? {
        switch self {
        case .directory:
            return "reader-full-directory"
        case .tts:
            return "reader-full-tts"
        case .appearance:
            return "reader-full-appearance"
        case .settings:
            return "reader-full-settings"
        case .search, .autoPage, .replacement, .cache, .debug:
            return nil
        }
    }
}

struct ReaderDemoRouteState: Equatable {
    let route: String
    let title: String
    let module: ReaderDemoModule
    let presentation: ReaderDemoPresentation

    init(route: String) {
        self.route = route
        switch route {
        case "toc-bookmarks":
            self.title = "目录与书签"
            self.module = .directory
            self.presentation = .compact
        case "reader-appearance":
            self.title = "界面设置"
            self.module = .appearance
            self.presentation = .compact
        case "tts":
            self.title = "朗读"
            self.module = .tts
            self.presentation = .compact
        case "reader-settings":
            self.title = "阅读设置"
            self.module = .settings
            self.presentation = .compact
        case "reader-full-directory":
            self.title = "目录大半屏控制窗"
            self.module = .directory
            self.presentation = .full
        case "reader-full-tts":
            self.title = "朗读大半屏控制窗"
            self.module = .tts
            self.presentation = .full
        case "reader-full-appearance":
            self.title = "界面大半屏控制窗"
            self.module = .appearance
            self.presentation = .full
        case "reader-full-settings":
            self.title = "阅读设置大半屏控制窗"
            self.module = .settings
            self.presentation = .full
        case "reader-book-cache":
            self.title = "书籍缓存"
            self.module = .cache
            self.presentation = .utility
        case "reader-debug-info":
            self.title = "调试信息"
            self.module = .debug
            self.presentation = .utility
        case "auto-page":
            self.title = "自动翻页"
            self.module = .autoPage
            self.presentation = .compact
        case "content-search":
            self.title = "内容搜索"
            self.module = .search
            self.presentation = .compact
        case "content-replacement":
            self.title = "内容替换"
            self.module = .replacement
            self.presentation = .compact
        default:
            self.title = "阅读控制层"
            self.module = .directory
            self.presentation = .compact
        }
    }
}

enum ReaderDemoSession: Equatable {
    case none
    case tts(playing: Bool)
    case autoPage(playing: Bool)

    var isActive: Bool {
        self != .none
    }

    var isPlaying: Bool {
        switch self {
        case .tts(let playing), .autoPage(let playing):
            return playing
        case .none:
            return false
        }
    }

    var icon: ReaderAssetIcon {
        switch self {
        case .tts:
            return .tts
        case .autoPage:
            return .readerAutoPage
        case .none:
            return .progress
        }
    }

    var title: String {
        switch self {
        case .tts:
            return "朗读"
        case .autoPage:
            return "自动翻页"
        case .none:
            return "控制层就绪"
        }
    }

    var statusLabel: String {
        guard isActive else { return "ready" }
        return isPlaying ? "运行中" : "已暂停"
    }

    var detailLabel: String {
        switch self {
        case .tts(let playing):
            return playing ? "1.20x · 系统女声" : "1.20x · 已暂停"
        case .autoPage(let playing):
            return playing ? "42 秒/页 · 倒计时" : "42 秒/页 · 已暂停"
        case .none:
            return "无运行会话"
        }
    }

    var countdownLabel: String {
        switch self {
        case .tts(let playing):
            return playing ? "00:22" : "pause"
        case .autoPage(let playing):
            return playing ? "00:42" : "pause"
        case .none:
            return "ready"
        }
    }

    var startMotionID: String? {
        switch self {
        case .tts:
            return "reader.session.tts.start"
        case .autoPage:
            return "reader.session.autoPage.start"
        case .none:
            return nil
        }
    }
}

private enum ReaderDemoSessionAction {
    case startTTS
    case pauseTTS
    case startAutoPage
    case pauseAutoPage
    case stop
}

private struct ReaderDemoReadingSurface: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("第 32 章 雨夜")
                .font(ReaderTypography.demoSerif(size: 23, weight: .bold))
                .lineLimit(1)
            ForEach(Self.paragraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.immersiveBodyFontSize))
                    .lineSpacing(ReaderDesignTokens.immersiveBodyFontSize * (ReaderDesignTokens.immersiveBodyLineHeight - 1))
                    .foregroundColor(SwiftUI.Color(red: 0.20, green: 0.17, blue: 0.14))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private static let paragraphs = [
        "雨声落在旧窗上，像有人隔着长街轻轻敲门。她把书页压平，指尖停在那句被反复标注的旁白上。",
        "灯塔的光越过雾面，照见远处海堤，也照见每一个被藏起来的名字。",
        "这一章的节奏比上一章慢，却把所有线索都收束到了同一个夜晚。"
    ]
}

private struct ReaderDemoTopBar: View {
    let state: ReaderDemoRouteState
    var style: ReaderProgressSurfaceStyle = .regular

    var body: some View {
        HStack(spacing: gap) {
            ReaderIcon(.back, size: 18, accessibilityLabel: "返回")
                .frame(width: backIconButtonSize, height: backIconButtonSize)
                .background(Circle().fill(ReaderDesignTokens.Color.surface.opacity(0.72)))
            VStack(alignment: .leading, spacing: 2) {
                Text("灯塔与雾")
                    .font(.system(size: titleFontSize, weight: .heavy))
                    .lineLimit(1)
                Text("第 32 章 · 38% · \(state.title)")
                    .font(.system(size: subtitleFontSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("38%")
                .font(.system(size: percentFontSize, weight: .heavy).monospacedDigit())
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .frame(width: percentWidth, height: percentHeight)
                .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
        }
        .padding(.horizontal, horizontalPadding)
        .frame(minHeight: minHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.readerTopCornerRadius)
                .fill(ReaderDesignTokens.Color.surface.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.readerTopCornerRadius)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder.opacity(0.72), lineWidth: 1)
                )
        )
    }

    private var minHeight: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactMinHeight : ReaderDesignTokens.readerTopMinHeight
    }

    private var gap: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactGap : 10
    }

    private var horizontalPadding: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactHorizontalPadding : 10
    }

    private var backIconButtonSize: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactMoreColumnWidth : 34
    }

    private var titleFontSize: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactTitleFontSize : ReaderDesignTokens.readerTopTitleFontSize
    }

    private var subtitleFontSize: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactSubtitleFontSize : ReaderDesignTokens.readerTopSubtitleFontSize
    }

    private var percentFontSize: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactSubtitleFontSize : 12
    }

    private var percentWidth: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerTopCompactSourceColumnWidth - 12 : 46
    }

    private var percentHeight: CGFloat {
        style == .compactLandscape ? 24 : 28
    }
}

private struct ReaderDemoModuleNav: View {
    let activeModule: ReaderDemoModule
    var style: ReaderStageActionBarStyle = .regular
    var onSelect: (ReaderDemoModule) -> Void = { _ in }
    private let modules: [ReaderDemoModule] = [.directory, .tts, .appearance, .settings]

    var body: some View {
        HStack(spacing: navGap) {
            ForEach(modules, id: \.self) { module in
                Button {
                    onSelect(module)
                } label: {
                    VStack(spacing: moduleGap) {
                        ReaderIcon(module.icon, size: iconSize, accessibilityLabel: module.title)
                            .frame(width: iconShellSize, height: iconShellSize)
                            .foregroundColor(activeModule == module ? .white : ReaderDesignTokens.Color.primary)
                            .background(Circle().fill(activeModule == module ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.readerModuleIconShellBackground))
                        Text(module.title)
                            .font(.system(size: moduleFontSize, weight: .heavy))
                            .foregroundColor(ReaderDesignTokens.readerModuleTextColor)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(module.title)
                .accessibilityHint("切换阅读控制模块")
            }
        }
        .padding(navPadding)
        .frame(minHeight: navMinHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.readerModuleNavCornerRadius)
                .fill(ReaderDesignTokens.Color.readerModuleNavBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.readerModuleNavCornerRadius)
                        .stroke(ReaderDesignTokens.Color.readerModuleNavBorder, lineWidth: 1)
                )
        )
    }

    private var navGap: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerDockCompactModuleGap : ReaderDesignTokens.readerModuleNavGap
    }

    private var navPadding: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerDockCompactModulePadding : ReaderDesignTokens.readerModuleNavPadding
    }

    private var navMinHeight: CGFloat {
        style == .compactLandscape ? ReaderDesignTokens.readerDockCompactNavHeight : ReaderDesignTokens.readerModuleNavMinHeight
    }

    private var moduleGap: CGFloat {
        style == .compactLandscape ? 2 : ReaderDesignTokens.readerModuleGap
    }

    private var iconSize: CGFloat {
        style == .compactLandscape ? 18 : 22
    }

    private var iconShellSize: CGFloat {
        style == .compactLandscape
            ? ReaderDesignTokens.readerDockCompactModuleIconShellSize
            : ReaderDesignTokens.readerModuleIconShellSize
    }

    private var moduleFontSize: CGFloat {
        style == .compactLandscape
            ? ReaderDesignTokens.readerDockCompactModuleFontSize
            : ReaderDesignTokens.readerModuleFontSize
    }
}

private struct ReaderDemoCompactPanel: View {
    let state: ReaderDemoRouteState
    @Binding var displaySettings: ReaderDisplaySettings
    let session: ReaderDemoSession
    let maxHeight: CGFloat
    let onExpand: (ReaderDemoModule) -> Void
    let onSessionAction: (ReaderDemoSessionAction) -> Void

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                Capsule()
                    .fill(ReaderDesignTokens.Color.mainNavBorder)
                    .frame(width: 46, height: 5)
                    .frame(maxWidth: .infinity)
                header
                if session.isActive {
                    ReaderDemoSessionCapsule(session: session)
                }
                content
            }
        }
        .frame(maxHeight: maxHeight)
    }

    private var header: some View {
        HStack(spacing: 8) {
            ReaderIcon(state.module.icon, size: 18, accessibilityLabel: state.title)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            Text(state.title)
                .font(.system(size: 13, weight: .heavy))
                .lineLimit(1)
            Spacer(minLength: 0)
            if state.module.fullRoute != nil {
                Button {
                    onExpand(state.module)
                } label: {
                    Text("展开")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("展开\(state.module.title)控制窗")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.module {
        case .directory:
            ReaderDemoDirectoryList(limit: 4)
        case .tts:
            ReaderDemoTTSControls(
                isFull: false,
                session: session,
                onSessionAction: onSessionAction
            )
        case .appearance:
            ReaderDemoAppearanceControls(isFull: false, displaySettings: $displaySettings)
        case .settings:
            ReaderDemoSettingsControls(isFull: false, displaySettings: $displaySettings)
        case .search:
            ReaderDemoSearchPanel()
        case .autoPage:
            ReaderDemoAutoPagePanel(session: session, onSessionAction: onSessionAction)
        case .replacement:
            ReaderDemoReplacementPanel()
        case .cache, .debug:
            EmptyView()
        }
    }
}

private struct ReaderDemoFullPanel: View {
    let state: ReaderDemoRouteState
    @Binding var displaySettings: ReaderDisplaySettings
    let session: ReaderDemoSession
    let maxHeight: CGFloat
    let onCollapse: (ReaderDemoModule) -> Void
    let onSessionAction: (ReaderDemoSessionAction) -> Void

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                Capsule()
                    .fill(ReaderDesignTokens.Color.mainNavBorder)
                    .frame(width: 54, height: 5)
                    .frame(maxWidth: .infinity)
                HStack {
                    LabelHeader(icon: state.module.icon, title: state.module.title)
                    Spacer(minLength: 0)
                    if state.module.compactRoute != nil {
                        Button {
                            onCollapse(state.module)
                        } label: {
                            Text("收起")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("收起\(state.module.title)控制窗")
                    }
                }
                Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                if session.isActive {
                    ReaderDemoSessionCapsule(session: session)
                }
                content
            }
        }
        .frame(maxHeight: maxHeight)
    }

    @ViewBuilder
    private var content: some View {
        switch state.module {
        case .directory:
            ReaderDemoDirectoryList(limit: 8)
        case .tts:
            ReaderDemoTTSControls(
                isFull: true,
                session: session,
                onSessionAction: onSessionAction
            )
        case .appearance:
            ReaderDemoAppearanceControls(isFull: true, displaySettings: $displaySettings)
        case .settings:
            ReaderDemoSettingsControls(isFull: true, displaySettings: $displaySettings)
        case .search, .autoPage, .replacement, .cache, .debug:
            EmptyView()
        }
    }
}

private struct ReaderDemoUtilityPanel: View {
    let state: ReaderDemoRouteState
    let maxHeight: CGFloat

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                HStack {
                    LabelHeader(icon: state.module.icon, title: state.title)
                    Spacer(minLength: 0)
                    Text("完成")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                }
                Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                if state.module == .cache {
                    ReaderDemoCachePanel()
                } else {
                    ReaderDemoDebugPanel()
                }
            }
        }
        .frame(maxHeight: maxHeight)
    }
}

private struct LabelHeader: View {
    let icon: ReaderAssetIcon
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            ReaderIcon(icon, size: 18, accessibilityLabel: title)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .lineLimit(1)
        }
    }
}

private struct ReaderDemoDirectoryList: View {
    let limit: Int
    private let chapters = [
        ("第 30 章 旧港", "已读"),
        ("第 31 章 归途", "已缓存"),
        ("第 32 章 雨夜", "当前 · 书签"),
        ("第 33 章 灯塔", "未读"),
        ("第 34 章 海风", "未读"),
        ("第 35 章 回声", "未读"),
        ("第 36 章 信号", "未读"),
        ("第 37 章 黎明", "未读")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(chapters.prefix(limit).enumerated()), id: \.offset) { index, chapter in
                HStack(spacing: 10) {
                    ReaderIcon(index == 2 ? .bookmark : .directory, size: 16)
                        .frame(width: 24)
                        .foregroundColor(index == 2 ? ReaderDesignTokens.Color.primaryDark : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chapter.0)
                            .font(.system(size: 13, weight: index == 2 ? .heavy : .semibold))
                            .lineLimit(1)
                        Text(chapter.1)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                if index < min(limit, chapters.count) - 1 {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
    }
}

private struct ReaderDemoSessionCapsule: View {
    let session: ReaderDemoSession

    var body: some View {
        HStack(spacing: 8) {
            ReaderIcon(session.icon, size: ReaderDesignTokens.readerSessionCapsuleIconSize, accessibilityLabel: session.title)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(session.title) · \(session.statusLabel)")
                    .font(.system(size: 12, weight: .heavy))
                    .lineLimit(1)
                Text(session.detailLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(session.countdownLabel)
                .font(.system(size: 10, weight: .heavy).monospacedDigit())
                .frame(width: ReaderDesignTokens.readerSessionCapsuleCountdownSize + 10)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: ReaderDesignTokens.readerSessionCapsuleHeight)
        .background(
            Capsule()
                .fill(ReaderDesignTokens.Color.controlBackground)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.title)\(session.statusLabel)")
    }
}

private struct ReaderDemoTTSControls: View {
    let isFull: Bool
    let session: ReaderDemoSession
    let onSessionAction: (ReaderDemoSessionAction) -> Void

    private var isPlaying: Bool {
        session == .tts(playing: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                PillButton(icon: .stop, title: "停止") {
                    onSessionAction(.stop)
                }
                PillButton(icon: .play, title: "播放", isPrimary: !isPlaying) {
                    onSessionAction(.startTTS)
                }
                PillButton(icon: .pause, title: "暂停", isPrimary: isPlaying) {
                    onSessionAction(.pauseTTS)
                }
            }
            controlRow("语速", value: "1.20x", options: ["0.8x", "1.0x", "1.2x", "1.5x"])
            controlRow("声音", value: "系统女声", options: ["系统", "清亮", "低沉"])
            if isFull {
                controlRow("定时", value: "30 分钟", options: ["15", "30", "60"])
            }
        }
    }
}

private struct ReaderDemoThemeOption {
    let title: String
    let mode: ReaderBackgroundMode
}

private struct ReaderDemoAppearanceControls: View {
    let isFull: Bool
    @Binding var displaySettings: ReaderDisplaySettings

    private let themeOptions = [
        ReaderDemoThemeOption(title: "暖白", mode: .light),
        ReaderDemoThemeOption(title: "纸色", mode: .sepia),
        ReaderDemoThemeOption(title: "夜间", mode: .dark)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(themeOptions, id: \.title) { option in
                    Button {
                        perform(.theme(option.mode))
                    } label: {
                        Text(option.title)
                            .font(.system(size: 11, weight: .heavy))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 30)
                            .background(
                                Capsule().fill(
                                    displaySettings.backgroundMode == option.mode
                                        ? ReaderDesignTokens.Color.primary.opacity(0.14)
                                        : ReaderDesignTokens.Color.chipBackground
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            ReaderDemoStepperRow(
                title: "字号",
                value: "\(displaySettings.fontSize)",
                decrease: { perform(.fontSize(delta: -2)) },
                increase: { perform(.fontSize(delta: 2)) }
            )
            ReaderDemoStepperRow(
                title: "行距",
                value: String(format: "%.0f", displaySettings.lineSpacing),
                decrease: { perform(.lineSpacing(delta: -2)) },
                increase: { perform(.lineSpacing(delta: 2)) }
            )
            if isFull {
                HStack(spacing: 8) {
                    Text("翻页")
                        .font(.system(size: 12, weight: .heavy))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ReaderDemoModeChip(
                        title: "滚动",
                        isSelected: displaySettings.pageTurnMode == .scroll,
                        action: { perform(.pageTurnMode(.scroll)) }
                    )
                    ReaderDemoModeChip(
                        title: "分页",
                        isSelected: displaySettings.pageTurnMode == .paginated,
                        action: { perform(.pageTurnMode(.paginated)) }
                    )
                }
            }
        }
    }

    private func perform(_ action: ReaderAppearanceQuickAction) {
        var nextSettings = displaySettings
        action.apply(to: &nextSettings)
        displaySettings = nextSettings
    }
}

private struct ReaderDemoSettingsControls: View {
    let isFull: Bool
    @Binding var displaySettings: ReaderDisplaySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReaderDemoToggleRow(
                icon: .gesture,
                title: "点击热区",
                isOn: displaySettings.tapZoneEnabled,
                action: { perform(.toggleTapZones) }
            )
            ReaderDemoToggleRow(
                icon: .volume,
                title: "音量键翻页",
                isOn: displaySettings.volumeKeyPageTurnEnabled,
                action: { perform(.toggleVolumeKeyPageTurn) }
            )
            ReaderDemoToggleRow(
                icon: .file,
                title: "横屏双页",
                isOn: displaySettings.dualPageEnabled,
                action: { perform(.toggleDualPage) }
            )
            ReaderDemoToggleRow(
                icon: .sun,
                title: "亮度覆盖",
                isOn: displaySettings.brightnessOverrideEnabled,
                action: { perform(.toggleBrightnessOverride) }
            )
            if isFull {
                settingRow(icon: .motion, title: "翻页动画", detail: "跟随阅读模式")
                settingRow(icon: .download, title: "缓存策略", detail: "跟随书籍缓存页")
            }
        }
    }

    private func perform(_ action: ReaderSettingsQuickAction) {
        var nextSettings = displaySettings
        action.apply(to: &nextSettings)
        displaySettings = nextSettings
    }
}

private struct ReaderDemoStepperRow: View {
    let title: String
    let value: String
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: decrease) {
                ReaderIcon(.clear, size: 12, accessibilityLabel: "\(title)减少")
                    .frame(width: ReaderDesignTokens.readerSettingsStepperSize, height: ReaderDesignTokens.readerSettingsStepperSize)
            }
            .buttonStyle(.plain)
            Text(value)
                .font(.system(size: 11, weight: .heavy).monospacedDigit())
                .frame(width: 34)
            Button(action: increase) {
                ReaderIcon(.add, size: 12, accessibilityLabel: "\(title)增加")
                    .frame(width: ReaderDesignTokens.readerSettingsStepperSize, height: ReaderDesignTokens.readerSettingsStepperSize)
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: ReaderDesignTokens.readerSettingsPanelRowHeight)
    }
}

private struct ReaderDemoModeChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(
                    Capsule().fill(
                        isSelected ? ReaderDesignTokens.Color.primary.opacity(0.14) : ReaderDesignTokens.Color.chipBackground
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)\(isSelected ? "已选择" : "")")
    }
}

private struct ReaderDemoToggleRow: View {
    let icon: ReaderAssetIcon
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(icon, size: 16, accessibilityLabel: title)
                    .frame(width: ReaderDesignTokens.settingsRowIconColumn)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(isOn ? "开" : "关")
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .heavy))
                    .foregroundStyle(.secondary)
                Capsule()
                    .fill(isOn ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.mainNavBorder)
                    .frame(width: ReaderDesignTokens.settingsSwitchTrackWidth, height: ReaderDesignTokens.settingsSwitchTrackHeight)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: ReaderDesignTokens.settingsSwitchThumbSize, height: ReaderDesignTokens.settingsSwitchThumbSize)
                            .padding(2)
                    }
            }
            .frame(minHeight: 38)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)\(isOn ? "开启" : "关闭")")
    }
}

private struct ReaderDemoSearchPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchField("搜索当前章节或全书内容")
            ReaderDemoDirectoryList(limit: 3)
        }
    }
}

private struct ReaderDemoAutoPagePanel: View {
    let session: ReaderDemoSession
    let onSessionAction: (ReaderDemoSessionAction) -> Void

    private var isPlaying: Bool {
        session == .autoPage(playing: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                PillButton(icon: .play, title: "开始", isPrimary: !isPlaying) {
                    onSessionAction(.startAutoPage)
                }
                PillButton(icon: .pause, title: "暂停", isPrimary: isPlaying) {
                    onSessionAction(.pauseAutoPage)
                }
                PillButton(icon: .stop, title: "停止") {
                    onSessionAction(.stop)
                }
            }
            controlRow("速度", value: "42 秒/页", options: ["慢", "默认", "快"])
            Text("自动翻页会保持当前章节进度，并在控制层显示运行胶囊。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ReaderDemoReplacementPanel: View {
    private let rules = [
        ("雨容称呼", true),
        ("旧称统一", true),
        ("标点清理", false),
        ("广告过滤", true)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            searchField("搜索替换规则")
            ForEach(rules, id: \.0) { rule in
                settingRow(icon: .replace, title: rule.0, detail: rule.1 ? "开启" : "关闭")
            }
        }
    }
}

private struct ReaderDemoCachePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            metricGrid([("12/48", "已缓存章节"), ("128 MB", "当前书籍缓存"), ("已开启", "自动缓存")])
            settingRow(icon: .download, title: "缓存当前章节", detail: "第 32 章")
            settingRow(icon: .refresh, title: "缓存后续章节", detail: "20 章")
            settingRow(icon: .directory, title: "更新缓存目录", detail: "刷新")
            settingRow(icon: .trash, title: "清理本书缓存", detail: "保留进度")
        }
    }
}

private struct ReaderDemoDebugPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            metricGrid([("3/8", "当前页"), ("32/48", "当前章节"), ("0", "当前错误")])
            settingRow(icon: .progress, title: "分页状态", detail: "流式测量分页")
            settingRow(icon: .typo, title: "正文排版", detail: "18 / 1.96")
            settingRow(icon: .sourceSwitch, title: "书源", detail: "优书网 · 128ms")
            settingRow(icon: .log, title: "导出阅读日志", detail: "可用")
        }
    }
}

private func controlRow(_ title: String, value: String, options: [String]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 11, weight: .heavy).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Text(option)
                    .font(.system(size: 10, weight: .heavy))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 28)
                    .background(Capsule().fill(option == value ? ReaderDesignTokens.Color.primary.opacity(0.14) : ReaderDesignTokens.Color.chipBackground))
            }
        }
    }
}

private func settingRow(icon: ReaderAssetIcon, title: String, detail: String) -> some View {
    HStack(spacing: ReaderDesignTokens.settingsRowGap) {
        ReaderIcon(icon, size: 16, accessibilityLabel: title)
            .frame(width: ReaderDesignTokens.settingsRowIconColumn)
            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        Text(title)
            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        Text(detail)
            .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .heavy))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
    .frame(minHeight: 38)
}

private func searchField(_ placeholder: String) -> some View {
    HStack(spacing: 8) {
        ReaderIcon(.search, size: 15, accessibilityLabel: "搜索")
            .foregroundStyle(.secondary)
        Text(placeholder)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        Spacer(minLength: 0)
    }
    .padding(.horizontal, 10)
    .frame(minHeight: 36)
    .background(
        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
            .fill(ReaderDesignTokens.Color.chipBackground)
    )
}

private func metricGrid(_ metrics: [(String, String)]) -> some View {
    HStack(spacing: 8) {
        ForEach(metrics, id: \.0) { metric in
            VStack(spacing: 3) {
                Text(metric.0)
                    .font(.system(size: 14, weight: .heavy).monospacedDigit())
                    .lineLimit(1)
                Text(metric.1)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                    .fill(ReaderDesignTokens.Color.primary.opacity(0.08))
            )
        }
    }
}

private struct PillButton: View {
    let icon: ReaderAssetIcon
    let title: String
    var isPrimary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ReaderIcon(icon, size: 14, accessibilityLabel: title)
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .lineLimit(1)
            }
            .foregroundColor(isPrimary ? .white : ReaderDesignTokens.Color.primaryDark)
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(Capsule().fill(isPrimary ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.chipBackground))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
