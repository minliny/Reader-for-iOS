import SwiftUI

public struct BookSourceRowView: View {
    let name: String
    let url: String
    let group: String?
    @Binding var enabled: Bool
    let onDelete: () -> Void
    let onShare: (() -> Void)?
    let onTapDetail: (() -> Void)?

    public init(
        name: String,
        url: String,
        group: String? = nil,
        enabled: Binding<Bool>,
        onDelete: @escaping () -> Void,
        onShare: (() -> Void)? = nil,
        onTapDetail: (() -> Void)? = nil
    ) {
        self.name = name
        self.url = url
        self.group = group
        self._enabled = enabled
        self.onDelete = onDelete
        self.onShare = onShare
        self.onTapDetail = onTapDetail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.headline)
                    Text(url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Toggle("", isOn: $enabled).labelsHidden()
            }
            HStack {
                Label(enabled ? "已启用" : "已禁用",
                      systemImage: enabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(enabled ? .green : .secondary)
                if let onShare = onShare {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up").font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash").font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture { onTapDetail?() }
    }
}
