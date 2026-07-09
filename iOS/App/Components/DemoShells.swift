import SwiftUI

/// SwiftUI translation of the canonical frontend demo shell constructors.
///
/// Source of truth:
/// `Reader UI/frontend-demo-optimized/shared-shell-kit/kit.js`
/// - `renderMainTabShell`: appFrame / appTopBar / contentRegion / stateHost / mainNav
/// - `renderLibraryShell`: stackFrame / backTopBar / contentRegion / bottomActionHost / sheetHost / dialogHost / stateHost
/// - `renderReaderShell`: readerFrame / readingSurface / readerOverlayHost / bottomSheetHost / readerModuleNav / readerStateHost
/// - `renderSettingsShell`: settingsFrame / backTopBar / settingsContent / bottomActionHost / sheetHost / toastHost / dialogHost / settingsStateHost
/// - `renderFlowShell`: flowFrame / stepRegion / comparisonRegion / resultRegion / stateHost

struct DemoMainTabShell<TopBar: View, ContentRegion: View, StateHost: View, MainNav: View>: View {
    let contentLeadingPadding: CGFloat
    let mainNavAlignment: Alignment
    let topBar: TopBar
    let contentRegion: ContentRegion
    let stateHost: StateHost
    let mainNav: MainNav

    init(
        contentLeadingPadding: CGFloat = 0,
        mainNavAlignment: Alignment = .bottom,
        @ViewBuilder topBar: () -> TopBar,
        @ViewBuilder contentRegion: () -> ContentRegion,
        @ViewBuilder stateHost: () -> StateHost,
        @ViewBuilder mainNav: () -> MainNav
    ) {
        self.contentLeadingPadding = contentLeadingPadding
        self.mainNavAlignment = mainNavAlignment
        self.topBar = topBar()
        self.contentRegion = contentRegion()
        self.stateHost = stateHost()
        self.mainNav = mainNav()
    }

    var body: some View {
        ZStack(alignment: mainNavAlignment) {
            VStack(spacing: 0) {
                topBar
                    .accessibilityIdentifier("fd-main-tab-app-top-bar-slot")
                contentRegion
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("fd-main-tab-content-region")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.leading, contentLeadingPadding)

            stateHost
                .accessibilityIdentifier("fd-main-tab-state-host")

            mainNav
                .accessibilityIdentifier("fd-main-tab-main-nav-slot")
        }
        .background(ReaderDesignTokens.Color.paperSolidAlt.ignoresSafeArea())
        .accessibilityIdentifier("fd-main-tab-phone")
    }
}

extension DemoMainTabShell where TopBar == EmptyView {
    init(
        contentLeadingPadding: CGFloat = 0,
        mainNavAlignment: Alignment = .bottom,
        @ViewBuilder contentRegion: () -> ContentRegion,
        @ViewBuilder stateHost: () -> StateHost,
        @ViewBuilder mainNav: () -> MainNav
    ) {
        self.init(
            contentLeadingPadding: contentLeadingPadding,
            mainNavAlignment: mainNavAlignment,
            topBar: { EmptyView() },
            contentRegion: contentRegion,
            stateHost: stateHost,
            mainNav: mainNav
        )
    }
}

struct DemoLibraryShell<Content: View, Trailing: View, BottomActionHost: View, SheetHost: View, DialogHost: View, StateHost: View>: View {
    let title: String
    let contentStyle: DemoBackScreenContentStyle
    let content: Content
    let trailing: Trailing
    let bottomActionHost: BottomActionHost
    let sheetHost: SheetHost
    let dialogHost: DialogHost
    let stateHost: StateHost
    let onBack: (() -> Void)?
    @SwiftUI.Environment(\.dismiss) private var dismiss

    init(
        title: String,
        contentStyle: DemoBackScreenContentStyle = .paper,
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder bottomActionHost: () -> BottomActionHost,
        @ViewBuilder sheetHost: () -> SheetHost,
        @ViewBuilder dialogHost: () -> DialogHost,
        @ViewBuilder stateHost: () -> StateHost
    ) {
        self.title = title
        self.contentStyle = contentStyle
        self.content = content()
        self.trailing = trailing()
        self.bottomActionHost = bottomActionHost()
        self.sheetHost = sheetHost()
        self.dialogHost = dialogHost()
        self.stateHost = stateHost()
        self.onBack = onBack
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                DemoBackBar(title: title, onBack: handleBack) {
                    trailing
                }
                .accessibilityIdentifier("fd-library-back-top-bar-slot")

                styledContent
                    .accessibilityIdentifier("fd-library-content-region")

                bottomActionHost
                    .accessibilityIdentifier("fd-library-bottom-action-host")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            sheetHost
                .accessibilityIdentifier("fd-library-sheet-host")
            dialogHost
                .accessibilityIdentifier("fd-library-dialog-host")
            stateHost
                .accessibilityIdentifier("fd-library-state-host")
        }
        .background(ReaderDesignTokens.Color.paperSolidAlt.ignoresSafeArea())
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        // NavigationStack 即使 `.toolbar(.hidden, for: .navigationBar)` 仍会预留 ~132pt 导航栏 safe area，
        // 把 DemoBackBar 推到 y≈132pt。忽略顶部 safe area 让 top bar 回到 y≈6pt（对齐 web demo）。
        .ignoresSafeArea(.container, edges: .top)
#endif
        .mainTabBarVisible(false)
        .accessibilityIdentifier("fd-library-shell")
    }

    private func handleBack() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }

    @ViewBuilder
    private var styledContent: some View {
        switch contentStyle {
        case .paper:
            DemoPaperScreen {
                content
            }
        case .custom:
            content
        }
    }
}

extension DemoLibraryShell where Trailing == EmptyView, BottomActionHost == EmptyView, SheetHost == EmptyView, DialogHost == EmptyView, StateHost == EmptyView {
    init(
        title: String,
        contentStyle: DemoBackScreenContentStyle = .paper,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            contentStyle: contentStyle,
            content: content,
            trailing: { EmptyView() },
            bottomActionHost: { EmptyView() },
            sheetHost: { EmptyView() },
            dialogHost: { EmptyView() },
            stateHost: { EmptyView() }
        )
    }
}

extension DemoLibraryShell where BottomActionHost == EmptyView, SheetHost == EmptyView, DialogHost == EmptyView, StateHost == EmptyView {
    init(
        title: String,
        contentStyle: DemoBackScreenContentStyle = .paper,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            title: title,
            contentStyle: contentStyle,
            content: content,
            trailing: trailing,
            bottomActionHost: { EmptyView() },
            sheetHost: { EmptyView() },
            dialogHost: { EmptyView() },
            stateHost: { EmptyView() }
        )
    }
}

struct DemoSettingsShell<Content: View, Trailing: View, BottomActionHost: View, SheetHost: View, ToastHost: View, DialogHost: View, StateHost: View>: View {
    let title: String
    let content: Content
    let trailing: Trailing
    let bottomActionHost: BottomActionHost
    let sheetHost: SheetHost
    let toastHost: ToastHost
    let dialogHost: DialogHost
    let stateHost: StateHost
    let onBack: (() -> Void)?
    @SwiftUI.Environment(\.dismiss) private var dismiss

    init(
        title: String,
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder bottomActionHost: () -> BottomActionHost,
        @ViewBuilder sheetHost: () -> SheetHost,
        @ViewBuilder toastHost: () -> ToastHost,
        @ViewBuilder dialogHost: () -> DialogHost,
        @ViewBuilder stateHost: () -> StateHost
    ) {
        self.title = title
        self.content = content()
        self.trailing = trailing()
        self.bottomActionHost = bottomActionHost()
        self.sheetHost = sheetHost()
        self.toastHost = toastHost()
        self.dialogHost = dialogHost()
        self.stateHost = stateHost()
        self.onBack = onBack
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                DemoBackBar(title: title, onBack: handleBack) {
                    trailing
                }
                .accessibilityIdentifier("fd-settings-back-top-bar-slot")

                content
                    .accessibilityIdentifier("fd-settings-content")

                bottomActionHost
                    .accessibilityIdentifier("fd-settings-bottom-action-host")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            sheetHost
                .accessibilityIdentifier("fd-settings-sheet-host")
            toastHost
                .accessibilityIdentifier("fd-settings-toast-host")
            dialogHost
                .accessibilityIdentifier("fd-settings-dialog-host")
            stateHost
                .accessibilityIdentifier("fd-settings-state-host")
        }
        .background(ReaderDesignTokens.Color.paperSolidAlt.ignoresSafeArea())
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        // NavigationStack 即使 `.toolbar(.hidden, for: .navigationBar)` 仍会预留 ~132pt 导航栏 safe area，
        // 把 DemoBackBar 推到 y≈132pt。忽略顶部 safe area 让 top bar 回到 y≈6pt（对齐 web demo）。
        .ignoresSafeArea(.container, edges: .top)
#endif
        .mainTabBarVisible(false)
        .accessibilityIdentifier("fd-settings-shell")
    }

    private func handleBack() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }
}

struct DemoReaderShell<ReadingSurface: View, OverlayHost: View, BottomSheetHost: View, ModuleNav: View, StateHost: View>: View {
    let layout: ReaderResponsiveLayout
    let readingSurface: ReadingSurface
    let overlayHost: OverlayHost
    let bottomSheetHost: BottomSheetHost
    let moduleNav: ModuleNav
    let stateHost: StateHost

    init(
        layout: ReaderResponsiveLayout,
        @ViewBuilder readingSurface: () -> ReadingSurface,
        @ViewBuilder overlayHost: () -> OverlayHost,
        @ViewBuilder bottomSheetHost: () -> BottomSheetHost,
        @ViewBuilder moduleNav: () -> ModuleNav,
        @ViewBuilder stateHost: () -> StateHost
    ) {
        self.layout = layout
        self.readingSurface = readingSurface()
        self.overlayHost = overlayHost()
        self.bottomSheetHost = bottomSheetHost()
        self.moduleNav = moduleNav()
        self.stateHost = stateHost()
    }

    var body: some View {
        ZStack {
            readingSurface
                .accessibilityIdentifier("fd-reader-reading-surface-slot")

            readerOverlaySlot
                .zIndex(ReaderZIndex.overlay.rawValue)

            stateHost
                .accessibilityIdentifier("fd-reader-state-host")
                .zIndex(ReaderZIndex.overlay.rawValue)
        }
        .background(ReaderDesignTokens.Color.paperSolidAlt.ignoresSafeArea())
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        // NavigationStack 即使 `.toolbar(.hidden, for: .navigationBar)` 仍会预留 ~132pt 导航栏 safe area。
        // 忽略顶部 safe area 让 reader shell 内容回到 y≈0pt（对齐 web demo）。
        .ignoresSafeArea(.container, edges: .top)
#endif
        .mainTabBarVisible(false)
        .accessibilityIdentifier("fd-reader-frame")
    }

    private var readerOverlaySlot: some View {
        ZStack {
            overlayHost
            bottomSheetSlot
                .accessibilityIdentifier("fd-reader-bottom-sheet-host")
            moduleNavSlot
                .accessibilityIdentifier("fd-reader-module-nav")
        }
        .accessibilityIdentifier("fd-reader-overlay-host")
    }

    @ViewBuilder
    private var bottomSheetSlot: some View {
        if layout.usesTrailingDock {
            bottomSheetHost
                .frame(width: layout.dockWidth)
                .padding(.trailing, layout.dockRightInset)
                .padding(.bottom, layout.dockNavBottomInset + layout.dockNavHeight + layout.dockNavGap)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        } else {
            bottomSheetHost
                .padding(.bottom, ReaderDesignTokens.readerModuleNavBottomInset + layout.dockNavHeight + ReaderDesignTokens.readerControlSheetGap)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    @ViewBuilder
    private var moduleNavSlot: some View {
        if layout.usesTrailingDock {
            moduleNav
                .frame(width: layout.dockWidth)
                .frame(minHeight: layout.dockNavHeight)
                .padding(.trailing, layout.dockRightInset)
                .padding(.bottom, layout.dockNavBottomInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        } else {
            moduleNav
                .padding(.bottom, ReaderDesignTokens.readerModuleNavBottomInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

struct DemoFlowShell<StepRegion: View, ComparisonRegion: View, ResultRegion: View, StateHost: View>: View {
    let title: String
    let stepRegion: StepRegion
    let comparisonRegion: ComparisonRegion
    let resultRegion: ResultRegion
    let stateHost: StateHost

    init(
        title: String,
        @ViewBuilder stepRegion: () -> StepRegion,
        @ViewBuilder comparisonRegion: () -> ComparisonRegion,
        @ViewBuilder resultRegion: () -> ResultRegion,
        @ViewBuilder stateHost: () -> StateHost
    ) {
        self.title = title
        self.stepRegion = stepRegion()
        self.comparisonRegion = comparisonRegion()
        self.resultRegion = resultRegion()
        self.stateHost = stateHost()
    }

    var body: some View {
        DemoFlowFrameLayout {
            stepRegion
                .accessibilityIdentifier("fd-flow-step-region")
            comparisonRegion
                .accessibilityIdentifier("fd-flow-comparison-region")
            resultRegion
                .accessibilityIdentifier("fd-flow-result-region")
            stateHost
                .accessibilityIdentifier("fd-flow-state-host")
        }
        .background(ReaderDesignTokens.Color.paperSolidAlt.ignoresSafeArea())
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        // NavigationStack 即使 `.toolbar(.hidden, for: .navigationBar)` 仍会预留 ~132pt 导航栏 safe area。
        // 忽略顶部 safe area 让 flow shell 内容回到 y≈0pt（对齐 web demo）。
        .ignoresSafeArea(.container, edges: .top)
#endif
        .mainTabBarVisible(false)
        .accessibilityIdentifier("fd-flow-frame")
    }
}

private struct DemoFlowFrameLayout: Layout {
    private let expandedBreakpoint: CGFloat = 760
    private let compactBreakpoint: CGFloat = 820
    private let expandedMinHeight: CGFloat = 642

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = resolvedWidth(from: proposal)
        let padding = framePadding(for: width)
        let contentWidth = max(0, width - padding * 2)

        if width >= expandedBreakpoint {
            let columns = expandedColumns(contentWidth: contentWidth)
            let rowHeight = maxHeight(for: subviews, indices: 0..<min(3, subviews.count), columns: columns)
            let stateHeight = sizeForSubview(at: 3, in: subviews, width: contentWidth).height
            let stateGap = stateHeight > 0 ? ReaderDesignTokens.sourceSwitchFlowGap : 0
            return CGSize(
                width: width,
                height: max(expandedMinHeight, padding * 2 + rowHeight + stateGap + stateHeight)
            )
        }

        var totalHeight: CGFloat = 0
        var visibleCount = 0
        for index in 0..<subviews.count {
            let size = sizeForSubview(at: index, in: subviews, width: contentWidth)
            if size.height > 0 {
                if visibleCount > 0 {
                    totalHeight += ReaderDesignTokens.sourceSwitchFlowGap
                }
                totalHeight += size.height
                visibleCount += 1
            }
        }

        return CGSize(width: width, height: padding * 2 + totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let padding = framePadding(for: bounds.width)
        let contentWidth = max(0, bounds.width - padding * 2)
        let origin = CGPoint(x: bounds.minX + padding, y: bounds.minY + padding)

        if bounds.width >= expandedBreakpoint {
            let columns = expandedColumns(contentWidth: contentWidth)
            let rowHeight = maxHeight(for: subviews, indices: 0..<min(3, subviews.count), columns: columns)
            var x = origin.x

            for index in 0..<min(3, subviews.count) {
                subviews[index].place(
                    at: CGPoint(x: x, y: origin.y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: columns[index], height: rowHeight)
                )
                x += columns[index] + ReaderDesignTokens.sourceSwitchFlowGap
            }

            if subviews.indices.contains(3) {
                let stateY = origin.y + rowHeight + ReaderDesignTokens.sourceSwitchFlowGap
                subviews[3].place(
                    at: CGPoint(x: origin.x, y: stateY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: contentWidth, height: nil)
                )
            }
            return
        }

        var y = origin.y
        var visibleCount = 0
        for index in 0..<subviews.count {
            let size = sizeForSubview(at: index, in: subviews, width: contentWidth)
            if size.height > 0 && visibleCount > 0 {
                y += ReaderDesignTokens.sourceSwitchFlowGap
            }
            subviews[index].place(
                at: CGPoint(x: origin.x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: contentWidth, height: nil)
            )
            if size.height > 0 {
                y += size.height
                visibleCount += 1
            }
        }
    }

    private func resolvedWidth(from proposal: ProposedViewSize) -> CGFloat {
        let proposed = proposal.width ?? ReaderDesignTokens.phoneWidth
        if proposed.isFinite && proposed > 0 {
            return proposed
        }
        return ReaderDesignTokens.phoneWidth
    }

    private func framePadding(for width: CGFloat) -> CGFloat {
        width <= compactBreakpoint ? 12 : ReaderDesignTokens.demoContentVerticalPadding
    }

    private func expandedColumns(contentWidth: CGFloat) -> [CGFloat] {
        let fixedWidth = ReaderDesignTokens.sourceSwitchWindowWidth + ReaderDesignTokens.sourceSwitchResultWidth
        let gaps = ReaderDesignTokens.sourceSwitchFlowGap * 2
        let stepWidth = max(300, contentWidth - fixedWidth - gaps)
        return [stepWidth, ReaderDesignTokens.sourceSwitchWindowWidth, ReaderDesignTokens.sourceSwitchResultWidth]
    }

    private func maxHeight(for subviews: Subviews, indices: Range<Int>, columns: [CGFloat]) -> CGFloat {
        indices.reduce(CGFloat.zero) { partial, index in
            let width = columns[min(index, columns.count - 1)]
            return max(partial, sizeForSubview(at: index, in: subviews, width: width).height)
        }
    }

    private func sizeForSubview(at index: Int, in subviews: Subviews, width: CGFloat) -> CGSize {
        guard subviews.indices.contains(index) else {
            return .zero
        }
        return subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
    }
}

extension DemoFlowShell where StateHost == EmptyView {
    init(
        title: String,
        @ViewBuilder stepRegion: () -> StepRegion,
        @ViewBuilder comparisonRegion: () -> ComparisonRegion,
        @ViewBuilder resultRegion: () -> ResultRegion
    ) {
        self.init(
            title: title,
            stepRegion: stepRegion,
            comparisonRegion: comparisonRegion,
            resultRegion: resultRegion,
            stateHost: { EmptyView() }
        )
    }
}
