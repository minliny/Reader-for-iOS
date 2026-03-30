import SwiftUI
import ReaderCoreModels

public struct BookSourceImportView: View {
    @ObservedObject public var coordinator: ReadingFlowCoordinator
    @State private var jsonInput = ""
    @State private var isImporting = false
    @State private var showFilePicker = false

    public init(coordinator: ReadingFlowCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("导入书源") {
                        TextEditor(text: $jsonInput)
                            .frame(minHeight: 150)
                            .font(.system(.body, design: .monospaced))
                            .border(Color.gray.opacity(0.3), cornerRadius: 8)

                        Button(action: importFromText) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("从文本导入")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(jsonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Section("已导入书源") {
                        if let selected = coordinator.selectedSource {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(selected.bookSourceName)
                                    .font(.headline)
                            }
                        }
                    }
                }

                if !coordinator.searchResults.isEmpty {
                    Divider()
                    Button(action: {}) {
                        NavigationLink("前往搜索") {
                            SearchView(coordinator: coordinator)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("书源管理")
            .sheet(isPresented: $isImporting) {
                if coordinator.isLoading {
                    LoadingView(message: "导入中...")
                } else if let error = coordinator.currentError {
                    ErrorView(error: error) {
                        coordinator.currentError = nil
                    }
                }
            }
            .onChange(of: coordinator.isLoading) { _, loading in
                isImporting = loading || coordinator.currentError != nil
            }
        }
    }

    private func importFromText() {
        Task {
            if let data = jsonInput.data(using: .utf8) {
                await coordinator.importBookSource(from: data)
            }
        }
    }
}
