import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct DirectorySheet: View {
    let chapters: [BookTocEntryData]
    let selected: Int64?
    let onSelect: (Int64) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DirectoryContent(chapters: chapters, selected: selected, onSelect: onSelect)
                .navigationTitle("目录")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                }
        }
    }
}

struct DirectoryContent: View {
    let chapters: [BookTocEntryData]
    let selected: Int64?
    let onSelect: (Int64) -> Void
    @Environment(\.readerTheme) private var theme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(chapters, id: \.index) { chapter in
                    Button { onSelect(chapter.index) } label: {
                        HStack(spacing: 12) {
                            Text((chapter.index + 1).formatted()).monospacedDigit()
                                .readerTypography(ReaderDesignMetrics.rowDetail, relativeTo: .caption)
                                .foregroundStyle(theme.mutedText).frame(minWidth: 24, alignment: .trailing)
                            Text(chapter.displayTitle ?? chapter.title)
                                .readerTypography(ReaderDesignMetrics.rowLabel, relativeTo: .body)
                                .foregroundStyle(selected == chapter.index ? theme.accent : theme.primaryText)
                                .lineLimit(2)
                            Spacer()
                            if selected == chapter.index {
                                Image(systemName: "book.fill").foregroundStyle(theme.accent)
                            }
                        }
                        .padding(.leading, CGFloat(max(0, min(4, chapter.level ?? 0))) * 10)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("directory-chapter-\(chapter.index)")
                    Rectangle().fill(theme.divider).frame(height: 1).accessibilityHidden(true)
                }
            }
            .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
        }
        .background(theme.background)
        .accessibilityIdentifier("book-directory")
    }
}
