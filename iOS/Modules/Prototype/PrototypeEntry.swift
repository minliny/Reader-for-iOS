import SwiftUI

/// Prototype Gallery 入口条目模型
public struct PrototypeEntry: Identifiable {
    public let id: String
    public let group: PrototypeGroup
    public let name: String
    public let description: String
    @ViewBuilder public let content: () -> AnyView

    public init(
        id: String,
        group: PrototypeGroup,
        name: String,
        description: String = "",
        @ViewBuilder content: @escaping () -> some View
    ) {
        self.id = id
        self.group = group
        self.name = name
        self.description = description
        self.content = { AnyView(content()) }
    }
}

/// 13 个分组
public enum PrototypeGroup: String, CaseIterable, Identifiable {
    case appShell = "App / Navigation"
    case bookshelf = "Bookshelf"
    case searchDetail = "Search / Detail"
    case reader = "Reader"
    case sourceMgmt = "Source Management"
    case discover = "Discover"
    case rss = "RSS"
    case webdav = "WebDAV"
    case sync = "Sync"
    case settings = "Settings"
    case states = "State Pages"
    case debug = "Debug"

    public var id: String { rawValue }

    /// demo 资产图标（替换原 SF Symbols `icon: String`）。
    public var assetIcon: ReaderAssetIcon {
        switch self {
        case .appShell: return .grid
        case .bookshelf: return .bookshelf
        case .searchDetail: return .search
        case .reader: return .book
        case .sourceMgmt: return .source
        case .discover: return .discover
        case .rss: return .rss
        case .webdav: return .cloud
        case .sync: return .sync
        case .settings: return .gear
        case .states: return .warning
        case .debug: return .bug
        }
    }
}
