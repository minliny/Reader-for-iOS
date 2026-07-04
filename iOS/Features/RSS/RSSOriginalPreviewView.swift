import SwiftUI

struct RSSOriginalPreviewView: View {
    let url: URL?
    let title: String
    let sourceTitle: String
    private let onExit: (() -> Void)?
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction
    @State private var isBrowserConfirmPresented = false

    init(url: URL?, title: String, sourceTitle: String, onExit: (() -> Void)? = nil) {
        self.url = url
        self.title = title
        self.sourceTitle = sourceTitle
        self.onExit = onExit
    }

    init(urlString: String, title: String, sourceTitle: String, onExit: (() -> Void)? = nil) {
        self.init(
            url: URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
            title: title,
            sourceTitle: sourceTitle,
            onExit: onExit
        )
    }

    var body: some View {
        ZStack {
            if isBrowserConfirmPresented {
                RSSOriginalBrowserConfirmView(
                    url: url,
                    title: title,
                    sourceTitle: sourceTitle,
                    onReturnToReader: {
                        isBrowserConfirmPresented = false
                        close()
                    }
                )
            } else {
                DemoBackScreen(title: "原文页面", onBack: close) {
                    RSSOriginalHeader(
                        title: displayURL,
                        subtitle: "来自 \(sourceTitle) · 已保留 RSS 阅读上下文"
                    )

                    if url != nil {
                        RSSOriginalWebContainer(title: title)
                    } else {
                        RSSOriginalInvalidState()
                    }
                } bottomActionHost: {
                    BottomFixedActionRow {
                        RSSOriginalBottomButton(title: "返回正文", isPrimary: false) {
                            close()
                        }
                    } trailing: {
                        RSSOriginalBottomButton(title: "浏览器打开", isPrimary: true) {
                            openExternal()
                        }
                        .disabled(url == nil)
                    }
                }
            }
        }
    }

    private func close() {
        if let onExit {
            onExit()
        } else {
            dismiss()
        }
    }

    private func openExternal() {
        guard url != nil else { return }
        isBrowserConfirmPresented = true
    }

    private var displayURL: String {
        guard let url else { return "原文链接不可用" }
        if let host = url.host {
            return host + url.path
        }
        return url.absoluteString
    }
}

private struct RSSOriginalHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        ReaderCard {
            HStack(spacing: 9) {
                ReaderIcon(.link, size: 18, accessibilityLabel: "原文页面")
                    .frame(
                        width: ReaderDesignTokens.rssOriginalHeaderIconSize,
                        height: ReaderDesignTokens.rssOriginalHeaderIconSize
                    )
                    .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.12)))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: ReaderDesignTokens.rssOriginalHeaderMinHeight)
        }
    }
}

private struct RSSOriginalWebContainer: View {
    let title: String

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.rssOriginalPreviewGap) {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewTitleFontSize, weight: .heavy))
                    .lineLimit(2)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                Text("这里展示原文网页入口的预览状态。实际 APP 中应打开内置 WebView，并保留返回 RSS 阅读页、复制链接、分享和用浏览器打开。")
                    .font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewBodyFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach([0.82, 0.64, 0.44], id: \.self) { widthRatio in
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                            .fill(ReaderDesignTokens.Color.chipBackground.opacity(0.72))
                            .frame(maxWidth: .infinity, minHeight: 14)
                            .frame(width: 260 * widthRatio, alignment: .leading)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssOriginalWebPreviewMinHeight, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                        .fill(ReaderDesignTokens.Color.paperSolid.opacity(0.62))
                        .overlay(
                            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                                .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                        )
                )
            }
        }
    }
}

private struct RSSOriginalInvalidState: View {
    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.rssOriginalPreviewGap) {
                Text("原文链接不可用")
                    .font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                Text("当前 RSS 条目没有可打开的 URL，保留返回正文入口。")
                    .font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewBodyFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssOriginalWebPreviewMinHeight, alignment: .topLeading)
        }
    }
}

private struct RSSOriginalBottomButton: View {
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
