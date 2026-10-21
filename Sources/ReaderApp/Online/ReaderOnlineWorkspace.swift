import SwiftUI
import UniformTypeIdentifiers
import WebKit

@MainActor final class ReaderOnlineWorkspaceModel: ObservableObject {
    @Published var query = ""
    @Published var sourceFilter = ""
    @Published var sources: [ReaderOnlineSource] = []
    @Published var results: [ReaderOnlineCandidate] = []
    @Published var timings: [String: Int] = [:]
    @Published var failures: [String: String] = [:]
    @Published var searching = false
    @Published var stopped = false
    @Published var searched = false
    @Published var currentResultIDs = Set<String>()
    @Published var sourceLoading = false
    @Published var sourceReadFailure: String?
    @Published private(set) var sourceReadFailureID: UUID?
    @Published var scrollAnchor: String?
    @Published var error: String?
    @Published var detail: ReaderOnlineDetail?
    @Published var detailLoading = false
    @Published var selected: ReaderOnlineCandidate?
    @Published var notice: String?
    let actions = ReaderLibraryActionOwner()
    var service: (any ReaderOnlineServing)?
    private var searchTask: Task<Void, Never>?
    private var searchID = UUID()
    private var detailID = UUID()
    private var detailTask: Task<Void, Never>?
    private var sourcesID = UUID()
    private var lastKeyword = ""
    private var announcedSourceFailure: UUID?
    deinit { searchTask?.cancel(); detailTask?.cancel() }
    func loadSources() async {
        guard let service else { return }
        let generation = UUID(); sourcesID = generation
        sourceLoading = true; defer { if sourcesID == generation { sourceLoading = false } }
        do { let result = try await service.onlineSources(); guard sourcesID == generation else { return }; sources = result; sourceReadFailure = nil; sourceReadFailureID = nil }
        catch { guard sourcesID == generation else { return }; sourceReadFailure = error.localizedDescription; sourceReadFailureID = UUID() }
    }
    func consumeSourceRefreshNotice() -> String? {
        guard !sources.isEmpty, let id = sourceReadFailureID, announcedSourceFailure != id else { return nil }
        announcedSourceFailure = id
        return "书源刷新未完成，已有书源仍可使用。"
    }
    func stop() { stopped = searching; searchTask?.cancel(); searchID = UUID(); searching = false }
    func search() { startSearch(retainCandidates: false) }
    func researchCandidates() { startSearch(retainCandidates: true) }
    private func startSearch(retainCandidates: Bool) {
        guard let service, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        stop()
        let enabled = sources.filter(\.enabled)
        guard !enabled.isEmpty else { return }
        let generation = UUID(); searchID = generation
        let keyword = query
        if !retainCandidates || keyword != lastKeyword { results = []; scrollAnchor = nil }
        lastKeyword = keyword; currentResultIDs = []
        timings = [:]; failures = [:]; searched = true; stopped = false; searching = true; error = nil
        searchTask = Task {
            await withTaskGroup(of: (String, ReaderSourceSearchResult?, String?).self) { group in
                var remaining = enabled.makeIterator()
                func enqueue(_ source: ReaderOnlineSource) {
                    group.addTask {
                        do { return (source.id, try await service.searchSource(source.id, keyword: keyword, page: 1), nil) }
                        catch is CancellationError { return (source.id, nil, nil) }
                        catch { return (source.id, nil, error.localizedDescription) }
                    }
                }
                for _ in 0..<4 { if let source = remaining.next() { enqueue(source) } }
                while let (sourceID, response, failure) = await group.next() {
                    guard generation == searchID, !Task.isCancelled else { group.cancelAll(); return }
                    if let response {
                        // Stable identity/order: late metadata never moves a tapped row.
                        var indexes = Dictionary(uniqueKeysWithValues: results.enumerated().map { ($0.element.id, $0.offset) })
                        for book in response.books {
                            if let index = indexes[book.id] { results[index] = book }
                            else { indexes[book.id] = results.count; results.append(book) }
                            currentResultIDs.insert(book.id)
                        }
                        timings[sourceID] = response.elapsedMilliseconds
                    } else if let failure { failures[sourceID] = failure }
                    if let source = remaining.next() { enqueue(source) }
                }
            }
            if generation == searchID { searching = false }
        }
    }
    func showDetail(_ candidate: ReaderOnlineCandidate) {
        guard let service else { return }
        detailTask?.cancel()
        let generation = UUID(); detailID = generation; selected = candidate; detail = nil; detailLoading = true; error = nil
        detailTask = Task {
            do { let value = try await service.onlineDetail(candidate); guard !Task.isCancelled, generation == detailID else { return }; detail = value }
            catch { guard !Task.isCancelled, generation == detailID else { return }; self.error = error.localizedDescription }
            if generation == detailID { detailLoading = false }
        }
    }
    func closeDetail() { detailTask?.cancel(); detailTask = nil; detailID = UUID(); selected = nil; detail = nil; detailLoading = false; error = nil }
    func sourceName(_ id: String) -> String { sources.first(where: { $0.id == id })?.name ?? id }
}

struct ReaderOnlineWorkspace: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var preferences: ReaderPreferences
    let close: () -> Void
    @StateObject private var state = ReaderOnlineWorkspaceModel()
    @State private var managing = false
    @State private var subscriptions = false
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ReaderIconAction(icon: .back, label: "返回", action: close)
                    .accessibilityIdentifier("online-close-workspace")
                Text(managing ? "书源管理" : "在线搜索").font(ReaderTypography.font(.controlHeader))
                Spacer()
                Button(managing ? "搜索" : "书源") { managing.toggle() }.frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier(managing ? "online-close-sources" : "online-open-sources")
            }.padding(.horizontal, 12)
            if managing {
                ReaderSourceManagement(state: state)
            } else if let candidate = state.selected {
                detail(candidate)
            } else {
                searchPage
            }
            ReaderOnlineSourceRefreshNotice(state: state)
            ReaderOperationStatus(owner: state.actions, scope: "online")
        }.foregroundStyle(ReaderPalette(scheme).ink).background(ReaderPalette(scheme).paper)
            .task { state.service = model.libraryService as? any ReaderOnlineServing; await state.loadSources() }
    }
    private var searchPage: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("书名或作者", text: $state.query).submitLabel(.search).onSubmit(state.search).readerField()
                    .accessibilityIdentifier("online-search-query")
                if state.searching { Button("停止", action: state.stop).accessibilityIdentifier("online-search-stop") }
                else { Button("搜索", action: state.search).accessibilityIdentifier("online-search-submit") }
            }.padding(.horizontal, 20)
            if state.sources.filter(\.enabled).isEmpty {
                ReaderPageState(title: state.sourceLoading ? "正在加载书源" : state.sourceReadFailure == nil ? "还没有启用的书源" : "书源加载失败", detail: state.sourceReadFailure ?? "导入书源后即可搜索。", loading: state.sourceLoading, actionTitle: state.sourceReadFailure == nil ? "管理书源" : "重试") {
                    if state.sourceReadFailure != nil { Task { await state.loadSources() } }
                    else { managing = true }
                }
            } else {
                HStack {
                    TextField("筛选来源或书名", text: $state.sourceFilter).readerField()
                    Text("\(state.results.count) 项").font(ReaderTypography.font(.caption))
                }.padding(.horizontal, 20)
                if state.searching { ProgressView("正在搜索 · 已返回 \(state.timings.count + state.failures.count)/\(state.sources.filter(\.enabled).count) 个书源").font(ReaderTypography.font(.caption)) }
                if !state.failures.isEmpty { Text("\(state.failures.count) 个书源未完成，可保留已有结果并重新搜索").font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(scheme).muted) }
                if state.results.isEmpty, state.searched, !state.searching {
                    ReaderPageState(title: state.stopped ? "搜索已停止" : state.timings.isEmpty ? "搜索未完成" : !state.failures.isEmpty ? "部分书源未完成" : "没有找到相关书籍", detail: state.stopped ? "可重新搜索，已有书架和阅读位置保留。" : state.timings.isEmpty ? "所有书源均未返回有效结果，请检查书源或网络。" : !state.failures.isEmpty ? "已返回的书源中没有匹配项，可重新搜索未完成的书源。" : "可更换关键词或书源。", actionTitle: "重新搜索", action: state.search)
                } else if !state.results.isEmpty, filteredResults.isEmpty {
                    ReaderPageState(title: "没有符合筛选的书籍", detail: "清除筛选可查看已有搜索结果。", actionTitle: "清除筛选") { state.sourceFilter = "" }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredResults) { book in
                                Button { state.showDetail(book) } label: {
                                    HStack(spacing: 14) {
                                        ReaderBookCover(book: ReaderBook(sourceId: book.sourceId, bookId: book.bookId, title: book.title, coverUrl: book.coverUrl), imageService: state.service as? any ReaderRemoteImageServing).frame(width: 54, height: 76)
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(book.title).font(ReaderTypography.font(.controlHeader)).lineLimit(2)
                                            Text(book.author).font(ReaderTypography.font(.caption))
                                            Text(state.sourceName(book.sourceId) + (state.timings[book.sourceId].map { " · \($0) ms" } ?? "")).font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(scheme).muted)
                                        }
                                        Spacer(); ReaderIcon(.chevronRight)
                                    }.padding(20).contentShape(Rectangle())
                                }.buttonStyle(ReaderPressFeedback()).id(book.id)
                                    .accessibilityIdentifier("online-result:\(book.id)")
                                Divider().padding(.horizontal, 20)
                            }
                        }.scrollTargetLayout()
                    }.scrollPosition(id: Binding(get: { state.scrollAnchor }, set: { id in
                        if let id, state.results.contains(where: { $0.id == id }) { state.scrollAnchor = id }
                    }))
                }
            }
        }
    }
    private var filteredResults: [ReaderOnlineCandidate] {
        state.results.filter { state.sourceFilter.isEmpty || $0.title.localizedCaseInsensitiveContains(state.sourceFilter) || state.sourceName($0.sourceId).localizedCaseInsensitiveContains(state.sourceFilter) }
    }
    @ViewBuilder private func detail(_ candidate: ReaderOnlineCandidate) -> some View {
        VStack(spacing: 12) {
            HStack {
                Button("返回搜索", action: state.closeDetail).accessibilityIdentifier("online-back-search")
                Spacer()
                Text(state.sourceName(candidate.sourceId)).lineLimit(1)
                    .accessibilityIdentifier("online-selected:\(candidate.id)")
            }.padding(.horizontal, 20)
            if let detail = state.detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 18) {
                            ReaderBookCover(book: detail.book, imageService: state.service as? any ReaderRemoteImageServing).frame(width: 86, height: 124)
                            Text(detail.book.title).font(ReaderTypography.font(.controlHeader))
                                .accessibilityIdentifier("online-detail-book:\(detail.book.bookId)")
                        }
                        Text(detail.book.author).font(ReaderTypography.font(.caption))
                        Text(detail.book.intro ?? "暂无简介").font(ReaderTypography.font(.caption))
                        Button("加入书架并阅读") { add(detail, index: detail.firstReadableIndex) }.buttonStyle(ReaderPrimaryButtonStyle()).disabled(state.actions.hasPending)
                            .accessibilityIdentifier("online-add-and-read")
                        Text("目录 · \(detail.chapters.count) 章").font(ReaderTypography.font(.controlHeader))
                        ForEach(detail.chapters) { chapter in
                            Button(chapter.title) { add(detail, index: chapter.index) }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .disabled(state.actions.hasPending)
                        }
                    }.padding(20)
                }.accessibilityIdentifier("online-detail-scroll")
            } else {
                ReaderPageState(title: state.detailLoading ? "正在加载书籍与目录" : "暂时无法打开书籍", detail: state.error ?? "", loading: state.detailLoading, actionTitle: state.detailLoading ? nil : "重试") { state.showDetail(candidate) }
            }
        }
    }
    private func add(_ detail: ReaderOnlineDetail, index: UInt32) {
        guard let service = state.service else { return }
        Task {
            await state.actions.perform("入架", scope: "online") { id in
                let book = try await service.addOnlineBook(detail, chapterIndex: index, operationID: id)
                await model.reloadLibrary(); model.open(book, chapterIndex: index)
            }
        }
    }
}

/// A failed refresh keeps the original source snapshot. This projection owns
/// only its two-second display and consumes each original failure once.
struct ReaderOnlineSourceRefreshNotice: View {
    @ObservedObject var state: ReaderOnlineWorkspaceModel
    @State private var message: String?
    @State private var displayID: UUID?
    @Environment(\.scenePhase) private var phase
    var body: some View {
        Group {
            if let message { ReaderTransientFeedback(message: message).allowsHitTesting(false) }
        }
        .task(id: state.sourceReadFailureID) {
            let id = state.sourceReadFailureID
            displayID = id
            message = state.consumeSourceRefreshNotice()
            guard phase == .active else { displayID = nil; message = nil; return }
            guard message != nil else { return }
            defer { if displayID == id { message = nil } }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        .onDisappear { displayID = nil; message = nil }
        .onChange(of: phase) { _, value in if value != .active { displayID = nil; message = nil } }
    }
}

private struct ReaderSourceManagement: View {
    @ObservedObject var state: ReaderOnlineWorkspaceModel
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @StateObject private var draftOwner: ReaderSourceEditorDraftOwner
    @State private var link = ""
    @State private var importFile = false
    @State private var fileRead: ReaderSourceEditorDraftOwner.ReadRequest?
    @State private var exportFile = false
    @State private var exportData = ReaderSourceJSONDocument(data: Data())
    @State private var importResults: [ReaderSourceImportItem] = []
    @State private var filter = ""
    @State private var login: ReaderOnlineSource?
    @State private var diagnostic = ""
    @State private var subscriptionPage = false
    @State private var diagnosticGeneration = UUID()
    @State private var debugSource: ReaderOnlineSource?
    @State private var validating = false
    @Environment(\.colorScheme) private var scheme
    init(state: ReaderOnlineWorkspaceModel) {
        self.state = state
        _draftOwner = StateObject(wrappedValue: ReaderSourceEditorDraftOwner(actions: state.actions))
    }
    var body: some View {
        let fileRequest = fileRead
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Button("导入 JSON") { openEditor() }; Button("选择文件", action: chooseSourceFile).disabled(!draftOwner.canReplace).accessibilityIdentifier("online-source-file"); Button("导出") { exportSources() } }
                Button("书源规则订阅") { subscriptionPage = true }
                    .accessibilityIdentifier("online-rule-subscriptions")
                HStack { TextField("书源包链接", text: $link).textInputAutocapitalization(.never).keyboardType(.URL).readerField(); Button("读取") { fetch() }.disabled(!draftOwner.canReplace) }
                TextField("名称或分组", text: $filter).readerField()
                if let error = state.error { ReaderPageState(title: "书源操作未完成", detail: error) }
                ForEach(importResults) { item in Text(item.name + " · " + item.message).font(ReaderTypography.font(.caption)) }
                if state.sources.isEmpty {
                    ReaderPageState(title: state.sourceLoading ? "正在加载书源" : state.sourceReadFailure == nil ? "暂无书源" : "书源加载失败", detail: state.sourceReadFailure ?? "", loading: state.sourceLoading, actionTitle: state.sourceReadFailure == nil ? nil : "重试") { Task { await state.loadSources() } }
                }
                ForEach(state.sources.filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) || $0.group.localizedCaseInsensitiveContains(filter) }) { source in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(source.name).font(ReaderTypography.font(.controlHeader))
                                .accessibilityIdentifier("online-source:\(source.id)"); Spacer()
                            Toggle("启用", isOn: Binding(get: { source.enabled }, set: { value in mutate("更改书源") { id in try await state.service?.updateSource(source.id, enabled: value, operationID: id) } })).labelsHidden()
                                .accessibilityIdentifier("online-source-enabled:\(source.id)")
                        }
                        Text(source.group.isEmpty ? source.baseURL : source.group).font(ReaderTypography.font(.caption)).lineLimit(1)
                        HStack {
                            Button("编辑") {
                                receive(draftOwner.offer(.savedSource(source.id, version: source.version, name: source.name,
                                                                      text: String(decoding: source.definition, as: UTF8.self))))
                            }.disabled(!draftOwner.canReplace)
                                .accessibilityIdentifier("online-source-edit:" + source.id)
                            Button("检测") { diagnose(source) }
                            Button("调试") { debugSource = source }
                            Button("网页登录") { login = source }
                            Spacer()
                            Button("删除", role: .destructive) { confirmation.confirm("删除书源？", message: "已有书籍与缓存保留，后续联网将需要重新导入此书源。", actionTitle: "删除", destructive: true) { mutate("删除书源") { id in try await state.service?.deleteSource(source.id, operationID: id) } } }
                        }.font(ReaderTypography.font(.caption))
                    }.padding(16).background(ReaderPalette(scheme).card, in: RoundedRectangle(cornerRadius: 16))
                }
                if !diagnostic.isEmpty { Text(diagnostic).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
            }.padding(20)
        }.accessibilityIdentifier("online-source-scroll")
            .readerConfirmation(confirmation)
            .disabled(state.actions.busy)
            .onAppear { draftOwner.activate(); restoreSaveIfNeeded() }
            .onDisappear {
                draftOwner.retire(); confirmation.request = nil; fileRead = nil
                diagnosticGeneration = UUID(); validating = false
            }
            .onChange(of: link) { _, _ in draftOwner.cancelRead() }
            .onChange(of: state.sourceLoading) { _, loading in if !loading { restoreSaveIfNeeded() } }
            .onChange(of: draftOwner.editorGeneration) { _, _ in validating = false }
            .onChange(of: confirmation.request?.id) { _, id in if id == nil { draftOwner.dismissConfirmation() } }
            .onChange(of: state.actions.hasPending) { _, pending in
                if pending { confirmation.request = nil; draftOwner.dismissConfirmation(); draftOwner.cancelRead() }
                else { restoreSaveIfNeeded() }
            }
            .onChange(of: state.actions.busy) { _, busy in if !busy { draftOwner.refreshPersistedDraft() } }
            .sheet(isPresented: Binding(get: { draftOwner.presented }, set: { if !$0 { draftOwner.close() } })) {
                VStack(spacing: 14) {
                    HStack { Button("保留草稿并关闭") { draftOwner.close() }; Spacer(); Button("校验") { validate() }.disabled(validating || !draftOwner.canReplace); Button("保存") { save() }.disabled(!draftOwner.canReplace || validating).accessibilityIdentifier("online-source-save") }
                    TextEditor(text: Binding(get: { draftOwner.draft }, set: draftOwner.updateDraft))
                        .disabled(!draftOwner.canReplace).font(.system(.body, design: .monospaced)).accessibilityLabel("书源 JSON 草稿")
                        .accessibilityIdentifier("online-source-draft")
                    if validating { ProgressView("正在校验") }
                    ForEach(importResults) { item in Text(item.name + " · " + item.message).font(ReaderTypography.font(.caption)) }
                    ReaderOperationStatus(owner: state.actions, scope: "online", completed: { Task { await state.loadSources(); draftOwner.refreshPersistedDraft() } })
                }.padding(20).onAppear { restoreSaveIfNeeded() }
            }
            .sheet(item: $login) { source in ReaderSourceLogin(source: source, service: state.service) }
            .sheet(item: $debugSource) { source in if let service = state.service { ReaderSourceDebugPanel(source: source, service: service) } }
            .sheet(isPresented: $subscriptionPage, onDismiss: { Task { await state.loadSources() } }) {
                if let service = state.service as? any ReaderRuleSubscriptionServing { ReaderRuleSubscriptionPanel(service: service) }
            }
            .fileImporter(isPresented: $importFile, allowedContentTypes: [.json, .plainText]) { result in
                guard let fileRequest, draftOwner.accepts(fileRequest) else { return }
                defer { if fileRead == fileRequest { fileRead = nil } }
                do {
                    let url = try result.get(); let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    let text = String(decoding: try Data(contentsOf: url), as: UTF8.self)
                    receive(draftOwner.finishRead(fileRequest, target: .imported(text, label: "导入文件“\(url.lastPathComponent)”")))
                } catch { draftOwner.cancelRead(); state.error = error.localizedDescription }
            }
            .fileExporter(isPresented: $exportFile, document: exportData, contentType: .json, defaultFilename: "Reader-书源") { result in if case .failure(let error) = result { state.error = error.localizedDescription } }
    }
    private func mutate(_ label: String, action: @escaping (String) async throws -> Void) {
        Task { if await state.actions.perform(label, scope: "online", action: action) { await state.loadSources() } }
    }
    private func save() {
        guard state.service != nil, draftOwner.canReplace, draftOwner.presented else { return }
        Task {
            let confirmed = await draftOwner.save(using: saveOriginal)
            if confirmed { await state.loadSources() }
        }
    }
    private func saveOriginal(_ id: String, input: ReaderSourceEditorDraftOwner.SaveInput) async throws -> Bool {
        guard let service = state.service else { throw ReaderLibraryError.operationPending(id) }
        let result = try await service.importSources(input.bytes, operationID: id)
        if draftOwner.isCurrentEditor(input) { importResults = result }
        return result.allSatisfy(\.succeeded)
    }
    private func restoreSaveIfNeeded() {
        guard let features = state.service as? any ReaderLibraryFeatures else { return }
        state.actions.pendingChecker = { id in
            do { return try await features.pendingFeatureOperations().contains { $0.id == id || $0.id.hasPrefix(id + ":") } }
            catch { return nil }
        }
        _ = draftOwner.restoreSave(using: saveOriginal)
    }
    private func openEditor() {
        confirmation.request = nil; draftOwner.resumeDraft(); importResults = []; validating = false
    }
    private func receive(_ result: ReaderSourceEditorDraftOwner.OpenResult) {
        switch result {
        case .ignored: break
        case .opened:
            confirmation.request = nil; importResults = []; validating = false
        case .confirmation(let intent):
            confirmation.request = nil
            confirmation.confirm("替换当前书源草稿？", message: "\(intent.target.label)将覆盖当前未保存的内容。取消可保留原草稿。",
                                 actionTitle: "替换草稿", destructive: true) {
                guard draftOwner.confirm(intent) else { return }
                importResults = []; validating = false
            }
        }
    }
    private func chooseSourceFile() {
        guard let request = draftOwner.beginRead() else { return }
        confirmation.request = nil; fileRead = request; importFile = true
    }
    private func validate() {
        guard let service = state.service, draftOwner.canReplace, !validating else { return }
        let bytes = Data(draftOwner.draft.utf8), generation = draftOwner.editorGeneration
        validating = true
        Task {
            do { let result = try await service.validateSources(bytes); if generation == draftOwner.editorGeneration, Data(draftOwner.draft.utf8) == bytes { importResults = result } }
            catch { if generation == draftOwner.editorGeneration { state.error = error.localizedDescription } }
            if generation == draftOwner.editorGeneration { validating = false }
        }
    }
    private func fetch() {
        guard let url = URL(string: link), let service = state.service, let request = draftOwner.beginRead() else { return }
        confirmation.request = nil
        Task {
            do {
                let result = try await service.onlineFetch(url)
                receive(draftOwner.finishRead(request, target: .imported(String(decoding: result, as: UTF8.self), label: "导入链接中的书源")))
            } catch { if draftOwner.accepts(request) { draftOwner.cancelRead(); state.error = error.localizedDescription } }
        }
    }
    private func exportSources() {
        guard let service = state.service else { return }
        Task { do { exportData = .init(data: try await service.exportSources(nil)); exportFile = true } catch { state.error = error.localizedDescription } }
    }
    private func diagnose(_ source: ReaderOnlineSource) {
        guard let service = state.service else { return }
        diagnostic = "正在检测 \(source.name)"
        let generation = UUID(); diagnosticGeneration = generation
        Task { do { let result = try await service.onlineDiagnostic(source.id, keyword: state.query.isEmpty ? "我的" : state.query); if diagnosticGeneration == generation { diagnostic = String(decoding: result, as: UTF8.self) } } catch { if diagnosticGeneration == generation { diagnostic = error.localizedDescription } } }
    }
}

struct ReaderSourceJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct ReaderSourceLogin: View {
    let source: ReaderOnlineSource
    let service: (any ReaderOnlineServing)?
    @State private var webView: WKWebView?
    @State private var cookies: [HTTPCookie]?
    @State private var failure: String?
    @State private var saving = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack {
            HStack { Button("关闭") { dismiss() }; Spacer(); Text(source.name); Spacer(); Button("完成登录") { save() }.disabled(webView == nil || saving) }.padding()
            if let failure { ReaderPageState(title: "网页登录未完成", detail: failure) }
            else if let cookies { ReaderSourceLoginWebView(url: loginURL, cookies: cookies, webView: $webView) }
            else { ReaderPageState(title: "正在准备来源登录", loading: true) }
        }.task { do { cookies = try await service?.prepareLogin(source.id) ?? [] } catch { failure = error.localizedDescription } }
    }
    private var loginURL: URL? {
        let raw = (try? JSONSerialization.jsonObject(with: source.definition)) as? [String: Any]
        return URL(string: raw?["loginUrl"] as? String ?? source.baseURL)
    }
    private func save() {
        guard let webView, let service, !saving else { return }; saving = true
        let originalCookies = cookies ?? []
        Task {
            let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            do { try await service.completeLogin(source.id, cookies: cookies, originalCookies: originalCookies); dismiss() }
            catch { failure = error.localizedDescription }
            saving = false
        }
    }
}
private struct ReaderSourceLoginWebView: UIViewRepresentable {
    let url: URL?
    let cookies: [HTTPCookie]
    @Binding var webView: WKWebView?
    final class Coordinator {
        var active = true
        var setup: Task<Void, Never>?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: config)
        let coordinator = context.coordinator
        coordinator.setup = Task { @MainActor in
            guard coordinator.active, !Task.isCancelled else { return }
            webView = view
            for cookie in cookies {
                await config.websiteDataStore.httpCookieStore.setCookie(cookie)
                guard coordinator.active, !Task.isCancelled else { return }
            }
            guard coordinator.active, !Task.isCancelled else { return }
            if let url, ["http", "https"].contains(url.scheme ?? "") { view.load(URLRequest(url: url)) }
        }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) { }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.active = false; coordinator.setup?.cancel(); coordinator.setup = nil; view.stopLoading()
    }
}
