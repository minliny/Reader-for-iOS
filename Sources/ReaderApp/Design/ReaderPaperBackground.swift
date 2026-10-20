import SwiftUI

/// Thin port of Host@33f7c7b:ReaderPaperBackground.ets.
/// Theme colors/effect flags remain owned by the frozen Reader-UI registry.
/// This is a stationary paint layer: it owns no reading position or interaction.
struct ReaderPaperBackground: View {
    let theme: ReaderTheme

    init(theme: ReaderTheme = .day) { self.theme = theme }

    var body: some View {
        GeometryReader { geometry in
            let paper = ReaderPaperPalette(theme: theme)
            let variant = geometry.size.width >= ReaderMetrics.expandedMinWidth ? "tablet" : "phone"
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [paper.paper, paper.paperEnd], startPoint: .top, endPoint: .bottom)
                if paper.sourcePaperLighting {
                    // ImageFit.Fill in the frozen Host deliberately stretches each
                    // exported lighting layer to the current canvas independently.
                    Image("reader-paper-\(variant)-shade")
                        .resizable().interpolation(.high)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    Image("reader-paper-\(variant)-highlight")
                        .resizable().interpolation(.high)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                if paper.paperTexture {
                    // The unchanged 200px source is a 2x asset, so its natural
                    // tile is exactly the Host's 100x100 logical-point grain.
                    Image("reader-paper-texture")
                        .resizable(resizingMode: .tile).interpolation(.high)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .background(paper.paper)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
