import SwiftUI

@MainActor
final class ReaderBookmarkState: ObservableObject {
    @Published var bookmarks: [ReaderBookmark] = []
    @Published var query = ""
    @Published var loading = true
    @Published var failure: String?
    @Published var note = ""
    @Published var editing: ReaderBookmark?
    var generation = UUID()
    @Published var anchor: String?
}

struct ReaderBookmarkPanel: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var state: ReaderBookmarkState
    let book: ReaderBook
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
                                    Spacer()
                                    Button("删除", role: .destructive) {
                                        confirmation.confirm("删除书签", message: bookmark.chapterName,
                                            actionTitle: "删除", destructive: true) { remove(bookmark) }
                                    }
                                }.font(ReaderTypography.font(.caption)).frame(minHeight: 44)
                            }.padding(12).background(ReaderPalette(scheme).readElevated, in: RoundedRectangle(cornerRadius: 8)).id(String(describing: bookmark.id))
                        }
                    }.scrollTargetLayout()
                }.scrollPosition(id: $state.anchor, anchor: .top)
            }
        }.font(ReaderTypography.font(.caption)).padding(8)
            .task(id: "\(book.id)|\(state.query)") { await load() }
            .onChange(of: model.actions.hasPending) { old, new in if old && !new { Task { await load() } } }
            .readerConfirmation(confirmation)
    }
    private func load() async {
        guard let feature = model.libraryService as? any ReaderLibraryFeatures else { state.loading = false; return }
        let expected = state.query
        let generation = UUID(); state.generation = generation
        state.loading = true
        defer { if generation == state.generation { state.loading = false } }
        do {
            let result = try await feature.bookmarks(for: book, query: expected)
            guard generation == state.generation else { return }
            state.bookmarks = result; state.failure = nil
        } catch { if generation == state.generation { state.failure = error.localizedDescription } }
    }
    private func remove(_ bookmark: ReaderBookmark) {
        guard let feature = model.libraryService as? any ReaderLibraryFeatures else { return }
        Task {
            if await model.actions.perform("删除书签", scope: book.id, action: { id in
                try await feature.deleteBookmark(bookmark, operationID: id)
            }) { await load() }
        }
    }
    private func saveNote(_ bookmark: ReaderBookmark) {
        guard let feature = model.libraryService as? any ReaderLibraryFeatures else { return }
        let text = state.note
        Task {
            if await model.actions.perform("保存备注", scope: book.id, action: { id in
                _ = try await feature.updateBookmark(bookmark, note: text, operationID: id)
            }) {
                if state.editing?.id == bookmark.id, state.note == text { state.editing = nil; state.note = "" }
                await load()
            }
        }
    }
}
