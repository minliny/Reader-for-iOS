import SwiftUI

public enum ReaderPageState: Sendable, Equatable {
    case loading
    case empty(String)
    case failed(String, actionGeneration: Int?)
}

public struct PageState: View {
    @Environment(\.readerTheme) private var theme
    private let state: ReaderPageState
    private let onRetry: (Int) -> Void

    public init(state: ReaderPageState, onRetry: @escaping (Int) -> Void = { _ in }) {
        self.state = state
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
            switch state {
            case .loading:
                ProgressView("正在载入")
                    .foregroundStyle(theme.secondaryText)
            case .empty(let text):
                ReaderIcon(ReaderIconRegistry.shelf)
                    .font(.title2)
                    .foregroundStyle(theme.accent)
                Text(text)
                    .foregroundStyle(theme.secondaryText)
            case .failed(let text, let actionGeneration):
                Image(systemName: "exclamationmark.circle")
                    .font(.title2)
                    .foregroundStyle(theme.danger)
                    .accessibilityHidden(true)
                Text(text)
                    .foregroundStyle(theme.secondaryText)
                if let actionGeneration {
                    Button("重试") { onRetry(actionGeneration) }
                        .readerTypography(ReaderDesignMetrics.rowLabel)
                        .foregroundStyle(theme.messageSoftText)
                        .padding(.horizontal, 16)
                        .frame(minWidth: CGFloat(ReaderDesignMetrics.minimumActionTarget),
                               minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
                        .background(theme.messageSoftSurface,
                                    in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.segmentedTrackRadius)))
                        .buttonStyle(.plain)
                }
            }
        }
        .readerTypography(ReaderDesignMetrics.rowLabel)
        .multilineTextAlignment(.center)
        .padding(CGFloat(ReaderDesignMetrics.screenInset))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
