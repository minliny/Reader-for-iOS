import Foundation

#if canImport(UIKit)
import SwiftUI
import UIKit
import XCTest
import ReaderCoreModels
import ReaderAppSupport
import ReaderShellValidation
@testable import ReaderApp

@MainActor
final class DemoRouteFamilySimulatorSmokeTests: XCTestCase {
    private let phone = CGSize(width: 390, height: 844)
    private let expandedWidth = CGSize(width: 820, height: 960)
    private let tablet = CGSize(width: 900, height: 960)
    private let compactLandscape = CGSize(width: 1_180, height: 500)

    func testBookshelfRouteFamilyRendersDemoSurfacesOnSimulator() {
        let navigationState = AppNavigationState()

        // bookshelf-root / bookshelf-book-more-menu / sort-filter 走 LazyVGrid 渲染真实封面，
        // 需要 wait≥0.6 让 demoCoverPNG 解码 + layout 落定，否则截图会是空纸面。
        assertRenders(
            NavigationStack { BookshelfView(demoRoute: "bookshelf", navigationState: navigationState) },
            family: "bookshelf",
            name: "root",
            wait: 0.6
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
        assertRenders(NavigationStack { BookshelfGroupManagementView() }, family: "bookshelf", name: "bookshelf-group-management")
        assertRenders(NavigationStack { BookshelfLocalImportView() }, family: "bookshelf", name: "local-import")
        // bookshelf-cover-mode / bookshelf-list-mode 对齐 demo `mainTabBookshelf(view=cover|list)`，
        // 用真实 BookshelfView + 初始 display mode，而非 PrototypeGalleryView 里的占位 prototype。
        assertRenders(NavigationStack { BookshelfView(demoRoute: "bookshelf-cover-mode") }, family: "bookshelf", name: "bookshelf-cover-mode", wait: 0.6)
        assertRenders(NavigationStack { BookshelfView(demoRoute: "bookshelf-list-mode") }, family: "bookshelf", name: "bookshelf-list-mode", wait: 0.6)
        assertRenders(NavigationStack { BookshelfEmptyPrototype() }, family: "bookshelf", name: "bookshelf-empty")
        assertRenders(NavigationStack { BookDetailTOCPrototype() }, family: "bookshelf", name: "book-detail-toc-preview")
        // bookshelf-book-more-menu 在 web demo 是 contractStaticRouteScreen（静态合同页），
        // 不是交互式书架。用 ContractStaticRouteScreen 对齐 web 语义。
        assertRenders(
            NavigationStack {
                ContractStaticRouteScreen(
                    route: "bookshelf-book-more-menu",
                    title: "书籍更多菜单",
                    shell: "MainTabShell",
                    activeType: "bookshelf",
                    iconName: "more",
                    summary: "书籍长按或更多菜单的静态合同页；平台实现应展示真实选中书籍上下文、焦点恢复和系统返回行为。",
                    actions: [
                        ("批量管理", "book-batch-management"),
                        ("书籍详情", "book-detail")
                    ]
                )
            },
            family: "bookshelf",
            name: "bookshelf-book-more-menu",
            wait: 0.6
        )
        assertRenders(NavigationStack { BookshelfView(demoRoute: "sort-filter") }, family: "bookshelf", name: "sort-filter", wait: 0.6)
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
                    immersiveStart: true
                )
            },
            family: "reader",
            name: "immersive-reading",
            wait: 0.6
        )

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
            name: "reader-phone",
            wait: 0.6
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

        assertRenders(
            NavigationStack { ReaderSourceSwitchFlowView(bookURL: "demo://book/lighthouse") },
            family: "reader",
            name: "source-switch"
        )
        assertRenders(
            NavigationStack {
                ReaderSourceSwitchFlowView(
                    bookURL: "demo://book/lighthouse",
                    initialResultState: .confirmed
                )
            },
            family: "reader",
            name: "source-switch-results"
        )

        assertReaderVisualAudit(size: phone, expectedClass: .phonePortrait)
        assertReaderVisualAudit(size: expandedWidth, expectedClass: .expandedWidth)
        assertReaderVisualAudit(size: tablet, expectedClass: .tabletExpanded)
        assertReaderVisualAudit(size: compactLandscape, expectedClass: .compactLandscape)
    }

    func testDemoBookshelfReaderEntryRendersVisibleTextOnSimulator() {
        let item = DemoBookshelfFixture.items[0]
        let chapterURL = item.lastReadChapterURL ?? item.bookURL
        let chapterList = item.localChapterList ?? []

        let image = renderForScreenshot(
            NavigationStack {
                ReaderView(
                    chapterURL: chapterURL,
                    chapterTitle: item.lastReadChapterTitle ?? "继续阅读",
                    chapterList: chapterList,
                    currentChapterIndex: chapterList.firstIndex { $0.chapterURL == chapterURL } ?? 0,
                    bookID: item.id,
                    sourceID: item.sourceID,
                    immersiveStart: true
                )
            },
            size: phone,
            wait: 0.35
        )

        assertContainsVisibleTextPixels(image, name: "bookshelf-reader-entry")
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
            "rss-source-category-novel",
            "rss-source-category-tech",
            "rss-source-category-booklist",
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
        assertRenders(NavigationStack { RSSReadRecordView(sourceID: "github-releases", title: "GitHub Releases") }, family: "rss", name: "rss-read-record")
        assertRenders(NavigationStack { RSSRecordClearConfirmView() }, family: "rss", name: "rss-record-clear")
        assertRenders(NavigationStack { RSSSourceEditView(sourceID: "github-releases", title: "GitHub Releases") }, family: "rss", name: "rss-source-edit")
        assertRenders(NavigationStack { RSSSourceEditView(sourceID: "new", title: "新增 RSS 源") }, family: "rss", name: "rss-source-add")
        assertRenders(NavigationStack { RSSSourceDebugView(sourceID: "github-releases", title: "GitHub Releases") }, family: "rss", name: "rss-source-debug")
        assertRenders(NavigationStack { RSSSourceVarsView(sourceID: "github-releases", title: "GitHub Releases") }, family: "rss", name: "rss-source-vars")
        assertRenders(NavigationStack { RSSSourceLoginView(sourceID: "source-maintenance", title: "书源维护公告") }, family: "rss", name: "rss-source-login")
        assertRenders(NavigationStack { RSSSourceLoginWebView(sourceID: "source-maintenance", title: "书源维护公告") }, family: "rss", name: "rss-source-login-web")
        assertRenders(NavigationStack { RSSSourceLoginCookieView(sourceID: "source-maintenance", title: "书源维护公告") }, family: "rss", name: "rss-source-login-cookie")
        assertRenders(NavigationStack { RSSSourceLoginClearView(sourceID: "source-maintenance", title: "书源维护公告") }, family: "rss", name: "rss-source-login-clear")
        assertRenders(NavigationStack { RSSSourceGroupsView() }, family: "rss", name: "rss-source-groups")
        assertRenders(NavigationStack { RSSSourceGroupEditView(groupID: "open-source", title: "开源项目") }, family: "rss", name: "rss-source-group-edit")
        assertRenders(NavigationStack { RSSSourceBatchView() }, family: "rss", name: "rss-source-batch")
        assertRenders(NavigationStack { RSSSourceExportView() }, family: "rss", name: "rss-source-export")
        assertRenders(NavigationStack { RSSSourceExportDetailView(sourceID: "github-releases", title: "GitHub Releases") }, family: "rss", name: "rss-source-export-detail")
        assertRenders(NavigationStack { RSSSourceExportResultView() }, family: "rss", name: "rss-source-export-result")
        assertRenders(NavigationStack { RSSSourcePinConfirmView(sourceID: "github-releases", title: "GitHub Releases") }, family: "rss", name: "rss-source-pin")
        assertRenders(NavigationStack { RSSSourceDisableConfirmView(sourceID: "github-releases", title: "GitHub Releases") }, family: "rss", name: "rss-source-disable")
        assertRenders(NavigationStack { RSSSourceBatchDisableConfirmView() }, family: "rss", name: "rss-source-batch-disable")
        assertRenders(NavigationStack { RSSSourceDeleteConfirmView(sourceID: "github-releases", title: "GitHub Releases") }, family: "rss", name: "rss-source-delete-confirm")
        assertRenders(NavigationStack { RSSSourceImportView() }, family: "rss", name: "rss-source-import")
        assertRenders(NavigationStack { RSSSourceImportDetailView(sourceID: "source-maintenance", title: "书源维护公告") }, family: "rss", name: "rss-source-import-detail")
        assertRenders(NavigationStack { RSSSourceImportResultView() }, family: "rss", name: "rss-source-import-result")
        assertRenders(NavigationStack { RSSRuleSubscriptionView() }, family: "rss", name: "rss-rule-subscription")
        assertRenders(NavigationStack { RSSRuleSubscriptionDetailView(subscriptionID: "community-rss", title: "社区 RSS 源订阅") }, family: "rss", name: "rss-rule-subscription-detail")
        assertRenders(NavigationStack { RSSRuleSubscriptionEditView(subscriptionID: "community-rss", title: "社区 RSS 源订阅") }, family: "rss", name: "rss-rule-subscription-edit")
        assertRenders(NavigationStack { RSSRuleSubscriptionEditView(subscriptionID: "new-subscription", title: "新增规则订阅") }, family: "rss", name: "rss-rule-subscription-create")
        assertRenders(NavigationStack { RSSRuleSubscriptionTestView(subscriptionID: "community-rss", title: "社区 RSS 源订阅") }, family: "rss", name: "rss-rule-subscription-test")
        assertRenders(NavigationStack { RSSRuleSubscriptionApplyConfirmView(subscriptionID: "community-rss", title: "社区 RSS 源订阅") }, family: "rss", name: "rss-rule-subscription-apply")
        assertRenders(NavigationStack { RSSFavoriteGroupsView() }, family: "rss", name: "rss-favorite-groups")
        assertRenders(NavigationStack { RSSFavoriteGroupEditView(groupID: "default", title: "默认分组") }, family: "rss", name: "rss-favorite-group-edit")
        assertRenders(NavigationStack { RSSFavoriteGroupEditView(groupID: "new", title: "新建收藏分组") }, family: "rss", name: "rss-favorite-add")
        assertRenders(NavigationStack { RSSFavoriteClearConfirmView() }, family: "rss", name: "rss-favorite-clear")
        assertRenders(NavigationStack { RSSFavoriteRemoveConfirmView(groupName: "默认分组") }, family: "rss", name: "rss-favorite-remove")
        assertRenders(NavigationStack { RSSStateView(kind: .empty) }, family: "rss", name: "empty")
        assertRenders(NavigationStack { RSSStateView(kind: .error) }, family: "rss", name: "error")
    }

    func testSearchAndDetailPrototypeRoutesRenderOnSimulator() {
        assertRenders(NavigationStack { SearchHomePrototype() }, family: "search", name: "search-home")
        assertRenders(NavigationStack { SearchView(initialQuery: "长夜余火", demoState: .loading) }, family: "search", name: "search-loading")
        assertRenders(NavigationStack { SearchResultsPrototype() }, family: "search", name: "search-results")
        assertRenders(NavigationStack { SearchEmptyPrototype() }, family: "search", name: "search-empty")
        assertRenders(NavigationStack { SearchErrorPrototype() }, family: "search", name: "search-error")
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
        assertRenders(shell, family: "app-shell", name: "expanded-width-bottom-nav", size: expandedWidth)
        assertRenders(shell, family: "app-shell", name: "tablet-left-rail", size: tablet)
        // demo `main-tabs` 与 `bookshelf-cover-mode` 同源：mainTabBookshelf(view=cover)。
        // 用真实 BookshelfView + cover mode，对齐 web contract，而非 AppShellPrototype 占位。
        assertRenders(NavigationStack { BookshelfView(demoRoute: "bookshelf-cover-mode") }, family: "app-shell", name: "main-tabs", size: phone, wait: 0.6)

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
        wait: TimeInterval = 0.03,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // P3-B: 注入 ReaderSessionStore，避免 ReaderView 的 @EnvironmentObject 在测试中崩溃
        let host = UIHostingController(rootView: view.environmentObject(ReaderSessionStore()))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(wait))
        // 实际渲染 ReaderView 等异步内容（demo chapter）需要二次 layout：
        // onAppear → Task { await loadContent() } → readerState=.loaded → SwiftUI 重建
        if wait > 0.03 {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(wait))
        }

        var rendered = false
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            // iOS 26.5 模拟器上 drawHierarchy(afterScreenUpdates: true) 产出全黑图，
            // 改用 layer.render(in:) 同步渲染 Core Animation 层级，不依赖 GPU 渲染管线。
            host.view.layer.render(in: ctx.cgContext)
            rendered = true
        }

        XCTAssertTrue(rendered, "\(family)/\(name) should render through UIKit on Simulator", file: file, line: line)
        XCTAssertEqual(host.view.bounds.size.width, size.width, accuracy: 0.5, file: file, line: line)
        XCTAssertEqual(host.view.bounds.size.height, size.height, accuracy: 0.5, file: file, line: line)
        XCTAssertGreaterThan(image.pngData()?.count ?? 0, 512, "\(family)/\(name) screenshot should not be empty", file: file, line: line)

        if let screenshotDirectory = ProcessInfo.processInfo.environment["READER_IOS_DEMO_SMOKE_SCREENSHOT_DIR"] {
            writeScreenshot(
                image,
                family: family,
                name: name,
                size: size,
                directory: screenshotDirectory,
                file: file,
                line: line
            )
        }

        let attachment = XCTAttachment(image: image)
        attachment.name = "\(family)-\(name)-\(Int(size.width))x\(Int(size.height))"
        attachment.lifetime = .keepAlways
        add(attachment)

        window.isHidden = true
    }

    private func renderForScreenshot<V: View>(
        _ view: V,
        size: CGSize,
        wait: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> UIImage {
        // P3-B: 注入 ReaderSessionStore，避免 ReaderView 的 @EnvironmentObject 在测试中崩溃
        let host = UIHostingController(rootView: view.environmentObject(ReaderSessionStore()))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(wait))
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        if wait > 0.03 {
            RunLoop.main.run(until: Date().addingTimeInterval(wait))
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            host.view.layer.render(in: ctx.cgContext)
        }
        window.isHidden = true
        return image
    }

    private func assertContainsVisibleTextPixels(
        _ image: UIImage,
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let cgImage = image.cgImage else {
            XCTFail("\(name) screenshot has no CGImage", file: file, line: line)
            return
        }

        let width = cgImage.width
        let height = cgImage.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("\(name) screenshot context creation failed", file: file, line: line)
            return
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var darkPixelCount = 0
        for offset in stride(from: 0, to: data.count, by: 4) {
            let red = Int(data[offset])
            let green = Int(data[offset + 1])
            let blue = Int(data[offset + 2])
            let alpha = Int(data[offset + 3])
            if alpha > 0, red < 105, green < 105, blue < 105 {
                darkPixelCount += 1
            }
        }

        if darkPixelCount <= 900 {
            let attachment = XCTAttachment(image: image)
            attachment.name = "\(name)-visible-text-diagnostic"
            attachment.lifetime = .keepAlways
            add(attachment)
            writeTextAuditDiagnostic(image, name: name)
        }

        XCTAssertGreaterThan(
            darkPixelCount,
            900,
            "\(name) should render visible reader text, not just a blank paper background",
            file: file,
            line: line
        )
    }

    private func writeTextAuditDiagnostic(_ image: UIImage, name: String) {
        guard let data = image.pngData() else {
            return
        }
        let diagnosticsURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("reader-ios-demo-smoke-diagnostics", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: diagnosticsURL, withIntermediateDirectories: true)
            let outputURL = diagnosticsURL.appendingPathComponent("\(sanitizePathComponent(name))-visible-text.png")
            try data.write(to: outputURL, options: .atomic)
            print("[DemoRouteFamilySimulatorSmokeTests] wrote diagnostic screenshot \(outputURL.path)")
        } catch {
            XCTFail("\(name) diagnostic screenshot write failed: \(error)")
        }
    }

    private func writeScreenshot(
        _ image: UIImage,
        family: String,
        name: String,
        size: CGSize,
        directory: String,
        file: StaticString,
        line: UInt
    ) {
        guard !directory.isEmpty else { return }
        guard let data = image.pngData() else {
            XCTFail("\(family)/\(name) screenshot PNG encoding failed", file: file, line: line)
            return
        }

        let baseURL = URL(fileURLWithPath: directory, isDirectory: true)
        let familyURL = baseURL.appendingPathComponent(sanitizePathComponent(family), isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: familyURL, withIntermediateDirectories: true)
            let filename = "\(sanitizePathComponent(name))-\(Int(size.width))x\(Int(size.height)).png"
            try data.write(to: familyURL.appendingPathComponent(filename), options: .atomic)
        } catch {
            XCTFail("\(family)/\(name) screenshot write failed: \(error)", file: file, line: line)
        }
    }

    private func sanitizePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "-"
        }.joined()
    }
}
#endif
