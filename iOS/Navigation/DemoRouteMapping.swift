import Foundation

/// Machine-readable platform mapping for selected demo routes.
///
/// Source of truth:
/// - Demo routes: `Reader UI/frontend-demo/route-contract.js`
/// - Human matrix: `docs/ui-handoff/ios/IOS_DEMO_BASELINE_ROUTE_MAPPING.md`
///
/// This table starts with Slice 1 and the shortest Slice 2 reader-entry path.
/// Add routes here only when the platform ownership/state/motion/test contract is known.
public struct DemoRouteMapping: Hashable, Identifiable {
    public let demoRoute: String
    public let slice: Int
    public let shell: String
    public let platformTarget: DemoRoutePlatformTarget
    public let stateModel: String
    public let navigationEntry: String
    public let motionIDs: [String]
    public let acceptanceTests: [String]

    public var id: String { demoRoute }

    public init(
        demoRoute: String,
        slice: Int,
        shell: String,
        platformTarget: DemoRoutePlatformTarget,
        stateModel: String,
        navigationEntry: String,
        motionIDs: [String],
        acceptanceTests: [String]
    ) {
        self.demoRoute = demoRoute
        self.slice = slice
        self.shell = shell
        self.platformTarget = platformTarget
        self.stateModel = stateModel
        self.navigationEntry = navigationEntry
        self.motionIDs = motionIDs
        self.acceptanceTests = acceptanceTests
    }
}

public enum DemoRoutePlatformTarget: Hashable {
    case appTab(AppTab)
    case nativeRoute(NativeRouteID)
    case featureState(String)
    case readerContext(ReaderContext.EntrySource)
    case planned(String)
}

public enum NativeRouteID: String, Hashable {
    case bookshelf
    case discover
    case rssList
    case settings
    case search
    case bookDetail
    case bookDetailToc
    case rssDetail
    case rssOriginal
    case rssOriginalBrowser
    case rssSubscriptions
    case rssSourceActions
    case rssSourceEdit
    case rssSourceDebug
    case rssSourceVars
    case rssSourceLogin
    case rssSourceLoginWeb
    case rssSourceLoginCookie
    case rssSourceLoginClear
    case rssSourceGroups
    case rssSourceGroupEdit
    case rssSourceBatch
    case rssSourceExport
    case rssSourceExportDetail
    case rssSourceExportResult
    case rssSourcePin
    case rssSourceDisable
    case rssSourceBatchDisable
    case rssSourceImport
    case rssSourceImportDetail
    case rssSourceImportResult
    case rssSearch
    case rssReadRecord
    case rssRecordClear
    case rssRuleSubscription
    case rssRuleSubscriptionDetail
    case rssRuleSubscriptionEdit
    case rssRuleSubscriptionTest
    case rssRuleSubscriptionApply
    case rssFavoriteGroups
    case rssFavoriteGroupEdit
    case rssFavoriteClear
    case rssEmpty
    case rssError
    case bookshelfGroups
    case bookshelfImport
    case bookBatchManagement
    case reader
    case sourceSwitch
}

public enum DemoRouteMappings {
    public static let expectedMainTabShellRoutes: [String] = [
        "bookshelf", "discover", "discover-control", "discover-sort", "discover-entry-ranking", "discover-entry-bestseller",
        "discover-entry-category", "discover-entry-finished", "discover-entry-latest", "discover-entry-new", "discover-entry-booklist", "discover-filter-keyword",
        "discover-filter-male", "discover-filter-female", "discover-sort-popularity", "discover-sort-update", "discover-sort-collection", "discover-sort-finished",
        "discover-sort-words", "discover-no-results", "discover-loading", "discover-refreshing", "discover-infinite-loading", "discover-page-two",
        "discover-cache-confirm", "discover-cache-toast", "discover-login-return", "discover-switching-source", "discover-switched-source", "discover-entry-error",
        "discover-empty", "discover-error", "rss", "settings", "bookshelf-empty", "sort-filter"
    ]

    public static let expectedLibraryShellRoutes: [String] = [
        "discover-source-login", "rss-all", "rss-starred", "rss-source-feed", "rss-source-category-releases", "rss-source-category-issues",
        "rss-source-category-discussions", "rss-refreshing", "rss-search", "rss-detail", "rss-original", "rss-original-browser",
        "rss-subscription-management", "rss-source-actions", "rss-source-edit", "rss-source-debug", "rss-source-vars", "rss-source-login",
        "rss-source-login-web", "rss-source-login-cookie", "rss-source-login-clear", "rss-source-groups", "rss-source-group-edit", "rss-source-batch",
        "rss-source-export", "rss-source-export-detail", "rss-source-export-result", "rss-source-pin", "rss-source-disable", "rss-source-batch-disable",
        "rss-source-import", "rss-source-import-detail", "rss-source-import-result", "rss-read-record", "rss-record-clear", "rss-rule-subscription",
        "rss-rule-subscription-detail", "rss-rule-subscription-edit", "rss-rule-subscription-test", "rss-rule-subscription-apply", "rss-favorite-groups", "rss-favorite-group-edit",
        "rss-favorite-clear", "rss-empty", "rss-error", "book-search", "book-detail", "book-directory",
        "book-batch-management", "group-management", "local-import"
    ]

    public static let expectedSettingsShellRoutes: [String] = [
        "discover-rule-test", "discover-source-bulk", "settings-general", "bookshelf-search-settings", "about-feedback", "sync-backup",
        "webdav-config", "restore-confirm", "restore-progress", "restore-conflict", "restore-result", "source-management",
        "source-import-options", "source-import-preview", "source-batch", "source-groups", "source-detail", "source-detect",
        "source-rule-edit", "source-debug", "source-debug-search-result", "source-debug-detail-result", "source-debug-catalog-result", "source-debug-content-log",
        "source-edit-debug", "source-logs", "source-code-view", "source-delete-confirm"
    ]

    public static let expectedReaderShellRoutes: [String] = [
        "immersive-reading", "reader", "toc-bookmarks", "reader-appearance", "tts", "reader-settings",
        "reader-full-directory", "reader-full-tts", "reader-full-appearance", "reader-full-settings", "reader-book-cache", "reader-debug-info",
        "auto-page", "content-search", "content-replacement"
    ]

    public static let expectedFlowShellRoutes: [String] = [
        "source-switch"
    ]

    public static let expectedRoutesByShell: [(shell: String, routes: [String])] = [
        ("MainTabShell", expectedMainTabShellRoutes),
        ("LibraryShell", expectedLibraryShellRoutes),
        ("SettingsShell", expectedSettingsShellRoutes),
        ("ReaderShell", expectedReaderShellRoutes),
        ("FlowShell", expectedFlowShellRoutes)
    ]

    public static var expectedRouteCount: Int {
        expectedRoutesByShell.reduce(0) { $0 + $1.routes.count }
    }

    private static let discoverFeatureMappings: [DemoRouteMapping] = expectedMainTabShellRoutes
        .filter { $0.hasPrefix("discover-") }
        .map { route in
            DemoRouteMapping(
                demoRoute: route,
                slice: 4,
                shell: "MainTabShell",
                platformTarget: .featureState("DiscoverHomeShellView(demoRoute: \"\(route)\")"),
                stateModel: "DiscoverHomeShellView(demoRoute:) + DemoTopBar + DiscoverDemoState + DiscoverPresentation",
                navigationEntry: "discover tab root feature-state transition; no pushed Route or new tab",
                motionIDs: discoverFeatureMotionIDs(for: route),
                acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
            )
        }

    private static let rssFeedFeatureRoutes: [String] = [
        "rss-all",
        "rss-starred",
        "rss-source-feed",
        "rss-source-category-releases",
        "rss-source-category-issues",
        "rss-source-category-discussions",
        "rss-refreshing"
    ]

    private static let libraryFeatureMappings: [DemoRouteMapping] = [
        DemoRouteMapping(
            demoRoute: "discover-source-login",
            slice: 4,
            shell: "LibraryShell",
            platformTarget: .featureState("DiscoverSourceLoginView"),
            stateModel: "DiscoverSourceLoginView + DemoBackScreen + source login UI state + cookie persistence toggle",
            navigationEntry: "Discover control login action opens LibraryShell subpage; returns to discover feature state after refresh",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward", "state.content.replace"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        )
    ] + rssFeedFeatureRoutes.map { route in
        DemoRouteMapping(
            demoRoute: route,
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .featureState("RSSFeedView(demoRoute: \"\(route)\")"),
            stateModel: "RSSFeedView(demoRoute:) + RSSDemoRouteState + RSSFeedState",
            navigationEntry: "RSS tab LibraryShell feature-state transition; source/category/mode state replaces RSS content",
            motionIDs: rssFeedFeatureMotionIDs(for: route),
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        )
    }

    private static let readerFeatureMappings: [DemoRouteMapping] = expectedReaderShellRoutes
        .filter { $0 != "immersive-reading" && $0 != "reader" }
        .map { route in
            DemoRouteMapping(
                demoRoute: route,
                slice: 3,
                shell: "ReaderShell",
                platformTarget: .featureState("ReaderDemoShellView(demoRoute: \"\(route)\")"),
                stateModel: "ReaderDemoShellView(demoRoute:) + hidden system navigation chrome + ReaderDemoRouteState + ReaderDemoPresentation + ReaderDemoModule.compactRoute/fullRoute + ReaderDemoSession + ReaderDisplaySettings + ReaderAppearanceQuickAction + ReaderSettingsQuickAction + ReaderResponsiveLayout + ReaderResponsiveVisualAudit",
                navigationEntry: "reader-owned chrome inline overlay/control module state; route replaces reader control panel without becoming a main tab; compact module nav switches directory/TTS/appearance/settings locally with reader.module.switch semantics; compact header expands to reader-full-* and full panel collapses back to compact module route; TTS/auto-page controls update a local ReaderDemoSession capsule; appearance/settings controls update local ReaderDisplaySettings",
                motionIDs: readerFeatureMotionIDs(for: route),
                acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests", "MotionTokenAlignmentTests"]
            )
        }

    private static let settingsFeatureMappings: [DemoRouteMapping] = expectedSettingsShellRoutes
        .map { route in
            DemoRouteMapping(
                demoRoute: route,
                slice: 6,
                shell: "SettingsShell",
                platformTarget: .featureState("SettingsDemoShellView(demoRoute: \"\(route)\")"),
                stateModel: "SettingsDemoShellView(demoRoute:) + DemoBackScreen + SettingsDemoRouteState + settings/source/restore demo state",
                navigationEntry: "settings stack feature-state transition; route replaces settings/source content without becoming a main tab",
                motionIDs: settingsFeatureMotionIDs(for: route),
                acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
            )
        }

    private static let baseConcreteMappings: [DemoRouteMapping] = [
        DemoRouteMapping(
            demoRoute: "bookshelf",
            slice: 1,
            shell: "MainTabShell",
            platformTarget: .appTab(.bookshelf),
            stateModel: "AppTab.bookshelf + AppNavigationState.activeTab + BookshelfView + DemoTopBar + DemoPaperScreen + ContinueReadingCard + BookshelfItemDetailView + BookmarksListView + BookmarkRowView",
            navigationEntry: "TabView(selection:) root; no route push; bookshelf item detail and bookmark sheets use demo back bar/paper/card rows instead of system List",
            motionIDs: ["tab.item.press", "tab.item.select", "tab.item.switch", "app.tab.switch"],
            acceptanceTests: ["AppShellAlignmentTests", "BookshelfHTMLCSSStructureAlignmentTests", "ReaderIconAssetAlignmentTests", "MotionTokenAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "discover",
            slice: 1,
            shell: "MainTabShell",
            platformTarget: .appTab(.discover),
            stateModel: "AppTab.discover + AppNavigationState.activeTab + DiscoverHomeShellView + DemoTopBar",
            navigationEntry: "TabView(selection:) root; no route push",
            motionIDs: ["tab.item.press", "tab.item.select", "tab.item.switch", "app.tab.switch"],
            acceptanceTests: ["AppShellAlignmentTests", "DemoComponentPrimitiveAlignmentTests", "ReaderIconAssetAlignmentTests", "MotionTokenAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss",
            slice: 1,
            shell: "MainTabShell",
            platformTarget: .appTab(.rss),
            stateModel: "AppTab.rss + AppNavigationState.activeTab + RSSFeedView + RSSRootTopBar",
            navigationEntry: "TabView(selection:) root; no route push",
            motionIDs: ["tab.item.press", "tab.item.select", "tab.item.switch", "app.tab.switch"],
            acceptanceTests: ["AppShellAlignmentTests", "DemoComponentPrimitiveAlignmentTests", "ReaderIconAssetAlignmentTests", "MotionTokenAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "settings",
            slice: 1,
            shell: "MainTabShell",
            platformTarget: .appTab(.settings),
            stateModel: "AppTab.settings + AppNavigationState.activeTab + SettingsTabView + DemoTopBar + DemoPaperScreen + SettingsRootEntryRow",
            navigationEntry: "TabView(selection:) root; no route push",
            motionIDs: ["tab.item.press", "tab.item.select", "tab.item.switch", "app.tab.switch"],
            acceptanceTests: ["AppShellAlignmentTests", "DemoComponentPrimitiveAlignmentTests", "ReaderIconAssetAlignmentTests", "MotionTokenAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "bookshelf-empty",
            slice: 2,
            shell: "MainTabShell",
            platformTarget: .featureState("BookshelfState.empty"),
            stateModel: "BookshelfViewModel + BookshelfState",
            navigationEntry: "bookshelf tab root state replacement",
            motionIDs: ["state.content.replace"],
            acceptanceTests: ["DemoRouteMappingTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "sort-filter",
            slice: 2,
            shell: "MainTabShell",
            platformTarget: .featureState("BookshelfFilterSheet"),
            stateModel: "BookshelfView + BookshelfFilterPopover + bookshelfGroup/sort/filter state",
            navigationEntry: "bookshelf toolbar or sort/filter control; no main-tab change",
            motionIDs: ["dropdown.menu.expand", "dropdown.menu.collapse", "dropdown.option.select"],
            acceptanceTests: ["DemoRouteMappingTests", "BookshelfHTMLCSSStructureAlignmentTests", "DemoComponentPrimitiveAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "book-search",
            slice: 2,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.search),
            stateModel: "Route.search + Route.searchResults(query:) + DemoBackScreen + SearchView(initialQuery:) + SearchHistoryRow + SearchResultDemoRow + SearchScope + BottomFixedActionRow",
            navigationEntry: "bookshelf toolbar search action pushes demo-aligned SearchView; legacy searchResults value route pre-fills SearchView(initialQuery:); result rows push BookDetailView; in-shelf action can enter ReaderView",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward", "input.focus"],
            acceptanceTests: ["DemoRouteMappingTests", "BookshelfHTMLCSSStructureAlignmentTests", "AppShellAlignmentTests", "DemoComponentPrimitiveAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "book-detail",
            slice: 2,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.bookDetail),
            stateModel: "Route.bookDetail(bookURL:title:author:) + DemoBackScreen + BookDetailView + BookDetailCoverView + BookDetailPreviewChapterRow + BottomFixedActionRow",
            navigationEntry: "search result or bookshelf item pushes demo-aligned book detail; chapter preview pushes reader; directory button pushes BookDirectoryPreviewView",
            motionIDs: ["card.route", "app.route.push.forward", "button.press", "button.activate"],
            acceptanceTests: ["DemoRouteMappingTests", "BookshelfHTMLCSSStructureAlignmentTests", "AppShellAlignmentTests", "DemoComponentPrimitiveAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "book-directory",
            slice: 2,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.bookDetailToc),
            stateModel: "Route.bookDetailToc(bookURL:title:) + DemoBackScreen + BookDirectoryPreviewView + directory/bookmark mode state",
            navigationEntry: "book detail TOC entry pushes demo-aligned full directory page",
            motionIDs: ["app.route.push.forward", "button.press", "button.activate"],
            acceptanceTests: ["DemoRouteMappingTests", "BookshelfHTMLCSSStructureAlignmentTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-detail",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssDetail),
            stateModel: "Route.rssDetail(rssID:) + DemoBackScreen + RSSArticleDetailView + SubscriptionItem",
            navigationEntry: "RSS article row pushes RSSArticleDetailView; global route has fallback item",
            motionIDs: ["listRow.route", "app.route.push.forward", "button.press", "button.activate"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-original",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssOriginal),
            stateModel: "Route.rssOriginal(url:title:sourceTitle:) + DemoBackScreen + RSSOriginalPreviewView + WKWebView",
            navigationEntry: "RSSArticleDetailView original actions push RSSOriginalPreviewView inside the RSS stack",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-original-browser",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssOriginalBrowser),
            stateModel: "Route.rssOriginalBrowser(url:title:sourceTitle:) + DemoBackScreen + RSSOriginalBrowserConfirmView + OpenURLAction",
            navigationEntry: "RSSOriginalPreviewView browser action pushes confirmation; confirm opens system browser and returns to RSS reader context",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-subscription-management",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSubscriptions),
            stateModel: "Route.rssSubscriptions + DemoBackScreen + RSSSubscriptionManagementView + RSSManagementSource",
            navigationEntry: "RSS tab manage action and RSS reader source settings push RSSSubscriptionManagementView",
            motionIDs: ["button.press", "button.activate", "chip.item.press", "chip.item.select", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-actions",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceActions),
            stateModel: "Route.rssSourceActions(sourceID:title:) + DemoBackScreen + RSSSourceActionsView + RSSManagementSource",
            navigationEntry: "RSSSubscriptionManagementView source more action pushes RSSSourceActionsView",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-edit",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceEdit),
            stateModel: "Route.rssSourceEdit(sourceID:title:) + DemoBackScreen + RSSSourceEditView + RSSEditField",
            navigationEntry: "RSSSourceActionsView edit action pushes RSSSourceEditView; debug toolbar pushes RSSSourceDebugView",
            motionIDs: ["button.press", "button.activate", "chip.item.press", "chip.item.select", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-debug",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceDebug),
            stateModel: "Route.rssSourceDebug(sourceID:title:) + DemoBackScreen + RSSSourceDebugView + RSSDebugPanel",
            navigationEntry: "RSSSourceActionsView debug action and RSSSourceEditView debug action push RSSSourceDebugView",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-vars",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceVars),
            stateModel: "Route.rssSourceVars(sourceID:title:) + DemoBackScreen + RSSSourceVarsView + RSSEditField",
            navigationEntry: "RSSSourceActionsView vars action pushes RSSSourceVarsView; test action pushes RSSSourceDebugView",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-login",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceLogin),
            stateModel: "Route.rssSourceLogin(sourceID:title:) + DemoBackScreen + RSSSourceLoginView + RSSSourceInfoPanel",
            navigationEntry: "RSSSourceActionsView login action pushes RSSSourceLoginView; login action grid pushes web/cookie/debug/clear subroutes",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-login-web",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceLoginWeb),
            stateModel: "Route.rssSourceLoginWeb(sourceID:title:) + DemoBackScreen + RSSSourceLoginWebView + RSSLoginWebPreview",
            navigationEntry: "RSSSourceLoginView web login action pushes RSSSourceLoginWebView; login complete pushes RSSSourceLoginCookieView",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-login-cookie",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceLoginCookie),
            stateModel: "Route.rssSourceLoginCookie(sourceID:title:) + DemoBackScreen + RSSSourceLoginCookieView + RSSSourceInfoPanel",
            navigationEntry: "RSSSourceLoginView cookie action and RSSSourceLoginWebView completion push RSSSourceLoginCookieView",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-login-clear",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceLoginClear),
            stateModel: "Route.rssSourceLoginClear(sourceID:title:) + DemoBackScreen + RSSSourceLoginClearView + RSSSourceConfirmCard",
            navigationEntry: "RSSSourceLoginView clear login action pushes RSSSourceLoginClearView",
            motionIDs: ["button.press", "button.activate", "overlay.dialog.enter", "overlay.dialog.exit", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-groups",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceGroups),
            stateModel: "Route.rssSourceGroups + DemoBackScreen + RSSSourceGroupsView + RSSManagementIconRow",
            navigationEntry: "RSSSubscriptionManagementView group action pushes RSSSourceGroupsView; group actions push RSSSourceGroupEditView",
            motionIDs: ["button.press", "button.activate", "toggle.switch", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-group-edit",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceGroupEdit),
            stateModel: "Route.rssSourceGroupEdit(groupID:title:) + DemoBackScreen + RSSSourceGroupEditView + RSSEditField",
            navigationEntry: "RSSSourceGroupsView add/rename actions push RSSSourceGroupEditView",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-batch",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceBatch),
            stateModel: "Route.rssSourceBatch + DemoBackScreen + RSSSourceBatchView + RSSManagementIconRow",
            navigationEntry: "RSSSubscriptionManagementView batch action pushes RSSSourceBatchView; bottom actions push export or batch-disable",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-export",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceExport),
            stateModel: "Route.rssSourceExport + DemoBackScreen + RSSSourceExportView + RSSImportOptionPanel + RSSImportExportRow",
            navigationEntry: "RSSSourceBatchView and RSSSubscriptionManagementView export actions push RSSSourceExportView",
            motionIDs: ["button.press", "button.activate", "chip.item.press", "chip.item.select", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-export-detail",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceExportDetail),
            stateModel: "Route.rssSourceExportDetail(sourceID:title:) + DemoBackScreen + RSSSourceExportDetailView + RSSSourceInfoPanel",
            navigationEntry: "RSSSourceExportView preview rows push RSSSourceExportDetailView",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-export-result",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceExportResult),
            stateModel: "Route.rssSourceExportResult + DemoBackScreen + RSSSourceExportResultView + RSSSourceConfirmationPage",
            navigationEntry: "RSSSourceExportView and RSSSourceExportDetailView export actions push RSSSourceExportResultView",
            motionIDs: ["button.press", "button.activate", "overlay.dialog.enter", "overlay.dialog.exit", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-pin",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourcePin),
            stateModel: "Route.rssSourcePin(sourceID:title:) + DemoBackScreen + RSSSourcePinConfirmView + RSSSourceConfirmationPage",
            navigationEntry: "RSSSourceActionsView pin action pushes RSSSourcePinConfirmView",
            motionIDs: ["button.press", "button.activate", "overlay.dialog.enter", "overlay.dialog.exit", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-disable",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceDisable),
            stateModel: "Route.rssSourceDisable(sourceID:title:) + DemoBackScreen + RSSSourceDisableConfirmView + RSSSourceConfirmationPage",
            navigationEntry: "RSSSourceActionsView disable action pushes RSSSourceDisableConfirmView",
            motionIDs: ["button.press", "button.activate", "overlay.dialog.enter", "overlay.dialog.exit", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-batch-disable",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceBatchDisable),
            stateModel: "Route.rssSourceBatchDisable + DemoBackScreen + RSSSourceBatchDisableConfirmView + RSSSourceConfirmationPage",
            navigationEntry: "RSSSubscriptionManagementView and RSSSourceBatchView disable actions push RSSSourceBatchDisableConfirmView",
            motionIDs: ["button.press", "button.activate", "overlay.dialog.enter", "overlay.dialog.exit", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-import",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceImport),
            stateModel: "Route.rssSourceImport + DemoBackScreen + RSSSourceImportView + RSSImportOptionPanel + RSSImportExportRow",
            navigationEntry: "RSSSubscriptionManagementView import action pushes RSSSourceImportView",
            motionIDs: ["button.press", "button.activate", "chip.item.press", "chip.item.select", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-import-detail",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceImportDetail),
            stateModel: "Route.rssSourceImportDetail(sourceID:title:) + DemoBackScreen + RSSSourceImportDetailView + RSSSourceInfoPanel",
            navigationEntry: "RSSSourceImportView import preview rows push RSSSourceImportDetailView",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-source-import-result",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSourceImportResult),
            stateModel: "Route.rssSourceImportResult + DemoBackScreen + RSSSourceImportResultView + RSSSourceConfirmationPage",
            navigationEntry: "RSSSourceImportView import action pushes RSSSourceImportResultView",
            motionIDs: ["button.press", "button.activate", "overlay.dialog.enter", "overlay.dialog.exit", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-search",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssSearch),
            stateModel: "Route.rssSearch + DemoBackScreen + RSSSearchView + RSSDemoArticle search scope",
            navigationEntry: "RSSFeedView top search action pushes RSSSearchView; result rows push RSSArticleDetailView",
            motionIDs: ["button.press", "button.activate", "chip.item.press", "chip.item.select", "input.focus", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-read-record",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssReadRecord),
            stateModel: "Route.rssReadRecord(sourceID:title:) + DemoBackScreen + RSSReadRecordView + RSSReadRecord",
            navigationEntry: "RSSSourceActionsView read-record action pushes RSSReadRecordView; record rows push RSSArticleDetailView",
            motionIDs: ["button.press", "button.activate", "listRow.route", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-record-clear",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssRecordClear),
            stateModel: "Route.rssRecordClear + DemoBackScreen + RSSRecordClearConfirmView + RSSSupplementalConfirmPage",
            navigationEntry: "RSSReadRecordView clear action pushes RSSRecordClearConfirmView",
            motionIDs: ["button.press", "button.activate", "overlay.dialog.enter", "overlay.dialog.exit", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-rule-subscription",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssRuleSubscription),
            stateModel: "Route.rssRuleSubscription + DemoBackScreen + RSSRuleSubscriptionView + RSSRuleSubscription",
            navigationEntry: "RSSSubscriptionManagementView rule-subscription action pushes RSSRuleSubscriptionView",
            motionIDs: ["button.press", "button.activate", "listRow.route", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-rule-subscription-detail",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssRuleSubscriptionDetail),
            stateModel: "Route.rssRuleSubscriptionDetail(subscriptionID:title:) + DemoBackScreen + RSSRuleSubscriptionDetailView + RSSImportChangeList",
            navigationEntry: "RSSRuleSubscriptionView rows and open action push RSSRuleSubscriptionDetailView",
            motionIDs: ["button.press", "button.activate", "listRow.route", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-rule-subscription-edit",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssRuleSubscriptionEdit),
            stateModel: "Route.rssRuleSubscriptionEdit(subscriptionID:title:) + DemoBackScreen + RSSRuleSubscriptionEditView + RSSSupplementalEditField",
            navigationEntry: "RSSRuleSubscriptionDetailView edit action pushes RSSRuleSubscriptionEditView",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-rule-subscription-test",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssRuleSubscriptionTest),
            stateModel: "Route.rssRuleSubscriptionTest(subscriptionID:title:) + DemoBackScreen + RSSRuleSubscriptionTestView + RSSSupplementalInfoPanel",
            navigationEntry: "RSSRuleSubscriptionEditView test action pushes RSSRuleSubscriptionTestView",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-rule-subscription-apply",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssRuleSubscriptionApply),
            stateModel: "Route.rssRuleSubscriptionApply + DemoBackScreen + RSSRuleSubscriptionApplyConfirmView + RSSSupplementalConfirmPage",
            navigationEntry: "RSSRuleSubscriptionDetailView apply action pushes RSSRuleSubscriptionApplyConfirmView",
            motionIDs: ["button.press", "button.activate", "overlay.dialog.enter", "overlay.dialog.exit", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-favorite-groups",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssFavoriteGroups),
            stateModel: "Route.rssFavoriteGroups + DemoBackScreen + RSSFavoriteGroupsView + RSSFavoriteGroup",
            navigationEntry: "RSS favorites management action pushes RSSFavoriteGroupsView; global route has fallback",
            motionIDs: ["button.press", "button.activate", "listRow.route", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-favorite-group-edit",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssFavoriteGroupEdit),
            stateModel: "Route.rssFavoriteGroupEdit(groupID:title:) + DemoBackScreen + RSSFavoriteGroupEditView + RSSSupplementalEditField",
            navigationEntry: "RSSFavoriteGroupsView add/sort/group rows push RSSFavoriteGroupEditView",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-favorite-clear",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssFavoriteClear),
            stateModel: "Route.rssFavoriteClear + DemoBackScreen + RSSFavoriteClearConfirmView + RSSSupplementalConfirmPage",
            navigationEntry: "RSS favorite clear action pushes RSSFavoriteClearConfirmView; global route has fallback",
            motionIDs: ["button.press", "button.activate", "overlay.dialog.enter", "overlay.dialog.exit", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-empty",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssEmpty),
            stateModel: "Route.rssEmpty + DemoBackScreen + RSSStateView(kind: .empty) + RSSStateKind",
            navigationEntry: "RSS empty state route replaces RSS content while preserving RSS stack context",
            motionIDs: ["state.content.replace", "button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "rss-error",
            slice: 5,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.rssError),
            stateModel: "Route.rssError + DemoBackScreen + RSSStateView(kind: .error) + RSSStateKind",
            navigationEntry: "RSS error state route replaces RSS content while preserving RSS stack context",
            motionIDs: ["state.content.replace", "button.press", "button.activate", "app.route.push.forward"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "group-management",
            slice: 2,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.bookshelfGroups),
            stateModel: "Route.bookshelfGroups + DemoBackScreen + BookshelfGroupManagementView + BookshelfGroupItem assignment state",
            navigationEntry: "bookshelf more/focus menu and batch move action push group management",
            motionIDs: ["app.route.push.forward", "button.press", "button.activate"],
            acceptanceTests: ["DemoRouteMappingTests", "BookshelfHTMLCSSStructureAlignmentTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "book-batch-management",
            slice: 2,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.bookBatchManagement),
            stateModel: "Route.bookBatchManagement + DemoBackScreen + BookshelfBatchManagementView + BookBatchItem selection state",
            navigationEntry: "Bookshelf more menu and book focus menu push BookshelfBatchManagementView",
            motionIDs: ["button.press", "button.activate", "app.route.push.forward", "state.content.replace"],
            acceptanceTests: ["DemoRouteMappingTests", "BookshelfHTMLCSSStructureAlignmentTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "local-import",
            slice: 2,
            shell: "LibraryShell",
            platformTarget: .nativeRoute(.bookshelfImport),
            stateModel: "Route.bookshelfImport + DemoBackScreen + BookshelfLocalImportView + FileImportViewModel import state",
            navigationEntry: "bookshelf toolbar and more menu push local import flow",
            motionIDs: ["app.route.push.forward", "button.press", "button.activate", "input.focus"],
            acceptanceTests: ["DemoRouteMappingTests", "BookshelfHTMLCSSStructureAlignmentTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "immersive-reading",
            slice: 3,
            shell: "ReaderShell",
            platformTarget: .readerContext(.coverToImmersive),
            stateModel: "ReaderContext + AppNavigationState.readerContext + ReaderView + ReaderReadingLayer + ReaderProgressSurfaceView + ReaderResponsiveLayout + hidden system navigation chrome",
            navigationEntry: "BookshelfView.enterImmersive(...) sets ReaderContext then pushes ReaderView with demo reading layer and reader top surface",
            motionIDs: ["reader.entry.coverToImmersive", "reader.entry.actionToImmersive", "motion.async.resultGuard"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "MotionTokenAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "reader",
            slice: 3,
            shell: "ReaderShell",
            platformTarget: .nativeRoute(.reader),
            stateModel: "Route.reader(bookID:chapterURL:chapterTitle:) + ReaderView + TOCView + TOCChapterDemoRow + ContentView + ReaderContentSectionView + ReaderInlineDestination + ReaderHotZoneSegment + ReaderControlSession + ReaderAppearanceQuickAction + ReaderSettingsQuickAction + ReaderReadingLayer + ReaderStateCard + ReaderStateBanner + ReaderProgressSurfaceView + ReaderResponsiveLayout + ReaderResponsiveVisualAudit + hidden system navigation chrome + ReaderSourceSwitchFlowView entry + reader-full-directory + reader-full-tts + reader-full-appearance + reader-full-settings entries",
            navigationEntry: "reader destination is pushed from detail/continue-reading, never a main tab; system navigation bar is hidden; contextful Route.toc/Route.content keep real coordinator data but use DemoBackScreen + paper/card rows instead of system navigation titles; reader top source action pushes source-switch; directory/TTS/appearance/settings modules open ReaderDemoShellView(reader-full-directory/reader-full-tts/reader-full-appearance/reader-full-settings); hotzone prev/next trigger paginated page turns; control sheet previous/next buttons call chapter navigation; appearance quick controls update ReaderDisplaySettings typography/theme/page mode; settings quick controls update tap zones, volume-key page turns, dual page mode, and brightness override; TTS module controls update ReaderControlSession and the running capsule",
            motionIDs: ["reader.control.show", "reader.control.hide", "reader.module.switch", "reader.page.turn.prev", "reader.page.turn.next", "reader.chapter.jump", "reader.session.tts.start", "reader.session.capsule.enter/update/switch/exit", "app.route.push.forward", "motion.async.resultGuard"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "MotionTokenAlignmentTests"]
        ),
        DemoRouteMapping(
            demoRoute: "source-switch",
            slice: 3,
            shell: "FlowShell",
            platformTarget: .nativeRoute(.sourceSwitch),
            stateModel: "Route.sourceSwitch(bookURL:) + DemoBackScreen + ReaderSourceSwitchFlowView + SourceSwitchCandidate selection state",
            navigationEntry: "reader inline source-switch flow pushes DemoBackScreen + ReaderSourceSwitchFlowView; not a main tab",
            motionIDs: ["reader.sourceSwitch.open", "reader.sourceSwitch.close", "overlay.sheet.enter", "overlay.sheet.exit"],
            acceptanceTests: ["DemoRouteMappingTests", "DemoComponentPrimitiveAlignmentTests", "AppShellAlignmentTests", "MotionTokenAlignmentTests"]
        )
    ]

    private static let concreteMappings: [DemoRouteMapping] = baseConcreteMappings + discoverFeatureMappings + libraryFeatureMappings + readerFeatureMappings + settingsFeatureMappings

    private static var concreteRouteNames: Set<String> {
        Set(concreteMappings.map(\.demoRoute))
    }

    private static var plannedMappings: [DemoRouteMapping] {
        expectedRoutesByShell.flatMap { shell, routes in
            routes
                .filter { !concreteRouteNames.contains($0) }
                .map { plannedMapping(route: $0, shell: shell) }
        }
    }

    public static var all: [DemoRouteMapping] {
        concreteMappings + plannedMappings
    }

    public static func mapping(for demoRoute: String) -> DemoRouteMapping? {
        all.first { $0.demoRoute == demoRoute }
    }

    public static let mainTabRoutes: [String] = ["bookshelf", "discover", "rss", "settings"]

    public static let shortestBookToReaderPath: [String] = [
        "bookshelf",
        "book-search",
        "book-detail",
        "book-directory",
        "immersive-reading",
        "reader"
    ]

    private static func discoverFeatureMotionIDs(for route: String) -> [String] {
        if route.contains("-entry-") {
            return ["chip.item.press", "chip.item.select", "state.content.replace"]
        }
        if route.contains("-filter-") {
            return ["dropdown.trigger.press", "dropdown.option.select", "state.content.replace"]
        }
        if route == "discover-sort" || route.contains("-sort-") {
            return ["dropdown.trigger.press", "dropdown.menu.expand", "dropdown.option.select", "state.content.replace"]
        }
        if route == "discover-cache-confirm" {
            return ["button.press", "button.activate", "overlay.dialog.enter", "overlay.dialog.exit"]
        }
        if route == "discover-cache-toast" {
            return ["button.press", "button.activate", "feedback.toast.show", "feedback.toast.hide"]
        }
        if route == "discover-loading" || route == "discover-refreshing" || route == "discover-infinite-loading" || route == "discover-login-return" {
            return ["state.content.replace", "motion.async.resultGuard"]
        }
        return ["button.press", "button.activate", "state.content.replace"]
    }

    private static func rssFeedFeatureMotionIDs(for route: String) -> [String] {
        if route == "rss-refreshing" {
            return ["button.press", "button.activate", "state.content.replace", "motion.async.resultGuard"]
        }
        if route == "rss-source-feed" || route.hasPrefix("rss-source-category-") {
            return ["chip.item.press", "chip.item.select", "dropdown.option.select", "state.content.replace"]
        }
        return ["chip.item.press", "chip.item.select", "listRow.route", "state.content.replace"]
    }

    private static func readerFeatureMotionIDs(for route: String) -> [String] {
        if route.hasPrefix("reader-full-") || route == "reader-book-cache" || route == "reader-debug-info" {
            return ["reader.control.handle.press", "reader.control.handle.drag", "overlay.sheet.enter", "overlay.sheet.exit", "state.content.replace"]
        }
        if route == "auto-page" {
            return ["reader.module.switch", "reader.session.autoPage.start", "reader.session.capsule.enter", "state.content.replace"]
        }
        if route == "tts" {
            return ["reader.module.switch", "reader.session.tts.start", "reader.session.capsule.enter", "state.content.replace"]
        }
        return ["reader.module.switch", "overlay.sheet.enter", "overlay.sheet.exit", "state.content.replace"]
    }

    private static func settingsFeatureMotionIDs(for route: String) -> [String] {
        if route == "source-delete-confirm" || route.hasPrefix("restore-") {
            return ["button.press", "button.activate", "overlay.dialog.enter", "overlay.dialog.exit", "state.content.replace"]
        }
        if route == "source-import-options" {
            return ["button.press", "button.activate", "overlay.sheet.enter", "overlay.sheet.exit", "state.content.replace"]
        }
        if route.hasPrefix("source-debug") || route == "source-detect" || route == "source-code-view" || route == "discover-rule-test" {
            return ["chip.item.press", "chip.item.select", "input.focus", "button.press", "button.activate", "state.content.replace"]
        }
        if route.hasPrefix("source") || route == "discover-source-bulk" {
            return ["chip.item.press", "chip.item.select", "toggle.switch", "button.press", "button.activate", "state.content.replace"]
        }
        return ["toggle.switch", "input.focus", "chip.item.press", "chip.item.select", "state.content.replace"]
    }

    private static func plannedMapping(route: String, shell: String) -> DemoRouteMapping {
        DemoRouteMapping(
            demoRoute: route,
            slice: plannedSlice(for: route, shell: shell),
            shell: shell,
            platformTarget: .planned(plannedTarget(for: route, shell: shell)),
            stateModel: plannedStateModel(for: route, shell: shell),
            navigationEntry: plannedNavigationEntry(for: route, shell: shell),
            motionIDs: plannedMotionIDs(for: route, shell: shell),
            acceptanceTests: ["PlannedRouteMappingTests", "slice-specific focused tests before visual implementation"]
        )
    }

    private static func plannedSlice(for route: String, shell: String) -> Int {
        if route.hasPrefix("discover") { return 4 }
        if route.hasPrefix("rss") { return 5 }
        if route.hasPrefix("settings")
            || route.hasPrefix("source")
            || route.hasPrefix("restore")
            || route == "webdav-config"
            || route == "sync-backup"
            || route == "about-feedback"
            || route == "bookshelf-search-settings" {
            return 6
        }
        if shell == "ReaderShell" { return 3 }
        if route.hasPrefix("book") || route.hasPrefix("group") || route == "local-import" || route == "sort-filter" || route == "bookshelf-empty" {
            return 2
        }
        return 7
    }

    private static func plannedTarget(for route: String, shell: String) -> String {
        switch plannedSlice(for: route, shell: shell) {
        case 3:
            return "Reader module/control state: \(route)"
        case 4:
            return "DiscoverUIState route/state: \(route)"
        case 5:
            return "RSSUIState route/state: \(route)"
        case 6:
            return "SettingsUIState/SourceManagementState route/state: \(route)"
        case 7:
            return "Shared state surface route/state: \(route)"
        default:
            return "Bookshelf/library route/state: \(route)"
        }
    }

    private static func plannedStateModel(for route: String, shell: String) -> String {
        switch plannedSlice(for: route, shell: shell) {
        case 3:
            return "ReaderViewModel + ReaderSession/OverlayState planned state for \(route)"
        case 4:
            return "DiscoverUIState planned source/entry/filter/sort/state field for \(route)"
        case 5:
            return "RSSUIState planned mode/source/detail/management field for \(route)"
        case 6:
            return "SettingsUIState + SourceManagementState planned field for \(route)"
        case 7:
            return "Shared loading/error/permission/toast state planned for \(route)"
        default:
            return "BookshelfViewModel or library flow planned field for \(route)"
        }
    }

    private static func plannedNavigationEntry(for route: String, shell: String) -> String {
        switch shell {
        case "MainTabShell":
            return "current tab root feature-state transition; no new main tab"
        case "LibraryShell":
            return "domain NavigationStack destination or feature-state transition under current tab"
        case "SettingsShell":
            return "settings NavigationStack destination or source-management feature state"
        case "ReaderShell", "FlowShell":
            return "reader inline overlay/control module state; not a main tab"
        default:
            return "planned route ownership"
        }
    }

    private static func plannedMotionIDs(for route: String, shell: String) -> [String] {
        switch plannedSlice(for: route, shell: shell) {
        case 3:
            return ["reader.module.switch", "overlay.sheet.enter", "overlay.sheet.exit", "state.content.replace"]
        case 4:
            return ["chip.item.press", "chip.item.select", "dropdown.option.select", "state.content.replace"]
        case 5:
            return ["chip.item.press", "chip.item.select", "input.focus", "state.content.replace"]
        case 6:
            return ["toggle.switch", "input.focus", "overlay.sheet.enter", "state.content.replace"]
        case 7:
            return ["state.content.replace", "feedback.toast.show", "overlay.dialog.enter", "motion.async.resultGuard"]
        default:
            return ["button.press", "button.activate", "app.route.push.forward", "state.content.replace"]
        }
    }
}
