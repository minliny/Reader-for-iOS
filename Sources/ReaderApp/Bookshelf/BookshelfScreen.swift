import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct BookshelfScreen: View {
    let model: ShelfModel
    let root: URL

    private enum Route: Hashable {
        case detail(BookIdentity)
        case onlineDetail(OnlineBookReference)
        case settings, search, sources, downloads
    }

    @State private var path: [Route] = []
    @State private var picker = false
    @State private var confirmation: ReaderConfirmation?
    @State private var removal: BookIdentity?
    @State private var actionGeneration = 0
    @AppStorage("reader.shelf.sort") private var sort = ShelfSort.added
    @Environment(\.readerTheme) private var theme
    @Environment(\.scenePhase) private var phase

    var body: some View {
        NavigationStack(path: $path) {
            BookshelfContent(
                books: model.books, state: model.state, recovery: model.recovery,
                onOpen: openBook, onRemove: confirmRemove,
                onRetry: {},
                onRetryGeneration: { generation in Task { await model.retry(root: root, expected: generation) } },
                onRecovery: { generation, action in
                    Task { await model.recover(expected: generation, action: action) }
                }, recoveryAvailable: !picker && confirmation == nil && path.isEmpty && phase == .active
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let task = model.task {
                    HStack {
                        ReaderTaskProgress(title: "导入本地书", completed: task.completed,
                                           failed: task.failed, total: task.total)
                        if task.completed + task.failed == task.total {
                            Button("关闭", systemImage: "xmark", action: model.clearFinishedTask)
                                .labelStyle(.iconOnly).accessibilityLabel("关闭导入进度")
                        }
                    }
                    .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
                    .padding(.vertical, 8)
                    .background(theme.background)
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = model.toast.message, path.isEmpty, !picker, confirmation == nil, phase == .active {
                    TransientToast(message: toast).padding(16)
                }
            }
            .background(theme.background)
            .navigationTitle("书架")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("设置", systemImage: "gearshape") { path.append(.settings) }
                        .accessibilityIdentifier("reader-settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { path.append(.search) } label: { ReaderIcon(ReaderIconRegistry.search) }
                        .accessibilityLabel("全局搜索")
                        .accessibilityIdentifier("reader-online-search")
                        .disabled(model.online == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { picker = true } label: { ReaderIcon(ReaderIconRegistry.add) }
                        .accessibilityLabel("导入本地书")
                        .accessibilityIdentifier("import-local-book")
                        .disabled(model.library == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("书源管理") { path.append(.sources) }
                            .accessibilityIdentifier("reader-open-sources")
                        Button { path.append(.downloads) } label: {
                            Label { Text("下载管理") } icon: { ReaderIcon(ReaderIconRegistry.download) }
                        }
                        .accessibilityIdentifier("reader-open-downloads")
                    } label: {
                        ReaderIcon(ReaderIconRegistry.more)
                    }
                    .accessibilityLabel("书架更多功能")
                    .accessibilityIdentifier("reader-online-menu")
                    .disabled(model.online == nil)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .settings: SettingsScreen(runtime: model.library?.runtime)
                case .search:
                    if let session = model.online, let files = model.files {
                        GlobalSearchScreen(session: session, files: files) { await model.reload() }
                    }
                case .sources:
                    if let session = model.online { SourceManagementScreen(coordinator: session.sources) }
                case .downloads:
                    if let session = model.online { DownloadManagementScreen(session: session) }
                case .onlineDetail(let reference):
                    if let session = model.online, let files = model.files {
                        OnlineBookDetailScreen(reference: reference, session: session, files: files,
                                               refreshShelf: { await model.reload() },
                                               remove: { await model.remove($0) })
                    }
                case .detail(let identity):
                    if let runtime = model.library?.runtime, let files = model.files {
                        BookDetailScreen(identity: identity, runtime: runtime, files: files) {
                            await model.remove(identity)
                        } refreshShelf: { await model.reload() }
                    }
                }
            }
        }
        .sheet(isPresented: $picker) {
            DocumentPicker(onSelect: { urls in picker = false; model.importFiles(urls) },
                           onCancel: { picker = false })
        }
        .readerConfirmation($confirmation) { generation in
            guard generation == actionGeneration, let removal, path.isEmpty else { return }
            self.removal = nil
            Task { await model.remove(removal) }
        }
        .onChange(of: sort, initial: true) { _, value in
            model.sort = value
            Task { await model.reload() }
        }
        .onChange(of: path) { _, value in
            model.frontmost = value.isEmpty && !picker
            model.toast.dismiss()
            if value.isEmpty { Task { await model.reload() } }
        }
        .onChange(of: picker) { _, value in
            model.frontmost = !value && path.isEmpty
            if value { model.toast.dismiss() }
        }
        .onChange(of: phase, initial: true) { _, value in
            model.sceneActive = value == .active
            if value != .active { model.toast.dismiss() }
        }
    }

    private func openBook(_ entry: BookshelfEntryData) {
        if entry.sourceId == "local" {
            path.append(.detail(BookIdentity(entry)))
        } else {
            path.append(.onlineDetail(OnlineBookReference(shelfBook: entry)))
        }
    }

    private func confirmRemove(_ entry: BookshelfEntryData) {
        actionGeneration += 1
        removal = BookIdentity(entry)
        confirmation = ReaderConfirmation(title: "移出书架？", message: "《\(entry.title)》将从书架移除。",
                                          confirmTitle: "移除", generation: actionGeneration)
    }
}
