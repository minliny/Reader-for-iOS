import SwiftUI

public struct BookshelfItemRowView: View {
    let item: BookshelfItem
    let onTap: (() -> Void)?
    let onDelete: (() -> Void)?

    public init(item: BookshelfItem, onTap: (() -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.item = item
        self.onTap = onTap
        self.onDelete = onDelete
    }

    public var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 12) {
                coverPlaceholder

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)

                    if let author = item.author, !author.isEmpty {
                        Text(author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let lastChapter = item.lastReadChapterTitle, !lastChapter.isEmpty {
                        Text("Last: \(lastChapter)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    if item.readingProgress > 0 {
                        ProgressView(value: item.readingProgress)
                            .frame(maxWidth: 120)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var coverPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 50, height: 70)

            Image(systemName: "book.closed")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
        }
    }
}