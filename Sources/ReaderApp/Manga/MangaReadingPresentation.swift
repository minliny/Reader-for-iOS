import ReaderDesign
import SwiftUI

enum MangaReadingPaper: String {
    case paper, ink
    var colors: ReaderTheme { ReaderTheme(night: self == .ink) }
}

struct MangaReadingToolbar: View {
    let title: String
    let chapter: String
    var controls = true
    var onBack: () -> Void = {}
    var onControls: () -> Void = {}
    var onDirectory: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            action("返回", ReaderIconRegistry.back, onBack)
                .accessibilityIdentifier("m3-manga-back")
            VStack(alignment: .leading, spacing: 2) {
                Text(title).readerTypography(ReaderDesignMetrics.mangaToolbarTitle).lineLimit(1)
                Text(chapter).readerTypography(ReaderDesignMetrics.mangaToolbarChapter)
                    .foregroundStyle(.secondary).lineLimit(1)
                    .accessibilityIdentifier("m3-manga-chapter-title")
            }
            Spacer(minLength: 4)
            action("目录", ReaderIconRegistry.directory, onDirectory).accessibilityIdentifier("m3-manga-directory")
            action(controls ? "收起漫画控制" : "展开漫画控制", ReaderIconRegistry.more, onControls)
                .accessibilityIdentifier("m3-manga-controls")
        }
        .frame(minHeight: CGFloat(ReaderDesignMetrics.mangaToolbarMinHeight))
        .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
    }

    private func action(_ label: String, _ icon: ReaderIconMapping, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            ReaderIcon(icon, squareSize: CGFloat(ReaderDesignMetrics.mangaToolbarActionIconSize))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct MangaUnavailablePage: View {
    var loading = false
    let height: CGFloat
    var pageIdentity: String?
    var onRetry: () -> Void = {}
    @Environment(\.readerTheme) private var theme

    var body: some View {
        VStack(spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
            if loading { ProgressView().tint(theme.accent) }
            else {
                ReaderIcon(ReaderIconRegistry.mangaImageUnavailable, squareSize: CGFloat(ReaderDesignMetrics.mangaUnavailableIconSize))
                    .foregroundStyle(theme.mutedText)
            }
            Text(loading ? "正在重试原图" : "这张图暂时无法加载")
                .readerTypography(ReaderDesignMetrics.rowLabel)
            Button("在原位重试", action: onRetry)
                .readerTypography(ReaderDesignMetrics.rowDetail)
                .frame(minHeight: 44)
                .disabled(loading)
                .accessibilityIdentifier("m3-manga-retry")
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .background(theme.mutedFill, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.mangaUnavailableCornerRadius)))
        .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("m3-manga-unavailable")
        .accessibilityValue(pageIdentity ?? "")
    }
}

struct MangaReadingDock: View {
    let page: Int64
    let total: Int64
    let direction: MangaDirection
    let paper: MangaReadingPaper
    var onDirection: (MangaDirection) -> Void = { _ in }
    var onPaper: (MangaReadingPaper) -> Void = { _ in }
    var onPage: (Int) -> Void = { _ in }
    var onLocate: () -> Void = {}
    var onSwitch: () -> Void = {}
    var onDownload: () -> Void = {}
    var previousChapter: (() -> Void)?
    var nextChapter: (() -> Void)?
    @Environment(\.readerTheme) private var theme

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                chip("条漫", direction == .vertical ? ReaderIconRegistry.mangaReadingVerticalSelected
                     : ReaderIconRegistry.mangaReadingVertical, selected: direction == .vertical) { onDirection(.vertical) }
                    .accessibilityIdentifier("m3-manga-vertical")
                chip("翻页", direction == .horizontal ? ReaderIconRegistry.mangaReadingHorizontalSelected
                     : ReaderIconRegistry.mangaReadingHorizontal, selected: direction == .horizontal) { onDirection(.horizontal) }
                    .accessibilityIdentifier("m3-manga-horizontal")
                Divider().frame(height: 20).padding(.horizontal, 3)
                chip("纸", paper == .paper ? ReaderIconRegistry.mangaPaperSelected : ReaderIconRegistry.mangaPaper,
                     selected: paper == .paper) { onPaper(.paper) }
                chip("墨", paper == .ink ? ReaderIconRegistry.mangaInkSelected : ReaderIconRegistry.mangaInk,
                     selected: paper == .ink) { onPaper(.ink) }
                Spacer(minLength: 1)
                chip("定位", ReaderIconRegistry.mangaLocate, action: onLocate)
                    .accessibilityIdentifier("m3-manga-locate")
            }
            Divider()
            HStack(spacing: 6) {
                step(-1).disabled(page <= 1)
                Text("\(page) / \(total)")
                    .monospacedDigit()
                    .readerTypography(ReaderDesignMetrics.mangaPageIndicator)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .accessibilityLabel("漫画页码")
                    .accessibilityValue("\(page)/\(total)")
                    .accessibilityIdentifier("m3-manga-page")
                step(1).disabled(page >= total)
                Divider().frame(height: 20)
                chip("换源", ReaderIconRegistry.sourceSwitch, action: onSwitch).accessibilityIdentifier("m3-manga-switch")
                chip("下载", ReaderIconRegistry.download, action: onDownload).accessibilityIdentifier("m3-manga-download")
            }
            if previousChapter != nil || nextChapter != nil {
                Divider()
                HStack {
                    Button("上一章") { previousChapter?() }.disabled(previousChapter == nil)
                    Spacer()
                    Button("下一章") { nextChapter?() }.disabled(nextChapter == nil)
                }
                .readerTypography(ReaderDesignMetrics.mangaChapterEndLabel)
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: CGFloat(ReaderDesignMetrics.mangaDockMaxWidth))
        .background(theme.panel, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.mangaDockRadius)))
        .overlay { RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.mangaDockRadius)).strokeBorder(theme.divider) }
        .shadow(color: theme.shadow.opacity(0.18), radius: 10, y: 4)
        .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
        .accessibilityIdentifier("m3-manga-dock")
    }

    private func chip(_ label: String, _ icon: ReaderIconMapping, selected: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                ReaderIcon(icon, squareSize: CGFloat(ReaderDesignMetrics.mangaControlIconSize))
                Text(label).readerTypography(ReaderDesignMetrics.mangaControlSection).lineLimit(1)
            }
            .foregroundStyle(selected ? theme.onAccent : theme.primaryText)
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .background(selected ? theme.accentFill : .clear, in: Capsule())
            .frame(minHeight: CGFloat(ReaderDesignMetrics.mangaControlMinHeight))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func step(_ offset: Int) -> some View {
        Button { onPage(offset) } label: {
            Image(systemName: offset < 0 ? "chevron.left" : "chevron.right")
                .frame(width: CGFloat(ReaderDesignMetrics.mangaDockStepPaintSize),
                       height: CGFloat(ReaderDesignMetrics.mangaDockStepPaintSize))
                .background(theme.mutedFill, in: Circle())
                .frame(width: CGFloat(ReaderDesignMetrics.mangaDockStepTargetSize),
                       height: CGFloat(ReaderDesignMetrics.mangaDockStepTargetSize))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(offset < 0 ? "上一页" : "下一页")
        .accessibilityIdentifier(offset < 0 ? "m3-manga-previous" : "m3-manga-next")
    }
}
