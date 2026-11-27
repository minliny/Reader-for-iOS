import SwiftUI

@main
struct ReaderApp: App {
    var body: some Scene {
        WindowGroup { ReaderRootView(root: Self.storageRoot) }
    }

    static var storageRoot: URL {
        URL.applicationSupportDirectory.appending(path: "Reader", directoryHint: .isDirectory)
    }
}
