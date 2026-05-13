import SwiftUI
import ReaderCoreModels
import ReaderShellValidation
import ReaderAppPersistence

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
                BookSourceImportView()
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

    private var enabledSources: [BookSource] {
        sources.filter { $0.enabled }
    }

    private var disabledSources: [BookSource] {
        sources.filter { !$0.enabled }
    }

    private var sourceListContent: some View {
        List {
            if !enabledSources.isEmpty {
                Section("Enabled (\(enabledSources.count))") {
                    ForEach(enabledSources, id: \.id) { source in
                        sourceRow(source: source)
                    }
                }
            }
            if !disabledSources.isEmpty {
                Section("Disabled (\(disabledSources.count))") {
                    ForEach(disabledSources, id: \.id) { source in
                        sourceRow(source: source)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func sourceRow(source: BookSource) -> some View {
        BookSourceRowView(
            source: source,
            onToggle: { Task { await toggleSource(source) } },
            onDelete: { Task { await deleteSource(source) } }
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
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
