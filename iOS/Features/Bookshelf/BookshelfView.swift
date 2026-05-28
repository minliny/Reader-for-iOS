import SwiftUI
import ReaderAppSupport

public struct BookshelfView: View {
    @StateObject private var viewModel = BookshelfViewModel()
    @State private var selectedItem: BookshelfItem?
    @State private var showFileImport = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                bookshelfStateView
            }
            .padding()
            .navigationTitle("书架")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFileImport = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                }
            }
            .onAppear {
                Task { await viewModel.loadItems() }
            }
            .refreshable {
                await viewModel.loadItems()
            }
            .sheet(item: $selectedItem) { item in
                BookshelfItemDetailView(item: item)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showFileImport) {
                FileImportView()
            }
        }
    }

    @ViewBuilder
    private var bookshelfStateView: some View {
        switch viewModel.bookshelfState {
        case .idle:
            Text("加载中...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case .loading:
            ProgressView("加载中...")
                .frame(maxWidth: .infinity, minHeight: 200)

        case .loaded(let items):
            List {
                ForEach(items) { item in
                    BookshelfItemRowView(
                        item: item,
                        onTap: {
                            navigateToDetail(item: item)
                        },
                        onDelete: {
                            Task {
                                await viewModel.removeItem(id: item.id)
                            }
                        }
                    )
                }
            }
            .listStyle(.plain)

        case .empty:
            VStack(spacing: 16) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("书架为空")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("从搜索结果添加书籍")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label("错误", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline.weight(.semibold))

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func navigateToDetail(item: BookshelfItem) {
        selectedItem = item
    }
}

struct BookshelfItemDetailView: View {
    let item: BookshelfItem
    @State private var navigateToReader = false
    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("书籍信息") {
                    LabeledContent("书名", value: item.title)
                    if let author = item.author {
                        LabeledContent("作者", value: author)
                    }
                    if let source = item.sourceName {
                        LabeledContent("来源", value: source)
                    }
                }

                Section("阅读进度") {
                    LabeledContent("进度") {
                        Text("\(Int(item.readingProgress * 100))%")
                    }
                    if let chapter = item.lastReadChapterTitle {
                        LabeledContent("最后阅读", value: chapter)
                    }
                    LabeledContent("添加时间") {
                        Text(item.addedAt, style: .date)
                    }
                }

                if item.lastReadChapterURL != nil {
                    Section {
                        Button {
                            navigateToReader = true
                        } label: {
                            HStack {
                                Image(systemName: "book.fill")
                                Text("继续阅读")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle(item.title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $navigateToReader) {
                ReaderView(
                    chapterURL: item.lastReadChapterURL ?? item.bookURL,
                    chapterTitle: item.lastReadChapterTitle ?? "继续阅读",
                    bookID: item.id,
                    sourceID: item.sourceID
                )
            }
        }
    }
}