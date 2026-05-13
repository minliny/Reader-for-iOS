import SwiftUI
import ReaderCoreModels

public struct BookSourceRowView: View {
    let source: BookSource
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onShare: (() -> Void)?

    public init(
        source: BookSource,
        onToggle: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onShare: (() -> Void)? = nil
    ) {
        self.source = source
        self.onToggle = onToggle
        self.onDelete = onDelete
        self.onShare = onShare
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
                    get: { source.enabled ?? true },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
            }

            HStack {
                if source.id != nil {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }

                if let onShare = onShare {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
