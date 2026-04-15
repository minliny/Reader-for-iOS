import Foundation
#if canImport(SwiftUI)
import SwiftUI

public extension View {
    @ViewBuilder
    public func inlineNavigationBarTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

public extension Color {
    /// Cross-platform equivalent of `Color(UIColor.systemGroupedBackground)`.
    static var platformGroupedBackground: Color {
        #if os(iOS)
        Color(UIColor.systemGroupedBackground)
        #else
        Color(white: 0.93)
        #endif
    }

    /// Cross-platform equivalent of `Color(UIColor.secondarySystemGroupedBackground)`.
    static var platformSecondaryGroupedBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemGroupedBackground)
        #else
        Color(white: 0.96)
        #endif
    }

    /// Cross-platform equivalent of `Color(UIColor.tertiarySystemGroupedBackground)`.
    static var platformTertiaryGroupedBackground: Color {
        #if os(iOS)
        Color(UIColor.tertiarySystemGroupedBackground)
        #else
        Color(white: 0.98)
        #endif
    }
}
#endif
