import SwiftUI

#if os(macOS)
import AppKit

extension Color {
    static let platformSecondaryGroupedBackground = Color(nsColor: .controlBackgroundColor)
    static let platformGroupedBackground = Color(nsColor: .windowBackgroundColor)
    static let platformTertiaryGroupedBackground = Color(nsColor: .underPageBackgroundColor)
}

public typealias UIColor = NSColor

extension NSColor {
    static var systemGroupedBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemGroupedBackground: NSColor { .controlBackgroundColor }
}

extension CGColor {
    static var secondarySystemBackground: CGColor { NSColor.controlBackgroundColor.cgColor }
    static var systemBackground: CGColor { NSColor.windowBackgroundColor.cgColor }
}

extension View {
    func navigationBarTitleDisplayMode(_ mode: some Hashable) -> some View {
        self
    }

    func inlineNavigationBarTitle() -> some View {
        self
    }
}

extension ToolbarItemPlacement {
    static let navigationBarTrailing = ToolbarItemPlacement.automatic
}
#endif

#if os(iOS)
import UIKit

extension Color {
    static let platformSecondaryGroupedBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let platformGroupedBackground = Color(uiColor: .systemGroupedBackground)
    static let platformTertiaryGroupedBackground = Color(uiColor: .tertiarySystemGroupedBackground)
}

extension View {
    func navigationBarTitleDisplayMode(_ mode: some Hashable) -> some View {
        self
    }

    func inlineNavigationBarTitle() -> some View {
        self
    }
}

extension ToolbarItemPlacement {
    static let navigationBarTrailing = ToolbarItemPlacement.automatic
}
#endif
