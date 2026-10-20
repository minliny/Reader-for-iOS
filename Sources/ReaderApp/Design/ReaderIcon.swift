import SwiftUI

enum ReaderIconName: String, CaseIterable {
    case bookshelf, bookshelfActive, settings, settingsActive, more, back, appearance, directory
    case chevronDown, chevronLeft, chevronRight, importFile, search, grid, gridActive, list, listActive
    case filter, filterActive, sun, bookmark, check, close
    var assetName: String { "reader-icon-" + rawValue }
}

/// Original frozen SVG artwork, rasterized with sharp/libvips. The asset catalog owns day/night variants.
struct ReaderIcon: View {
    let name: ReaderIconName
    let size: CGFloat
    init(_ name: ReaderIconName, size: CGFloat = 24) { self.name = name; self.size = size }
    init(name: ReaderIconName, size: CGFloat = 24) { self.name = name; self.size = size }
    var body: some View {
        Image(name.assetName).resizable().scaledToFit().frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
