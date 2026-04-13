import SwiftUI

public struct ReaderStatusCardItem: Identifiable, Equatable {
    public let id: String
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.id = label
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
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !items.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text(item.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)

                            Text(item.value)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
