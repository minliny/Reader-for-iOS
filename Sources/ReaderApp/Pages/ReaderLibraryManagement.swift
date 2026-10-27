import SwiftUI

/// Unsaved input belongs to the retained shelf, while each save keeps its
/// original raw fields and revision. A typed ACK cannot clear later edits.
@MainActor
final class ReaderGroupDraftOwner: ObservableObject {
    struct Submission {
        fileprivate let revision: UUID
        let rawName: String
        let editing: ReaderBookGroup?
        var title: String { rawName.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    @Published var name = "" { didSet { revision = UUID() } }
    @Published var editing: ReaderBookGroup? { didSet { revision = UUID() } }
    private var revision = UUID()
    private var presentationID: UUID?

    func activate(_ id: UUID) {
        guard presentationID != id else { return }
        presentationID = id; revision = UUID()
    }
    func retire(_ id: UUID) {
        guard presentationID == id else { return }
        presentationID = nil; revision = UUID()
    }
    func submission() -> Submission { .init(revision: revision, rawName: name, editing: editing) }

    @discardableResult
    func consumeSaved(_ original: Submission) -> Bool {
        guard revision == original.revision, name == original.rawName, editing == original.editing else { return false }
        editing = nil; name = ""
        return true
    }
}

struct ReaderBookManagementView: View {
    @ObservedObject var model: ReaderApplicationModel
    let book: ReaderBook
    let changed: () -> Void
    let close: () -> Void
    @State private var details: ReaderBook?
    @State private var groups: [ReaderBookGroup] = []
    @State private var failure: String?
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @Environment(\.colorScheme) private var scheme
    private var palette: ReaderPalette { ReaderPalette(scheme) }
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("书籍信息").font(ReaderTypography.font(.appTitle))
                Spacer()
                ReaderIconAction(icon: .close, label: "关闭书籍信息", action: close)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text((details ?? book).title).font(ReaderTypography.font(.pageTitle))
                    Text((details ?? book).author).font(ReaderTypography.font(.body)).foregroundStyle(palette.muted)
                    Text("共 \((details ?? book).chapterCount) 章").font(ReaderTypography.font(.caption))
                    Text(book.sourceName ?? (book.sourceId == "local" ? "本地书籍" : "在线书籍"))
                        .font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted)
                    if let intro = (details ?? book).intro, !intro.isEmpty { Text(intro).font(ReaderTypography.font(.body)) }
                    if let failure { ReaderPageState(title: failure, actionTitle: "重试") { Task { await load() } } }
                    Text("分组").font(ReaderTypography.font(.controlHeader))
                    Button("未分组") { assign(nil) }.frame(minHeight: 44)
                    ForEach(groups) { group in
                        Button { assign(group) } label: {
                            HStack {
                                Text(group.groupName)
                                Spacer()
                                if (details ?? book).group == group.groupName { ReaderIcon(.check, size: 18) }
                            }.frame(minHeight: 44)
                        }
                    }
                    Button("移出书架", role: .destructive) {
                        let message = book.sourceId == "local"
                            ? "将《\(book.title)》移出书架，同时清除应用内该书的目录、正文缓存、阅读进度及历史、正文编辑和下载任务。移除成功后清理应用内原书副本。书签、笔记、阅读时长和下载目录原件保留。"
                            : "将《\(book.title)》移出书架。已下载正文、阅读进度、书签、笔记和阅读时长记录保留。"
                        confirmation.confirm("移出书架", message: message,
                            actionTitle: "移除", destructive: true) { remove() }
                    }.frame(minHeight: 44)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            ReaderOperationStatus(owner: model.actions, scope: book.id, completed: { changed(); Task { await load() } })
        }.padding(20).foregroundStyle(palette.ink).background(palette.paper)
            .frame(maxWidth: 720).frame(maxWidth: .infinity).task { await load() }
            .interactiveDismissDisabled(model.actions.busy || model.actions.recovery != nil)
            .readerConfirmation(confirmation)
    }
    private func load() async {
        guard let service = model.libraryService as? any ReaderLibraryFeatures else { return }
        do {
            details = try await service.bookDetails(for: book)
            groups = try await service.groups()
            failure = details == nil ? "这本书已不在书架" : nil
        } catch { failure = error.localizedDescription }
    }
    private func assign(_ group: ReaderBookGroup?) {
        guard let service = model.libraryService as? any ReaderLibraryFeatures else { return }
        Task {
            if await model.actions.perform("保存《\(book.title)》分组", scope: book.id, action: { id in
                _ = try await service.assignGroup(group, to: book, operationID: id)
            }) { changed(); await load() }
        }
    }
    private func remove() {
        guard let service = model.libraryService as? any ReaderLibraryFeatures else { return }
        Task {
            if await model.actions.perform("移出《\(book.title)》", scope: book.id, action: { id in
                _ = try await service.removeBooks([book], operationID: id)
            }) { changed(); close() }
        }
    }
}

struct ReaderGroupManagementView: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var draft: ReaderGroupDraftOwner
    @State private var groups: [ReaderBookGroup] = []
    @State private var presentationID = UUID()
    let close: () -> Void
    @State private var failure: String?
    @State private var loading = true
    @State private var loadGeneration = UUID()
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("管理分组").font(ReaderTypography.font(.appTitle))
                Spacer()
                ReaderIconAction(icon: .close, label: "关闭分组管理", action: close)
            }
            HStack {
                TextField("分组名称", text: $draft.name).readerField().accessibilityIdentifier("group-name")
                Button(draft.editing == nil ? "创建" : "保存") { save() }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.actions.hasPending)
                    .frame(minWidth: 44, minHeight: 44)
                if draft.editing != nil { Button("取消") { draft.editing = nil; draft.name = "" } }
            }
            if let failure { ReaderPageState(title: failure, actionTitle: "重试") { Task { await load() } } }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(groups) { group in
                        HStack {
                            Button(group.groupName) { draft.editing = group; draft.name = group.groupName }
                            Spacer()
                            Button("删除", role: .destructive) {
                                confirmation.confirm("删除分组", message: "删除“\(group.groupName)”，保留书籍和现有分组标签。",
                                    actionTitle: "删除", destructive: true) { remove(group) }
                            }
                        }.frame(minHeight: 44).padding(.horizontal, 12)
                    }
                    if groups.isEmpty, failure == nil {
                        ReaderPageState(title: loading ? "正在读取分组" : "暂无分组", loading: loading)
                    }
                }
            }
            ReaderOperationStatus(owner: model.actions, scope: "shelf", completed: { Task { await load() } })
        }.font(ReaderTypography.font(.body)).padding(20).foregroundStyle(ReaderPalette(scheme).ink)
            .background(ReaderPalette(scheme).paper).task { await load() }
            .onAppear { draft.activate(presentationID) }
            .onDisappear { draft.retire(presentationID) }
            .interactiveDismissDisabled(model.actions.busy || model.actions.recovery != nil).readerConfirmation(confirmation)
    }
    private func load() async {
        guard let service = model.libraryService as? any ReaderLibraryFeatures else { loading = false; failure = "当前阅读服务不支持分组管理"; return }
        let generation = UUID(); loadGeneration = generation; loading = true
        defer { if generation == loadGeneration { loading = false } }
        do {
            let value = try await service.groups()
            guard generation == loadGeneration, !Task.isCancelled else { return }
            groups = value; failure = nil
        } catch { if generation == loadGeneration, !Task.isCancelled { failure = error.localizedDescription } }
    }
    private func save() {
        guard let service = model.libraryService as? any ReaderLibraryFeatures else { return }
        let submitted = draft.submission()
        let title = submitted.title
        let target = submitted.editing
        Task {
            if await model.actions.perform("保存分组", scope: "shelf", action: { id in
                if var group = target { group.groupName = title; _ = try await service.updateGroup(group, operationID: id) }
                else { _ = try await service.createGroup(name: title, operationID: id) }
                // Keep this cleanup inside the original action so its exact
                // retry also checks the first submission, never current input.
                draft.consumeSaved(submitted)
            }) {
                await load(); await model.reloadLibrary()
            }
        }
    }
    private func remove(_ group: ReaderBookGroup) {
        guard let service = model.libraryService as? any ReaderLibraryFeatures else { return }
        Task {
            if await model.actions.perform("删除分组", scope: "shelf", action: { id in
                try await service.deleteGroup(group, operationID: id)
            }) { await load(); await model.reloadLibrary() }
        }
    }
}
