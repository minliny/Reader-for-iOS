import SwiftUI
import ReaderCoreModels

struct RSSArticleDetailView: View {
    let item: SubscriptionItem
    let sourceTitle: String
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction
    @State private var isRead = true
    @State private var isStarred = false
    @State private var isOriginalPresented = false
    @State private var isSourceManagementPresented = false

    init(item: SubscriptionItem, sourceTitle: String) {
        self.item = item
        self.sourceTitle = sourceTitle
    }

    var body: some View {
        DemoBackScreen(title: "RSS 阅读") {
            RSSReaderSourceCard(
                sourceTitle: resolvedSourceTitle,
                metaText: sourceMetaText,
                link: item.link
            )

            RSSReaderTitleBlock(
                title: item.title,
                subtitle: cleanSummary.nonEmpty ?? "已进入 RSS 阅读上下文，正文和原文入口保持在同一个二级页面。"
            )

            RSSReaderInlineActions(
                isRead: $isRead,
                isStarred: $isStarred,
                openOriginal: openOriginal,
                openSourceSettings: openSourceSettings
            )

            RSSReaderBody(paragraphs: bodyParagraphs)

            RSSOriginalLinkCard(link: item.link, openOriginal: openOriginal)
        }
        .navigationDestination(isPresented: $isOriginalPresented) {
            RSSOriginalPreviewView(
                url: originalURL,
                title: item.title,
                sourceTitle: resolvedSourceTitle
            )
        }
        .navigationDestination(isPresented: $isSourceManagementPresented) {
            RSSSubscriptionManagementView()
        }
        .safeAreaInset(edge: .bottom) {
            BottomFixedActionRow {
                RSSReaderBottomButton(title: "返回列表", isPrimary: false) {
                    dismiss()
                }
            } trailing: {
                RSSReaderBottomButton(title: "打开原文", isPrimary: true) {
                    openOriginal()
                }
                .disabled(originalURL == nil)
            }
        }
    }

    static func fallbackItem(link: String) -> SubscriptionItem {
        SubscriptionItem(
            title: "RSS 阅读",
            link: link,
            author: nil,
            summary: "该入口来自全局 RSS detail route。真实列表进入时会带入订阅条目的标题、摘要、作者和发布时间。",
            publishedAt: nil,
            sourceId: "route-fallback",
            sourceName: "RSS"
        )
    }

    private var resolvedSourceTitle: String {
        item.sourceName?.nonEmpty ?? sourceTitle.nonEmpty ?? "RSS"
    }

    private var sourceMetaText: String {
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
        let summaryParagraphs = cleanSummary
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !summaryParagraphs.isEmpty {
            return summaryParagraphs
        }
        return [
            "该订阅条目尚未提供完整正文，当前页面保留 RSS 阅读结构、已读/收藏操作和原文入口。",
            "如果订阅源后续提供正文规则，正文会直接渲染在这里；如果只提供链接，则通过原文入口进入 WebView 或系统浏览器。"
        ]
    }

    private var originalURL: URL? {
        URL(string: item.link.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func openOriginal() {
        guard originalURL != nil else { return }
        isOriginalPresented = true
    }

    private func openSourceSettings() {
        isSourceManagementPresented = true
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
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
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                        .lineLimit(1)
                    Text(metaText)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("查看源")
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .heavy))
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
                .foregroundStyle(.secondary)
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
            .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .heavy))
            .foregroundColor(isPrimary ? ReaderDesignTokens.Color.primaryDark : SwiftUI.Color(red: 0x4d/255, green: 0x46/255, blue: 0x3f/255))
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
                        .foregroundColor(SwiftUI.Color(red: 0x34/255, green: 0x2f/255, blue: 0x2a/255))
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
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                        .lineLimit(1)
                    Text(link)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("打开", action: openOriginal)
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .heavy))
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
                .font(.system(size: 13, weight: .heavy))
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
