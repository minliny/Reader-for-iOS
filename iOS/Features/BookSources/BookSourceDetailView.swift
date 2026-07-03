import SwiftUI
import ReaderCoreModels

/// Compatibility wrapper for the current demo-aligned source detail sheet.
public struct BookSourceDetailView: View {
    let source: BookSource

    public init(source: BookSource) {
        self.source = source
    }

    public var body: some View {
        BookSourceDetailSheet(source: source)
    }
}
