import SwiftUI

public struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                sourceSelectionView
                searchInputView
                searchStateView
            }
            .padding()
            .navigationTitle("Search")
        }
    }

    private var sourceSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Book Source")
                .font(.subheadline)
                .fontWeight(.semibold)

            Picker("Select source", selection: Binding(
                get: { viewModel.selectedSource },
                set: { if let source = $0 { viewModel.selectSource(source) } }
            )) {
                ForEach(viewModel.sources, id: \.id) { source in
                    Text(source.displayName)
                }
            }
            .pickerStyle(.menu)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var searchInputView: some View {
        HStack(spacing: 8) {
            TextField("Enter keyword", text: $viewModel.keyword)
                .textFieldStyle(.roundedBorder)

            Button(action: {
                Task { await viewModel.search() }
            }) {
                Image(systemName: "magnifyingglass")
                    .padding()
                    .background(.primary)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
            }
        }
    }

    @ViewBuilder
    private var searchStateView: some View {
        switch viewModel.searchState {
        case .idle:
            Text("Enter a keyword and select a book source to search")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case .loading:
            ProgressView("Searching...")
                .frame(maxWidth: .infinity, minHeight: 120)

        case .success(let results):
            List {
                ForEach(results, id: \.detailURL) { result in
                    SearchResultRowView(
                        result: result,
                        sourceName: viewModel.selectedSource?.displayName ?? ""
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
                            sourceName: viewModel.selectedSource?.displayName ?? ""
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
