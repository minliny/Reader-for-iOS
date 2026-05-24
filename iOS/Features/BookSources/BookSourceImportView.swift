import SwiftUI
import ReaderShellValidation

public struct BookSourceImportView: View {
    @StateObject private var viewModel = BookSourceViewModel()
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("导入书源")
                    .font(.headline)

                TextEditor(text: $viewModel.jsonInput)
                    .frame(minHeight: 150)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                Button(action: {
                    Task { await viewModel.importFromText() }
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("从文本导入")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.jsonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                importStateView
            }
            .padding()
            .navigationTitle("导入书源")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var importStateView: some View {
        switch viewModel.importState {
        case .idle:
            EmptyView()

        case .loading:
            ProgressView("导入中...")
                .frame(maxWidth: .infinity, minHeight: 120)

        case .success(let source):
            VStack(alignment: .leading, spacing: 8) {
                Label("导入成功", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline.weight(.semibold))

                Text(source.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label("导入失败", systemImage: "xmark.circle.fill")
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
                Label("不支持", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline.weight(.semibold))

                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

        case .partial(let source, let warnings):
            VStack(alignment: .leading, spacing: 8) {
                Label("部分导入", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.yellow)
                    .font(.subheadline.weight(.semibold))

                Text(source.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(warnings, id: \.self) { warning in
                    Text("⚠️ \(warning)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
