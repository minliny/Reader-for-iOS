import SwiftUI
import ReaderCoreModels

public struct BookSourceRowView: View {
    let source: BookSource
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onShare: (() -> Void)?
    let onTapDetail: (() -> Void)?

    public init(
        source: BookSource,
        onToggle: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onShare: (() -> Void)? = nil,
        onTapDetail: (() -> Void)? = nil
    ) {
        self.source = source
        self.onToggle = onToggle
        self.onDelete = onDelete
        self.onShare = onShare
        self.onTapDetail = onTapDetail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.displayName)
                        .font(.headline)

                    Text(source.displayURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { source.enabled },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
            }

            HStack {
                Label(source.enabled ? "已启用" : "已禁用",
                      systemImage: source.enabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(source.enabled ? .green : .secondary)

                if let onShare = onShare {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onTapGesture {
            onTapDetail?()
        }
    }
}
