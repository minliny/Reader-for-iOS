import SwiftUI

public struct ReaderContentSectionView: View {
    public let title: String
    public let bodyText: String
    public let bookTitle: String?
    public let sourceName: String?

    public init(
        title: String,
        bodyText: String,
        bookTitle: String? = nil,
        sourceName: String? = nil
    ) {
        self.title = title
        self.bodyText = bodyText
        self.bookTitle = bookTitle
        self.sourceName = sourceName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // Header Context
            VStack(alignment: .leading, spacing: 8) {
                if let bookTitle = bookTitle {
                    Text(bookTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                Text(title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let sourceName = sourceName {
                    Text("来源: \(sourceName)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.bottom, 8)

            // Content Body
            Text(bodyText)
                .font(.body)
                .lineSpacing(14)
                .foregroundStyle(.primary.opacity(0.85))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 16)
        // No heavy background card, just readable text on the system background
    }
}
