import SwiftUI
import ReaderCoreModels
import ReaderAppSupport
import ReaderShellValidation

public struct ReaderView: View {
    @StateObject private var viewModel: ReaderViewModel
    @StateObject private var ttsPlayer = ReaderTTSPlayer()
    // P3-B: 会话存储（由 AppShellView 注入），并行记录会话状态，不取代既有 ReaderViewModel
    @EnvironmentObject private var sessionStore: ReaderSessionStore
    @State private var showTTS = false
    @State private var readerControlPresentation: ReaderControlPresentation = .control
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var visibleHeight: CGFloat = 0
    @State private var chromeVisible: Bool
    @State private var readerDestination: ReaderInlineDestination?
    @StateObject private var pageTurnTrigger = PageTurnTrigger()
    private let brightnessController = ScreenBrightnessController()
    private let volumeKeyPageTurner = VolumeKeyPageTurner()
    private let motion = MotionEnvironment()
    private let onExit: (() -> Void)?
    @SwiftUI.Environment(\.dismiss) private var dismiss

    /// `immersiveStart = true` 时进入「沉浸阅读」终态：阅读控制层（进度面/动作条/
    /// 朗读·设置·书签工具项）默认隐藏，对齐 `reader.entry.coverToImmersive` /
    /// `reader.entry.actionToImmersive` 的 finalState —— 不自动打开控制层。
    /// 点击正文区域切换控制层显隐（`reader.control.show/hide` 的最小入口）。
    public init(
        chapterURL: String,
        chapterTitle: String,
        chapterList: [TOCItem] = [],
        currentChapterIndex: Int = 0,
        bookID: String? = nil,
        sourceID: String? = nil,
        source: BookSource? = nil,
        immersiveStart: Bool = false,
        onExit: (() -> Void)? = nil
    ) {
        self._viewModel = StateObject(wrappedValue: ReaderViewModel(
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            chapterList: chapterList,
            currentChapterIndex: currentChapterIndex,
            bookID: bookID,
            sourceID: sourceID,
            source: source
        ))
        self._chromeVisible = State(initialValue: !immersiveStart)
        self.onExit = onExit
    }

    public var body: some View {
        GeometryReader { proxy in
            readerBody(layout: ReaderResponsiveLayout.make(size: proxy.size))
        }
        .overlay {
            readerInlineDestinationLayer
        }
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
#endif
        .mainTabBarVisible(false)
        .onAppear {
            Task { await viewModel.loadContent() }
            brightnessController.apply(BrightnessPolicy(
                enabled: viewModel.displaySettings.brightnessOverrideEnabled,
                level: viewModel.displaySettings.brightnessLevel,
                restoreOnExit: true
            ))
            if viewModel.displaySettings.volumeKeyPageTurnEnabled {
                volumeKeyPageTurner.onVolumeChange = { [weak pageTurnTrigger] direction in
                    DispatchQueue.main.async {
                        pageTurnTrigger?.trigger = (direction == .up) ? .next : .previous
                    }
                }
                volumeKeyPageTurner.start()
            }
            // P3-B: 启动阅读会话（并行记录，不影响既有 ReaderViewModel 加载逻辑）
            if sessionStore.currentSession == nil {
                sessionStore.startSession(
                    bookId: viewModel.currentBookID ?? viewModel.chapterURL,
                    chapterURL: viewModel.chapterURL,
                    sourceId: viewModel.currentSourceID
                )
            }
        }
        .onDisappear {
            viewModel.saveSettings()
            ttsPlayer.stop()
            brightnessController.restore()
            volumeKeyPageTurner.stop()
            // P3-B: 结束阅读会话
            sessionStore.endSession()
        }
    }

    @ViewBuilder
    private var readerInlineDestinationLayer: some View {
        switch readerDestination {
        case .some(.sourceSwitch(let bookURL)):
            ReaderSourceSwitchFlowView(bookURL: bookURL, onExit: {
                readerDestination = nil
            })
            .transition(.move(edge: .trailing).combined(with: .opacity))
        case .some(.demoRoute(let route)):
            ReaderDemoShellView(demoRoute: route, onExit: {
                readerDestination = nil
            })
            .transition(.move(edge: .trailing).combined(with: .opacity))
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func readerBody(layout: ReaderResponsiveLayout) -> some View {
        DemoReaderShell(layout: layout) {
            contentBackground
                .ignoresSafeArea()

            readerStateView(layout: layout)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 沉浸热区层 —— 对齐 demo `.fd-immersive-hotzone`
            // prev/center/next = 26% / 48% / 26%。Chrome 覆盖层绘制在它上方，
            // 所以按钮不会被透明热区吞掉。
            if viewModel.displaySettings.tapZoneEnabled {
                immersiveHotZoneLayer
                    .allowsHitTesting(true)
            }
        } overlayHost: {
            if chromeVisible {
                VStack(spacing: 0) {
                    progressSurface(layout: layout)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer(minLength: 0)
                }
            }
        } bottomSheetHost: {
            readerBottomSheetHost(layout: layout)
        } moduleNav: {
            readerModuleNavHost(layout: layout)
        } stateHost: {
            EmptyView()
        }
    }

    /// 沉浸热区层 —— 对齐 demo `.fd-immersive-hotzone` 规格（prev 26% / center 48% / next 26%）。
    /// prev/next 在分页模式下触发 `reader.page.turn.prev/next`，center tap 触发 `reader.control.show/hide`，
    /// 用 `motion.withMotionAnimation(ReaderMotion.Duration.readerEntry)` 驱动：
    /// reduced-motion 下即时切换，否则用 240ms ease。
    private var immersiveHotZoneLayer: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(ReaderHotZoneSegment.allCases) { segment in
                    Color.clear
                        .frame(width: geo.size.width * segment.widthRatio)
                        .contentShape(Rectangle())
                        .onTapGesture { handleHotZoneSegment(segment) }
                        .accessibilityLabel(segment.accessibilityLabel)
                }
            }
        }
    }

    private var currentContentText: String {
        switch viewModel.readerState {
        case .loaded(let content), .cached(let content), .partial(let content, _):
            return content.content
        default:
            return ""
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var contentBackground: some View {
        Color(hex: viewModel.displaySettings.backgroundMode.backgroundColor)
    }

    @ViewBuilder
    private func progressSurface(layout: ReaderResponsiveLayout) -> some View {
        if viewModel.totalChapterCount > 0 {
            ReaderProgressSurfaceView(
                chapterIndex: viewModel.currentChapterIndex,
                chapterCount: viewModel.totalChapterCount,
                progressPercentage: viewModel.readingProgress,
                title: viewModel.chapterTitle,
                subtitle: readerTopSubtitle,
                onBack: exitReader,
                onSourceSwitch: { readerDestination = .sourceSwitch(viewModel.chapterURL) },
                onMore: openReaderSettings,
                style: topBarStyle(for: layout)
            )
            // `.fd-reader-top` inset：top 18 / 左右 14
            .padding(.horizontal, topBarHorizontalInset(for: layout))
            .padding(.top, topBarTopInset(for: layout))
        }
    }

    private func exitReader() {
        if let onExit {
            onExit()
        } else {
            dismiss()
        }
    }

    @ViewBuilder
    private func readerStateView(layout: ReaderResponsiveLayout) -> some View {
        switch viewModel.readerState {
        case .idle:
            idleStateView

        case .loading:
            loadingStateView

        case .loaded(let content), .cached(let content):
            loadedContentView(content, layout: layout)

        case .empty:
            emptyStateView

        case .failed(let message):
            failedStateView(message)

        case .unsupported(let reason):
            unsupportedStateView(reason)

        case .partial(let content, let warnings):
            partialContentView(content, warnings: warnings, layout: layout)
        }
    }

    @ViewBuilder
    private func controlChrome(layout: ReaderResponsiveLayout) -> some View {
        if layout.usesTrailingDock {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                actionBar(layout: layout)
                    .frame(width: layout.dockWidth)
                    .padding(.trailing, layout.dockRightInset)
                    .padding(.bottom, layout.dockNavBottomInset)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        } else {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                actionBar(layout: layout)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func readerBottomSheetHost(layout: ReaderResponsiveLayout) -> some View {
        if chromeVisible {
            VStack(spacing: ReaderDesignTokens.readerControlSheetGap) {
                if readerControlSession.isActive {
                    ReaderSessionCapsule(session: readerControlSession)
                        .frame(width: layout.usesTrailingDock ? layout.dockWidth : nil)
                        .padding(.horizontal, layout.usesTrailingDock ? 0 : ReaderDesignTokens.readerControlSheetSideInset)
                        .accessibilityIdentifier("fd-reader-control-session-host")
                }

                if showTTS {
                    ReaderTTSControlView(
                        player: ttsPlayer,
                        contentText: currentContentText
                    )
                    .frame(width: layout.usesTrailingDock ? layout.dockWidth : nil)
                    .padding(.horizontal, layout.usesTrailingDock ? 0 : ReaderDesignTokens.readerControlSheetSideInset)
                    .accessibilityIdentifier("fd-reader-tts-control-host")
                }

                ReaderControlSheet(
                    presentation: readerControlPresentation,
                    displaySettings: $viewModel.displaySettings,
                    chapterTitle: viewModel.chapterTitle,
                    progressPercentage: viewModel.readingProgress,
                    chapterCount: viewModel.totalChapterCount,
                    chapterList: viewModel.chapterList,
                    currentChapterIndex: viewModel.currentChapterIndex,
                    session: readerControlSession,
                    layout: layout,
                    canGoPreviousChapter: viewModel.canGoPreviousChapter,
                    canGoNextChapter: viewModel.canGoNextChapter,
                    onExpandModule: expandReaderModule,
                    onOpenQuickAction: openReaderQuickAction,
                    onPreviousChapter: goPreviousChapter,
                    onNextChapter: goNextChapter,
                    onSelectChapter: viewModel.goToChapter,
                    onSessionAction: handleReaderSessionAction
                )
                .frame(height: layout.usesTrailingDock ? layout.dockSheetHeight : nil)
                .padding(.horizontal, layout.usesTrailingDock ? 0 : ReaderDesignTokens.readerControlSheetSideInset)
            }
        }
    }

    @ViewBuilder
    private func readerModuleNavHost(layout: ReaderResponsiveLayout) -> some View {
        if chromeVisible {
            ReaderStageActionBar(
                activeModule: readerControlPresentation.activeModule,
                onSelectModule: openReaderModule,
                style: layout.compactModuleNav ? .compactLandscape : .regular
            )
            .frame(minHeight: layout.usesTrailingDock ? layout.dockNavHeight : nil)
            .padding(.horizontal, layout.usesTrailingDock ? 0 : ReaderDesignTokens.readerModuleNavSideInset)
        }
    }

    @ViewBuilder
    private func actionBar(layout: ReaderResponsiveLayout) -> some View {
        switch viewModel.readerState {
        case .loaded, .cached, .partial, .failed, .empty:
            actionBarContent(layout: layout)
        case .idle, .loading:
            EmptyView()
        case .unsupported:
            EmptyView()
        }
    }

    @ViewBuilder
    private func actionBarContent(layout: ReaderResponsiveLayout) -> some View {
        if layout.usesTrailingDock {
            VStack(spacing: layout.dockNavGap) {
                if readerControlSession.isActive {
                    ReaderSessionCapsule(session: readerControlSession)
                        .frame(width: layout.dockWidth)
                        .accessibilityIdentifier("fd-reader-control-session-host")
                }

                ReaderControlSheet(
                    presentation: readerControlPresentation,
                    displaySettings: $viewModel.displaySettings,
                    chapterTitle: viewModel.chapterTitle,
                    progressPercentage: viewModel.readingProgress,
                    chapterCount: viewModel.totalChapterCount,
                    chapterList: viewModel.chapterList,
                    currentChapterIndex: viewModel.currentChapterIndex,
                    session: readerControlSession,
                    layout: layout,
                    canGoPreviousChapter: viewModel.canGoPreviousChapter,
                    canGoNextChapter: viewModel.canGoNextChapter,
                    onExpandModule: expandReaderModule,
                    onOpenQuickAction: openReaderQuickAction,
                    onPreviousChapter: goPreviousChapter,
                    onNextChapter: goNextChapter,
                    onSelectChapter: viewModel.goToChapter,
                    onSessionAction: handleReaderSessionAction
                )
                .frame(width: layout.dockWidth, height: layout.dockSheetHeight)

                ReaderStageActionBar(
                    activeModule: readerControlPresentation.activeModule,
                    onSelectModule: openReaderModule,
                    style: layout.compactModuleNav ? .compactLandscape : .regular
                )
                .frame(width: layout.dockWidth)
                .frame(minHeight: layout.dockNavHeight)
            }
            .frame(width: layout.dockWidth)
        } else {
            VStack(spacing: ReaderDesignTokens.readerControlSheetGap) {
                if readerControlSession.isActive {
                    ReaderSessionCapsule(session: readerControlSession)
                        .padding(.horizontal, ReaderDesignTokens.readerControlSheetSideInset)
                        .accessibilityIdentifier("fd-reader-control-session-host")
                }

                ReaderControlSheet(
                    presentation: readerControlPresentation,
                    displaySettings: $viewModel.displaySettings,
                    chapterTitle: viewModel.chapterTitle,
                    progressPercentage: viewModel.readingProgress,
                    chapterCount: viewModel.totalChapterCount,
                    chapterList: viewModel.chapterList,
                    currentChapterIndex: viewModel.currentChapterIndex,
                    session: readerControlSession,
                    layout: layout,
                    canGoPreviousChapter: viewModel.canGoPreviousChapter,
                    canGoNextChapter: viewModel.canGoNextChapter,
                    onExpandModule: expandReaderModule,
                    onOpenQuickAction: openReaderQuickAction,
                    onPreviousChapter: goPreviousChapter,
                    onNextChapter: goNextChapter,
                    onSelectChapter: viewModel.goToChapter,
                    onSessionAction: handleReaderSessionAction
                )
                .padding(.horizontal, ReaderDesignTokens.readerControlSheetSideInset)

                ReaderStageActionBar(
                    activeModule: readerControlPresentation.activeModule,
                    onSelectModule: openReaderModule
                )
                // `.fd-reader-module-nav` inset：左右 24 / 距底 32
                .padding(.horizontal, ReaderDesignTokens.readerModuleNavSideInset)
            }
            .padding(.bottom, ReaderDesignTokens.readerModuleNavBottomInset)
        }
    }

    // MARK: - State Views

    private var idleStateView: some View {
        Text("Loading...")
            .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize))
            .foregroundStyle(ReaderDesignTokens.Color.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingStateView: some View {
        // demo `.fd-reader-loading-panel`：30×30 spinner + 文案，居中。
        VStack(spacing: 8) {
            DemoLoadingSpinner(size: .reader)
            Text("Loading content...")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadedContentView(_ content: ContentPage, layout: ReaderResponsiveLayout) -> some View {
        Group {
            if viewModel.displaySettings.pageTurnMode == .paginated {
                paginatedContentView(content, layout: layout)
            } else {
                scrollContentView(content, layout: layout)
            }
        }
    }

    private func paginatedContentView(_ content: ContentPage, layout: ReaderResponsiveLayout) -> some View {
        PaginatedReaderView(
            title: content.title,
            text: content.content,
            displaySettings: viewModel.displaySettings,
            contentInsets: layout.readingInsets,
            onToggleUI: toggleReaderChrome,
            onProgressUpdate: { ratio in
                viewModel.updateProgress(ratio: ratio)
            },
            pageTurnTrigger: pageTurnTrigger
        )
    }

    private func scrollContentView(_ content: ContentPage, layout: ReaderResponsiveLayout) -> some View {
        ScrollView {
            contentText(title: content.title, text: content.content, layout: layout)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named("scroll")).minY
                            )
                            .preference(
                                key: ContentHeightPreferenceKey.self,
                                value: geo.size.height
                            )
                    }
                )
        }
        .coordinateSpace(name: "scroll")
        .background(
            GeometryReader { scrollGeo in
                Color.clear
                    .preference(
                        key: VisibleHeightPreferenceKey.self,
                        value: scrollGeo.size.height
                    )
            }
        )
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            trackScrollProgress(offset: offset)
        }
        .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
            contentHeight = height
        }
        .onPreferenceChange(VisibleHeightPreferenceKey.self) { height in
            visibleHeight = height
        }
    }

    private func partialContentView(_ content: ContentPage, warnings: [String], layout: ReaderResponsiveLayout) -> some View {
        VStack(spacing: 0) {
            ReaderStateBanner(
                icon: .warning,
                title: "内容不完整",
                messages: warnings.isEmpty ? ["部分正文由缓存或兜底内容呈现。"] : warnings
            )
            .padding(.horizontal, max(ReaderDesignTokens.demoContentHorizontalPadding, layout.readingInsets.leading))
            .padding(.top, 12)
            .padding(.bottom, 10)

            ScrollView {
                contentText(title: content.title, text: content.content, layout: layout)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var emptyStateView: some View {
        centeredReaderStateCard(
            icon: .file,
            title: "暂无正文",
            subtitle: "当前章节还没有可展示的正文内容。"
        )
    }

    private func failedStateView(_ message: String) -> some View {
        centeredReaderStateCard(
            icon: .warning,
            title: "加载失败",
            subtitle: message
        )
    }

    private func unsupportedStateView(_ reason: String) -> some View {
        centeredReaderStateCard(
            icon: .shield,
            title: "暂不支持",
            subtitle: reason
        )
    }

    private func centeredReaderStateCard(icon: ReaderAssetIcon, title: String, subtitle: String) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: ReaderDesignTokens.immersiveReadingLayerTopInset)
            ReaderStateCard(icon: icon, title: title, subtitle: subtitle)
                .padding(.horizontal, ReaderDesignTokens.demoContentHorizontalPadding)
                .frame(maxWidth: 390)
            Spacer(minLength: ReaderDesignTokens.immersiveReadingLayerBottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shared Content Rendering

    private func contentText(title: String, text: String, layout: ReaderResponsiveLayout) -> some View {
        ReaderReadingLayer(
            title: title,
            text: text,
            displaySettings: viewModel.displaySettings,
            insets: layout.readingInsets
        )
    }

    private var readerTopSubtitle: String {
        let sourceLabel = viewModel.currentSourceID.flatMap { $0.isEmpty ? nil : $0 } ?? "当前书源"
        return "\(sourceLabel) · \(String(format: "%.1f", viewModel.readingProgress * 100))% · 共 \(viewModel.totalChapterCount) 章"
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

    // MARK: - Helpers

    private func openReaderDirectory() {
        openReaderModule(.directory)
    }

    private func openReaderSettings() {
        chromeVisible = true
        openReaderModule(.settings)
    }

    private func openReaderModule(_ module: ReaderStageModule) {
        readerControlPresentation = .module(module)
    }

    private func expandReaderModule(_ module: ReaderStageModule) {
        readerDestination = .demoRoute(module.fullDemoRoute)
    }

    private func openReaderQuickAction(_ action: ReaderQuickAction) {
        switch action {
        case .search:
            readerDestination = .demoRoute("content-search")
        case .autoPage:
            readerDestination = .demoRoute("auto-page")
        case .replacement:
            readerDestination = .demoRoute("content-replacement")
        }
    }

    private func handleHotZoneSegment(_ segment: ReaderHotZoneSegment) {
        if segment == .controls {
            toggleReaderChrome()
            return
        }

        guard
            viewModel.displaySettings.pageTurnMode == .paginated,
            let direction = segment.pageTurnDirection
        else {
            return
        }
        pageTurnTrigger.trigger = direction
    }

    private func toggleReaderChrome() {
        // `reader.control.show/hide` —— latest-intent-wins，旧动画被打断。
        // 通过 ReaderMotionAdapter.resolve(request:) 解析契约 MotionId：
        // - show (enter): targetRole="sheet" + containerRole=.readerShell → .overlay_sheet_enter (priority 300)
        // - hide (exit): sourceRole="controlLayer" + containerRole=.readerSurface → .reader_control_hide (priority 300)
        let willShow = !chromeVisible
        let request: MotionRequest = willShow
            ? MotionRequest(operation: .enter, targetRole: "sheet", containerRole: .readerShell)
            : MotionRequest(operation: .exit, sourceRole: "controlLayer", containerRole: .readerSurface)
        let animation = ReaderMotionAdapter.animation(for: request, motion: motion)
        if let animation {
            withAnimation(animation) {
                chromeVisible.toggle()
            }
        } else {
            chromeVisible.toggle()
        }
    }

    private func goPreviousChapter() {
        viewModel.goPreviousChapter()
    }

    private func goNextChapter() {
        viewModel.goNextChapter()
    }

    private var readerControlSession: ReaderControlSession {
        if showTTS || ttsPlayer.playbackState == .playing || ttsPlayer.playbackState == .paused {
            return .tts(playbackState: ttsPlayer.playbackState)
        }
        return .ready
    }

    private func handleReaderSessionAction(_ action: ReaderControlSessionAction) {
        switch action {
        case .startTTS:
            showTTS = true
            ttsPlayer.togglePlayPause(text: currentContentText)
        case .pauseTTS:
            ttsPlayer.pause()
        case .stopTTS:
            ttsPlayer.stop()
            showTTS = false
        }
    }

    private func trackScrollProgress(offset: CGFloat) {
        scrollOffset = offset
        // Compute clamped scroll ratio: 0.0 at top, 1.0 at bottom.
        // offset is negative when scrolled down (content moves up).
        let scrollableDistance = contentHeight - visibleHeight
        guard scrollableDistance > 0 else { return }
        let ratio = (-offset) / scrollableDistance
        viewModel.updateProgress(ratio: ratio)
    }
}

private enum ReaderInlineDestination: Identifiable, Hashable {
    case sourceSwitch(String)
    case demoRoute(String)

    var id: String {
        switch self {
        case .sourceSwitch(let bookURL):
            return "source-switch:\(bookURL)"
        case .demoRoute(let route):
            return "demo-route:\(route)"
        }
    }
}

enum ReaderHotZoneSegment: CaseIterable, Identifiable, Equatable {
    case previousPage
    case controls
    case nextPage

    var id: Self { self }

    var widthRatio: CGFloat {
        switch self {
        case .previousPage:
            return ReaderDesignTokens.hotzonePrevRatio
        case .controls:
            return ReaderDesignTokens.hotzoneCenterRatio
        case .nextPage:
            return ReaderDesignTokens.hotzoneNextRatio
        }
    }

    var pageTurnDirection: PageTurnTrigger.Direction? {
        switch self {
        case .previousPage:
            return .previous
        case .nextPage:
            return .next
        case .controls:
            return nil
        }
    }

    var motionID: String {
        switch self {
        case .previousPage:
            return "reader.page.turn.prev"
        case .controls:
            return "reader.control.show/hide"
        case .nextPage:
            return "reader.page.turn.next"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .previousPage:
            return "上一页"
        case .controls:
            return "显示或隐藏阅读控制层"
        case .nextPage:
            return "下一页"
        }
    }
}

private struct ReaderReadingLayer: View {
    let title: String
    let text: String
    let displaySettings: ReaderDisplaySettings
    let insets: ReaderContentInsets

    var body: some View {
        VStack(alignment: .leading, spacing: paragraphGap) {
            if !displayTitle.isEmpty {
                Text(displayTitle)
                    .font(ReaderTypography.readerDisplayFont(family: displaySettings.fontFamily, size: titleFontSize, weight: .bold))
                    .lineSpacing(titleFontSize * (ReaderDesignTokens.immersiveTitleLineHeight - 1))
                    .multilineTextAlignment(.center)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, max(0, ReaderDesignTokens.immersiveTitleBottomMargin - paragraphGap))
            }

            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(indentedParagraph(paragraph))
                    .font(ReaderTypography.readerDisplayFont(family: displaySettings.fontFamily, size: bodyFontSize))
                    .lineSpacing(bodyFontSize * (ReaderDesignTokens.immersiveBodyLineHeight - 1))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(insets.edgeInsets)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("正文排版层")
    }

    private var displayTitle: String {
        title.replacingOccurrences(of: #"^第\s*\d+\s*章\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var paragraphs: [String] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? [text] : lines
    }

    private var bodyFontSize: CGFloat {
        CGFloat(displaySettings.fontSize)
    }

    private var titleFontSize: CGFloat {
        bodyFontSize + ReaderDesignTokens.immersiveTitleFontSizeOffset
    }

    private var paragraphGap: CGFloat {
        CGFloat(displaySettings.paragraphSpacing)
    }

    private var textColor: SwiftUI.Color {
        Color(hex: displaySettings.backgroundMode.textColor)
    }

    private func indentedParagraph(_ paragraph: String) -> String {
        let indentCount = max(0, Int(ReaderDesignTokens.immersiveBodyParagraphIndent.rounded()))
        return String(repeating: "\u{3000}", count: indentCount) + paragraph
    }
}

enum ReaderControlSession: Equatable {
    case ready
    case tts(playbackState: TTSPlaybackState)

    var icon: ReaderAssetIcon {
        switch self {
        case .ready:
            return .progress
        case .tts:
            return .tts
        }
    }

    var title: String {
        switch self {
        case .ready:
            return "控制层就绪"
        case .tts:
            return "朗读"
        }
    }

    var statusLabel: String {
        switch self {
        case .ready:
            return "ready"
        case .tts(let playbackState):
            switch playbackState {
            case .playing:
                return "运行中"
            case .paused:
                return "已暂停"
            case .finished:
                return "已完成"
            case .idle:
                return "待播放"
            }
        }
    }

    var countdownLabel: String {
        switch self {
        case .ready:
            return "ready"
        case .tts(let playbackState):
            switch playbackState {
            case .playing:
                return "00:22"
            case .paused:
                return "pause"
            case .finished:
                return "done"
            case .idle:
                return "ready"
            }
        }
    }

    var isTTSPlaying: Bool {
        self == .tts(playbackState: .playing)
    }

    var isTTSPaused: Bool {
        self == .tts(playbackState: .paused)
    }

    var isActive: Bool {
        switch self {
        case .ready:
            return false
        case .tts:
            return true
        }
    }
}

private enum ReaderControlSessionAction {
    case startTTS
    case pauseTTS
    case stopTTS
}

private enum ReaderControlPresentation: Equatable {
    case control
    case module(ReaderStageModule)

    var activeModule: ReaderStageModule? {
        switch self {
        case .control:
            return nil
        case .module(let module):
            return module
        }
    }

    var expansionModule: ReaderStageModule {
        activeModule ?? .settings
    }

    var slotIdentifier: String {
        switch self {
        case .control:
            return "fd-reader-control-main"
        case .module:
            return "fd-reader-module-panel"
        }
    }
}

private enum ReaderQuickAction: CaseIterable {
    case search
    case autoPage
    case replacement

    var title: String {
        switch self {
        case .search:
            return "内容搜索"
        case .autoPage:
            return "自动翻页"
        case .replacement:
            return "内容替换"
        }
    }

    var icon: ReaderAssetIcon {
        switch self {
        case .search:
            return .readerContentSearch
        case .autoPage:
            return .readerAutoPage
        case .replacement:
            return .readerContentReplace
        }
    }
}

enum ReaderAppearanceQuickAction: Equatable {
    case fontSize(delta: Int)
    case lineSpacing(delta: Double)
    case theme(ReaderBackgroundMode)
    case pageTurnMode(PageTurnMode)

    func apply(to settings: inout ReaderDisplaySettings) {
        switch self {
        case .fontSize(let delta):
            settings.fontSize = min(32, max(12, settings.fontSize + delta))
        case .lineSpacing(let delta):
            settings.lineSpacing = min(24, max(2, settings.lineSpacing + delta))
        case .theme(let mode):
            settings.backgroundMode = mode
        case .pageTurnMode(let mode):
            settings.pageTurnMode = mode
        }
    }
}

enum ReaderSettingsQuickAction: Equatable {
    case toggleTapZones
    case toggleVolumeKeyPageTurn
    case toggleDualPage
    case toggleBrightnessOverride

    func apply(to settings: inout ReaderDisplaySettings) {
        switch self {
        case .toggleTapZones:
            settings.tapZoneEnabled.toggle()
        case .toggleVolumeKeyPageTurn:
            settings.volumeKeyPageTurnEnabled.toggle()
        case .toggleDualPage:
            settings.dualPageEnabled.toggle()
        case .toggleBrightnessOverride:
            settings.brightnessOverrideEnabled.toggle()
        }
    }
}

private struct ReaderControlSheet: View {
    let presentation: ReaderControlPresentation
    @Binding var displaySettings: ReaderDisplaySettings
    let chapterTitle: String
    let progressPercentage: Double
    let chapterCount: Int
    let chapterList: [TOCItem]
    let currentChapterIndex: Int
    let session: ReaderControlSession
    let layout: ReaderResponsiveLayout
    let canGoPreviousChapter: Bool
    let canGoNextChapter: Bool
    let onExpandModule: (ReaderStageModule) -> Void
    let onOpenQuickAction: (ReaderQuickAction) -> Void
    let onPreviousChapter: () -> Void
    let onNextChapter: () -> Void
    let onSelectChapter: (Int) -> Void
    let onSessionAction: (ReaderControlSessionAction) -> Void

    // P2-B HANDLE-P0-1: grabber 拖拽预览状态
    // 对应 demo `reader.control.handle.press/drag/release`：
    // - press: 0-80ms pressed 反馈（宽度 46→48，颜色加深）
    // - drag: 面板跟手移动，最大预览位移 18pt（handlePullY）
    // - release: 超过阈值（18pt 或容器 8%）→ onExpandModule；否则 handleSnap(120ms) 回原位
    @State private var grabberDragOffset: CGFloat = 0
    @State private var grabberIsPressed: Bool = false
    private let motion = MotionEnvironment()

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.readerControlSheetGap) {
                grabber
                ReaderControlMain(
                    presentation: presentation,
                    displaySettings: $displaySettings,
                    chapterTitle: chapterTitle,
                    progressPercentage: progressPercentage,
                    chapterCount: chapterCount,
                    chapterList: chapterList,
                    currentChapterIndex: currentChapterIndex,
                    layout: layout,
                    session: session,
                    canGoPreviousChapter: canGoPreviousChapter,
                    canGoNextChapter: canGoNextChapter,
                    onExpandModule: onExpandModule,
                    onOpenQuickAction: onOpenQuickAction,
                    onPreviousChapter: onPreviousChapter,
                    onNextChapter: onNextChapter,
                    onSelectChapter: onSelectChapter,
                    onSessionAction: onSessionAction
                )
            }
            .frame(maxWidth: .infinity, minHeight: layout.dockSheetHeight, alignment: .topLeading)
        }
        .accessibilityIdentifier("fd-reader-sheet")
    }

    /// P2-B HANDLE-P0-1: grabber 视图。
    ///
    /// 真源：demo `MOTION_EFFECTS.md` §`reader.control.handle.press/drag/release`。
    /// - press 反馈：0-80ms 视觉宽度 46→48，颜色加深（opacity 0.5→0.7）
    /// - drag：向上拖动跟手，最大预览位移 `handlePullY`(18pt)；向下拖动不预览
    /// - release：向上超过阈值（18pt）→ onExpandModule；否则 120ms (handleSnap) 回原位
    /// - reduced motion：press/drag 仍可用，但 snap 用 instant (0ms)
    private var grabber: some View {
        let grabberWidth: CGFloat = grabberIsPressed ? 48 : 46
        let grabberColorOpacity: Double = grabberIsPressed ? 0.7 : 0.5

        return Capsule()
            .fill(ReaderDesignTokens.Color.mainNavBorder.opacity(grabberColorOpacity))
            .frame(width: grabberWidth, height: 5)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // press 反馈（不论是否开始拖动）
                        if !grabberIsPressed {
                            grabberIsPressed = true
                        }
                        // 向上拖动预览（value.translation.height 为负数），向下不允许
                        let pull = min(0, value.translation.height)
                        // clamp 到 handlePullY (18pt) 上限
                        grabberDragOffset = max(pull, -ReaderMotion.Distance.handlePullY)
                    }
                    .onEnded { value in
                        grabberIsPressed = false
                        let threshold = ReaderMotion.Distance.handlePullY
                        let triggeredExpand = value.translation.height <= -threshold
                        // 释放后清空 dragOffset，使用 handleSnap (120ms) 动画
                        withAnimation(motion.animation(ReaderMotion.Duration.handleSnap)) {
                            grabberDragOffset = 0
                        }
                        if triggeredExpand {
                            onExpandModule(presentation.expansionModule)
                        }
                    }
            )
            .offset(y: grabberDragOffset)
            .accessibilityLabel("展开完整控制页")
            .accessibilityIdentifier("fd-reader-grabber")
    }
}

private struct ReaderSessionCapsule: View {
    let session: ReaderControlSession

    var body: some View {
        HStack(spacing: 8) {
            ReaderIcon(session.icon, size: ReaderDesignTokens.readerSessionCapsuleIconSize, accessibilityLabel: session.title)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            Text("\(session.title) · \(session.statusLabel)")
                .font(.system(size: ReaderDesignTokens.readerModuleFontSize, weight: .black))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(session.countdownLabel)
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                .frame(width: ReaderDesignTokens.readerSessionCapsuleCountdownSize)
                .foregroundStyle(ReaderDesignTokens.Color.muted)
        }
        .padding(.horizontal, 12)
        .frame(height: ReaderDesignTokens.readerSessionCapsuleHeight)
        .background(
            Capsule()
                .fill(ReaderDesignTokens.Color.controlBackground)
        )
    }
}

private struct ReaderDirectoryQuickPanel: View {
    let chapters: [TOCItem]
    let currentChapterIndex: Int
    let fallbackTitle: String
    let onSelectChapter: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if chapters.isEmpty {
                directoryRow(title: fallbackTitle, index: currentChapterIndex, isCurrent: true)
            } else {
                ForEach(Array(chapters.prefix(6).enumerated()), id: \.offset) { _, chapter in
                    directoryRow(
                        title: chapter.chapterTitle,
                        index: chapter.chapterIndex,
                        isCurrent: chapter.chapterIndex == currentChapterIndex
                    )
                    if chapter.chapterIndex != chapters.prefix(6).last?.chapterIndex {
                        Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.readerControlChapterPanelHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.controlBackground)
        )
        .accessibilityIdentifier("fd-reader-toc-panel")
    }

    private func directoryRow(title: String, index: Int, isCurrent: Bool) -> some View {
        Button {
            onSelectChapter(index)
        } label: {
            HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.isEmpty ? "当前章节" : title)
                        .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.ink)
                        .lineLimit(1)
                    Text(isCurrent ? "当前阅读位置" : "第 \(index + 1) 章")
                        .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if isCurrent {
                    Text("当前")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct ReaderTTSQuickPanel: View {
    var body: some View {
        VStack(spacing: 0) {
            optionRow(icon: .tts, title: "播放控制", detail: "上一句 / 播放暂停 / 下一句")
            Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
            optionRow(icon: .motion, title: "语速", detail: "1.0x")
            Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
            optionRow(icon: .volume, title: "音色", detail: "系统女声")
            Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
            optionRow(icon: .currentLocation, title: "范围", detail: "当前章节")
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.readerControlChapterPanelHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.controlBackground)
        )
        .accessibilityIdentifier("fd-reader-tts-panel")
    }

    private func optionRow(icon: ReaderAssetIcon, title: String, detail: String) -> some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(icon, size: 15, accessibilityLabel: title)
                .frame(width: ReaderDesignTokens.settingsRowIconColumn)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            Text(title)
                .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .black))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(detail)
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
    }
}

private struct ReaderAppearanceQuickPanel: View {
    @Binding var displaySettings: ReaderDisplaySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("阅读主题")
                    .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .black))
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(ReaderBackgroundMode.allCases, id: \.self) { mode in
                    Button {
                        perform(.theme(mode))
                    } label: {
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs)
                            .fill(Color(hex: mode.backgroundColor))
                            .frame(
                                width: displaySettings.backgroundMode == mode ? ReaderDesignTokens.readerSettingsLargeSwatchWidth : ReaderDesignTokens.readerSettingsSwatchSize,
                                height: ReaderDesignTokens.readerSettingsSwatchSize
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs)
                                    .stroke(displaySettings.backgroundMode == mode ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("阅读主题\(mode.rawValue)")
                }
            }
            ReaderAppearanceQuickStepper(
                title: "字号",
                value: "\(displaySettings.fontSize)",
                decrease: { perform(.fontSize(delta: -2)) },
                increase: { perform(.fontSize(delta: 2)) }
            )
            ReaderAppearanceQuickStepper(
                title: "行距",
                value: String(format: "%.0f", displaySettings.lineSpacing),
                decrease: { perform(.lineSpacing(delta: -2)) },
                increase: { perform(.lineSpacing(delta: 2)) }
            )
            HStack(spacing: 8) {
                Text("翻页")
                    .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .black))
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(PageTurnMode.allCases, id: \.self) { mode in
                    PillChip(mode == .scroll ? "滚动" : "分页", isSelected: displaySettings.pageTurnMode == mode) {
                        perform(.pageTurnMode(mode))
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: layoutHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.controlBackground)
        )
    }

    private var layoutHeight: CGFloat {
        ReaderDesignTokens.readerControlChapterPanelHeight
    }

    private func perform(_ action: ReaderAppearanceQuickAction) {
        var nextSettings = displaySettings
        action.apply(to: &nextSettings)
        displaySettings = nextSettings
    }
}

private struct ReaderAppearanceQuickStepper: View {
    let title: String
    let value: String
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            Text(title)
                .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .black))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: decrease) {
                ReaderIcon(.clear, size: 13, accessibilityLabel: "\(title)减少")
                    .frame(width: ReaderDesignTokens.readerSettingsStepperSize, height: ReaderDesignTokens.readerSettingsStepperSize)
            }
            .buttonStyle(.plain)
            Text(value)
                .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .black).monospacedDigit())
                .frame(width: 34)
            Button(action: increase) {
                ReaderIcon(.add, size: 13, accessibilityLabel: "\(title)增加")
                    .frame(width: ReaderDesignTokens.readerSettingsStepperSize, height: ReaderDesignTokens.readerSettingsStepperSize)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ReaderSettingsQuickPanel: View {
    @Binding var displaySettings: ReaderDisplaySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReaderSettingsQuickToggleRow(
                icon: .gesture,
                title: "点击热区",
                isOn: displaySettings.tapZoneEnabled,
                action: { perform(.toggleTapZones) }
            )
            ReaderSettingsQuickToggleRow(
                icon: .volume,
                title: "音量键翻页",
                isOn: displaySettings.volumeKeyPageTurnEnabled,
                action: { perform(.toggleVolumeKeyPageTurn) }
            )
            ReaderSettingsQuickToggleRow(
                icon: .file,
                title: "横屏双页",
                isOn: displaySettings.dualPageEnabled,
                action: { perform(.toggleDualPage) }
            )
            ReaderSettingsQuickToggleRow(
                icon: .sun,
                title: "亮度覆盖",
                isOn: displaySettings.brightnessOverrideEnabled,
                action: { perform(.toggleBrightnessOverride) }
            )
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.readerControlChapterPanelHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.controlBackground)
        )
    }

    private func perform(_ action: ReaderSettingsQuickAction) {
        var nextSettings = displaySettings
        action.apply(to: &nextSettings)
        displaySettings = nextSettings
    }
}

private struct ReaderSettingsQuickToggleRow: View {
    let icon: ReaderAssetIcon
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(icon, size: 15, accessibilityLabel: title)
                    .frame(width: ReaderDesignTokens.settingsRowIconColumn)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                Text(title)
                    .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .black))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(isOn ? "开" : "关")
                    .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .black))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                Capsule()
                    .fill(isOn ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.mainNavBorder)
                    .frame(width: 34, height: 18)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .padding(2)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)\(isOn ? "开启" : "关闭")")
    }
}

private struct ReaderControlMain: View {
    let presentation: ReaderControlPresentation
    @Binding var displaySettings: ReaderDisplaySettings
    let chapterTitle: String
    let progressPercentage: Double
    let chapterCount: Int
    let chapterList: [TOCItem]
    let currentChapterIndex: Int
    let layout: ReaderResponsiveLayout
    let session: ReaderControlSession
    let canGoPreviousChapter: Bool
    let canGoNextChapter: Bool
    let onExpandModule: (ReaderStageModule) -> Void
    let onOpenQuickAction: (ReaderQuickAction) -> Void
    let onPreviousChapter: () -> Void
    let onNextChapter: () -> Void
    let onSelectChapter: (Int) -> Void
    let onSessionAction: (ReaderControlSessionAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.readerControlSheetGap) {
            actionRow

            mainPanel
        }
        .accessibilityIdentifier(presentation.slotIdentifier)
    }

    @ViewBuilder
    private var mainPanel: some View {
        switch presentation {
        case .control:
            chapterProgressPanel
        case .module(.directory):
            ReaderDirectoryQuickPanel(
                chapters: chapterList,
                currentChapterIndex: currentChapterIndex,
                fallbackTitle: chapterTitle,
                onSelectChapter: onSelectChapter
            )
        case .module(.tts):
            ReaderTTSQuickPanel()
        case .module(.appearance):
            ReaderAppearanceQuickPanel(displaySettings: $displaySettings)
        case .module(.settings):
            ReaderSettingsQuickPanel(displaySettings: $displaySettings)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        switch presentation {
        case .control:
            quickActionRow
        case .module(.tts):
            HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                PillChip("停止") {
                    onSessionAction(.stopTTS)
                }
                PillChip(session.isTTSPaused ? "继续" : "播放", isSelected: !session.isTTSPlaying) {
                    onSessionAction(.startTTS)
                }
                PillChip("暂停", isSelected: session.isTTSPlaying) {
                    onSessionAction(.pauseTTS)
                }
            }
            .frame(minHeight: layout.dockControlActionRowHeight)
        case .module:
            EmptyView()
        }
    }

    private var quickActionRow: some View {
        HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
            ForEach(ReaderQuickAction.allCases, id: \.self) { action in
                Button {
                    onOpenQuickAction(action)
                } label: {
                    VStack(spacing: 4) {
                        ReaderIcon(action.icon, size: 22, accessibilityLabel: action.title)
                            .frame(width: 34, height: 34)
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                            .background(
                                Circle()
                                    .fill(ReaderDesignTokens.Color.readerModuleIconShellBackground)
                            )
                        Text(action.title)
                            .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .black))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(action.title)
            }
        }
        .frame(minHeight: layout.dockControlActionRowHeight)
    }

    private var chapterProgressPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                chapterStepButton(icon: .chevronLeft, label: "上一章", isEnabled: canGoPreviousChapter, action: onPreviousChapter)
                Text(chapterTitle)
                    .font(.system(size: ReaderDesignTokens.readerTopTitleFontSize, weight: .heavy))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                chapterStepButton(icon: .chevron, label: "下一章", isEnabled: canGoNextChapter, action: onNextChapter)
            }

            HStack(spacing: 8) {
                Text("\(Int(progressPercentage * 100))%")
                    .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .black).monospacedDigit())
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                // demo `.fd-reader-progress`：30px 容器 + 5px bar + 12px thumb。
                DemoReaderProgressBar(progress: progressPercentage, tint: ReaderDesignTokens.Color.primary)
                    .frame(maxWidth: .infinity)
                Text("共 \(max(chapterCount, 1)) 章")
                    .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .black))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: layout.dockChapterPanelHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.controlBackground)
        )
    }

    private func chapterStepButton(icon: ReaderAssetIcon, label: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            ReaderIcon(icon, size: 16, accessibilityLabel: label)
                .frame(width: 34, height: 34)
                .foregroundColor(isEnabled ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.readerModuleTextColor.opacity(0.45))
                .background(
                    Circle()
                        .fill(ReaderDesignTokens.Color.readerModuleIconShellBackground)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    private func moduleInfoPanel(icon: ReaderAssetIcon, title: String, description: String) -> some View {
        Button {
            onExpandModule(presentation.expansionModule)
        } label: {
            HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(icon, size: 18, accessibilityLabel: title)
                    .frame(width: ReaderDesignTokens.settingsRowIconColumn)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .black))
                    Text(description)
                        .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Text("展开")
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: layout.dockChapterPanelHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                    .fill(ReaderDesignTokens.Color.controlBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct VisibleHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#if DEBUG
extension ReaderView {
    /// Debug-only fixture init — for tab bar hiding verification
    public init(fixtureChapterTitle: String, fixtureContent: String) {
        self._viewModel = StateObject(wrappedValue: ReaderViewModel(
            chapterURL: "debug://fixture/chapter",
            chapterTitle: fixtureChapterTitle,
            fixtureContent: fixtureContent
        ))
        self._chromeVisible = State(initialValue: true)
        self.onExit = nil
    }
}
#endif
