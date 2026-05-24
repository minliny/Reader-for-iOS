import SwiftUI

/// 「我的」Tab 最小生产 Shell — 设置/WebDAV/备份/同步归入此 Tab
/// Debug-only 入口仅在 #if DEBUG 下可见
public struct MineTabView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // MARK: 个人
                Section("个人") {
                    NavigationLink(destination: WebDAVSettingsView()) {
                        Label("设置", systemImage: "gearshape")
                    }
                    Label("阅读记录", systemImage: "clock")
                    Label("阅读统计", systemImage: "chart.bar")
                    Label("收藏/书签", systemImage: "bookmark")
                }

                // MARK: 备份与同步
                Section("备份与同步") {
                    NavigationLink(destination: WebDAVSettingsView()) {
                        Label("WebDAV 备份", systemImage: "icloud")
                    }
                    Label("备份设置", systemImage: "externaldrive")
                    Label("同步进度", systemImage: "arrow.triangle.2.circlepath")
                }

                // MARK: 关于
                Section("关于") {
                    Label("关于 Reader", systemImage: "info.circle")
                    Label("版本 1.0.0", systemImage: "number")
                }

                // MARK: Developer Tools (Debug only)
                #if DEBUG
                Section("Developer Tools") {
                    NavigationLink(destination: PrototypeGalleryView()) {
                        Label("[DEBUG] Prototype Gallery", systemImage: "wrench")
                    }
                    NavigationLink(destination: WebViewRuntimeHarnessView()) {
                        Label("WebView Harness", systemImage: "hammer")
                    }
                }
                #endif
            }
            .navigationTitle("我的")
        }
    }
}
