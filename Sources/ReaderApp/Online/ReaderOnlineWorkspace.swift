import SwiftUI
import UniformTypeIdentifiers
import WebKit

@MainActor final class ReaderOnlineWorkspaceModel: ObservableObject {
    @Published var query = "" {
        didSet {
            #if DEBUG && targetEnvironment(simulator)
            if query != oldValue, ReaderUIVerificationJournal.observes(ReaderUIVerificationJournal.search) {
                ReaderUIVerificationJournal.record(ReaderUIVerificationJournal.search, "search-edit",
                    values: ["utf16Length": Double(query.utf16.count)])
            }
            #endif
        }
    }
    @Published var sourceFilter = ""
    @Published var sources: [ReaderOnlineSource] = []
    @Published var results: [ReaderOnlineCandidate] = []
    @Published var timings: [String: Int] = [:]
    @Published var failures: [String: String] = [:]
    @Published var searching = false
    @Published var stopped = false
    @Published var searched = false
    @Published var currentResultIDs = Set<String>()
    @Published private(set) var searchSourceCount = 0
    @Published var sourceLoading = false
    @Published private(set) var sourceReadRevision = 0
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
    var searchTraceSink: ReaderSearchTraceSink? // Disabled unless an observation owner installs a sink.
    private var searchTask: Task<Void, Never>?
    private var searchTrace: ReaderSearchTraceRecording?
    private var searchID = UUID()
    private var detailID = UUID()
    private var detailTask: Task<Void, Never>?
    private var sourcesID = UUID()
    // The complete search workspace and cached switch sheets opt into the same
    // read lifetime. Source-management and accepted mutation owners stay intact.
    private var discoveryManaged = false
    private var discoveryPresentationID: UUID?
    private var discoverySourcesTask: Task<[ReaderOnlineSource], Error>?
    private var lastKeyword = ""
    private var lastSourceVersions: [String: String] = [:]
    private struct SuccessfulSearchSource {
        let keyword: String
        let version: String
        let resultIDs: Set<String>
        let elapsedMilliseconds: Int
    }
    private var successfulSearchSources: [String: SuccessfulSearchSource] = [:]
    private var announcedSourceFailure: UUID?
    deinit { searchTask?.cancel(); detailTask?.cancel(); discoverySourcesTask?.cancel() }

    func activateDiscoveryPresentation(_ identity: UUID) {
        guard !Task.isCancelled, discoveryPresentationID != identity else { return }
        retireDiscoveryReads()
        discoveryManaged = true; discoveryPresentationID = identity
        #if DEBUG && targetEnvironment(simulator)
        ReaderUIVerificationJournal.record(ReaderUIVerificationJournal.search, "search-entry",
            tags: ["presentationID": identity.uuidString])
        #endif
    }

    func isCurrentDiscoveryPresentation(_ identity: UUID) -> Bool {
        discoveryManaged && discoveryPresentationID == identity
    }

    func retireDiscoveryPresentation(_ identity: UUID) {
        guard isCurrentDiscoveryPresentation(identity) else { return }
        discoveryPresentationID = nil
        retireDiscoveryReads()
    }

    func retireCachedDiscovery() {
        discoveryManaged = true; discoveryPresentationID = nil
        retireDiscoveryReads()
    }

    private func retireDiscoveryReads() {
        sourcesID = UUID(); discoverySourcesTask?.cancel(); discoverySourcesTask = nil
        sourceLoading = false
        if searching { stopped = true }
        searchTrace?.emit(.generationStopped, outcome: .presentationRetired); searchTrace = nil
        searchID = UUID(); searchTask?.cancel(); searchTask = nil; searching = false
        detailID = UUID(); detailTask?.cancel(); detailTask = nil; detailLoading = false
        // Keep obtained candidates/query/scroll/timings and every write owner.
    }

    private func searchPresentationIsCurrent(_ identity: UUID?) -> Bool {
        !discoveryManaged || (identity != nil && discoveryPresentationID == identity)
    }

    func refreshDiscoverySources(presentationID identity: UUID) async {
        guard !Task.isCancelled, isCurrentDiscoveryPresentation(identity), let service else { return }
        discoverySourcesTask?.cancel()
        let generation = UUID(); sourcesID = generation
        sourceLoading = true
        let read = Task {
            try Task.checkCancellation()
            return try await service.onlineSources()
        }
        discoverySourcesTask = read
        defer {
            if sourcesID == generation { sourceLoading = false; discoverySourcesTask = nil }
        }
        do {
            let result = try await withTaskCancellationHandler(operation: {
                try await read.value
            }, onCancel: { read.cancel() })
            guard !Task.isCancelled, sourcesID == generation,
                  isCurrentDiscoveryPresentation(identity) else { return }
            sources = result; sourceReadFailure = nil; sourceReadFailureID = nil
            sourceReadRevision += 1
            if !searched { search() }
        } catch {
            guard !Task.isCancelled, sourcesID == generation,
                  isCurrentDiscoveryPresentation(identity) else { return }
            sourceReadFailure = error.localizedDescription; sourceReadFailureID = UUID()
        }
    }
    func loadSources() async {
        let presentationID = discoveryPresentationID
        guard !Task.isCancelled, searchPresentationIsCurrent(presentationID), let service else { return }
        discoverySourcesTask?.cancel()
        let generation = UUID(); sourcesID = generation
        sourceLoading = true
        let read = Task {
            try Task.checkCancellation()
            return try await service.onlineSources()
        }
        discoverySourcesTask = read
        defer {
            if sourcesID == generation { sourceLoading = false; discoverySourcesTask = nil }
        }
        do {
            let result = try await withTaskCancellationHandler(operation: {
                try await read.value
            }, onCancel: { read.cancel() })
            guard !Task.isCancelled, sourcesID == generation,
                  searchPresentationIsCurrent(presentationID) else { return }
            sources = result; sourceReadFailure = nil; sourceReadFailureID = nil
            sourceReadRevision += 1
        } catch {
            guard !Task.isCancelled, sourcesID == generation,
                  searchPresentationIsCurrent(presentationID) else { return }
            sourceReadFailure = error.localizedDescription; sourceReadFailureID = UUID()
        }
    }
    func consumeSourceRefreshNotice() -> String? {
        guard !sources.isEmpty, let id = sourceReadFailureID, announcedSourceFailure != id else { return nil }
        announcedSourceFailure = id
        return "书源刷新未完成，已有书源仍可使用。"
    }
    func stop() {
        searchTrace?.emit(.generationStopped, outcome: .cancelled); searchTrace = nil
        stopped = searching; searchTask?.cancel(); searchTask = nil; searchID = UUID(); searching = false
    }
    private enum SearchMode: Equatable { case newSearch, refreshCandidates, retryIncomplete }
    func search() { startSearch(.newSearch) }
    // Explicit refresh searches every enabled source, retaining prior rows as
    // unconfirmed until the new generation actually returns their identities.
    func researchCandidates() { startSearch(.refreshCandidates) }
    func retryIncompleteSources() { startSearch(.retryIncomplete) }
    private func startSearch(_ mode: SearchMode) {
        let presentationID = discoveryPresentationID
        guard let service, searchPresentationIsCurrent(presentationID),
              !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        stop()
        let keyword = query
        let enabled = sources.filter(\.enabled)
        let versions = Dictionary(uniqueKeysWithValues: enabled.map { ($0.id, $0.version) })
        let sameKeyword = Data(keyword.utf8) == Data(lastKeyword.utf8)
        if mode == .newSearch || !sameKeyword {
            results = []; scrollAnchor = nil
        } else {
            // A registry change cannot carry an old rule's rows into recovery
            // or a refresh, including rows retained by an earlier refresh.
            results.removeAll { candidate in
                guard let version = versions[candidate.sourceId] else { return true }
                return lastSourceVersions[candidate.sourceId] != version
            }
            if let anchor = scrollAnchor, !results.contains(where: { $0.id == anchor }) { scrollAnchor = nil }
        }
        let retained = mode == .retryIncomplete && sameKeyword
            ? successfulSearchSources.filter { sourceID, success in
                Data(success.keyword.utf8) == Data(keyword.utf8) && versions[sourceID] == success.version
            } : [:]
        successfulSearchSources = retained
        currentResultIDs = retained.values.reduce(into: Set<String>()) { $0.formUnion($1.resultIDs) }
        timings = retained.mapValues(\.elapsedMilliseconds)
        failures = [:]; searched = true; stopped = false; error = nil
        lastKeyword = keyword; lastSourceVersions = versions
        searchSourceCount = enabled.count
        let pending = enabled.filter { retained[$0.id] == nil }
        guard !pending.isEmpty else {
            #if DEBUG && targetEnvironment(simulator)
            ReaderUIVerificationJournal.record(ReaderUIVerificationJournal.search, "search-no-work",
                values: ["utf16Length": Double(keyword.utf16.count), "sourceCount": Double(enabled.count)])
            #endif
            return
        }
        let generation = UUID(); searchID = generation
        #if DEBUG && targetEnvironment(simulator)
        ReaderUIVerificationJournal.record(ReaderUIVerificationJournal.search, "search-accepted",
            tags: ["generation": generation.uuidString],
            values: ["utf16Length": Double(keyword.utf16.count), "sourceCount": Double(pending.count)])
        #endif
        let trace = searchTraceSink.map { ReaderSearchTraceRecording(searchID: generation, sink: $0) }
        searchTrace = trace
        // The trace describes only newly dispatched work. Retained successes
        // contribute to presentation progress, never to this request generation.
        trace?.emit(.generationStarted, count: pending.count)
        searching = true
        searchTask = Task {
            guard !Task.isCancelled, generation == searchID,
                  searchPresentationIsCurrent(presentationID) else {
                trace?.emit(.generationFinished, outcome: .superseded); return
            }
            await withTaskGroup(of: (String, UInt32, ReaderSourceSearchResult?, String?).self) { group in
                var remaining = pending.enumerated().makeIterator()
                var unapplied = Set<UInt32>()
                defer {
                    // Returning from the original stale-generation guard also
                    // discards every still-enqueued source, even if it finishes later.
                    for ordinal in unapplied {
                        trace?.emit(.sourceResultDiscarded, sourceOrdinal: ordinal, outcome: .superseded)
                    }
                }
                func enqueue(_ source: ReaderOnlineSource, ordinal: UInt32) {
                    if trace != nil { unapplied.insert(ordinal) }
                    group.addTask {
                        let attempt = trace.map { ReaderSearchTraceAttempt(recording: $0, sourceOrdinal: ordinal, source: source) }
                        attempt?.emit(.sourceAttemptStarted)
                        guard !Task.isCancelled else {
                            attempt?.emit(.sourceAttemptFinished, outcome: .cancelled)
                            return (source.id, ordinal, nil, nil)
                        }
                        do {
                            let response = try await ReaderSearchTraceContext.$attempt.withValue(attempt) {
                                try await service.searchSource(source.id, keyword: keyword, page: 1)
                            }
                            attempt?.emit(.sourceAttemptFinished, outcome: .succeeded,
                                count: response.books.count, durationMilliseconds: response.elapsedMilliseconds)
                            return (source.id, ordinal, response, nil)
                        } catch is CancellationError {
                            attempt?.emit(.sourceAttemptFinished, outcome: .cancelled)
                            return (source.id, ordinal, nil, nil)
                        } catch {
                            attempt?.emit(.sourceAttemptFinished, outcome: .failure(error))
                            return (source.id, ordinal, nil, error.localizedDescription)
                        }
                    }
                }
                for _ in 0..<4 {
                    if let source = remaining.next() { enqueue(source.element, ordinal: UInt32(clamping: source.offset + 1)) }
                }
                while let (sourceID, ordinal, response, failure) = await group.next() {
                    guard generation == searchID, !Task.isCancelled,
                          searchPresentationIsCurrent(presentationID) else { group.cancelAll(); return }
                    unapplied.remove(ordinal)
                    if let response {
                        // Stable identity/order: late metadata never moves a tapped row.
                        var indexes = Dictionary(uniqueKeysWithValues: results.enumerated().map { ($0.element.id, $0.offset) })
                        for book in response.books {
                            if let index = indexes[book.id] { results[index] = book }
                            else { indexes[book.id] = results.count; results.append(book) }
                            currentResultIDs.insert(book.id)
                        }
                        timings[sourceID] = response.elapsedMilliseconds
                        if let version = versions[sourceID] {
                            successfulSearchSources[sourceID] = .init(keyword: keyword, version: version,
                                resultIDs: Set(response.books.map(\.id)), elapsedMilliseconds: response.elapsedMilliseconds)
                        }
                        trace?.emit(.sourceResultApplied, sourceOrdinal: ordinal, outcome: .succeeded,
                                    count: response.books.count, durationMilliseconds: response.elapsedMilliseconds)
                    } else if let failure {
                        failures[sourceID] = failure
                        trace?.emit(.sourceResultApplied, sourceOrdinal: ordinal, outcome: .failed)
                    } else { trace?.emit(.sourceResultDiscarded, sourceOrdinal: ordinal, outcome: .cancelled) }
                    if let source = remaining.next() { enqueue(source.element, ordinal: UInt32(clamping: source.offset + 1)) }
                }
            }
            if generation == searchID, searchPresentationIsCurrent(presentationID) {
                searching = false; searchTask = nil
                searchTrace = nil
                trace?.emit(.generationFinished)
                #if DEBUG && targetEnvironment(simulator)
                ReaderUIVerificationJournal.record(ReaderUIVerificationJournal.search, "search-settled",
                    tags: ["generation": generation.uuidString],
                    values: ["resultCount": Double(results.count), "successfulSources": Double(timings.count),
                             "failedSources": Double(failures.count)])
                #endif
            } else {
                trace?.emit(.generationFinished, outcome: .superseded)
            }
        }
    }
    func showDetail(_ candidate: ReaderOnlineCandidate) {
        let presentationID = discoveryPresentationID
        guard !Task.isCancelled, searchPresentationIsCurrent(presentationID), let service else { return }
        detailTask?.cancel()
        let generation = UUID(); detailID = generation; selected = candidate; detail = nil; detailLoading = true; error = nil
        detailTask = Task {
            guard !Task.isCancelled, generation == detailID,
                  searchPresentationIsCurrent(presentationID) else { return }
            do {
                let value = try await service.onlineDetail(candidate)
                guard !Task.isCancelled, generation == detailID,
                      searchPresentationIsCurrent(presentationID) else { return }
                detail = value
            } catch {
                guard !Task.isCancelled, generation == detailID,
                      searchPresentationIsCurrent(presentationID) else { return }
                self.error = error.localizedDescription
            }
            if generation == detailID, searchPresentationIsCurrent(presentationID) { detailLoading = false }
        }
    }
    func closeDetail() { detailTask?.cancel(); detailTask = nil; detailID = UUID(); selected = nil; detail = nil; detailLoading = false; error = nil }
    func sourceName(_ id: String) -> String { sources.first(where: { $0.id == id })?.name ?? id }
    func candidateElapsedMilliseconds(_ candidate: ReaderOnlineCandidate) -> Int? {
        guard currentResultIDs.contains(candidate.id) else { return nil }
        return timings[candidate.sourceId]
    }
    func candidateSearchStatus(_ candidate: ReaderOnlineCandidate) -> String? {
        guard !currentResultIDs.contains(candidate.id) else { return nil }
        return searching ? "上次候选 · 本次搜索中" : "上次候选 · 本次未确认"
    }
}

struct ReaderOnlineWorkspace: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var preferences: ReaderPreferences
    let close: () -> Void
    @StateObject private var state: ReaderOnlineWorkspaceModel
    #if DEBUG
    @StateObject private var searchEvidence: ReaderOnlineSearchEvidence
    #endif
    @ObservedObject private var subscriptionScheduler: ReaderRuleSubscriptionScheduler
    @State private var managing = false
    @State private var subscriptions = false
    @State private var workspacePresentationID = UUID()
    private enum SearchField: Hashable { case query, filter }
    @FocusState private var focusedSearchField: SearchField?
    @Environment(\.colorScheme) private var scheme
    private var searchVisible: Bool { !managing && state.selected == nil }

    @MainActor init(model: ReaderApplicationModel, preferences: ReaderPreferences, close: @escaping () -> Void) {
        self.init(model: model, preferences: preferences, close: close,
            state: ReaderOnlineWorkspaceModel(), subscriptionScheduler: .shared)
    }

    @MainActor init(model: ReaderApplicationModel, preferences: ReaderPreferences, close: @escaping () -> Void,
                    state: ReaderOnlineWorkspaceModel, subscriptionScheduler: ReaderRuleSubscriptionScheduler) {
        self.model = model; self.preferences = preferences; self.close = close
        _state = StateObject(wrappedValue: state)
        #if DEBUG
        _searchEvidence = StateObject(wrappedValue: ReaderOnlineSearchEvidence(attachingTo: state,
            expectedMode: ReaderOnlineSearchEvidence.globalMode))
        #endif
        _subscriptionScheduler = ObservedObject(wrappedValue: subscriptionScheduler)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ReaderIconAction(icon: .back, label: "返回") {
                    state.retireDiscoveryPresentation(workspacePresentationID)
                    close()
                }
                    .accessibilityIdentifier("online-close-workspace")
                #if DEBUG
                if searchEvidence.enabled {
                    workspaceTitle.accessibilityIdentifier(ReaderOnlineSearchEvidence.globalHeaderIdentifier)
                        .accessibilityValue(searchEvidence.proof)
                } else { workspaceTitle }
                #else
                workspaceTitle
                #endif
                Spacer()
                Button(managing ? "搜索" : "书源") { focusedSearchField = nil; managing.toggle() }.frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier(managing ? "online-close-sources" : "online-open-sources")
            }.padding(.horizontal, 12)
            ZStack(alignment: .top) {
                // Keep the native scroll container and its intra-row offset
                // alive through these child routes. An item ID alone cannot
                // reconstruct the original viewport after remounting.
                searchPage
                    .opacity(searchVisible ? 1 : 0)
                    .allowsHitTesting(searchVisible)
                    .accessibilityHidden(!searchVisible)
                if managing {
                    ReaderSourceManagement(state: state)
                } else if let candidate = state.selected {
                    detail(candidate)
                }
            }
            ReaderOnlineSourceRefreshNotice(state: state)
            ReaderOperationStatus(owner: state.actions, scope: "online", completed: { Task { await state.loadSources() } })
                .accessibilityIdentifier("online-original-operation")
        }.foregroundStyle(ReaderPalette(scheme).ink).background(ReaderPalette(scheme).paper)
            // The same finite task owns initial load and opportunity refresh.
            // loadSources keeps the current presentation/generation checks and
            // preserves candidates, draft/write owners and the old list on failure.
            .task(id: subscriptionScheduler.completedOpportunityRevision) {
                guard !Task.isCancelled else { return }
                state.activateDiscoveryPresentation(workspacePresentationID)
                state.service = model.libraryService as? any ReaderOnlineServing
                await state.loadSources()
            }
            // Only the complete workspace lifetime ends here. Its management/
            // detail overlays and the root's reading opacity keep this view alive.
            .onDisappear { state.retireDiscoveryPresentation(workspacePresentationID) }
    }
    private var workspaceTitle: some View {
        Text(managing ? "书源管理" : "在线搜索").font(ReaderTypography.font(.controlHeader))
    }
    private var searchPage: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("书名或作者", text: $state.query).submitLabel(.search).onSubmit { submitSearch(origin: "ime") }.readerField()
                    .focused($focusedSearchField, equals: .query)
                    .accessibilityIdentifier("online-search-query")
                if state.searching {
                    Button("停止") { focusedSearchField = nil; state.stop() }
                        .accessibilityIdentifier("online-search-stop")
                } else { Button("搜索") { submitSearch(origin: "button") }.accessibilityIdentifier("online-search-submit") }
            }.padding(.horizontal, 20)
            if state.sources.filter(\.enabled).isEmpty {
                ReaderPageState(title: state.sourceLoading ? "正在加载书源" : state.sourceReadFailure == nil ? "还没有启用的书源" : "书源加载失败", detail: state.sourceReadFailure ?? "导入书源后即可搜索。", loading: state.sourceLoading, actionTitle: state.sourceReadFailure == nil ? "管理书源" : "重试") {
                    if state.sourceReadFailure != nil { Task { await state.loadSources() } }
                    else { managing = true }
                }
            } else {
                HStack {
                    TextField("筛选来源或书名", text: $state.sourceFilter).readerField()
                        .focused($focusedSearchField, equals: .filter)
                    Text("\(state.results.count) 项").font(ReaderTypography.font(.caption))
                }.padding(.horizontal, 20)
                if state.searching { ProgressView("正在搜索 · 已返回 \(state.timings.count + state.failures.count)/\(state.searchSourceCount) 个书源").font(ReaderTypography.font(.caption)) }
                if !state.searching && !state.results.isEmpty && (state.stopped || !state.failures.isEmpty) {
                    HStack(spacing: 8) {
                        Text(state.stopped ? "搜索已停止，可保留已有结果并重新搜索" : "\(state.failures.count) 个书源未完成，可保留已有结果并重新搜索")
                            .font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(scheme).muted)
                        Button("重新搜索", action: state.retryIncompleteSources)
                            .accessibilityIdentifier("online-research-failed")
                    }.padding(.horizontal, 20)
                }
                if state.results.isEmpty, state.searched, !state.searching {
                    ReaderPageState(title: state.stopped ? "搜索已停止" : state.timings.isEmpty ? "搜索未完成" : !state.failures.isEmpty ? "部分书源未完成" : "没有找到相关书籍", detail: state.stopped ? "可重新搜索，已有书架和阅读位置保留。" : state.timings.isEmpty ? "所有书源均未返回有效结果，请检查书源或网络。" : !state.failures.isEmpty ? "已返回的书源中没有匹配项，可重新搜索未完成的书源。" : "可更换关键词或书源。", actionTitle: "重新搜索") {
                        if state.stopped || !state.failures.isEmpty { state.retryIncompleteSources() }
                        else { state.researchCandidates() }
                    }
                } else if !state.results.isEmpty, filteredResults.isEmpty {
                    ReaderPageState(title: "没有符合筛选的书籍", detail: "清除筛选可查看已有搜索结果。", actionTitle: "清除筛选") { state.sourceFilter = "" }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredResults) { book in
                                Button { focusedSearchField = nil; state.showDetail(book) } label: {
                                    HStack(spacing: 14) {
                                        ReaderBookCover(book: ReaderBook(sourceId: book.sourceId, bookId: book.bookId, title: book.title, coverUrl: book.coverUrl), imageService: state.service as? any ReaderRemoteImageServing).frame(width: 54, height: 76)
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(book.title).font(ReaderTypography.font(.controlHeader)).lineLimit(2)
                                            Text(book.author).font(ReaderTypography.font(.caption))
                                            Text(state.sourceName(book.sourceId)
                                                 + (state.candidateElapsedMilliseconds(book).map { " · \($0) ms" } ?? "")
                                                 + (state.candidateSearchStatus(book).map { " · \($0)" } ?? ""))
                                                .font(ReaderTypography.font(.caption))
                                                .foregroundStyle(ReaderPalette(scheme).muted)
                                                .lineLimit(1)
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
    private func submitSearch(origin: String) {
        #if DEBUG && targetEnvironment(simulator)
        ReaderUIVerificationJournal.record(ReaderUIVerificationJournal.search, "search-submit",
            tags: ["origin": origin], values: ["utf16Length": Double(state.query.utf16.count)],
            flags: ["queryFocused": focusedSearchField == .query])
        #endif
        focusedSearchField = nil
        state.search()
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
                            Button { add(detail, index: chapter.index) } label: {
                                HStack(spacing: 8) {
                                    Text(chapter.displayTitle ?? chapter.title)
                                    Spacer(minLength: 0)
                                    ReaderChapterSourceLabel(isVip: chapter.isVip, isPay: chapter.isPay)
                                }
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
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
    @ObservedObject private var actions: ReaderLibraryActionOwner
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @StateObject private var draftOwner: ReaderSourceEditorDraftOwner
    @State private var link = ""
    @State private var importFile = false
    @State private var fileRead: ReaderSourceEditorDraftOwner.ReadRequest?
    @State private var fileReadTask: Task<Void, Never>?
    @State private var exportFile = false
    @State private var exportData = ReaderSourceJSONDocument(data: Data())
    @State private var importResults: [ReaderSourceImportItem] = []
    @State private var filter = ""
    @State private var login: ReaderSourceLoginPresentation?
    @State private var diagnostic = ""
    @State private var subscriptionPage = false
    @State private var diagnosticGeneration = UUID()
    @State private var debugSource: ReaderSourceDebugPresentation?
    @State private var validating = false
    @Environment(\.colorScheme) private var scheme
    init(state: ReaderOnlineWorkspaceModel) {
        self.state = state
        _actions = ObservedObject(wrappedValue: state.actions)
        _draftOwner = StateObject(wrappedValue: ReaderSourceEditorDraftOwner(actions: state.actions))
    }
    // The source rows are persisted-read projections. Expose their read identity
    // together with the same write owner, so AX consumers cannot classify a
    // stale toggle value as a terminal mutation or a successful refresh.
    private var sourceListState: String {
        let read = state.sourceLoading ? "loading" : state.sourceReadFailure == nil ? "ready" : "failed"
        let operation = actions.busy ? "busy" : actions.hasPending ? "pending" : "terminal"
        return "\(state.sourceReadRevision)|\(read)|\(operation)|\(actions.pendingOperationID ?? "")"
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
                    .accessibilityIdentifier("online-source-state:" + sourceListState)
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
                            Button("调试") {
                                debugSource?.owner.retire()
                                debugSource = ReaderSourceDebugPresentation(source: source)
                            }
                            Button("网页登录") { login = ReaderSourceLoginPresentation(source: source) }
                                .accessibilityIdentifier("online-source-login:" + source.id)
                            Spacer()
                            Button("删除", role: .destructive) { confirmation.confirm("删除书源？", message: "已有书籍与缓存保留，后续联网将需要重新导入此书源。", actionTitle: "删除", destructive: true) { mutate("删除书源") { id in try await state.service?.deleteSource(source.id, operationID: id) } } }
                        }.font(ReaderTypography.font(.caption))
                    }.padding(16).background(ReaderPalette(scheme).card, in: RoundedRectangle(cornerRadius: 16))
                }
                if !diagnostic.isEmpty { Text(diagnostic).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
            }.padding(20)
        }.accessibilityIdentifier("online-source-scroll")
            .readerConfirmation(confirmation)
            .disabled(actions.busy)
            .onAppear { draftOwner.activate(); restoreSaveIfNeeded() }
            .onDisappear {
                fileReadTask?.cancel(); fileReadTask = nil
                draftOwner.retire(); confirmation.request = nil; fileRead = nil
                diagnosticGeneration = UUID(); validating = false
            }
            .onChange(of: link) { _, _ in
                fileReadTask?.cancel(); fileReadTask = nil; fileRead = nil
                draftOwner.cancelRead()
            }
            .onChange(of: state.sourceLoading) { _, loading in if !loading { restoreSaveIfNeeded() } }
            .onChange(of: draftOwner.editorGeneration) { _, _ in
                validating = false
                if let request = fileRead, !draftOwner.accepts(request) {
                    fileReadTask?.cancel(); fileReadTask = nil; fileRead = nil
                }
            }
            .onChange(of: confirmation.request?.id) { _, id in if id == nil { draftOwner.dismissConfirmation() } }
            .onChange(of: actions.hasPending) { _, pending in
                if pending {
                    fileReadTask?.cancel(); fileReadTask = nil; fileRead = nil
                    confirmation.request = nil; draftOwner.dismissConfirmation(); draftOwner.cancelRead()
                }
                else { restoreSaveIfNeeded() }
            }
            .onChange(of: actions.busy) { _, busy in if !busy { draftOwner.refreshPersistedDraft() } }
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
            .sheet(item: $login) { request in
                ReaderSourceLogin(source: request.source, service: state.service, lifetime: request.lifetime) {
                    guard login?.id == request.id else { return }
                    request.lifetime.retire(); login = nil
                }.id(request.id)
            }
            .sheet(item: $debugSource) { request in
                if let service = state.service {
                    ReaderSourceDebugPanel(source: request.source, service: service, owner: request.owner) {
                        guard debugSource?.id == request.id else { return }
                        request.owner.retire(); debugSource = nil
                    }.id(request.id)
                }
            }
            .sheet(isPresented: $subscriptionPage, onDismiss: { Task { await state.loadSources() } }) {
                if let service = state.service as? any ReaderRuleSubscriptionServing { ReaderRuleSubscriptionPanel(service: service) }
            }
            .fileImporter(isPresented: $importFile, allowedContentTypes: [.json, .plainText]) { result in
                guard let fileRequest, draftOwner.accepts(fileRequest) else { return }
                do {
                    let url = try result.get()
                    fileReadTask?.cancel()
                    fileReadTask = Task {
                        defer { if fileRead == fileRequest { fileRead = nil; fileReadTask = nil } }
                        do {
                            let text = try await ReaderSourcePackageInput.readUTF8File(at: url)
                            guard !Task.isCancelled, fileRead == fileRequest, draftOwner.accepts(fileRequest) else { return }
                            receive(draftOwner.finishRead(fileRequest, target: .imported(text, label: "导入文件“\(url.lastPathComponent)”")))
                        } catch {
                            guard !Task.isCancelled, fileRead == fileRequest, draftOwner.accepts(fileRequest) else { return }
                            draftOwner.cancelRead(); state.error = error.localizedDescription
                        }
                    }
                } catch {
                    if fileRead == fileRequest { fileRead = nil }
                    draftOwner.cancelRead(); state.error = error.localizedDescription
                }
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
        fileReadTask?.cancel(); fileReadTask = nil
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
        draftOwner.performRead(request, operation: {
            let result = try await service.onlineFetch(url)
            let text = try ReaderSourcePackageInput.decodeUTF8(result)
            return .imported(text, label: "导入链接中的书源")
        }, completion: receive, failure: { state.error = $0.localizedDescription })
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

/// Ephemeral presentation/readiness only. Native CookieJar/Keychain remain the
/// credential owner; accepted original writes are never cancelled here.
@MainActor
final class ReaderSourceLoginLifetime {
    struct Ticket: Equatable {
        let id: UUID
        let presentationID: UUID
        let sourceID: String
    }
    let presentationID: UUID
    let sourceID: String
    private var active = true
    private var preparation: Ticket?
    private var prepared = false
    private var cookieSeed: Ticket?
    private var seedReady = false
    private var save: Ticket?
    private var credentialWriteDispatched = false

    init(presentationID: UUID = UUID(), sourceID: String) {
        self.presentationID = presentationID; self.sourceID = sourceID
    }
    private func ticket() -> Ticket {
        .init(id: UUID(), presentationID: presentationID, sourceID: sourceID)
    }
    private func belongs(_ token: Ticket) -> Bool {
        token.presentationID == presentationID && token.sourceID == sourceID
    }
    func beginPreparation() -> Ticket? {
        guard active, save == nil else { return nil }
        prepared = false; cookieSeed = nil; seedReady = false
        let token = ticket(); preparation = token; return token
    }
    func finishPreparation(_ token: Ticket) -> Bool {
        guard active, belongs(token), preparation == token else { return false }
        preparation = nil; prepared = true; return true
    }
    func acceptsPreparation(_ token: Ticket) -> Bool {
        active && belongs(token) && preparation == token
    }
    func beginCookieSeed() -> Ticket? {
        guard active, prepared, save == nil else { return nil }
        seedReady = false
        let token = ticket(); cookieSeed = token; return token
    }
    func acceptsCookieSeed(_ token: Ticket) -> Bool {
        active && belongs(token) && cookieSeed == token
    }
    func finishCookieSeed(_ token: Ticket) -> Bool {
        guard acceptsCookieSeed(token) else { return false }
        cookieSeed = nil; seedReady = true; return true
    }
    var canSave: Bool { active && seedReady && save == nil }
    func beginSave() -> Ticket? {
        guard canSave else { return nil }
        let token = ticket(); save = token; credentialWriteDispatched = false; return token
    }
    func beginCredentialWrite(_ token: Ticket) -> Bool {
        guard active, belongs(token), save == token, !credentialWriteDispatched else { return false }
        credentialWriteDispatched = true; return true
    }
    /// Clear only this exact completion. False means no UI or navigation right.
    func finishSave(_ token: Ticket) -> Bool {
        guard belongs(token), save == token else { return false }
        save = nil; credentialWriteDispatched = false
        return active
    }
    func retire() {
        active = false; preparation = nil; prepared = false; cookieSeed = nil; seedReady = false
        // Keep the accepted save ticket for its exact completion; no write replay
        // or cancellation, and no authority to publish after this presentation.
    }
}

enum ReaderSourceLoginURL {
    static func resolve(definition: Data, baseURL: String) -> URL? {
        guard let raw = (try? JSONSerialization.jsonObject(with: definition)) as? [String: Any] else { return nil }
        let declared = (raw["loginUrl"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let address = declared.isEmpty ? baseURL.trimmingCharacters(in: .whitespacesAndNewlines) : declared
        let resolved: URL?
        if let absolute = URL(string: address), absolute.scheme != nil {
            resolved = absolute
        } else {
            guard let base = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
                  ["http", "https"].contains(base.scheme?.lowercased() ?? ""),
                  let host = base.host, !host.isEmpty,
                  let relative = URL(string: address, encodingInvalidCharacters: false) else { return nil }
            // Foundation resolves the original source's relative declaration;
            // strict parsing keeps non-URL login scripts/text out of this path.
            resolved = URL(string: relative.relativeString, relativeTo: base)?.absoluteURL
        }
        guard let url = resolved, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}

private struct ReaderSourceLoginPresentation: Identifiable {
    let id: UUID
    let source: ReaderOnlineSource
    let lifetime: ReaderSourceLoginLifetime
    @MainActor init(source: ReaderOnlineSource) {
        let id = UUID(); self.id = id; self.source = source
        lifetime = ReaderSourceLoginLifetime(presentationID: id, sourceID: source.id)
    }
}

private struct ReaderSourceLogin: View {
    let source: ReaderOnlineSource
    let service: (any ReaderOnlineServing)?
    let lifetime: ReaderSourceLoginLifetime
    let closePresentation: () -> Void
    @State private var webView: WKWebView?
    @State private var cookies: [HTTPCookie]?
    @State private var failure: String?
    @State private var saving = false
    var body: some View {
        VStack {
            HStack {
                Button("关闭") { close() }.accessibilityIdentifier("online-source-login-close")
                Spacer()
                Text(source.name).accessibilityIdentifier("online-source-login-title:" + source.id)
                Spacer()
                Button("完成登录") { save() }.disabled(service == nil || webView == nil || saving || !lifetime.canSave)
            }.padding()
            if let cookies, let loginURL {
                if let failure { ReaderPageState(title: "登录状态未能保存", detail: failure) }
                ReaderSourceLoginWebView(url: loginURL, cookies: cookies, lifetime: lifetime, webView: $webView)
            }
            else if let failure {
                ReaderPageState(title: "网页登录未完成", detail: failure, actionTitle: "重试") {
                    Task { await prepare() }
                }
            }
            else { ReaderPageState(title: "正在准备来源登录", loading: true) }
        }.task { await prepare() }.onDisappear { lifetime.retire() }
    }
    private func prepare() async {
        guard cookies == nil, let token = lifetime.beginPreparation() else { return }
        failure = nil
        guard let service else {
            failure = "来源登录服务尚未准备"
            return
        }
        guard loginURL != nil else {
            failure = "此书源没有可用的 HTTP/HTTPS 网页登录地址"
            return
        }
        do {
            let original = try await service.prepareLogin(token.sourceID)
            guard !Task.isCancelled, lifetime.finishPreparation(token) else { return }
            cookies = original
        } catch {
            guard !Task.isCancelled, lifetime.acceptsPreparation(token) else { return }
            failure = error.localizedDescription
        }
    }
    private var loginURL: URL? {
        ReaderSourceLoginURL.resolve(definition: source.definition, baseURL: source.baseURL)
    }
    private func close() {
        lifetime.retire(); closePresentation()
    }
    private func save() {
        guard let webView else { return }
        guard let service else {
            failure = "来源登录服务尚未准备"
            return
        }
        guard !saving, let token = lifetime.beginSave() else { return }
        saving = true; failure = nil
        let originalCookies = cookies ?? []
        Task {
            let updatedCookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            // This is still a read until the original exact-source write is
            // dispatched. A retired snapshot must not start a new credential write.
            guard lifetime.beginCredentialWrite(token) else { _ = lifetime.finishSave(token); return }
            do {
                try await service.completeLogin(token.sourceID, cookies: updatedCookies, originalCookies: originalCookies)
                guard lifetime.finishSave(token) else { return }
                saving = false; close()
            } catch {
                guard lifetime.finishSave(token) else { return }
                failure = error.localizedDescription; saving = false
            }
        }
    }
}
private struct ReaderSourceLoginWebView: UIViewRepresentable {
    let url: URL
    let cookies: [HTTPCookie]
    let lifetime: ReaderSourceLoginLifetime
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
            guard coordinator.active, !Task.isCancelled, let token = lifetime.beginCookieSeed() else { return }
            for cookie in cookies {
                await config.websiteDataStore.httpCookieStore.setCookie(cookie)
                guard coordinator.active, !Task.isCancelled, lifetime.acceptsCookieSeed(token) else { return }
            }
            guard coordinator.active, !Task.isCancelled, lifetime.finishCookieSeed(token) else { return }
            // Savable publication happens only after every original native seed.
            webView = view
            view.load(URLRequest(url: url))
        }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) { }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.active = false; coordinator.setup?.cancel(); coordinator.setup = nil; view.stopLoading()
    }
}
