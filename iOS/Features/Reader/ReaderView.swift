import SwiftUI
import ReaderCoreModels
import ReaderAppSupport
import ReaderShellValidation

public struct ReaderView: View {
    @StateObject private var viewModel: ReaderViewModel
    @StateObject private var ttsPlayer = ReaderTTSPlayer()
    @State private var showSettings = false
    @State private var showTTS = false
    @State private var readerControlModule: ReaderControlModule = .directory
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var visibleHeight: CGFloat = 0
    @State private var chromeVisible: Bool
    @State private var readerDestination: ReaderInlineDestination?
    @StateObject private var pageTurnTrigger = PageTurnTrigger()
    private let brightnessController = ScreenBrightnessController()
    private let volumeKeyPageTurner = VolumeKeyPageTurner()
    private let motion = MotionEnvironment()
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
        immersiveStart: Bool = false
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
    }

    public var body: some View {
        GeometryReader { proxy in
            readerBody(layout: ReaderResponsiveLayout.make(size: proxy.size))
        }
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showSettings) {
            ReaderSettingsPanel(
                displaySettings: $viewModel.displaySettings,
                onDismiss: {
                    viewModel.saveSettings()
                    showSettings = false
                }
            )
            .presentationDetents([.medium])
        }
        .navigationDestination(item: $readerDestination) { destination in
            switch destination {
            case .sourceSwitch(let bookURL):
                ReaderSourceSwitchFlowView(bookURL: bookURL)
            case .demoRoute(let route):
                ReaderDemoShellView(demoRoute: route)
            }
        }
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
        }
        .onDisappear {
            viewModel.saveSettings()
            ttsPlayer.stop()
            brightnessController.restore()
            volumeKeyPageTurner.stop()
        }
        .safeAreaInset(edge: .bottom) {
            if showTTS {
                ReaderTTSControlView(
                    player: ttsPlayer,
                    contentText: currentContentText
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private func readerBody(layout: ReaderResponsiveLayout) -> some View {
        ZStack {
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

            if chromeVisible {
                VStack(spacing: 0) {
                    progressSurface(layout: layout)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer(minLength: 0)
                }
                .zIndex(2)

                controlChrome(layout: layout)
                .zIndex(2)
            }
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
                onBack: { dismiss() },
                onSourceSwitch: { readerDestination = .sourceSwitch(viewModel.chapterURL) },
                onMore: { showSettings = true },
                style: topBarStyle(for: layout)
            )
            // `.fd-reader-top` inset：top 18 / 左右 14
            .padding(.horizontal, topBarHorizontalInset(for: layout))
            .padding(.top, topBarTopInset(for: layout))
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
    private func actionBar(layout: ReaderResponsiveLayout) -> some View {
        switch viewModel.readerState {
        case .loaded, .cached:
            actionBarContent(layout: layout)
        case .partial:
            fallbackStageActionBar(
                onPrevious: viewModel.canGoPreviousChapter
                    ? goPreviousChapter : nil,
                onNext: viewModel.canGoNextChapter
                    ? goNextChapter : nil,
                onReload: { Task { await viewModel.reload() } },
                layout: layout
            )
        case .failed:
            fallbackStageActionBar(
                onPrevious: nil,
                onNext: nil,
                onReload: { Task { await viewModel.reload() } },
                layout: layout
            )
        case .empty:
            fallbackStageActionBar(
                onPrevious: viewModel.canGoPreviousChapter
                    ? goPreviousChapter : nil,
                onNext: viewModel.canGoNextChapter
                    ? goNextChapter : nil,
                onReload: { Task { await viewModel.reload() } },
                layout: layout
            )
        case .idle, .loading:
            EmptyView()
        case .unsupported:
            EmptyView()
        }
    }

    @ViewBuilder
    private func fallbackStageActionBar(
        onPrevious: (() -> Void)?,
        onNext: (() -> Void)?,
        onReload: (() -> Void)?,
        layout: ReaderResponsiveLayout
    ) -> some View {
        ReaderStageActionBar(
            onPrevious: onPrevious,
            onNext: onNext,
            onReload: onReload,
            onDirectory: openReaderDirectory,
            style: layout.compactModuleNav ? .compactLandscape : .regular
        )
        .frame(width: layout.usesTrailingDock ? layout.dockWidth : nil)
        .padding(.horizontal, layout.usesTrailingDock ? 0 : ReaderDesignTokens.readerModuleNavSideInset)
        .padding(.bottom, layout.usesTrailingDock ? 0 : ReaderDesignTokens.readerModuleNavBottomInset)
    }

    @ViewBuilder
    private func actionBarContent(layout: ReaderResponsiveLayout) -> some View {
        if layout.usesTrailingDock {
            VStack(spacing: layout.dockNavGap) {
                ReaderControlSheet(
                    selectedModule: $readerControlModule,
                    displaySettings: $viewModel.displaySettings,
                    chapterTitle: viewModel.chapterTitle,
                    progressPercentage: viewModel.readingProgress,
                    session: readerControlSession,
                    layout: layout,
                    canGoPreviousChapter: viewModel.canGoPreviousChapter,
                    canGoNextChapter: viewModel.canGoNextChapter,
                    onOpenModule: openReaderModule,
                    onPreviousChapter: goPreviousChapter,
                    onNextChapter: goNextChapter,
                    onSessionAction: handleReaderSessionAction
                )
                .frame(width: layout.dockWidth, height: layout.dockSheetHeight)

                ReaderStageActionBar(
                    onPrevious: viewModel.canGoPreviousChapter
                        ? goPreviousChapter : nil,
                    onNext: viewModel.canGoNextChapter
                        ? goNextChapter : nil,
                    onReload: { Task { await viewModel.reload() } },
                    onDirectory: openReaderDirectory,
                    style: layout.compactModuleNav ? .compactLandscape : .regular
                )
                .frame(width: layout.dockWidth)
                .frame(minHeight: layout.dockNavHeight)
            }
            .frame(width: layout.dockWidth)
        } else {
            VStack(spacing: ReaderDesignTokens.readerControlSheetGap) {
                ReaderControlSheet(
                    selectedModule: $readerControlModule,
                    displaySettings: $viewModel.displaySettings,
                    chapterTitle: viewModel.chapterTitle,
                    progressPercentage: viewModel.readingProgress,
                    session: readerControlSession,
                    layout: layout,
                    canGoPreviousChapter: viewModel.canGoPreviousChapter,
                    canGoNextChapter: viewModel.canGoNextChapter,
                    onOpenModule: openReaderModule,
                    onPreviousChapter: goPreviousChapter,
                    onNextChapter: goNextChapter,
                    onSessionAction: handleReaderSessionAction
                )
                .padding(.horizontal, ReaderDesignTokens.readerControlSheetSideInset)

                ReaderStageActionBar(
                    onPrevious: viewModel.canGoPreviousChapter
                        ? goPreviousChapter : nil,
                    onNext: viewModel.canGoNextChapter
                        ? goNextChapter : nil,
                    onReload: { Task { await viewModel.reload() } },
                    onDirectory: openReaderDirectory
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
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingStateView: some View {
        ProgressView("Loading content...")
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

    private func openReaderModule(_ module: ReaderControlModule) {
        readerDestination = .demoRoute(module.fullDemoRoute)
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
        motion.withMotionAnimation(ReaderMotion.Duration.readerEntry) {
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
}

private enum ReaderControlSessionAction {
    case startTTS
    case pauseTTS
    case stopTTS
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

private enum ReaderControlModule: String, CaseIterable {
    case directory = "目录"
    case tts = "朗读"
    case appearance = "外观"
    case settings = "设置"

    var icon: ReaderAssetIcon {
        switch self {
        case .directory: return .readerModuleDirectory
        case .tts: return .readerModuleTts
        case .appearance: return .readerModuleAppearance
        case .settings: return .readerModuleSettings
        }
    }

    var fullDemoRoute: String {
        switch self {
        case .directory:
            return "reader-full-directory"
        case .tts:
            return "reader-full-tts"
        case .appearance:
            return "reader-full-appearance"
        case .settings:
            return "reader-full-settings"
        }
    }
}

private struct ReaderControlSheet: View {
    @Binding var selectedModule: ReaderControlModule
    @Binding var displaySettings: ReaderDisplaySettings
    let chapterTitle: String
    let progressPercentage: Double
    let session: ReaderControlSession
    let layout: ReaderResponsiveLayout
    let canGoPreviousChapter: Bool
    let canGoNextChapter: Bool
    let onOpenModule: (ReaderControlModule) -> Void
    let onPreviousChapter: () -> Void
    let onNextChapter: () -> Void
    let onSessionAction: (ReaderControlSessionAction) -> Void

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.readerControlSheetGap) {
                ReaderSessionCapsule(session: session)
                modulePicker
                ReaderControlMain(
                    selectedModule: selectedModule,
                    displaySettings: $displaySettings,
                    chapterTitle: chapterTitle,
                    progressPercentage: progressPercentage,
                    layout: layout,
                    session: session,
                    canGoPreviousChapter: canGoPreviousChapter,
                    canGoNextChapter: canGoNextChapter,
                    onOpenModule: onOpenModule,
                    onPreviousChapter: onPreviousChapter,
                    onNextChapter: onNextChapter,
                    onSessionAction: onSessionAction
                )
            }
            .frame(maxWidth: .infinity, minHeight: layout.dockSheetHeight, alignment: .topLeading)
        }
    }

    private var modulePicker: some View {
        HStack(spacing: layout.compactModuleNav ? ReaderDesignTokens.readerDockCompactModuleGap : ReaderDesignTokens.readerModuleNavGap) {
            ForEach(ReaderControlModule.allCases, id: \.self) { module in
                Button {
                    selectedModule = module
                } label: {
                    VStack(spacing: layout.compactModuleNav ? 2 : 4) {
                        ReaderIcon(module.icon, size: layout.compactModuleNav ? 16 : 18, accessibilityLabel: module.rawValue)
                            .frame(width: layout.compactModuleNav ? 26 : 30, height: layout.compactModuleNav ? 26 : 30)
                            .background(
                                Circle()
                                    .fill(selectedModule == module ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.readerModuleIconShellBackground)
                            )
                            .foregroundColor(selectedModule == module ? .white : ReaderDesignTokens.Color.primary)
                        Text(module.rawValue)
                            .font(.system(size: layout.compactModuleNav ? ReaderDesignTokens.readerDockCompactModuleFontSize : ReaderDesignTokens.readerControlLabelFontSize, weight: .heavy))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ReaderSessionCapsule: View {
    let session: ReaderControlSession

    var body: some View {
        HStack(spacing: 8) {
            ReaderIcon(session.icon, size: ReaderDesignTokens.readerSessionCapsuleIconSize, accessibilityLabel: session.title)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            Text("\(session.title) · \(session.statusLabel)")
                .font(.system(size: 12, weight: .heavy))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(session.countdownLabel)
                .font(.system(size: 10, weight: .heavy))
                .frame(width: ReaderDesignTokens.readerSessionCapsuleCountdownSize)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: ReaderDesignTokens.readerSessionCapsuleHeight)
        .background(
            Capsule()
                .fill(ReaderDesignTokens.Color.controlBackground)
        )
    }
}

private struct ReaderAppearanceQuickPanel: View {
    @Binding var displaySettings: ReaderDisplaySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("阅读主题")
                    .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .heavy))
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
                    .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .heavy))
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
                .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .heavy))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: decrease) {
                ReaderIcon(.clear, size: 13, accessibilityLabel: "\(title)减少")
                    .frame(width: ReaderDesignTokens.readerSettingsStepperSize, height: ReaderDesignTokens.readerSettingsStepperSize)
            }
            .buttonStyle(.plain)
            Text(value)
                .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .heavy).monospacedDigit())
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
                    .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .heavy))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(isOn ? "开" : "关")
                    .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize, weight: .heavy))
                    .foregroundStyle(.secondary)
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
    let selectedModule: ReaderControlModule
    @Binding var displaySettings: ReaderDisplaySettings
    let chapterTitle: String
    let progressPercentage: Double
    let layout: ReaderResponsiveLayout
    let session: ReaderControlSession
    let canGoPreviousChapter: Bool
    let canGoNextChapter: Bool
    let onOpenModule: (ReaderControlModule) -> Void
    let onPreviousChapter: () -> Void
    let onNextChapter: () -> Void
    let onSessionAction: (ReaderControlSessionAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.readerControlSheetGap) {
            actionRow

            mainPanel
        }
    }

    @ViewBuilder
    private var mainPanel: some View {
        if selectedModule == .appearance {
            ReaderAppearanceQuickPanel(displaySettings: $displaySettings)
        } else if selectedModule == .settings {
            ReaderSettingsQuickPanel(displaySettings: $displaySettings)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(chapterTitle)
                    .font(.system(size: ReaderDesignTokens.readerTopTitleFontSize, weight: .heavy))
                    .lineLimit(1)
                ProgressView(value: progressPercentage)
                    .tint(ReaderDesignTokens.Color.primary)
                Text(panelDescription)
                    .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: layout.dockChapterPanelHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                    .fill(ReaderDesignTokens.Color.controlBackground)
            )
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        if selectedModule == .tts {
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
        } else {
            HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                chapterActionChip("上一章", isEnabled: canGoPreviousChapter, action: onPreviousChapter)
                PillChip(selectedModule.rawValue, isSelected: true) {
                    triggerModuleAction()
                }
                chapterActionChip("下一章", isEnabled: canGoNextChapter, action: onNextChapter)
            }
            .frame(minHeight: layout.dockControlActionRowHeight)
        }
    }

    private func chapterActionChip(_ title: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        PillChip(title) {
            guard isEnabled else { return }
            action()
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityHint(isEnabled ? "切换章节" : "没有可切换的章节")
    }

    private var panelDescription: String {
        switch selectedModule {
        case .directory:
            return "目录、书签与章节跳转面板入口。"
        case .tts:
            return "朗读控制、语速与运行胶囊入口。"
        case .appearance:
            return "字号、主题、间距和调色板入口。"
        case .settings:
            return "缓存、调试与阅读行为设置入口。"
        }
    }

    private func triggerModuleAction() {
        onOpenModule(selectedModule)
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
    }
}
#endif
