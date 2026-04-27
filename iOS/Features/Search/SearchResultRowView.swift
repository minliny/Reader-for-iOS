import SwiftUI
import ReaderCoreModels

public struct SearchResultRowView: View {
    let result: SearchResultItem
    let sourceName: String

    public init(result: SearchResultItem, sourceName: String) {
        self.result = result
        self.sourceName = sourceName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.title)
                .font(.headline)

            if let author = result.author, !author.isEmpty {
                Text("by \(author)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if let latestChapter = result.latestChapter, !latestChapter.isEmpty {
                    Text(latestChapter)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(sourceName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
