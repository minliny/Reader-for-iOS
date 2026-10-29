import SwiftUI
import Combine

@MainActor
final class ReaderTextToolsState: ObservableObject {
    struct SearchRequest: Equatable {
        let book: ReaderBook
        let keyword: String
        let limit: UInt32
        let cursor: String?
        let append: Bool
        static func == (lhs: Self, rhs: Self) -> Bool {
            SearchIdentity(lhs.book) == SearchIdentity(rhs.book) && lhs.keyword.utf8.elementsEqual(rhs.keyword.utf8)
                && lhs.limit == rhs.limit && (lhs.cursor.map { Data($0.utf8) }) == (rhs.cursor.map { Data($0.utf8) })
                && lhs.append == rhs.append
        }
    }
    private struct SearchIdentity: Equatable {
        let source: Data
        let book: Data
        init(_ book: ReaderBook) { source = Data(book.sourceId.utf8); self.book = Data(book.bookId.utf8) }
    }
    private final class SearchLease { var retired = false }
    typealias Search = @MainActor (ReaderBook, String, UInt32, String?) async throws -> ReaderContentSearchPage
    typealias CloseSearch = @MainActor (ReaderBook, String, String) async throws -> Void
    struct NoteContext: Equatable {
        let sessionID: UUID
        let restorationID: UUID
        let bookID: String
        let chapterIndex: UInt32
        let bodyVersion: String?
        let processingVersion: String?
        let selection: ReaderTextSelection?

        init(session: ReaderActiveSession, selection: ReaderTextSelection?) {
            sessionID = session.id; restorationID = session.restorationID; bookID = session.book.id
            chapterIndex = session.content.chapterIndex; bodyVersion = session.content.bodyVersion
            processingVersion = session.content.processingVersion; self.selection = selection
        }
    }
    struct NoteDraft {
        let presentation: UUID
        let revision: UUID
        let context: NoteContext
        let note: String
        let editing: ReaderHighlight?
    }
    struct NoteReadKey: Hashable {
        let source: Data
        let book: Data
        let query: Data
        let readerEpoch: UUID
        init(book: ReaderBook, query: String, readerEpoch: UUID) {
            source = Data(book.sourceId.utf8); self.book = Data(book.bookId.utf8)
            self.query = Data(query.utf8); self.readerEpoch = readerEpoch
        }
    }
    private struct NoteReadContext: Equatable {
        let session: UUID
        let restoration: UUID
        let source: Data
        let book: Data
        init(_ session: ReaderActiveSession) {
            self.session = session.id; restoration = session.restorationID
            source = Data(session.book.sourceId.utf8); book = Data(session.book.bookId.utf8)
        }
    }
    @Published var query = "" { didSet { if !query.utf8.elementsEqual(oldValue.utf8) { retireSearch() } } }
    @Published var submitted = ""
    @Published var requested = ""
    @Published var results: [ReaderContentSearchHit] = []
    @Published var searchLoading = false
    @Published var searchFailure: String?
    @Published private(set) var searchRequiresRestart = false
    @Published var hasMore = false
    @Published var notes: [ReaderHighlight] = []
    @Published var noteQuery = "" {
        didSet { if !noteQuery.utf8.elementsEqual(oldValue.utf8) { retireNoteRead() } }
    }
    @Published var note = "" { didSet { noteRevision = UUID() } }
    @Published var editingNote: ReaderHighlight? { didSet { noteRevision = UUID() } }
    @Published var notesFailure: String?
    @Published var notesLoading = false
    var searchGeneration = UUID()
    var notesGeneration = UUID()
    var searchTask: Task<Void, Never>?
    private(set) var searchRetirementTask: Task<Void, Never>?
    private(set) var nextSearchCursor: String?
    private var searchIdentity: SearchIdentity?
    private var confirmedSearch: SearchRequest?
    private var cursorCloser: CloseSearch?
    private var activeSearchLease: SearchLease?
    var returnPosition: (ReaderContentPositionScope, UInt64)?
    private(set) var failedSearchRequest: SearchRequest?
    private var noteRevision = UUID()
    private var notePresentation = UUID()
    private var notesActive = false
    private var noteContext: NoteContext?
    private var noteObservation: AnyCancellable?
    @Published private(set) var noteReadEpoch = UUID()
    private var noteReadContext: NoteReadContext?
    private var noteReadTask: Task<Void, Never>?

    deinit { noteReadTask?.cancel() }

    /// Retire only the current read. Confirmed results and return position stay
    /// available; the Runtime owns cancellation and exact reply retirement.
    func cancelSearch() {
        searchGeneration = UUID()
        searchTask?.cancel()
        searchTask = nil
        searchLoading = false
    }

    /// Discard the continuation capability, not the confirmed rows/return
    /// position. A stopped read alone keeps its last confirmed cursor.
    func retireSearch() {
        activeSearchLease?.retired = true
        cancelSearch()
        let hadContinuation = nextSearchCursor != nil || failedSearchRequest?.cursor != nil
        closeKnownSearch()
        if failedSearchRequest?.cursor != nil { failedSearchRequest = nil }
        if hadContinuation {
            searchRequiresRestart = true
            searchFailure = "搜索已结束，原结果已保留，请重新搜索以读取更多结果"
        }
    }

    private func closeKnownSearch() {
        if let cursor = nextSearchCursor, let request = confirmedSearch, let close = cursorCloser {
            closeSearch(request, cursor: cursor, using: close)
        }
        nextSearchCursor = nil; hasMore = false
    }

    private func closeSearch(_ request: SearchRequest, cursor: String, using close: @escaping CloseSearch) {
        let previous = searchRetirementTask
        searchRetirementTask = Task {
            await previous?.value
            // Cleanup never converts a failed search into success. Core also
            // bounds sessions by TTL if this best-effort read cannot finish.
            try? await close(request.book, request.keyword, cursor)
        }
    }

    func startSearch(for book: ReaderBook, using service: any ReaderReadingToolsServing, more: Bool) {
        startSearch(for: book, more: more, close: { book, keyword, cursor in
            try await service.closeContentSearch(for: book, keyword: keyword, cursor: cursor)
        }) { book, keyword, limit, cursor in
            try await service.searchContent(for: book, keyword: keyword, limit: limit, cursor: cursor)
        }
    }

    func retrySearch(for book: ReaderBook, using service: any ReaderReadingToolsServing) {
        retrySearch(for: book, close: { book, keyword, cursor in
            try await service.closeContentSearch(for: book, keyword: keyword, cursor: cursor)
        }) { book, keyword, limit, cursor in
            try await service.searchContent(for: book, keyword: keyword, limit: limit, cursor: cursor)
        }
    }

    func startSearch(for book: ReaderBook, more: Bool, close: CloseSearch? = nil, search: @escaping Search) {
        let identity = SearchIdentity(book)
        if let old = searchIdentity, old != identity {
            retireSearch(); results = []; submitted = ""; requested = ""; returnPosition = nil; failedSearchRequest = nil
            searchFailure = nil; searchRequiresRestart = false
        }
        searchIdentity = identity
        let query = more ? submitted : self.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        guard !more || (hasMore && nextSearchCursor != nil && confirmedSearch.map { SearchIdentity($0.book) == identity } == true) else { return }
        let request = SearchRequest(book: book, keyword: query, limit: 100,
            cursor: more ? nextSearchCursor : nil, append: more)
        if !more { retireSearch() }
        beginSearch(request, close: close, search: search)
    }

    func retrySearch(for book: ReaderBook, close: CloseSearch? = nil, search: @escaping Search) {
        guard let request = failedSearchRequest, SearchIdentity(request.book) == SearchIdentity(book), !searchRequiresRestart else { return }
        beginSearch(request, close: close, search: search)
    }

    private func beginSearch(_ request: SearchRequest, close: CloseSearch?, search: @escaping Search) {
        cancelSearch()
        let generation = UUID(); searchGeneration = generation
        let lease = SearchLease(); activeSearchLease = lease
        // The previous known session must receive its cleanup result before a
        // fresh initial request competes for Core's bounded cursor slots. This
        // does not prove an old in-flight worker has released its reservation.
        let retirement = request.cursor == nil ? searchRetirementTask : nil
        requested = request.keyword; searchLoading = true; searchFailure = nil; failedSearchRequest = nil; searchRequiresRestart = false
        // The in-flight Core read owns its book/service. It must not retain the
        // departed presentation state while waiting for an original terminal.
        searchTask = Task { [weak self] in
            do {
                await retirement?.value
                guard !Task.isCancelled, self?.searchGeneration == generation else { return }
                let page = try await search(request.book, request.keyword, request.limit, request.cursor)
                guard let self, self.searchGeneration == generation, !Task.isCancelled else {
                    // A stopped initial request has no confirmed cursor to
                    // retain. A stopped More request keeps its known session
                    // for exact receipt retry unless the owner was retired.
                    if lease.retired || request.cursor == nil, let cursor = page.nextCursor, let close {
                        if let self { self.closeSearch(request, cursor: cursor, using: close) }
                        else { Task { try? await close(request.book, request.keyword, cursor) } }
                    }
                    return
                }
                self.submitted = request.keyword
                self.results = request.append ? self.results + page.results : page.results
                self.hasMore = page.hasMore
                self.confirmedSearch = request; self.cursorCloser = close; self.nextSearchCursor = page.nextCursor
                if !page.hasMore, let cursor = request.cursor, let close { self.closeSearch(request, cursor: cursor, using: close) }
            } catch {
                guard let self, self.searchGeneration == generation, !Task.isCancelled else { return }
                if case ReaderLibraryError.core(_, _, _, let reason) = error,
                   reason == "CONTENT_SEARCH_STALE" || reason == "CONTENT_SEARCH_EXPIRED" {
                    self.searchFailure = reason == "CONTENT_SEARCH_EXPIRED"
                        ? "本次搜索会话已失效，原结果已保留，请重新搜索"
                        : "搜索依据已更新，原结果已保留，请重新搜索"
                    self.searchRequiresRestart = true; self.closeKnownSearch()
                } else { self.searchFailure = error.localizedDescription; self.failedSearchRequest = request }
            }
            if let self, self.searchGeneration == generation {
                self.searchLoading = false
                self.searchTask = nil
                self.activeSearchLease = nil
            }
        }
    }

    func observeNotes(in model: ReaderApplicationModel) {
        activateNotes(session: model.reader, selection: model.selection)
        // Published values arrive synchronously, so selection A -> B -> A
        // invalidates an old ACK even when SwiftUI coalesces view updates.
        noteObservation = Publishers.CombineLatest(model.$reader, model.$selection).sink { [weak self] session, selection in
            self?.updateNoteContext(session: session, selection: selection)
        }
    }

    func activateNotes(session: ReaderActiveSession?, selection: ReaderTextSelection?) {
        noteObservation?.cancel(); noteObservation = nil
        notePresentation = UUID(); notesActive = true
        retireNoteRead()
        updateNoteContext(session: session, selection: selection)
    }

    func updateNoteContext(session: ReaderActiveSession?, selection: ReaderTextSelection?) {
        let readContext = session.map(NoteReadContext.init)
        if readContext != noteReadContext { retireNoteRead(); noteReadContext = readContext }
        let context = session.map { NoteContext(session: $0, selection: selection) }
        if context != noteContext { noteRevision = UUID(); noteContext = context }
    }

    func retireNotes() {
        notesActive = false; notePresentation = UUID()
        noteObservation?.cancel(); noteObservation = nil
        retireNoteRead(); noteReadContext = nil
    }

    private func retireNoteRead() {
        noteReadEpoch = UUID(); notesGeneration = UUID()
        noteReadTask?.cancel(); noteReadTask = nil; notesLoading = false
    }

    @discardableResult
    func readNotes(for book: ReaderBook, read: @escaping @MainActor (ReaderBook, String) async throws -> [ReaderHighlight]) -> Task<Void, Never>? {
        let input = NoteReadKey(book: book, query: noteQuery, readerEpoch: noteReadEpoch)
        guard notesActive, let context = noteReadContext,
              context.source == input.source, context.book == input.book else { return nil }
        noteReadTask?.cancel()
        let generation = UUID(); notesGeneration = generation
        let presentation = notePresentation, query = noteQuery
        notesLoading = true; notesFailure = nil
        let task = Task { [weak self] in
            defer {
                if let self, self.notesGeneration == generation { self.notesLoading = false; self.noteReadTask = nil }
            }
            do {
                let values = try await read(book, query)
                guard let self, !Task.isCancelled,
                      self.acceptsNoteRead(input, context: context, presentation: presentation, generation: generation) else { return }
                self.notes = values; self.notesFailure = nil
            } catch {
                guard let self, !Task.isCancelled,
                      self.acceptsNoteRead(input, context: context, presentation: presentation, generation: generation) else { return }
                self.notesFailure = error.localizedDescription
            }
        }
        noteReadTask = task
        return task
    }

    private func acceptsNoteRead(_ input: NoteReadKey, context: NoteReadContext, presentation: UUID, generation: UUID) -> Bool {
        notesActive && notePresentation == presentation && notesGeneration == generation && noteReadContext == context
            && noteReadEpoch == input.readerEpoch && Data(noteQuery.utf8) == input.query
    }

    func captureNoteDraft(for book: ReaderBook) -> NoteDraft? {
        guard notesActive, let context = noteContext, context.bookID == book.id else { return nil }
        return NoteDraft(presentation: notePresentation, revision: noteRevision, context: context, note: note, editing: editingNote)
    }

    func acceptsNotePresentation(_ captured: NoteDraft) -> Bool {
        notesActive && notePresentation == captured.presentation && noteContext?.sessionID == captured.context.sessionID
            && noteContext?.bookID == captured.context.bookID
    }

    func finishNoteSave(_ captured: NoteDraft) {
        guard acceptsNotePresentation(captured), noteContext == captured.context, noteRevision == captured.revision,
              note == captured.note, editingNote == captured.editing else { return }
        editingNote = nil; note = ""
    }

    /// Completion belongs to the original action even when its first observer
    /// returned pending. The existing draft guard owns whether input can clear.
    @discardableResult
    func performNoteSave(_ captured: NoteDraft, actions: ReaderLibraryActionOwner, scope: String,
                         refresh: (@MainActor () async -> Void)? = nil,
                         action: @escaping (String) async throws -> Void) async -> Bool {
        await actions.perform("保存笔记", scope: scope, ended: { [weak self] _, confirmed in
            guard confirmed, let self, self.acceptsNotePresentation(captured) else { return }
            self.finishNoteSave(captured)
            if let refresh {
                Task { [weak self] in
                    guard self?.acceptsNotePresentation(captured) == true else { return }
                    await refresh()
                }
            }
        }, action: action)
    }
}

struct ReaderContentSearchPanel: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var state: ReaderTextToolsState
    let book: ReaderBook
    @Environment(\.colorScheme) private var scheme
    @State private var resultToReveal: (generation: UUID, index: Int)?
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("搜索本书正文", text: $state.query).readerField().onSubmit { search(more: false) }
                    .accessibilityIdentifier("content-search-query")
                Button(state.searchLoading ? "停止" : "搜索") {
                    if state.searchLoading { stop() } else { search(more: false) }
                }.frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("content-search-submit")
            }
            if book.sourceId != "local" {
                Text("搜索本书已取得的正文").font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(scheme).muted)
            }
            if !state.results.isEmpty, state.requested != state.submitted {
                Text("保留上次“\(state.submitted)”的结果").font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(scheme).muted)
            }
            if !state.results.isEmpty {
                Text("已显示 \(state.results.count) 条结果")
                    .foregroundStyle(ReaderPalette(scheme).muted)
                    .accessibilityIdentifier("content-search-result-count")
                    .accessibilityValue(String(state.results.count))
            }
            if let failure = state.searchFailure {
                ReaderPageState(title: state.results.isEmpty ? "正文搜索尚未完成" : "本次搜索尚未完成，保留原结果",
                                detail: failure, actionTitle: state.searchRequiresRestart ? "重新搜索" : "重试") {
                    if state.searchRequiresRestart { search(more: false) } else { retry() }
                }
            }
            if state.searchLoading, state.results.isEmpty { ReaderPageState(title: "正在搜索正文", loading: true) }
            else if state.results.isEmpty, !state.submitted.isEmpty, state.searchFailure == nil {
                ReaderPageState(title: "没有找到匹配正文")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(state.results) { result in
                                Button {
                                    guard let scope = result.positionScope else { model.showFeedback("搜索位置缺少版本信息，请重新搜索"); return }
                                    if state.returnPosition == nil, let current = model.reader,
                                       let original = try? ReaderContentPositionScope(book: current.book, content: current.content) {
                                        state.returnPosition = (original, current.scalarOffset)
                                    }
                                    Task { await model.jump(scope: scope, scalarOffset: result.chapterOffset) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(result.chapterTitle).font(ReaderTypography.font(.controlHeader))
                                        Text(result.snippet).font(ReaderTypography.font(.caption)).multilineTextAlignment(.leading)
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                        .background(ReaderPalette(scheme).readElevated, in: RoundedRectangle(cornerRadius: 8))
                                }.buttonStyle(ReaderPressFeedback()).id(result.id)
                                    .accessibilityIdentifier("content-hit-\(result.id)")
                            }
                        }
                    }.accessibilityIdentifier("content-search-results")
                        .onChange(of: state.results) { _, _ in
                            guard let reveal = resultToReveal, reveal.generation == state.searchGeneration,
                                  state.results.indices.contains(reveal.index) else { return }
                            proxy.scrollTo(state.results[reveal.index].id, anchor: .top)
                            resultToReveal = nil
                        }
                }
            }
            if state.hasMore {
                Button("更多结果") { search(more: true) }
                    .frame(maxWidth: .infinity, minHeight: 44).disabled(state.searchLoading)
                    .accessibilityIdentifier("content-search-more")
            }
            if let original = state.returnPosition {
                Button("返回搜索前的位置") {
                    Task {
                        await model.jump(scope: original.0, scalarOffset: original.1)
                        if let current = model.reader, current.scalarOffset == original.1,
                           (try? ReaderContentPositionScope(book: current.book, content: current.content)) == original.0 {
                            state.returnPosition = nil
                        }
                    }
                }.frame(minHeight: 44)
            }
        }.padding(10).font(ReaderTypography.font(.caption))
            .onDisappear { state.retireSearch() }
    }
    private func stop() { resultToReveal = nil; state.cancelSearch() }
    private func search(more: Bool) {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        let index = more ? state.results.count : 0
        state.startSearch(for: book, using: service, more: more)
        resultToReveal = (state.searchGeneration, index)
    }
    private func retry() {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        let index = state.failedSearchRequest?.append == true ? state.results.count : 0
        state.retrySearch(for: book, using: service)
        resultToReveal = (state.searchGeneration, index)
    }
}

struct ReaderAnnotationsPanel: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var state: ReaderTextToolsState
    let book: ReaderBook
    var presentationActive = true
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let readKey = ReaderTextToolsState.NoteReadKey(book: book, query: state.noteQuery, readerEpoch: state.noteReadEpoch)
        VStack(spacing: 8) {
            TextField("搜索笔记", text: $state.noteQuery).readerField()
            if let selected = model.selection, selected.bookId == book.bookId {
                Text(selected.text).font(ReaderTypography.font(.caption)).lineLimit(3)
                    .accessibilityIdentifier("annotation-selected-text")
            }
            TextField("笔记内容", text: $state.note, axis: .vertical).lineLimit(2...5).readerField()
                .accessibilityIdentifier("annotation-note")
            HStack {
                Button(state.editingNote == nil ? "高亮并保存笔记" : "保存笔记") { save() }
                    .disabled(model.actions.hasPending || (state.editingNote == nil && model.selection == nil))
                    .accessibilityIdentifier("save-annotation")
                if state.editingNote != nil { Button("取消编辑") { state.editingNote = nil; state.note = "" } }
            }.frame(minHeight: 44)
            if state.notesLoading, state.notes.isEmpty { ReaderPageState(title: "正在读取笔记", loading: true) }
            else if let failure = state.notesFailure, state.notes.isEmpty {
                ReaderPageState(title: failure, actionTitle: "重试") { Task { await load() } }
            } else if state.notes.isEmpty { ReaderPageState(title: state.noteQuery.isEmpty ? "暂无笔记" : "没有符合条件的笔记") }
            else {
                if let failure = state.notesFailure {
                    ReaderPageState(title: "笔记刷新失败，保留原列表", detail: failure, actionTitle: "重试") { Task { await load() } }
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(state.notes) { mark in
                            VStack(alignment: .leading, spacing: 5) {
                                Button {
                                    guard let scope = mark.positionScope, mark.chapterPos >= 0 else {
                                        model.showFeedback("这条笔记缺少可核对的位置"); return
                                    }
                                    Task { await model.jump(scope: scope, scalarOffset: UInt64(mark.chapterPos)) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(mark.chapterName).font(ReaderTypography.font(.controlHeader))
                                        Text(mark.bookText).lineLimit(3)
                                        Text(mark.note)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.accessibilityIdentifier("annotation-\(mark.id)")
                                HStack {
                                    Button("编辑") { state.editingNote = mark; state.note = mark.note }
                                        .disabled(model.actions.hasPending || state.notesLoading)
                                    Spacer()
                                    Button("删除", role: .destructive) {
                                        guard acceptsRemoval(mark) else { return }
                                        confirmation.confirm("删除笔记", message: mark.chapterName,
                                            actionTitle: "删除", destructive: true) { remove(mark) }
                                    }.disabled(model.actions.hasPending || state.notesLoading)
                                }.frame(minHeight: 44)
                            }.padding(12).background(ReaderPalette(scheme).readElevated, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }.font(ReaderTypography.font(.caption)).padding(10)
            .task(id: readKey) {
                guard readKey == ReaderTextToolsState.NoteReadKey(book: book, query: state.noteQuery, readerEpoch: state.noteReadEpoch) else { return }
                await load()
            }
            .onChange(of: model.actions.hasPending) { old, new in if old && !new { Task { await load() } } }
            .onAppear { if presentationActive { state.observeNotes(in: model) } }
            .onChange(of: presentationActive) { _, active in
                if active {
                    state.observeNotes(in: model)
                } else { state.retireNotes() }
            }
            .onDisappear { state.retireNotes() }
            .readerConfirmation(confirmation)
    }
    private func load() async {
        guard presentationActive, let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        guard let task = state.readNotes(for: book, read: { book, query in
            try await service.highlights(for: book, query: query)
        }) else { return }
        await withTaskCancellationHandler(operation: { await task.value }, onCancel: { task.cancel() })
    }
    private func save() {
        guard let service = model.libraryService as? any ReaderReadingToolsServing,
              let captured = state.captureNoteDraft(for: book) else { return }
        let note = captured.note
        let editing = captured.editing
        let selected = model.selection
        let session = model.reader
        Task {
            await state.performNoteSave(captured, actions: model.actions, scope: book.id, refresh: {
                await load()
                guard state.acceptsNotePresentation(captured) else { return }
                await model.reloadHighlights()
            }) { id in
                if let editing { _ = try await service.updateHighlight(editing, note: note, style: editing.style, operationID: id) }
                else {
                    guard let selected, let session, selected.sourceId == book.sourceId,
                          selected.bookId == book.bookId, selected.chapterIndex == session.content.chapterIndex,
                          selected.bodyVersion == session.content.bodyVersion,
                          selected.processingVersion == session.content.processingVersion else { throw ReaderLibraryError.invalidPosition }
                    _ = try await service.createHighlight(for: book, content: session.content,
                        range: ReaderScalarRange(lowerBound: selected.start, upperBound: selected.end),
                        style: "highlight", note: note, operationID: id)
                }
            }
        }
    }
    private func acceptsRemoval(_ mark: ReaderHighlight) -> Bool {
        guard state.editingNote?.id != mark.id else {
            model.showFeedback("请先保存或取消当前笔记编辑")
            return false
        }
        return true
    }
    private func remove(_ mark: ReaderHighlight) {
        guard acceptsRemoval(mark),
              let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        Task {
            guard acceptsRemoval(mark) else { return }
            if await model.actions.perform("删除笔记", scope: book.id, action: { id in
                _ = try await service.deleteHighlight(mark, operationID: id)
            }) { await load(); await model.reloadHighlights() }
        }
    }
}

struct ReaderReadingRecordPanel: View {
    @ObservedObject var model: ReaderApplicationModel
    @State private var summary: ReaderReadingSummary?
    @State private var failure: String?
    @State private var loadGeneration = UUID()
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let error = model.readingTime.failure {
                    ReaderPageState(title: "阅读时长尚未入账", detail: error, actionTitle: "核对原记录") {
                        Task { await model.readingTime.resumeOriginal(); await load() }
                    }
                }
                if let summary {
                    if let failure {
                        ReaderPageState(title: "阅读记录刷新失败，保留原列表", detail: failure, actionTitle: "重试") { Task { await load() } }
                    }
                    if summary.books.isEmpty { ReaderPageState(title: "暂无阅读记录") }
                    Text("累计阅读 \(summary.totalReadTime / 60_000) 分钟").font(ReaderTypography.font(.controlHeader))
                    ForEach(summary.books) { record in
                        HStack {
                            VStack(alignment: .leading) { Text(record.bookName); Text("\(record.readTime / 60_000) 分钟") }
                            Spacer()
                            Button("清除", role: .destructive) {
                                confirmation.confirm("清除阅读记录", message: "清除《\(record.bookName)》的阅读时长，书籍和位置保留。",
                                    actionTitle: "清除", destructive: true) { remove(record.bookName) }
                            }
                        }.frame(minHeight: 44)
                    }
                } else if let failure { ReaderPageState(title: failure, actionTitle: "重试") { Task { await load() } } }
                else { ReaderPageState(title: "正在读取记录", loading: true) }
            }.font(ReaderTypography.font(.caption)).padding(12)
        }.task { _ = await model.flushReading(); await model.readingTime.flush(); await load() }.readerConfirmation(confirmation)
    }
    private func load() async {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        let generation = UUID(); loadGeneration = generation
        do {
            let value = try await service.readingSummary()
            guard generation == loadGeneration, !Task.isCancelled else { return }
            summary = value; failure = nil
        } catch { if generation == loadGeneration, !Task.isCancelled { failure = error.localizedDescription } }
    }
    private func remove(_ name: String) {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        let scope = model.reader?.book.id ?? "shelf"
        Task {
            if await model.actions.perform("清除记录", scope: scope, action: { id in
                _ = try await service.deleteReadingRecords(bookName: name, operationID: id)
            }) { await load() }
        }
    }
}
