import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct MangaDownloadScreen: View {
    let session: M2AppSession
    let book: OnlineBookReference
    @State private var status: M3CacheBookStatusData?
    @State private var state = ReaderPageState.loading
    @State private var toast = ReaderToastPresenter()
    @Environment(\.readerTheme) private var theme
    @Environment(\.scenePhase) private var phase

    var body: some View {
        Group {
            if let status, !status.chapters.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ReaderTaskProgress(title: book.title, completed: Int(status.completedCount),
                                           failed: Int(status.failedCount), total: Int(status.chapterCount))
                            .padding(.vertical, 12)
                        ForEach(status.chapters, id: \.chapterIndex) { chapter in row(chapter) }
                    }
                    .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
                }
            } else {
                PageState(state: state) { _ in Task { await load(first: true) } }
            }
        }
        .background(theme.background)
        .navigationTitle("漫画下载")
        .navigationBarTitleDisplayMode(.inline)
        .readerNavigationBar()
        .accessibilityIdentifier("m3-manga-download-page")
        .overlay(alignment: .bottom) {
            if let message = toast.message, phase == .active { TransientToast(message: message).padding(16) }
        }
        .task(id: phase) {
            guard phase == .active else { toast.dismiss(); return }
            await load(first: true)
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(0.8)) } catch { return }
                await load()
            }
        }
        .refreshable { await load(first: true) }
        .onDisappear { toast.dismiss() }
    }

    private func row(_ chapter: M3CacheChapterStatusData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.displayTitle ?? chapter.title).readerTypography(ReaderDesignMetrics.rowLabel)
                    Text(label(chapter.state)).readerTypography(ReaderDesignMetrics.rowDetail)
                        .foregroundStyle(theme.mutedText)
                        .accessibilityIdentifier("m3-manga-download-state-\(chapter.chapterIndex)")
                }
                Spacer()
                if chapter.navigable != false {
                    switch chapter.state {
                    case .completed:
                        ReaderIcon(ReaderIconRegistry.check).foregroundStyle(theme.accent)
                    case .inProgress, .queued:
                        Button("暂停") { control(.pause, chapter.chapterIndex) }
                        Button("取消") { control(.cancel, chapter.chapterIndex) }
                    case .paused:
                        Button("继续") { control(.resume, chapter.chapterIndex) }
                        Button("取消") { control(.cancel, chapter.chapterIndex) }
                    case .missing, .cached, .failed, .cancelled:
                        Button(chapter.state == .failed ? "重试" : "下载") { start(chapter.chapterIndex) }
                            .accessibilityIdentifier("m3-manga-download-start-\(chapter.chapterIndex)")
                    }
                }
            }
            .buttonStyle(.borderless)
            .frame(minHeight: 58)
            Divider()
        }
    }

    private func label(_ state: M3CacheChapterState) -> String {
        switch state {
        case .missing: "待下载"
        case .queued: "等待下载"
        case .paused: "已暂停"
        case .inProgress: "正在下载"
        case .cached: "可下载原图"
        case .completed: "可离线阅读"
        case .failed: "未下载完成"
        case .cancelled: "已取消"
        }
    }

    private func start(_ index: Int64) {
        do {
            let task = try session.mangaDownloads.start(book, index: index)
            Task {
                if case .failure(_) = await task.result { feedback("本章下载未完成，可查看状态后重试。") }
                await load()
            }
        } catch { feedback("已有本章下载任务。") }
    }

    private func control(_ action: MangaReadingCoordinator.DownloadAction, _ index: Int64) {
        Task {
            do { try await session.mangaDownloads.control(action, book: book, index: index) }
            catch { feedback("下载状态暂未更新。") }
            await load()
        }
    }

    private func load(first: Bool = false) async {
        do {
            var result = try await session.mangaDownloads.status(book)
            if first && !result.tocAvailable {
                try await session.mangaDownloads.prepareDirectory(book)
                result = try await session.mangaDownloads.status(book)
            }
            guard !Task.isCancelled else { return }
            status = result
            if result.chapters.isEmpty { state = .empty("没有可下载的章节") }
        } catch {
            if status == nil { state = .failed("暂时无法读取漫画下载目录。", actionGeneration: 0) }
        }
    }

    private func feedback(_ text: String) {
        toast.show(message: text, key: "manga-download", feedbackEnabled: true, sceneActive: phase == .active)
    }
}

struct MangaDownloadLibraryScreen: View {
    let session: M2AppSession
    @State private var books: [BookshelfEntryData] = []
    @State private var state = ReaderPageState.loading
    @Environment(\.readerTheme) private var theme

    var body: some View {
        Group {
            if books.isEmpty {
                PageState(state: state) { _ in Task { await load() } }
            } else {
                List(books.map(OnlineBookReference.init(shelfBook:))) { book in
                    NavigationLink {
                        MangaDownloadScreen(session: session, book: book)
                    } label: {
                        Label(book.title, systemImage: "books.vertical")
                            .readerTypography(ReaderDesignMetrics.rowLabel)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(theme.background)
        .navigationTitle("漫画下载")
        .navigationBarTitleDisplayMode(.inline)
        .readerNavigationBar()
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            var result: [BookshelfEntryData] = []
            var offset: Int64 = 0
            while !Task.isCancelled {
                let page = try await session.sources.runtime.request(ReaderM1.bookshelfList,
                    .init(sourceKind: .online, contentKind: .manga, offset: offset, limit: 100)).value
                result += page.books
                offset += Int64(page.books.count)
                if page.books.isEmpty || offset >= page.total { break }
            }
            guard !Task.isCancelled else { return }
            books = result
            if result.isEmpty { state = .empty("书架中没有漫画") }
        } catch {
            if books.isEmpty { state = .failed("暂时无法读取漫画书架。", actionGeneration: 0) }
        }
    }
}
