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

    public var icon: String {
        switch self {
        case .appShell: return "rectangle.split.2x2"
        case .bookshelf: return "books.vertical"
        case .searchDetail: return "magnifyingglass"
        case .reader: return "book"
        case .sourceMgmt: return "doc.text.magnifyingglass"
        case .discover: return "safari"
        case .rss: return "dot.radiowaves.left.and.right"
        case .webdav: return "icloud"
        case .sync: return "arrow.triangle.2.circlepath"
        case .settings: return "gearshape"
        case .states: return "exclamationmark.triangle"
        case .debug: return "wrench"
        }
    }
}
