import SwiftUI

@MainActor
final class ReaderBookmarkState: ObservableObject {
    struct NoteDraft {
        let presentation: UUID
        let revision: UUID
        let bookmark: ReaderBookmark
        let note: String
    }
    @Published var bookmarks: [ReaderBookmark] = []
    @Published var query = ""
    @Published var loading = true
    @Published var failure: String?
    @Published var note = "" { didSet { noteRevision = UUID() } }
    @Published var editing: ReaderBookmark? { didSet { noteRevision = UUID() } }
    var generation = UUID()
    @Published var anchor: String?
    private var noteRevision = UUID()
    private var presentation = UUID()
    private var active = false

    func activate() { presentation = UUID(); active = true }

    func retire() {
        active = false; presentation = UUID()
        generation = UUID(); loading = false
    }

    func captureNoteDraft(for bookmark: ReaderBookmark) -> NoteDraft? {
        guard active, editing == bookmark else { return nil }
        return NoteDraft(presentation: presentation, revision: noteRevision, bookmark: bookmark, note: note)
    }

    func acceptsNotePresentation(_ captured: NoteDraft) -> Bool {
        active && presentation == captured.presentation
    }

    func finishNoteSave(_ captured: NoteDraft) {
        guard acceptsNotePresentation(captured), noteRevision == captured.revision,
              editing == captured.bookmark, note == captured.note else { return }
        editing = nil; note = ""
    }

    @discardableResult
    func performNoteSave(_ captured: NoteDraft, actions: ReaderLibraryActionOwner, scope: String,
                         refresh: (@MainActor () async -> Void)? = nil,
                         action: @escaping (String) async throws -> Void) async -> Bool {
        await actions.perform("保存备注", scope: scope, ended: { [weak self] _, confirmed in
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

struct ReaderBookmarkPanel: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var state: ReaderBookmarkState
    let book: ReaderBook
    var presentationActive = true
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("搜索书签", text: $state.query).readerField().accessibilityIdentifier("bookmark-query")
                Button("添加书签") { Task { if await model.addBookmark() { await load() } } }
                    .frame(minHeight: 44).disabled(model.actions.hasPending).accessibilityIdentifier("add-bookmark")
            }
            if let target = state.editing {
                HStack {
                    TextField("书签备注", text: $state.note).readerField()
                    Button("保存") { saveNote(target) }.disabled(model.actions.hasPending)
                    Button("取消") { state.editing = nil; state.note = "" }
                }
            }
            if state.loading, state.bookmarks.isEmpty { ReaderPageState(title: "正在读取书签", loading: true) }
            else if let failure = state.failure, state.bookmarks.isEmpty { ReaderPageState(title: failure, actionTitle: "重试") { Task { await load() } } }
            else if state.bookmarks.isEmpty { ReaderPageState(title: state.query.isEmpty ? "暂无书签" : "没有符合条件的书签") }
            else {
                if let failure = state.failure {
                    ReaderPageState(title: "书签刷新失败，保留原列表", detail: failure, actionTitle: "重试") { Task { await load() } }
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(state.bookmarks) { bookmark in
                            VStack(alignment: .leading, spacing: 6) {
                                Button {
                                    guard let scope = bookmark.positionScope else {
                                        model.showFeedback("这个书签缺少可核对的位置，请重新创建"); return
                                    }
                                    Task { await model.jump(scope: scope, scalarOffset: bookmark.scalarOffset) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(bookmark.chapterName).font(ReaderTypography.font(.controlHeader))
                                        Text(bookmark.bookText).font(ReaderTypography.font(.caption)).lineLimit(3)
                                        if !bookmark.content.isEmpty { Text(bookmark.content).font(ReaderTypography.font(.caption)) }
                                    }.frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 44)
                                }.accessibilityIdentifier("bookmark-\(bookmark.id)")
                                HStack {
                                    Button("备注") { state.editing = bookmark; state.note = bookmark.content }
                                        .disabled(model.actions.hasPending || state.loading)
                                    Spacer()
                                    Button("删除", role: .destructive) {
                                        guard acceptsRemoval(bookmark) else { return }
                                        confirmation.confirm("删除书签", message: bookmark.chapterName,
                                            actionTitle: "删除", destructive: true) { remove(bookmark) }
                                    }.disabled(model.actions.hasPending || state.loading)
                                }.font(ReaderTypography.font(.caption)).frame(minHeight: 44)
                            }.padding(12).background(ReaderPalette(scheme).readElevated, in: RoundedRectangle(cornerRadius: 8)).id(String(describing: bookmark.id))
                        }
                    }.scrollTargetLayout()
                }.scrollPosition(id: $state.anchor, anchor: .top)
            }
        }.font(ReaderTypography.font(.caption)).padding(8)
            .task(id: "\(book.id)|\(state.query)") { await load() }
            .onChange(of: model.actions.hasPending) { old, new in if old && !new { Task { await load() } } }
            .onAppear { if presentationActive { state.activate() } }
            .onChange(of: presentationActive) { _, active in
                if active { state.activate(); Task { await load() } }
                else { state.retire() }
            }
            .onDisappear { state.retire() }
            .readerConfirmation(confirmation)
    }
    private func load() async {
        guard presentationActive else { return }
        guard let feature = model.libraryService as? any ReaderLibraryFeatures else { state.loading = false; return }
        let expected = state.query
        let generation = UUID(); state.generation = generation
        state.loading = true
        defer { if generation == state.generation { state.loading = false } }
        do {
            let result = try await feature.bookmarks(for: book, query: expected)
            guard generation == state.generation, !Task.isCancelled else { return }
            state.bookmarks = result; state.failure = nil
        } catch { if generation == state.generation, !Task.isCancelled { state.failure = error.localizedDescription } }
    }
    private func acceptsRemoval(_ bookmark: ReaderBookmark) -> Bool {
        guard state.editing?.id != bookmark.id else {
            model.showFeedback("请先保存或取消当前书签备注")
            return false
        }
        return true
    }
    private func remove(_ bookmark: ReaderBookmark) {
        guard acceptsRemoval(bookmark),
              let feature = model.libraryService as? any ReaderLibraryFeatures else { return }
        Task {
            guard acceptsRemoval(bookmark) else { return }
            if await model.actions.perform("删除书签", scope: book.id, action: { id in
                try await feature.deleteBookmark(bookmark, operationID: id)
            }) { await load() }
        }
    }
    private func saveNote(_ bookmark: ReaderBookmark) {
        guard let feature = model.libraryService as? any ReaderLibraryFeatures,
              let captured = state.captureNoteDraft(for: bookmark) else { return }
        Task {
            await state.performNoteSave(captured, actions: model.actions, scope: book.id, refresh: { await load() }) { id in
                _ = try await feature.updateBookmark(captured.bookmark, note: captured.note, operationID: id)
            }
        }
    }
}
