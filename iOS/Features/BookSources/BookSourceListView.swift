import SwiftUI
import ReaderCoreModels
import ReaderShellValidation

public struct BookSourceListView: View {
    @ObservedObject var coordinator: ReadingFlowCoordinator
    @State private var sources: [BookSource] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingImport = false

    private let store = BookSourceStore.shared

    public init(coordinator: ReadingFlowCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading sources...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sources.isEmpty {
                    emptyStateView
                } else {
                    sourceListContent
                }
            }
            .navigationTitle("Book Sources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingImport = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingImport) {
                BookSourceImportView(coordinator: coordinator)
            }
            .task {
                await loadSources()
            }
            .refreshable {
                await loadSources()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Book Sources")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Import a book source to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Import Book Source") {
                showingImport = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sourceListContent: some View {
        List {
            ForEach(sources, id: \.id) { source in
                BookSourceRowView(
                    source: source,
                    onToggle: { Task { await toggleSource(source) } },
                    onDelete: { Task { await deleteSource(source) } }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    private func loadSources() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            sources = try await store.load()
        } catch {
            errorMessage = "Failed to load sources: \(error.localizedDescription)"
        }
    }

    private func toggleSource(_ source: BookSource) async {
        guard let id = source.id else { return }

        do {
            try await store.toggleEnabled(id: id)
            await loadSources()
        } catch {
            errorMessage = "Failed to toggle source: \(error.localizedDescription)"
        }
    }

    private func deleteSource(_ source: BookSource) async {
        guard let id = source.id else { return }

        do {
            try await store.delete(id: id)
            await loadSources()
        } catch {
            errorMessage = "Failed to delete source: \(error.localizedDescription)"
        }
    }
}
