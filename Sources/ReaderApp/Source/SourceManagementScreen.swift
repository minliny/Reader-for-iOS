import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct SourceManagementScreen: View {
    let coordinator: SourceManagementCoordinator
    @Environment(\.readerTheme) private var theme
    @Environment(\.scenePhase) private var scene
    @State private var sources: [M2SourceListEntry]?
    @State private var groups: M2SourceGroupCatalogData?
    @State private var query = ""
    @State private var groupID: String?
    @State private var selection: Set<String> = []
    @State private var selecting = false
    @State private var pendingPage: Surface?
    @State private var confirmation: Confirmation?
    @State private var busy = false
    @State private var loadFailed = false
    @State private var recoveryGeneration = 0
    @State private var reloadGeneration = 0
    @State private var recovering = false
    @State private var toast = ReaderToastPresenter()

    private enum Surface: Identifiable {
        case add, subscriptions, reports
        case edit(M2SourceListEntry), diagnostic(SourceReportRow), login(String), check(Set<String>)

        var id: String {
            switch self {
            case .add: "import"
            case .subscriptions: "subscriptions"
            case .reports: "reports"
            case .edit(let entry): "edit-\(entry.sourceId)"
            case .diagnostic(let row): "report-\(row.sourceId)"
            case .login(let id): "login-\(id)"
            case .check(let ids): "check-\(ids.sorted().joined(separator: ","))"
            }
        }
    }

    private enum Confirmation: Identifiable {
        case delete(Set<String>)
        case clearLogin(M2SourceListEntry)

        var id: String {
            switch self {
            case .delete(let ids): "delete-\(ids.sorted().joined(separator: ","))"
            case .clearLogin(let entry): "clear-\(entry.sourceId)"
            }
        }

        var title: String {
            switch self {
            case .delete: "删除书源？"
            case .clearLogin: "清除登录态？"
            }
        }

        var message: String {
            switch self {
            case .delete(let ids): "将删除 \(ids.count) 个书源。书架条目、缓存和阅读进度会保留。"
            case .clearLogin: "将清除该书源的 Cookie 和检测报告，其他书源不受影响。"
            }
        }
    }

    var body: some View {
        Group {
            if let sources {
                SourceCatalogContent(sources: sources, groups: groups, query: $query, groupID: $groupID,
                                     selection: $selection, selecting: selecting, onAction: route)
                    .refreshable { await load() }
            } else {
                PageState(state: loadFailed ? .failed("无法读取书源", actionGeneration: reloadGeneration) : .loading) { generation in
                    if generation == reloadGeneration { Task { await load() } }
                }
            }
        }
        .background(theme.background)
        .navigationTitle("书源管理")
        .navigationBarTitleDisplayMode(.inline)
        .readerNavigationBar()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("source.catalog")
        .safeAreaInset(edge: .bottom) { taskProgress }
        .overlay(alignment: .top) { recoveryNotice }
        .overlay(alignment: .bottom) {
            if scene == .active, pendingPage == nil, let message = toast.message {
                TransientToast(message: message).padding(CGFloat(ReaderDesignMetrics.spaceSmall))
            }
        }
        .task { await load() }
        .onChange(of: coordinator.checkBatch.revision) { _, _ in Task { await load() } }
        .onChange(of: coordinator.importBatch.running) { _, running in
            if !running { Task { await load() } }
        }
        .sheet(item: $pendingPage, onDismiss: { Task { await load() } }) { page in
            NavigationStack { content(page) }
        }
        .alert(confirmation?.title ?? "", isPresented: Binding(
            get: { confirmation != nil },
            set: { if !$0 { confirmation = nil } }
        ), presenting: confirmation) { value in
            Button("取消", role: .cancel) {}
            Button("确认", role: .destructive) { commit(value) }
        } message: { value in Text(value.message) }
    }

    @ViewBuilder
    private var recoveryNotice: some View {
        if recovering {
            let generation = recoveryGeneration
            RecoveryNotice(title: "需要核对书源操作", message: "上一次变更尚无可核对回执，核对之前会保留已有书源。",
                           generation: generation, action: .init(title: "核对原操作", generation: generation),
                           availability: pendingPage == nil && confirmation == nil) { expected, action in
                guard expected == recoveryGeneration, action == expected else { return }
                verify()
            }
            .padding(CGFloat(ReaderDesignMetrics.spaceSmall))
        }
    }

    @ViewBuilder
    private var taskProgress: some View {
        if coordinator.checkBatch.running {
            ReaderTaskProgress(title: "正在检测书源", completed: coordinator.checkBatch.completed,
                               failed: coordinator.checkBatch.failed, total: coordinator.checkBatch.rows.count)
                .padding(CGFloat(ReaderDesignMetrics.screenInset))
        } else if coordinator.importBatch.running {
            ReaderTaskProgress(title: "正在导入书源", completed: coordinator.importBatch.completed,
                               failed: coordinator.importBatch.failed, total: coordinator.importBatch.total)
                .padding(CGFloat(ReaderDesignMetrics.screenInset))
        }
    }

    @ViewBuilder
    private func content(_ page: Surface) -> some View {
        switch page {
        case .add:
            SourceImportScreen(coordinator: coordinator) { Task { await load() } }
        case .subscriptions:
            SourceSubscriptionsScreen(coordinator: coordinator)
        case .reports:
            SourceReportsScreen(storedSources: sources ?? [], batch: coordinator.checkBatch)
        case .edit(let source):
            SourceEditScreen(source: source, coordinator: coordinator)
        case .diagnostic(let row):
            SourceDiagnosticScreen(row: row, batch: coordinator.checkBatch)
        case .login(let id):
            SourceLoginScreen(sourceID: id, title: sources?.first { $0.sourceId == id }?.name ?? "书源登录",
                              coordinator: coordinator)
        case .check(let ids):
            SourceCheckOptions(count: ids.count) { levels, keyword in
                let entries = (sources ?? []).filter { ids.contains($0.sourceId) }
                coordinator.checkBatch.start(sources: entries, levels: levels, keyword: keyword, coordinator: coordinator)
            }
        }
    }

    private func route(_ action: SourceListAction) {
        switch action {
        case .add: pendingPage = .add
        case .subscriptions: pendingPage = .subscriptions
        case .reports: pendingPage = .reports
        case .edit(let source): pendingPage = .edit(source)
        case .login(let id): pendingPage = .login(id)
        case .report(let source):
            let report = coordinator.checkBatch.rows.first { $0.id == source.sourceId }
                ?? source.latestSourceReport
                ?? .init(sourceId: source.sourceId, name: source.name, report: nil)
            pendingPage = .diagnostic(report)
        case .select:
            selecting.toggle()
            if !selecting { selection = [] }
        case .selectVisible(let ids):
            if ids.isSubset(of: selection) { selection.subtract(ids) } else { selection.formUnion(ids) }
        case .check(let ids):
            if coordinator.checkBatch.running { notify("正在检测，请查看批量报告", key: "check-running") }
            else if !ids.isEmpty { pendingPage = .check(ids) }
        case .delete(let ids): if !ids.isEmpty { confirmation = .delete(ids) }
        case .clearLogin(let source): confirmation = .clearLogin(source)
        case .enabled(let id, let enabled): setEnabled([id], enabled: enabled)
        case .batchEnabled(let ids, let enabled): setEnabled(ids, enabled: enabled)
        }
    }

    private func load() async {
        reloadGeneration += 1
        let generation = reloadGeneration
        defer {
            if generation == reloadGeneration { updateRecovery() }
        }
        do {
            let updated = try await coordinator.list(.init(includeCheckReports: true, checkReportVersion: .v2)).sources
            guard generation == reloadGeneration else { return }
            sources = updated
            loadFailed = false
            selection.formIntersection(updated.map(\.sourceId))
            do {
                let catalog = try await coordinator.groups()
                guard generation == reloadGeneration else { return }
                groups = catalog
                if let groupID, !catalog.groups.contains(where: { $0.groupId == groupID }) { self.groupID = nil }
            } catch {
                guard generation == reloadGeneration else { return }
                notify("暂时无法刷新分组", key: "source-groups")
            }
        } catch {
            guard generation == reloadGeneration else { return }
            if sources == nil { loadFailed = true }
            else { notify("书源暂时无法刷新，已保留原列表", key: "source-list-refresh") }
        }
    }

    private func setEnabled(_ ids: Set<String>, enabled: Bool) {
        execute(key: "source-enabled") {
            let receipts = try await coordinator.updateEnabled(sourceIds: ids.sorted(), enabled: enabled)
            let applied = receipts.filter {
                if case .sourceUpdate = $0 { return true }
                return false
            }.count
            return "已更新 \(applied) 个书源 · 未更新 \(ids.count - applied) 个"
        }
    }

    private func commit(_ value: Confirmation) {
        switch value {
        case .delete(let ids):
            execute(key: "source-delete") {
                let receipt = try await coordinator.delete(.init(sourceIds: ids.sorted()))
                guard case .sourceDelete(let result) = receipt else { throw SourceManagementCoordinator.Failure.invalidDraft }
                return "已删除 \(result.data.deleted) 个书源"
            }
        case .clearLogin(let source):
            execute(key: "source-clear-login") {
                guard let base = source.baseUrl.sourceDocumentURL else { throw SourceManagementCoordinator.Failure.loginUnavailable }
                _ = try await coordinator.clearLogin(sourceId: source.sourceId, url: base)
                return "已清除该书源的登录态和检测报告"
            }
        }
    }

    private func execute(key: String, _ operation: @escaping @MainActor () async throws -> String) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let message = try await operation()
                await load()
                notify(message, key: key)
            } catch {
                await load()
                if !recovering {
                    notify("操作未完整完成，列表已按当前状态刷新", key: key)
                }
            }
        }
    }

    private func verify() {
        execute(key: "source-recovery") {
            guard let result = try await coordinator.verifyPending() else { return "原操作暂未返回可核对回执" }
            if case .rejected = result { return "Core 已确认该变更未应用" }
            return "已核对原操作"
        }
    }

    private func updateRecovery() {
        let unresolved = coordinator.pendingMutation != nil
        if recovering != unresolved {
            recoveryGeneration += 1
            recovering = unresolved
        }
    }

    private func notify(_ message: String, key: String) {
        _ = toast.show(message: message, key: key, feedbackEnabled: pendingPage == nil, sceneActive: scene == .active)
    }
}
