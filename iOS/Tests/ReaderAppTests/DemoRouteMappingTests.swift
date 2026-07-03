import XCTest
@testable import ReaderApp

@MainActor
final class DemoRouteMappingTests: XCTestCase {

    func testMainTabDemoRoutesMapToAppTabsInContractOrder() {
        let mappedTabs = DemoRouteMappings.mainTabRoutes.compactMap { route -> AppTab? in
            guard case .appTab(let tab) = DemoRouteMappings.mapping(for: route)?.platformTarget else {
                return nil
            }
            return tab
        }

        XCTAssertEqual(mappedTabs, AppTab.contractOrder)
    }

    func testMainTabRoutesAreNotModeledAsPushedRoutes() {
        for route in DemoRouteMappings.mainTabRoutes {
            let mapping = DemoRouteMappings.mapping(for: route)
            guard case .appTab = mapping?.platformTarget else {
                return XCTFail("\(route) must map to AppTab, not Route")
            }
        }
    }

    func testSliceTwoShortestBookToReaderPathIsMapped() {
        let path = DemoRouteMappings.shortestBookToReaderPath
        XCTAssertEqual(path, [
            "bookshelf",
            "book-search",
            "book-detail",
            "book-directory",
            "immersive-reading",
            "reader"
        ])

        for route in path {
            XCTAssertNotNil(DemoRouteMappings.mapping(for: route), "\(route) must have a platform mapping")
        }
    }

    func testSliceTwoRoutesMapToExpectedNativeTargets() {
        XCTAssertEqual(DemoRouteMappings.mapping(for: "book-search")?.platformTarget, .nativeRoute(.search))
        XCTAssertEqual(DemoRouteMappings.mapping(for: "book-detail")?.platformTarget, .nativeRoute(.bookDetail))
        XCTAssertEqual(DemoRouteMappings.mapping(for: "book-directory")?.platformTarget, .nativeRoute(.bookDetailToc))
        XCTAssertEqual(DemoRouteMappings.mapping(for: "book-batch-management")?.platformTarget, .nativeRoute(.bookBatchManagement))
        XCTAssertEqual(DemoRouteMappings.mapping(for: "group-management")?.platformTarget, .nativeRoute(.bookshelfGroups))
        XCTAssertEqual(DemoRouteMappings.mapping(for: "local-import")?.platformTarget, .nativeRoute(.bookshelfImport))
    }

    func testBookshelfRootRouteMapsToDemoAlignedSurface() {
        let mapping = DemoRouteMappings.mapping(for: "bookshelf")

        XCTAssertEqual(mapping?.shell, "MainTabShell")
        XCTAssertEqual(mapping?.platformTarget, .appTab(.bookshelf))
        XCTAssertTrue(mapping?.stateModel.contains("BookshelfView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("DemoTopBar") == true)
        XCTAssertTrue(mapping?.stateModel.contains("DemoPaperScreen") == true)
        XCTAssertTrue(mapping?.stateModel.contains("ContinueReadingCard") == true)
        XCTAssertTrue(mapping?.stateModel.contains("BookshelfItemDetailView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("BookmarksListView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("BookmarkRowView") == true)
        XCTAssertTrue(mapping?.navigationEntry.contains("instead of system List") == true)
        XCTAssertTrue(mapping?.acceptanceTests.contains("BookshelfHTMLCSSStructureAlignmentTests") == true)
    }

    func testDiscoverRootRouteMapsToDemoTopBarSurface() {
        let mapping = DemoRouteMappings.mapping(for: "discover")

        XCTAssertEqual(mapping?.shell, "MainTabShell")
        XCTAssertEqual(mapping?.platformTarget, .appTab(.discover))
        XCTAssertTrue(mapping?.stateModel.contains("DiscoverHomeShellView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("DemoTopBar") == true)
        XCTAssertTrue(mapping?.acceptanceTests.contains("DemoComponentPrimitiveAlignmentTests") == true)
    }

    func testRSSRootRouteMapsToDemoTopBarSurface() {
        let mapping = DemoRouteMappings.mapping(for: "rss")

        XCTAssertEqual(mapping?.shell, "MainTabShell")
        XCTAssertEqual(mapping?.platformTarget, .appTab(.rss))
        XCTAssertTrue(mapping?.stateModel.contains("RSSFeedView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("RSSRootTopBar") == true)
        XCTAssertTrue(mapping?.acceptanceTests.contains("DemoComponentPrimitiveAlignmentTests") == true)
    }

    func testSettingsRootRouteMapsToDemoTopBarSurface() {
        let mapping = DemoRouteMappings.mapping(for: "settings")

        XCTAssertEqual(mapping?.shell, "MainTabShell")
        XCTAssertEqual(mapping?.platformTarget, .appTab(.settings))
        XCTAssertTrue(mapping?.stateModel.contains("SettingsTabView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("DemoTopBar") == true)
        XCTAssertTrue(mapping?.stateModel.contains("DemoPaperScreen") == true)
        XCTAssertTrue(mapping?.stateModel.contains("SettingsRootEntryRow") == true)
        XCTAssertTrue(mapping?.acceptanceTests.contains("DemoComponentPrimitiveAlignmentTests") == true)
    }

    func testSettingsRootEntriesMatchDemoMainTabSettingsRoutes() {
        XCTAssertEqual(SettingsTabView.demoRootRoutes, [
            "settings-general",
            "bookshelf-search-settings",
            "source-management",
            "sync-backup",
            "about-feedback"
        ])

        for route in SettingsTabView.demoRootRoutes {
            let mapping = DemoRouteMappings.mapping(for: route)
            XCTAssertEqual(mapping?.shell, "SettingsShell")
            guard case .featureState(let stateName) = mapping?.platformTarget else {
                return XCTFail("\(route) must open a SettingsShell feature state")
            }
            XCTAssertTrue(stateName.contains("SettingsDemoShellView"))
        }
    }

    func testGroupManagementRouteMapsToConcreteBookshelfView() {
        let mapping = DemoRouteMappings.mapping(for: "group-management")

        XCTAssertEqual(mapping?.shell, "LibraryShell")
        XCTAssertEqual(mapping?.platformTarget, .nativeRoute(.bookshelfGroups))
        XCTAssertTrue(mapping?.stateModel.contains("BookshelfGroupManagementView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("BookshelfGroupItem") == true)
        XCTAssertTrue(mapping?.navigationEntry.contains("batch move") == true)
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testLocalImportRouteMapsToConcreteBookshelfImportView() {
        let mapping = DemoRouteMappings.mapping(for: "local-import")

        XCTAssertEqual(mapping?.shell, "LibraryShell")
        XCTAssertEqual(mapping?.platformTarget, .nativeRoute(.bookshelfImport))
        XCTAssertTrue(mapping?.stateModel.contains("BookshelfLocalImportView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("FileImportViewModel") == true)
        XCTAssertTrue(mapping?.navigationEntry.contains("toolbar") == true)
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testBookshelfSecondaryRoutesUseDemoBackScreen() {
        let routes = [
            "book-search",
            "book-detail",
            "book-directory",
            "book-batch-management",
            "group-management",
            "local-import"
        ]

        for route in routes {
            let mapping = DemoRouteMappings.mapping(for: route)
            XCTAssertEqual(mapping?.shell, "LibraryShell")
            XCTAssertTrue(mapping?.stateModel.contains("DemoBackScreen") == true, route)
            XCTAssertTrue(mapping?.acceptanceTests.contains("DemoComponentPrimitiveAlignmentTests") == true, route)
        }
    }

    func testBookshelfSortFilterRouteMapsToConcreteFilterState() {
        let mapping = DemoRouteMappings.mapping(for: "sort-filter")

        XCTAssertEqual(mapping?.shell, "MainTabShell")
        XCTAssertTrue(mapping?.stateModel.contains("BookshelfFilterPopover") == true)
        XCTAssertTrue(mapping?.stateModel.contains("bookshelfGroup/sort/filter") == true)
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testBookSearchRouteMapsToConcreteDemoAlignedView() {
        let mapping = DemoRouteMappings.mapping(for: "book-search")

        XCTAssertEqual(mapping?.shell, "LibraryShell")
        XCTAssertEqual(mapping?.platformTarget, .nativeRoute(.search))
        XCTAssertTrue(mapping?.stateModel.contains("Route.searchResults") == true)
        XCTAssertTrue(mapping?.stateModel.contains("SearchView(initialQuery:)") == true)
        XCTAssertTrue(mapping?.stateModel.contains("SearchView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("SearchHistoryRow") == true)
        XCTAssertTrue(mapping?.stateModel.contains("SearchResultDemoRow") == true)
        XCTAssertTrue(mapping?.stateModel.contains("BottomFixedActionRow") == true)
        XCTAssertTrue(mapping?.navigationEntry.contains("SearchView(initialQuery:)") == true)
        XCTAssertTrue(mapping?.navigationEntry.contains("BookDetailView") == true)
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testBookDetailRouteMapsToConcreteDemoAlignedView() {
        let mapping = DemoRouteMappings.mapping(for: "book-detail")

        XCTAssertEqual(mapping?.shell, "LibraryShell")
        XCTAssertEqual(mapping?.platformTarget, .nativeRoute(.bookDetail))
        XCTAssertTrue(mapping?.stateModel.contains("BookDetailView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("BookDetailCoverView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("BookDetailPreviewChapterRow") == true)
        XCTAssertTrue(mapping?.stateModel.contains("BottomFixedActionRow") == true)
        XCTAssertTrue(mapping?.navigationEntry.contains("BookDirectoryPreviewView") == true)
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testBookDirectoryRouteMapsToConcreteDirectoryPreviewView() {
        let mapping = DemoRouteMappings.mapping(for: "book-directory")

        XCTAssertEqual(mapping?.shell, "LibraryShell")
        XCTAssertEqual(mapping?.platformTarget, .nativeRoute(.bookDetailToc))
        XCTAssertTrue(mapping?.stateModel.contains("BookDirectoryPreviewView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("directory/bookmark mode") == true)
        XCTAssertFalse(mapping?.stateModel.contains("TOCView") == true)
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testDiscoverMainTabRoutesMapToFeatureStatesNotPushedRoutes() {
        let discoverRoutes = DemoRouteMappings.expectedMainTabShellRoutes.filter { $0.hasPrefix("discover-") }
        XCTAssertEqual(discoverRoutes.count, 30)

        for route in discoverRoutes {
            let mapping = DemoRouteMappings.mapping(for: route)
            XCTAssertEqual(mapping?.shell, "MainTabShell")
            XCTAssertEqual(mapping?.slice, 4)
            guard case .featureState(let stateName) = mapping?.platformTarget else {
                return XCTFail("\(route) must map to a Discover feature state, not a pushed Route")
            }
            XCTAssertTrue(stateName.contains("DiscoverHomeShellView"))
            XCTAssertTrue(mapping?.stateModel.contains("DemoTopBar") == true)
            XCTAssertTrue(mapping?.stateModel.contains("DiscoverDemoState") == true)
            XCTAssertTrue(mapping?.navigationEntry.contains("no pushed Route") == true)
        }
    }

    func testRSSDetailRouteMapsToNativeReaderPage() {
        let mapping = DemoRouteMappings.mapping(for: "rss-detail")

        XCTAssertEqual(mapping?.shell, "LibraryShell")
        XCTAssertEqual(mapping?.platformTarget, .nativeRoute(.rssDetail))
        XCTAssertTrue(mapping?.stateModel.contains("RSSArticleDetailView") == true)
    }

    func testRSSNativeSecondaryRoutesUseDemoBackScreen() {
        let routes = DemoRouteMappings.all.filter { mapping in
            guard mapping.demoRoute.hasPrefix("rss-") else { return false }
            if case .nativeRoute = mapping.platformTarget {
                return true
            }
            return false
        }

        XCTAssertGreaterThan(routes.count, 30)
        for mapping in routes {
            XCTAssertEqual(mapping.shell, "LibraryShell", mapping.demoRoute)
            XCTAssertTrue(mapping.stateModel.contains("DemoBackScreen"), mapping.demoRoute)
            XCTAssertTrue(mapping.acceptanceTests.contains("DemoComponentPrimitiveAlignmentTests"), mapping.demoRoute)
        }
    }

    func testLibraryFeatureStateRoutesMapToConcreteViews() {
        let featureRoutes = [
            "discover-source-login",
            "rss-all",
            "rss-starred",
            "rss-source-feed",
            "rss-source-category-releases",
            "rss-source-category-issues",
            "rss-source-category-discussions",
            "rss-refreshing"
        ]

        for route in featureRoutes {
            let mapping = DemoRouteMappings.mapping(for: route)
            XCTAssertEqual(mapping?.shell, "LibraryShell")
            guard case .featureState(let stateName) = mapping?.platformTarget else {
                return XCTFail("\(route) must map to a concrete LibraryShell feature state")
            }
            if route == "discover-source-login" {
                XCTAssertTrue(stateName.contains("DiscoverSourceLoginView"))
                XCTAssertTrue(mapping?.stateModel.contains("DemoBackScreen") == true)
            } else {
                XCTAssertTrue(stateName.contains("RSSFeedView"))
                XCTAssertTrue(mapping?.stateModel.contains("RSSDemoRouteState") == true)
            }
        }
    }

    func testReaderShellRoutesMapToFeatureStatesNotMainTabs() {
        let readerRoutes = DemoRouteMappings.expectedReaderShellRoutes.filter {
            $0 != "immersive-reading" && $0 != "reader"
        }
        XCTAssertEqual(readerRoutes.count, 13)

        for route in readerRoutes {
            let mapping = DemoRouteMappings.mapping(for: route)
            XCTAssertEqual(mapping?.shell, "ReaderShell")
            XCTAssertEqual(mapping?.slice, 3)
            guard case .featureState(let stateName) = mapping?.platformTarget else {
                return XCTFail("\(route) must map to a Reader feature state")
            }
            XCTAssertTrue(stateName.contains("ReaderDemoShellView"))
            XCTAssertTrue(mapping?.stateModel.contains("hidden system navigation chrome") == true)
            XCTAssertTrue(mapping?.stateModel.contains("ReaderDemoRouteState") == true)
            XCTAssertTrue(mapping?.stateModel.contains("ReaderResponsiveLayout") == true)
            XCTAssertTrue(mapping?.stateModel.contains("ReaderDisplaySettings") == true)
            XCTAssertTrue(mapping?.stateModel.contains("ReaderAppearanceQuickAction") == true)
            XCTAssertTrue(mapping?.stateModel.contains("ReaderSettingsQuickAction") == true)
            XCTAssertTrue(mapping?.stateModel.contains("ReaderResponsiveVisualAudit") == true)
            XCTAssertTrue(mapping?.navigationEntry.contains("reader-owned chrome") == true)
            XCTAssertTrue(mapping?.navigationEntry.contains("ReaderDisplaySettings") == true)
            XCTAssertTrue(mapping?.navigationEntry.contains("without becoming a main tab") == true)
        }
    }

    func testSettingsShellRoutesMapToFeatureStatesNotMainTabs() {
        let settingsRoutes = DemoRouteMappings.expectedSettingsShellRoutes
        XCTAssertEqual(settingsRoutes.count, 28)

        for route in settingsRoutes {
            let mapping = DemoRouteMappings.mapping(for: route)
            XCTAssertEqual(mapping?.shell, "SettingsShell")
            XCTAssertEqual(mapping?.slice, 6)
            guard case .featureState(let stateName) = mapping?.platformTarget else {
                return XCTFail("\(route) must map to a Settings feature state")
            }
            XCTAssertTrue(stateName.contains("SettingsDemoShellView"))
            XCTAssertTrue(mapping?.stateModel.contains("DemoBackScreen") == true)
            XCTAssertTrue(mapping?.stateModel.contains("SettingsDemoRouteState") == true)
            XCTAssertTrue(mapping?.navigationEntry.contains("without becoming a main tab") == true)
        }
    }


    func testRSSOriginalRouteMapsToNativePreviewPage() {
        let mapping = DemoRouteMappings.mapping(for: "rss-original")

        XCTAssertEqual(mapping?.shell, "LibraryShell")
        XCTAssertEqual(mapping?.platformTarget, .nativeRoute(.rssOriginal))
        XCTAssertTrue(mapping?.stateModel.contains("RSSOriginalPreviewView") == true)
    }

    func testRSSOriginalBrowserRouteMapsToNativeConfirmationPage() {
        let mapping = DemoRouteMappings.mapping(for: "rss-original-browser")

        XCTAssertEqual(mapping?.shell, "LibraryShell")
        XCTAssertEqual(mapping?.platformTarget, .nativeRoute(.rssOriginalBrowser))
        XCTAssertTrue(mapping?.stateModel.contains("RSSOriginalBrowserConfirmView") == true)
    }

    func testRSSManagementRoutesMapToNativePages() {
        let management = DemoRouteMappings.mapping(for: "rss-subscription-management")
        let actions = DemoRouteMappings.mapping(for: "rss-source-actions")
        let edit = DemoRouteMappings.mapping(for: "rss-source-edit")
        let debug = DemoRouteMappings.mapping(for: "rss-source-debug")
        let vars = DemoRouteMappings.mapping(for: "rss-source-vars")
        let login = DemoRouteMappings.mapping(for: "rss-source-login")
        let loginWeb = DemoRouteMappings.mapping(for: "rss-source-login-web")
        let loginCookie = DemoRouteMappings.mapping(for: "rss-source-login-cookie")
        let loginClear = DemoRouteMappings.mapping(for: "rss-source-login-clear")
        let groups = DemoRouteMappings.mapping(for: "rss-source-groups")
        let groupEdit = DemoRouteMappings.mapping(for: "rss-source-group-edit")
        let batch = DemoRouteMappings.mapping(for: "rss-source-batch")
        let export = DemoRouteMappings.mapping(for: "rss-source-export")
        let exportDetail = DemoRouteMappings.mapping(for: "rss-source-export-detail")
        let exportResult = DemoRouteMappings.mapping(for: "rss-source-export-result")
        let pin = DemoRouteMappings.mapping(for: "rss-source-pin")
        let disable = DemoRouteMappings.mapping(for: "rss-source-disable")
        let batchDisable = DemoRouteMappings.mapping(for: "rss-source-batch-disable")
        let importRoute = DemoRouteMappings.mapping(for: "rss-source-import")
        let importDetail = DemoRouteMappings.mapping(for: "rss-source-import-detail")
        let importResult = DemoRouteMappings.mapping(for: "rss-source-import-result")

        XCTAssertEqual(management?.platformTarget, .nativeRoute(.rssSubscriptions))
        XCTAssertTrue(management?.stateModel.contains("RSSSubscriptionManagementView") == true)
        XCTAssertEqual(actions?.platformTarget, .nativeRoute(.rssSourceActions))
        XCTAssertTrue(actions?.stateModel.contains("RSSSourceActionsView") == true)
        XCTAssertEqual(edit?.platformTarget, .nativeRoute(.rssSourceEdit))
        XCTAssertTrue(edit?.stateModel.contains("RSSSourceEditView") == true)
        XCTAssertEqual(debug?.platformTarget, .nativeRoute(.rssSourceDebug))
        XCTAssertTrue(debug?.stateModel.contains("RSSSourceDebugView") == true)
        XCTAssertEqual(vars?.platformTarget, .nativeRoute(.rssSourceVars))
        XCTAssertTrue(vars?.stateModel.contains("RSSSourceVarsView") == true)
        XCTAssertEqual(login?.platformTarget, .nativeRoute(.rssSourceLogin))
        XCTAssertTrue(login?.stateModel.contains("RSSSourceLoginView") == true)
        XCTAssertEqual(loginWeb?.platformTarget, .nativeRoute(.rssSourceLoginWeb))
        XCTAssertTrue(loginWeb?.stateModel.contains("RSSSourceLoginWebView") == true)
        XCTAssertEqual(loginCookie?.platformTarget, .nativeRoute(.rssSourceLoginCookie))
        XCTAssertTrue(loginCookie?.stateModel.contains("RSSSourceLoginCookieView") == true)
        XCTAssertEqual(loginClear?.platformTarget, .nativeRoute(.rssSourceLoginClear))
        XCTAssertTrue(loginClear?.stateModel.contains("RSSSourceLoginClearView") == true)
        XCTAssertEqual(groups?.platformTarget, .nativeRoute(.rssSourceGroups))
        XCTAssertTrue(groups?.stateModel.contains("RSSSourceGroupsView") == true)
        XCTAssertEqual(groupEdit?.platformTarget, .nativeRoute(.rssSourceGroupEdit))
        XCTAssertTrue(groupEdit?.stateModel.contains("RSSSourceGroupEditView") == true)
        XCTAssertEqual(batch?.platformTarget, .nativeRoute(.rssSourceBatch))
        XCTAssertTrue(batch?.stateModel.contains("RSSSourceBatchView") == true)
        XCTAssertEqual(export?.platformTarget, .nativeRoute(.rssSourceExport))
        XCTAssertTrue(export?.stateModel.contains("RSSSourceExportView") == true)
        XCTAssertEqual(exportDetail?.platformTarget, .nativeRoute(.rssSourceExportDetail))
        XCTAssertTrue(exportDetail?.stateModel.contains("RSSSourceExportDetailView") == true)
        XCTAssertEqual(exportResult?.platformTarget, .nativeRoute(.rssSourceExportResult))
        XCTAssertTrue(exportResult?.stateModel.contains("RSSSourceExportResultView") == true)
        XCTAssertEqual(pin?.platformTarget, .nativeRoute(.rssSourcePin))
        XCTAssertTrue(pin?.stateModel.contains("RSSSourcePinConfirmView") == true)
        XCTAssertEqual(disable?.platformTarget, .nativeRoute(.rssSourceDisable))
        XCTAssertTrue(disable?.stateModel.contains("RSSSourceDisableConfirmView") == true)
        XCTAssertEqual(batchDisable?.platformTarget, .nativeRoute(.rssSourceBatchDisable))
        XCTAssertTrue(batchDisable?.stateModel.contains("RSSSourceBatchDisableConfirmView") == true)
        XCTAssertEqual(importRoute?.platformTarget, .nativeRoute(.rssSourceImport))
        XCTAssertTrue(importRoute?.stateModel.contains("RSSSourceImportView") == true)
        XCTAssertEqual(importDetail?.platformTarget, .nativeRoute(.rssSourceImportDetail))
        XCTAssertTrue(importDetail?.stateModel.contains("RSSSourceImportDetailView") == true)
        XCTAssertEqual(importResult?.platformTarget, .nativeRoute(.rssSourceImportResult))
        XCTAssertTrue(importResult?.stateModel.contains("RSSSourceImportResultView") == true)
    }

    func testRSSSupplementalRoutesMapToNativePages() {
        let search = DemoRouteMappings.mapping(for: "rss-search")
        let readRecord = DemoRouteMappings.mapping(for: "rss-read-record")
        let recordClear = DemoRouteMappings.mapping(for: "rss-record-clear")
        let ruleSubscription = DemoRouteMappings.mapping(for: "rss-rule-subscription")
        let ruleDetail = DemoRouteMappings.mapping(for: "rss-rule-subscription-detail")
        let ruleEdit = DemoRouteMappings.mapping(for: "rss-rule-subscription-edit")
        let ruleTest = DemoRouteMappings.mapping(for: "rss-rule-subscription-test")
        let ruleApply = DemoRouteMappings.mapping(for: "rss-rule-subscription-apply")
        let favoriteGroups = DemoRouteMappings.mapping(for: "rss-favorite-groups")
        let favoriteEdit = DemoRouteMappings.mapping(for: "rss-favorite-group-edit")
        let favoriteClear = DemoRouteMappings.mapping(for: "rss-favorite-clear")
        let empty = DemoRouteMappings.mapping(for: "rss-empty")
        let error = DemoRouteMappings.mapping(for: "rss-error")

        XCTAssertEqual(search?.platformTarget, .nativeRoute(.rssSearch))
        XCTAssertTrue(search?.stateModel.contains("RSSSearchView") == true)
        XCTAssertEqual(readRecord?.platformTarget, .nativeRoute(.rssReadRecord))
        XCTAssertTrue(readRecord?.stateModel.contains("RSSReadRecordView") == true)
        XCTAssertEqual(recordClear?.platformTarget, .nativeRoute(.rssRecordClear))
        XCTAssertTrue(recordClear?.stateModel.contains("RSSRecordClearConfirmView") == true)
        XCTAssertEqual(ruleSubscription?.platformTarget, .nativeRoute(.rssRuleSubscription))
        XCTAssertTrue(ruleSubscription?.stateModel.contains("RSSRuleSubscriptionView") == true)
        XCTAssertEqual(ruleDetail?.platformTarget, .nativeRoute(.rssRuleSubscriptionDetail))
        XCTAssertTrue(ruleDetail?.stateModel.contains("RSSRuleSubscriptionDetailView") == true)
        XCTAssertEqual(ruleEdit?.platformTarget, .nativeRoute(.rssRuleSubscriptionEdit))
        XCTAssertTrue(ruleEdit?.stateModel.contains("RSSRuleSubscriptionEditView") == true)
        XCTAssertEqual(ruleTest?.platformTarget, .nativeRoute(.rssRuleSubscriptionTest))
        XCTAssertTrue(ruleTest?.stateModel.contains("RSSRuleSubscriptionTestView") == true)
        XCTAssertEqual(ruleApply?.platformTarget, .nativeRoute(.rssRuleSubscriptionApply))
        XCTAssertTrue(ruleApply?.stateModel.contains("RSSRuleSubscriptionApplyConfirmView") == true)
        XCTAssertEqual(favoriteGroups?.platformTarget, .nativeRoute(.rssFavoriteGroups))
        XCTAssertTrue(favoriteGroups?.stateModel.contains("RSSFavoriteGroupsView") == true)
        XCTAssertEqual(favoriteEdit?.platformTarget, .nativeRoute(.rssFavoriteGroupEdit))
        XCTAssertTrue(favoriteEdit?.stateModel.contains("RSSFavoriteGroupEditView") == true)
        XCTAssertEqual(favoriteClear?.platformTarget, .nativeRoute(.rssFavoriteClear))
        XCTAssertTrue(favoriteClear?.stateModel.contains("RSSFavoriteClearConfirmView") == true)
        XCTAssertEqual(empty?.platformTarget, .nativeRoute(.rssEmpty))
        XCTAssertTrue(empty?.stateModel.contains("RSSStateView") == true)
        XCTAssertEqual(error?.platformTarget, .nativeRoute(.rssError))
        XCTAssertTrue(error?.stateModel.contains("RSSStateView") == true)
    }

    func testReaderEntryUsesReaderContextNotMainTab() {
        let immersive = DemoRouteMappings.mapping(for: "immersive-reading")
        let reader = DemoRouteMappings.mapping(for: "reader")

        XCTAssertEqual(immersive?.platformTarget, .readerContext(.coverToImmersive))
        XCTAssertTrue(immersive?.stateModel.contains("ReaderReadingLayer") == true)
        XCTAssertTrue(immersive?.stateModel.contains("ReaderProgressSurfaceView") == true)
        XCTAssertTrue(immersive?.stateModel.contains("hidden system navigation chrome") == true)
        XCTAssertEqual(reader?.platformTarget, .nativeRoute(.reader))
        XCTAssertTrue(reader?.stateModel.contains("ReaderReadingLayer") == true)
        XCTAssertTrue(reader?.stateModel.contains("ReaderProgressSurfaceView") == true)
        XCTAssertTrue(reader?.stateModel.contains("ReaderResponsiveLayout") == true)
        XCTAssertTrue(reader?.stateModel.contains("ReaderResponsiveVisualAudit") == true)
        XCTAssertTrue(reader?.stateModel.contains("hidden system navigation chrome") == true)
        XCTAssertTrue(reader?.stateModel.contains("ReaderInlineDestination") == true)
        XCTAssertTrue(reader?.stateModel.contains("ReaderHotZoneSegment") == true)
        XCTAssertTrue(reader?.stateModel.contains("ReaderStateCard") == true)
        XCTAssertTrue(reader?.stateModel.contains("ReaderStateBanner") == true)
        XCTAssertTrue(reader?.stateModel.contains("TOCView") == true)
        XCTAssertTrue(reader?.stateModel.contains("TOCChapterDemoRow") == true)
        XCTAssertTrue(reader?.stateModel.contains("ContentView") == true)
        XCTAssertTrue(reader?.stateModel.contains("ReaderContentSectionView") == true)
        XCTAssertTrue(reader?.navigationEntry.contains("Route.toc/Route.content") == true)
        XCTAssertTrue(reader?.navigationEntry.contains("DemoBackScreen") == true)
        XCTAssertTrue(reader?.stateModel.contains("ReaderAppearanceQuickAction") == true)
        XCTAssertTrue(reader?.stateModel.contains("ReaderSettingsQuickAction") == true)
        for route in ["reader-full-directory", "reader-full-tts", "reader-full-appearance", "reader-full-settings"] {
            XCTAssertTrue(reader?.stateModel.contains(route) == true, "reader state model should reference \(route)")
            XCTAssertTrue(reader?.navigationEntry.contains(route) == true, "reader navigation entry should reference \(route)")
        }
        XCTAssertTrue(reader?.stateModel.contains("ReaderSourceSwitchFlowView") == true)
        XCTAssertTrue(reader?.navigationEntry.contains("source-switch") == true)
        XCTAssertTrue(reader?.motionIDs.contains("reader.page.turn.prev") == true)
        XCTAssertTrue(reader?.motionIDs.contains("reader.page.turn.next") == true)
        XCTAssertTrue(reader?.motionIDs.contains("reader.chapter.jump") == true)
        XCTAssertFalse(AppTab.contractOrder.contains { $0.title.contains("阅读") })
    }

    func testSourceSwitchFlowMapsToConcreteReaderFlowView() {
        let mapping = DemoRouteMappings.mapping(for: "source-switch")

        XCTAssertEqual(mapping?.shell, "FlowShell")
        XCTAssertEqual(mapping?.platformTarget, .nativeRoute(.sourceSwitch))
        XCTAssertTrue(mapping?.stateModel.contains("DemoBackScreen") == true)
        XCTAssertTrue(mapping?.stateModel.contains("ReaderSourceSwitchFlowView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("SourceSwitchCandidate") == true)
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testEveryMappedRouteHasCompleteContractFields() {
        for mapping in DemoRouteMappings.all {
            XCTAssertFalse(mapping.demoRoute.isEmpty)
            XCTAssertFalse(mapping.shell.isEmpty, "\(mapping.demoRoute) missing shell")
            XCTAssertFalse(mapping.stateModel.isEmpty, "\(mapping.demoRoute) missing state model")
            XCTAssertFalse(mapping.navigationEntry.isEmpty, "\(mapping.demoRoute) missing navigation entry")
            XCTAssertFalse(mapping.motionIDs.isEmpty, "\(mapping.demoRoute) missing motion IDs")
            XCTAssertFalse(mapping.acceptanceTests.isEmpty, "\(mapping.demoRoute) missing acceptance tests")
        }
    }

    func testMappedRoutesAreUnique() {
        let routes = DemoRouteMappings.all.map(\.demoRoute)
        XCTAssertEqual(routes.count, Set(routes).count)
    }

    func testAllDemoContractRoutesAreOwnedByIOSMapping() {
        XCTAssertEqual(DemoRouteMappings.expectedRouteCount, 131)
        XCTAssertEqual(DemoRouteMappings.all.count, DemoRouteMappings.expectedRouteCount)

        let mappedRoutes = Set(DemoRouteMappings.all.map(\.demoRoute))
        for (_, routes) in DemoRouteMappings.expectedRoutesByShell {
            for route in routes {
                XCTAssertTrue(mappedRoutes.contains(route), "\(route) must have AppTab, native route, feature-state, or planned ownership")
            }
        }
    }

    func testShellDistributionMatchesReaderUIDemoContract() {
        let counts = Dictionary(grouping: DemoRouteMappings.all, by: \.shell)
            .mapValues(\.count)

        XCTAssertEqual(counts["MainTabShell"], 36)
        XCTAssertEqual(counts["LibraryShell"], 51)
        XCTAssertEqual(counts["SettingsShell"], 28)
        XCTAssertEqual(counts["ReaderShell"], 15)
        XCTAssertEqual(counts["FlowShell"], 1)
    }

    func testNoUnimplementedRoutesRemainPlanned() {
        let planned = DemoRouteMappings.all.filter { mapping in
            if case .planned = mapping.platformTarget {
                return true
            }
            return false
        }

        XCTAssertEqual(planned.count, 0)
        for mapping in planned {
            XCTAssertFalse(mapping.stateModel.isEmpty, "\(mapping.demoRoute) planned mapping missing state model")
            XCTAssertFalse(mapping.navigationEntry.isEmpty, "\(mapping.demoRoute) planned mapping missing navigation entry")
            XCTAssertFalse(mapping.motionIDs.isEmpty, "\(mapping.demoRoute) planned mapping missing motion IDs")
            XCTAssertTrue(mapping.acceptanceTests.contains("PlannedRouteMappingTests"))
        }
    }
}
