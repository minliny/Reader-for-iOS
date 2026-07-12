import SwiftUI
import ReaderUIContract
import ReaderAppSupport

/// Native SwiftUI rendering entry for every route added by Reader UI 2.5.
///
/// The registry classifies each route into one of five domain renderers. This switch is
/// intentionally exhaustive and has no generic fallback, so a new renderer family cannot become
/// a silent placeholder.
struct ReaderContract25RouteScreen: View {
    @State private var navigation: ReaderContract25RouteNavigation
    private let onNavigate: ((ReaderUIContract.RouteId) -> Void)?
    private let onExit: (() -> Void)?

    init(
        routeId: ReaderUIContract.RouteId,
        onNavigate: ((ReaderUIContract.RouteId) -> Void)? = nil,
        onExit: (() -> Void)? = nil
    ) {
        self._navigation = State(initialValue: ReaderContract25RouteNavigation(initialRouteId: routeId))
        self.onNavigate = onNavigate
        self.onExit = onExit
    }

    private var page: ReaderContract25RoutePage {
        guard let page = ReaderContract25RouteRegistry.page(for: navigation.currentRouteId) else {
            preconditionFailure("Reader UI 2.5 route lost its explicit native renderer")
        }
        return page
    }

    /// Reader UI 2.5 routes can enter this screen directly, bypassing `ContractHostView`, so the
    /// route screen is also a production ScreenGraph shadow-consumption entry. It remains
    /// observation-only and follows the current local navigation route.
    var screenGraphShadowPlan: Result<ReaderScreenGraphRoutePlan, ReaderScreenGraphPlannerError> {
        ReaderScreenGraphProductionPlanner.plan(routeId: navigation.currentRouteId)
    }

    @ViewBuilder
    var body: some View {
        Group {
            switch page.renderer {
            case .readerWorkspaceState:
                readerStateScreen(page, icon: .appearance)
            case .readerReplacementState:
                readerStateScreen(page, icon: .readerContentReplace)
            case .readerContentState:
                readerStateScreen(page, icon: contentStateIcon(for: page.routeId))
            case .sourceSwitchState:
                sourceSwitchStateScreen(page)
            case .localImportState:
                localImportStateScreen(page)
            }
        }
        .overlay(alignment: .topTrailing) {
            ReaderScreenGraphShadowDiagnostic(result: screenGraphShadowPlan)
        }
    }

    private func readerStateScreen(
        _ page: ReaderContract25RoutePage,
        icon: ReaderAssetIcon
    ) -> some View {
        GeometryReader { proxy in
            let layout = ReaderResponsiveLayout.make(size: proxy.size)
            DemoReaderShell(layout: layout) {
                ZStack {
                    LinearGradient(
                        colors: [
                            ReaderDesignTokens.Color.readerPaperGradientStart,
                            ReaderDesignTokens.Color.readerPaperGradientEnd
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    VStack(alignment: .leading, spacing: 18) {
                        Text("第 32 章 雨夜")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(ReaderDesignTokens.Color.ink)
                        Text("雨声在窗外连成一片，阅读上下文与当前位置在状态处理期间保持不变。")
                            .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.immersiveBodyFontSize))
                            .lineSpacing(ReaderDesignTokens.immersiveBodyFontSize * 0.72)
                            .foregroundColor(ReaderDesignTokens.Color.ink)
                    }
                    .padding(layout.readingInsets.edgeInsets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } overlayHost: {
                contractReaderTopBar(page)
                    .padding(.horizontal, ReaderDesignTokens.readerTopSideInset)
                    .padding(.top, ReaderDesignTokens.readerTopTopInset)
                    .frame(maxHeight: .infinity, alignment: .top)
            } bottomSheetHost: {
                readerStateBottomSheet(page: page, icon: icon, layout: layout)
            } moduleNav: {
                EmptyView()
            } stateHost: {
                EmptyView()
            }
        }
        .accessibilityIdentifier("reader-contract25-\(page.routeId.rawValue)")
    }

    @ViewBuilder
    private func readerStateBottomSheet(
        page: ReaderContract25RoutePage,
        icon: ReaderAssetIcon,
        layout: ReaderResponsiveLayout
    ) -> some View {
        switch page.renderer {
        case .readerContentState:
            W2ReaderContentFlowContent(page: page, onAction: activate)
                .padding(.horizontal, layout.usesTrailingDock ? 0 : ReaderDesignTokens.readerControlSheetSideInset)
        case .readerReplacementState:
            W5ReplaceRuleFlowContent(page: page, onAction: activate)
                .padding(.horizontal, layout.usesTrailingDock ? 0 : ReaderDesignTokens.readerControlSheetSideInset)
        default:
            ReaderContract25StateCard(page: page, icon: icon, onAction: activate)
                .padding(.horizontal, layout.usesTrailingDock ? 0 : ReaderDesignTokens.readerControlSheetSideInset)
        }
    }

    private func sourceSwitchStateScreen(_ page: ReaderContract25RoutePage) -> some View {
        DemoFlowShell(title: page.title) {
            W3SourceSwitchStepRegion(page: page, onAction: activate)
        } comparisonRegion: {
            W3SourceSwitchComparisonRegion(page: page)
        } resultRegion: {
            W3SourceSwitchResultRegion(page: page)
        }
        .accessibilityIdentifier("reader-contract25-\(page.routeId.rawValue)")
    }

    @ViewBuilder
    private func localImportStateScreen(_ page: ReaderContract25RoutePage) -> some View {
        DemoBackScreen(title: page.title, onBack: { onExit?() }) {
            W1ImportFlowContent(page: page, onAction: activate)
        }
        .accessibilityIdentifier("reader-contract25-\(page.routeId.rawValue)")
    }

    private func contractReaderTopBar(_ page: ReaderContract25RoutePage) -> some View {
        HStack(spacing: 10) {
            Button { onExit?() } label: {
                ReaderIcon(.back, size: 18, accessibilityLabel: "返回")
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(ReaderDesignTokens.Color.surface.opacity(0.72)))
            }
            .buttonStyle(DemoPressButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(page.title)
                    .font(.system(size: ReaderDesignTokens.readerTopTitleFontSize, weight: .heavy))
                    .lineLimit(1)
                Text(page.routeId.rawValue)
                    .font(.system(size: ReaderDesignTokens.readerTopSubtitleFontSize, weight: .semibold))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ReaderIcon(icon(for: page.renderer), size: 18, accessibilityLabel: page.title)
                .frame(width: 34, height: 34)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
        }
        .padding(.horizontal, 10)
        .frame(minHeight: ReaderDesignTokens.readerTopMinHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.readerTopCornerRadius)
                .fill(ReaderDesignTokens.Color.surface.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.readerTopCornerRadius)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder.opacity(0.72), lineWidth: 1)
                )
        )
    }

    private func activate(_ action: ReaderContract25RouteAction) {
        var next = navigation
        let outcome = next.perform(action)
        navigation = next

        if case .external(let target) = outcome {
            if let onNavigate {
                onNavigate(target)
            } else {
                onExit?()
            }
        }
    }

    private func contentStateIcon(for routeId: ReaderUIContract.RouteId) -> ReaderAssetIcon {
        let value = routeId.rawValue
        if value.contains("error") || value.contains("offline") || value.contains("timeout") || value.contains("rollback") {
            return .warning
        }
        if value.contains("loading") || value.contains("parsing") {
            return .activity
        }
        return .bookOpen
    }

    private func icon(for renderer: ReaderContract25Renderer) -> ReaderAssetIcon {
        switch renderer {
        case .readerWorkspaceState: return .appearance
        case .readerReplacementState: return .readerContentReplace
        case .sourceSwitchState: return .sourceSwitch
        case .readerContentState: return .bookOpen
        case .localImportState: return .file
        }
    }
}

private struct ReaderContract25StateCard: View {
    let page: ReaderContract25RoutePage
    let icon: ReaderAssetIcon
    let onAction: (ReaderContract25RouteAction) -> Void

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                    ReaderIcon(icon, size: 24, accessibilityLabel: page.title)
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(page.title)
                            .font(.system(size: ReaderDesignTokens.rssBrowserConfirmTitleFontSize, weight: .heavy))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        Text(page.message)
                            .font(.system(size: ReaderDesignTokens.rssBrowserConfirmBodyFontSize))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    ForEach(Array(page.actions.enumerated()), id: \.offset) { index, action in
                        Button { onAction(action) } label: {
                            Text(action.label)
                                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                                .foregroundColor(index == page.actions.count - 1 ? .white : ReaderDesignTokens.Color.primaryDark)
                                .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssReaderInlineActionMinHeight)
                                .background(
                                    Capsule().fill(
                                        index == page.actions.count - 1
                                            ? ReaderDesignTokens.Color.primaryDark
                                            : ReaderDesignTokens.Color.paperSolidAlt
                                    )
                                )
                        }
                        .buttonStyle(DemoPressButtonStyle())
                        .accessibilityIdentifier("reader-contract25-action-\(action.target.rawValue)")
                    }
                }
            }
        }
    }
}

// MARK: - W1 导入流程专用视图

/// W1 导入流程的内容容器，按 routeId 分发到 8 个专用产品视图。
/// 对齐 Demo `w1-import-renderers.js` 的 8 个 schema-only renderer。
struct W1ImportFlowContent: View {
    let page: ReaderContract25RoutePage
    let onAction: (ReaderContract25RouteAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportPhaseBreadcrumb(currentPhase: phase)
            stateHeader
            phaseContent
            W1ImportActionRow(actions: page.actions, onAction: onAction)
        }
    }

    private var phase: W1ImportPhase {
        switch page.routeId {
        case .importPermissionDenied: return .selecting
        case .importFormatUnsupported: return .input
        case .importEmptyFile: return .parsing
        case .importParsing: return .parsing
        case .importDuplicate: return .preview
        case .importConflictResolve: return .conflict
        case .importPartialSuccess: return .result
        case .importResultDetail: return .result
        default: return .selecting
        }
    }

    private var icon: ReaderAssetIcon {
        switch page.routeId {
        case .importPermissionDenied: return .permission
        case .importFormatUnsupported: return .warning
        case .importEmptyFile: return .file
        case .importParsing: return .refresh
        case .importDuplicate: return .bookmark
        case .importConflictResolve: return .warning
        case .importPartialSuccess: return .check
        case .importResultDetail: return .info
        default: return .file
        }
    }

    @ViewBuilder
    private var stateHeader: some View {
        ReaderCard {
            HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(icon, size: 24, accessibilityLabel: page.title)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                VStack(alignment: .leading, spacing: 5) {
                    Text(page.title)
                        .font(.system(size: ReaderDesignTokens.rssBrowserConfirmTitleFontSize, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    Text(page.message)
                        .font(.system(size: ReaderDesignTokens.rssBrowserConfirmBodyFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch page.routeId {
        case .importPermissionDenied:
            W1ImportPermissionDetail()
        case .importFormatUnsupported:
            W1ImportFormatDetail()
        case .importEmptyFile:
            W1ImportEmptyFileDetail()
        case .importParsing:
            W1ImportParsingDetail()
        case .importDuplicate:
            W1ImportDuplicateDetail()
        case .importConflictResolve:
            W1ImportConflictDetail()
        case .importPartialSuccess:
            W1ImportPartialSuccessDetail()
        case .importResultDetail:
            W1ImportResultDetailContent()
        default:
            EmptyView()
        }
    }
}

/// 导入流程阶段标识。
enum W1ImportPhase: String, CaseIterable {
    case selecting
    case input
    case parsing
    case preview
    case conflict
    case applying
    case result

    var label: String {
        switch self {
        case .selecting: return "选择"
        case .input: return "输入"
        case .parsing: return "解析"
        case .preview: return "预览"
        case .conflict: return "冲突"
        case .applying: return "应用"
        case .result: return "结果"
        }
    }
}

/// 导入流程阶段面包屑，对齐 Demo `w1ImportPhaseBreadcrumb`。
/// 高亮当前阶段，已完成阶段弱化标记，未到达阶段灰色。
struct W1ImportPhaseBreadcrumb: View {
    let currentPhase: W1ImportPhase

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(W1ImportPhase.allCases.enumerated()), id: \.element.rawValue) { index, phase in
                    breadcrumbItem(for: phase, index: index)
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityLabel("导入流程阶段")
    }

    private func breadcrumbItem(for phase: W1ImportPhase, index: Int) -> some View {
        let currentIndex = W1ImportPhase.allCases.firstIndex(of: currentPhase) ?? 0
        let isActive = phase == currentPhase
        let isPast = index < currentIndex

        return HStack(spacing: 0) {
            if index > 0 {
                ReaderIcon(.chevron, size: 12)
                    .foregroundStyle(
                        isPast || isActive
                            ? ReaderDesignTokens.Color.primaryDark
                            : ReaderDesignTokens.Color.muted.opacity(0.4)
                    )
                    .padding(.horizontal, 4)
            }

            Text(phase.label)
                .font(.system(size: ReaderDesignTokens.chipFontSize, weight: .black))
                .foregroundColor(
                    isActive
                        ? ReaderDesignTokens.Color.primaryDark
                        : (isPast
                            ? ReaderDesignTokens.Color.primaryDark.opacity(0.6)
                            : ReaderDesignTokens.Color.muted.opacity(0.5))
                )
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(
                    Capsule().fill(
                        isActive
                            ? ReaderDesignTokens.Color.primary.opacity(0.12)
                            : SwiftUI.Color.clear
                    )
                )
        }
    }
}

/// 导入操作按钮行，对齐 Demo `fd-action-row`。
/// 最后一个按钮为 primary（实心），其余为 secondary（描边）。
struct W1ImportActionRow: View {
    let actions: [ReaderContract25RouteAction]
    let onAction: (ReaderContract25RouteAction) -> Void

    var body: some View {
        if actions.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 8) {
                ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                    Button { onAction(action) } label: {
                        Text(action.label)
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            .foregroundColor(index == actions.count - 1 ? .white : ReaderDesignTokens.Color.primaryDark)
                            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssReaderInlineActionMinHeight)
                            .background(
                                Capsule().fill(
                                    index == actions.count - 1
                                        ? ReaderDesignTokens.Color.primaryDark
                                        : ReaderDesignTokens.Color.paperSolidAlt
                                )
                            )
                    }
                    .buttonStyle(DemoPressButtonStyle())
                    .accessibilityIdentifier("reader-contract25-action-\(action.target.rawValue)")
                }
            }
        }
    }
}

/// 通用信息卡，对齐 Demo `fd-import-permission-detail` / `fd-import-format-detail`。
struct W1ImportInfoCard: View {
    let rows: [(label: String, value: String)]

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                        Text(row.label)
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .frame(width: 80, alignment: .leading)
                        Text(row.value)
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .heavy))
                            .foregroundColor(ReaderDesignTokens.Color.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 8)
                    if index < rows.count - 1 {
                        Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                    }
                }
            }
        }
    }
}

// MARK: - 8 个 schema-only 路由的专用内容

/// 1. import-permission-denied —— 权限拒绝详情
/// 对齐 Demo `importPermissionDeniedScreen`：权限说明卡（所需权限/触发场景/影响范围）。
struct W1ImportPermissionDetail: View {
    var body: some View {
        W1ImportInfoCard(rows: [
            ("所需权限", "存储访问"),
            ("触发场景", "本地书导入 · 选择文件阶段"),
            ("影响范围", "无法读取或写入本地书籍文件")
        ])
    }
}

/// 2. import-format-unsupported —— 格式不支持详情
/// 对齐 Demo `importFormatUnsupportedScreen`：格式信息卡（文件名/检测格式/支持格式）+ 提示。
struct W1ImportFormatDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("文件名", "未知文件"),
                ("检测格式", "未知格式"),
                ("支持格式", "EPUB · TXT · MOBI · AZW3 · PDF")
            ])
            Text("可尝试使用格式转换工具转换为支持的格式后重新导入。")
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 3. import-empty-file —— 空文件详情
/// 对齐 Demo `importEmptyFileScreen`：文件信息卡（文件名/文件大小/检测结果）。
struct W1ImportEmptyFileDetail: View {
    var body: some View {
        W1ImportInfoCard(rows: [
            ("文件名", "未知文件"),
            ("文件大小", "0 KB"),
            ("检测结果", "文件内容为空或无法读取")
        ])
    }
}

/// 4. import-parsing —— 解析中详情
/// 对齐 Demo `importParsingScreen`：解析进度卡（当前文件/当前步骤）+ 进度条。
struct W1ImportParsingDetail: View {
    private let progress: Double = 72

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("当前文件", "雨夜.epub"),
                ("当前步骤", "正在识别章节结构")
            ])

            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ReaderDesignTokens.Color.chipBackground)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ReaderDesignTokens.Color.primary)
                            .frame(width: proxy.size.width * (progress / 100.0), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("解析进度")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                    Spacer()
                    Text("\(Int(progress))%")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                }
            }
            .padding(.horizontal, ReaderDesignTokens.cardPadding)
        }
    }
}

/// 5. import-duplicate —— 重复检测详情
/// 对齐 Demo `importDuplicateScreen`：重复项列表（标题/元数据/大小）。
struct W1ImportDuplicateDetail: View {
    private let duplicates: [(title: String, meta: String, size: String)] = [
        ("雨夜.epub", "本地已存在 · 同名同作者", "1.2 MB"),
        ("旧书扫描.txt", "本地已存在 · 同名不同作者", "0.8 MB")
    ]

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("检测到 \(duplicates.count) 个重复项")
                    .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .padding(.bottom, 8)

                ForEach(Array(duplicates.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .center, spacing: ReaderDesignTokens.settingsRowGap) {
                        ReaderIcon(.bookmark, size: 16, accessibilityLabel: item.title)
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                                .foregroundColor(ReaderDesignTokens.Color.ink)
                                .lineLimit(1)
                            Text(item.meta)
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(item.size)
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .heavy))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                    }
                    .padding(.vertical, 8)
                    if index < duplicates.count - 1 {
                        Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                    }
                }
            }
        }
    }
}

/// 6. import-conflict-resolve —— 冲突解决详情
/// 对齐 Demo `importConflictResolveScreen`：字段冲突列表（字段/本地值/导入值）。
struct W1ImportConflictDetail: View {
    private let conflicts: [(field: String, local: String, remote: String)] = [
        ("书名", "雨夜", "雨夜（修订版）"),
        ("作者", "佚名", "张三"),
        ("分组", "默认分组", "小说")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            ReaderCard {
                VStack(alignment: .leading, spacing: 0) {
                    Text("字段冲突")
                        .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .padding(.bottom, 8)

                    ForEach(Array(conflicts.enumerated()), id: \.offset) { index, item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.field)
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("本地")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                                    Text(item.local)
                                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .heavy))
                                        .foregroundColor(ReaderDesignTokens.Color.ink)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("导入")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                                    Text(item.remote)
                                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .heavy))
                                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 8)
                        if index < conflicts.count - 1 {
                            Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                        }
                    }
                }
            }

            Text("选择解决方案后将进入应用阶段，可通过回滚撤销本次导入。")
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 7. import-partial-success —— 部分成功结果详情
/// 对齐 Demo `importPartialSuccessScreen`：结果摘要（成功/失败/总计）+ 结果明细列表。
struct W1ImportPartialSuccessDetail: View {
    private let results: [(title: String, status: String, tone: ResultTone)] = [
        ("雨夜.epub", "成功", .good),
        ("旧书扫描.txt", "失败 · 编码异常", .danger),
        ("缺失章节.mobi", "失败 · 格式不支持", .danger)
    ]

    enum ResultTone {
        case good, danger
    }

    private var successCount: Int { results.filter { $0.tone == .good }.count }
    private var failCount: Int { results.count - successCount }

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("成功", "\(successCount) 项"),
                ("失败", "\(failCount) 项"),
                ("总计", "\(results.count) 项")
            ])

            ReaderCard {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .center, spacing: ReaderDesignTokens.settingsRowGap) {
                            ReaderIcon(
                                item.tone == .danger ? .warning : .check,
                                size: 16,
                                accessibilityLabel: item.title
                            )
                            .foregroundColor(
                                item.tone == .danger
                                    ? ReaderDesignTokens.Color.danger
                                    : ReaderDesignTokens.Color.Semantic.success
                            )
                            .frame(width: 28, height: 28)
                            .background(
                                Circle().fill(
                                    item.tone == .danger
                                        ? ReaderDesignTokens.Color.danger.opacity(0.10)
                                        : ReaderDesignTokens.Color.Semantic.successTint
                                )
                            )

                            Text(item.title)
                                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                                .foregroundColor(ReaderDesignTokens.Color.ink)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(item.status)
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .heavy))
                                .foregroundColor(
                                    item.tone == .danger
                                        ? ReaderDesignTokens.Color.danger
                                        : ReaderDesignTokens.Color.Semantic.success
                                )
                        }
                        .padding(.vertical, 8)
                        if index < results.count - 1 {
                            Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                        }
                    }
                }
            }
        }
    }
}

/// 8. import-result-detail —— 导入结果详情内容
/// 对齐 Demo `importResultDetailScreen`：结果统计（导入时间/来源/分组）+ 完整结果列表。
struct W1ImportResultDetailContent: View {
    private let results: [(title: String, status: String, meta: String, tone: ResultTone)] = [
        ("雨夜.epub", "成功", "作者已识别 · 加入默认分组", .good),
        ("旧书扫描.txt", "成功", "编码 UTF-8 · 章节识别完成", .good),
        ("缺失章节.mobi", "失败", "格式不支持 · 已跳过", .danger)
    ]

    enum ResultTone {
        case good, danger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("导入时间", "刚刚"),
                ("来源", "本地文件"),
                ("分组", "默认分组")
            ])

            ReaderCard {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .center, spacing: ReaderDesignTokens.settingsRowGap) {
                            ReaderIcon(
                                item.tone == .danger ? .warning : .bookOpen,
                                size: 16,
                                accessibilityLabel: item.title
                            )
                            .foregroundColor(
                                item.tone == .danger
                                    ? ReaderDesignTokens.Color.danger
                                    : ReaderDesignTokens.Color.Semantic.success
                            )
                            .frame(width: 28, height: 28)
                            .background(
                                Circle().fill(
                                    item.tone == .danger
                                        ? ReaderDesignTokens.Color.danger.opacity(0.10)
                                        : ReaderDesignTokens.Color.Semantic.successTint
                                )
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                                    .foregroundColor(ReaderDesignTokens.Color.ink)
                                    .lineLimit(1)
                                Text(item.meta)
                                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(item.status)
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .heavy))
                                .foregroundColor(
                                    item.tone == .danger
                                        ? ReaderDesignTokens.Color.danger
                                        : ReaderDesignTokens.Color.Semantic.success
                                )
                        }
                        .padding(.vertical, 8)
                        if index < results.count - 1 {
                            Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - W2: Reader content state dedicated views

/// W2 阅读内容/目录/边界/恢复状态的专用内容容器。
/// 按 routeId 分发到 10 个专用产品视图，每个视图展示该状态特有的信息卡和操作。
struct W2ReaderContentFlowContent: View {
    let page: ReaderContract25RoutePage
    let onAction: (ReaderContract25RouteAction) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                stateHeader
                phaseContent
                W1ImportActionRow(actions: page.actions, onAction: onAction)
            }
            .padding(.vertical, ReaderDesignTokens.cardPadding)
        }
    }

    private var icon: ReaderAssetIcon {
        let value = page.routeId.rawValue
        if value.contains("error") || value.contains("offline") { return .warning }
        if value.contains("loading") { return .activity }
        if value.contains("boundary") { return .directory }
        if value.contains("restore") { return .refresh }
        return .bookOpen
    }

    @ViewBuilder
    private var stateHeader: some View {
        ReaderCard {
            HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(icon, size: 24, accessibilityLabel: page.title)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                VStack(alignment: .leading, spacing: 5) {
                    Text(page.title)
                        .font(.system(size: ReaderDesignTokens.rssBrowserConfirmTitleFontSize, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    Text(page.message)
                        .font(.system(size: ReaderDesignTokens.rssBrowserConfirmBodyFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch page.routeId {
        case .readerContentLoading:
            W2ContentLoadingDetail()
        case .readerContentOffline:
            W2ContentOfflineDetail()
        case .readerContentError:
            W2ContentErrorDetail()
        case .readerTocLoading:
            W2TocLoadingDetail()
        case .readerTocOffline:
            W2TocOfflineDetail()
        case .readerTocError:
            W2TocErrorDetail()
        case .readerPageBoundaryFirst:
            W2PageBoundaryDetail(isFirst: true)
        case .readerPageBoundaryLast:
            W2PageBoundaryDetail(isFirst: false)
        case .readerProgressRestore:
            W2ProgressRestoreDetail()
        case .readerBackgroundRestore:
            W2BackgroundRestoreDetail()
        default:
            EmptyView()
        }
    }
}

/// 正文加载中详情：加载步骤卡 + 进度指示器。
struct W2ContentLoadingDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("当前章节", DemoReaderFixture.chapterTitle),
                ("书源", DemoReaderFixture.sourceLine),
                ("加载步骤", "正在拉取正文内容")
            ])

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ReaderIcon(.activity, size: 16, accessibilityLabel: "加载中")
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    Text("正在请求书源接口并解析正文…")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                }
                Text("加载期间保持当前章节上下文，不会丢失阅读位置。")
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, ReaderDesignTokens.cardPadding)
        }
    }
}

/// 正文离线详情：网络状态卡 + 缓存内容信息。
struct W2ContentOfflineDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("网络状态", "不可用"),
                ("当前章节", DemoReaderFixture.chapterTitle),
                ("缓存状态", "本章已缓存 · 可离线阅读")
            ])

            ReaderCard {
                HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                    ReaderIcon(.offline, size: 20, accessibilityLabel: "离线")
                        .foregroundColor(ReaderDesignTokens.Color.Semantic.warning)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(ReaderDesignTokens.Color.Semantic.warningTint))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前网络不可用")
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        Text("请检查网络连接后重试。已缓存章节可继续阅读，但无法拉取新内容。")
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// 正文解析错误详情：错误类型卡 + 排查建议。
struct W2ContentErrorDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("错误类型", "正文解析失败"),
                ("当前章节", DemoReaderFixture.chapterTitle),
                ("书源", DemoReaderFixture.sourceLine)
            ])

            ReaderCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ReaderIcon(.warning, size: 18, accessibilityLabel: "错误")
                            .foregroundColor(ReaderDesignTokens.Color.danger)
                        Text("可能原因")
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            .foregroundColor(ReaderDesignTokens.Color.danger)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• 书源正文规则与当前页面结构不匹配")
                        Text("• 编码识别异常（非 UTF-8 / GBK）")
                        Text("• 书源返回了反爬验证页面")
                    }
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)

                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)

                    Text("可重试加载或更换书源；阅读位置保持不变。")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// 目录加载中详情。
struct W2TocLoadingDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("书源", DemoReaderFixture.sourceLine),
                ("加载步骤", "正在拉取章节列表")
            ])

            HStack(spacing: 8) {
                ReaderIcon(.activity, size: 16, accessibilityLabel: "加载中")
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                Text("正在请求书源目录接口…")
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .padding(.horizontal, ReaderDesignTokens.cardPadding)
        }
    }
}

/// 目录离线详情。
struct W2TocOfflineDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("网络状态", "不可用"),
                ("缓存目录", "已缓存 48 章 · 可离线浏览"),
                ("最后更新", "昨天 23:15")
            ])

            ReaderCard {
                HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                    ReaderIcon(.offline, size: 20, accessibilityLabel: "离线")
                        .foregroundColor(ReaderDesignTokens.Color.Semantic.warning)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(ReaderDesignTokens.Color.Semantic.warningTint))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("无法更新目录")
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        Text("网络恢复后可重新拉取最新章节列表。当前可浏览已缓存目录。")
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// 目录解析错误详情。
struct W2TocErrorDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("错误类型", "目录解析错误"),
                ("书源", DemoReaderFixture.sourceLine),
                ("解析步骤", "章节列表规则匹配失败")
            ])

            ReaderCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ReaderIcon(.warning, size: 18, accessibilityLabel: "错误")
                            .foregroundColor(ReaderDesignTokens.Color.danger)
                        Text("书源目录规则可能已失效")
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            .foregroundColor(ReaderDesignTokens.Color.danger)
                    }
                    Text("书源返回的章节列表无法解析。可重试加载或更换书源后再次拉取目录。")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// 章节边界详情（首章/末章共用）。
struct W2PageBoundaryDetail: View {
    let isFirst: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("当前位置", isFirst ? "第一章 · 第一页" : "最后一章 · 最后一页"),
                ("章节标题", DemoReaderFixture.chapterTitle),
                ("进度", isFirst ? "0%" : "100%")
            ])

            ReaderCard {
                HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                    ReaderIcon(isFirst ? .chevronLeft : .chevron, size: 20, accessibilityLabel: "边界")
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isFirst ? "已是第一章" : "已是最后一章")
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        Text(isFirst
                             ? "没有更早的章节。可返回控制层或继续阅读当前章节。"
                             : "没有更多正文。可返回控制层或回到首页重新浏览。")
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// 阅读进度恢复详情。
struct W2ProgressRestoreDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("恢复章节", DemoReaderFixture.chapterTitle),
                ("字符锚点", "第 1,248 字符"),
                ("分页签名", "已校验 · 页面布局一致"),
                ("恢复时间", "刚刚")
            ])

            ReaderCard {
                HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                    ReaderIcon(.check, size: 20, accessibilityLabel: "已恢复")
                        .foregroundColor(ReaderDesignTokens.Color.Semantic.success)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(ReaderDesignTokens.Color.Semantic.successTint))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("进度已恢复")
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        Text("已恢复到上次阅读的章节、字符锚点和分页签名，可继续阅读或从控制层开始。")
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// 后台恢复详情。
struct W2BackgroundRestoreDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("恢复来源", "应用从后台恢复"),
                ("当前章节", DemoReaderFixture.chapterTitle),
                ("阅读位置", "已保留"),
                ("正文状态", "可能需要重载")
            ])

            ReaderCard {
                HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                    ReaderIcon(.refresh, size: 20, accessibilityLabel: "重载")
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("应用已从后台恢复")
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        Text("可立即重载正文以获取最新内容，或返回控制层查看阅读状态。阅读位置保持不变。")
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - W3: Source switch state dedicated views

/// W3 换源状态变体的 step region（状态卡区域）。
struct W3SourceSwitchStepRegion: View {
    let page: ReaderContract25RoutePage
    let onAction: (ReaderContract25RouteAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            stateHeader
            W1ImportActionRow(actions: page.actions, onAction: onAction)
        }
    }

    private var icon: ReaderAssetIcon {
        let value = page.routeId.rawValue
        if value.contains("error") || value.contains("rollback") { return .warning }
        if value.contains("timeout") { return .clock }
        if value.contains("loading") { return .activity }
        if value.contains("empty") { return .folderOff }
        if value.contains("preview") { return .bookOpen }
        return .sourceSwitch
    }

    @ViewBuilder
    private var stateHeader: some View {
        ReaderCard {
            HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(icon, size: 24, accessibilityLabel: page.title)
                    .foregroundColor(headerTint)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(headerTint.opacity(0.10)))

                VStack(alignment: .leading, spacing: 5) {
                    Text(page.title)
                        .font(.system(size: ReaderDesignTokens.rssBrowserConfirmTitleFontSize, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    Text(page.message)
                        .font(.system(size: ReaderDesignTokens.rssBrowserConfirmBodyFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var headerTint: Color {
        let value = page.routeId.rawValue
        if value.contains("error") || value.contains("rollback") { return ReaderDesignTokens.Color.danger }
        if value.contains("timeout") { return ReaderDesignTokens.Color.Semantic.warning }
        return ReaderDesignTokens.Color.primaryDark
    }
}

/// W3 换源状态变体的 comparison region（对比区域）。
struct W3SourceSwitchComparisonRegion: View {
    let page: ReaderContract25RoutePage

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(comparisonTitle)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                W1ImportInfoCard(rows: comparisonRows)

                if let extra = comparisonExtra {
                    extra
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var comparisonTitle: String {
        switch page.routeId {
        case .sourceSwitchEmpty: return "候选书源为空"
        case .sourceSwitchError: return "加载失败详情"
        case .sourceSwitchTimeout: return "超时详情"
        case .sourceSwitchLoading: return "切换进行中"
        case .sourceSwitchRollback: return "回滚详情"
        case .sourceSwitchPreview: return "候选预览"
        default: return "当前位置"
        }
    }

    private var comparisonRows: [(label: String, value: String)] {
        switch page.routeId {
        case .sourceSwitchEmpty:
            return [("书籍", DemoReaderFixture.title), ("当前书源", DemoReaderFixture.sourceLine), ("候选数量", "0 个")]
        case .sourceSwitchError:
            return [("书籍", DemoReaderFixture.title), ("错误来源", "书源接口请求失败"), ("当前书源", DemoReaderFixture.sourceLine)]
        case .sourceSwitchTimeout:
            return [("书籍", DemoReaderFixture.title), ("超时时长", "30 秒"), ("当前书源", DemoReaderFixture.sourceLine)]
        case .sourceSwitchLoading:
            return [("书籍", DemoReaderFixture.title), ("原书源", DemoReaderFixture.sourceLine), ("目标书源", "笔趣阁镜像"), ("切换步骤", "正在拉取目录与正文")]
        case .sourceSwitchRollback:
            return [("书籍", DemoReaderFixture.title), ("原书源", DemoReaderFixture.sourceLine), ("失败书源", "轻小说书站"), ("回滚状态", "已恢复原书源 · 进度保留")]
        case .sourceSwitchPreview:
            return [("书籍", DemoReaderFixture.title), ("当前书源", DemoReaderFixture.sourceLine), ("候选书源", "笔趣阁镜像"), ("候选延迟", "180 ms")]
        default:
            return [("当前位置", DemoReaderFixture.chapterTitle)]
        }
    }

    @ViewBuilder
    private var comparisonExtra: (some View)? {
        if page.routeId == .sourceSwitchEmpty {
            Text("未找到可用候选书源。可重新加载或检查书源状态后再次尝试。")
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .fixedSize(horizontal: false, vertical: true)
        } else if page.routeId == .sourceSwitchLoading {
            HStack(spacing: 8) {
                ReaderIcon(.activity, size: 16, accessibilityLabel: "加载中")
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                Text("切换期间保持当前阅读位置，不会覆盖已有正文。")
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
        } else if page.routeId == .sourceSwitchRollback {
            HStack(spacing: 8) {
                ReaderIcon(.warning, size: 16, accessibilityLabel: "回滚")
                    .foregroundColor(ReaderDesignTokens.Color.danger)
                Text("目标书源切换失败，已自动回滚到原书源。阅读进度和章节上下文保持不变。")
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if page.routeId == .sourceSwitchPreview {
            VStack(alignment: .leading, spacing: 4) {
                Text("候选章节")
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                Text("第 32 章 雨夜 · 与当前章节一致")
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
            }
        }
    }
}

/// W3 换源状态变体的 result region（结果区域）。
struct W3SourceSwitchResultRegion: View {
    let page: ReaderContract25RoutePage

    var body: some View {
        ReaderStateBanner(
            icon: resultIcon,
            title: resultTitle,
            messages: resultMessages
        )
    }

    private var resultIcon: ReaderAssetIcon {
        switch page.routeId {
        case .sourceSwitchEmpty: return .folderOff
        case .sourceSwitchError: return .warning
        case .sourceSwitchTimeout: return .clock
        case .sourceSwitchLoading: return .activity
        case .sourceSwitchRollback: return .refresh
        case .sourceSwitchPreview: return .sourceSwitch
        default: return .sourceSwitch
        }
    }

    private var resultTitle: String {
        switch page.routeId {
        case .sourceSwitchEmpty: return "无候选书源"
        case .sourceSwitchError: return "加载失败"
        case .sourceSwitchTimeout: return "请求超时"
        case .sourceSwitchLoading: return "切换连续性"
        case .sourceSwitchRollback: return "已回滚"
        case .sourceSwitchPreview: return "预览确认"
        default: return "换源连续性"
        }
    }

    private var resultMessages: [String] {
        switch page.routeId {
        case .sourceSwitchEmpty:
            return ["书籍、章节和阅读位置保持绑定", "可重新加载候选列表"]
        case .sourceSwitchError:
            return ["书籍、章节和阅读位置保持绑定", "可重试加载或检查书源状态"]
        case .sourceSwitchTimeout:
            return ["请求已超时但阅读位置不变", "可重试或选择其他书源"]
        case .sourceSwitchLoading:
            return ["书籍、章节和阅读位置保持绑定", "切换失败时自动回滚到原书源"]
        case .sourceSwitchRollback:
            return ["已恢复到原书源", "阅读进度和章节上下文完整保留"]
        case .sourceSwitchPreview:
            return ["候选书源章节与当前一致", "确认后进入切换流程"]
        default:
            return ["书籍、章节和阅读位置保持绑定", "失败时回滚到原书源"]
        }
    }
}

// MARK: - W5: Replace rule state dedicated views

/// W5 替换规则状态的专用内容容器。
/// 按 routeId 分发到 5 个专用产品视图。
struct W5ReplaceRuleFlowContent: View {
    let page: ReaderContract25RoutePage
    let onAction: (ReaderContract25RouteAction) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                stateHeader
                phaseContent
                W1ImportActionRow(actions: page.actions, onAction: onAction)
            }
            .padding(.vertical, ReaderDesignTokens.cardPadding)
        }
    }

    @ViewBuilder
    private var stateHeader: some View {
        ReaderCard {
            HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(.readerContentReplace, size: 24, accessibilityLabel: page.title)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                VStack(alignment: .leading, spacing: 5) {
                    Text(page.title)
                        .font(.system(size: ReaderDesignTokens.rssBrowserConfirmTitleFontSize, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    Text(page.message)
                        .font(.system(size: ReaderDesignTokens.rssBrowserConfirmBodyFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch page.routeId {
        case .readerReplacePage:
            W5ReplacePageDetail()
        case .readerReplacePreview:
            W5ReplacePreviewDetail()
        case .readerReplaceDeleteConfirm:
            W5ReplaceDeleteConfirmDetail()
        case .readerReplaceApplyResult:
            W5ReplaceApplyResultDetail()
        case .readerReplaceImportExport:
            W5ReplaceImportExportDetail()
        default:
            EmptyView()
        }
    }
}

/// 替换规则管理页：规则列表 + CRUD 操作。
struct W5ReplacePageDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            ReaderCard {
                VStack(alignment: .leading, spacing: 0) {
                    Text("替换规则列表")
                        .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .padding(.bottom, 8)

                    ForEach(Array(rules.enumerated()), id: \.offset) { index, rule in
                        HStack(alignment: .center, spacing: ReaderDesignTokens.settingsRowGap) {
                            ReaderIcon(.replace, size: 16, accessibilityLabel: rule.name)
                                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.name)
                                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                                    .foregroundColor(ReaderDesignTokens.Color.ink)
                                    .lineLimit(1)
                                Text("\(rule.pattern) → \(rule.replacement)")
                                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(rule.isEnabled ? "启用" : "关闭")
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .heavy))
                                .foregroundColor(rule.isEnabled ? ReaderDesignTokens.Color.Semantic.success : ReaderDesignTokens.Color.muted)
                        }
                        .padding(.vertical, 8)
                        if index < rules.count - 1 {
                            Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                        }
                    }
                }
            }

            W1ImportInfoCard(rows: [
                ("规则总数", "\(rules.count) 条"),
                ("已启用", "\(rules.filter { $0.isEnabled }.count) 条"),
                ("作用范围", "当前书籍 · 全部章节")
            ])
        }
    }

    private let rules: [(name: String, pattern: String, replacement: String, isEnabled: Bool)] = [
        ("称呼统一", "雨容", "雨蓉", true),
        ("旧称替换", "旧称", "新称", true),
        ("标点清理", "，，", "，", false),
        ("广告过滤", "本章未完", "", true)
    ]
}

/// 替换规则预览：原文与替换后正文对比。
struct W5ReplacePreviewDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("应用规则数", "3 条"),
                ("替换次数", "12 处"),
                ("预览章节", DemoReaderFixture.chapterTitle)
            ])

            ReaderCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("原文 → 替换后")
                        .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("原文片段")
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                        Text("雨容望着窗外，旧称的雨声在夜色里连成一片……")
                            .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.settingsRowMetaFontSize))
                            .foregroundColor(ReaderDesignTokens.Color.ink)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                                    .fill(ReaderDesignTokens.Color.chipBackground)
                            )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("替换后")
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                        Text("雨蓉望着窗外，新称的雨声在夜色里连成一片……")
                            .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.settingsRowMetaFontSize))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                                    .fill(ReaderDesignTokens.Color.primary.opacity(0.08))
                            )
                    }

                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("本次应用的规则")
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                        Text("• 称呼统一：雨容 → 雨蓉")
                        Text("• 旧称替换：旧称 → 新称")
                        Text("• 标点清理：，，→ ，（已关闭，未应用）")
                    }
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// 删除替换规则确认：规则详情 + 删除影响。
struct W5ReplaceDeleteConfirmDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("规则名称", "称呼统一"),
                ("匹配模式", "雨容"),
                ("替换为", "雨蓉"),
                ("启用状态", "已启用")
            ])

            ReaderCard {
                HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                    ReaderIcon(.warning, size: 20, accessibilityLabel: "删除确认")
                        .foregroundColor(ReaderDesignTokens.Color.danger)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(ReaderDesignTokens.Color.danger.opacity(0.10)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("删除后不可恢复")
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            .foregroundColor(ReaderDesignTokens.Color.danger)
                        Text("其他替换规则和原始正文不会被修改。删除后该规则不再参与正文替换。")
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// 替换规则应用结果：应用统计 + 结果明细。
struct W5ReplaceApplyResultDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("应用规则", "3 条"),
                ("替换次数", "12 处"),
                ("应用章节", DemoReaderFixture.chapterTitle),
                ("应用时间", "刚刚")
            ])

            ReaderCard {
                VStack(alignment: .leading, spacing: 0) {
                    Text("规则应用明细")
                        .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        .padding(.bottom, 8)

                    ForEach(Array(results.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .center, spacing: ReaderDesignTokens.settingsRowGap) {
                            ReaderIcon(.replace, size: 16, accessibilityLabel: item.rule)
                                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.rule)
                                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                                    .foregroundColor(ReaderDesignTokens.Color.ink)
                                    .lineLimit(1)
                                Text(item.detail)
                                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text("\(item.count) 处")
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .heavy))
                                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        }
                        .padding(.vertical, 8)
                        if index < results.count - 1 {
                            Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                        }
                    }
                }
            }
        }
    }

    private let results: [(rule: String, detail: String, count: Int)] = [
        ("称呼统一", "雨容 → 雨蓉", 5),
        ("旧称替换", "旧称 → 新称", 4),
        ("广告过滤", "本章未完 → （删除）", 3)
    ]
}

/// 替换规则导入导出：格式信息 + 操作说明。
struct W5ReplaceImportExportDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            W1ImportInfoCard(rows: [
                ("格式", "JSON"),
                ("当前规则数", "4 条"),
                ("导入校验", "格式 + 字段完整性"),
                ("导出范围", "全部规则")
            ])

            ReaderCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("JSON 结构预览")
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                    Text("""
                    [
                      {
                        "name": "称呼统一",
                        "pattern": "雨容",
                        "replacement": "雨蓉",
                        "isEnabled": true,
                        "scope": "currentBook"
                      }
                    ]
                    """)
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, design: .monospaced))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                            .fill(ReaderDesignTokens.Color.chipBackground)
                    )

                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)

                    Text("导入时会校验规则格式与字段完整性，重复规则可选择覆盖或跳过。")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
