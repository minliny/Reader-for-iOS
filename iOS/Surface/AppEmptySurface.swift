import SwiftUI

public struct AppEmptySurface: View {
    let title: String
    let message: String
    let icon: ReaderAssetIcon
    let actionTitle: String?
    let onAction: (() -> Void)?

    public init(
        title: String,
        message: String,
        icon: ReaderAssetIcon = .file,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    public var body: some View {
        VStack(spacing: 20) {
            ReaderIcon(icon, size: 48, accessibilityLabel: title)
                .foregroundColor(ReaderDesignTokens.Color.muted)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                Text(message)
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let actionTitle = actionTitle, let action = onAction {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .foregroundColor(.white)
                        .frame(minWidth: 100, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
                        .background(Capsule().fill(ReaderDesignTokens.Color.primary))
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}
