import Foundation
import SwiftUI
import ReaderUIContract

// MARK: - AnyCodable typed accessors
//
// contract `ViewStateComponent.props` 是 `[String: AnyCodable]?`（弱类型）。
// 以下扩展为 SwiftUI view 提供强类型 props 解码入口。
// 真源：`generated/swift/UiEvent.swift` L230-252 AnyCodable（value: any Sendable）。

extension AnyCodable {
    /// 提取 String 值；非 String 返回 nil。
    public var stringValue: String? { value as? String }
    /// 提取 Int 值；Double 类型会尝试截断，非数值返回 nil。
    public var intValue: Int? {
        if let v = value as? Int { return v }
        if let v = value as? Double { return Int(v) }
        if let v = value as? String, let i = Int(v) { return i }
        return nil
    }
    /// 提取 Double 值；Int 类型会提升，非数值返回 nil。
    public var doubleValue: Double? {
        if let v = value as? Double { return v }
        if let v = value as? Int { return Double(v) }
        if let v = value as? String, let d = Double(v) { return d }
        return nil
    }
    /// 提取 Bool 值；非 Bool 返回 nil。
    public var boolValue: Bool? { value as? Bool }
    /// 提取 `[String: AnyCodable]` 值；非字典返回 nil。
    public var dictValue: [String: AnyCodable]? { value as? [String: AnyCodable] }
    /// 提取 `[AnyCodable]` 值；非数组返回 nil。
    public var arrayValue: [AnyCodable]? { value as? [AnyCodable] }
}

extension Dictionary where Key == String, Value == AnyCodable {
    /// 安全下标取值并转为 String。
    public func string(_ key: String) -> String? { self[key]?.stringValue }
    /// 安全下标取值并转为 Int。
    public func int(_ key: String) -> Int? { self[key]?.intValue }
    /// 安全下标取值并转为 Double。
    public func double(_ key: String) -> Double? { self[key]?.doubleValue }
    /// 安全下标取值并转为 Bool。
    public func bool(_ key: String) -> Bool? { self[key]?.boolValue }
    /// 安全下标取值并转为子字典。
    public func dict(_ key: String) -> [String: AnyCodable]? { self[key]?.dictValue }
    /// 安全下标取值并转为数组。
    public func array(_ key: String) -> [AnyCodable]? { self[key]?.arrayValue }
}

// MARK: - ComponentProps 协议
//
// 每个 ComponentType 的强类型 props struct 实现此协议，
// 通过 `init?(props:)` 从弱类型字典解码。解码失败返回 nil（调用方回退到默认值）。

/// 强类型 props 协议。实现者从 `[String: AnyCodable]?` 解码为强类型字段。
public protocol ComponentProps {
    init?(props: [String: AnyCodable]?)
}

// MARK: - Slice 2 Props（书架 → 沉浸阅读）
//
// 真源：`contracts/fixtures/view-state.fixtures.json` L47-1924
// 涉及 RouteId: bookshelf / book-detail / toc-bookmarks / immersive-reading

/// `AppTopBar` props（fixture L49: `{ "title": "书架" }`）
public struct AppTopBarProps: ComponentProps {
    public let title: String
    public init?(props: [String: AnyCodable]?) {
        guard let title = props?.string("title") else { return nil }
        self.title = title
    }
}

/// `ContinueReadingCard` props（fixture L52: bookId/title/author/coverKey）
public struct ContinueReadingCardProps: ComponentProps {
    public let bookId: String
    public let title: String
    public let author: String
    public let coverKey: String?
    public init?(props: [String: AnyCodable]?) {
        guard let bookId = props?.string("bookId"),
              let title = props?.string("title"),
              let author = props?.string("author") else { return nil }
        self.bookId = bookId
        self.title = title
        self.author = author
        self.coverKey = props?.string("coverKey")
    }
}

/// `BookshelfShelfSection` props（fixture L60: title/viewMode）
public struct BookshelfShelfSectionProps: ComponentProps {
    public let title: String
    public let viewMode: String  // "cover" | "list"
    public init?(props: [String: AnyCodable]?) {
        guard let title = props?.string("title"),
              let viewMode = props?.string("viewMode") else { return nil }
        self.title = title
        self.viewMode = viewMode
    }
}

/// `ShelfSectionHeader` props（fixture L64: title/viewMode）
public struct ShelfSectionHeaderProps: ComponentProps {
    public let title: String
    public let viewMode: String
    public init?(props: [String: AnyCodable]?) {
        guard let title = props?.string("title"),
              let viewMode = props?.string("viewMode") else { return nil }
        self.title = title
        self.viewMode = viewMode
    }
}

/// `BookGrid` props（fixture L68: viewMode）
public struct BookGridProps: ComponentProps {
    public let viewMode: String
    public init?(props: [String: AnyCodable]?) {
        guard let viewMode = props?.string("viewMode") else { return nil }
        self.viewMode = viewMode
    }
}

/// `BookCard` props（fixture L72: bookId/title/author/coverKey）
public struct BookCardProps: ComponentProps {
    public let bookId: String
    public let title: String
    public let author: String
    public let coverKey: String?
    public init?(props: [String: AnyCodable]?) {
        guard let bookId = props?.string("bookId"),
              let title = props?.string("title"),
              let author = props?.string("author") else { return nil }
        self.bookId = bookId
        self.title = title
        self.author = author
        self.coverKey = props?.string("coverKey")
    }
}

/// `BookListItem` props（与 BookCard 同结构，列表模式）
public struct BookListItemProps: ComponentProps {
    public let bookId: String
    public let title: String
    public let author: String
    public init?(props: [String: AnyCodable]?) {
        guard let bookId = props?.string("bookId"),
              let title = props?.string("title"),
              let author = props?.string("author") else { return nil }
        self.bookId = bookId
        self.title = title
        self.author = author
    }
}

/// `ReaderBase` props（fixture L1917: `{ "theme": "paper" }`）
public struct ReaderBaseProps: ComponentProps {
    public let theme: String  // "paper" | "warm" | "green" | "blue" + night 变体
    public init?(props: [String: AnyCodable]?) {
        guard let theme = props?.string("theme") else { return nil }
        self.theme = theme
    }
}

/// `ReadingTextFlow` props（阅读正文流，含 typography 配置）
public struct ReadingTextFlowProps: ComponentProps {
    public let bookId: String
    public let chapterId: String?
    public let fontSize: Double?
    public let lineHeight: Double?
    public let paragraphSpacing: Double?
    public init?(props: [String: AnyCodable]?) {
        guard let bookId = props?.string("bookId") else { return nil }
        self.bookId = bookId
        self.chapterId = props?.string("chapterId")
        self.fontSize = props?.double("fontSize")
        self.lineHeight = props?.double("lineHeight")
        self.paragraphSpacing = props?.double("paragraphSpacing")
    }
}

/// `BottomNav` props（fixture L162: `{ "selected": "bookshelf" }`）
public struct BottomNavProps: ComponentProps {
    public let selected: String  // "bookshelf" | "discover" | "rss" | "settings"
    public init?(props: [String: AnyCodable]?) {
        guard let selected = props?.string("selected") else { return nil }
        self.selected = selected
    }
}

/// `BackTopBar` props（二级页返回栏）
public struct BackTopBarProps: ComponentProps {
    public let title: String
    public init?(props: [String: AnyCodable]?) {
        guard let title = props?.string("title") else { return nil }
        self.title = title
    }
}

// MARK: - Slice 3: Reader Control Layer Props

/// `ReaderTopArea` props（control-layer-base-v2 fixture：`{}`，预留 title/chapterLabel）
public struct ReaderTopAreaProps: ComponentProps {
    public let title: String?
    public let chapterLabel: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
        self.chapterLabel = props?.string("chapterLabel")
    }
}

/// `ReaderControlSheet` props（control-layer-base-v2 fixture：`{}`）
public struct ReaderControlSheetProps: ComponentProps {
    public let presentation: String?  // "control" | "module"
    public init?(props: [String: AnyCodable]?) {
        self.presentation = props?.string("presentation")
    }
}

/// `ReaderBottomBar` props（control-layer-base-v2 fixture：`{}`）
public struct ReaderBottomBarProps: ComponentProps {
    public let module: String?  // "directory" | "tts" | "appearance" | "settings"
    public init?(props: [String: AnyCodable]?) {
        self.module = props?.string("module")
    }
}

/// `ReaderDirectoryPanel` props（reader-directory-overlay-v2 fixture：`{}`）
public struct ReaderDirectoryPanelProps: ComponentProps {
    public let chapters: [AnyCodable]?
    public let currentIndex: Int?
    public init?(props: [String: AnyCodable]?) {
        self.chapters = props?.array("chapters")
        self.currentIndex = props?.int("currentIndex")
    }
}

/// `ReaderAppearancePanel` props（reader-appearance-overlay-v2 fixture：`{}`）
public struct ReaderAppearancePanelProps: ComponentProps {
    public let theme: String?
    public let fontSize: Double?
    public let lineSpacing: Double?
    public init?(props: [String: AnyCodable]?) {
        self.theme = props?.string("theme")
        self.fontSize = props?.double("fontSize")
        self.lineSpacing = props?.double("lineSpacing")
    }
}

/// `ReaderTtsPanel` props（reader-tts-overlay-v2 fixture：`{}`）
public struct ReaderTtsPanelProps: ComponentProps {
    public let playbackState: String?  // "playing" | "paused" | "stopped"
    public let rate: Double?
    public init?(props: [String: AnyCodable]?) {
        self.playbackState = props?.string("playbackState")
        self.rate = props?.double("rate")
    }
}

/// `ReaderSettingsPanel` props（reader-settings-overlay-v2 fixture：`{}`）
public struct ReaderSettingsPanelProps: ComponentProps {
    public let tapZone: String?
    public let volumeKey: Bool?
    public let dualPage: Bool?
    public let brightness: Double?
    public init?(props: [String: AnyCodable]?) {
        self.tapZone = props?.string("tapZone")
        self.volumeKey = props?.bool("volumeKey")
        self.dualPage = props?.bool("dualPage")
        self.brightness = props?.double("brightness")
    }
}

/// `ReaderSearchPanel` props（reader-search-overlay-v2 fixture：`{}`）
public struct ReaderSearchPanelProps: ComponentProps {
    public let query: String?
    public let results: [AnyCodable]?
    public init?(props: [String: AnyCodable]?) {
        self.query = props?.string("query")
        self.results = props?.array("results")
    }
}

/// `ReaderReplacePanel` props（reader-replace-overlay-v2 fixture：`{}`）
public struct ReaderReplacePanelProps: ComponentProps {
    public let pattern: String?
    public let replacement: String?
    public init?(props: [String: AnyCodable]?) {
        self.pattern = props?.string("pattern")
        self.replacement = props?.string("replacement")
    }
}

/// `ReaderAutoScrollPanel` props（reader-auto-scroll-overlay-v2 fixture：`{}`）
public struct ReaderAutoScrollPanelProps: ComponentProps {
    public let interval: Double?
    public let enabled: Bool?
    public init?(props: [String: AnyCodable]?) {
        self.interval = props?.double("interval")
        self.enabled = props?.bool("enabled")
    }
}

/// `NightToast` props（reader-night-state-v2 fixture：`{}`）
public struct NightToastProps: ComponentProps {
    public let message: String?
    public let visible: Bool?
    public init?(props: [String: AnyCodable]?) {
        self.message = props?.string("message")
        self.visible = props?.bool("visible")
    }
}


// MARK: - Slice 4 Props（进度/会话/焦点/TTS 全屏页）

/// \`ReaderFullDirectoryPage\` props（reader-full-directory fixture：\`{}\`）
public struct ReaderFullDirectoryPageProps: ComponentProps {
    public let bookId: String?
    public init?(props: [String: AnyCodable]?) {
        self.bookId = props?.string("bookId")
    }
}

/// \`ReaderFullTtsPage\` props（reader-full-tts fixture：\`{}\`）
public struct ReaderFullTtsPageProps: ComponentProps {
    public let playbackState: String?
    public let rate: Double?
    public init?(props: [String: AnyCodable]?) {
        self.playbackState = props?.string("playbackState")
        self.rate = props?.double("rate")
    }
}

/// \`ReaderFullAppearancePage\` props（reader-full-appearance/font/theme/themeEdit/layout fixture：\`{}\`）
public struct ReaderFullAppearancePageProps: ComponentProps {
    public let theme: String?
    public let fontSize: Double?
    public let lineSpacing: Double?
    public init?(props: [String: AnyCodable]?) {
        self.theme = props?.string("theme")
        self.fontSize = props?.double("fontSize")
        self.lineSpacing = props?.double("lineSpacing")
    }
}

/// \`ReaderFullSettingsPage\` props（reader-full-settings/pageTurn fixture：\`{}\`）
public struct ReaderFullSettingsPageProps: ComponentProps {
    public let tapZone: String?
    public let volumeKey: Bool?
    public let dualPage: Bool?
    public let brightness: Double?
    public init?(props: [String: AnyCodable]?) {
        self.tapZone = props?.string("tapZone")
        self.volumeKey = props?.bool("volumeKey")
        self.dualPage = props?.bool("dualPage")
        self.brightness = props?.double("brightness")
    }
}

/// \`ReaderBookCachePage\` props（reader-book-cache fixture：\`{}\`）
public struct ReaderBookCachePageProps: ComponentProps {
    public let bookId: String?
    public let cacheSize: Double?
    public init?(props: [String: AnyCodable]?) {
        self.bookId = props?.string("bookId")
        self.cacheSize = props?.double("cacheSize")
    }
}

/// \`ReaderDebugInfoPage\` props（reader-debug-info fixture：\`{}\`）
public struct ReaderDebugInfoPageProps: ComponentProps {
    public let bookId: String?
    public let sourceId: String?
    public init?(props: [String: AnyCodable]?) {
        self.bookId = props?.string("bookId")
        self.sourceId = props?.string("sourceId")
    }
}

/// \`ProgressSyncPage\` props（progress-sync fixture：\`{}\`）
public struct ProgressSyncPageProps: ComponentProps {
    public let enabled: Bool?
    public let lastSyncTime: String?
    public init?(props: [String: AnyCodable]?) {
        self.enabled = props?.bool("enabled")
        self.lastSyncTime = props?.string("lastSyncTime")
    }
}

/// \`SyncProgressPage\` props（progress-sync-status fixture：\`{ title, progress }\`）
public struct SyncProgressPageProps: ComponentProps {
    public let title: String?
    public let progress: Double?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
        self.progress = props?.double("progress")
    }
}


// MARK: - Slice 5a Props（RSS 系列页）

/// `RssSearchEntry` props（rss / rss-search fixture：`{}`）
public struct RssSearchEntryProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `RssModeRow` props（rss fixture：`{}`）
public struct RssModeRowProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `RssSourceOverview` props（rss fixture：`{}`）
public struct RssSourceOverviewProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `RssArticleSection` props（rss / rss-starred fixture：`{}`）
public struct RssArticleSectionProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `RssAllPage` props（rss-all fixture：`{}`）
public struct RssAllPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `RssDetailPage` props（rss-detail fixture：`{ title }`）
public struct RssDetailPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `RssOriginalPage` props（rss-original fixture：`{}`）
public struct RssOriginalPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `RssRefreshingPage` props（rss-refreshing fixture：`{}`）
public struct RssRefreshingPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `RssOriginalBrowserPage` props（rss-original-browser fixture：`{}`）
public struct RssOriginalBrowserPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `RssFavoriteGroupsPage` props（rss-favorite-groups fixture：`{}`）
public struct RssFavoriteGroupsPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `RssSourceGroupsPage` props（rss-source-groups fixture：`{}`）
public struct RssSourceGroupsPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `RssSourceImportPage` props（rss-source-import fixture：`{ message }`）
public struct RssSourceImportPageProps: ComponentProps {
    public let message: String?
    public init?(props: [String: AnyCodable]?) {
        self.message = props?.string("message")
    }
}

/// `RssSourceEditPage` props（rss-source-add/rss-source-edit fixture：`{ mode }`）
public struct RssSourceEditPageProps: ComponentProps {
    public let mode: String?
    public init?(props: [String: AnyCodable]?) {
        self.mode = props?.string("mode")
    }
}

/// `RssSubscriptionManagementPage` props（rss-subscription-management fixture：`{ title }`）
public struct RssSubscriptionManagementPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `RssEmptyState` props（rss-empty fixture：`{ title, message, action }`）
public struct RssEmptyStateProps: ComponentProps {
    public let title: String?
    public let message: String?
    public let action: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
        self.message = props?.string("message")
        self.action = props?.string("action")
    }
}

/// `RssErrorState` props（rss-error fixture：`{ title, message, action }`）
public struct RssErrorStateProps: ComponentProps {
    public let title: String?
    public let message: String?
    public let action: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
        self.message = props?.string("message")
        self.action = props?.string("action")
    }
}


// MARK: - Slice 5b Props（书源系列页）

/// `SourceDetailPage` props（source-detail fixture：`{ title }`）
public struct SourceDetailPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `SourceSwitchFlowPage` props（source-switch / source-switch-results fixture：`{}`）
public struct SourceSwitchFlowPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `SourceManagementPage` props（source-management / source-settings-entry fixture：`{ title }`）
public struct SourceManagementPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `SourceImportOptionsPage` props（source-add / source-import-options fixture：`{ title }`）
public struct SourceImportOptionsPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `SourceRuleEditPage` props（source-edit / source-edit-debug / source-rule-edit fixture：`{ title?, variant? }`）
public struct SourceRuleEditPageProps: ComponentProps {
    public let title: String?
    public let variant: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
        self.variant = props?.string("variant")
    }
}

/// `SourceTestResultPage` props（source-test-result fixture：`{ title }`）
public struct SourceTestResultPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `SourceBatchPage` props（source-batch fixture：`{}`）
public struct SourceBatchPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `SourceCodeViewPage` props（source-code-view fixture：`{}`）
public struct SourceCodeViewPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `SourceDebugPage` props（source-debug fixture：`{}`）
public struct SourceDebugPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `SourceDebugResultPage` props（source-debug-*-result fixture：`{ variant }`）
public struct SourceDebugResultPageProps: ComponentProps {
    public let variant: String?
    public init?(props: [String: AnyCodable]?) {
        self.variant = props?.string("variant")
    }
}

/// `SourceDebugContentLogPage` props（source-debug-content-log fixture：`{}`）
public struct SourceDebugContentLogPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `SourceDebugRunningPage` props（source-debug-running fixture：`{}`）
public struct SourceDebugRunningPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `SourceDeleteConfirmPage` props（source-delete-confirm fixture：`{}`）
public struct SourceDeleteConfirmPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `SourceDetectPage` props（source-detect fixture：`{}`）
public struct SourceDetectPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `SourceGroupsPage` props（source-groups fixture：`{}`）
public struct SourceGroupsPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `SourceImportPreviewPage` props（source-import-preview fixture：`{}`）
public struct SourceImportPreviewPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `SourceLogsPage` props（source-logs fixture：`{}`）
public struct SourceLogsPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `SourceDisabledState` props（无 fixture，contract 独立状态组件）
public struct SourceDisabledStateProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}


// MARK: - Slice 5c Props（搜索/书籍详情/书架管理扩展）

/// `SearchInputBox` props（book-search fixture：`{ query }`）
public struct SearchInputBoxProps: ComponentProps {
    public let query: String?
    public init?(props: [String: AnyCodable]?) {
        self.query = props?.string("query")
    }
}

/// `ScopeSelector` props（book-search fixture：`{}`）
public struct ScopeSelectorProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `GroupSelector` props（book-search fixture：`{}`）
public struct GroupSelectorProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `SearchHistoryList` props（book-search fixture：`{}`）
public struct SearchHistoryListProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `SearchHomePage` props（search-home fixture：`{ query, placeholder }`）
public struct SearchHomePageProps: ComponentProps {
    public let query: String?
    public let placeholder: String?
    public init?(props: [String: AnyCodable]?) {
        self.query = props?.string("query")
        self.placeholder = props?.string("placeholder")
    }
}

/// `SearchResultsPage` props（search-results fixture：`{ query }`）
public struct SearchResultsPageProps: ComponentProps {
    public let query: String?
    public init?(props: [String: AnyCodable]?) {
        self.query = props?.string("query")
    }
}

/// `SearchStatePage` props（search-empty/loading/error fixture：`{ variant, title, message, action? }`）
public struct SearchStatePageProps: ComponentProps {
    public let variant: String?
    public let title: String?
    public let message: String?
    public let action: String?
    public init?(props: [String: AnyCodable]?) {
        self.variant = props?.string("variant")
        self.title = props?.string("title")
        self.message = props?.string("message")
        self.action = props?.string("action")
    }
}

/// `BookTocPreviewPage` props（book-detail-toc-preview fixture：`{ title }`）
public struct BookTocPreviewPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `BookDirectoryPage` props（book-directory fixture：`{}`）
public struct BookDirectoryPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `GroupManagementPage` props（group-management fixture：`{ variant }`）
public struct GroupManagementPageProps: ComponentProps {
    public let variant: String?
    public init?(props: [String: AnyCodable]?) {
        self.variant = props?.string("variant")
    }
}

/// `BookBatchManagementPage` props（book-batch-management fixture：`{}`）
public struct BookBatchManagementPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `BookGroupManagementPage` props（bookshelf-group-management fixture：`{ title }`）
public struct BookGroupManagementPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}


// MARK: - Slice 5d Props（发现系列页）

/// `DiscoverSourceBar` props（discover fixture：`{}`）
public struct DiscoverSourceBarProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `DiscoverEntryRow` props（discover fixture：`{}`）
public struct DiscoverEntryRowProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `DiscoverFilterTrigger` props（discover fixture：`{}`）
public struct DiscoverFilterTriggerProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `DiscoverListHead` props（discover fixture：`{}`）
public struct DiscoverListHeadProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `DiscoverBookList` props（discover fixture：`{}`）
public struct DiscoverBookListProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `DiscoverStatePage` props（discover-empty/error/loading/no-results fixture：`{ variant, title, message, action? }`）
public struct DiscoverStatePageProps: ComponentProps {
    public let variant: String?
    public let title: String?
    public let message: String?
    public let action: String?
    public init?(props: [String: AnyCodable]?) {
        self.variant = props?.string("variant")
        self.title = props?.string("title")
        self.message = props?.string("message")
        self.action = props?.string("action")
    }
}

/// `DiscoverRuleTestPage` props（discover-rule-test fixture：`{}`）
public struct DiscoverRuleTestPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `DiscoverSourceBulkPage` props（discover-source-bulk fixture：`{}`）
public struct DiscoverSourceBulkPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `DiscoverSourceLoginPage` props（discover-source-login fixture：`{}`）
public struct DiscoverSourceLoginPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}


// MARK: - Slice 6 Props（同步/冲突/离线/设置/about/app-shell）

/// `Loading` props（app-shell loading fixture：`{}`）
public struct LoadingProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `AppShellStructure` props（app-shell default fixture：`{ title }`）
public struct AppShellStructureProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `Offline` props（state-offline fixture：`{}`）
public struct OfflineProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `OfflineStatePage` props（offline-state fixture：`{}`）
public struct OfflineStatePageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `SettingsHomePage` props（settings fixture：`{ title }`）
public struct SettingsHomePageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `GlobalSettingsPage` props（global-settings fixture：`{ title }`）
public struct GlobalSettingsPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `SettingsGeneralPage` props（settings-general fixture：`{ title }`）
public struct SettingsGeneralPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `ReadingSettingsEntryPage` props（reading-settings-entry fixture：`{ title }`）
public struct ReadingSettingsEntryPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `BackupSettingsPage` props（backup-settings fixture：`{ title }`）
public struct BackupSettingsPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `BookshelfSearchSettingsPage` props（bookshelf-search-settings fixture：`{ title }`）
public struct BookshelfSearchSettingsPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `SyncBackupPage` props（sync-backup / webdav-config fixture：`{ variant?, status? }`）
public struct SyncBackupPageProps: ComponentProps {
    public let variant: String?
    public let status: String?
    public init?(props: [String: AnyCodable]?) {
        self.variant = props?.string("variant")
        self.status = props?.string("status")
    }
}

/// `SyncErrorPage` props（sync-error fixture：`{ title, message }`）
public struct SyncErrorPageProps: ComponentProps {
    public let title: String?
    public let message: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
        self.message = props?.string("message")
    }
}

/// `SyncSettingsEntryPage` props（sync-settings-entry fixture：`{ title }`）
public struct SyncSettingsEntryPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}

/// `RestoreConflictPage` props（restore-conflict fixture：`{}`）
public struct RestoreConflictPageProps: ComponentProps {
    public init?(props: [String: AnyCodable]?) {}
}

/// `AboutVersionPage` props（about-version fixture：`{ title, version }`）
public struct AboutVersionPageProps: ComponentProps {
    public let title: String?
    public let version: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
        self.version = props?.string("version")
    }
}

/// `AboutFeedbackPage` props（about / about-feedback fixture：`{ title }`）
public struct AboutFeedbackPageProps: ComponentProps {
    public let title: String?
    public init?(props: [String: AnyCodable]?) {
        self.title = props?.string("title")
    }
}
