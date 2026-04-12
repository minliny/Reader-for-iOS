import SwiftUI
import ReaderCoreModels
import ReaderShellValidation

public struct BookSourceImportView: View {
    @ObservedObject public var coordinator: ReadingFlowCoordinator
    @State private var jsonInput = ""

    public init(coordinator: ReadingFlowCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导入书源")
                .font(.headline)

            TextEditor(text: $jsonInput)
                .frame(minHeight: 150)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Button(action: importFromText) {
                HStack {
                    Image(systemName: "doc.text")
                    Text("从文本导入")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(jsonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if coordinator.isLoading {
                LoadingView(message: "导入中...")
                    .frame(maxWidth: .infinity, minHeight: 120)
            }

            if let selected = coordinator.selectedSource {
                VStack(alignment: .leading, spacing: 6) {
                    Text("当前书源")
                        .font(.subheadline.weight(.semibold))
                    Text(selected.bookSourceName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            if let error = coordinator.currentError {
                ErrorView(error: error) {
                    coordinator.currentError = nil
                }
                .frame(maxWidth: .infinity, minHeight: 180)
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
