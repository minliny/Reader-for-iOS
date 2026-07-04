import SwiftUI

struct BookDirectoryPreviewView: View {
    enum Mode: String, CaseIterable {
        case directory = "目录"
        case bookmark = "书签"
    }

    let bookURL: String
    let title: String
    let onExit: (() -> Void)?
    @State private var mode: Mode = .directory

    init(bookURL: String = "demo://book/long-night", title: String = "长夜余火", onExit: (() -> Void)? = nil) {
        self.bookURL = bookURL
        self.title = title
        self.onExit = onExit
    }

    var body: some View {
        DemoBackScreen(title: "书籍目录", onBack: onExit) {
            directoryCard
        }
    }

    private var visibleChapters: [BookDirectoryChapter] {
        switch mode {
        case .directory:
            return BookDirectoryChapter.demoChapters
        case .bookmark:
            return BookDirectoryChapter.demoChapters.filter(\.isBookmarked)
        }
    }

    private var directoryCard: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.bookDirectoryFullGap) {
            header
            modeSwitch
            chapterRows
        }
        .padding(.top, ReaderDesignTokens.bookDirectoryFullTopPadding)
        .padding(.horizontal, ReaderDesignTokens.bookDirectoryFullHorizontalPadding)
        .padding(.bottom, ReaderDesignTokens.bookDirectoryFullBottomPadding)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                )
                .shadow(
                    // demo `--reader-ds-shadow-soft`: 0 8px 26px rgba(89,70,50,0.1)
                    color: ReaderDesignTokens.Color.Shadow.soft,
                    radius: 26,
                    x: 0,
                    y: 8
                )
        )
        .padding(.top, ReaderDesignTokens.bookDirectoryListTopPadding - ReaderDesignTokens.demoContentVerticalPadding)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("书籍目录")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: ReaderDesignTokens.readerTopTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderDesignTokens.Color.ink)
                .lineLimit(1)
            Text("爱潜水的乌贼 · 共 \(BookDirectoryChapter.demoChapters.count) 章")
                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .medium))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookDirectoryHeaderMinHeight, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private var modeSwitch: some View {
        HStack(spacing: ReaderDesignTokens.bookDirectorySwitchGap) {
            ForEach(Mode.allCases, id: \.self) { item in
                Button {
                    mode = item
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .bold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookDirectorySwitchButtonMinHeight)
                        .foregroundColor(mode == item ? .white : ReaderDesignTokens.Color.controlInkAlt)
                        .background(
                            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                                .fill(mode == item ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.chipBackground.opacity(0.70))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == item ? [.isButton, .isSelected] : [.isButton])
            }
        }
    }

    private var chapterRows: some View {
        VStack(spacing: 0) {
            ForEach(visibleChapters) { chapter in
                BookDirectoryChapterRow(chapter: chapter)
                if chapter.id != visibleChapters.last?.id {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .background(ReaderDesignTokens.Color.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                .stroke(ReaderDesignTokens.Color.readerModuleNavBorder, lineWidth: 1)
        )
    }
}

private struct BookDirectoryChapter: Identifiable, Hashable {
    let id: String
    let title: String
    let isCurrent: Bool
    let isCached: Bool
    let isBookmarked: Bool

    static let demoChapters: [BookDirectoryChapter] = [
        BookDirectoryChapter(id: "chapter-30", title: "第 30 章 旧日", isCurrent: false, isCached: true, isBookmarked: false),
        BookDirectoryChapter(id: "chapter-31", title: "第 31 章 归途", isCurrent: false, isCached: true, isBookmarked: true),
        BookDirectoryChapter(id: "chapter-32", title: "第 32 章 雨夜", isCurrent: true, isCached: false, isBookmarked: true),
        BookDirectoryChapter(id: "chapter-33", title: "第 33 章 灯塔", isCurrent: false, isCached: false, isBookmarked: false),
        BookDirectoryChapter(id: "chapter-34", title: "第 34 章 旧地图", isCurrent: false, isCached: true, isBookmarked: false),
        BookDirectoryChapter(id: "chapter-35", title: "第 35 章 夜行", isCurrent: false, isCached: false, isBookmarked: false),
        BookDirectoryChapter(id: "chapter-36", title: "第 36 章 灯塔之后", isCurrent: false, isCached: false, isBookmarked: true)
    ]
}

private struct BookDirectoryChapterRow: View {
    let chapter: BookDirectoryChapter

    var body: some View {
        HStack(spacing: ReaderDesignTokens.bookGroupRowGap) {
            Text(chapter.title)
                .font(.system(size: ReaderDesignTokens.readerSectionTitleFontSize, weight: chapter.isCurrent ? .heavy : .regular))
                .foregroundColor(chapter.isCurrent ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: ReaderDesignTokens.bookDirectoryMarkerGap) {
                markerIcon(chapter.isCached ? .check : .download, isActive: chapter.isCached, accessibilityLabel: chapter.isCached ? "已缓存" : "未缓存")
                markerIcon(.bookmark, isActive: chapter.isBookmarked, accessibilityLabel: chapter.isBookmarked ? "书签" : "无书签")
            }
            .frame(width: ReaderDesignTokens.bookDirectoryMarkerColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, ReaderDesignTokens.bookDirectoryFullHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookDirectoryRowMinHeight, alignment: .leading)
        .background(chapter.isCurrent ? ReaderDesignTokens.Color.primary.opacity(0.08) : SwiftUI.Color.clear)
        .contentShape(Rectangle())
        .accessibilityLabel(chapter.title)
    }

    private func markerIcon(_ icon: ReaderAssetIcon, isActive: Bool, accessibilityLabel: String) -> some View {
        ReaderIcon(icon, size: 14, accessibilityLabel: accessibilityLabel)
            .foregroundColor(isActive ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.muted.opacity(0.58))
            .frame(width: ReaderDesignTokens.bookDirectoryMarkerSize, height: ReaderDesignTokens.bookDirectoryMarkerSize)
            .background(
                Capsule()
                    .fill(isActive ? ReaderDesignTokens.Color.primary.opacity(0.12) : ReaderDesignTokens.Color.chipBackground.opacity(0.82))
            )
    }
}
