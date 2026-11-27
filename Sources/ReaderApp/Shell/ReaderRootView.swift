import ReaderDesign
import SwiftUI

struct ReaderRootView: View {
    let root: URL
    @State private var model: ShelfModel
    @AppStorage("reader.appearance") private var appearance = ReaderAppearance.system
    @Environment(\.colorScheme) private var systemScheme

    init(root: URL, model: ShelfModel = ShelfModel()) {
        self.root = root
        _model = State(initialValue: model)
    }

    var body: some View {
        BookshelfScreen(model: model, root: root)
            .environment(\.readerTheme, ReaderTheme(night: appearance.night(system: systemScheme)))
            .preferredColorScheme(appearance.scheme)
            .readerDesign()
            .task { await model.start(root: root) }
    }
}
