import SwiftUI
import WebKit

struct RSSOriginalPreviewView: View {
    let url: URL?
    let title: String
    let sourceTitle: String
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction
    @State private var isBrowserConfirmPresented = false

    init(url: URL?, title: String, sourceTitle: String) {
        self.url = url
        self.title = title
        self.sourceTitle = sourceTitle
    }

    init(urlString: String, title: String, sourceTitle: String) {
        self.init(
            url: URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
            title: title,
            sourceTitle: sourceTitle
        )
    }

    var body: some View {
        DemoBackScreen(title: "原文页面") {
            RSSOriginalHeader(
                title: url?.host ?? url?.absoluteString ?? "原文链接不可用",
                subtitle: "来自 \(sourceTitle) · 已保留 RSS 阅读上下文"
            )

            if let url {
                RSSOriginalWebContainer(url: url, title: title)
            } else {
                RSSOriginalInvalidState()
            }
        }
        .navigationDestination(isPresented: $isBrowserConfirmPresented) {
            RSSOriginalBrowserConfirmView(
                url: url,
                title: title,
                sourceTitle: sourceTitle,
                onReturnToReader: {
                    isBrowserConfirmPresented = false
                    dismiss()
                }
            )
        }
        .safeAreaInset(edge: .bottom) {
            BottomFixedActionRow {
                RSSOriginalBottomButton(title: "返回正文", isPrimary: false) {
                    dismiss()
                }
            } trailing: {
                RSSOriginalBottomButton(title: "浏览器打开", isPrimary: true) {
                    openExternal()
                }
                .disabled(url == nil)
            }
        }
    }

    private func openExternal() {
        guard url != nil else { return }
        isBrowserConfirmPresented = true
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
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: ReaderDesignTokens.rssOriginalHeaderMinHeight)
        }
    }
}

private struct RSSOriginalWebContainer: View {
    let url: URL
    let title: String

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.rssOriginalPreviewGap) {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewTitleFontSize, weight: .heavy))
                    .lineLimit(2)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                Text("内置 WebView 预览原文；返回时保留 RSS 阅读页上下文。")
                    .font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewBodyFontSize))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                RSSOriginalWebView(url: url)
                    .frame(minHeight: ReaderDesignTokens.rssOriginalWebPreviewMinHeight)
                    .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                            .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
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
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssOriginalWebPreviewMinHeight, alignment: .topLeading)
        }
    }
}

private struct RSSOriginalWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.backgroundColor = UIColor.clear
        webView.backgroundColor = UIColor.clear
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
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
