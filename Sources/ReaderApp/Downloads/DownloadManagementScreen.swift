import Foundation
import Observation
import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct DownloadManagementScreen: View {
    let session: M2AppSession
    var book: OnlineBookReference? = nil
    @State private var model = DownloadPanelModel()
    @State private var confirmation: ReaderConfirmation?
    @State private var scopedBook: OnlineBookReference?
    @State private var confirmGeneration = 0
    @State private var isFrontmost = false
    @State private var toast = ReaderToastPresenter()
    @Environment(\.scenePhase) private var phase

    private var runtime: CoreRuntimeActor { session.sources.runtime }
    private var coordinator: DownloadCoordinator { session.downloads }

    var body: some View {
        DownloadManagementContent(books: model.books, storage: model.storage, stage: model.state,
            expandedByDefault: book != nil, onStart: start, onControl: control,
            onStorageCleanup: confirmCleanup, onPrepare: prepareAction, onRetry: { expected in
                guard expected == model.generation else { return }
                Task { await load(includeCatalogue: true, explicit: true) }
            }, network: session.sources.network)
        .navigationTitle("下载管理")
        .navigationBarTitleDisplayMode(.inline)
        .readerNavigationBar()
        .sheet(item: $scopedBook) { current in
            NavigationStack {
                DownloadManagementScreen(session: session, book: current)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("关闭") { scopedBook = nil } }
                    }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await load(includeCatalogue: true, explicit: true) }
                } label: {
                    ReaderIcon(ReaderIconRegistry.refresh)
                }
                .accessibilityLabel("刷新下载状态")
                .accessibilityIdentifier("m2-download-refresh")
            }
        }
        .overlay(alignment: .top) {
            if let pending = model.recovery.first {
                RecoveryNotice(title: "下载任务待核对", message: "按原操作核对《\(pending.title)》的下载结果。",
                    generation: model.recoveryGeneration,
                    action: ReaderRecoveryAction(title: "核对原任务", generation: model.recoveryGeneration),
                    availability: confirmation == nil && scopedBook == nil) { expected, action in
                        guard expected == action, expected == model.recoveryGeneration,
                              isFrontmost, phase == .active else { return }
                        Task { await recover(pending) }
                    }
                    .padding(CGFloat(ReaderDesignMetrics.spaceSmall))
            }
        }
        .overlay(alignment: .bottom) {
            if let message = toast.message, phase == .active, scopedBook == nil {
                TransientToast(message: message).padding(CGFloat(ReaderDesignMetrics.spaceMedium))
            }
        }
        .onAppear { isFrontmost = true }
        .onDisappear {
            isFrontmost = false
            model.retire()
            coordinator.retirePanel()
            toast.dismiss()
        }
        .task(id: phase) {
            guard phase == .active else { toast.dismiss(); return }
            await load(includeCatalogue: true)
            while !Task.isCancelled {
                let running = model.books.contains { $0.active }
                do { try await Task.sleep(for: .seconds(running ? 0.5 : 4)) }
                catch { return }
                guard !Task.isCancelled else { return }
                await load()
            }
        }
        .refreshable { await load(includeCatalogue: true, explicit: true) }
        .readerConfirmation($confirmation) { expected in
            guard expected == confirmGeneration, isFrontmost, phase == .active else { return }
            Task { await cleanup() }
        }
    }

    private var prepareAction: ((OnlineBookReference) -> Void)? {
        guard book == nil else { return nil }
        return { scopedBook = $0 }
    }

    private func start(_ item: DownloadBookPresentation) {
        let eligible = item.chapters.filter { $0.navigable && [.missing, .cached, .failed, .cancelled].contains($0.state) }
        guard let first = eligible.first else { return }
        var upper = first.index + 1
        for chapter in eligible.dropFirst() {
            guard chapter.index == upper else { break }
            upper += 1
        }
        start(item.book, range: [first.index, upper])
    }

    private func start(_ reference: OnlineBookReference, range: [Int64]) {
        do {
            let operation = try coordinator.begin(.init(sourceId: reference.sourceId, bookId: reference.bookId,
                                                        chapterRange: range, contentKind: .text))
            Task { await load() }
            Task {
                let terminal = await operation.result
                await load()
                if case .failure = terminal, !model.recovery.contains(where: { $0.id == reference.id }) {
                    feedback("下载未完成，请查看章节状态", key: "download-terminal")
                }
            }
        } catch {
            feedback("当前下载任务尚未结案", key: "download-busy")
        }
    }

    private func control(_ item: DownloadBookPresentation, _ chapter: DownloadChapterPresentation,
                         _ action: DownloadChapterControl) {
        let reference = item.book
        let params = M2CacheDownloadTaskParams(sourceId: reference.sourceId, bookId: reference.bookId,
                                              chapterIndex: chapter.index)
        Task {
            do {
                switch action {
                case .pause: _ = try await coordinator.pause(params)
                case .cancel: _ = try await coordinator.cancel(params)
                case .resume:
                    _ = try await coordinator.resume(params)
                    if !coordinator.isWorking(sourceId: reference.sourceId, bookId: reference.bookId) {
                        let pending = try coordinator.pendingOperations().contains { $0.sourceId == reference.sourceId && $0.bookId == reference.bookId }
                        if pending { await recover(reference) }
                        else { start(reference, range: [chapter.index, chapter.index + 1]) }
                    }
                }
                await load()
            } catch {
                await load()
                feedback("暂时无法确认\(action.title)结果", key: "download-\(action.rawValue)")
            }
        }
    }

    private func recover(_ reference: OnlineBookReference) async {
        do {
            guard let original = try coordinator.pendingOperations().first(where: {
                $0.sourceId == reference.sourceId && $0.bookId == reference.bookId
            }) else {
                await load()
                return
            }
            _ = try await coordinator.recoverPrefetch(original)
            await load()
        } catch {
            feedback("原下载结果仍待核对", key: "download-recovery")
            await load()
        }
    }

    private func confirmCleanup() {
        confirmGeneration += 1
        confirmation = ReaderConfirmation(title: "清理正文缓存？",
            message: "可清理的在线正文将移除。书架与阅读进度会保留，未保留的章节需要联网重新读取。",
            confirmTitle: "清理", generation: confirmGeneration)
    }

    private func cleanup() async {
        do {
            let result = try await coordinator.cleanup(.init(reason: .clear, contentScope: .text))
            await load()
            if result.cleanupError == nil && !result.hasMore { feedback("缓存清理完成", key: "cache-cleanup") }
            else { feedback("部分缓存尚未清理，可重新核对", key: "cache-incomplete") }
        } catch {
            await load()
            feedback("暂时无法清理正文缓存", key: "cache-cleanup-failure")
        }
    }

    private func load(includeCatalogue: Bool = false, explicit: Bool = false) async {
        guard isFrontmost, phase == .active else { return }
        let loaded = await model.refresh(book: book, runtime: runtime, coordinator: coordinator,
                                         includeCatalogue: includeCatalogue)
        if explicit && !loaded && !model.books.isEmpty {
            feedback("状态刷新未完成，已保留上次结果", key: "download-refresh")
        }
    }

    private func feedback(_ message: String, key: String) {
        toast.show(message: message, key: key, feedbackEnabled: isFrontmost && confirmation == nil && scopedBook == nil,
                   sceneActive: phase == .active)
    }
}

@MainActor
@Observable
final class DownloadPanelModel {
    private(set) var books: [DownloadBookPresentation] = []
    private(set) var storage: M2CacheStorageData?
    private(set) var recovery: [OnlineBookReference] = []
    private(set) var recoveryGeneration = 0
    private(set) var generation = 0
    private(set) var state = ReaderPageState.loading
    private var shelf: [OnlineBookReference] = []
    private var loadedShelf = false
    private var loading = false

    func retire() { generation += 1 }

    @discardableResult
    func refresh(book: OnlineBookReference?, runtime: CoreRuntimeActor, coordinator: DownloadCoordinator,
                 includeCatalogue: Bool) async -> Bool {
        guard !loading else { return true }
        loading = true
        generation += 1
        let expected = generation
        defer { loading = false }
        var fullyRead = true
        do {
            if book == nil, includeCatalogue || !loadedShelf {
                shelf = try await loadShelf(runtime: runtime)
                loadedShelf = true
            } else if let book {
                shelf = [book]
            }
            let pending = try coordinator.pendingOperations()
            async let storageResponse = coordinator.summary(.init(contentScope: .text))
            var requested = shelf
            if book == nil {
                var existing = Set(requested.map(\.id))
                requested.append(contentsOf: pending.compactMap { original in
                    let id = OnlineBookReference.Identity(sourceId: original.sourceId, bookId: original.bookId)
                    guard existing.insert(id).inserted else { return nil }
                    return OnlineBookReference(sourceId: original.sourceId, bookId: original.bookId,
                        title: URL(string: original.bookId)?.lastPathComponent ?? "在线书籍")
                })
            }
            var projections: [DownloadBookPresentation] = []
            for reference in requested {
                guard expected == generation, !Task.isCancelled else { return false }
                let active = coordinator.isWorking(sourceId: reference.sourceId, bookId: reference.bookId)
                let originalPending = !active && pending.contains { $0.sourceId == reference.sourceId && $0.bookId == reference.bookId }
                do {
                    var value = try await coordinator.status(.init(sourceId: reference.sourceId, bookId: reference.bookId,
                                                                      includeGlobalStats: false, includeChapterStates: true))
                    if book != nil, includeCatalogue, !value.tocAvailable {
                        let online = OnlineReadingCoordinator(runtime: runtime)
                        let detail = try await online.detail(reference.detailParams)
                        _ = try await online.refreshDirectory(.init(sourceId: reference.sourceId, bookId: reference.bookId,
                                                                    tocUrl: detail.tocUrl, variables: detail.variables))
                        value = try await coordinator.status(.init(sourceId: reference.sourceId, bookId: reference.bookId,
                                                                     includeGlobalStats: false, includeChapterStates: true))
                    }
                    guard value.sourceId == reference.sourceId, value.bookId == reference.bookId else {
                        throw CoreBridgeFailure.endpointMismatch
                    }
                    let chapters = value.chapters.map { chapter in
                        DownloadChapterPresentation(index: chapter.chapterIndex, title: chapter.displayTitle ?? chapter.title,
                                                    state: chapter.state, navigable: chapter.navigable != false)
                    }
                    projections.append(.init(book: reference, total: Int(value.chapterCount), chapters: chapters,
                                             active: active, recovering: originalPending))
                } catch {
                    fullyRead = false
                    if let previous = books.first(where: { $0.id == reference.id }) { projections.append(previous) }
                }
            }
            let summary = try? await storageResponse
            guard expected == generation, !Task.isCancelled else { return false }
            if let summary { storage = summary } else { fullyRead = false }
            books = projections
            let pendingBooks = projections.filter(\.recovering).map(\.book)
            if pendingBooks.map(\.id) != recovery.map(\.id) {
                recoveryGeneration += 1
                recovery = pendingBooks
            }
            if books.isEmpty {
                state = fullyRead ? .empty("暂没有在线书籍需要下载") :
                    .failed("暂时无法读取下载状态。", actionGeneration: expected)
            }
        } catch {
            guard expected == generation else { return false }
            if books.isEmpty { state = .failed("暂时无法读取下载状态。", actionGeneration: expected) }
            return false
        }
        return fullyRead
    }

    private func loadShelf(runtime: CoreRuntimeActor) async throws -> [OnlineBookReference] {
        var rows: [OnlineBookReference] = []
        var offset: Int64 = 0
        while !Task.isCancelled {
            let page = try await runtime.request(ReaderM1.bookshelfList, .init(
                sourceKind: .online, contentKind: .text, offset: offset, limit: 100
            )).value
            rows += page.books.map(OnlineBookReference.init(shelfBook:))
            offset += Int64(page.books.count)
            if page.books.isEmpty || offset >= page.total { break }
        }
        return rows
    }
}
