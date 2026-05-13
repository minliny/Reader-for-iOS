import SwiftUI
import ReaderCoreModels

private struct BookDetailRoute: Hashable {
    let detailURL: String
}

public struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var selectedResult: SearchResultItem?
    @State private var bookRoute: BookDetailRoute?
    @State private var selectedSourceID: String?
    @AppStorage("search_history") private var historyData: Data = Data()
    @State private var searchHistory: [String] = []
    @StateObject private var bookshelfVM = BookshelfViewModel()
    @State private var toastMessage: String?
    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            toastMessage = nil
        }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let toast = toastMessage {
                    Text(toast)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green, in: RoundedRectangle(cornerRadius: 8))
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut, value: toastMessage)
                }
                sourceSelectionView
                searchInputView
                searchStateView
            }
            .padding()
            .navigationTitle("Search")
#if os(iOS)
            .navigationDestination(item: $bookRoute) { _ in
                if let result = selectedResult {
                    BookDetailView(result: result)
                }
            }
#endif
        }
    }

    private var sourceSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Book Source")
                .font(.subheadline)
                .fontWeight(.semibold)

            Picker("Select source", selection: $selectedSourceID) {
                Text("None").tag(nil as String?)
                ForEach(viewModel.sources, id: \.id) { source in
                    Text(source.displayName).tag(source.id)
                }
            }
            .pickerStyle(.menu)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .onChange(of: selectedSourceID) { newID in
            if let id = newID, let source = viewModel.sources.first(where: { $0.id == id }) {
                viewModel.selectSource(source)
            }
        }
        .onAppear {
            if selectedSourceID == nil, let first = viewModel.selectedSource {
                selectedSourceID = first.id
            }
        }
    }

    private var searchInputView: some View {
        HStack(spacing: 8) {
            TextField("Enter keyword", text: $viewModel.keyword)
                .textFieldStyle(.roundedBorder)

            Button(action: {
                saveSearchHistory(viewModel.keyword)
                Task { await viewModel.search() }
            }) {
                Image(systemName: "magnifyingglass")
                    .padding()
                    .background(.primary)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
            }
        }
        .onAppear {
            loadSearchHistory()
        }
    }

    @ViewBuilder
    private var searchStateView: some View {
        switch viewModel.searchState {
        case .idle:
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter a keyword and select a book source to search")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !searchHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Recent Searches")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Clear") {
                                searchHistory = []
                                historyData = Data()
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(searchHistory, id: \.self) { keyword in
                                    Button(keyword) {
                                        viewModel.keyword = keyword
                                        saveSearchHistory(keyword)
                                        Task { await viewModel.search() }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
            }

        case .loading:
            ProgressView("Searching...")
                .frame(maxWidth: .infinity, minHeight: 120)

        case .success(let results):
            List {
                ForEach(results, id: \.detailURL) { result in
                    SearchResultRowView(
                        result: result,
                        sourceName: viewModel.selectedSource?.displayName ?? "",
                        onTap: {
                            selectedResult = result
                            bookRoute = BookDetailRoute(detailURL: result.detailURL)
                        },
                        onAddToBookshelf: {
                            let sourceID = viewModel.selectedSource?.id ?? "unknown"
                            Task {
                                await bookshelfVM.addOrUpdateItem(
                                    from: result,
                                    sourceID: sourceID,
                                    sourceName: viewModel.selectedSource?.bookSourceName
                                )
                                showToast("Added \"\(result.title)\" to Bookshelf")
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)

        case .empty:
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("No Results")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Try a different keyword or book source")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label("Search Failed", systemImage: "xmark.circle.fill")
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

        case .partial(let results, let warnings):
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Partial Results", systemImage: "exclamationmark.circle.fill")
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
                    ForEach(results, id: \.detailURL) { result in
                        SearchResultRowView(
                            result: result,
                            sourceName: viewModel.selectedSource?.displayName ?? "",
                            onTap: {
                                selectedResult = result
                                bookRoute = BookDetailRoute(detailURL: result.detailURL)
                            },
                            onAddToBookshelf: {
                                let sourceID = viewModel.selectedSource?.id ?? "unknown"
                                Task {
                                    await bookshelfVM.addOrUpdateItem(
                                        from: result,
                                        sourceID: sourceID,
                                        sourceName: viewModel.selectedSource?.bookSourceName
                                    )
                                    showToast("Added \"\(result.title)\" to Bookshelf")
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Search History

    private func loadSearchHistory() {
        searchHistory = (try? JSONDecoder().decode([String].self, from: historyData)) ?? []
    }

    private func saveSearchHistory(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var history = searchHistory
        history.removeAll { $0 == trimmed }
        history.insert(trimmed, at: 0)
        if history.count > 10 { history = Array(history.prefix(10)) }
        searchHistory = history
        historyData = (try? JSONEncoder().encode(history)) ?? Data()
    }
}
