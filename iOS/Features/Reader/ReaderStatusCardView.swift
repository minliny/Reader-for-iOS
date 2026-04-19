import Foundation
#if canImport(SwiftUI)
import SwiftUI

public struct ReaderStatusCardItem: Identifiable, Equatable {
    public let id: String
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.id = UUID().uuidString
        self.label = label
        self.value = value
    }
}

public struct ReaderStatusCardView: View {
    public let eyebrow: String
    public let title: String
    public let subtitle: String
    public let items: [ReaderStatusCardItem]

    public init(
        eyebrow: String,
        title: String,
        subtitle: String,
        items: [ReaderStatusCardItem] = []
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tint)
                    .tracking(1.2)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if !items.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { item in
                        HStack {
                            Text(item.element.label)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(item.element.value)
                                .font(.callout)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, 10)

                        if item.offset < items.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(Color.platformTertiaryGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(Color.platformSecondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}
#endif
