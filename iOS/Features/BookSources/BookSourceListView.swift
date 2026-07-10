import SwiftUI
import ReaderCoreModels
import ReaderShellValidation
import ReaderAppPersistence

/// 用于统一 sheet 分发的标记类型 — detail 使用 source ID 保证唯一性
enum BookSourceSheet: Identifiable {
    case importSheet
    case shareSheet
    case detail(source: BookSource, id: String)

    var id: String {
        switch self {
        case .importSheet: return "import"
        case .shareSheet: return "share"
        case .detail(_, let sourceId): return "detail-\(sourceId)"
        }
    }

    var title: String {
        switch self {
        case .importSheet:
            return "导入书源"
        case .shareSheet:
            return "书源 JSON"
        case .detail:
            return "书源详情"
        }
    }

    var maxHeight: CGFloat? {
        switch self {
        case .importSheet:
            return 620
        case .shareSheet:
            return 420
        case .detail:
            return 680
        }
    }
}

public struct BookSourceListView: View {
    @ObservedObject var coordinator: ReadingFlowCoordinator
    /// P0 修复：返回按钮回调（pop 路由）。传给 DemoBackScreen 的 onBack。
    private let onExit: (() -> Void)?
    @State private var sources: [BookSource] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var shareText: String = ""
    @State private var activeSheet: BookSourceSheet?

    public init(coordinator: ReadingFlowCoordinator, onExit: (() -> Void)? = nil) {
        self.coordinator = coordinator
        self.onExit = onExit
    }

    /// 书源列表 — fixture + 真实候选源
    static let fixtureSources: [BookSource] = [
        BookSource(id: "candidate-xingxingxsw", bookSourceName: "⭐ 星星小说网", bookSourceUrl: "https://www.xingxingxsw.com", bookSourceGroup: "在线书源", enabled: true),
        BookSource(id: "fixture-001", bookSourceName: "笔趣阁", bookSourceUrl: "https://www.biquge.com", bookSourceGroup: "在线书源", enabled: false),
        BookSource(id: "fixture-002", bookSourceName: "全本书屋", bookSourceUrl: "https://www.quanben.com", bookSourceGroup: "在线书源", enabled: false),
        BookSource(id: "fixture-003", bookSourceName: "千帆小说", bookSourceUrl: "https://www.qianfanxs.com", bookSourceGroup: "在线书源", enabled: false),
        BookSource(id: "fixture-004", bookSourceName: "起点中文", bookSourceUrl: "https://www.qidian.com", bookSourceGroup: "在线书源", enabled: false),
        BookSource(id: "fixture-005", bookSourceName: "本地书源示例", bookSourceUrl: "file:///local/sample.json", bookSourceGroup: "本地书源", enabled: false),
    ]

    public var body: some View {
        DemoBackScreen(title: "书源管理", onBack: onExit) {
            if let errorMessage {
                ReaderStateBanner(
                    icon: .warning,
                    title: "书源加载提示",
                    messages: [errorMessage]
                )
            }

            sourceSummaryCard

            if isLoading {
                ReaderStateBanner(
                    icon: .refresh,
                    title: "加载书源中",
                    messages: ["正在合并预置候选源与本地导入源。"]
                )
            } else if sources.isEmpty {
                emptyStateView
            } else {
                sourceListContent
            }
        } trailing: {
            DemoTopActionButton(icon: .add, accessibilityLabel: "导入书源") {
                activeSheet = .importSheet
            }
        } bottomActionHost: {
            EmptyView()
        } sheetHost: {
            if let activeSheet {
                DemoBottomSheet(
                    title: activeSheet.title,
                    maxHeight: activeSheet.maxHeight,
                    onDismiss: { self.activeSheet = nil }
                ) {
                    bookSourceSheetContent(activeSheet)
                }
            }
        } dialogHost: {
            EmptyView()
        } stateHost: {
            EmptyView()
        }
        .task {
            await loadSources()
        }
    }

    private var emptyStateView: some View {
        ReaderStateCard(
            icon: .sourceStack,
            title: "暂无书源",
            subtitle: "导入书源以开始使用。",
            actionTitle: "导入书源"
        ) {
            activeSheet = .importSheet
        }
    }

    private var sourceSummaryCard: some View {
        ReaderCard {
            HStack(alignment: .center, spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(.sourceStack, size: ReaderDesignTokens.rssSourceListIconSize, accessibilityLabel: "书源配置")
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                VStack(alignment: .leading, spacing: 4) {
                    Text("书源配置")
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    Text("启用 \(enabledSources.count) 个，停用 \(disabledSources.count) 个")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    activeSheet = .importSheet
                } label: {
                    Text("导入")
                        .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                        .foregroundColor(.white)
                        .frame(minHeight: ReaderDesignTokens.rssImportListActionMinHeight)
                        .padding(.horizontal, 10)
                        .background(Capsule().fill(ReaderDesignTokens.Color.primaryDark))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("导入书源")
            }
        }
    }

    @ViewBuilder
    private func bookSourceSheetContent(_ sheet: BookSourceSheet) -> some View {
        switch sheet {
        case .importSheet:
            BookSourceImportContent { _ in
                activeSheet = nil
            }

        case .shareSheet:
            shareSheetContent

        case .detail(let source, _):
            BookSourceDetailSheet(source: source, onClose: { activeSheet = nil })
        }
    }

    private var shareSheetContent: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            ReaderCard {
                Text(shareText)
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, design: .monospaced))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
#if os(iOS)
                UIPasteboard.general.string = shareText
#endif
            } label: {
                HStack(spacing: 8) {
                    ReaderIcon(.file, size: 16, accessibilityLabel: "复制书源 JSON")
                    Text("复制书源 JSON")
                        .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                }
                .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
                .foregroundColor(.white)
                .background(Capsule().fill(ReaderDesignTokens.Color.primaryDark))
            }
            .buttonStyle(.plain)
        }
    }

    private var enabledSources: [BookSource] { sources.filter { $0.enabled } }
    private var disabledSources: [BookSource] { sources.filter { !$0.enabled } }

    private var sourceListContent: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                if !enabledSources.isEmpty {
                    sourceSection(title: "已启用", sources: enabledSources)
                }
                if !disabledSources.isEmpty {
                    sourceSection(title: "已禁用", sources: disabledSources)
                }
            }
        }
    }

    private func sourceSection(title: String, sources: [BookSource]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(title) (\(sources.count))")
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                Spacer()
            }
            .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
            .padding(.bottom, 6)

            ForEach(Array(sources.enumerated()), id: \.offset) { index, source in
                sourceRow(source: source)
                if index < sources.count - 1 {
                    Divider()
                        .padding(.leading, ReaderDesignTokens.settingsRowHorizontalPadding + ReaderDesignTokens.settingsRowIconColumn + ReaderDesignTokens.settingsRowGap)
                }
            }
        }
    }

    private func sourceRow(source: BookSource) -> some View {
        let sourceId = source.id ?? UUID().uuidString
        return BookSourceRowView(
            name: source.bookSourceName,
            url: source.bookSourceUrl ?? "",
            group: source.bookSourceGroup,
            enabled: Binding<Bool>(
                get: { sources.first(where: { $0.id == sourceId })?.enabled ?? false },
                set: { newValue in
                    if let idx = sources.firstIndex(where: { $0.id == sourceId }) {
                        var copy = sources
                        copy[idx].enabled = newValue
                        sources = copy
                    }
                }
            ),
            onDelete: { deleteSource(source) },
            onShare: {
                if let data = try? JSONEncoder().encode(source),
                   let json = String(data: data, encoding: .utf8) {
                    shareText = json
                    activeSheet = .shareSheet
                }
            },
            onTapDetail: {
                activeSheet = .detail(source: source, id: sourceId)
            }
        )
    }

    private func loadSources() async {
        isLoading = true
        defer { isLoading = false }

        // Load fixture/candidate sources
        var allSources = Self.fixtureSources

        // Merge imported local sources from BookSourceStore
        if let storeSources = try? await BookSourceStore.shared.load() {
            for storeSource in storeSources {
                // Only add if not already present (by id)
                if !allSources.contains(where: { $0.id == storeSource.id }) {
                    allSources.append(storeSource)
                }
            }
        }

        sources = allSources
    }

    private func deleteSource(_ source: BookSource) {
        guard let id = source.id else { return }
        sources.removeAll { $0.id == id }
    }
}
