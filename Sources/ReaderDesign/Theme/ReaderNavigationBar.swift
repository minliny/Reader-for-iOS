import SwiftUI

public extension View {
    func readerNavigationBar() -> some View { modifier(ReaderNavigationBarStyle()) }
}

private struct ReaderNavigationBarStyle: ViewModifier {
    @Environment(\.readerTheme) private var theme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(theme.night ? .dark : .light, for: .navigationBar)
    }
}
