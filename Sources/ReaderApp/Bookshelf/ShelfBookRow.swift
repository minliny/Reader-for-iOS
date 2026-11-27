import ImageIO
import ReaderCoreBridge
import ReaderDesign
import SwiftUI
import UIKit

struct BookCover: View {
    let entry: BookshelfEntryData
    @Environment(\.readerTheme) private var theme
    @State private var retainedCover: UIImage?

    var body: some View {
        Group {
            if let retainedCover {
                GeometryReader { geometry in
                    Image(uiImage: retainedCover).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
            } else { placeholder }
        }
        .accessibilityHidden(true)
        .task(id: entry.coverUrl) { retainedCover = decodeCover() }
    }

    private var placeholder: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 7).fill(theme.accentTint)
            Rectangle().fill(theme.accent.opacity(0.30)).frame(width: 3)
                .padding(.vertical, 7).padding(.leading, 5)
            VStack(alignment: .leading, spacing: 7) {
                Text(entry.title)
                    .readerTypography(ReaderDesignMetrics.shelfTitle, relativeTo: .caption)
                    .foregroundStyle(theme.accent)
                    .lineLimit(3)
                Spacer(minLength: 2)
                Text("本地").font(.system(size: 8, weight: .semibold)).foregroundStyle(theme.accent)
            }
            .padding(.horizontal, 8).padding(.vertical, 8)
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private func decodeCover() -> UIImage? {
        guard let uri = entry.coverUrl, uri.utf8.count <= 3 * 1024 * 1024,
              let separator = uri.firstIndex(of: ",") else { return nil }
        let header = uri[..<separator].lowercased()
        guard header.hasPrefix("data:image/"), header.hasSuffix(";base64"),
              let data = Data(base64Encoded: String(uri[uri.index(after: separator)...])),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 320
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}

struct ShelfBookRow: View {
    let entry: BookshelfEntryData
    let narrow: Bool
    let selected: Bool
    let onOpen: () -> Void
    let onRemove: () -> Void
    @Environment(\.readerTheme) private var theme
    @Environment(\.dynamicTypeSize) private var size

    var body: some View {
        let compact = narrow || size.isAccessibilitySize
        let height = CGFloat(ReaderDesignMetrics.shelfCoverHeight) + (compact ? 10 : 0)
        HStack(alignment: .top, spacing: CGFloat(ReaderDesignMetrics.shelfListColumnSpacing)) {
            Button(action: onOpen) {
                HStack(spacing: CGFloat(ReaderDesignMetrics.shelfListColumnSpacing)) {
                    BookCover(entry: entry)
                        .frame(width: CGFloat(ReaderDesignMetrics.shelfCoverWidth), height: height)
                    information(compact: compact)
                        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("shelf-book-\(entry.bookId)")
            Menu {
                Button("查看详情", action: onOpen)
                Button("移出书架", role: .destructive, action: onRemove)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 28, height: 32, alignment: .center)
            }
            .accessibilityLabel("书籍更多操作")
        }
        .padding(CGFloat(ReaderDesignMetrics.shelfCardPadding))
        .background(selected ? theme.accentTint : theme.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
    }

    private func information(compact: Bool) -> some View {
        ViewThatFits(in: .vertical) {
            metadata(author: true, chapter: true, showProgress: true)
            metadata(author: true, chapter: false, showProgress: true)
            metadata(author: false, chapter: false, showProgress: true)
            metadata(author: false, chapter: false, showProgress: false)
        }
        .dynamicTypeSize(...(compact ? .accessibility2 : .accessibility1))
    }

    private func metadata(author: Bool, chapter: Bool, showProgress: Bool) -> some View {
        let progress = min(1, max(0, Double(entry.readProgress ?? 0) / 100))
        return VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
            Text(entry.title)
                .readerTypography(ReaderDesignMetrics.shelfTitle, relativeTo: .body)
                .foregroundStyle(theme.primaryText)
                .lineLimit(ReaderDesignMetrics.shelfTitleMaxLines)
            if author, !entry.author.isEmpty {
                Text(entry.author)
                    .readerTypography(ReaderDesignMetrics.shelfAuthor, relativeTo: .caption)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            if chapter {
                Text(entry.currentChapterTitle ?? (entry.readingPosition == nil ? "尚未阅读" : "已保存阅读位置"))
                    .readerTypography(ReaderDesignMetrics.shelfChapter, relativeTo: .caption)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            if showProgress {
                HStack(spacing: 5) {
                    ProgressView(value: progress).tint(theme.accent)
                    Text(progress.formatted(.percent))
                        .readerTypography(ReaderDesignMetrics.shelfProgress, relativeTo: .caption2)
                        .foregroundStyle(theme.mutedText).lineLimit(1)
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
