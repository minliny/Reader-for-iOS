import ReaderCoreBridge
import ReaderDesign
import ReaderHost
import SwiftUI

struct BookDetailScreen: View {
    struct ReadingRoute: Hashable { let chapter: Int64? }

    let identity: BookIdentity
    let runtime: CoreRuntimeActor
    let files: FileAndAssetHost
    let remove: () async -> Bool
    let refreshShelf: () async -> Void
    @State private var model: BookDetailModel = .init()
    @State private var route: ReadingRoute?
    @State private var directory = false
    @State private var confirmation: ReaderConfirmation?
    @State private var removalGeneration = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let book = model.book {
                BookDetailContent(book: book, chapters: model.chapters,
                                  onRead: { route = .init(chapter: nil) }, onDirectory: { directory = true }) {
                    removalGeneration += 1
                    confirmation = ReaderConfirmation(title: "移出书架？", message: "《\(book.title)》将从书架移除。",
                                                      confirmTitle: "移除", generation: removalGeneration)
                }
                .navigationDestination(item: $route) { route in
                    ReadingScreen(book: book, chapters: model.chapters, original: model.original,
                                  runtime: runtime, files: files, startChapter: route.chapter) {
                        await load()
                        await refreshShelf()
                    }
                }
                .sheet(isPresented: $directory) {
                    DirectorySheet(chapters: model.chapters, selected: nil) { index in
                        directory = false
                        route = .init(chapter: index)
                    }
                }
            } else {
                PageState(state: model.state) { expected in
                    guard expected == model.generation else { return }
                    Task { await load() }
                }
            }
        }
        .navigationTitle("书籍详情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .readerConfirmation($confirmation) { generation in
            guard generation == removalGeneration else { return }
            Task {
                if await remove() { dismiss() }
                else { await load() }
            }
        }
    }

    private func load() async { await model.load(identity, runtime: runtime) }
}

@MainActor
@Observable
final class BookDetailModel {
    private(set) var book: BookshelfEntryData?
    private(set) var original: LocalBookOriginalData?
    private(set) var chapters: [BookTocEntryData] = []
    private(set) var state = ReaderPageState.loading
    private(set) var generation = 0

    func load(_ identity: BookIdentity, runtime: CoreRuntimeActor) async {
        generation += 1
        let current = generation
        if book == nil { state = .loading }
        do {
            async let metadata = runtime.request(ReaderM1.bookshelfGet, identity.query)
            async let directory = runtime.request(ReaderM1.localBookToc, .init(bookId: identity.bookId))
            let (detail, toc) = try await (metadata.value, directory.value)
            guard current == generation else { return }
            guard let entry = detail.book else { state = .empty("书籍已移出书架"); book = nil; return }
            guard BookIdentity(entry) == identity, toc.bookId == identity.bookId,
                  toc.sourceId == identity.sourceId else { throw CoreBridgeFailure.endpointMismatch }
            book = entry
            original = detail.original
            chapters = toc.toc
        } catch {
            guard current == generation, book == nil else { return }
            state = .failed("暂时无法读取书籍详情。", actionGeneration: current)
        }
    }
}
