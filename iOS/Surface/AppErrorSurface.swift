import SwiftUI
import ReaderCoreModels

public struct AppErrorSurface: View {
    let error: ReaderError?
    let onRetry: (() -> Void)?

    public init(error: ReaderError?, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
    }

    public var body: some View {
        if let error = error {
            VStack(spacing: 16) {
                ReaderIcon(.warning, size: 34, accessibilityLabel: "错误")
                    .foregroundColor(ReaderDesignTokens.Color.Semantic.danger)

                Text(error.message)
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                if let failureType = error.failure?.type {
                    Text("Failure: \(failureType.rawValue)")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                }

                if let retry = onRetry {
                    Button(action: retry) {
                        Text("重试")
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                            .foregroundColor(.white)
                            .frame(minWidth: 100, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
                            .background(Capsule().fill(ReaderDesignTokens.Color.primary))
                    }
                    .padding(.top, 8)
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ReaderDesignTokens.Color.paperSolid)
            .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md))
            .shadow(
                // demo `--reader-ds-shadow-soft`: 0 8px 26px rgba(89,70,50,0.1)
                color: ReaderDesignTokens.Color.Shadow.soft,
                radius: 26, x: 0, y: 8
            )
        }
    }
}
