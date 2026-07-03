# iOS Demo Baseline And Route Mapping

Frozen at: 2026-07-02 11:00:37 +0800

Demo source: `/Users/minliny/Documents/Reader UI/frontend-demo`

iOS target: `/Users/minliny/Documents/Reader for iOS`

## Baseline Snapshot

| Item | Frozen value |
|---|---|
| Reader UI branch | `codex/motion-demo-optimizations` |
| Reader UI commit | `a596e2bbd75b564e1b21b14929c5c455e260044d` |
| Baseline cleanliness | Dirty baseline. Freeze includes current disk state plus the dirty-file list below. |
| Route source | `frontend-demo/route-contract.js` |
| Route count | 131 |
| Shell distribution | `MainTabShell=36`, `LibraryShell=51`, `SettingsShell=28`, `ReaderShell=15`, `FlowShell=1` |
| Deep closure groups | `discover=34`, `rss=45`, `settings=7` |
| Handoff readiness | `8/8` passed |
| Motion coverage from handoff gate | `29/29`; routes `131`; unresolved `0` |
| Motion evidence from handoff gate | entries `9`; missing `0`; fileProblems `0` |
| Syntax checks | `render-runtime.js`, `motion-controller.js`, `route-contract.js`, `render.js` passed `node --check` |
| Icon asset baseline | `92` tokens imported from `frontend-demo/asset-library/icons.js` into `ReaderIcons.xcassets` |

Dirty Reader UI files at freeze:

```text
 M README.md
 M docs/ui-handoff/README.md
 M frontend-demo/MOTION_IMPLEMENTATION_GAP_AUDIT.md
 M frontend-demo/README.md
 M frontend-demo/verify/motion/motion-coverage-report.json
?? artifacts/
?? docs/ui-handoff/FRONTEND_DEVELOPMENT_READINESS.md
?? docs/ui-handoff/FRONTEND_DEVELOPMENT_SLICE_MATRIX.md
?? docs/ui-handoff/UI_PLATFORM_EVIDENCE_REQUESTS.md
?? frontend-demo/.stitch/
?? frontend-demo/verify/handoff/
?? frontend-demo/verify/motion/evidence/reader-session-capsule-crop.jpg
```

Verification commands:

```bash
cd "/Users/minliny/Documents/Reader UI"
node frontend-demo/verify/handoff/verify-ui-handoff-readiness.mjs
node --check frontend-demo/render-runtime.js
node --check frontend-demo/motion-controller.js
node --check frontend-demo/route-contract.js
node --check frontend-demo/render.js
```

## Mapping Rules

- Demo route names are immutable input from `route-contract.js`.
- iOS navigation uses `Route`, `AppTab`, and `AppNavigationState`.
- Main Tab routes must map to `AppTab`, not to a pushed `Route`.
- Secondary routes map to `NavigationStack(path:)` destinations or explicit feature state.
- Reader entry uses `ReaderContext`, not a tab.
- CSS tokens map to `ReaderDesignTokens`; Web selectors do not cross the platform boundary.
- Motion contracts map to `AppMotion`, `ReaderMotion`, `MotionEnvironment`, SwiftUI transitions, and reduced-motion behavior.
- Demo icon tokens map to `ReaderAssetIcon`, `ReaderIcon`, `ReaderIcons.xcassets`, and `AppTab.assetIcon`; SF Symbols stay only as compatibility fallback where a route has not been migrated.
- Every slice must name the current automated acceptance command, or explicitly mark the acceptance as planned when the platform surface is not implemented yet.

## Core Type Mapping

| Demo artifact | iOS artifact | Scope |
|---|---|---|
| `route-contract.js.routes` | `Route` + `AppTab` | route names, shell ownership, main-tab boundaries |
| `deepRouteClosure.discover` | `DiscoverHomeShellView(demoRoute:)` + `DiscoverDemoState` + `DemoBackScreen` + `DiscoverSourceLoginView` + `SettingsDemoShellView(demoRoute:)` for rule/bulk source states | discover source, entry, filter, sort, loading/error/cache/login-return/login/rule/bulk source states |
| `deepRouteClosure.rss` | `RSSFeedView`, `RSSFeedView(demoRoute:)`, `RSSDemoRouteState`, `RSSFeedViewModel`, `RSSArticleDetailView`, `RSSOriginalPreviewView`, `RSSOriginalBrowserConfirmView`, `RSSSubscriptionManagementView`, `RSSSourceActionsView`, `RSSSourceEditView`, `RSSSourceDebugView`, `RSSSourceVarsView`, `RSSSourceLoginView`, `RSSSourceImportView`, `RSSSourceExportView`, `RSSSourceGroupsView`, `RSSSearchView`, `RSSReadRecordView`, `RSSRuleSubscriptionView`, `RSSFavoriteGroupsView`, `RSSStateView` | subscriptions, feed mode/source/category/refresh states, detail reader, original preview/browser handoff, source-management, search, record, rule subscription, favorite group, empty/error flows |
| `deepRouteClosure.settings` | `SettingsTabView` + `SettingsDemoShellView(demoRoute:)` + `SettingsDemoRouteState` | settings, sync, restore, WebDAV, source-management, source import/batch/group/detail/detect/edit/debug/log/code/delete feature states |
| `tokens.css`, `styles/*.css` | `ReaderDesignTokens` | dimensions, typography, color roles, radius, spacing |
| `motion-tokens.css`, `MOTION_CONTRACT.md` | `AppMotion`, `ReaderMotion`, `MotionEnvironment` | animation durations, distances, reduced-motion |
| `asset-library/icons.js` | `ReaderAssetIcon`, `ReaderIcon`, `ReaderIcons.xcassets`, `AppTab.assetIcon` | semantic icon tokens, template rendering, tab/module icon ownership |
| `asset-library/icons/*.png`, `asset-library/icons/*.svg` | `docs/ui-handoff/ios/demo-icon-library`, `scripts/import_demo_icon_assets.mjs` | provenance snapshot and repeatable iOS asset generation |

## Cross-Cutting Implementation Bridges

| Contract area | Demo source | iOS implementation | Current verification |
|---|---|---|---|
| Route ownership | `route-contract.js` | `Route`, `AppTab`, `AppNavigationState`, `DemoRouteMappings`, per-tab `NavigationStack` paths; all 131 routes have explicit AppTab/native/feature-state ownership | `DemoRouteMappingTests`; `AppShellAlignmentTests`; `scripts/verify_demo_slice_mapping.mjs` |
| Main tab icons | `asset-library/icons.js` tokens `bookshelf/discover/rss/settings` | `AppTab.assetIcon`, `ReaderIcon`, `ReaderIcons.xcassets` | `ReaderIconAssetAlignmentTests` |
| CSS dimensions and color roles | `styles/*.css`, `tokens.css` | `ReaderDesignTokens` | `MotionTokenAlignmentTests`; component-specific tests as each slice lands |
| Motion tokens and IDs | `MOTION_CONTRACT.md`, `motion-tokens.css`, `motion-controller.js` | `AppMotion`, `ReaderMotion`, `MotionEnvironment`, SwiftUI transitions | `MotionTokenAlignmentTests`; simulator smoke for interactive surfaces |
| Reduced motion | `MOTION_CONTRACT.md` reduced-motion rules | `MotionEnvironment.duration/animation/distance` | `MotionTokenAlignmentTests` |
| Icon provenance | `asset-library/README.md`, `ASSET_LIBRARY.md`, `icons.js` | `docs/ui-handoff/ios/demo-icon-library`, generated asset catalog | `node scripts/import_demo_icon_assets.mjs`; `.imageset` count `92` |

## Slice Mapping

### Slice 0 - Demo Baseline Freeze

| Field | Mapping |
|---|---|
| demo route | all 131 routes in `route-contract.js` |
| platform page/View | no production View; this is the frozen contract input |
| state model | route dictionary + shell metadata + handoff readiness result |
| navigation entry | none |
| motion IDs | all IDs resolved by `verify-motion-coverage.mjs` via handoff gate |
| acceptance tests | handoff readiness `8/8`; `node --check` for runtime, motion controller, route contract, render entry; `node scripts/verify_demo_slice_mapping.mjs`; icon import count `92` |

### Slice 1 - App Shell And Primary Tabs

| Field | Mapping |
|---|---|
| demo route | `bookshelf`, `discover`, `rss`, `settings` |
| platform page/View | `AppShellView`, `FloatingTabBar`, `ReaderIcon`, `BookshelfView`, `BookshelfItemDetailView`, `BookmarksListView`, `BookmarkRowView`, `DiscoverHomeShellView`, `RSSFeedView`, `SettingsTabView` |
| state model | `AppTab.contractOrder`, `AppTab.assetIcon`, `AppNavigationState.activeTab`, per-tab `NavigationStack` paths in `AppShellView`, `BookshelfView` root `DemoTopBar` + `DemoPaperScreen` with `ContinueReadingCard`, `BookshelfItemDetailView`, `BookmarksListView`, `BookmarkRowView`, `DiscoverHomeShellView` root `DemoTopBar` refresh feature state, `RSSFeedView` root `RSSRootTopBar` refresh/manage app top-bar surface, `SettingsTabView` root `DemoTopBar` + `DemoPaperScreen` + `SettingsTabView.demoRootRoutes` 5-entry Settings root |
| navigation entry | `TabView(selection:)`; selected state writes through `AppNavigationState.switchTab(_:)`; bookshelf item detail and bookmark sheets use demo back bar/paper/card rows instead of system `List` |
| motion IDs | `tab.item.press`, `tab.item.select`, `tab.item.switch`, `app.tab.switch`, `motion.interrupt.cancel` |
| acceptance tests | `ReaderAppTests/DemoRouteMappingTests`; `ReaderAppTests/AppShellAlignmentTests`; `ReaderAppTests/BookshelfHTMLCSSStructureAlignmentTests`; `ReaderAppTests/DemoComponentPrimitiveAlignmentTests`; `ReaderAppTests/ReaderIconAssetAlignmentTests`; `ReaderAppTests/MotionTokenAlignmentTests`; iOS Simulator build |

### Slice 2 - Bookshelf, Search, Book Detail

| Field | Mapping |
|---|---|
| demo route | `bookshelf`, `bookshelf-empty`, `sort-filter`, `book-search`, `book-detail`, `book-directory`, `book-batch-management`, `group-management`, `local-import` |
| platform page/View | `BookshelfView`, `DemoTopBar`, `DemoBackScreen`, `ContinueReadingCard`, `BookshelfBookCoverCard`, `BookshelfBookListCard`, `BookshelfBookFocusLayer`, `BookshelfMoreLayer`, `BookshelfItemDetailView`, `BookmarksListView`, `BookmarkRowView`, `BookshelfBatchManagementView`, `BookshelfGroupManagementView`, `BookshelfLocalImportView`, legacy `FileImportView` compatibility wrapper, `SearchView`, `SearchHistoryRow`, `SearchResultDemoRow`, legacy `SearchResultRowView` compatibility row, `BookDetailView`, `BookDetailCoverView`, `BookDetailPreviewChapterRow`, `BookDirectoryPreviewView`, legacy `BookshelfItemRowView` compatibility row |
| state model | `BookshelfViewModel`, `BookshelfState`, `BookshelfItem`, `BookmarksListView(bookId:sourceId:bookTitle:)`, `BookmarkRowView`, `Route.search`, `Route.searchResults(query:)`, `Route.bookDetail`, `Route.bookDetailToc`, `Route.bookBatchManagement`, `Route.bookshelfGroups`, `Route.bookshelfImport`, `SearchViewModel`, `SearchView(initialQuery:)`, `SearchScope`, `BookBatchItem`, `BookshelfGroupItem`, `FileImportViewModel`, `BookDetailViewModel`, `BookDetailPreviewChapter`, `BookDirectoryChapter`, bookshelf secondary route back-bar ownership |
| navigation entry | bookshelf tab root; bookshelf item detail and bookmark sheets use demo back bar/paper/card rows instead of system `List`; bookmark rows open `ReaderView` or delete inline; search toolbar action; legacy `Route.searchResults(query:)` value route opens `SearchView(initialQuery:)`; legacy `SearchResultRowView` and `BookshelfItemRowView` remain compile-compatible but now render with demo `ReaderCard` / `ReaderIcon` row primitives instead of SF Symbol/system backgrounds; row/cover detail push; book detail directory entry pushes full directory; more/focus menu pushes batch management or group management; batch move action pushes group management; toolbar/more menu pushes local import through `BookshelfLocalImportView`; legacy `FileImportView` forwards to the same demo import surface; bookshelf secondary routes use `DemoBackScreen` and hide the system navigation bar |
| motion IDs | `reader.entry.coverToImmersive`, `reader.entry.actionToImmersive`, `card.route`, `button.press/activate`, `dropdown.menu.expand/collapse/select`, `chip.item.press/select`, `state.content.replace` |
| acceptance tests | `DemoRouteMappingTests`; `BookshelfHTMLCSSStructureAlignmentTests`; `AppShellAlignmentTests`; `DemoComponentPrimitiveAlignmentTests`; `DemoRouteFamilySimulatorSmokeTests/testBookshelfRouteFamilyRendersDemoSurfacesOnSimulator` covers cover-to-reader entry surface, search, book detail, directory, batch management, group management, and local import on iOS Simulator |

### Slice 3 - Immersive Reader And Reader Control Layer

| Field | Mapping |
|---|---|
| demo route | `immersive-reading`, `reader`, `toc-bookmarks`, `reader-appearance`, `tts`, `reader-settings`, `reader-full-directory`, `reader-full-tts`, `reader-full-appearance`, `reader-full-settings`, `reader-book-cache`, `reader-debug-info`, `auto-page`, `content-search`, `content-replacement`, `source-switch` |
| platform page/View | `ReaderView`, `TOCView`, `TOCChapterDemoRow`, `ContentView`, `ReaderContentSectionView`, `ChapterListView`, `ChapterRowView`, `ReaderResponsiveLayout`, `ReaderResponsiveVisualAudit`, `ReaderReadingLayer`, `ReaderStateCard`, `ReaderStateBanner`, `PaginatedReaderView`, `ReaderProgressSurfaceView(style:)`, `ReaderStageActionBar`, `ReaderIcon`, `ReaderSettingsPanel`, `ReaderTTSControlView`, `ReaderDemoShellView(demoRoute:)`, `ReaderDemoSessionCapsule`, reader route/demo compact/full/utility panels with hidden system navigation chrome, `DemoBackScreen`, `ReaderSourceSwitchFlowView` |
| state model | `ReaderViewModel`, `ReadingFlowCoordinator`, `ChapterListViewModel`, `ChapterNavigation`, `ReaderContext`, `ReaderSession`, `OverlayState`, `MotionInterrupt`, `ReaderDisplaySettings`, `ReaderResponsiveLayout`, `ReaderResponsiveVisualAudit`, `ReaderViewportClass`, `AppShellView.readerRoutePayload(for:)`, `AppShellView.readerContextFallbackRoute(for:)`, `ReaderInlineDestination`, `ReaderHotZoneSegment`, `ReaderControlModule`, `ReaderControlSession`, `TOCView`, `ContentView`, `ReaderStateCard`, `ReaderStateBanner`, `ReaderAppearanceQuickAction`, `ReaderSettingsQuickAction`, `ReaderDemoRouteState`, `ReaderDemoPresentation`, `ReaderDemoModule`, `ReaderDemoModule.compactRoute/fullRoute`, `ReaderDemoSession`, reader-owned chrome state, live chapter content paragraph/non-content state, contextful TOC/content value-route state, standalone chapter-list state, FlowShell source-switch `DemoBackScreen` ownership, `SourceSwitchCandidate` selection state |
| navigation entry | `BookshelfView.enterImmersive(...)` sets `ReaderContext`; `NavigationDestination` pushes `ReaderView`; legacy `Route.reader(bookID:chapterURL:chapterTitle:)` value routes now resolve through `AppShellView.readerRoutePayload(for:)` and push `ReaderView` instead of default placeholder text; `ReaderView` hides system navigation chrome and uses reader-owned `ReaderProgressSurfaceView` / control layer for back, source, more, TTS, settings, and directory entry points; Reader empty/failed/unsupported/partial content states render through demo card/banner primitives instead of system labels or SF Symbols; `ReaderView` TTS module buttons update `ReaderControlSession` and the running capsule; hotzone prev/next trigger paginated page turns while center toggles chrome; control sheet previous/next buttons call chapter navigation; appearance quick controls update `ReaderDisplaySettings` typography, theme, and page mode; settings quick controls update tap zones, volume-key page turns, dual-page mode, and brightness override; legacy `Route.toc(...)` / `Route.content(...)` keep real `TOCView` / `ContentView` when coordinator context exists, but those views now use `DemoBackScreen` + paper/card rows instead of system navigation titles and old empty/error views; standalone `ChapterListView` keeps its hidden `NavigationStack(path:)` for `ReaderView` push payloads, while visible chrome now uses `DemoBackScreen`, `ReaderCard`, `ReaderStateCard` / `ReaderStateBanner`, and tokenized chapter rows instead of system `List` / navigation title / SF Symbol states; contextless `Route.toc` / `Route.content` still fall back to `ReaderDemoShellView(demoRoute:)` instead of plain unavailable text; center hot zone toggles chrome; reader top source action pushes `DemoBackScreen` + `ReaderSourceSwitchFlowView`; reader control sheet directory/TTS/appearance/settings modules open `ReaderDemoShellView(demoRoute:)` for `reader-full-directory`, `reader-full-tts`, `reader-full-appearance`, and `reader-full-settings`; width/height-derived reader layouts keep phone controls bottom-bound and move expanded/tablet/compact reader controls into the right dock; 13 ReaderShell demo control routes render through `ReaderDemoShellView(demoRoute:)` as inline reader feature states, compact module nav switches `toc-bookmarks` / `tts` / `reader-appearance` / `reader-settings` locally with `reader.module.switch` semantics, compact headers expand to matching `reader-full-*` routes, full panels collapse back to compact routes, TTS/auto-page buttons update local `ReaderDemoSession` and running capsule, appearance/settings controls update local `ReaderDisplaySettings`, hide system navigation chrome, and do not become tabs; `source-switch` pushes as a FlowShell reader continuation, not a main tab |
| motion IDs | `reader.entry.coverToImmersive`, `reader.entry.actionToImmersive`, `reader.control.show`, `reader.control.hide`, `reader.page.turn.prev`, `reader.page.turn.next`, `reader.chapter.jump`, `reader.control.handle.press/drag/release`, `reader.control.dock.longPress/drag/release/rebound`, `reader.module.switch`, `reader.session.autoPage.start`, `reader.session.tts.start`, `reader.session.capsule.enter/update/switch/exit`, `reader.sourceSwitch.open/close`, `overlay.sheet.enter/exit` |
| acceptance tests | `DemoRouteMappingTests`; `DemoComponentPrimitiveAlignmentTests`; `AppShellAlignmentTests`; `SingleSourceTOCM2Tests`; `MotionTokenAlignmentTests`; `ReaderIconAssetAlignmentTests`; `DemoRouteFamilySimulatorSmokeTests/testReaderRouteFamilyRendersResponsiveDemoSurfacesOnSimulator` covers reader entry, all ReaderShell demo feature states, tablet right dock, compact-landscape top surface, static non-overlap geometry, and paginated typography surface |

### Slice 4 - Discover

| Field | Mapping |
|---|---|
| demo route | `discover`, `discover-control`, `discover-sort`, `discover-entry-ranking`, `discover-entry-bestseller`, `discover-entry-category`, `discover-entry-finished`, `discover-entry-latest`, `discover-entry-new`, `discover-entry-booklist`, `discover-filter-keyword`, `discover-filter-male`, `discover-filter-female`, `discover-sort-popularity`, `discover-sort-update`, `discover-sort-collection`, `discover-sort-finished`, `discover-sort-words`, `discover-no-results`, `discover-loading`, `discover-refreshing`, `discover-infinite-loading`, `discover-page-two`, `discover-cache-confirm`, `discover-cache-toast`, `discover-login-return`, `discover-switching-source`, `discover-switched-source`, `discover-entry-error`, `discover-empty`, `discover-error`, `discover-source-login`, `discover-rule-test`, `discover-source-bulk` |
| platform page/View | `DiscoverHomeShellView(demoRoute:)`, `DiscoverDemoState`, `DiscoverSourceBar`, `DiscoverEntryRow`, `DiscoverFilterRow`, `DiscoverControlPanel`, `DiscoverBookList`, `DiscoverLargeStateCard`, `DiscoverSkeletonList`, `DemoBackScreen`, `DiscoverSourceLoginView`, `SettingsDemoShellView(demoRoute:)` for `discover-rule-test` / `discover-source-bulk` |
| state model | `DiscoverDemoState(route:selectedEntry:selectedFilter:selectedSort:isControlPanelExpanded:)`, `DiscoverPresentation`, source/entry/filter/sort/loading/error/cache/login-return feature-state fields, `discover-source-login` `DemoBackScreen` ownership and cookie-save state, `SettingsDemoRouteState` for rule-test/bulk source states; host-backed `DiscoverUIState` for live source data remains separate |
| navigation entry | discover tab root feature-state transition; 30 MainTabShell discover routes render inside `DiscoverHomeShellView(demoRoute:)` and are not pushed `Route`s; `discover-source-login` renders as `DemoBackScreen` + `DiscoverSourceLoginView` LibraryShell feature-state subpage and hides the system navigation bar; `discover-rule-test` and `discover-source-bulk` render as SettingsShell feature-state subpages |
| motion IDs | `tab.item.switch`, `chip.item.press/select`, `dropdown.menu.expand/collapse/select`, `input.focus`, `state.content.replace`, `feedback.toast.show/hide`, `overlay.dialog.enter/exit`, `button.press/activate` |
| acceptance tests | `DemoRouteMappingTests`; `DemoComponentPrimitiveAlignmentTests`; `AppShellAlignmentTests`; `DemoRouteFamilySimulatorSmokeTests/testDiscoverRouteFamilyRendersAllDemoFeatureStatesOnSimulator` covers source/filter/sort feature states plus secondary login, rule-test, and bulk-source flows on iOS Simulator |

### Slice 5 - RSS

| Field | Mapping |
|---|---|
| demo route | `rss`, `rss-all`, `rss-starred`, `rss-source-feed`, `rss-source-category-releases`, `rss-source-category-issues`, `rss-source-category-discussions`, `rss-refreshing`, `rss-search`, `rss-detail`, `rss-original`, `rss-original-browser`, `rss-subscription-management`, `rss-source-actions`, `rss-source-edit`, `rss-source-debug`, `rss-source-vars`, `rss-source-login`, `rss-source-login-web`, `rss-source-login-cookie`, `rss-source-login-clear`, `rss-source-groups`, `rss-source-group-edit`, `rss-source-batch`, `rss-source-export`, `rss-source-export-detail`, `rss-source-export-result`, `rss-source-pin`, `rss-source-disable`, `rss-source-batch-disable`, `rss-source-import`, `rss-source-import-detail`, `rss-source-import-result`, `rss-read-record`, `rss-record-clear`, `rss-rule-subscription`, `rss-rule-subscription-detail`, `rss-rule-subscription-edit`, `rss-rule-subscription-test`, `rss-rule-subscription-apply`, `rss-favorite-groups`, `rss-favorite-group-edit`, `rss-favorite-clear`, `rss-empty`, `rss-error` |
| platform page/View | `RSSFeedView`, `RSSRootTopBar`, `DemoBackScreen`, `RSSFeedView(demoRoute:)`, `RSSDemoRouteState`, `RSSSummaryCard`, `RSSModeRow`, `RSSSourceStrip`, RSS demo source/mode/category/refresh components, `RSSArticleDetailView`, `RSSOriginalPreviewView`, `RSSOriginalBrowserConfirmView`, `RSSSubscriptionManagementView`, `RSSSourceActionsView`, `RSSSourceEditView`, `RSSSourceDebugView`, `RSSSourceVarsView`, `RSSSourceLoginView`, `RSSSourceLoginWebView`, `RSSSourceLoginCookieView`, `RSSSourceLoginClearView`, `RSSSourceGroupsView`, `RSSSourceGroupEditView`, `RSSSourceBatchView`, `RSSSourceExportView`, `RSSSourceExportDetailView`, `RSSSourceExportResultView`, `RSSSourceImportView`, `RSSSourceImportDetailView`, `RSSSourceImportResultView`, `RSSSourcePinConfirmView`, `RSSSourceDisableConfirmView`, `RSSSourceBatchDisableConfirmView`, `RSSSearchView`, `RSSReadRecordView`, `RSSRecordClearConfirmView`, `RSSRuleSubscriptionView`, `RSSRuleSubscriptionDetailView`, `RSSRuleSubscriptionEditView`, `RSSRuleSubscriptionTestView`, `RSSRuleSubscriptionApplyConfirmView`, `RSSFavoriteGroupsView`, `RSSFavoriteGroupEditView`, `RSSFavoriteClearConfirmView`, `RSSStateView` |
| state model | `RSSDemoRouteState`, `RSSFeedViewModel`, `CoreRSSFeedSummary`, `SubscriptionItem`, `RSSManagementSource`, RSS native secondary `DemoBackScreen` ownership, `Route.rssDetail(rssID:)`, `Route.rssOriginal(url:title:sourceTitle:)`, `Route.rssOriginalBrowser(url:title:sourceTitle:)`, `Route.rssSubscriptions`, `Route.rssSourceActions(sourceID:title:)`, `Route.rssSourceEdit(sourceID:title:)`, `Route.rssSourceDebug(sourceID:title:)`, `Route.rssSourceVars(sourceID:title:)`, `Route.rssSourceLogin(sourceID:title:)`, `Route.rssSourceLoginWeb(sourceID:title:)`, `Route.rssSourceLoginCookie(sourceID:title:)`, `Route.rssSourceLoginClear(sourceID:title:)`, `Route.rssSourceGroups`, `Route.rssSourceGroupEdit(groupID:title:)`, `Route.rssSourceBatch`, `Route.rssSourceExport`, `Route.rssSourceExportDetail(sourceID:title:)`, `Route.rssSourceExportResult`, `Route.rssSourcePin(sourceID:title:)`, `Route.rssSourceDisable(sourceID:title:)`, `Route.rssSourceBatchDisable`, `Route.rssSourceImport`, `Route.rssSourceImportDetail(sourceID:title:)`, `Route.rssSourceImportResult`, `Route.rssSearch`, `Route.rssReadRecord(sourceID:title:)`, `Route.rssRecordClear`, `Route.rssRuleSubscription`, `Route.rssRuleSubscriptionDetail(subscriptionID:title:)`, `Route.rssRuleSubscriptionEdit(subscriptionID:title:)`, `Route.rssRuleSubscriptionTest(subscriptionID:title:)`, `Route.rssRuleSubscriptionApply`, `Route.rssFavoriteGroups`, `Route.rssFavoriteGroupEdit(groupID:title:)`, `Route.rssFavoriteClear`, `Route.rssEmpty`, `Route.rssError`; live host-backed dynamic RSS refresh remains separate from demo static state |
| navigation entry | rss tab root owns `RSSRootTopBar`; root refresh performs live refresh or demo `rss-refreshing` feature-state replacement, root manage/search push `RSSSubscriptionManagementView` / `RSSSearchView`; `rss-all`, `rss-starred`, `rss-source-feed`, `rss-source-category-*`, and `rss-refreshing` render through `RSSFeedView(demoRoute:)` LibraryShell feature states; RSS native secondary routes use `DemoBackScreen` and hide the system navigation bar; article rows push `RSSArticleDetailView`; detail original actions push `RSSOriginalPreviewView`; original browser action pushes `RSSOriginalBrowserConfirmView` before system `openURL`; reader source settings push `RSSSubscriptionManagementView`; source more action pushes `RSSSourceActionsView`; source edit/debug/record/vars/login actions push `RSSSourceEditView` / `RSSSourceDebugView` / `RSSReadRecordView` / `RSSSourceVarsView` / `RSSSourceLoginView`; login sub-actions push web/cookie/clear/debug routes; subscription-management rule/import/group/batch/export/disable actions push native management routes; rule subscription actions push detail/edit/test/apply routes; favorite and RSS state routes have global fallbacks; source-action pin/disable actions push confirm routes; global RSS detail/original/browser/subscription/source/search/record/rule/favorite/state routes have fallbacks |
| motion IDs | `tab.item.switch`, `chip.item.press/select`, `input.focus`, `state.content.replace`, `button.press/activate`, `overlay.sheet.enter/exit`, `overlay.dialog.enter/exit`, `feedback.toast.show/hide` |
| acceptance tests | `DemoRouteMappingTests`; `DemoComponentPrimitiveAlignmentTests`; `AppShellAlignmentTests`; `RSSCoreIntegrationTests`; `DemoRouteFamilySimulatorSmokeTests/testRSSRouteFamilyRendersListDetailManagementAndStateSurfacesOnSimulator` covers refresh/list modes, search, detail, original preview/browser confirmation, subscription management, source actions, empty, and error states on iOS Simulator |

### Slice 6 - Settings, Sync, WebDAV, Source Management

| Field | Mapping |
|---|---|
| demo route | `settings`, `settings-general`, `bookshelf-search-settings`, `about-feedback`, `sync-backup`, `webdav-config`, `restore-confirm`, `restore-progress`, `restore-conflict`, `restore-result`, `source-management`, `source-import-options`, `source-import-preview`, `source-batch`, `source-groups`, `source-detail`, `source-detect`, `source-rule-edit`, `source-debug`, `source-debug-search-result`, `source-debug-detail-result`, `source-debug-catalog-result`, `source-debug-content-log`, `source-edit-debug`, `source-logs`, `source-code-view`, `source-delete-confirm` |
| platform page/View | `SettingsTabView`, `SettingsRootEntryRow`, `DemoBackScreen`, `SettingsDemoShellView(demoRoute:)`, settings/source/restore demo rows, chips, metrics, source list, debug result, code view, delete-confirm dialog; old settings/source/sync `Route` fallbacks without live screens reuse Settings demo feature states; `.bookSources` / `.bookSourceImport` live routes use `BookSourceListView`, `BookSourceRowView`, `BookSourceImportView`, and `BookSourceDetailSheet` with demo paper/card/state/icon primitives; legacy `BookSourceDetailView` forwards to `BookSourceDetailSheet`; `.webdavSettings` live route uses `WebDAVSettingsView` with demo paper/card/input/action/result primitives; legacy `MineTabView` compatibility surface uses `DemoTopBar`, `DemoPaperScreen`, `ReaderCard`, `DemoIconRow`, `ReaderIcon`, and a tokenized settings switch row; debug-only `M6BookSourceImportVerificationView`, `RealNetworkVerifyView`, `NativeCoreEvidenceView`, and `NativeCoreEvidenceAutorunView` use `DemoBackScreen` / `DemoPaperScreen`, `ReaderStateBanner` / `ReaderStateCard`, `ReaderCard`, `DemoIconRow`, and tokenized action buttons |
| state model | `SettingsTabView.demoRootRoutes`, SettingsShell feature-state `DemoBackScreen` ownership, `SettingsDemoRouteState`, `SettingsDemoSection`, `SettingsDemoRow`, `SettingsDemoSourceRow`, `SettingsDemoAction`, `AppShellView.settingsDemoFallbackRoute(for:)`; source import/list state remains native live state via `BookSourceStore`, `BookSourceViewModel`, and `BookSourceImportValidator`; WebDAV live state remains native via `WebDAVSettingsViewModel` credentials/configuration/export/restore/progress-sync properties |
| navigation entry | settings tab root shows exactly 5 demo entries: `settings-general`, `bookshelf-search-settings`, `source-management`, `sync-backup`, `about-feedback`; all 28 SettingsShell demo routes render as `DemoBackScreen` + `SettingsDemoShellView(demoRoute:)` feature states under settings/source stack and hide the system navigation bar; legacy `settingsReading/settingsAbout/backupSettings/syncProgress/webdavBooks/sourceDetail/sourceAdd/sourceEdit/sourceTestResult` value routes now push the corresponding Settings demo feature state instead of default placeholder text; live `.bookSources`, `.bookSourceImport`, and `.webdavSettings` route destinations keep their native data flow but no longer use system `NavigationStack` / `List` / `Form` chrome internally; `MineTabView` keeps only a hidden local `NavigationStack` for direct compatibility/debug destinations and removes visible system `List` / `Section` / `Label` / navigation title chrome; its M6 import verification, real-network verification, and native-core evidence destinations remove visible system `List` / `Section` / `Label` / SF Symbol / navigation title chrome while keeping the same debug-only verification actions |
| motion IDs | `tab.item.switch`, `toggle.switch`, `input.focus`, `chip.item.press/select`, `dropdown.menu.expand/collapse/select`, `overlay.keyboard.enter/exit`, `overlay.sheet.enter/exit`, `overlay.dialog.enter/exit`, `feedback.toast.show/hide`, `state.content.replace` |
| acceptance tests | `DemoRouteMappingTests`; `DemoComponentPrimitiveAlignmentTests`; `AppShellAlignmentTests`; `WebDAVBackupIntegrationTests`; `DemoRouteFamilySimulatorSmokeTests/testSettingsBackupImportAndSharedStateFamiliesRenderOnSimulator` covers SettingsShell routes, live WebDAV surface, source management, source import, restore states, and shared fallback states on iOS Simulator |

### Slice 7 - Cross-Route State And Error Pages

| Field | Mapping |
|---|---|
| demo route | state routes folded into each domain: `discover-empty/error/loading`, `rss-empty/error`, restore conflict/result, source delete confirm, plus iOS `Route.stateError/stateOffline/statePermission` |
| platform page/View | domain state views plus shared `StateSurfaceView`, `ConfirmDialog`, `ToastSurface`, `PermissionStateView` for iOS fallback state routes; legacy `ErrorView` and `ReaderEmptyStateView` now wrap `ReaderStateCard` / demo icon primitives |
| state model | domain-specific error/loading state plus `OverlayState`, `StateSurfaceKind`, toast copy state, and `Route.stateError/stateOffline/statePermission` fallback payloads |
| navigation entry | not independent main tab; domain state routes render inside current shell, while iOS fallback state routes render through `DemoBackScreen` + `StateSurfaceView` / `PermissionStateView` and hide the system navigation bar |
| motion IDs | `state.content.replace`, `feedback.toast.show/hide`, `overlay.dialog.enter/exit`, `motion.async.resultGuard` |
| acceptance tests | `AppShellAlignmentTests`; `DemoComponentPrimitiveAlignmentTests`; `DemoRouteFamilySimulatorSmokeTests/testAsyncResultGuardKeepsLatestReaderContext`; `DemoRouteFamilySimulatorSmokeTests/testSettingsBackupImportAndSharedStateFamiliesRenderOnSimulator` covers async result guard plus failed/offline/permission states on iOS Simulator |

## Route Coverage Status

| Category | Demo route count | iOS status |
|---|---:|---|
| MainTabShell | 36 | Root tabs covered; 30 Discover feature-state routes render through `DiscoverHomeShellView(demoRoute:)`; iPad left rail/content shift covered by `DemoRouteFamilySimulatorSmokeTests/testAppShellTabletRailAndContentShiftMatchDemoContract` |
| LibraryShell | 51 | All LibraryShell demo routes now have concrete native or feature-state ownership; search/book detail/book batch/RSS list-mode/source/category/refresh/detail/original/browser-confirmation/subscription-management/source-actions/source-edit/source-debug/source-vars/source-login/source-import/source-export/source-groups/search/record/rule/favorite/state primitives are covered; bookshelf and RSS native secondary routes use demo back-bar chrome; route-family simulator smoke covers the representative native surface set |
| SettingsShell | 28 | All SettingsShell demo routes now render through `DemoBackScreen` + `SettingsDemoShellView(demoRoute:)` feature states for settings/general/search/about/sync/WebDAV/restore/source import/batch/group/detail/detect/edit/debug/log/code/delete-confirm; legacy Settings/source/sync value-route fallbacks also land on the same demo feature states; live WebDAV/source-management/source-import UI surfaces are covered by simulator smoke |
| ReaderShell | 15 | Immersive route, reader route via `AppShellView.readerRoutePayload(for:)`, scroll and paginated reading layer/top surface, phone/expanded/tablet/compact reader responsive layout, static `ReaderResponsiveVisualAudit` for top/dock geometry, compact-landscape top progress surface, and 13 route-derived `ReaderDemoShellView(demoRoute:)` control/full/utility feature states with hidden system navigation chrome covered; route-family simulator smoke covers phone reader, tablet right dock, compact-landscape top surface, and geometry non-overlap |
| FlowShell | 1 | `source-switch` now renders through `DemoBackScreen` + `ReaderSourceSwitchFlowView` with reading-continuity, candidate-source, and confirmation slots; live adapter binding is outside the demo UI contract and remains owned by platform integration tests |

## Acceptance Ladder For Each Future Slice

1. Demo contract check: route exists in `route-contract.js` and belongs to expected shell/group.
2. iOS mapping check: route has one of `AppTab`, `Route`, or explicit feature-state mapping.
3. Token check: component dimensions and typography come from `ReaderDesignTokens`, not literal drift.
4. Icon check: demo-owned icon tokens come from `ReaderAssetIcon` / `ReaderIcons.xcassets`, not ad hoc redraws.
5. Motion check: Motion IDs are mapped to `AppMotion`/`ReaderMotion` and reduced-motion behavior.
6. Build check: `xcodebuild -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'generic/platform=iOS Simulator' build ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`.
7. Focused tests: route/state/token/icon tests for the slice.
8. Simulator proof: target page reachable, no layout overlap, no unexpected route/tab ownership.

## Current iOS Verification

```bash
node --check scripts/verify_demo_slice_mapping.mjs
node scripts/verify_demo_slice_mapping.mjs
xcodegen generate
xcodebuild test -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:ReaderAppTests/DemoRouteMappingTests -only-testing:ReaderAppTests/AppShellAlignmentTests -only-testing:ReaderAppTests/ReaderIconAssetAlignmentTests -only-testing:ReaderAppTests/MotionTokenAlignmentTests -only-testing:ReaderAppTests/BookshelfHTMLCSSStructureAlignmentTests -only-testing:ReaderAppTests/DemoComponentPrimitiveAlignmentTests
xcodebuild test -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:ReaderAppTests/DemoRouteFamilySimulatorSmokeTests
git diff --check
```

Latest focused result: selected tests passed, including `DemoRouteMappingTests`, `AppShellAlignmentTests`, `ReaderIconAssetAlignmentTests`, `MotionTokenAlignmentTests`, `BookshelfHTMLCSSStructureAlignmentTests`, `DemoComponentPrimitiveAlignmentTests`, and `DemoRouteFamilySimulatorSmokeTests`. `scripts/verify_demo_slice_mapping.mjs` now cross-checks all 131 high-priority / Swift-owned routes against Reader UI `route-contract.js`. `DemoRouteFamilySimulatorSmokeTests` executed 7 simulator-render tests with 0 failures and stored XCTAttachment screenshots in `/Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Logs/Test/Test-ReaderForIOSApp-2026.07.03_09-59-43-+0800.xcresult`.

## Closure Status - 2026-07-03

- Route ownership gap: closed (`131` high-priority demo routes present and Swift-owned).
- Planned simulator smoke gap: closed by `DemoRouteFamilySimulatorSmokeTests`.
- Reader right-dock / compact top / paginated typography proof gap: closed by simulator rendering plus `ReaderResponsiveVisualAudit`.
- Failed/offline/permission fallback proof gap: closed by shared state simulator rendering.
- Remaining work is normal regression hygiene only: rerun the full project test ladder before release/commit and keep live adapter behavior covered by its dedicated integration tests.
