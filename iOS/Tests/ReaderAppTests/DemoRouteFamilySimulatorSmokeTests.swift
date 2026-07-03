import SwiftUI
import UIKit
import XCTest
import ReaderCoreModels
import ReaderShellValidation
@testable import ReaderApp

@MainActor
final class DemoRouteFamilySimulatorSmokeTests: XCTestCase {
    private let phone = CGSize(width: 390, height: 844)
    private let tablet = CGSize(width: 820, height: 960)
    private let compactLandscape = CGSize(width: 1_180, height: 500)

    func testBookshelfRouteFamilyRendersDemoSurfacesOnSimulator() {
        let navigationState = AppNavigationState()

        assertRenders(
            NavigationStack { BookshelfView(navigationState: navigationState) },
            family: "bookshelf",
            name: "root"
        )
        assertRenders(NavigationStack { SearchView(initialQuery: "长夜余火") }, family: "bookshelf", name: "search")
        assertRenders(
            NavigationStack { BookDetailView(result: demoSearchResult, sourceName: "优书网") },
            family: "bookshelf",
            name: "book-detail"
        )
        assertRenders(
            NavigationStack { BookDirectoryPreviewView(bookURL: "demo://book/long-night", title: "长夜余火") },
            family: "bookshelf",
            name: "book-directory"
        )
        assertRenders(NavigationStack { BookshelfBatchManagementView() }, family: "bookshelf", name: "batch")
        assertRenders(NavigationStack { BookshelfGroupManagementView() }, family: "bookshelf", name: "groups")
        assertRenders(NavigationStack { BookshelfLocalImportView() }, family: "bookshelf", name: "local-import")
    }

    func testReaderRouteFamilyRendersResponsiveDemoSurfacesOnSimulator() {
        assertRenders(
            NavigationStack {
                ReaderView(
                    chapterURL: "demo://chapter/32",
                    chapterTitle: "第 32 章 雨夜",
                    chapterList: demoChapterList,
                    currentChapterIndex: 1,
                    bookID: "demo-book",
                    sourceID: "demo-source",
                    immersiveStart: false
                )
            },
            family: "reader",
            name: "reader-phone"
        )

        for route in DemoRouteMappings.expectedReaderShellRoutes where route != "immersive-reading" && route != "reader" {
            assertRenders(
                NavigationStack { ReaderDemoShellView(demoRoute: route) },
                family: "reader",
                name: route,
                size: route == "toc-bookmarks" ? compactLandscape : phone
            )
        }

        assertRenders(
            NavigationStack { ReaderDemoShellView(demoRoute: "reader-appearance") },
            family: "reader",
            name: "tablet-right-dock",
            size: tablet
        )

        assertReaderVisualAudit(size: phone, expectedClass: .phonePortrait)
        assertReaderVisualAudit(size: tablet, expectedClass: .tabletExpanded)
        assertReaderVisualAudit(size: compactLandscape, expectedClass: .compactLandscape)
    }

    func testDiscoverRouteFamilyRendersAllDemoFeatureStatesOnSimulator() {
        assertRenders(NavigationStack { DiscoverHomeShellView() }, family: "discover", name: "root")

        for route in DemoRouteMappings.expectedMainTabShellRoutes where route.hasPrefix("discover-") {
            assertRenders(
                NavigationStack { DiscoverHomeShellView(demoRoute: route) },
                family: "discover",
                name: route
            )
        }

        assertRenders(NavigationStack { DiscoverSourceLoginView() }, family: "discover", name: "source-login")
        assertRenders(NavigationStack { SettingsDemoShellView(demoRoute: "discover-rule-test") }, family: "discover", name: "rule-test")
        assertRenders(NavigationStack { SettingsDemoShellView(demoRoute: "discover-source-bulk") }, family: "discover", name: "source-bulk")
    }

    func testRSSRouteFamilyRendersListDetailManagementAndStateSurfacesOnSimulator() {
        assertRenders(NavigationStack { RSSFeedView() }, family: "rss", name: "root")

        for route in [
            "rss-all",
            "rss-starred",
            "rss-source-feed",
            "rss-source-category-releases",
            "rss-source-category-issues",
            "rss-source-category-discussions",
            "rss-refreshing"
        ] {
            assertRenders(NavigationStack { RSSFeedView(demoRoute: route) }, family: "rss", name: route)
        }

        assertRenders(
            NavigationStack { RSSArticleDetailView(item: RSSArticleDetailView.fallbackItem(link: "https://example.com/rss"), sourceTitle: "RSS") },
            family: "rss",
            name: "detail"
        )
        assertRenders(
            NavigationStack { RSSOriginalPreviewView(urlString: "https://example.com/rss", title: "RSS 原文", sourceTitle: "RSS") },
            family: "rss",
            name: "original"
        )
        assertRenders(
            NavigationStack { RSSOriginalBrowserConfirmView(urlString: "https://example.com/rss", title: "RSS 原文", sourceTitle: "RSS") },
            family: "rss",
            name: "original-browser"
        )
        assertRenders(NavigationStack { RSSSubscriptionManagementView() }, family: "rss", name: "subscription-management")
        assertRenders(NavigationStack { RSSSourceActionsView(sourceID: "github-releases", title: "GitHub Releases") }, family: "rss", name: "source-actions")
        assertRenders(NavigationStack { RSSSearchView() }, family: "rss", name: "search")
        assertRenders(NavigationStack { RSSStateView(kind: .empty) }, family: "rss", name: "empty")
        assertRenders(NavigationStack { RSSStateView(kind: .error) }, family: "rss", name: "error")
    }

    func testSettingsBackupImportAndSharedStateFamiliesRenderOnSimulator() {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()

        assertRenders(
            NavigationStack { SettingsTabView(coordinator: coordinator) },
            family: "settings",
            name: "root"
        )

        for route in DemoRouteMappings.expectedSettingsShellRoutes {
            assertRenders(
                NavigationStack { SettingsDemoShellView(demoRoute: route) },
                family: "settings",
                name: route
            )
        }

        assertRenders(NavigationStack { BookSourceListView(coordinator: coordinator) }, family: "settings", name: "live-source-management")
        assertRenders(NavigationStack { BookSourceImportView() }, family: "settings", name: "live-source-import")
        assertRenders(NavigationStack { WebDAVSettingsView() }, family: "settings", name: "live-webdav")
        assertRenders(NavigationStack { StateSurfaceView(kind: .error(message: "网络连接失败")) }, family: "state", name: "error")
        assertRenders(NavigationStack { StateSurfaceView(kind: .offline) }, family: "state", name: "offline")
        assertRenders(NavigationStack { PermissionStateView(permission: "本地文件") }, family: "state", name: "permission")
    }

    func testAppShellTabletRailAndContentShiftMatchDemoContract() {
        let shell = AppShellView(
            coordinator: ShellAssembly.makeMockReadingFlowCoordinator(),
            navigationState: AppNavigationState(),
            environment: ReaderShellEnvironment()
        )

        assertRenders(shell, family: "app-shell", name: "phone", size: phone)
        assertRenders(shell, family: "app-shell", name: "tablet-left-rail", size: tablet)

        XCTAssertEqual(ReaderDesignTokens.tabletNavWidth, 82)
        XCTAssertEqual(ReaderDesignTokens.tabletNavItemHeight, 58)
        XCTAssertEqual(ReaderDesignTokens.mainNavHeight, 68)
    }

    func testAsyncResultGuardKeepsLatestReaderContext() {
        let navigationState = AppNavigationState()
        let first = ReaderContext(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            bookID: "first-book",
            chapterURL: "demo://chapter/first",
            chapterTitle: "第一章",
            sourceID: "demo-source",
            source: .coverToImmersive
        )
        let second = ReaderContext(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            bookID: "second-book",
            chapterURL: "demo://chapter/second",
            chapterTitle: "第二章",
            sourceID: "demo-source",
            source: .actionToImmersive
        )

        navigationState.enterImmersiveReading(first)
        navigationState.enterImmersiveReading(second)

        XCTAssertEqual(navigationState.readerContext, second)
        XCTAssertNotEqual(navigationState.readerContext?.id, first.id)
        XCTAssertEqual(DemoRouteMappings.mapping(for: "reader")?.motionIDs.contains("motion.async.resultGuard"), true)
    }

    private var demoSearchResult: SearchResultItem {
        SearchResultItem(
            title: "长夜余火",
            detailURL: "demo://book/long-night",
            author: "爱潜水的乌贼",
            intro: "旧世界的余烬尚未冷却，新的秩序已经在废墟之上生长。"
        )
    }

    private var demoChapterList: [TOCItem] {
        [
            TOCItem(chapterTitle: "第 31 章 来信", chapterURL: "demo://chapter/31", chapterIndex: 0),
            TOCItem(chapterTitle: "第 32 章 雨夜", chapterURL: "demo://chapter/32", chapterIndex: 1),
            TOCItem(chapterTitle: "第 33 章 灯火", chapterURL: "demo://chapter/33", chapterIndex: 2)
        ]
    }

    private func assertReaderVisualAudit(
        size: CGSize,
        expectedClass: ReaderViewportClass,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let audit = ReaderResponsiveVisualAudit.make(size: size)

        XCTAssertEqual(audit.layout.viewportClass, expectedClass, file: file, line: line)
        XCTAssertTrue(audit.readingRectInsideViewport, file: file, line: line)
        XCTAssertTrue(audit.topBarClearsReadingContent, file: file, line: line)
        XCTAssertTrue(audit.dockStackInsideViewport, file: file, line: line)
        XCTAssertTrue(audit.readingAvoidsDockWhenRequired, file: file, line: line)

        if expectedClass == .tabletExpanded || expectedClass == .compactLandscape {
            XCTAssertEqual(audit.layout.controlPlacement, .trailingDock, file: file, line: line)
            XCTAssertNotNil(audit.dockStackRect, file: file, line: line)
        }
    }

    private func assertRenders<V: View>(
        _ view: V,
        family: String,
        name: String,
        size: CGSize = CGSize(width: 390, height: 844),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        var rendered = false
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            rendered = host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }

        XCTAssertTrue(rendered, "\(family)/\(name) should render through UIKit on Simulator", file: file, line: line)
        XCTAssertEqual(host.view.bounds.size.width, size.width, accuracy: 0.5, file: file, line: line)
        XCTAssertEqual(host.view.bounds.size.height, size.height, accuracy: 0.5, file: file, line: line)
        XCTAssertGreaterThan(image.pngData()?.count ?? 0, 512, "\(family)/\(name) screenshot should not be empty", file: file, line: line)

        let attachment = XCTAttachment(image: image)
        attachment.name = "\(family)-\(name)-\(Int(size.width))x\(Int(size.height))"
        attachment.lifetime = .keepAlways
        add(attachment)

        window.isHidden = true
    }
}
