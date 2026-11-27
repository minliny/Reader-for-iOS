import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct BookDetailContent: View {
    let book: BookshelfEntryData
    let chapters: [BookTocEntryData]
    let onRead: () -> Void
    let onDirectory: () -> Void
    let onRemove: () -> Void

    @Environment(\.readerTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center, spacing: 18) {
                    BookCover(entry: book).frame(width: 94, height: 132)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title).readerTypography(ReaderDesignMetrics.appTitle, relativeTo: .title)
                            .foregroundStyle(theme.primaryText).lineLimit(3)
                            .accessibilityIdentifier("detail-book-title")
                        if !book.author.isEmpty {
                            Text(book.author).readerTypography(ReaderDesignMetrics.rowLabel, relativeTo: .body)
                                .foregroundStyle(theme.secondaryText)
                        }
                        Label("本地藏书", systemImage: "internaldrive")
                            .readerTypography(ReaderDesignMetrics.rowDetail, relativeTo: .caption)
                            .foregroundStyle(theme.accent)
                    }
                }
                HStack(spacing: 12) {
                    Button(action: onRead) {
                        Label(book.readingPosition == nil ? "开始阅读" : "继续阅读", systemImage: "book")
                            .readerTypography(ReaderDesignMetrics.rowLabel)
                            .foregroundStyle(theme.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, 10)
                            .background(theme.accentFill,
                                        in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.inputRadius)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("detail-read")
                    Button(action: onDirectory) {
                        Label("目录 · \(chapters.count)", systemImage: "list.bullet")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("detail-directory")
                }
                if let intro = book.intro, !intro.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("简介").readerTypography(ReaderDesignMetrics.pageTitle, relativeTo: .headline)
                        Text(intro).readerTypography(ReaderDesignMetrics.rowLabel, relativeTo: .body)
                            .foregroundStyle(theme.secondaryText).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let chapter = book.currentChapterTitle {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("阅读位置").readerTypography(ReaderDesignMetrics.sectionHeading, relativeTo: .subheadline)
                        Text(chapter).readerTypography(ReaderDesignMetrics.rowLabel, relativeTo: .body)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                Button("移出书架", role: .destructive, action: onRemove)
                    .buttonStyle(.bordered).accessibilityIdentifier("detail-remove")
            }
            .padding(CGFloat(ReaderDesignMetrics.screenInset))
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
    }
}
