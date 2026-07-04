import SwiftUI

public struct WebDAVSettingsView: View {
    private let onExit: (() -> Void)?

    public init(onExit: (() -> Void)? = nil) {
        self.onExit = onExit
    }

    public var body: some View {
        SettingsDemoShellView(demoRoute: "webdav-config", onExit: onExit)
    }
}
