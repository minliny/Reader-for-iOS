import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct MangaReadingScreen: View {
    @State private var model: MangaScreenModel
    let initialChapter: Int64?
    let showSwitch: Bool
    let onBookChanged: (OnlineBookReference) -> Void
    let onExit: () async -> Void
    @State private var controls = true
    @State private var panel: Panel?
    @State private var chapters: [BookTocEntryData] = []
    @State private var size = CGSize.zero
    @State private var exiting = false
    @AppStorage("reader.manga.direction") private var direction = MangaDirection.vertical
    @AppStorage("reader.manga.paper") private var paper = MangaReadingPaper.paper
    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var dismiss

    private enum Panel: String, Identifiable {
        case directory, sources, downloads
        var id: Self { self }
    }

    init(book: OnlineBookReference, session: M2AppSession, initialChapter: Int64? = nil, showSwitch: Bool = false,
         onBookChanged: @escaping (OnlineBookReference) -> Void, onExit: @escaping () async -> Void) {
        _model = State(initialValue: MangaScreenModel(book: book, session: session))
        self.initialChapter = initialChapter
        self.showSwitch = showSwitch
        self.onBookChanged = onBookChanged
        self.onExit = onExit
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                MangaReadingToolbar(title: model.book.title, chapter: model.chapter?.chapterTitle ?? "漫画阅读",
                    controls: controls, onBack: leave, onControls: { controls.toggle() }, onDirectory: { panel = .directory })
                viewport
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .overlay(alignment: .top) { recovery }
                if controls, let chapter = model.chapter, let page = model.currentOrdinal {
                    MangaReadingDock(page: page + 1, total: chapter.totalPages, direction: direction, paper: paper,
                        onDirection: { direction = $0 }, onPaper: { paper = $0 }, onPage: turn,
                        onLocate: { model.resetPosition() }, onSwitch: { panel = .sources }, onDownload: { panel = .downloads },
                        previousChapter: chapterAction(-1), nextChapter: chapterAction(1))
                        .disabled(model.busy || model.pendingSwitch != nil)
                        .padding(.vertical, 6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: geometry.size, initial: true) { _, value in size = value }
            .task {
                size = geometry.size
                await model.open(chapterIndex: initialChapter, width: pixels)
                await readChapters()
                if showSwitch, model.chapter != nil { panel = .sources }
            }
        }
        .background(paper.colors.background.ignoresSafeArea())
        .readerDesign()
        .environment(\.readerTheme, paper.colors)
        .preferredColorScheme(paper == .ink ? .dark : .light)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .sheet(item: $panel) { selected in sheet(selected) }
        .accessibilityIdentifier("m3-manga-reader")
        .onChange(of: phase) { _, value in
            if value != .active { Task { try? await model.flush() } }
        }
        .onDisappear {
            Task {
                await model.retire()
                if !exiting { await onExit() }
            }
        }
    }

    private var pixels: Int { max(256, Int(size.width * displayScale)) }

    @ViewBuilder private var viewport: some View {
        if let view = model.viewport {
            switch view.frame.content {
            case .image(let image, _):
                MangaPageCanvas(image: image, direction: direction, anchor: model.anchor, anchorRequest: model.anchorRequest,
                                accessibilityPage: "\(view.page.pageId) · \(view.page.ordinal + 1) · \(image.tiles.count) 个切片",
                                onPosition: model.relocate, onPageSwipe: turn)
                    .id(view.page.pageId)
            case .unavailable:
                let height = max(CGFloat(ReaderDesignMetrics.mangaUnknownImageMinHeight),
                                 min(CGFloat(ReaderDesignMetrics.mangaUnknownImageMaxHeight),
                                     size.width * CGFloat(ReaderDesignMetrics.mangaUnknownImageHeightToWidth)))
                MangaUnavailablePage(loading: model.busy, height: height, pageIdentity: view.page.pageId) {
                    Task { await model.retry(width: pixels) }
                }
            }
        } else {
            PageState(state: model.loadFailed ? .failed("暂时无法打开漫画。", actionGeneration: 0) : .loading) { _ in
                Task { await model.open(chapterIndex: initialChapter, width: pixels); await readChapters() }
            }
        }
    }

    @ViewBuilder private var recovery: some View {
        if model.pendingSwitch != nil {
            RecoveryNotice(title: "换源待核对", message: "先核对原操作，再继续阅读。", generation: 0,
                           action: .init(title: "核对换源", generation: 0)) { _, _ in
                Task {
                    if let target = try? await model.reconcileSwitch(width: pixels) {
                        onBookChanged(target)
                        await readChapters()
                    }
                }
            }
            .padding(.horizontal, 12)
        } else if model.coordinator?.recoveryRequired == true {
            RecoveryNotice(title: "位置需要确认", message: "原图位置与当前图源不同。请选择目录重新定位。", generation: 0,
                           action: .init(title: "查看目录", generation: 0)) { _, _ in panel = .directory }
                .padding(.horizontal, 12)
        } else if model.loadFailed, model.viewport != nil {
            RecoveryNotice(title: "漫画操作暂未完成", message: "保留当前图页，请重试或继续阅读。", generation: 0)
                .padding(.horizontal, 12)
        }
    }

    @ViewBuilder private func sheet(_ selected: Panel) -> some View {
        let session = model.session
        let online = OnlineReadingCoordinator(runtime: session.sources.runtime)
        switch selected {
        case .directory:
            OnlineDirectorySheet(book: model.book, online: online, selected: model.chapter?.chapterIndex, refresh: {
                do { try await model.prepareDirectory(model.book, refresh: true); await readChapters(); return true }
                catch { return false }
            }, onSelect: { target, _, _ in
                let resolved = try await online.resolveTarget(target)
                await model.open(chapterIndex: resolved.chapterIndex, width: pixels)
                guard model.chapter?.chapterIndex == resolved.chapterIndex, !model.loadFailed else {
                    throw CoreBridgeFailure.endpointMismatch
                }
                panel = nil
            })
        case .sources:
            OnlineSourceSwitchSheet(book: model.book, session: session) { candidate in
                let target = try await model.switchSource(candidate.book, width: pixels)
                onBookChanged(target)
                await readChapters()
                panel = nil
            }
        case .downloads:
            NavigationStack {
                MangaDownloadScreen(session: session, book: model.book)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { panel = nil } } }
            }
        }
    }

    private func turn(_ offset: Int) {
        Task { await model.move(by: offset, width: pixels) }
    }

    private func readChapters() async {
        let book = model.book
        let reader = OnlineReadingCoordinator(runtime: model.session.sources.runtime)
        let loaded = try? await reader.cachedDirectory(sourceId: book.sourceId, bookId: book.bookId)
        if model.book.id == book.id { chapters = loaded?.chapters ?? [] }
    }

    private func chapterAction(_ delta: Int) -> (() -> Void)? {
        guard let chapter = model.chapter, let index = chapters.firstIndex(where: { $0.index == chapter.chapterIndex }),
              chapters.indices.contains(index + delta) else { return nil }
        let target = chapters[index + delta].index
        return { Task { await model.open(chapterIndex: target, width: pixels) } }
    }

    private func leave() {
        guard !exiting, !model.busy else { return }
        exiting = true
        Task {
            await model.retire()
            dismiss()
            await onExit()
        }
    }
}
