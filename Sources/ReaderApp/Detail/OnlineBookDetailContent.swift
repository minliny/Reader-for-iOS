import ReaderDesign
import ReaderHost
import SwiftUI

struct OnlineBookDetailContent: View {
    let book: OnlineBookReference
    var onAdd: () -> Void = {}
    var onRead: () -> Void = {}
    var onSwitch: () -> Void = {}
    var onDownloads: () -> Void = {}
    var onDirectory: () -> Void = {}
    var onRefresh: () -> Void = {}
    var onRemove: (() -> Void)?
    var isShelved = false
    var busy = false
    var network: NetworkAndWebHost? = nil
    @Environment(\.readerTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= CGFloat(ReaderDesignMetrics.wideBreakpoint)
            ScrollView {
                if wide {
                    HStack(alignment: .top, spacing: CGFloat(ReaderDesignMetrics.spaceLarge)) {
                        VStack(spacing: CGFloat(ReaderDesignMetrics.spaceMedium)) {
                            hero(wide: true)
                            actions
                        }
                        summary
                    }
                    .padding(CGFloat(ReaderDesignMetrics.screenInset))
                } else {
                    VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceMedium)) {
                        hero(wide: false)
                        actions
                        summary
                    }
                    .padding(CGFloat(ReaderDesignMetrics.screenInset))
                }
            }
        }
        .background(theme.background)
    }

    private func hero(wide: Bool) -> some View {
        HStack(alignment: .top, spacing: CGFloat(ReaderDesignMetrics.spaceMedium)) {
            OnlineBookCover(book: book, width: CGFloat(ReaderDesignMetrics.onlineDetailCoverWidth),
                            height: CGFloat(ReaderDesignMetrics.onlineDetailCoverHeight),
                            radius: CGFloat(ReaderDesignMetrics.onlineDetailCoverRadius), network: network)
            VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceExtraSmall)) {
                Text(book.title)
                    .readerTypography(wide ? ReaderDesignMetrics.onlineDetailWideTitle : ReaderDesignMetrics.onlineDetailTitle)
                    .accessibilityAddTraits(.isHeader)
                    .lineLimit(3)
                    .accessibilityIdentifier("m2-detail-page")
                if let author = book.author, !author.isEmpty {
                    Text(author).readerTypography(ReaderDesignMetrics.onlineReadingMetadata)
                        .foregroundStyle(theme.secondaryText)
                }
                Label { Text(book.displaySource).lineLimit(2) } icon: {
                    ReaderIcon(ReaderIconRegistry.sourceSwitch, squareSize: CGFloat(ReaderDesignMetrics.onlineReadingMetadata.fontSize))
                }
                .readerTypography(ReaderDesignMetrics.onlineReadingMetadata)
                .foregroundStyle(theme.secondaryText)
                if let chapter = book.lastChapter, !chapter.isEmpty {
                    Text(chapter)
                        .readerTypography(ReaderDesignMetrics.onlineReadingMetadata)
                        .foregroundStyle(theme.accent)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(CGFloat(ReaderDesignMetrics.cardPadding))
        .background(theme.surface, in: .rect(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
    }

    private var actions: some View {
        VStack(spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
            HStack(spacing: CGFloat(ReaderDesignMetrics.controlInlineSpacing)) {
                button("开始阅读", icon: ReaderIconRegistry.shelf, prominent: true, id: "m2-detail-read", action: onRead)
                if isShelved {
                    button("已加入书架", icon: ReaderIconRegistry.checkCircle, id: "m2-detail-add", action: {})
                        .disabled(true)
                } else {
                    button("加入书架", icon: ReaderIconRegistry.add, id: "m2-detail-add", action: onAdd)
                }
            }
            let minimum: CGFloat = typeSize.isAccessibilitySize ? 140 : (onRemove == nil ? 84 : 106)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum))], spacing: CGFloat(ReaderDesignMetrics.spaceExtraSmall)) {
                button("目录", icon: ReaderIconRegistry.directory, id: "m2-detail-directory", action: onDirectory)
                button("换源", icon: ReaderIconRegistry.sourceSwitch, id: "m2-detail-switch", action: onSwitch)
                button("下载", icon: ReaderIconRegistry.download, id: "m2-detail-downloads", action: onDownloads)
                button("刷新", icon: ReaderIconRegistry.refresh, id: "m2-detail-refresh", action: onRefresh)
                if let onRemove {
                    button("移出书架", icon: ReaderIconRegistry.delete, id: "m2-detail-remove", action: onRemove)
                }
            }
        }
        .disabled(busy)
    }

    private var summary: some View {
        Group {
            if let intro = book.intro, !intro.isEmpty {
                VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceExtraSmall)) {
                    Text("简介").readerTypography(ReaderDesignMetrics.pageTitle)
                        .accessibilityAddTraits(.isHeader)
                    Text(intro).readerTypography(ReaderDesignMetrics.onlineDetailSummary)
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CGFloat(ReaderDesignMetrics.cardPadding))
                .background(theme.surface, in: .rect(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
            }
        }
    }

    private func button(_ title: String, icon: ReaderIconMapping, prominent: Bool = false,
                        id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(title).lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                ReaderIcon(icon, squareSize: CGFloat(ReaderDesignMetrics.onlineDetailAction.fontSize))
            }
                .readerTypography(ReaderDesignMetrics.onlineDetailAction)
                .foregroundStyle(prominent ? theme.onAccent : theme.accent)
                .frame(maxWidth: .infinity, minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
                .padding(.horizontal, CGFloat(ReaderDesignMetrics.spaceExtraSmall))
                .background(prominent ? theme.accentFill : theme.elevated, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
