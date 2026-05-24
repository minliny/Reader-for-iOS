import SwiftUI

/// 发现 Tab 最小生产 Shell — fixture-only，不接真实网络
public struct DiscoverHomeShellView: View {
    @State private var searchText = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // 搜索入口（不作为底栏）
                Section {
                    NavigationLink(destination: SearchView()) {
                        Label("搜索书籍", systemImage: "magnifyingglass")
                    }
                }

                // 推荐占位
                Section("推荐") {
                    Label("热门推荐", systemImage: "flame")
                    Label("新书速递", systemImage: "sparkles")
                    Label("编辑精选", systemImage: "star")
                }

                // 分类占位
                Section("分类") {
                    Label("玄幻", systemImage: "mountain.2")
                    Label("仙侠", systemImage: "leaf")
                    Label("都市", systemImage: "building.2")
                    Label("科幻", systemImage: "rocket")
                }

                // 排行占位
                Section("排行") {
                    Label("阅读榜", systemImage: "chart.bar")
                    Label("收藏榜", systemImage: "heart")
                    Label("新书榜", systemImage: "clock.badge")
                }

                // RSS 入口
                Section("订阅") {
                    Label("RSS 订阅", systemImage: "dot.radiowaves.left.and.right")
                }
            }
            .navigationTitle("发现")
        }
    }
}
