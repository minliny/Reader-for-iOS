import SwiftUI

/// Legacy Mine entry retained as a facade to the canonical demo settings route.
/// The current app shell uses `SettingsTabView` for the fourth main tab.
public struct MineTabView: View {
    public init() {}

    public var body: some View {
        SettingsDemoShellView(demoRoute: "settings-general")
    }
}
