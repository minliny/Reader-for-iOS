import SwiftUI

public struct ReaderIcon: View {
    @Environment(\.readerTheme) private var theme
    private let mapping: ReaderIconMapping
    private let squareSize: CGFloat?

    public init(_ mapping: ReaderIconMapping, squareSize: CGFloat? = nil) {
        self.mapping = mapping
        self.squareSize = squareSize
    }

    @ViewBuilder
    public var body: some View {
        if let systemName = mapping.systemName {
            Image(systemName: systemName)
                .accessibilityHidden(true)
        } else if let assetName = mapping.assetName,
                  let image = UIImage(named: (assetName as NSString).deletingPathExtension,
                                      in: ReaderDesignResources.bundle, compatibleWith: nil) {
            asset(image).foregroundStyle(tint).accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func asset(_ image: UIImage) -> some View {
        let template = Image(uiImage: image).renderingMode(.template)
        if let squareSize {
            template.resizable().scaledToFit().frame(width: squareSize, height: squareSize)
        } else {
            template
        }
    }

    private var tint: Color {
        guard let key = mapping.tintRole, let role = ReaderAppRole(rawValue: key) else { return theme.accent }
        return theme.color(role)
    }
}
