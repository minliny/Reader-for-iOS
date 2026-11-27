import SwiftUI

public struct ReaderRecoveryAction: Sendable, Equatable {
    public let title: String
    public let generation: Int

    public init(title: String, generation: Int) {
        self.title = title
        self.generation = generation
    }
}

public struct RecoveryNotice: View {
    @Environment(\.readerTheme) private var theme
    private let title: String
    private let message: String
    private let generation: Int
    private let action: ReaderRecoveryAction?
    private let availability: Bool
    private let onAction: (Int, Int) -> Void

    public init(title: String, message: String, generation: Int, action: ReaderRecoveryAction? = nil,
                availability: Bool = true, onAction: @escaping (Int, Int) -> Void = { _, _ in }) {
        self.title = title
        self.message = message
        self.generation = generation
        self.action = action
        self.availability = availability
        self.onAction = onAction
    }

    @ViewBuilder
    public var body: some View {
        if availability {
            let card = RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius))
            VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceExtraSmall)) {
                Text(title)
                    .readerTypography(ReaderDesignMetrics.pageTitle, relativeTo: .headline)
                    .accessibilityAddTraits(.isHeader)
                ViewThatFits(in: .vertical) {
                    messageBody.fixedSize(horizontal: false, vertical: true)
                    ScrollView { messageBody }
                        .frame(height: 86)
                }
                .frame(maxHeight: 86, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                if let action {
                    Button(action.title) { onAction(generation, action.generation) }
                        .readerTypography(ReaderDesignMetrics.rowLabel)
                        .buttonStyle(.bordered)
                }
            }
            .foregroundStyle(theme.noticeText)
            .padding(CGFloat(ReaderDesignMetrics.cardPadding))
            .frame(maxWidth: 520, alignment: .leading)
            .background(theme.noticeSurface, in: card)
            .overlay { card.strokeBorder(theme.messageBorder) }
            .contentShape(card)
            .onTapGesture { }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reader-recovery-notice")
        }
    }

    private var messageBody: some View {
        Text(message)
            .readerTypography(ReaderDesignMetrics.rowDetail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
