import SwiftUI

struct RSSOriginalBrowserConfirmView: View {
    let url: URL?
    let title: String
    let sourceTitle: String
    let onReturnToReader: (() -> Void)?
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction
    @SwiftUI.Environment(\.openURL) private var openURL: OpenURLAction

    init(url: URL?, title: String, sourceTitle: String, onReturnToReader: (() -> Void)? = nil) {
        self.url = url
        self.title = title
        self.sourceTitle = sourceTitle
        self.onReturnToReader = onReturnToReader
    }

    init(urlString: String, title: String, sourceTitle: String, onReturnToReader: (() -> Void)? = nil) {
        self.init(
            url: URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
            title: title,
            sourceTitle: sourceTitle,
            onReturnToReader: onReturnToReader
        )
    }

    var body: some View {
        DemoBackScreen(title: "系统浏览器") {
            RSSBrowserConfirmCard(
                heading: "已准备打开原文链接",
                copy: copyText,
                detail: detailText
            )
        }
        .safeAreaInset(edge: .bottom) {
            BottomFixedActionRow {
                RSSBrowserConfirmButton(title: "返回原文页", isPrimary: false) {
                    dismiss()
                }
            } trailing: {
                RSSBrowserConfirmButton(title: "回到正文", isPrimary: true) {
                    confirmOpenAndReturn()
                }
                .disabled(url == nil)
            }
        }
    }

    private var copyText: String {
        let target = url?.host ?? url?.absoluteString ?? "当前原文链接"
        return "将调用系统浏览器打开 \(target)，同时保留 \(sourceTitle) 的 RSS 阅读上下文。"
    }

    private var detailText: String {
        if let url {
            return "\(title) · \(url.absoluteString)"
        }
        return "当前 RSS 条目没有可交给系统浏览器的 URL。"
    }

    private func confirmOpenAndReturn() {
        guard let url else { return }
        openURL(url)
        if let onReturnToReader {
            onReturnToReader()
        } else {
            dismiss()
        }
    }
}

private struct RSSBrowserConfirmCard: View {
    let heading: String
    let copy: String
    let detail: String

    var body: some View {
        VStack(spacing: ReaderDesignTokens.rssBrowserConfirmGap) {
            ReaderIcon(.globe, size: 22, accessibilityLabel: "系统浏览器")
                .frame(
                    width: ReaderDesignTokens.rssBrowserConfirmIconSize,
                    height: ReaderDesignTokens.rssBrowserConfirmIconSize
                )
                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.12)))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)

            Text(heading)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmTitleFontSize, weight: .heavy))
                .foregroundColor(SwiftUI.Color(red: 0x34/255, green: 0x2f/255, blue: 0x2a/255))
                .multilineTextAlignment(.center)
                .frame(maxWidth: ReaderDesignTokens.rssBrowserConfirmTextMaxWidth)

            Text(copy)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmBodyFontSize))
                .lineSpacing(ReaderDesignTokens.rssBrowserConfirmBodyFontSize * 0.7)
                .foregroundColor(SwiftUI.Color(red: 0x51/255, green: 0x48/255, blue: 0x3f/255))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: ReaderDesignTokens.rssBrowserConfirmTextMaxWidth)

            Text(detail)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmDetailFontSize))
                .lineSpacing(ReaderDesignTokens.rssBrowserConfirmDetailFontSize * 0.55)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .truncationMode(.middle)
                .frame(maxWidth: ReaderDesignTokens.rssBrowserConfirmTextMaxWidth)
        }
        .padding(.vertical, ReaderDesignTokens.rssBrowserConfirmVerticalPadding)
        .padding(.horizontal, ReaderDesignTokens.rssBrowserConfirmHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssBrowserConfirmCardMinHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .stroke(ReaderDesignTokens.Color.mainNavBorder.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: SwiftUI.Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }
}

private struct RSSBrowserConfirmButton: View {
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
