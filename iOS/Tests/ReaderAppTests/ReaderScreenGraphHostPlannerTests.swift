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
        "ReadingTextFlow", "Loading", "Offline", "ReaderBase", "ReaderTopArea",
        "ReaderControlSheet", "ReaderBottomBar", "ReaderDirectoryPanel", "ReaderAppearancePanel",
        "ReaderTtsPanel", "ReaderSettingsPanel", "ReaderFullDirectoryPage", "ReaderFullTtsPage",
        "ReaderFullAppearancePage", "ReaderFullSettingsPage", "ReaderBookCachePage",
        "ReaderDebugInfoPage", "ReaderSearchPanel", "ReaderReplacePanel", "ReaderAutoScrollPanel",
        "NightToast", "SourceSwitchFlowPage", "SourceImportPreviewPage", "SourceGroupsPage",
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
        "BackupSettingsPage", "RssSubscriptionManagementPage"
    ]

    private let expectedGenericRaw: Set<String> = [
        "BookshelfEmptyPage", "Button", "Content", "Dialog", "Empty", "ErrorState",
        "FormSection", "List", "ListRow", "Permission", "ReadingBackgroundLayer",
        "ReadingInfoLayer", "SourceSwitchResultsPanel", "Toast"
    ]

    private let expectedVisibleGapRaw: Set<String> = [
        "BookChapterList", "BookMoreMenuPage", "BookSummaryCard", "Error", "FloatingPageControl",
        "LocalBookImportPage", "MainTabsStructure", "PermissionRequiredPage",
        "RemoteWebDavBooksPage", "RestoreConfirmPage", "RestoreProgressPage", "RestoreResultPage",
        "TapZones"
    ]

    private let expectedExplicitGapRaw: Set<String> = [
        "SearchEntry", "SourceTypeSegment", "CurrentSourceCard", "SourceCategoryChips",
        "DiscoveryContentCard", "SourceStatusBar", "ShelfChipGroup", "RecentUpdateCard",
        "BookListItem", "ProgressBar", "SubscriptionSummaryCard", "FeedStatusChips",
        "FeedSourceChips", "RssEntryItem", "UnreadIndicator", "LocalOverviewCard", "QuickEntryGrid",
        "SettingsSection", "SettingsListItem", "SearchResultList", "AddToShelfButton", "ReadButton",
        "BookCover", "BookTitleAuthor", "SourceStatus", "DirectoryPreview", "BookIntro", "ConfigEntry",
        "Sheet", "Overlay", "Card", "Chip", "Toggle", "Slider", "Stepper", "Segment", "Dropdown",
        "Input", "FilterBar", "WebView", "FloatingBrightness", "FloatingQuickActions",
        "SourceSettingsEntryPage", "WebDavConfigPage", "SourceFormPage"
    ]

    func testCanonicalRegistryIntegrityAndExactMetrics() throws {
        let planner = try ReaderScreenGraphHostPlanner()

        XCTAssertEqual(planner.metrics.sha256, ReaderScreenGraphHostPlanner.expectedCanonicalSHA256)
        XCTAssertEqual(planner.metrics.sha256, ScreenGraphCanonicalAsset.sha256)
        XCTAssertEqual(planner.metrics.routeCount, 235)
        XCTAssertEqual(planner.metrics.directRouteCount, 159)
        XCTAssertEqual(planner.metrics.aliasRouteCount, 76)
        XCTAssertEqual(planner.metrics.variantCount, 165)
        XCTAssertEqual(planner.metrics.recursiveComponentCount, 519)
        XCTAssertEqual(planner.metrics.bindingCount, 36)
        XCTAssertEqual(planner.metrics.stateEventEvidenceCount, 19)
        XCTAssertEqual(planner.metrics.eventReferenceCount, 55)
        XCTAssertEqual(planner.metrics.referencedComponentTypeCount, 129)
        XCTAssertEqual(planner.metrics.explicitGapComponentTypeCount, 45)
        XCTAssertEqual(planner.metrics.actionGapCount, 6)
        XCTAssertEqual(planner.registry.document.routes.map(\.routeId), RouteId.allCases)
    }

    func testAll235RouteQueriesAnd76AliasesResolveToPlans() throws {
        let planner = try ReaderScreenGraphHostPlanner()
        XCTAssertEqual(RouteId.allCases.count, 235)

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

        XCTAssertEqual(componentCount, 519)
        XCTAssertEqual(bindingCount, 36)
        XCTAssertEqual(stateEventEvidenceCount, 19)
        XCTAssertEqual(bindingCount + stateEventEvidenceCount, 55)

        let bookshelf = try planner.plan(routeId: .bookshelf)
        XCTAssertNotNil(bookshelf.component(withId: "bookshelf-shelf-section"))
        XCTAssertNotNil(bookshelf.component(withId: "book-1"))
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
            expectedSupportedRaw.union(expectedGenericRaw).union(expectedVisibleGapRaw)
        )
        XCTAssertEqual(rawValues(coverage.canonicalExplicitGaps), expectedExplicitGapRaw)
        XCTAssertEqual(rawValues(coverage.faithfulReferenced), expectedSupportedRaw)
        XCTAssertEqual(rawValues(coverage.genericUsableReferenced), expectedGenericRaw)
        XCTAssertEqual(
            rawValues(coverage.supportedReferenced),
            expectedSupportedRaw.union(expectedGenericRaw)
        )
        XCTAssertEqual(rawValues(coverage.visibleReferencedGaps), expectedVisibleGapRaw)
        XCTAssertEqual(coverage.faithfulReferenced.count, 102)
        XCTAssertEqual(coverage.genericUsableReferenced.count, 14)
        XCTAssertEqual(coverage.supportedReferenced.count, 116)
        XCTAssertEqual(coverage.visibleReferencedGaps.count, 13)
        XCTAssertEqual(coverage.canonicalReferenced.count, 129)
        XCTAssertEqual(coverage.canonicalExplicitGaps.count, 45)
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
                "AddToShelfButton", "BookCover", "BookIntro", "BookListItem",
                "BookTitleAuthor", "DirectoryPreview", "ReadButton", "SourceStatus"
            ]
        )
    }

    func testOnly36TriggeredBindingsAreExecutableAnd19StateEventsStayReadOnly() throws {
        let planner = try ReaderScreenGraphHostPlanner()
        var bindingCount = 0
        var stateEvidenceCount = 0
        var executableGenericButtons = 0

        for route in planner.registry.document.routes where route.status == .direct {
            for variant in route.variants {
                let plan = try planner.plan(
                    routeId: route.routeId,
                    preferredVariantId: variant.variantId
                )
                for component in flatten(plan.components) {
                    bindingCount += component.bindings.count
                    stateEvidenceCount += component.stateEventEvidence.count
                    XCTAssertTrue(component.bindings.allSatisfy { $0.trigger == "tap" })
                    XCTAssertTrue(component.stateEventEvidence.allSatisfy {
                        $0.classification == "state-evidence"
                    })

                    let action = ReaderScreenGraphGenericActionResolver.action(
                        for: component.component
                    )
                    if component.component.type == .button, let binding = component.bindings.first {
                        let action = try XCTUnwrap(action, component.component.id ?? "button")
                        XCTAssertEqual(action.event, binding.event)
                        XCTAssertEqual(
                            try canonicalJSON(AnyCodable(action.payload)),
                            try canonicalJSON(AnyCodable(binding.payload))
                        )
                        executableGenericButtons += 1
                    } else {
                        XCTAssertNil(action, component.component.id ?? component.component.type.rawValue)
                    }

                    if !component.stateEventEvidence.isEmpty {
                        XCTAssertNil(action, "state evidence must never become a callback")
                    }
                }
            }
        }

        XCTAssertEqual(bindingCount, 36)
        XCTAssertEqual(stateEvidenceCount, 19)
        XCTAssertEqual(executableGenericButtons, 31)
    }

    func testGenericFamiliesExposeSemanticPropsRecursiveChildrenCallbackAndAccessibility() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()

        let listPlan = try planner.plan(routeId: .bookshelfListMode)
        let list = try XCTUnwrap(listPlan.component(withId: "book-list"))
        XCTAssertEqual(list.component.type, .list)
        XCTAssertEqual(list.children.map(\.component.type), [.listRow, .listRow])
        XCTAssertEqual(list.children.first?.component.props?.string("title"), "长夜余火")
        XCTAssertTrue(
            ReaderScreenGraphGenericAccessibility.identifier(for: list.component)
                .hasSuffix("List-book-list")
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
            ReaderScreenGraphGenericActionResolver.action(for: button.component)
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
        XCTAssertNil(ReaderScreenGraphGenericActionResolver.action(for: evidence.component))
    }

    func testUnknownRouteAndUnsupportedReferencedPrimitiveFailClosedVisibly() throws {
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
            reason: "missing-tap-zone-definitions"
        )
        XCTAssertEqual(failure.type, .tapZones)
        XCTAssertEqual(failure.componentId, "missing-tap-zones")
        XCTAssertEqual(failure.reason, "missing-tap-zone-definitions")
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
            XCTAssertEqual(source.bindings.count, target.bindings.count, routeId, file: file, line: line)
            XCTAssertEqual(
                source.stateEventEvidence.count,
                target.stateEventEvidence.count,
                routeId,
                file: file,
                line: line
            )
            XCTAssertEqual(source.children.count, target.children.count, routeId, file: file, line: line)
            assertSameTree(source.children, target.children, routeId: routeId, file: file, line: line)
        }
    }

    private func canonicalJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
}
