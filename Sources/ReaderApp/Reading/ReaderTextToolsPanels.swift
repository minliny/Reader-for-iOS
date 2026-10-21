import SwiftUI

@MainActor
final class ReaderTextToolsState: ObservableObject {
    @Published var query = ""
    @Published var submitted = ""
    @Published var requested = ""
    @Published var results: [ReaderContentSearchHit] = []
    @Published var searchLoading = false
    @Published var searchFailure: String?
    @Published var hasMore = false
    @Published var notes: [ReaderHighlight] = []
    @Published var noteQuery = ""
    @Published var note = ""
    @Published var editingNote: ReaderHighlight?
    @Published var notesFailure: String?
    @Published var notesLoading = false
    var searchGeneration = UUID()
    var notesGeneration = UUID()
    var searchTask: Task<Void, Never>?
    var returnPosition: (ReaderContentPositionScope, UInt64)?
}

struct ReaderContentSearchPanel: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var state: ReaderTextToolsState
    let book: ReaderBook
    @Environment(\.colorScheme) private var scheme
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
            if let failure = state.searchFailure {
                ReaderPageState(title: state.results.isEmpty ? "正文搜索尚未完成" : "本次搜索尚未完成，保留原结果",
                                detail: failure, actionTitle: "重试") {
                    search(more: !state.results.isEmpty && state.requested == state.submitted)
                }
            }
            if state.searchLoading, state.results.isEmpty { ReaderPageState(title: "正在搜索正文", loading: true) }
            else if state.results.isEmpty, !state.submitted.isEmpty, state.searchFailure == nil {
                ReaderPageState(title: "没有找到匹配正文")
            } else {
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
                            }.buttonStyle(ReaderPressFeedback()).accessibilityIdentifier("content-hit-\(result.id)")
                        }
                        if state.hasMore {
                            Button("更多结果") { search(more: true) }.frame(minHeight: 44).disabled(state.searchLoading)
                        }
                    }
                }
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
    }
    private func stop() {
        state.searchGeneration = UUID(); state.searchTask?.cancel(); state.searchTask = nil; state.searchLoading = false
    }
    private func search(more: Bool) {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        let query = more ? state.submitted : state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        stop()
        let generation = UUID(); state.searchGeneration = generation
        let offset = more ? state.results.count : 0
        state.requested = query; state.searchLoading = true; state.searchFailure = nil
        state.searchTask = Task {
            do {
                let page = try await service.searchContent(for: book, keyword: query, limit: 100, offset: UInt32(clamping: offset))
                guard state.searchGeneration == generation, !Task.isCancelled else { return }
                state.submitted = query
                state.results = more ? state.results + page.results : page.results
                state.hasMore = page.hasMore
            } catch {
                guard state.searchGeneration == generation, !Task.isCancelled else { return }
                state.searchFailure = error.localizedDescription
            }
            if state.searchGeneration == generation { state.searchLoading = false }
        }
    }
}

struct ReaderAnnotationsPanel: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var state: ReaderTextToolsState
    let book: ReaderBook
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @Environment(\.colorScheme) private var scheme
    var body: some View {
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
                                    Spacer()
                                    Button("删除", role: .destructive) {
                                        confirmation.confirm("删除笔记", message: mark.chapterName,
                                            actionTitle: "删除", destructive: true) { remove(mark) }
                                    }
                                }.frame(minHeight: 44)
                            }.padding(12).background(ReaderPalette(scheme).readElevated, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }.font(ReaderTypography.font(.caption)).padding(10)
            .task(id: "\(book.id)|\(state.noteQuery)") { await load() }
            .onChange(of: model.actions.hasPending) { old, new in if old && !new { Task { await load() } } }
            .readerConfirmation(confirmation)
    }
    private func load() async {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        let query = state.noteQuery
        let generation = UUID(); state.notesGeneration = generation
        state.notesLoading = true
        defer { if generation == state.notesGeneration { state.notesLoading = false } }
        do {
            let values = try await service.highlights(for: book, query: query)
            guard generation == state.notesGeneration, !Task.isCancelled else { return }
            state.notes = values; state.notesFailure = nil
        } catch { if generation == state.notesGeneration, !Task.isCancelled { state.notesFailure = error.localizedDescription } }
    }
    private func save() {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        let note = state.note
        let editing = state.editingNote
        let selected = model.selection
        let session = model.reader
        Task {
            let success = await model.actions.perform("保存笔记", scope: book.id) { id in
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
            if success {
                if state.editingNote?.id == editing?.id, state.note == note { state.editingNote = nil; state.note = "" }
                await load(); await model.reloadHighlights()
            }
        }
    }
    private func remove(_ mark: ReaderHighlight) {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        Task {
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
