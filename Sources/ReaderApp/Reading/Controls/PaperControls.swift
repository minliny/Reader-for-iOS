import ReaderDesign
import SwiftUI

struct PaperControls: View {
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 9) {
            ForEach(ReaderPaper.all) { paper in
                Button { onSelect(paper.id) } label: {
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 7).fill(paper.swatch)
                            .overlay {
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(.secondary.opacity(selected == paper.id ? 0.8 : 0.3),
                                                  lineWidth: selected == paper.id ? 2 : 1)
                            }
                            .frame(height: 30)
                        Text(paper.name)
                            .readerTypography(ReaderDesignMetrics.rowDetail, relativeTo: .caption2)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected == paper.id ? .isSelected : [])
            }
        }
    }
}
