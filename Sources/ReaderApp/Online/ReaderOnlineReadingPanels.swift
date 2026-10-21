import SwiftUI

/// Bounded presentation cache: candidates/query/timing survive closing the
/// switch sheet. Core remains the owner of books, catalogs and transactions.
@MainActor final class ReaderSwitchPresentationCache {
    static let shared = ReaderSwitchPresentationCache()
    private var states: [String: ReaderOnlineWorkspaceModel] = [:]
    private var order: [String] = []
    func state(for identity: String, initialQuery: String) -> ReaderOnlineWorkspaceModel {
        if let state = states[identity] { return state }
        let state = ReaderOnlineWorkspaceModel(); state.query = initialQuery
        states[identity] = state; order.append(identity)
        while order.count > 8 {
            let evicted = order.removeFirst()
            states.removeValue(forKey: evicted)?.retireCachedDiscovery()
        }
        return state
    }
}

struct ReaderOnlineSwitchPanel: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var preferences: ReaderPreferences
    let session: ReaderActiveSession
    @StateObject private var state: ReaderOnlineWorkspaceModel
    @State private var discoveryPresentationID = UUID()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    init(model: ReaderApplicationModel, preferences: ReaderPreferences, session: ReaderActiveSession) {
        self.model = model; self.preferences = preferences; self.session = session
        _state = StateObject(wrappedValue: ReaderSwitchPresentationCache.shared.state(for: session.book.id, initialQuery: session.book.title))
    }
    var body: some View {
        let presentationID = discoveryPresentationID
        VStack(spacing: 12) {
            HStack {
                Button("关闭") { dismiss() }.accessibilityIdentifier("online-switch-close")
                Spacer()
                Text("切换书源").font(ReaderTypography.font(.controlHeader))
                    .accessibilityIdentifier("online-switch-owner:\(model.actions.busy ? "busy" : model.actions.hasPending ? "pending" : "settled")")
                Spacer()
                Button(state.searching ? "停止" : "重新搜索") { if state.searching { state.stop() } else { state.researchCandidates() } }
            }.padding(.horizontal, 20)
            HStack { TextField("书名或作者", text: $state.query).readerField(); Button("搜索", action: state.researchCandidates) }.padding(.horizontal, 20)
            Text("当前：\(session.book.sourceName ?? state.sourceName(session.book.sourceId))").font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(scheme).muted)
            if state.searching { ProgressView("正在查找其他来源") }
            if !state.failures.isEmpty { Text("\(state.failures.count) 个来源未完成").font(ReaderTypography.font(.caption)) }
            if candidates.isEmpty, !state.searching {
                emptyCandidates
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(candidates) { candidate in
                            Button {
                                Task {
                                    if await model.actions.perform("切换书源", scope: session.book.id, action: { id in
                                        try await model.switchOnlineSource(candidate, operationID: id)
                                    }) { dismiss() }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(candidate.title).font(ReaderTypography.font(.controlHeader))
                                        Text(candidate.author).font(ReaderTypography.font(.caption))
                                        Text(state.sourceName(candidate.sourceId) + (state.timings[candidate.sourceId].map { " · \($0) ms" } ?? "")).font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(scheme).muted)
                                        if !state.currentResultIDs.contains(candidate.id) { Text(state.searching ? "上次候选 · 本次搜索中" : "上次候选 · 本次未确认").font(ReaderTypography.font(.caption)) }
                                    }
                                    Spacer(); ReaderIcon(.chevronRight)
                                }.padding(18).contentShape(Rectangle())
                            }.buttonStyle(ReaderPressFeedback()).disabled(model.actions.hasPending)
                                .id(candidate.id)
                                .accessibilityIdentifier("online-switch-candidate:" + candidate.id)
                            Divider()
                        }
                    }.scrollTargetLayout()
                }.scrollPosition(id: Binding(get: { state.scrollAnchor }, set: { id in
                    if let id, candidates.contains(where: { $0.id == id }) { state.scrollAnchor = id }
                }))
            }
            ReaderOnlineSourceRefreshNotice(state: state)
            ReaderOperationStatus(owner: model.actions, scope: session.book.id)
                .accessibilityIdentifier("online-switch-outcome")
        }.padding(.vertical, 20).background(ReaderPalette(scheme).paper)
            .task {
                guard !Task.isCancelled else { return }
                state.activateDiscoveryPresentation(presentationID)
                state.service = model.libraryService as? any ReaderOnlineServing
                await state.refreshDiscoverySources(presentationID: presentationID)
            }
            .onDisappear { state.retireDiscoveryPresentation(presentationID) }
    }
    @ViewBuilder private var emptyCandidates: some View {
        if state.sourceLoading {
            ReaderPageState(title: "正在加载书源", loading: true)
        } else if state.sources.allSatisfy({ !$0.enabled }) {
            ReaderPageState(title: state.sourceReadFailure == nil ? "还没有启用的书源" : "书源加载失败", detail: state.sourceReadFailure ?? "可在书源管理中启用书源，已有正文和阅读位置保留。", actionTitle: state.sourceReadFailure == nil ? nil : "重试") {
                let presentationID = discoveryPresentationID
                Task { await state.refreshDiscoverySources(presentationID: presentationID) }
            }
        } else if state.stopped {
            ReaderPageState(title: "查找已停止", detail: "已有正文和阅读位置保留，可重新搜索。", actionTitle: "重新搜索", action: state.researchCandidates)
        } else if !state.failures.isEmpty {
            ReaderPageState(title: state.timings.isEmpty ? "查找来源失败" : "部分来源未完成", detail: "尚不能确认没有其他来源，已有正文和阅读位置保留。", actionTitle: "重新搜索", action: state.researchCandidates)
        } else if !state.searched || state.timings.isEmpty {
            ReaderPageState(title: "尚未取得来源结果", detail: "已有正文和阅读位置保留，可重新搜索。", actionTitle: "重新搜索", action: state.researchCandidates)
        } else {
            ReaderPageState(title: "没有其他来源", detail: "已有正文和阅读位置保留，可重新搜索。", actionTitle: "重新搜索", action: state.researchCandidates)
        }
    }
    private var candidates: [ReaderOnlineCandidate] { state.results.filter { $0.id != session.book.id } }
}

struct ReaderOnlineDownloadPanel: View {
    @ObservedObject var model: ReaderApplicationModel
    let session: ReaderActiveSession
    @StateObject private var downloadActions = ReaderDownloadControlOwner()
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @State private var status: ReaderDownloadStatus?
    @State private var storage: ReaderStorageSummary?
    @State private var start = "1"
    @State private var end = "1"
    @State private var failure: String?
    @State private var selected = Set<UInt32>()
    @State private var updatingCatalog = false
    @State private var catalogFeedback: String?
    @State private var batchFeedback: String?
    @State private var catalogGeneration = UUID()
    @State private var catalogTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    private var service: (any ReaderDownloadServing)? { model.libraryService as? any ReaderDownloadServing }
    var body: some View {
        VStack(spacing: 14) {
            HStack { Button("关闭") { dismiss() }.accessibilityIdentifier("online-download-close"); Spacer(); Text("下载管理").font(ReaderTypography.font(.controlHeader)); Spacer(); Button("刷新") { Task { await refresh() } } }.padding(.horizontal, 20)
            Button(updatingCatalog ? "正在取得目录" : "更新在线目录") { updateCatalog() }.disabled(model.actions.hasPending || updatingCatalog)
                .accessibilityIdentifier("online-update-catalog")
            if let catalogFeedback { Text(catalogFeedback).font(ReaderTypography.font(.caption)).accessibilityIdentifier("online-catalog-feedback") }
            if let status {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        Text(session.book.title).font(ReaderTypography.font(.controlHeader))
                        Text("已完成 \(status.completedCount) · 缓存 \(status.cachedCount) · 失败 \(status.failedCount) · 暂停 \(status.pausedCount)").font(ReaderTypography.font(.caption))
                        HStack { TextField("起章", text: $start).keyboardType(.numberPad).readerField(); Text("至"); TextField("末章", text: $end).keyboardType(.numberPad).readerField(); Button("下载") { downloadRange() } }
                        HStack { Button("整本下载") { download(0..<status.chapterCount) }; Spacer(); Button("下载所选") { downloadSelected() }.disabled(selected.isEmpty).accessibilityIdentifier("online-download-selected") }.disabled(model.actions.hasPending)
                        if let batchFeedback { Text(batchFeedback).font(ReaderTypography.font(.caption)) }
                        Text("阅读前后章缓存与主动下载分别记账。清理自动缓存保留已完成下载及当前章。").font(ReaderTypography.font(.caption))
                        if let storage {
                            Text("可清理自动正文 \(ByteCountFormatter.string(fromByteCount: Int64(clamping: storage.cleanableBytes), countStyle: .file))").font(ReaderTypography.font(.caption))
                            Button("清理自动缓存") { confirmation.confirm("清理自动缓存？", message: "保留当前章和已完成下载；书架、阅读位置及原书不变。", actionTitle: "清理") { cleanup() } }.disabled(model.actions.hasPending)
                        }
                        ForEach(status.chapters) { chapter in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Toggle(isOn: Binding(get: { selected.contains(chapter.chapterIndex) }, set: { value in if value { selected.insert(chapter.chapterIndex) } else { selected.remove(chapter.chapterIndex) } })) { Text(chapter.title) }.toggleStyle(.button)
                                        .accessibilityIdentifier("online-download-select:" + session.book.id + ":" + String(chapter.chapterIndex))
                                    Spacer(); Text(label(chapter.state)).font(ReaderTypography.font(.caption))
                                        .accessibilityIdentifier("online-download-state:" + session.book.id + ":" + String(chapter.chapterIndex))
                                }
                                if let error = chapter.lastError { Text(error).font(ReaderTypography.font(.caption)) }
                                HStack {
                                    if [.queued, .inProgress].contains(chapter.state) {
                                        Button("暂停") { task(chapter, action: .pause) }
                                            .disabled(!downloadActions.canControl)
                                            .accessibilityIdentifier("online-download-pause:" + session.book.id + ":" + String(chapter.chapterIndex))
                                    }
                                    if [.paused, .failed, .cancelled].contains(chapter.state) {
                                        Button(chapter.state == .failed ? "重试" : "继续") { task(chapter, action: .resume) }
                                            .disabled(!downloadActions.canResume)
                                            .accessibilityIdentifier("online-download-resume:" + session.book.id + ":" + String(chapter.chapterIndex))
                                    }
                                    if [.queued, .inProgress, .paused].contains(chapter.state) {
                                        Button("取消任务") { task(chapter, action: .cancel) }
                                            .disabled(!downloadActions.canControl)
                                            .accessibilityIdentifier("online-download-cancel:" + session.book.id + ":" + String(chapter.chapterIndex))
                                    }
                                    if chapter.chapterIndex != session.content.chapterIndex,
                                       [.cached, .completed, .failed, .cancelled, .paused].contains(chapter.state) {
                                        Button("清除此章下载") {
                                            confirmation.confirm("清除此章下载？", message: "删除此章缓存正文、下载任务及对应图片副本。书架、目录和阅读位置保留。", actionTitle: "清除") {
                                                clearChapter(chapter)
                                            }
                                        }
                                        .disabled(!downloadActions.canClear)
                                    }
                                }.font(ReaderTypography.font(.caption))
                            }.padding(.vertical, 8)
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("online-download-attempt:" + session.book.id + ":" + String(chapter.chapterIndex) + ":" + String(chapter.attempts))
                            Divider()
                        }
                    }.padding(20)
                }.accessibilityIdentifier("online-download-scroll")
            } else { ReaderPageState(title: failure == nil ? "正在加载下载状态" : "下载状态不可用", detail: failure ?? "", loading: failure == nil) }
            if let failure, status != nil { ReaderPageState(title: "下载管理未完成", detail: failure).padding(.horizontal, 20) }
            ReaderOperationStatus(owner: model.actions, scope: session.book.id)
            ReaderOperationStatus(owner: downloadActions.resumeActions, scope: session.book.id)
            ReaderOperationStatus(owner: downloadActions.controlActions, scope: session.book.id)
        }.padding(.vertical, 20).readerConfirmation(confirmation)
            .task(id: phase) {
                guard phase == .active else { return }
                await refresh()
                while !Task.isCancelled { try? await Task.sleep(nanoseconds: 2_000_000_000); if !Task.isCancelled { await refresh() } }
            }
            .onChange(of: phase) { value in if value != .active { cancelCatalogRead() } }
            .onDisappear { cancelCatalogRead() }
    }
    private func refresh() async {
        guard let service else { return }
        do {
            let value = try await service.readerDownloadStatus(session.book)
            try Task.checkCancellation(); status = value
            if end == "1" { end = String(value.chapterCount) }
            storage = try await service.readerStorageSummary(protected: [.init(book: session.book, chapterIndex: session.content.chapterIndex)])
            failure = nil
        } catch is CancellationError { } catch { failure = error.localizedDescription }
    }
    private func updateCatalog() {
        guard !updatingCatalog, model.libraryService is any ReaderOnlineServing else { return }
        let generation = UUID(); catalogGeneration = generation
        updatingCatalog = true; catalogFeedback = nil
        catalogTask = Task {
            do {
                let detail = try await model.refreshOnlineCatalog(sessionID: session.id, bookID: session.book.id)
                try Task.checkCancellation()
                guard catalogGeneration == generation else { return }
                catalogFeedback = "已取得目录，共 \(detail.chapters.count) 章"
                await refresh()
            } catch is CancellationError { } catch {
                guard !Task.isCancelled, catalogGeneration == generation else { return }
                failure = error.localizedDescription
            }
            guard catalogGeneration == generation else { return }
            updatingCatalog = false; catalogTask = nil
        }
    }
    private func cancelCatalogRead() {
        catalogTask?.cancel(); catalogTask = nil; catalogGeneration = UUID(); updatingCatalog = false
    }
    private func downloadRange() {
        guard let lower = UInt32(start), let upper = UInt32(end), lower > 0, upper >= lower, let status, upper <= status.chapterCount else { failure = "请输入目录范围内的起止章节"; return }
        download((lower - 1)..<upper)
    }
    private func download(_ range: Range<UInt32>) {
        guard let service, !range.isEmpty else { return }
        Task { _ = await model.actions.perform("下载章节", scope: session.book.id) { id in _ = try await service.downloadChapters(session.book, range: range, operationID: id) }; await refresh() }
    }
    private func downloadSelected() {
        guard let service else { return }; let indexes = selected.sorted()
        Task {
            var completed = 0
            for index in indexes where index < UInt32.max {
                // Each accepted chapter has its own real operation owner.
                // Stop at an unresolved write and retain the remaining selection.
                let confirmed = await model.actions.perform("下载所选章节", scope: session.book.id) { id in
                    _ = try await service.downloadChapters(session.book, range: index..<(index + 1), operationID: id)
                }
                guard confirmed else {
                    batchFeedback = "已处理 \(completed) 章，其余 \(indexes.count - completed) 章未完成；所选章节保留。"
                    await refresh(); return
                }
                completed += 1
            }
            batchFeedback = "已处理 \(completed) 章，具体完成或失败状态见下方列表。"
            await refresh()
        }
    }
    private enum TaskAction { case pause, resume, cancel }
    private func task(_ chapter: ReaderDownloadChapter, action: TaskAction) {
        guard let service else { return }
        Task {
            let operation: (String) async throws -> Void = { id in
                switch action {
                case .pause: _ = try await service.pauseDownload(session.book, chapterIndex: chapter.chapterIndex, operationID: id)
                case .resume: _ = try await service.resumeDownload(session.book, chapterIndex: chapter.chapterIndex, operationID: id)
                case .cancel: _ = try await service.cancelDownload(session.book, chapterIndex: chapter.chapterIndex, operationID: id)
                }
            }
            switch action {
            case .resume: _ = await downloadActions.performResume(scope: session.book.id, action: operation)
            case .pause, .cancel: _ = await downloadActions.performControl(scope: session.book.id, action: operation)
            }
            await refresh()
        }
    }
    private func cleanup() {
        guard let service else { return }
        Task { _ = await model.actions.perform("清理缓存", scope: session.book.id) { id in
            storage = try await service.cleanupReaderStorage(retained: [], protected: [.init(book: session.book, chapterIndex: session.content.chapterIndex)], operationID: id)
        }; await refresh() }
    }
    private func clearChapter(_ chapter: ReaderDownloadChapter) {
        guard let service, chapter.chapterIndex != session.content.chapterIndex else { return }
        Task {
            _ = await downloadActions.performClear(scope: session.book.id) { id in
                try await service.clearDownloadedChapter(session.book, chapterIndex: chapter.chapterIndex, operationID: id)
            }
            await refresh()
        }
    }
    private func label(_ state: ReaderDownloadChapterState) -> String {
        switch state {
        case .missing: return "未下载"; case .queued: return "排队中"; case .paused: return "已暂停"; case .inProgress: return "下载中"
        case .cached: return "阅读缓存"; case .completed: return "已完成"; case .failed: return "失败"; case .cancelled: return "已取消"
        }
    }
}
