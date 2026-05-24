import SwiftUI
import ReaderCoreModels
import ReaderShellValidation
import ReaderAppPersistence

public struct BookSourceListView: View {
    @ObservedObject var coordinator: ReadingFlowCoordinator
    @State private var sources: [BookSource] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingImport = false
    @State private var shareText: String = ""
    @State private var showShare = false
    @State private var selectedDetail: BookSource?
    @State private var showDetail = false

    private let store = BookSourceStore.shared

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
                    Button(action: { showingImport = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingImport) {
                BookSourceImportView()
            }
            .sheet(isPresented: $showShare) {
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
                            Button("完成") { showShare = false }
                        }
                    }
                }
            }
            .task {
                await loadSources()
            }
            .refreshable {
                await loadSources()
            }
            .sheet(isPresented: $showDetail) {
                if let source = selectedDetail {
                    BookSourceDetailView(source: source)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("暂无书源")
                .font(.title2)
                .fontWeight(.semibold)

            Text("导入书源以开始使用")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("导入书源") {
                showingImport = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var enabledSources: [BookSource] {
        sources.filter { $0.enabled }
    }

    private var disabledSources: [BookSource] {
        sources.filter { !$0.enabled }
    }

    private var sourceListContent: some View {
        List {
            if !enabledSources.isEmpty {
                Section("已启用 (\(enabledSources.count))") {
                    ForEach(enabledSources, id: \.id) { source in
                        sourceRow(source: source)
                    }
                }
            }
            if !disabledSources.isEmpty {
                Section("已禁用 (\(disabledSources.count))") {
                    ForEach(disabledSources, id: \.id) { source in
                        sourceRow(source: source)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func sourceRow(source: BookSource) -> some View {
        BookSourceRowView(
            source: source,
            onToggle: { Task { await toggleSource(source) } },
            onDelete: { Task { await deleteSource(source) } },
            onShare: {
                if let data = try? JSONEncoder().encode(source),
                   let json = String(data: data, encoding: .utf8) {
                    shareText = json
                    showShare = true
                }
            },
            onTapDetail: {
                selectedDetail = source
                showDetail = true
            }
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
    }

    private func loadSources() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var list = try await store.load()
            if list.isEmpty {
                // Pre-populate fixture sources for demo
                try await store.save(Self.fixtureSources)
                list = Self.fixtureSources
            }
            sources = list
        } catch {
            errorMessage = "加载书源失败: \(error.localizedDescription)"
        }
    }

    private func toggleSource(_ source: BookSource) async {
        guard let id = source.id else { return }

        do {
            try await store.toggleEnabled(id: id)
            await loadSources()
        } catch {
            errorMessage = "切换书源失败: \(error.localizedDescription)"
        }
    }

    private func deleteSource(_ source: BookSource) async {
        guard let id = source.id else { return }

        do {
            try await store.delete(id: id)
            await loadSources()
        } catch {
            errorMessage = "删除书源失败: \(error.localizedDescription)"
        }
    }
}
