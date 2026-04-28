import SwiftUI
import ReaderCoreModels

public struct BookDetailView: View {
    @StateObject private var viewModel: BookDetailViewModel
    @State private var showChapterList = false
    @State private var isInBookshelf = false
    let result: SearchResultItem
    private let bookshelfStore = BookshelfStore.shared
    private var sourceIdentity: SourceIdentity {
        SourceIdentityFactory.from(searchResult: result)
    }

    public init(result: SearchResultItem) {
        self.result = result
        self._viewModel = StateObject(wrappedValue: BookDetailViewModel(bookURL: result.detailURL))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detailStateView
                }
                .padding()
            }
            .navigationTitle("Book Detail")
            .onAppear {
                Task {
                    await viewModel.loadDetail()
                    checkBookshelfStatus()
                }
            }
            .navigationDestination(isPresented: $showChapterList) {
                ChapterListView(bookURL: result.detailURL, bookTitle: result.title)
            }
        }
    }

    private func checkBookshelfStatus() {
        isInBookshelf = (try? bookshelfStore.find(bookURL: result.detailURL, sourceID: sourceIdentity.id)) != nil
    }

    @ViewBuilder
    private var detailStateView: some View {
        switch viewModel.detailState {
        case .idle:
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case .loading:
            ProgressView("Loading detail...")
                .frame(maxWidth: .infinity, minHeight: 200)

        case .loaded(let detail):
            bookDetailContent(detail: detail)

        case .empty:
            VStack(spacing: 16) {
                Image(systemName: "book")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("No Detail")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Book detail is unavailable")
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

        case .partial(let detail, let warnings):
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

                bookDetailContent(detail: detail)
            }
        }
    }

    @ViewBuilder
    private func bookDetailContent(detail: SearchResultItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                coverPlaceholder
                VStack(alignment: .leading, spacing: 8) {
                    Text(detail.title)
                        .font(.title)
                        .fontWeight(.bold)

                    if let author = detail.author, !author.isEmpty {
                        Text("by \(author)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let coverURL = detail.coverURL, !coverURL.isEmpty {
                Text("Cover: \(coverURL)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            if let latestChapter = detail.latestChapter, !latestChapter.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latest Chapter")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(latestChapter)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            if let bookDescription = detail.bookDescription, !bookDescription.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(bookDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                }
            }

            Button(action: {
                showTOCAction()
            }) {
                HStack {
                    Image(systemName: "list.bullet")
                    Text("View Table of Contents")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.primary)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            addToBookshelfButton
        }
    }

    private var addToBookshelfButton: some View {
        Button(action: {
            addToBookshelf()
        }) {
            HStack {
                Image(systemName: isInBookshelf ? "checkmark.circle.fill" : "plus.circle")
                Text(isInBookshelf ? "In Bookshelf" : "Add to Bookshelf")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isInBookshelf ? Color.gray : Color.blue)
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func addToBookshelf() {
        let identity = sourceIdentity
        let item = BookshelfItem(
            sourceID: identity.id,
            sourceName: identity.name,
            bookURL: result.detailURL,
            title: result.title,
            author: result.author,
            coverURL: result.coverURL,
            latestChapter: result.latestChapter
        )
        try? bookshelfStore.addOrUpdate(item)
        isInBookshelf = true
    }

    private var coverPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 100, height: 140)

            Image(systemName: "book.closed")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
        }
    }

    private func showTOCAction() {
        showChapterList = true
    }
}