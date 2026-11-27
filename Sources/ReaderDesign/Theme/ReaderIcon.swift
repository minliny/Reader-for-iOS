import SwiftUI

public struct ReaderIcon: View {
    @Environment(\.readerTheme) private var theme
    private let mapping: ReaderIconMapping

    public init(_ mapping: ReaderIconMapping) { self.mapping = mapping }

    @ViewBuilder
    public var body: some View {
        if let systemName = mapping.systemName {
            Image(systemName: systemName)
                .accessibilityHidden(true)
        } else if let assetName = mapping.assetName,
                  let image = UIImage(named: (assetName as NSString).deletingPathExtension,
                                      in: ReaderDesignResources.bundle, compatibleWith: nil) {
            Image(uiImage: image)
                .renderingMode(.template)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
        }
    }

    private var tint: Color {
        guard let key = mapping.tintRole, let role = ReaderAppRole(rawValue: key) else { return theme.accent }
        return theme.color(role)
    }
}
