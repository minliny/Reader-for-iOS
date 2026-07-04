import SwiftUI
import ReaderCoreModels

struct RSSArticleDetailView: View {
    let item: SubscriptionItem
    let sourceTitle: String
    private let onExit: (() -> Void)?
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction
    @State private var isRead = true
    @State private var isStarred = false
    @State private var activeDestination: RSSArticleDestination?

    init(item: SubscriptionItem, sourceTitle: String, onExit: (() -> Void)? = nil) {
        self.item = item
        self.sourceTitle = sourceTitle
        self.onExit = onExit
    }

    var body: some View {
        ZStack {
            switch activeDestination {
            case .some(.original):
                RSSOriginalPreviewView(
                    url: originalURL,
                    title: item.title,
                    sourceTitle: resolvedSourceTitle,
                    onExit: { activeDestination = nil }
                )
            case .some(.sourceManagement):
                RSSSubscriptionManagementView(onExit: { activeDestination = nil })
            case .none:
                DemoBackScreen(title: "RSS 阅读", onBack: onExit) {
                    RSSReaderSourceCard(
                        sourceTitle: resolvedSourceTitle,
                        metaText: sourceMetaText,
                        link: item.link
                    )

                    RSSReaderTitleBlock(
                        title: item.title,
                        subtitle: cleanSummary.nonEmpty ?? Self.demoSummary
                    )

                    RSSReaderInlineActions(
                        isRead: $isRead,
                        isStarred: $isStarred,
                        openOriginal: openOriginal,
                        openSourceSettings: openSourceSettings
                    )

                    RSSReaderBody(paragraphs: bodyParagraphs)

                    RSSOriginalLinkCard(link: item.link, openOriginal: openOriginal)
                } bottomActionHost: {
                    BottomFixedActionRow {
                        RSSReaderBottomButton(title: "返回列表", isPrimary: false) {
                            close()
                        }
                    } trailing: {
                        RSSReaderBottomButton(title: "打开原文", isPrimary: true) {
                            openOriginal()
                        }
                        .disabled(originalURL == nil)
                    }
                }
            }
        }
    }

    private enum RSSArticleDestination {
        case original
        case sourceManagement
    }

    private func close() {
        if let onExit {
            onExit()
        } else {
            dismiss()
        }
    }

    private func openOriginal() {
        guard originalURL != nil else { return }
        activeDestination = .original
    }

    private func openSourceSettings() {
        activeDestination = .sourceManagement
    }

    static func fallbackItem(link: String) -> SubscriptionItem {
        SubscriptionItem(
            title: demoTitle,
            link: link.nonEmpty ?? demoLink,
            author: "开源项目",
            summary: demoSummary,
            publishedAt: nil,
            sourceId: "github-releases",
            sourceName: demoSourceTitle
        )
    }

    private var resolvedSourceTitle: String {
        item.sourceName?.nonEmpty ?? sourceTitle.nonEmpty ?? Self.demoSourceTitle
    }

    private var sourceMetaText: String {
        if item.title == Self.demoTitle {
            return "今天 10:18 · 开源项目 · 已解析正文"
        }
        let date = item.publishedAt.map(Self.dateFormatter.string(from:)) ?? "未标记时间"
        if let author = item.author?.nonEmpty {
            return "\(date) · \(author) · 已解析正文"
        }
        return "\(date) · 已解析正文"
    }

    private var cleanSummary: String {
        (item.summary ?? "")
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bodyParagraphs: [String] {
        if item.title == Self.demoTitle {
            return Self.demoBodyParagraphs
        }
        let summaryParagraphs = cleanSummary
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !summaryParagraphs.isEmpty {
            return summaryParagraphs
        }
        return Self.demoBodyParagraphs
    }

    private var originalURL: URL? {
        URL(string: item.link.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let demoTitle = "Reader UI 前端输入件更新说明"
    private static let demoSourceTitle = "GitHub Releases"
    private static let demoLink = "https://github.com/minliny/Reader-UI/releases/latest"
    private static let demoSummary = "本条目汇总最近的阅读体验修复、发现页状态补充和 RSS 页面结构调整。"
    private static let demoBodyParagraphs = [
        "RSS 页面现在以订阅源为一级对象，同时保留常规阅读器里的未读、全部、收藏和刷新工作流。主页负责快速浏览条目，阅读页则专注正文、原文和源相关操作。",
        "如果订阅源提供正文规则，文章应直接进入当前阅读页；如果源只提供链接，则在阅读页保留原文入口，并用 WebView 或外部浏览器作为兜底。",
        "后续实现里，已读状态应在进入阅读页时自动写入，收藏和源设置需要回到订阅源维度同步，不应该散落在主 Tab 的临时按钮里。"
    ]
}

private struct RSSReaderSourceCard: View {
    let sourceTitle: String
    let metaText: String
    let link: String

    var body: some View {
        ReaderCard {
            HStack(spacing: ReaderDesignTokens.rssSummaryGap) {
                ReaderIcon(.rss, size: 20, accessibilityLabel: "RSS 源")
                    .frame(
                        width: ReaderDesignTokens.rssReaderSourceIconColumn,
                        height: ReaderDesignTokens.rssReaderSourceIconSize
                    )
                    .background(
                        Circle()
                            .fill(ReaderDesignTokens.Color.primary.opacity(0.12))
                    )
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sourceTitle)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .lineLimit(1)
                    Text(metaText)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("查看源")
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 28)
                    .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
            }
            .frame(minHeight: ReaderDesignTokens.rssReaderSourceMinHeight)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct RSSReaderTitleBlock: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: ReaderDesignTokens.rssReaderTitleFontSize, weight: .heavy))
                .lineSpacing(ReaderDesignTokens.rssReaderTitleFontSize * (ReaderDesignTokens.rssReaderTitleLineHeight - 1))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(size: ReaderDesignTokens.rssReaderSubtitleFontSize))
                .lineSpacing(ReaderDesignTokens.rssReaderSubtitleFontSize * (ReaderDesignTokens.rssReaderSubtitleLineHeight - 1))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, ReaderDesignTokens.cardPadding)
        .padding(.vertical, 8)
    }
}

private struct RSSReaderInlineActions: View {
    @Binding var isRead: Bool
    @Binding var isStarred: Bool
    let openOriginal: () -> Void
    let openSourceSettings: () -> Void

    var body: some View {
        HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
            inlineButton(
                icon: .check,
                title: isRead ? "已读" : "标已读",
                isPrimary: true
            ) {
                isRead.toggle()
            }
            inlineButton(
                icon: .bookmark,
                title: isStarred ? "已收藏" : "收藏",
                isPrimary: false
            ) {
                isStarred.toggle()
            }
            inlineButton(
                icon: .sourceStack,
                title: "源设置",
                isPrimary: false,
                action: openSourceSettings
            )
        }
    }

    private func inlineButton(icon: ReaderAssetIcon, title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ReaderIcon(icon, size: 14)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
            .foregroundColor(isPrimary ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.readerModuleTextColor)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssReaderInlineActionMinHeight)
            .padding(.horizontal, 8)
            .background(
                Capsule()
                    .fill(isPrimary ? ReaderDesignTokens.Color.primary.opacity(0.12) : ReaderDesignTokens.Color.chipBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct RSSReaderBody: View {
    let paragraphs: [String]

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.rssReaderBodyParagraphGap) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(.system(size: ReaderDesignTokens.rssReaderBodyFontSize))
                        .lineSpacing(ReaderDesignTokens.rssReaderBodyFontSize * (ReaderDesignTokens.rssReaderBodyLineHeight - 1))
                        .foregroundColor(ReaderDesignTokens.Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
        }
        .textSelection(.enabled)
    }
}

private struct RSSOriginalLinkCard: View {
    let link: String
    let openOriginal: () -> Void

    var body: some View {
        ReaderCard {
            HStack(spacing: 9) {
                ReaderIcon(.link, size: 18, accessibilityLabel: "原文链接")
                    .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                    .background(Circle().fill(ReaderDesignTokens.Color.chipBackground))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                VStack(alignment: .leading, spacing: 2) {
                    Text("原文链接")
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .lineLimit(1)
                    Text(link)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("打开", action: openOriginal)
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 28)
                    .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
                    .buttonStyle(.plain)
            }
            .frame(minHeight: ReaderDesignTokens.rssReaderOriginalCardMinHeight)
        }
    }
}

private struct RSSReaderBottomButton: View {
    let title: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                .foregroundColor(isPrimary ? .white : ReaderDesignTokens.Color.primaryDark)
                .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
                .background(
                    Capsule()
                        .fill(isPrimary ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.surface)
                )
                .overlay(
                    Capsule()
                        .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: isPrimary ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
