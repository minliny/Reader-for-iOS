import Foundation
import Observation
import ReaderCoreBridge
import ReaderDesign
import ReaderHost
import SwiftUI

struct OnlineBookDetailScreen: View {
    let reference: OnlineBookReference
    let session: M2AppSession
    let files: FileAndAssetHost
    let refreshShelf: () async -> Void
    var remove: ((BookIdentity) async -> Bool)? = nil

    @State private var model = OnlineBookDetailModel()
    @State private var route: Route?
    @State private var directory = false
    @State private var initialTarget: M2DirectoryTargetResolveParamsV2?
    @State private var confirmation: ReaderConfirmation?
    @State private var removalTarget: BookIdentity?
    @State private var actionGeneration = 0
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var dismiss
    @State private var toast = ReaderToastPresenter()

    private enum Route: Hashable {
        case reading(chapter: Int64? = nil, switchOnOpen: Bool = false)
        case downloads
    }

    private var online: OnlineReadingCoordinator { .init(runtime: session.sources.runtime) }

    var body: some View {
        detailBody
            .navigationTitle("书籍详情")
            .navigationBarTitleDisplayMode(.inline)
            .readerNavigationBar()
            .navigationDestination(item: $route) { target in routeBody(target) }
            .sheet(isPresented: $directory) { directoryBody }
            .task { await load() }
            .overlay(alignment: .bottom) { feedbackBody }
            .readerConfirmation($confirmation, onConfirm: removeConfirmed)
    }

    @ViewBuilder private var detailBody: some View {
        if let book = model.book {
            let removal: (() -> Void)? = model.shelfBook != nil && remove != nil ? { confirmRemoval() } : nil
            OnlineBookDetailContent(
                book: book, onAdd: add, onRead: openReading, onSwitch: openSwitch,
                onDownloads: { route = .downloads }, onDirectory: { directory = true },
                onRefresh: { Task { await load(refresh: true) } }, onRemove: removal,
                isShelved: model.shelfBook != nil, busy: model.writing, network: session.sources.network
            )
        } else {
            PageState(state: model.state) { expected in
                guard expected == model.generation else { return }
                Task { await load() }
            }
        }
    }

    @ViewBuilder private func routeBody(_ target: Route) -> some View {
        switch target {
        case .reading(let chapter, let switchOnOpen):
            if let book = model.book, book.isManga {
                MangaReadingScreen(book: book, session: session, initialChapter: chapter, showSwitch: switchOnOpen,
                                   onBookChanged: { model.retarget($0) }, onExit: readerExited)
            } else if let entry = model.readerEntry {
                let context = OnlineReadingContext(session: session, switchOnOpen: switchOnOpen,
                    initialTarget: initialTarget, onBookChanged: { current in model.retarget(current) })
                ReadingScreen(book: entry, chapters: [], original: nil, runtime: online.runtime, files: files,
                              startChapter: chapter, onlineContext: context, onExit: readerExited)
            }
        case .downloads:
            if let book = model.book {
                if book.isManga { MangaDownloadScreen(session: session, book: book) }
                else { DownloadManagementScreen(session: session, book: book) }
            }
        }
    }

    @ViewBuilder private var directoryBody: some View {
        if let book = model.book {
            OnlineDirectorySheet(book: book, online: online, selected: model.shelfBook?.currentChapterIndex,
                refresh: { await model.loadDirectory(online: online) },
                onSelect: { target, _, _ in try await openDirectoryTarget(target) })
        }
    }

    @ViewBuilder private var feedbackBody: some View {
        if let message = toast.message, phase == .active, route == nil, !directory {
            TransientToast(message: message).padding(CGFloat(ReaderDesignMetrics.spaceMedium))
        }
    }

    private func readerExited() async {
        await load()
        await refreshShelf()
    }

    private func openDirectoryTarget(_ target: M2DirectoryTargetResolveParamsV2) async throws {
        let resolved = try await online.resolveTarget(target)
        initialTarget = target
        directory = false
        route = .reading(chapter: resolved.chapterIndex)
    }

    private func openReading() {
        initialTarget = nil
        route = .reading()
    }

    private func removeConfirmed(_ generation: Int) {
        guard generation == actionGeneration, phase == .active, let remove,
              let target = removalTarget, model.shelfBook.map(BookIdentity.init) == target else { return }
        Task {
            if await remove(target) { dismiss() }
            else { await load() }
        }
    }

    private func load(refresh: Bool = false) async {
        let loaded = await model.load(reference, online: online)
        if !loaded, refresh, model.book != nil {
            feedback("详情刷新失败，已保留原内容", key: "detail-refresh")
        }
    }

    private func add() {
        Task {
            switch await model.add(online: online, network: session.sources.network) {
            case .added:
                await refreshShelf()
                feedback("已加入书架", key: "shelf-add")
            case .addedReadbackPending:
                await refreshShelf()
                feedback("已加入书架，详情暂未更新", key: "shelf-add-readback")
            case .failed:
                feedback("暂时无法加入书架", key: "shelf-add-failed")
            }
        }
    }

    private func openSwitch() {
        guard model.shelfBook != nil else {
            feedback("加入书架后可以切换书源", key: "switch-needs-shelf")
            return
        }
        initialTarget = nil
        route = .reading(switchOnOpen: true)
    }

    private func confirmRemoval() {
        guard let entry = model.shelfBook else { return }
        removalTarget = BookIdentity(entry)
        actionGeneration += 1
        confirmation = ReaderConfirmation(title: "移出书架？", message: "《\(entry.title)》将从书架移除。",
                                          confirmTitle: "移除", generation: actionGeneration)
    }

    private func feedback(_ message: String, key: String) {
        toast.show(message: message, key: key, feedbackEnabled: route == nil && !directory, sceneActive: phase == .active)
    }
}

@MainActor
@Observable
final class OnlineBookDetailModel {
    enum AddResult { case added, addedReadbackPending, failed }
    private(set) var book: OnlineBookReference?
    private(set) var shelfBook: BookshelfEntryData?
    private(set) var detail: M2BookDetailData?
    private(set) var state = ReaderPageState.loading
    private(set) var generation = 0
    private(set) var writing = false
    private var activeBook: OnlineBookReference?

    var readerEntry: BookshelfEntryData? {
        if let shelfBook { return shelfBook }
        guard let book else { return nil }
        // A preview uses the verified Core detail as its render projection.
        // Shelf membership remains a separate Core write.
        return .init(sourceName: book.sourceName, sourceId: book.sourceId, bookId: book.bookId,
                     title: book.title, author: book.author ?? "", coverUrl: book.coverURL, intro: book.intro,
                     kind: book.kind, lastChapter: book.lastChapter, addedAt: 0, sortIndex: 0, contentKind: .text)
    }

    func retarget(_ target: OnlineBookReference) {
        activeBook = target
        generation += 1
        book = target
        shelfBook = nil
        detail = nil
    }

    func load(_ initial: OnlineBookReference, online: OnlineReadingCoordinator) async -> Bool {
        let requested = activeBook ?? initial
        generation += 1
        let observed = generation
        if book == nil { state = .loading }
        if let result = try? await online.runtime.request(ReaderM1.bookshelfGet, requested.shelfQuery).value,
           generation == observed {
            shelfBook = result.book
            if book == nil, let entry = result.book {
                book = .init(shelfBook: entry)
            }
        }
        do {
            let result = try await online.detail(requested.detailParams)
            guard generation == observed else { return false }
            detail = result
            book = .init(detail: result, sourceName: shelfBook?.sourceName ?? requested.sourceName)
            return true
        } catch {
            guard generation == observed else { return false }
            if book == nil { state = .failed("暂时无法打开书籍详情。", actionGeneration: observed) }
            return false
        }
    }

    func add(online: OnlineReadingCoordinator, network: NetworkAndWebHost? = nil) async -> AddResult {
        guard !writing, let detail, let book, shelfBook == nil else { return .failed }
        writing = true
        defer { writing = false }
        let observed = generation
        do {
            if book.isManga {
                guard let network else { return .failed }
                try await MangaShelfAdmission.add(detail: detail, runtime: online.runtime, network: network)
            } else {
                _ = try await online.addToShelf(detail)
            }
        } catch {
            return .failed
        }
        guard generation == observed else { return .addedReadbackPending }
        do {
            shelfBook = try await online.runtime.request(ReaderM1.bookshelfGet, book.shelfQuery).value.book
            return shelfBook != nil ? .added : .addedReadbackPending
        } catch {
            return .addedReadbackPending
        }
    }

    func loadDirectory(online: OnlineReadingCoordinator) async -> Bool {
        guard let book else { return false }
        do {
            let current: M2BookDetailData
            if let detail { current = detail }
            else { current = try await online.detail(book.detailParams) }
            _ = try await online.refreshDirectory(.init(sourceId: book.sourceId, bookId: book.bookId,
                                                       tocUrl: current.tocUrl, variables: current.variables))
            return true
        } catch { return false }
    }
}
