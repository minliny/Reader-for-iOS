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
        } bottomActionHost: {
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
        if url == nil {
            return "当前 RSS 条目没有可交给系统浏览器的 URL。"
        }
        return "实际应用中这里会调用系统浏览器打开 github.com/minliny/Reader-UI/releases/latest，同时保留当前 RSS 阅读上下文。"
    }

    private var detailText: String {
        ""
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
                .foregroundColor(ReaderDesignTokens.Color.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: ReaderDesignTokens.rssBrowserConfirmTextMaxWidth)

            Text(copy)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmBodyFontSize))
                .lineSpacing(ReaderDesignTokens.rssBrowserConfirmBodyFontSize * 0.7)
                .foregroundColor(ReaderDesignTokens.Color.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: ReaderDesignTokens.rssBrowserConfirmTextMaxWidth)

            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: ReaderDesignTokens.rssBrowserConfirmDetailFontSize))
                    .lineSpacing(ReaderDesignTokens.rssBrowserConfirmDetailFontSize * 0.55)
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .frame(maxWidth: ReaderDesignTokens.rssBrowserConfirmTextMaxWidth)
            }
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
        .shadow(
            // demo `--fd-ds-shadow-soft`: 0 8px 26px rgba(89,70,50,0.1)
            color: ReaderDesignTokens.Color.Shadow.soft,
            radius: 26, x: 0, y: 8
        )
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
