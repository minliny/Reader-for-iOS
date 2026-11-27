import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct OnlineDirectorySheet: View {
    let book: OnlineBookReference
    let online: OnlineReadingCoordinator
    let selected: Int64?
    let refresh: () async -> Bool
    let onSelect: (M2DirectoryTargetResolveParamsV2, Int64, String) async throws -> Void

    @State private var view: M2DirectoryViewOpenDataV2?
    @State private var nodes: [M2DirectoryViewNodeV2] = []
    @State private var collapsed = Set<String>()
    @State private var nextOffset: Int64?
    @State private var busy = false
    @State private var state = ReaderPageState.loading
    @State private var generation = 0
    @State private var toast = ReaderToastPresenter()
    @Environment(\.readerTheme) private var theme
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if nodes.isEmpty {
                    PageState(state: state) { expected in
                        guard expected == generation else { return }
                        Task { await reload(force: true) }
                    }
                } else {
                    content
                }
            }
            .background(theme.background)
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .readerNavigationBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await reload(force: true) } } label: { ReaderIcon(ReaderIconRegistry.refresh) }
                        .accessibilityLabel("刷新在线目录")
                        .accessibilityIdentifier("m2-directory-refresh")
                        .disabled(busy)
                }
            }
            .overlay(alignment: .bottom) {
                if let message = toast.message, phase == .active {
                    TransientToast(message: message).padding(CGFloat(ReaderDesignMetrics.spaceMedium))
                }
            }
            .task { await reload(force: false, allowFirstFetch: true) }
            .onDisappear {
                generation += 1
                toast.dismiss()
            }
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(nodes, id: \.nodeId) { node in
                    Button { act(node) } label: {
                        HStack(spacing: CGFloat(ReaderDesignMetrics.controlInlineSpacing)) {
                            if node.kind == .group {
                                ReaderIcon(node.expanded ? ReaderIconRegistry.collapse : ReaderIconRegistry.expand)
                            }
                            Text(node.displayTitle ?? node.title)
                                .readerTypography(ReaderDesignMetrics.rowLabel)
                                .lineLimit(2)
                            Spacer()
                            if let index = node.chapterIndex, index == selected {
                                ReaderIcon(ReaderIconRegistry.check).foregroundStyle(theme.accent)
                            }
                        }
                        .foregroundStyle(node.chapterIndex != nil && node.chapterIndex == selected ? theme.accent : theme.primaryText)
                        .padding(.leading, CGFloat(min(4, max(0, node.depth))) * CGFloat(ReaderDesignMetrics.controlInlineSpacing))
                        .frame(minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(node.kind == .disabled || busy)
                    .accessibilityIdentifier(node.chapterIndex.map { "directory-chapter-\($0)" } ?? "directory-group-\(node.nodeId)")
                    Divider()
                }
                if nextOffset != nil {
                    Button("继续加载目录") { Task { await loadMore() } }
                        .readerTypography(ReaderDesignMetrics.rowLabel)
                        .padding(.vertical, CGFloat(ReaderDesignMetrics.spaceSmall))
                        .disabled(busy)
                }
            }
            .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
        }
    }

    private func fetch() async throws -> M2DirectoryViewOpenDataV2 {
        let value = try await online.openDirectory(.init(bookId: book.bookId, collapsedNodeIds: collapsed.sorted(),
            chapterIndex: selected, limit: 100, sourceId: book.sourceId))
        guard value.status == .ready, value.sourceId == book.sourceId, value.bookId == book.bookId,
              value.viewId != nil, value.catalogRevision != nil, value.structureRevision != nil,
              value.nodes != nil else { throw OnlineReadingCoordinator.Failure.directoryUnavailable }
        return value
    }

    private func reload(force: Bool, allowFirstFetch: Bool = false) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        generation += 1
        let current = generation
        if nodes.isEmpty { state = .loading }
        do {
            if force, !(await refresh()) { throw OnlineReadingCoordinator.Failure.directoryUnavailable }
            let result: M2DirectoryViewOpenDataV2
            do { result = try await fetch() }
            catch {
                guard allowFirstFetch, await refresh() else { throw error }
                result = try await fetch()
            }
            guard current == generation else { return }
            view = result
            nodes = result.nodes ?? []
            nextOffset = result.nextOffset
            if nodes.isEmpty { state = .empty("目录没有可读章节") }
        } catch {
            guard current == generation else { return }
            if nodes.isEmpty { state = .failed("暂时无法读取在线目录。", actionGeneration: current) }
            else { feedback("目录刷新失败，已保留原目录", key: "directory-refresh") }
        }
    }

    private func loadMore() async {
        guard !busy, let nextOffset, let proof = projection else { return }
        busy = true
        defer { busy = false }
        let current = generation
        do {
            let result = try await online.pageDirectory(.init(bookId: book.bookId, viewId: proof.view,
                offset: nextOffset, limit: 100, sourceId: book.sourceId, catalogRevision: proof.catalog,
                structureRevision: proof.structure))
            guard current == generation, result.viewId == proof.view, result.sourceId == book.sourceId,
                  result.bookId == book.bookId, result.catalogRevision == proof.catalog,
                  result.structureRevision == proof.structure else { return }
            nodes += result.nodes
            self.nextOffset = result.nextOffset
        } catch {
            if current == generation { feedback("加载下一段目录失败", key: "directory-next") }
        }
    }

    private var projection: (view: String, catalog: String, structure: String)? {
        guard let id = view?.viewId, let catalog = view?.catalogRevision, let structure = view?.structureRevision
        else { return nil }
        return (id, catalog, structure)
    }

    private func act(_ node: M2DirectoryViewNodeV2) {
        if node.kind == .group {
            if node.expanded { collapsed.insert(node.nodeId) }
            else { collapsed.remove(node.nodeId) }
            Task { await reload(force: false) }
        } else if node.kind == .target, let proof = projection, let index = node.chapterIndex {
            let params = M2DirectoryTargetResolveParamsV2(bookId: book.bookId, viewId: proof.view, nodeId: node.nodeId,
                sourceId: book.sourceId, catalogRevision: proof.catalog, structureRevision: proof.structure)
            busy = true
            let current = generation
            Task {
                defer { busy = false }
                do { try await onSelect(params, index, node.title) }
                catch {
                    if generation == current { feedback("该目录项已变更，请刷新后重试", key: "directory-target") }
                }
            }
        }
    }

    private func feedback(_ message: String, key: String) {
        toast.show(message: message, key: key, feedbackEnabled: true, sceneActive: phase == .active)
    }
}
