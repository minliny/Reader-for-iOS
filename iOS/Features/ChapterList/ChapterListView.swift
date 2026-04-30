import SwiftUI
import ReaderCoreModels

public struct ChapterListView: View {
    @StateObject private var viewModel: ChapterListViewModel
    @State private var navigationPath = NavigationPath()

    public init(bookURL: String, bookTitle: String) {
        self._viewModel = StateObject(wrappedValue: ChapterListViewModel(bookURL: bookURL, bookTitle: bookTitle))
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(alignment: .leading, spacing: 16) {
                listStateView
            }
            .padding()
            .navigationTitle("Table of Contents")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .onAppear {
                Task { await viewModel.loadChapters() }
            }
            .navigationDestination(for: String.self) { chapterURL in
                ReaderView(chapterURL: chapterURL, chapterTitle: chapterURL)
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
            List {
                ForEach(chapters, id: \.chapterURL) { chapter in
                    ChapterRowView(
                        chapter: chapter,
                        onTap: {
                            showChapterAction(chapter: chapter)
                        }
                    )
                }
            }
            .listStyle(.plain)

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

                List {
                    ForEach(chapters, id: \.chapterURL) { chapter in
                        ChapterRowView(
                            chapter: chapter,
                            onTap: {
                                showChapterAction(chapter: chapter)
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func showChapterAction(chapter: TOCItem) {
        navigationPath.append(chapter.chapterURL)
    }
}