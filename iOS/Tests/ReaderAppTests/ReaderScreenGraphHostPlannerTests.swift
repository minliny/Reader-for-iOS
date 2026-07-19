import Foundation
import ReaderUIContract
import XCTest
@testable import ReaderApp

@MainActor
final class ReaderScreenGraphHostPlannerTests: XCTestCase {
    private let expectedSupportedRaw: Set<String> = [
        "AppTopBar", "BackTopBar", "DiscoverSourceBar", "DiscoverEntryRow",
        "DiscoverFilterTrigger", "DiscoverListHead", "DiscoverBookList", "DiscoverStatePage",
        "DiscoverSourceBulkPage", "DiscoverSourceLoginPage", "DiscoverRuleTestPage", "BottomNav",
        "ContinueReadingCard", "BookshelfShelfSection", "ShelfSectionHeader", "BookGrid",
        "BookCard", "RssSearchEntry", "RssModeRow", "RssSourceOverview", "RssArticleSection",
        "RssAllPage", "RssOriginalPage", "RssRefreshingPage", "RssOriginalBrowserPage",
        "RssFavoriteGroupsPage", "RssSourceGroupsPage", "RssSourceImportPage", "RssSourceEditPage",
        "SettingsHomePage", "SettingsGeneralPage", "BookshelfSearchSettingsPage", "ProgressSyncPage",
        "SearchInputBox", "ScopeSelector", "GroupSelector", "SearchHistoryList", "BookHero",
        "ReadingTextFlow", "ReadingBackgroundLayer", "Loading", "Offline", "Button", "ReaderBase", "ReaderTopArea",
        "ReaderControlSheet", "ReaderBottomBar", "ReaderDirectoryPanel", "ReaderAppearancePanel",
        "ReaderTtsPanel", "ReaderSettingsPanel", "ReaderFullDirectoryPage", "ReaderFullTtsPage",
        "ReaderFullAppearancePage", "ReaderFullSettingsPage", "ReaderBookCachePage",
        "ReaderDebugInfoPage", "ReaderSearchPanel", "ReaderReplacePanel", "ReaderAutoScrollPanel",
        "NightToast", "FloatingPageControl", "SourceSwitchFlowPage", "SourceImportPreviewPage", "SourceGroupsPage",
        "SourceDetectPage", "SourceDebugPage", "SourceDebugRunningPage", "SourceDebugResultPage",
        "SourceDebugContentLogPage", "SourceCodeViewPage", "SourceLogsPage",
        "SourceDeleteConfirmPage", "SourceRuleEditPage", "SourceBatchPage", "AppShellStructure",
        "SearchHomePage", "SearchResultsPage", "SearchStatePage", "BookTocPreviewPage",
        "SourceManagementPage", "SourceDetailPage", "SourceImportOptionsPage", "SourceDisabledState",
        "SourceTestResultPage", "SyncSettingsEntryPage", "SyncBackupPage", "SyncErrorPage",
        "SyncProgressPage", "RestoreConflictPage", "RssDetailPage", "RssEmptyState",
        "RssErrorState", "GlobalStatePage", "OfflineStatePage", "AboutVersionPage",
        "ReadingSettingsEntryPage", "BookGroupManagementPage", "GroupManagementPage",
        "BookBatchManagementPage", "BookDirectoryPage", "AboutFeedbackPage", "GlobalSettingsPage",
        "BackupSettingsPage", "RssSubscriptionManagementPage", "BookCover"
    ]

    private let expectedGenericRaw: Set<String> = [
        "BookshelfEmptyPage", "Content", "Dialog", "Dropdown", "Empty", "Error", "ErrorState",
        "FormSection", "Input", "List", "ListRow", "LocalBookImportPage", "MainTabsStructure",
        "Permission", "PermissionRequiredPage", "ProgressBar", "ReadingInfoLayer",
        "RestoreProgressPage", "SettingsListItem", "Slider", "SourceFormPage",
        "SourceSwitchResultsPanel", "Toast", "Toggle", "WebView"
    ]

    private let expectedVisibleGapRaw: Set<String> = [
        "BookChapterList", "BookMoreMenuPage", "BookSummaryCard",
        "RemoteWebDavBooksPage", "RestoreConfirmPage", "RestoreResultPage"
    ]

    private let expectedHostCompositeRaw: Set<String> = [
        "ReaderBase", "ReaderTopArea", "ReaderBottomBar", "TapZones"
    ]

    private let expectedExplicitGapRaw: Set<String> = [
        "SearchEntry", "SourceTypeSegment", "CurrentSourceCard", "SourceCategoryChips",
        "DiscoveryContentCard", "SourceStatusBar", "ShelfChipGroup", "RecentUpdateCard",
        "BookListItem", "SubscriptionSummaryCard", "FeedStatusChips",
        "FeedSourceChips", "RssEntryItem", "UnreadIndicator", "LocalOverviewCard", "QuickEntryGrid",
        "SettingsSection", "SearchResultList", "AddToShelfButton", "ReadButton",
        "BookTitleAuthor", "SourceStatus", "DirectoryPreview", "BookIntro", "ConfigEntry",
        "Sheet", "Overlay", "Card", "Chip", "Stepper", "Segment",
        "FilterBar", "FloatingBrightness", "FloatingQuickActions",
        "SourceSettingsEntryPage", "WebDavConfigPage"
    ]

    func testCanonicalRegistryIntegrityAndExactMetrics() throws {
        let planner = try ReaderScreenGraphHostPlanner()

        XCTAssertEqual(planner.metrics.sha256, ReaderScreenGraphHostPlanner.expectedCanonicalSHA256)
        XCTAssertEqual(planner.metrics.sha256, ScreenGraphCanonicalAsset.sha256)
        XCTAssertEqual(planner.metrics.routeCount, 260)
        XCTAssertEqual(planner.metrics.directRouteCount, 184)
        XCTAssertEqual(planner.metrics.aliasRouteCount, 76)
        XCTAssertEqual(planner.metrics.variantCount, 190)
        XCTAssertEqual(planner.metrics.recursiveComponentCount, 615)
        XCTAssertEqual(planner.metrics.bindingCount, 97)
        XCTAssertEqual(planner.metrics.executableBindingCount, 41)
        XCTAssertEqual(planner.metrics.plannedFailClosedBindingCount, 56)
        XCTAssertEqual(planner.metrics.stateEventEvidenceCount, 19)
        XCTAssertEqual(planner.metrics.eventReferenceCount, 116)
        XCTAssertEqual(planner.metrics.referencedComponentTypeCount, 138)
        XCTAssertEqual(planner.metrics.explicitGapComponentTypeCount, 36)
        XCTAssertEqual(planner.metrics.actionGapCount, 6)
        XCTAssertEqual(planner.registry.document.routes.map(\.routeId), RouteId.allCases)
    }

    func testAll260RouteQueriesAnd76AliasesResolveToPlans() throws {
        let planner = try ReaderScreenGraphHostPlanner()
        XCTAssertEqual(RouteId.allCases.count, 260)

        for routeId in RouteId.allCases {
            let plan = try planner.plan(routeId: routeId)
            XCTAssertEqual(plan.requestedRouteId, routeId, routeId.rawValue)
            XCTAssertFalse(plan.components.isEmpty, routeId.rawValue)
            XCTAssertEqual(plan.viewState.routeId, plan.resolvedRouteId.rawValue, routeId.rawValue)
            XCTAssertEqual(plan.authority, .shadow, routeId.rawValue)
            XCTAssertFalse(plan.isPromotedRenderAuthority, routeId.rawValue)
            XCTAssertFalse(plan.hasDeviceProof, routeId.rawValue)
        }

        let aliases = planner.registry.document.routes.filter { $0.status == .alias }
        XCTAssertEqual(aliases.count, 76)
        for alias in aliases {
            let plan = try planner.plan(routeId: alias.routeId)
            XCTAssertTrue(plan.isAlias, alias.routeId.rawValue)
            XCTAssertEqual(plan.resolvedRouteId, alias.aliasFor, alias.routeId.rawValue)
        }

        let appearance = try planner.plan(routeId: .readerAppearance)
        XCTAssertEqual(appearance.resolvedRouteId, .readerAppearanceOverlayV2)
        let tts = try planner.plan(routeId: .tts)
        XCTAssertEqual(tts.resolvedRouteId, .readerTtsOverlayV2)
    }

    func testVariantSelectionSupportsExplicitPageStateAndContext() throws {
        let planner = try ReaderScreenGraphHostPlanner()

        XCTAssertEqual(try planner.plan(routeId: .bookDetail).variantId, "default")
        XCTAssertEqual(
            try planner.plan(routeId: .bookDetail, pageState: .loading).variantId,
            "loading"
        )
        XCTAssertEqual(try planner.plan(routeId: .reader, pageState: .offline).variantId, "offline")
        XCTAssertEqual(
            try planner.plan(routeId: .sourceManagement, pageState: .sourceUnavailable).variantId,
            "source-unavailable"
        )
        XCTAssertEqual(
            try planner.plan(routeId: .syncBackup, preferredVariantId: "loading").variantId,
            "loading"
        )
        XCTAssertEqual(
            try planner.plan(
                routeId: .bookDetail,
                overridingContext: ["variantId": AnyCodable("loading")]
            ).variantId,
            "loading"
        )

        XCTAssertThrowsError(
            try planner.plan(routeId: .bookDetail, preferredVariantId: "missing")
        ) { error in
            XCTAssertEqual(
                error as? ReaderScreenGraphPlannerError,
                .variantNotFound(routeId: "book-detail", variantId: "missing")
            )
        }
    }

    func testEveryDirectVariantRecursivelyConvertsWithoutCountOrBindingLoss() throws {
        let planner = try ReaderScreenGraphHostPlanner()
        var componentCount = 0
        var bindingCount = 0
        var stateEventEvidenceCount = 0

        for route in planner.registry.document.routes where route.status == .direct {
            for variant in route.variants {
                let plan = try planner.plan(
                    routeId: route.routeId,
                    preferredVariantId: variant.variantId
                )
                componentCount += plan.recursiveComponentCount
                bindingCount += plan.recursiveBindingCount
                stateEventEvidenceCount += plan.recursiveStateEventEvidenceCount
                XCTAssertEqual(plan.variantId, variant.variantId)
                XCTAssertEqual(plan.components.count, variant.components.count)
                assertSameTree(variant.components, plan.components, routeId: route.routeId.rawValue)
            }
        }

        XCTAssertEqual(componentCount, 615)
        XCTAssertEqual(bindingCount, 97)
        XCTAssertEqual(stateEventEvidenceCount, 19)
        XCTAssertEqual(bindingCount + stateEventEvidenceCount, 116)

        let bookshelf = try planner.plan(routeId: .bookshelf)
        XCTAssertNotNil(bookshelf.component(withId: "bookshelf-shelf-section"))
        XCTAssertNotNil(bookshelf.component(withId: "book-bk-001"))
    }

    func testJSONValueAndNestedBindingPayloadsRemainLossless() throws {
        let original: ScreenGraphJSONValue = .object([
            "null": .null,
            "bool": .bool(true),
            "integer": .integer(9_007_199_254_740_991),
            "number": .number(3.25),
            "string": .string("reader"),
            "array": .array([.integer(1), .string("two"), .null]),
            "object": .object(["enabled": .bool(false)])
        ])
        let converted = try ReaderScreenGraphHostPlanner.anyCodable(original)
        XCTAssertEqual(try canonicalJSON(original), try canonicalJSON(converted))

        let convertedObject = try XCTUnwrap(converted.value as? [String: AnyCodable])
        XCTAssertTrue(convertedObject["bool"]?.value is Bool)
        XCTAssertTrue(convertedObject["integer"]?.value is Int)
        XCTAssertTrue(convertedObject["number"]?.value is Double)
        XCTAssertTrue(convertedObject["array"]?.value is [AnyCodable])
        XCTAssertTrue(convertedObject["object"]?.value is [String: AnyCodable])

        let planner = try ReaderScreenGraphHostPlanner()
        let themePlan = try planner.plan(routeId: .readerThemeNew)
        let themeConfirm = try XCTUnwrap(themePlan.component(withId: "reader_theme_new-confirm"))
        let themeBinding = try XCTUnwrap(themeConfirm.bindings.first)
        XCTAssertEqual(themeBinding.event.rawValue, "reader.theme.new")
        XCTAssertEqual(themeBinding.evidenceProperty, "uiEvent")
        XCTAssertEqual(themeBinding.trigger, "tap")
        let theme = try XCTUnwrap(themeBinding.payload["theme"]?.value as? [String: AnyCodable])
        XCTAssertEqual(theme["id"]?.value as? String, "theme-custom-paper")
        XCTAssertEqual(theme["accent"]?.value as? String, "#8A5F3D")

        let propPayload = try XCTUnwrap(
            themeConfirm.component.props?["uiEventPayload"]?.value as? [String: AnyCodable]
        )
        XCTAssertEqual(
            try canonicalJSON(AnyCodable(propPayload)),
            try canonicalJSON(AnyCodable(themeBinding.payload))
        )

        let deletePlan = try planner.plan(routeId: .readerReplaceDeleteConfirm)
        let deleteAction = try XCTUnwrap(
            deletePlan.component(withId: "reader_replace_delete_confirm-action-1")
        )
        XCTAssertEqual(deleteAction.bindings.first?.payload["ruleId"]?.value as? Int, 41)

        let partialPlan = try planner.plan(routeId: .importPartialSuccess)
        let partialState = try XCTUnwrap(
            partialPlan.component(withId: "import_partial_success-state")
        )
        XCTAssertTrue(partialState.bindings.isEmpty)
        XCTAssertEqual(partialState.stateEventEvidence.count, 1)
        XCTAssertEqual(partialState.stateEventEvidence.first?.classification, "state-evidence")
        XCTAssertEqual(partialState.stateEventEvidence.first?.event.rawValue, "import.partial.success")
        let retryAction = try XCTUnwrap(partialPlan.component(withId: "import_partial_success-action"))
        let failureIds = try XCTUnwrap(
            retryAction.bindings.first?.payload["failureIds"]?.value as? [AnyCodable]
        )
        XCTAssertEqual(failureIds.first?.value as? String, "file-003")
    }

    func testExactNativeCoverageAndExplicitGapsRemainUnadapted() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()
        let coverage = planner.componentCoverage()

        XCTAssertEqual(
            rawValues(coverage.canonicalReferenced),
            expectedSupportedRaw
                .union(expectedGenericRaw)
                .union(expectedVisibleGapRaw)
                .union(expectedHostCompositeRaw)
        )
        XCTAssertEqual(rawValues(coverage.canonicalExplicitGaps), expectedExplicitGapRaw)
        XCTAssertEqual(
            rawValues(coverage.faithfulReferenced),
            expectedSupportedRaw.subtracting(expectedHostCompositeRaw)
        )
        XCTAssertEqual(rawValues(coverage.genericUsableReferenced), expectedGenericRaw)
        XCTAssertEqual(
            rawValues(coverage.hostCompositeIntegratedReferenced),
            expectedHostCompositeRaw
        )
        XCTAssertEqual(
            rawValues(coverage.supportedReferenced),
            expectedSupportedRaw.union(expectedGenericRaw).union(expectedHostCompositeRaw)
        )
        XCTAssertEqual(rawValues(coverage.visibleReferencedGaps), expectedVisibleGapRaw)
        XCTAssertEqual(coverage.faithfulReferenced.count, 103)
        XCTAssertEqual(coverage.genericUsableReferenced.count, 25)
        XCTAssertEqual(coverage.hostCompositeIntegratedReferenced.count, 4)
        XCTAssertEqual(coverage.supportedReferenced.count, 132)
        XCTAssertEqual(coverage.visibleReferencedGaps.count, 6)
        XCTAssertEqual(coverage.canonicalReferenced.count, 138)
        XCTAssertEqual(coverage.canonicalExplicitGaps.count, 36)
        XCTAssertEqual(rawValues(coverage.screenGraphAdapterTypes), expectedGenericRaw)
        XCTAssertTrue(coverage.explicitGapAdapterTypes.isEmpty)
        XCTAssertFalse(coverage.fullRenderer)
        XCTAssertEqual(Set(coverage.visibleGapReasons.keys), coverage.visibleReferencedGaps)
        XCTAssertTrue(coverage.visibleGapReasons.values.allSatisfy {
            !$0.code.isEmpty && !$0.detail.isEmpty
        })

        XCTAssertEqual(
            rawValues(coverage.nativeRenderersForExplicitGaps),
            [
                "AddToShelfButton", "BookIntro", "BookListItem",
                "BookTitleAuthor", "DirectoryPreview", "ReadButton", "SourceStatus"
            ]
        )

        let referencedInstanceCounts = Dictionary(uniqueKeysWithValues:
            planner.registry.document.componentCatalog
                .filter { $0.status == .referenced }
                .map { ($0.type, $0.instanceCount) }
        )
        func instanceCount(for types: Set<ComponentType>) -> Int {
            types.reduce(0) { $0 + (referencedInstanceCounts[$1] ?? 0) }
        }
        XCTAssertEqual(instanceCount(for: coverage.faithfulReferenced), 425)
        XCTAssertEqual(instanceCount(for: coverage.genericUsableReferenced), 67)
        XCTAssertEqual(instanceCount(for: coverage.hostCompositeIntegratedReferenced), 115)
        XCTAssertEqual(instanceCount(for: coverage.visibleReferencedGaps), 8)
    }

    func testHostCompositesKeepAuditTreeButDoNotRecursivelyProjectViewState() throws {
        let planner = try ReaderScreenGraphHostPlanner()
        let plan = try planner.plan(routeId: .readerPageBoundaryFirst)
        let readerBase = try XCTUnwrap(plan.component(withId: "reader-base"))

        XCTAssertEqual(readerBase.compositionMode, .hostComposite)
        XCTAssertEqual(
            readerBase.stateAuthorities,
            ["core", "reader-ui-runtime", "host-store", "host-layout"]
        )
        XCTAssertEqual(readerBase.children.count, 4, "Canonical descendants remain auditable.")
        XCTAssertTrue(
            readerBase.component.children?.isEmpty == true,
            "Host composite descendants must not enter the generic ViewState renderer."
        )

        let tapZones = try XCTUnwrap(readerBase.component(withId: "reader-tap-zones"))
        XCTAssertEqual(tapZones.compositionMode, .hostComposite)
        XCTAssertEqual(tapZones.stateAuthorities, ["reader-ui-runtime", "host-layout"])
        XCTAssertTrue(tapZones.children.isEmpty)

        let reader = try planner.plan(routeId: .reader)
        for (id, authorities) in [
            ("reader-top-area", ["core", "reader-ui-runtime", "host-store"]),
            ("reader-bottom-bar", ["reader-ui-runtime", "host-store"]),
        ] {
            let component = try XCTUnwrap(reader.component(withId: id), id)
            XCTAssertEqual(component.compositionMode, .hostComposite, id)
            XCTAssertEqual(component.stateAuthorities, authorities, id)
        }
    }

    func testTapZonesCanonicalTargetsPreserveBindingsAndProductionIntentChain() throws {
        let planner = try ReaderScreenGraphHostPlanner()
        let cases: [(RouteId, [ReaderTapZoneTarget])] = [
            (.readerContentLoading, []),
            (.readerContentOffline, [.previous, .control, .next]),
            (.readerContentError, [.previous, .control, .next]),
            (.readerPageBoundaryFirst, [.control, .next]),
            (.readerPageBoundaryLast, [.previous, .control]),
        ]

        for (routeId, expectedTargets) in cases {
            let tapZones = try XCTUnwrap(
                planner.plan(routeId: routeId).component(withId: "reader-tap-zones"),
                routeId.rawValue
            )
            XCTAssertEqual(tapZones.compositionMode, .hostComposite, routeId.rawValue)
            XCTAssertEqual(tapZones.component.props?.string("mode"), "horizontal")
            XCTAssertEqual(tapZones.component.props?.double("previousRatio"), 0.26)
            XCTAssertEqual(tapZones.component.props?.double("controlRatio"), 0.48)
            XCTAssertEqual(tapZones.component.props?.double("nextRatio"), 0.26)
            XCTAssertEqual(tapZones.bindings.map(\.target), expectedTargets.map(\.rawValue))
            XCTAssertEqual(
                tapZones.component.bindings?.map(\.target),
                expectedTargets.map(\.rawValue),
                "ScreenGraph explicit bindings must survive the ViewState bridge."
            )

            for target in ReaderTapZoneTarget.allCases {
                let action = ReaderScreenGraphHostCompositePolicy.action(for: target, in: tapZones)
                if expectedTargets.contains(target) {
                    let action = try XCTUnwrap(action, "\(routeId.rawValue)/\(target.rawValue)")
                    switch target {
                    case .previous:
                        XCTAssertEqual(action.event, .reader_page_prev)
                        XCTAssertTrue(action.payload.isEmpty)
                    case .control:
                        XCTAssertEqual(action.event, .reader_control_toggle)
                        XCTAssertEqual(action.payload.string("overlay"), "reader-control")
                    case .next:
                        XCTAssertEqual(action.event, .reader_page_next)
                        XCTAssertTrue(action.payload.isEmpty)
                    }
                } else {
                    XCTAssertNil(action, "\(routeId.rawValue)/\(target.rawValue)")
                }
            }
        }

        XCTAssertEqual(ReaderHotZoneSegment.previousPage.canonicalTarget, .previous)
        XCTAssertEqual(ReaderHotZoneSegment.controls.canonicalTarget, .control)
        XCTAssertEqual(ReaderHotZoneSegment.nextPage.canonicalTarget, .next)

        let navigationState = AppNavigationState()
        let coordinator = ReaderCoordinator(navigationState: navigationState)
        XCTAssertEqual(navigationState.overlayState, .none)
        coordinator.toggleReaderControl()
        XCTAssertEqual(navigationState.overlayState, .sheet)
        coordinator.toggleReaderControl()
        XCTAssertEqual(navigationState.overlayState, .none)
    }

    func testFloatingPageControlFaithfullyDecodesReadOnlyBoundaryEvidence() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()

        let firstComponent = try XCTUnwrap(
            planner.plan(routeId: .readerPageBoundaryFirst)
                .component(withId: "reader_page_boundary_first-control")?.component
        )
        let first = try XCTUnwrap(FloatingPageControlProps(props: firstComponent.props))
        XCTAssertEqual(first.title, "已是第一章")
        XCTAssertEqual(first.bookId, "bk-001")
        XCTAssertEqual(first.boundary, .first)

        let lastComponent = try XCTUnwrap(
            planner.plan(routeId: .readerPageBoundaryLast)
                .component(withId: "reader_page_boundary_last-control")?.component
        )
        let last = try XCTUnwrap(FloatingPageControlProps(props: lastComponent.props))
        XCTAssertEqual(last.title, "已是最后一章")
        XCTAssertEqual(last.bookId, "bk-001")
        XCTAssertEqual(last.boundary, .last)

        XCTAssertTrue(ComponentRegistry.isRegistered(.floatingPageControl))
        XCTAssertFalse(ComponentRegistry.genericRendererTypes.contains(.floatingPageControl))
    }

    func testPermissionRequiredPageStrictGenericPreservesVisibleActionGap() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()

        let planned = try XCTUnwrap(
            planner.plan(routeId: .permissionRequired)
                .component(withId: "permission-page")
        )
        let props = try XCTUnwrap(
            ReaderScreenGraphPermissionRequiredPageProps(props: planned.component.props)
        )
        XCTAssertEqual(props.title, "需要存储权限")
        XCTAssertEqual(props.message, "授予权限后可导入本地书籍。")
        XCTAssertEqual(props.actionLabel, "授予权限")
        XCTAssertTrue(planned.bindings.isEmpty)
        XCTAssertNil(ReaderScreenGraphButtonActionResolver.action(for: planned.component))
        XCTAssertTrue(ComponentRegistry.isRegistered(.permissionRequiredPage))
        XCTAssertTrue(ComponentRegistry.genericRendererTypes.contains(.permissionRequiredPage))
        XCTAssertFalse(ComponentRegistry.faithfulRendererTypes.contains(.permissionRequiredPage))
        _ = ReaderScreenGraphGenericComponentView(component: planned.component)

        XCTAssertNil(
            ReaderScreenGraphPermissionRequiredPageProps(
                props: [
                    "title": AnyCodable("需要存储权限"),
                    "message": AnyCodable("授予权限后可导入本地书籍。"),
                    "action": AnyCodable("授予权限"),
                    "uiEvent": AnyCodable("host.permission.request")
                ]
            ),
            "A future executable binding must be reviewed instead of silently entering the read-only adapter."
        )
    }

    func testMainTabsStructureStrictGenericDoesNotInventTabIdentityOrSelection() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()

        let planned = try XCTUnwrap(
            planner.plan(routeId: .mainTabs)
                .component(withId: "main-tabs-structure")
        )
        let props = try XCTUnwrap(
            ReaderScreenGraphMainTabsStructureProps(props: planned.component.props)
        )
        XCTAssertEqual(props.title, "主导航")
        XCTAssertEqual(props.message, "底部四项：书架、发现、RSS、设置。")
        XCTAssertTrue(planned.bindings.isEmpty)
        XCTAssertTrue(planned.children.isEmpty)
        XCTAssertNil(ReaderScreenGraphButtonActionResolver.action(for: planned.component))
        XCTAssertTrue(ComponentRegistry.isRegistered(.mainTabsStructure))
        XCTAssertTrue(ComponentRegistry.genericRendererTypes.contains(.mainTabsStructure))
        XCTAssertFalse(ComponentRegistry.faithfulRendererTypes.contains(.mainTabsStructure))
        _ = ReaderScreenGraphGenericComponentView(component: planned.component)

        XCTAssertNil(
            ReaderScreenGraphMainTabsStructureProps(
                props: [
                    "title": AnyCodable("主导航"),
                    "message": AnyCodable("底部四项：书架、发现、RSS、设置。"),
                    "selectedTab": AnyCodable("bookshelf")
                ]
            ),
            "A future tab model must be reviewed instead of silently entering the read-only adapter."
        )
    }

    func testRestoreProgressStrictGenericIsIndeterminateAcrossBothLoadingRoutes() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()

        let cases: [(RouteId, String, ReaderScreenGraphRestoreProgressPhase)] = [
            (.restoreRunning, "restore-running-page", .running),
            (.restoreProgress, "restore-progress-page", .unspecified)
        ]
        for (route, componentId, expectedPhase) in cases {
            let plan = try planner.plan(routeId: route)
            XCTAssertEqual(plan.viewState.pageState, .loading, route.rawValue)
            let planned = try XCTUnwrap(plan.component(withId: componentId), route.rawValue)
            let props = try XCTUnwrap(
                ReaderScreenGraphRestoreProgressProps(props: planned.component.props),
                route.rawValue
            )
            XCTAssertEqual(props.phase, expectedPhase, route.rawValue)
            XCTAssertTrue(planned.bindings.isEmpty, route.rawValue)
            XCTAssertTrue(planned.stateEventEvidence.isEmpty, route.rawValue)
            XCTAssertTrue(planned.children.isEmpty, route.rawValue)
            XCTAssertNil(
                ReaderScreenGraphButtonActionResolver.action(for: planned.component),
                route.rawValue
            )
            _ = ReaderScreenGraphGenericComponentView(component: planned.component)
        }

        XCTAssertTrue(ComponentRegistry.isRegistered(.restoreProgressPage))
        XCTAssertTrue(ComponentRegistry.genericRendererTypes.contains(.restoreProgressPage))
        XCTAssertFalse(ComponentRegistry.faithfulRendererTypes.contains(.restoreProgressPage))
        XCTAssertNil(
            ReaderScreenGraphRestoreProgressProps(
                props: [
                    "variant": AnyCodable("running"),
                    "progress": AnyCodable(0.68)
                ]
            ),
            "Determinate progress requires a reviewed canonical schema."
        )
        XCTAssertNil(
            ReaderScreenGraphRestoreProgressProps(
                props: ["variant": AnyCodable("completed")]
            ),
            "A future restore phase must fail closed until reviewed."
        )
    }

    func testRestoreConfirmAndResultStayVisibleGapsWithoutSemanticModels() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()

        let confirmCases: [(RouteId, String, String?)] = [
            (.restoreScopes, "restore-scopes-page", "scopes"),
            (.restorePreview, "restore-preview-page", "preview"),
            (.restoreConfirm, "restore-confirm-page", nil)
        ]
        for (route, componentId, expectedVariant) in confirmCases {
            let planned = try XCTUnwrap(
                planner.plan(routeId: route).component(withId: componentId),
                route.rawValue
            )
            XCTAssertEqual(planned.component.props?.string("variant"), expectedVariant)
            XCTAssertTrue(planned.bindings.isEmpty, route.rawValue)
            XCTAssertTrue(planned.stateEventEvidence.isEmpty, route.rawValue)
            XCTAssertTrue(planned.children.isEmpty, route.rawValue)
            XCTAssertEqual(
                ComponentRegistry.renderingDisposition(for: planned.component),
                .visibleFailure(type: .restoreConfirmPage, id: componentId),
                route.rawValue
            )
        }

        let result = try XCTUnwrap(
            planner.plan(routeId: .restoreResult).component(withId: "restore-result-page")
        )
        XCTAssertTrue(result.component.props?.isEmpty == true)
        XCTAssertTrue(result.bindings.isEmpty)
        XCTAssertTrue(result.stateEventEvidence.isEmpty)
        XCTAssertTrue(result.children.isEmpty)
        XCTAssertEqual(
            ComponentRegistry.renderingDisposition(for: result.component),
            .visibleFailure(type: .restoreResultPage, id: "restore-result-page")
        )

        XCTAssertFalse(ComponentRegistry.isRegistered(.restoreConfirmPage))
        XCTAssertFalse(ComponentRegistry.isRegistered(.restoreResultPage))
        XCTAssertEqual(
            ReaderScreenGraphGenericComponentPolicy.visibleGapReasons[.restoreConfirmPage]?.code,
            "missing-confirmation-model"
        )
        XCTAssertEqual(
            ReaderScreenGraphGenericComponentPolicy.visibleGapReasons[.restoreResultPage]?.code,
            "missing-semantic-props"
        )
    }

    func testErrorStrictGenericShowsMessageWithoutInventingRetryAction() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()

        let plan = try planner.plan(routeId: .stateError)
        XCTAssertEqual(plan.viewState.pageState, .error)
        XCTAssertEqual(plan.viewState.context?["message"]?.stringValue, "网络异常")
        let planned = try XCTUnwrap(plan.component(withId: "global-error"))
        let props = try XCTUnwrap(
            ReaderScreenGraphErrorProps(props: planned.component.props)
        )
        XCTAssertEqual(props.message, "网络异常")
        XCTAssertTrue(props.retryable)
        XCTAssertTrue(planned.bindings.isEmpty)
        XCTAssertTrue(planned.stateEventEvidence.isEmpty)
        XCTAssertTrue(planned.children.isEmpty)
        XCTAssertNil(ReaderScreenGraphButtonActionResolver.action(for: planned.component))
        XCTAssertTrue(ComponentRegistry.isRegistered(.error))
        XCTAssertTrue(ComponentRegistry.genericRendererTypes.contains(.error))
        XCTAssertFalse(ComponentRegistry.faithfulRendererTypes.contains(.error))
        _ = ReaderScreenGraphGenericComponentView(component: planned.component)

        XCTAssertNil(
            ReaderScreenGraphErrorProps(
                props: [
                    "message": AnyCodable("网络异常"),
                    "retryable": AnyCodable(true),
                    "uiEvent": AnyCodable("state.retry")
                ]
            ),
            "A future retry binding must be reviewed instead of entering the read-only adapter."
        )
        XCTAssertNil(
            ReaderScreenGraphErrorProps(
                props: ["message": AnyCodable("网络异常"), "retryable": AnyCodable(false)]
            ),
            "A future non-retryable variant must fail closed until reviewed."
        )
    }

    func testBookSummaryAndChapterListStayVisibleGapsWithoutComponentData() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()
        let plan = try planner.plan(routeId: .bookDetail)
        XCTAssertEqual(plan.viewState.context?["bookId"]?.stringValue, "bk-001")

        let cases: [(String, ComponentType)] = [
            ("detail-summary", .bookSummaryCard),
            ("detail-chapters", .bookChapterList)
        ]
        for (componentId, type) in cases {
            let planned = try XCTUnwrap(plan.component(withId: componentId), componentId)
            XCTAssertTrue(planned.component.props?.isEmpty == true, componentId)
            XCTAssertTrue(planned.bindings.isEmpty, componentId)
            XCTAssertTrue(planned.stateEventEvidence.isEmpty, componentId)
            XCTAssertTrue(planned.children.isEmpty, componentId)
            XCTAssertEqual(
                ComponentRegistry.renderingDisposition(for: planned.component),
                .visibleFailure(type: type, id: componentId),
                componentId
            )
        }

        XCTAssertFalse(ComponentRegistry.isRegistered(.bookSummaryCard))
        XCTAssertFalse(ComponentRegistry.isRegistered(.bookChapterList))
        XCTAssertEqual(
            ReaderScreenGraphGenericComponentPolicy.visibleGapReasons[.bookSummaryCard]?.code,
            "missing-semantic-props"
        )
        XCTAssertEqual(
            ReaderScreenGraphGenericComponentPolicy.visibleGapReasons[.bookChapterList]?.code,
            "missing-collection-items"
        )
    }

    func testLocalImportTitleOnlySchemaHasReadOnlyNativeStructure() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()

        let plan = try planner.plan(routeId: .localImport)
        XCTAssertEqual(plan.viewState.pageState, .defaultValue)
        XCTAssertTrue(plan.viewState.context?.isEmpty == true)
        XCTAssertTrue(plan.facets.isEmpty)
        XCTAssertTrue(plan.actionGaps.isEmpty)

        let planned = try XCTUnwrap(plan.component(withId: "local-import-page"))
        let props = try XCTUnwrap(planned.component.props)
        XCTAssertEqual(Set(props.keys), ["title"])
        XCTAssertEqual(props.string("title"), "本地导入")
        XCTAssertTrue(planned.bindings.isEmpty)
        XCTAssertTrue(planned.stateEventEvidence.isEmpty)
        XCTAssertTrue(planned.children.isEmpty)
        XCTAssertEqual(
            ComponentRegistry.renderingDisposition(for: planned.component),
            .registered
        )
        XCTAssertTrue(ComponentRegistry.isRegistered(.localBookImportPage))
        XCTAssertTrue(
            ComponentRegistry.genericRendererTypes.contains(.localBookImportPage)
        )
        XCTAssertNil(
            ReaderScreenGraphGenericComponentPolicy.visibleGapReasons[.localBookImportPage]
        )

        let catalog = try XCTUnwrap(
            planner.registry.document.componentCatalog.first { $0.type == .localBookImportPage }
        )
        XCTAssertEqual(catalog.status, .referenced)
        XCTAssertEqual(catalog.instanceCount, 2)
        XCTAssertEqual(Set(catalog.routeIds), [.localImport, .localFormatSupport])
    }

    func testRemoteWebDavBooksTitleOnlySchemaStaysVisibleGap() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()
        let plan = try planner.plan(routeId: .remoteWebdavBooks)

        XCTAssertEqual(plan.viewState.pageState, .defaultValue)
        XCTAssertTrue(plan.viewState.context?.isEmpty == true)
        XCTAssertTrue(plan.facets.isEmpty)
        XCTAssertTrue(plan.actionGaps.isEmpty)

        let planned = try XCTUnwrap(plan.component(withId: "remote-webdav-books-page"))
        let props = try XCTUnwrap(planned.component.props)
        XCTAssertEqual(Set(props.keys), ["title"])
        XCTAssertEqual(props.string("title"), "远端书籍")
        XCTAssertTrue(planned.bindings.isEmpty)
        XCTAssertTrue(planned.stateEventEvidence.isEmpty)
        XCTAssertTrue(planned.children.isEmpty)
        XCTAssertEqual(
            ComponentRegistry.renderingDisposition(for: planned.component),
            .visibleFailure(
                type: .remoteWebDavBooksPage,
                id: "remote-webdav-books-page"
            )
        )
        XCTAssertFalse(ComponentRegistry.isRegistered(.remoteWebDavBooksPage))
        XCTAssertEqual(
            ReaderScreenGraphGenericComponentPolicy
                .visibleGapReasons[.remoteWebDavBooksPage]?.code,
            "missing-collection-items"
        )

        let catalog = try XCTUnwrap(
            planner.registry.document.componentCatalog.first {
                $0.type == .remoteWebDavBooksPage
            }
        )
        XCTAssertEqual(catalog.status, .referenced)
        XCTAssertEqual(catalog.instanceCount, 1)
        XCTAssertEqual(catalog.routeIds, [.remoteWebdavBooks])
    }

    func testBookMoreMenuStaysVisibleGapWithoutMenuItemsOrActions() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()
        let plan = try planner.plan(routeId: .bookshelfBookMoreMenu)

        XCTAssertEqual(plan.viewState.pageState, .defaultValue)
        XCTAssertEqual(plan.viewState.context?["tab"]?.stringValue, "bookshelf")
        XCTAssertTrue(plan.facets.isEmpty)
        XCTAssertTrue(plan.actionGaps.isEmpty)

        let planned = try XCTUnwrap(plan.component(withId: "book-more-menu-page"))
        let props = try XCTUnwrap(planned.component.props)
        XCTAssertEqual(Set(props.keys), ["subtitle", "title"])
        XCTAssertEqual(props.string("title"), "深空信号")
        XCTAssertEqual(props.string("subtitle"), "本地书籍")
        XCTAssertTrue(planned.bindings.isEmpty)
        XCTAssertTrue(planned.stateEventEvidence.isEmpty)
        XCTAssertTrue(planned.children.isEmpty)
        XCTAssertNil(ReaderScreenGraphButtonActionResolver.action(for: planned.component))
        XCTAssertEqual(
            ComponentRegistry.renderingDisposition(for: planned.component),
            .visibleFailure(type: .bookMoreMenuPage, id: "book-more-menu-page")
        )
        XCTAssertFalse(ComponentRegistry.isRegistered(.bookMoreMenuPage))
        XCTAssertEqual(
            ReaderScreenGraphGenericComponentPolicy.visibleGapReasons[.bookMoreMenuPage]?.code,
            "missing-action-model"
        )

        let catalog = try XCTUnwrap(
            planner.registry.document.componentCatalog.first { $0.type == .bookMoreMenuPage }
        )
        XCTAssertEqual(catalog.status, .referenced)
        XCTAssertEqual(catalog.instanceCount, 1)
        XCTAssertEqual(catalog.routeIds, [.bookshelfBookMoreMenu])
    }

    func test97BindingsSeparate41ExecutableFrom56PlannedAnd19StateEventsStayReadOnly() throws {
        let planner = try ReaderScreenGraphHostPlanner()
        var bindingCount = 0
        var selfBindingCount = 0
        var semanticTargetBindingCount = 0
        var executableBindingCount = 0
        var plannedBindingCount = 0
        var stateEvidenceCount = 0
        var executableButtons = 0
        var plannedButtons = 0

        for route in planner.registry.document.routes where route.status == .direct {
            for variant in route.variants {
                let plan = try planner.plan(
                    routeId: route.routeId,
                    preferredVariantId: variant.variantId
                )
                for component in flatten(plan.components) {
                    bindingCount += component.bindings.count
                    selfBindingCount += component.bindings.filter { $0.target == "self" }.count
                    semanticTargetBindingCount += component.bindings.filter { $0.target != "self" }.count
                    executableBindingCount += component.bindings.filter(\.isExecutable).count
                    plannedBindingCount += component.bindings.filter { !$0.isExecutable }.count
                    stateEvidenceCount += component.stateEventEvidence.count
                    XCTAssertTrue(component.bindings.allSatisfy {
                        ["tap", "appear", "change", "submit"].contains($0.trigger)
                    })
                    XCTAssertTrue(component.stateEventEvidence.allSatisfy {
                        $0.classification == "state-evidence"
                    })

                    let action = ReaderScreenGraphButtonActionResolver.action(
                        for: component.component
                    )
                    if component.component.type == .button, let binding = component.bindings.first {
                        if binding.isExecutable {
                            let action = try XCTUnwrap(action, component.component.id ?? "button")
                            XCTAssertEqual(action.event, binding.event)
                            XCTAssertEqual(
                                try canonicalJSON(AnyCodable(action.payload)),
                                try canonicalJSON(AnyCodable(binding.payload))
                            )
                            executableButtons += 1
                        } else {
                            XCTAssertNil(action, component.component.id ?? "button")
                            plannedButtons += 1
                        }
                    } else {
                        XCTAssertNil(action, component.component.id ?? component.component.type.rawValue)
                    }

                    if !component.stateEventEvidence.isEmpty {
                        XCTAssertNil(action, "state evidence must never become a callback")
                    }
                }
            }
        }

        XCTAssertEqual(bindingCount, 97)
        XCTAssertEqual(selfBindingCount, 36)
        XCTAssertEqual(semanticTargetBindingCount, 61)
        XCTAssertEqual(executableBindingCount, 41)
        XCTAssertEqual(plannedBindingCount, 56)
        XCTAssertEqual(stateEvidenceCount, 19)
        XCTAssertEqual(executableButtons, 22)
        XCTAssertEqual(plannedButtons, 35)
    }

    func testGenericFamiliesAndDedicatedButtonExposeSemanticPropsCallbackAndAccessibility() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()

        let listPlan = try planner.plan(routeId: .readerReplacePage)
        let list = try XCTUnwrap(listPlan.component(withId: "reader_replace_page-state"))
        XCTAssertEqual(list.component.type, .list)
        XCTAssertTrue(list.children.isEmpty)
        XCTAssertEqual(list.component.props?.string("title"), "替换规则管理")
        XCTAssertTrue(
            ReaderScreenGraphGenericAccessibility.identifier(for: list.component)
                .hasSuffix("List-reader_replace_page-state")
        )
        _ = ReaderScreenGraphGenericComponentView(component: list.component)

        let dialogPlan = try planner.plan(routeId: .readerProgressRestore)
        let dialog = try XCTUnwrap(
            dialogPlan.component(withId: "reader-progress-restore-dialog")
        )
        XCTAssertEqual(dialog.component.props?.string("title"), "恢复上次阅读进度")
        XCTAssertEqual(dialog.children.count, 2)

        let themePlan = try planner.plan(routeId: .readerThemeNew)
        let button = try XCTUnwrap(themePlan.component(withId: "reader_theme_new-confirm"))
        let action = try XCTUnwrap(
            ReaderScreenGraphButtonActionResolver.action(for: button.component)
        )
        var received: UiEvent?
        let callback: (UiEvent) -> Void = { received = $0 }
        callback(action.makeEvent())
        XCTAssertEqual(received?.type.rawValue, "reader.theme.new")
        XCTAssertEqual(
            received?.payload["theme"]?.dictValue?["id"]?.stringValue,
            "theme-custom-paper"
        )

        let evidencePlan = try planner.plan(routeId: .importPartialSuccess)
        let evidence = try XCTUnwrap(
            evidencePlan.component(withId: "import_partial_success-state")
        )
        XCTAssertEqual(evidence.component.props?.string("title"), "部分导入成功")
        XCTAssertEqual(evidence.component.props?.string("uiEventTrigger"), "state-evidence")
        XCTAssertNil(ReaderScreenGraphButtonActionResolver.action(for: evidence.component))
    }

    func testUnknownRouteAndRawHostCompositeWithoutHostAdapterFailClosedVisibly() throws {
        let planner = try ReaderScreenGraphHostPlanner()
        let unknown = try JSONDecoder().decode(
            ViewState.self,
            from: Data(
                #"{"routeId":"not-a-reader-route","pageState":"default","context":{},"components":[]}"#.utf8
            )
        )
        XCTAssertThrowsError(try planner.plan(viewState: unknown)) { error in
            XCTAssertEqual(
                error as? ReaderScreenGraphPlannerError,
                .unknownRoute("not-a-reader-route")
            )
        }

        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let unsupported = try JSONDecoder().decode(
            ViewStateComponent.self,
            from: Data(
                #"{"type":"TapZones","id":"missing-tap-zones","props":{"enabled":true},"children":[]}"#.utf8
            )
        )
        XCTAssertEqual(
            ComponentRegistry.renderingDisposition(for: unsupported),
            .visibleFailure(type: .tapZones, id: "missing-tap-zones")
        )
        XCTAssertFalse(ComponentRegistry.isRegistered(.tapZones))
        _ = ComponentRegistry.render(unsupported)

        let failure = UnsupportedComponentFailureView(
            type: .tapZones,
            componentId: "missing-tap-zones",
            reason: "host-composite-requires-host-adapter"
        )
        XCTAssertEqual(failure.type, .tapZones)
        XCTAssertEqual(failure.componentId, "missing-tap-zones")
        XCTAssertEqual(failure.reason, "host-composite-requires-host-adapter")
    }

    func testProductionHostAndContract25EntriesConsumeShadowWithoutPromotion() throws {
        let host = ContractHostView(routeId: .bookshelf)
        let hostPlan = try host.screenGraphShadowPlan.get()
        XCTAssertEqual(hostPlan.requestedRouteId, .bookshelf)
        XCTAssertEqual(hostPlan.authority, .shadow)
        XCTAssertFalse(hostPlan.isPromotedRenderAuthority)
        XCTAssertFalse(hostPlan.hasDeviceProof)

        let route25 = ReaderContract25RouteScreen(routeId: .readerThemeNew)
        let route25Plan = try route25.screenGraphShadowPlan.get()
        XCTAssertEqual(route25Plan.requestedRouteId, .readerThemeNew)
        XCTAssertEqual(route25Plan.authority, .shadow)
        XCTAssertFalse(route25Plan.isPromotedRenderAuthority)
        XCTAssertFalse(route25Plan.hasDeviceProof)
    }

    func testSixActionGapsAreReportedExactlyAndNotInventedAsBindings() throws {
        let planner = try ReaderScreenGraphHostPlanner()
        var actual = Set<String>()

        for route in planner.registry.document.routes {
            for variant in route.variants {
                for gap in variant.actionGaps {
                    let value: String
                    if case .string(let string) = gap.value {
                        value = string
                    } else {
                        value = String(describing: gap.value)
                    }
                    actual.insert(
                        [
                            route.routeId.rawValue, variant.variantId, gap.componentId,
                            gap.property, value, gap.reason
                        ].joined(separator: "|")
                    )
                }
            }
        }

        let expected: Set<String> = [
            "search-error|error|search-error-page|action|重试|label-without-ui-event",
            "rss-error|error|rss-error-page|action|重试|label-without-ui-event",
            "global-error|error|global-error-page|action|重试|label-without-ui-event",
            "permission-required|permission|permission-page|action|授予权限|label-without-ui-event",
            "reader-progress-restore|default|reader-progress-start-over|action|从头阅读|label-without-ui-event",
            "import-parsing|loading|import_parsing-action|action|取消解析|label-without-ui-event"
        ]
        XCTAssertEqual(actual, expected)
    }

    private func rawValues(_ values: Set<ComponentType>) -> Set<String> {
        Set(values.map(\.rawValue))
    }

    private func flatten(
        _ components: [ReaderScreenGraphPlannedComponent]
    ) -> [ReaderScreenGraphPlannedComponent] {
        components.flatMap { [$0] + flatten($0.children) }
    }

    private func assertSameTree(
        _ canonical: [ScreenGraphComponentNode],
        _ planned: [ReaderScreenGraphPlannedComponent],
        routeId: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(canonical.count, planned.count, routeId, file: file, line: line)
        for (source, target) in zip(canonical, planned) {
            XCTAssertEqual(source.id, target.component.id, routeId, file: file, line: line)
            XCTAssertEqual(source.type, target.component.type, routeId, file: file, line: line)
            XCTAssertEqual(
                source.stateAuthorities,
                target.stateAuthorities,
                routeId,
                file: file,
                line: line
            )
            XCTAssertEqual(
                source.compositionMode,
                target.compositionMode.rawValue,
                routeId,
                file: file,
                line: line
            )
            XCTAssertEqual(source.bindings.count, target.bindings.count, routeId, file: file, line: line)
            XCTAssertEqual(
                source.bindings.map(\.target),
                target.bindings.map(\.target),
                routeId,
                file: file,
                line: line
            )
            XCTAssertEqual(
                source.bindings.map(\.target),
                target.component.bindings?.map(\.target) ?? [],
                routeId,
                file: file,
                line: line
            )
            XCTAssertEqual(
                source.stateEventEvidence.count,
                target.stateEventEvidence.count,
                routeId,
                file: file,
                line: line
            )
            XCTAssertEqual(source.children.count, target.children.count, routeId, file: file, line: line)
            if target.compositionMode == .hostComposite {
                XCTAssertTrue(
                    target.component.children?.isEmpty == true,
                    routeId,
                    file: file,
                    line: line
                )
            } else {
                XCTAssertEqual(
                    source.children.count,
                    target.component.children?.count ?? 0,
                    routeId,
                    file: file,
                    line: line
                )
            }
            assertSameTree(source.children, target.children, routeId: routeId, file: file, line: line)
        }
    }

    private func canonicalJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
}
