import SwiftUI

/// Root retains this navigation/filter projection. Core and the existing
/// action owners retain accepted writes independently of the page lifetime.
@MainActor
final class ReaderDownloadManagementPresentation: ObservableObject {
    struct SourceOption: Identifiable {
        let sourceId: String
        let title: String
        var id: Data { Data(sourceId.utf8) }
    }
    enum StateFilter: String, CaseIterable { case all = "全部", failed = "失败", active = "进行中", paused = "暂停", completed = "已完成", cancelled = "已取消" }
    enum Sort: String, CaseIterable { case updated = "最近更新", title = "书名", tasks = "任务数" }
    @Published var query = ""
    @Published var state: StateFilter = .all
    @Published var contentKind = ""
    @Published var sourceId = ""
    @Published var sort: Sort = .updated
    @Published var ascending = false
    @Published var bookAnchor: ReaderDownloadBookCursor?
    @Published var selected: ReaderDownloadBook?
    @Published private var chapterAnchors: [ReaderDownloadBookCursor: UInt32] = [:]
    let inventory = ReaderDownloadReadOwner<UUID, [ReaderDownloadBook]>()
    let identity = UUID()
    private var controls: [ReaderDownloadBookCursor: ReaderDownloadControlOwner] = [:]

    var sourceKey: Data {
        get { Data(sourceId.utf8) }
        set { if let value = String(data: newValue, encoding: .utf8) { sourceId = value } }
    }

    func sourceOptions(_ items: [ReaderDownloadBook]) -> [SourceOption] {
        var sources: [Data: SourceOption] = [:]
        for item in items {
            let key = Data(item.sourceId.utf8)
            if sources[key] == nil { sources[key] = .init(sourceId: item.sourceId, title: item.sourceName ?? item.sourceId) }
        }
        if !sourceId.isEmpty, sources[sourceKey] == nil {
            sources[sourceKey] = .init(sourceId: sourceId, title: sourceId)
        }
        return sources.values.sorted { $0.id.lexicographicallyPrecedes($1.id) }
    }

    func chapterAnchor(for identity: ReaderDownloadBookCursor) -> Binding<UInt32?> {
        Binding(get: { self.chapterAnchors[identity] }, set: { self.chapterAnchors[identity] = $0 })
    }

    func controlOwner(for item: ReaderDownloadBook, model: ReaderApplicationModel) -> ReaderDownloadControlOwner {
        if let owner = controls[item.id] { return owner }
        let owner = ReaderDownloadControlOwner(pendingChecker: { [weak actions = model.actions] id in
            guard let checker = actions?.pendingChecker else { return nil }
            return await checker(id)
        })
        controls[item.id] = owner
        return owner
    }

    func refresh(service: (any ReaderDownloadServing)?) {
        inventory.activate(identity: identity)
        inventory.invalidate(identity: identity) { publish in
            guard let service else { throw ReaderLibraryError.invalidResponse("当前书库不支持下载清单") }
            publish(try await service.readerDownloadBooks())
        }
    }

    func visible(_ items: [ReaderDownloadBook]) -> [ReaderDownloadBook] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            (needle.isEmpty || [item.displayTitle, item.author ?? "", item.bookId, item.sourceName ?? item.sourceId]
                .contains { $0.localizedCaseInsensitiveContains(needle) }) &&
            (contentKind.isEmpty || item.contentKind == contentKind) &&
            (sourceId.isEmpty || item.sourceId.utf8.elementsEqual(sourceId.utf8)) && accepts(item)
        }.sorted { a, b in
            let order: Bool
            switch sort {
            case .updated:
                if a.latestUpdatedAt != b.latestUpdatedAt { return ascending ? a.latestUpdatedAt < b.latestUpdatedAt : a.latestUpdatedAt > b.latestUpdatedAt }
                order = a.id.precedes(b.id)
            case .tasks:
                if a.taskCount != b.taskCount { return ascending ? a.taskCount < b.taskCount : a.taskCount > b.taskCount }
                order = a.id.precedes(b.id)
            case .title:
                let result = a.displayTitle.localizedStandardCompare(b.displayTitle)
                if result != .orderedSame { return ascending ? result == .orderedAscending : result == .orderedDescending }
                order = a.id.precedes(b.id)
            }
            return order
        }
    }

    private func accepts(_ item: ReaderDownloadBook) -> Bool {
        switch state {
        case .all: return true
        case .failed: return item.failedCount > 0
        case .active: return item.queuedCount > 0 || item.inProgressCount > 0
        case .paused: return item.pausedCount > 0
        case .completed: return item.completedCount > 0
        case .cancelled: return item.cancelledCount > 0
        }
    }
}

struct ReaderDownloadManagementView: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var owner: ReaderDownloadManagementPresentation
    @ObservedObject private var inventory: ReaderDownloadReadOwner<UUID, [ReaderDownloadBook]>
    let close: () -> Void
    @Environment(\.scenePhase) private var phase
    @Environment(\.colorScheme) private var scheme

    init(model: ReaderApplicationModel, owner: ReaderDownloadManagementPresentation, close: @escaping () -> Void) {
        self.model = model; self.owner = owner; self.close = close
        _inventory = ObservedObject(wrappedValue: owner.inventory)
    }
    private var palette: ReaderPalette { ReaderPalette(scheme) }
    private var items: [ReaderDownloadBook] { inventory.value ?? [] }

    var body: some View {
        Group {
            if let selected = owner.selected {
                let item = items.first { $0.id == selected.id } ?? selected
                if item.supportsTextControls {
                    ReaderOnlineDownloadPanel(model: model, book: item.controlBook,
                        downloadActions: owner.controlOwner(for: item, model: model),
                        chapterAnchor: owner.chapterAnchor(for: item.id), close: backToBooks)
                        .id(item.id)
                } else {
                    VStack(spacing: 18) {
                        header(back: backToBooks)
                        Text(item.displayTitle).font(ReaderTypography.font(.controlHeader))
                            .accessibilityIdentifier("online-download-book-identity:" + item.id.accessibilityKey)
                        Text(item.sourceName ?? item.sourceId).font(ReaderTypography.font(.caption))
                        ReaderPageState(title: "此类任务暂不支持控制",
                            detail: "保留的媒介类型为 \(kindName(item.contentKind))，共 \(item.taskCount) 项任务。")
                        Spacer()
                    }.padding(.horizontal, 18)
                }
            } else {
                books
            }
        }.foregroundStyle(palette.ink).background(palette.paper)
            .task(id: phase == .active && model.reader == nil) {
                if phase == .active && model.reader == nil { refresh() } else { inventory.retire() }
            }
            .onChange(of: phase) { _, phase in if phase != .active { inventory.retire() } }
            .onDisappear { inventory.retire() }
    }

    private var books: some View {
        VStack(spacing: 14) {
            header { inventory.retire(); close() }
            TextField("筛选下载书籍、作者或书源", text: $owner.query).readerField()
                .accessibilityIdentifier("download-management-search")
            HStack(spacing: 16) {
                Button("全部") { owner.state = .all }.accessibilityIdentifier("download-management-filter-all")
                Button("失败") { owner.state = .failed }.accessibilityIdentifier("download-management-filter-failed")
                Menu(owner.state == .all || owner.state == .failed ? "状态" : owner.state.rawValue) {
                    ForEach(ReaderDownloadManagementPresentation.StateFilter.allCases, id: \.self) { filter in
                        Button(filter.rawValue) { owner.state = filter }
                    }
                }
                Spacer()
                Menu("筛选与排序") {
                    Picker("媒介", selection: $owner.contentKind) {
                        Text("全部类型").tag("")
                        ForEach(Array(Set(items.map(\.contentKind) + (owner.contentKind.isEmpty ? [] : [owner.contentKind]))).sorted(), id: \.self) { Text(kindName($0)).tag($0) }
                    }
                    Picker("书源", selection: $owner.sourceKey) {
                        Text("全部书源").tag(Data())
                        ForEach(owner.sourceOptions(items)) { source in
                            Text(source.title).tag(source.id)
                        }
                    }
                    Picker("排序", selection: $owner.sort) {
                        ForEach(ReaderDownloadManagementPresentation.Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("升序", isOn: $owner.ascending)
                }
            }.font(ReaderTypography.font(.caption))
            if let failure = inventory.failure {
                ReaderPageState(title: items.isEmpty ? "下载清单不可用" : "下载清单刷新未完成", detail: failure,
                                actionTitle: "重试", action: refresh)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let visible = owner.visible(items)
            if inventory.value == nil && inventory.failure == nil {
                ReaderPageState(title: "正在加载下载书籍", loading: true)
            } else if visible.isEmpty {
                ReaderPageState(title: items.isEmpty ? "暂无下载任务" : "没有符合筛选的下载书籍")
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visible) { item in
                        Button { owner.selected = item; inventory.retire() } label: { bookRow(item) }
                            .buttonStyle(ReaderPressFeedback()).id(item.id)
                            .accessibilityIdentifier("download-management-book:" + item.id.accessibilityKey)
                        Divider()
                    }
                }.scrollTargetLayout()
            }.scrollPosition(id: $owner.bookAnchor, anchor: .top)
                .accessibilityIdentifier("download-management-books")
        }.padding(.horizontal, 18).padding(.top, 16)
    }

    private func header(back: @escaping () -> Void) -> some View {
        HStack {
            ReaderIconAction(icon: .back, label: "返回", action: back)
                .accessibilityIdentifier("download-management-back")
            Spacer(); Text("下载管理").font(ReaderTypography.font(.controlHeader)); Spacer()
            Button(inventory.loading ? "正在刷新" : "刷新", action: refresh)
                .disabled(inventory.loading || phase != .active)
                .accessibilityIdentifier("download-management-refresh")
        }.frame(minHeight: 52)
    }
    private func bookRow(_ item: ReaderDownloadBook) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ReaderBookCover(book: item.controlBook,
                imageService: item.sourceConfigured ? model.libraryService as? any ReaderRemoteImageServing : nil)
                .frame(width: 54, height: 80)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    Text(item.displayTitle).font(ReaderTypography.font(.controlHeader)).multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Text(kindName(item.contentKind)).font(ReaderTypography.font(.caption))
                }
                Text([item.author, item.sourceName ?? item.sourceId].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted).lineLimit(2)
                Text("\(item.completedCount) / \(item.taskCount) 项已完成 · 失败 \(item.failedCount) · 暂停 \(item.pausedCount)")
                    .font(ReaderTypography.font(.caption)).multilineTextAlignment(.leading)
                ProgressView(value: Double(item.completedCount), total: Double(item.taskCount)).tint(palette.green)
                    .accessibilityLabel("任务完成进度")
                if item.inProgressCount > 0 || item.queuedCount > 0 || item.cancelledCount > 0 {
                    Text("下载中 \(item.inProgressCount) · 排队 \(item.queuedCount) · 已取消 \(item.cancelledCount)")
                        .font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted)
                }
                if !item.onShelf || !item.sourceConfigured {
                    Text([item.onShelf ? nil : "已离开书架", item.sourceConfigured ? nil : "书源未配置"].compactMap { $0 }.joined(separator: " · "))
                        .font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted)
                }
            }
        }.padding(.vertical, 15).contentShape(Rectangle())
    }
    private func kindName(_ value: String) -> String {
        switch value { case "text": return "小说"; case "manga": return "漫画"; case "audio": return "有声"; case "unknown": return "未知类型"; default: return value }
    }
    private func backToBooks() { owner.selected = nil; refresh() }
    private func refresh() {
        guard phase == .active, model.reader == nil else { return }
        owner.refresh(service: model.libraryService as? any ReaderDownloadServing)
    }
}
