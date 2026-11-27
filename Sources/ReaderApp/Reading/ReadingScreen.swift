import ReaderCoreBridge
import ReaderDesign
import ReaderHost
import SwiftUI
import UIKit

struct ReadingScreen: View {
    let book: BookshelfEntryData
    let chapters: [BookTocEntryData]
    let original: LocalBookOriginalData?
    let files: FileAndAssetHost
    let startChapter: Int64?
    let onExit: () async -> Void
    @State private var model: ReadingSessionCoordinator
    @State private var renderer: ReadingRenderState
    @State private var controls = ReadingControls.hidden
    @State private var sheet: Sheet?
    @AppStorage("reader.paper") private var paper = ReaderPaper.all[0].id
    @AppStorage("reader.fontSize") private var font = ReaderDesignMetrics.readerBody.fontSize
    @AppStorage("reader.lineSpacing") private var spacing = ReaderDesignMetrics.readerBody.lineHeight / ReaderDesignMetrics.readerBody.fontSize
    @AppStorage("reader.letterSpacing") private var tracking = 0.0
    @AppStorage("reader.readingMode") private var mode = ReadingMode.pages
    @AppStorage("reader.keepAwake") private var keepAwake = false
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Sheet: String, Identifiable {
        case directory, bookmarks
        var id: String { rawValue }
    }

    init(book: BookshelfEntryData, chapters: [BookTocEntryData], original: LocalBookOriginalData?,
         runtime: CoreRuntimeActor, files: FileAndAssetHost, startChapter: Int64?,
         session: ReadingSessionCoordinator? = nil, renderer: ReadingRenderState = ReadingRenderState(),
         onExit: @escaping () async -> Void) {
        self.book = book
        self.chapters = chapters
        self.original = original
        self.files = files
        self.startChapter = startChapter
        self.onExit = onExit
        _model = State(initialValue: session ?? ReadingSessionCoordinator(runtime: runtime))
        _renderer = State(initialValue: renderer)
    }

    private var preferences: ReadingPreferences {
        .init(paperId: paper, fontSize: min(48, max(12, font)), lineSpacing: min(2.6, max(1, spacing)),
              letterSpacing: min(4, max(0, tracking)), mode: mode)
    }

    var body: some View {
        let appearance = preferences
        ReadingPresentation(title: model.chapter?.title ?? book.title, preferences: appearance,
                            controls: controls, onAction: act) {
            if let chapter = model.chapter {
                GeometryReader { geometry in
                    ReadingChapterSurface(chapter: chapter, preferences: appearance, model: model, renderer: renderer,
                                          onTap: tap)
                        .id(chapter.generation)
                        .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { value in
                            let intent = GestureArbiter().drag(start: value.startLocation,
                                translation: value.translation, width: geometry.size.width, mode: appearance.mode)
                            switch intent {
                            case .next: turn(1)
                            case .previous: turn(-1)
                            case .none, .systemBack: break
                            }
                        })
                }
            } else {
                PageState(state: model.pageState) { expected in
                    guard expected == model.generation else { return }
                    Task { await model.reopen(startChapter: startChapter) }
                }
            }
        }
        .overlay(alignment: .top) {
            if let recovery = model.recovery {
                RecoveryNotice(title: recovery.title, message: recovery.message, generation: recovery.generation,
                               action: recovery.action, availability: controls == .hidden && sheet == nil) { generation, action in
                    Task { await model.verifyPosition(expected: generation, action: action) }
                }.padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
                    .padding(.top, 32)
            }
        }
        .overlay(alignment: .bottom) {
            if let message = model.toast.message, phase == .active, sheet == nil {
                TransientToast(message: message).padding(16)
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(appearance.paper.statusBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(appearance.paper.systemStatusBarScheme, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: tap) { ReaderIcon(ReaderIconRegistry.readingAppearance) }
                    .accessibilityLabel("阅读控制岛")
                    .accessibilityIdentifier("reader-controls")
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .directory:
                DirectorySheet(chapters: chapters, selected: model.chapter?.index) { choose($0) }
            case .bookmarks:
                BookmarkSheet(bookmarks: model.bookmarks, onAdd: addBookmark, onJump: {
                    choose($0.chapterIndex, bookmark: $0)
                }, onDelete: { bookmark in Task { await model.deleteBookmark(bookmark) } })
            }
        }
        .task {
            await model.begin(book: book, chapters: chapters, original: original, files: files, startChapter: startChapter)
        }
        .onAppear {
            model.frontmost = true
            UIApplication.shared.isIdleTimerDisabled = keepAwake
        }
        .onDisappear {
            model.frontmost = false
            model.toast.dismiss()
            UIApplication.shared.isIdleTimerDisabled = false
            Task {
                await sampleSurface()
                await model.drain()
                model.retirePage()
                await renderer.retire()
                await onExit()
            }
        }
        .onChange(of: keepAwake) { _, value in UIApplication.shared.isIdleTimerDisabled = value }
        .onChange(of: sheet) { _, value in
            model.frontmost = value == nil
            if value != nil { model.toast.dismiss() }
        }
        .onChange(of: phase, initial: true) { _, value in
            model.sceneActive = value == .active
            if value == .background {
                model.toast.dismiss()
                drainInBackground()
            }
        }
    }

    private func tap() {
        guard sheet == nil else { return }
        setControls(controls == .hidden ? .quick : .hidden)
    }

    private func setControls(_ state: ReadingControls) {
        let millis = reduceMotion ? ReaderDesignMetrics.reducedMotionFadeMillis :
            (state == .hidden ? ReaderDesignMetrics.navigationPopMillis : ReaderDesignMetrics.navigationPushMillis)
        withAnimation(.easeInOut(duration: Double(millis) / 1000)) { controls = state }
    }

    private func act(_ action: ReadingControlAction) {
        switch action {
        case .dismiss: setControls(.hidden)
        case .expand: setControls(.full)
        case .quick: setControls(.quick)
        case .directory: sheet = .directory
        case .bookmarks:
            sheet = .bookmarks
            Task { await model.reloadBookmarks() }
        case .addBookmark: addBookmark()
        case .previous: if let chapter = model.neighboringChapter(-1) { choose(chapter) }
        case .next: if let chapter = model.neighboringChapter(1) { choose(chapter) }
        case .size(let delta): font = min(48, max(12, font + delta))
        case .spacing(let delta): spacing = min(2.6, max(1, spacing + delta))
        case .tracking(let delta): tracking = min(4, max(0, tracking + delta))
        case .paper(let value): paper = value
        case .mode(let value): mode = value
        }
    }

    private func turn(_ direction: Int) {
        guard controls == .hidden else { return }
        Task {
            if await renderer.selection() { return }
            if let text = renderer.text, text.turn(direction) { return }
            if let ebook = renderer.ebook, (try? await ebook.moveViewport(direction)) == true {
                await sampleSurface()
                return
            }
            if let next = model.neighboringChapter(direction) { choose(next) }
        }
    }

    private func choose(_ index: Int64, bookmark: BookmarkData? = nil) {
        sheet = nil
        setControls(.hidden)
        Task {
            await sampleSurface()
            await model.chooseChapter(index, bookmark: bookmark)
        }
    }

    private func sampleSurface() async {
        let generation = model.generation
        if let measured = await renderer.position() { model.measured(measured, expected: generation) }
    }

    private func addBookmark() {
        Task {
            await sampleSurface()
            await model.addBookmark()
        }
    }

    private func drainInBackground() {
        let handle = UIApplication.shared.beginBackgroundTask(withName: "Save reading position")
        Task {
            defer { if handle != .invalid { UIApplication.shared.endBackgroundTask(handle) } }
            await sampleSurface()
            await model.drain()
        }
    }
}

private extension ReaderPaper {
    var systemStatusBarScheme: ColorScheme {
        let value = statusForegroundARGB
        let luma = ((value >> 16) & 0xFF) * 299 + ((value >> 8) & 0xFF) * 587 + (value & 0xFF) * 114
        return luma > 128_000 ? .dark : .light
    }
}
