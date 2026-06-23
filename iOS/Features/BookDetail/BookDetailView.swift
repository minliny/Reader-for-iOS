import SwiftUI
import ReaderCoreModels
import ReaderAppSupport
import ReaderAppPersistence
import ReaderShellValidation

public struct BookDetailView: View {
    @StateObject private var viewModel: BookDetailViewModel
    @State private var showChapterList = false
    @State private var isInBookshelf = false
    let result: SearchResultItem
    let sourceName: String
    let source: BookSource?
    private let bookshelfStore = BookshelfStore.shared
    private var sourceIdentity: ReaderAppSupport.SourceIdentity {
        SourceIdentityFactory.from(searchResult: result)
    }
    private var resolvedSourceID: String {
        if let id = source?.id, !id.isEmpty {
            return id
        }
        return sourceIdentity.id
    }

    public init(result: SearchResultItem, sourceName: String = "", source: BookSource? = nil) {
        self.result = result
        self.sourceName = sourceName
        self.source = source
        self._viewModel = StateObject(wrappedValue: BookDetailViewModel(bookURL: result.detailURL, source: source))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                detailStateView
            }
            .padding()
        }
        .navigationTitle("书籍详情")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onAppear {
            Task {
                await viewModel.loadDetail()
                checkBookshelfStatus()
            }
        }
        .sheet(isPresented: $showChapterList) {
            ChapterListView(bookURL: result.detailURL, bookTitle: result.title, sourceName: sourceName, source: source)
        }
    }

    private func checkBookshelfStatus() {
        isInBookshelf = (try? bookshelfStore.find(bookURL: result.detailURL, sourceID: resolvedSourceID)) != nil
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
            // 书名 + 作者
            HStack(spacing: 16) {
                coverPlaceholder
                VStack(alignment: .leading, spacing: 8) {
                    Text(detail.title)
                        .font(.title)
                        .fontWeight(.bold)

                    if let author = detail.author, !author.isEmpty {
                        Label("\(author)", systemImage: "person.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 来源 + 最新章节
            VStack(alignment: .leading, spacing: 6) {
                Label("来源：\(sourceName.isEmpty ? "未知书源" : sourceName)", systemImage: "link")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(detail.latestChapterLabel, systemImage: "text.justify")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

            // 简介
            VStack(alignment: .leading, spacing: 6) {
                Text("简介")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail.intro?.isEmpty == false
                     ? detail.intro!
                     : "一个普通的山村少年韩立，机缘巧合之下踏入修仙界，历经千难万险，最终飞升仙界。这是一个关于坚持、智慧和勇气的故事。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(6)
            }

            Divider()

            // 操作区
            VStack(spacing: 12) {
                // 开始阅读
                NavigationLink {
                    ReaderView(
                        chapterURL: viewModel.firstChapter?.chapterURL ?? result.detailURL,
                        chapterTitle: viewModel.firstChapter?.chapterTitle ?? "第一章",
                        chapterList: viewModel.chapters,
                        currentChapterIndex: 0,
                        bookID: sourceIdentity.id,
                        sourceID: resolvedSourceID,
                        source: source
                    )
                } label: {
                    HStack {
                        Image(systemName: "book.fill")
                        Text("开始阅读")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .onAppear {
                    // Auto-add to bookshelf when "开始阅读" is shown, if not already added
                    if !isInBookshelf {
                        addToBookshelf()
                    }
                }

                // 查看目录
                Button(action: {
                    showTOCAction()
                }) {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("查看目录（5 章）")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.primary)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // 加入书架
                addToBookshelfButton
            }
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
            sourceID: resolvedSourceID,
            sourceName: source?.bookSourceName ?? identity.name,
            bookURL: result.detailURL,
            title: result.title,
            author: result.author,
            coverURL: result.coverURL,
            latestChapter: nil
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

extension SearchResultItem {
    var latestChapterLabel: String {
        if let next = nextPageUrl, !next.isEmpty { return "最新章节：\(next)" }
        return "最新章节：待接入（M2.2）"
    }
}
