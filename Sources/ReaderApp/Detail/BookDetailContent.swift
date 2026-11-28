import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct BookDetailContent: View {
    let book: BookshelfEntryData
    let chapters: [BookTocEntryData]
    let onRead: () -> Void
    let onDirectory: () -> Void
    let onRemove: () -> Void
    var onShelfAction: () -> Void = {}
    var onSelectChapter: ((Int64) -> Void)? = nil

    @Environment(\.readerTheme) private var theme
    @State private var introExpanded = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceMedium)) {
                    detailInfoCard
                    summaryCard
                    directoryPreview
                    Color.clear.frame(height: 96)
                }
                .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
                .padding(.top, CGFloat(ReaderDesignMetrics.spaceMedium))
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(theme.background)
            detailFooter
        }
        .foregroundStyle(theme.primaryText)
        .accessibilityIdentifier("book-detail-content")
    }

    private var detailInfoCard: some View {
        HStack(alignment: .top, spacing: CGFloat(ReaderDesignMetrics.spaceMedium)) {
            BookCover(entry: book).frame(width: 108, height: 148)
            VStack(alignment: .leading, spacing: 7) {
                Text(book.title)
                    .readerTypography(ReaderDesignMetrics.appTitle, relativeTo: .title)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(3)
                    .accessibilityIdentifier("detail-book-title")
                if !book.author.isEmpty {
                    Text(book.author)
                        .readerTypography(ReaderDesignMetrics.rowLabel, relativeTo: .body)
                        .foregroundStyle(theme.secondaryText)
                }
                if book.sourceId != "local", let latest = book.lastChapter, !latest.isEmpty {
                    Text("最新：\(latest)")
                        .readerTypography(ReaderDesignMetrics.rowDetail, relativeTo: .caption)
                        .foregroundStyle(theme.secondaryText)
                }
                Text(book.sourceName ?? (book.sourceId == "local" ? "本地文件" : "书源未知"))
                    .readerTypography(ReaderDesignMetrics.rowDetail, relativeTo: .caption)
                    .foregroundStyle(theme.accent)
                if let group = book.group, !group.isEmpty {
                    Text(group)
                        .readerTypography(ReaderDesignMetrics.rowDetail, relativeTo: .caption)
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(theme.accentTint, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(CGFloat(ReaderDesignMetrics.cardPadding))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: .rect(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
        .overlay(RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)).stroke(theme.outline, lineWidth: 1))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceExtraSmall)) {
            Text("内容简介")
                .readerTypography(ReaderDesignMetrics.pageTitle, relativeTo: .headline)
            Text(book.intro?.isEmpty == false ? book.intro! : "暂无简介")
                .readerTypography(ReaderDesignMetrics.rowLabel, relativeTo: .body)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(introExpanded ? nil : 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let intro = book.intro, intro.count > 120 {
                Button(introExpanded ? "收起" : "展开全部") { introExpanded.toggle() }
                    .readerTypography(ReaderDesignMetrics.rowDetail)
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .buttonStyle(.plain)
            }
        }
        .padding(CGFloat(ReaderDesignMetrics.cardPadding))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: .rect(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
        .overlay(RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)).stroke(theme.outline, lineWidth: 1))
        .accessibilityIdentifier("detail-summary-card")
    }

    private var directoryPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("目录预览").readerTypography(ReaderDesignMetrics.pageTitle, relativeTo: .headline)
                Text("\(chapters.count) 章").readerTypography(ReaderDesignMetrics.rowDetail)
                    .foregroundStyle(theme.secondaryText).monospacedDigit()
                Spacer()
                Button { onDirectory() } label: {
                    Label("完整目录", systemImage: "list.bullet")
                        .readerTypography(ReaderDesignMetrics.rowDetail)
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 10).frame(minHeight: 32)
                        .background(theme.field, in: Capsule())
                        .overlay(Capsule().stroke(theme.outline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("detail-directory")
            }
            .padding(CGFloat(ReaderDesignMetrics.cardPadding))
            ForEach(Array(chapters.prefix(4)), id: \.index) { chapter in
                Button { onReadChapter(chapter) } label: {
                    HStack(spacing: 8) {
                        Text(chapter.displayTitle ?? chapter.title)
                            .readerTypography(ReaderDesignMetrics.rowLabel)
                            .foregroundStyle(chapter.index == book.currentChapterIndex ? theme.accent : theme.primaryText)
                            .lineLimit(1)
                        if chapter.index == book.currentChapterIndex {
                            Text("在读").readerTypography(ReaderDesignMetrics.rowDetail)
                                .foregroundStyle(theme.onAccent)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(theme.accentFill, in: Capsule())
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(theme.secondaryText)
                    }
                    .padding(.horizontal, CGFloat(ReaderDesignMetrics.cardPadding))
                    .frame(minHeight: 44)
                    .overlay(alignment: .top) { Rectangle().fill(theme.divider).frame(height: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("detail-preview-chapter-\(chapter.index)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: .rect(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
        .overlay(RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)).stroke(theme.outline, lineWidth: 1))
        .clipShape(.rect(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
        .accessibilityIdentifier("detail-directory-preview")
    }

    private func onReadChapter(_ chapter: BookTocEntryData) {
        if let onSelectChapter { onSelectChapter(chapter.index) } else { onRead() }
    }

    private var detailFooter: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [theme.background.opacity(0), theme.background], startPoint: .top, endPoint: .bottom)
                .frame(height: 26)
            HStack(spacing: 8) {
                Button(action: onRead) {
                    Text(book.readingPosition == nil ? "开始阅读" : "继续阅读")
                        .readerTypography(ReaderDesignMetrics.rowLabel)
                        .foregroundStyle(theme.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(theme.accentFill, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("detail-read")
                Button(action: onShelfAction) {
                    Text("已在书架")
                        .readerTypography(ReaderDesignMetrics.rowDetail)
                        .foregroundStyle(theme.accent)
                        .frame(width: 94, minHeight: 44)
                        .background(theme.surface, in: Capsule())
                        .overlay(Capsule().stroke(theme.outline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("detail-shelf-state")
            }
            .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
            .padding(.bottom, 8)
            .background(theme.background)
        }
        .accessibilityIdentifier("detail-footer-dock")
    }
}
