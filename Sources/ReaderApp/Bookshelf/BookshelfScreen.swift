import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct BookshelfScreen: View {
    let model: ShelfModel
    let root: URL

    private enum Route: Hashable { case detail(BookIdentity); case settings }

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
                onOpen: { path.append(.detail(BookIdentity($0))) }, onRemove: confirmRemove,
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
                    Button { picker = true } label: { ReaderIcon(ReaderIconRegistry.add) }
                        .accessibilityLabel("导入本地书")
                        .accessibilityIdentifier("import-local-book")
                        .disabled(model.library == nil)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .settings: SettingsScreen()
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

    private func confirmRemove(_ entry: BookshelfEntryData) {
        actionGeneration += 1
        removal = BookIdentity(entry)
        confirmation = ReaderConfirmation(title: "移出书架？", message: "《\(entry.title)》将从书架移除。",
                                          confirmTitle: "移除", generation: actionGeneration)
    }
}
