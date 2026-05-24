import SwiftUI
import ReaderCoreModels
import ReaderShellValidation

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
}

public struct BookSourceListView: View {
    @ObservedObject var coordinator: ReadingFlowCoordinator
    @State private var sources: [BookSource] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var shareText: String = ""
    @State private var activeSheet: BookSourceSheet?

    public init(coordinator: ReadingFlowCoordinator) {
        self.coordinator = coordinator
    }

    /// 本地 fixture 书源 — 仅用于演示，不接真实网络
    static let fixtureSources: [BookSource] = [
        BookSource(id: "fixture-001", bookSourceName: "笔趣阁", bookSourceUrl: "https://www.biquge.com", bookSourceGroup: "在线书源", enabled: true),
        BookSource(id: "fixture-002", bookSourceName: "全本书屋", bookSourceUrl: "https://www.quanben.com", bookSourceGroup: "在线书源", enabled: true),
        BookSource(id: "fixture-003", bookSourceName: "千帆小说", bookSourceUrl: "https://www.qianfanxs.com", bookSourceGroup: "在线书源", enabled: false),
        BookSource(id: "fixture-004", bookSourceName: "起点中文", bookSourceUrl: "https://www.qidian.com", bookSourceGroup: "在线书源", enabled: true),
        BookSource(id: "fixture-005", bookSourceName: "本地书源示例", bookSourceUrl: "file:///local/sample.json", bookSourceGroup: "本地书源", enabled: false),
    ]

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let error = errorMessage {
                    HStack {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Spacer()
                        Button("关闭") { errorMessage = nil }
                            .font(.caption)
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                }

                Group {
                    if isLoading {
                        ProgressView("加载书源中...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if sources.isEmpty {
                        emptyStateView
                    } else {
                        sourceListContent
                    }
                }
            }
            .navigationTitle("书源")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { activeSheet = .importSheet }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .importSheet:
                    BookSourceImportView()
                case .shareSheet:
                    NavigationStack {
                        ScrollView {
                            Text(shareText)
                                .font(.caption.monospaced())
                                .padding()
                        }
                        .navigationTitle("书源 JSON")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("复制") {
#if os(iOS)
                                    UIPasteboard.general.string = shareText
#endif
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("完成") { activeSheet = nil }
                            }
                        }
                    }
                case .detail(let source, _):
                    BookSourceDetailSheet(source: source)
                }
            }
            .task {
                loadSources()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("暂无书源")
                .font(.title2).fontWeight(.semibold)
            Text("导入书源以开始使用")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("导入书源") {
                activeSheet = .importSheet
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var enabledSources: [BookSource] { sources.filter { $0.enabled } }
    private var disabledSources: [BookSource] { sources.filter { !$0.enabled } }

    private var sourceListContent: some View {
        List {
            if !enabledSources.isEmpty {
                Section("已启用 (\(enabledSources.count))") {
                    ForEach(enabledSources, id: \.id) { source in sourceRow(source: source) }
                }
            }
            if !disabledSources.isEmpty {
                Section("已禁用 (\(disabledSources.count))") {
                    ForEach(disabledSources, id: \.id) { source in sourceRow(source: source) }
                }
            }
        }
        .listStyle(.plain)
    }

    private func sourceRow(source: BookSource) -> some View {
        BookSourceRowView(
            source: source,
            onToggle: { toggleSource(source) },
            onDelete: { deleteSource(source) },
            onShare: {
                if let data = try? JSONEncoder().encode(source),
                   let json = String(data: data, encoding: .utf8) {
                    shareText = json
                    activeSheet = .shareSheet
                }
            },
            onTapDetail: {
                activeSheet = .detail(source: source, id: source.id ?? UUID().uuidString)
            }
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
    }

    private func loadSources() {
        isLoading = true
        defer { isLoading = false }
        sources = Self.fixtureSources
    }

    private func toggleSource(_ source: BookSource) {
        guard let id = source.id,
              let idx = sources.firstIndex(where: { $0.id == id }) else { return }
        // @State 数组必须整体替换才能触发 UI 刷新
        var copy = sources
        copy[idx].enabled.toggle()
        sources = copy
    }

    private func deleteSource(_ source: BookSource) {
        guard let id = source.id else { return }
        sources.removeAll { $0.id == id }
    }
}
