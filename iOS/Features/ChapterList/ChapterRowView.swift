import SwiftUI
import ReaderCoreModels

public struct ChapterRowView: View {
    let chapter: TOCItem
    let onTap: (() -> Void)?

    public init(chapter: TOCItem, onTap: (() -> Void)? = nil) {
        self.chapter = chapter
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 12) {
                let index = chapter.chapterIndex
                Text("\(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .leading)

                Text(chapter.chapterTitle)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}