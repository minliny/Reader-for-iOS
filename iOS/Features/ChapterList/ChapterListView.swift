import SwiftUI
import ReaderCoreModels

struct ChapterNavigation: Hashable {
    let chapterURL: String
    let chapterTitle: String
    let chapterIndex: Int

    init(chapterURL: String, chapterTitle: String, chapterIndex: Int = 0) {
        self.chapterURL = chapterURL
        self.chapterTitle = chapterTitle
        self.chapterIndex = chapterIndex
    }
}

public struct ChapterListView: View {
    @StateObject private var viewModel: ChapterListViewModel
    @State private var navigationPath = NavigationPath()
    let sourceName: String
    let source: BookSource?
    private var resolvedBookID: String { viewModel.bookURL }
    private var resolvedSourceID: String {
        if let id = source?.id, !id.isEmpty {
            return id
        }
        return viewModel.bookURL
    }

    public init(bookURL: String, bookTitle: String, sourceName: String = "", source: BookSource? = nil) {
        self.sourceName = sourceName
        self.source = source
        self._viewModel = StateObject(wrappedValue: ChapterListViewModel(bookURL: bookURL, bookTitle: bookTitle, source: source))
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(alignment: .leading, spacing: 16) {
                listStateView
            }
            .padding()
            .navigationTitle("目录")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .onAppear {
                Task { await viewModel.loadChapters() }
            }
            .navigationDestination(for: ChapterNavigation.self) { nav in
                ReaderView(
                    chapterURL: nav.chapterURL,
                    chapterTitle: nav.chapterTitle,
                    chapterList: viewModel.chaptersForReader,
                    currentChapterIndex: nav.chapterIndex,
                    bookID: resolvedBookID,
                    sourceID: resolvedSourceID,
                    source: source
                )
            }
        }
    }

    @ViewBuilder
    private var listStateView: some View {
        switch viewModel.listState {
        case .idle:
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case .loading:
            ProgressView("Loading chapters...")
                .frame(maxWidth: .infinity, minHeight: 200)

        case .loaded(let chapters):
            chapterList(chapters)

        case .empty:
            VStack(spacing: 16) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("No Chapters")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Chapter list is unavailable")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label("Load Failed", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline.weight(.semibold))

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

        case .unsupported(let reason):
            VStack(alignment: .leading, spacing: 8) {
                Label("Unsupported", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline.weight(.semibold))

                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

        case .partial(let chapters, let warnings):
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Partial Data", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.yellow)
                        .font(.subheadline.weight(.semibold))

                    ForEach(warnings, id: \.self) {
                        Text("⚠️ \($0)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                chapterList(chapters)
            }
        }
    }

    private func chapterList(_ chapters: [TOCItem]) -> some View {
        List {
            ForEach(Array(chapters.enumerated()), id: \.element.chapterURL) { index, chapter in
                ChapterRowView(
                    chapter: chapter,
                    onTap: {
                        showChapterAction(chapter: chapter, index: index)
                    }
                )
            }
        }
        .listStyle(.plain)
    }

    private func showChapterAction(chapter: TOCItem, index: Int) {
        navigationPath.append(ChapterNavigation(
            chapterURL: chapter.chapterURL,
            chapterTitle: chapter.chapterTitle,
            chapterIndex: index
        ))
    }
}
