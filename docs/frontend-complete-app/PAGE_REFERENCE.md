# Page Reference

状态：Phase 1 P0 可执行参考规格
日期：2026-07-04
权威源：[route.schema.json](./route.schema.json)、[view-state.schema.json](./view-state.schema.json)、[ui-state.schema.json](./ui-state.schema.json)、[STATE_OWNERSHIP.md](./STATE_OWNERSHIP.md)
来源：[docs/ui-design/](../docs/ui-design/) 各页 01-页面结构稿 / 02-组件规格稿 / 03-交互规则稿 / 04-状态规则稿、[frontend-demo/route-contract.js](../frontend-demo/route-contract.js)

本文是 P0 阶段"页面级实现参考"。覆盖 Slice 1-6 优先链路的关键 route，给三端 reducer / Native UI 实现提供单一参考。全量 route × component 矩阵见 [ROUTE_COMPONENT_MATRIX.md](./ROUTE_COMPONENT_MATRIX.md)。

## 0. 文档边界

本文只覆盖：
- 每个 P0 route 的屏幕结构、组件树、状态集合、入口/返回/overlay/keyboard 行为
- 每个状态的归属（Core / Reducer / Ephemeral）
- 与 schema 的 id 对齐

本文不覆盖：
- 不重新定义 RouteId / ComponentType / PageState enum（以 schema 为准）
- 不写原生代码（SwiftUI / Compose / ArkUI）
- 不写动画数值（见 [MOTION_SPEC.md](./MOTION_SPEC.md)）
- 不写视觉数值（见 [TOKEN_SPEC.md](./TOKEN_SPEC.md)）

## 1. Shell 分组

| Shell | 包含 P0 route | 说明 |
| --- | --- | --- |
| `MainTabShell` | `app-shell`, `main-tabs`, `bookshelf`, `discover`, `rss`, `settings` | 主 Tab 根容器，4 个 Tab 入口 |
| `LibraryShell` | `bookshelf-empty`, `book-search`, `book-detail`, `book-directory`, `local-import`, `sort-filter`, `group-management` | 书架链路二级页 |
| `ReaderShell` | `immersive-reading`, `reader`, `reader_content`, `control-layer-base-v2`, `reader-appearance-overlay-v2`, `reader-tts-overlay-v2`, `reader-settings-overlay-v2`, `reader-search-overlay-v2`, `reader-replace-overlay-v2`, `reader-auto-scroll-overlay-v2`, `reader-directory-overlay-v2`, `reader-night-state-v2`, `tts`, `auto-page`, `content-search`, `content-replacement`, `source-switch`, `source-switch-results`, `toc-bookmarks` | 阅读链路 |
| `SettingsShell` | `global-settings`, `sync-backup`, `webdav-config`, `restore-scopes`, `restore-preview`, `restore-running`, `restore-result`, `sync-error`, `source-management`, `source-detail`, `source-add`, `source-edit` | 设置链路 |
| `FlowShell` | `source-switch`（从 ReaderShell 内打开）、`rss-original-browser` | 不使用全屏阻断遮罩的浮层链路 |

## 2. 状态归属标记

每个状态用三标记之一：

- `[C]` DomainState —— Owner: Reader-Core-Native。UI 不能直接改。
- `[R]` UiState —— Owner: Platform Interaction Reducer。本仓 schema 定义形状。
- `[E]` EphemeralState —— Owner: Native UI。不进入本仓 schema，不参与业务判断、不持久化、不跨页共享。

详见 [STATE_OWNERSHIP.md](./STATE_OWNERSHIP.md)。

## 3. Slice 1：AppShell + main tabs

### 3.1 `app-shell`

屏幕结构：
```
AppShell
  ├─ StatusBar inset（系统）
  ├─ HomeIndicator inset（系统）
  ├─ MainTabContent（当前 tab 对应的根 route）
  └─ BottomNav（4 个 tab）
```

组件树（ComponentType）：
- `BottomNav`（必需，4 个子项：bookshelf / discover / rss / settings）
- 当前 tab 对应的根页面组件树

状态集合：
| 状态 | 归属 | 来源 |
| --- | --- | --- |
| `tab` | `[R]` | `ui-state.tab` |
| `route` | `[R]` | `ui-state.route` |
| `reducedMotion` | `[R]` | `ui-state.reducedMotion`，URL/system reduced-motion 状态可见于 controller |
| `loading` | `[R]` | `ui-state.loading`，全局 loading |
| `error` | `[R]` | `ui-state.error`，全局 error |
| `viewportOrientation` | `[E]` | 平台测量 |
| `hasPlayedFirstOpen` | `[R]` | `appState.hasPlayedFirstOpen`，首屏进入动画只播一次 |

入口：冷启动进入 `app-shell`，触发 `app.firstOpen.enter` 事件。
返回：系统 back 不退出 App（除非 `bookshelf` 根态），由平台决定。
overlay：无主 overlay；全局 loading / error / offline 由 reducer 推到 `app-shell` 层。
keyboard：AppShell 不主动管理键盘 inset；键盘行为由含输入的子 route 负责。

### 3.2 `main-tabs`

`main-tabs` 是 `app-shell` 的子概念，描述 4 个 tab 的切换行为，不单独渲染。

入口：`mainTab.select` 事件 → reducer 更新 `ui-state.tab` → 触发 `tab.switch` motion。
返回：tab 之间切换不走返回栈；每个 tab 维护自己的子路由栈。
overlay：tab 切换时若 `loading=true` 且 `async guard` 命中，屏蔽切换（见 [state-rule.fixtures.json](./fixtures/state-rule.fixtures.json) overlay async guard）。

### 3.3 `bookshelf`（主 Tab：bookshelf）

屏幕结构：
```
BookshelfRoot
  ├─ AppTopBar（标题 + 搜索入口 + 排序入口）
  ├─ ShelfChipGroup（分组 chip）
  ├─ ContinueReadingCard / RecentUpdateCard（条件渲染）
  └─ BookGrid / BookList（按 view mode）
  └─ BottomNav
```

组件树（ComponentType）：
- `AppTopBar`、`SearchEntry`、`ShelfChipGroup`、`ContinueReadingCard`、`RecentUpdateCard`、`ShelfSectionHeader`、`BookCard` / `BookListItem`、`BottomNav`

状态集合：
| 状态 | 归属 | 来源 |
| --- | --- | --- |
| `bookshelfViewMode` | `[R]` | `appState.bookshelfViewMode`（cover-mode / list-mode）|
| `currentGroup` | `[R]` | `appState.currentGroup`，分组 id |
| `bookshelfBooks` | `[C]` | Core `bookshelf.list` 返回 |
| `bookshelfGroups` | `[C]` | Core `bookshelf.group.list` 返回 |
| `continueReadingBook` | `[C]` | Core `reader.progress.snapshot` 返回 |
| `recentUpdates` | `[C]` | Core `bookshelf.list` 派生 |
| `pageState` | `[R]` | `default / loading / shelf-empty / error / offline / permission` |
| `sortFilterOpen` | `[R]` | overlay 是否打开 |
| `dragOffset`（长按拖拽中）| `[E]` | 平台手势 |
| `pressedState`（卡片按下）| `[E]` | 平台手势 |

入口：主 Tab 切换；冷启动默认 tab。
返回：根 route，系统 back 通常退出 App（由平台决定）。
overlay：`sort-filter`、`bookshelf-book-more-menu`、`group-management`、`local-import`、`book-batch-management` 经 reducer 推入。
dialog/sheet：书籍操作底表 `Sheet`、删除确认 `Dialog`。
keyboard：`book-search` 入口打开后接管键盘 inset。

### 3.4 `discover`（主 Tab：discover）

屏幕结构：
```
DiscoverRoot
  ├─ AppTopBar（标题 + 搜索入口）
  ├─ SourceTypeSegment（来源类型）
  ├─ CurrentSourceCard / SourceCategoryChips
  ├─ DiscoveryContentCard（推荐书籍）
  └─ BottomNav
```

组件树：`AppTopBar`、`SearchEntry`、`SourceTypeSegment`、`CurrentSourceCard`、`SourceCategoryChips`、`DiscoveryContentCard`、`SourceStatusBar`、`BottomNav`

状态集合：
| 状态 | 归属 | 来源 |
| --- | --- | --- |
| `discoverFilter` / `discoverSort` / `discoverSortOpen` | `[R]` | `appState.discover*` |
| `discoverSourceType` | `[R]` | 当前选中的来源类型 |
| `discoverContent` | `[C]` | Core `source.search` 返回 |
| `discoverSourceStatus` | `[C]` | Core `source.detail` 返回 |
| `pageState` | `[R]` | `default / switching-source-type / source-empty / source-unavailable / network-failed / loading / refreshing` |

入口：主 Tab 切换。
返回：根 route。
overlay：`discover-sort`、`discover-filter-*`、`discover-source-bulk` 经 reducer 推入。
dialog/sheet：来源切换确认 `Sheet`。

### 3.5 `rss`（主 Tab：rss）

屏幕结构：
```
RssRoot
  ├─ AppTopBar（标题 + 刷新）
  ├─ FeedStatusChips / FeedSourceChips
  ├─ SubscriptionSummaryCard
  ├─ RssEntryItem list
  └─ BottomNav
```

组件树：`AppTopBar`、`FeedStatusChips`、`FeedSourceChips`、`SubscriptionSummaryCard`、`RssEntryItem`、`UnreadIndicator`、`BottomNav`

状态集合：
| 状态 | 归属 | 来源 |
| --- | --- | --- |
| `rssFilter` | `[R]` | 当前 filter（all / starred / source-feed）|
| `rssRefreshing` | `[R]` | `appState.rssRefreshing` |
| `rssFeed` | `[C]` | Core `rss.list` / `rss.refresh` 返回 |
| `rssSubscriptions` | `[C]` | Core `rss.subscription.list` 返回 |
| `pageState` | `[R]` | `default / refreshing / no-subscription / no-unread / network-failed` |

入口：主 Tab 切换。
返回：根 route。
overlay：`rss-subscription-management`、`rss-source-add`、`rss-source-edit` 经 reducer 推入。
dialog/sheet：刷新失败 `Toast`、订阅删除确认 `Dialog`。
keyboard：`rss-search` 输入接管键盘。

### 3.6 `settings`（主 Tab：settings）

屏幕结构：
```
SettingsRoot
  ├─ AppTopBar
  ├─ LocalOverviewCard
  ├─ QuickEntryGrid
  ├─ SettingsSection list
  └─ BottomNav
```

组件树：`AppTopBar`、`LocalOverviewCard`、`QuickEntryGrid`、`SettingsSection`、`SettingsListItem`、`BottomNav`

状态集合：
| 状态 | 归属 | 来源 |
| --- | --- | --- |
| `settingsExpandedOption` | `[R]` | `appState.settingsExpandedOption` |
| `settingsOverlay` | `[R]` | `appState.settingsOverlay` |
| `localStats` | `[C]` | Core `bookshelf.list` / `cache.book.status` 派生 |
| `pageState` | `[R]` | `default / local-data-loading / no-backup / permission-missing / topbar-action` |

入口：主 Tab 切换。
返回：根 route。
overlay：`settings-general`、`bookshelf-search-settings`、`about-feedback` 经 reducer 推入。
禁止：设置首页不直接执行清空/删除/恢复默认；破坏性操作必须在二级页确认（见 [STATE_OWNERSHIP.md](./STATE_OWNERSHIP.md) §6）。

## 4. Slice 2：Bookshelf → open book → reader surface

### 4.1 `bookshelf-empty`

屏幕结构：`AppTopBar` + `Empty`（空书架引导）+ `BottomNav`
状态：`pageState = shelf-empty` `[R]`；`bookshelfBooks` `[C]` 为空列表。
入口：从 `bookshelf` 在 `bookshelfBooks` 为空时切换。
返回：根态，不返回到 `bookshelf`（同根）。

### 4.2 `book-search` / `search-home` / `search-results` / `search-loading` / `search-empty` / `search-error`

屏幕结构（`book-search`）：
```
BookSearch
  ├─ BackTopBar（含 SearchInputBox）
  ├─ ScopeSelector（搜索范围）
  ├─ SearchHistoryList（条件渲染）
  ├─ SearchResultList
  ├─ AddToShelfButton / ReadButton（每条结果）
  └─ Loading / Empty / Error（状态层）
```

组件树：`BackTopBar`、`SearchInputBox`、`ScopeSelector`、`SearchHistoryList`、`SearchResultList`、`AddToShelfButton`、`ReadButton`、`Loading`、`Empty`、`Error`

状态集合：
| 状态 | 归属 | 来源 |
| --- | --- | --- |
| `searchQuery` | `[R]` | `appState.searchQuery` |
| `searchScope` | `[R]` | `appState.searchScope` |
| `searchResults` | `[C]` | Core `source.search` 返回 |
| `searchHistory` | `[C]` | Core 持久化（搜索历史归 Core）|
| `pageState` | `[R]` | `default / loading / empty / error / offline` |
| `searchInputFocused` | `[E]` | 平台焦点 |
| `searchScrollPixel` | `[E]` | 平台滚动 |

入口：`book.search.submit` / `search.open` 事件。
返回：`route.pop` 回到 `bookshelf`。
keyboard：搜索框获得焦点时打开键盘；`input.blur` / 系统返回时关闭键盘。
async guard：`search.loading` 时禁止重复提交（见 state-rule fixtures）。

### 4.3 `book-detail` / `book-detail-toc-preview` / `book-directory`

屏幕结构（`book-detail`）：
```
BookDetail
  ├─ BackTopBar
  ├─ BookCover + BookTitleAuthor
  ├─ SourceStatus
  ├─ DirectoryPreview
  ├─ BookIntro
  ├─ ReadButton + AddToShelfButton
  └─ Loading / Empty / Error / Offline / Permission（状态层）
```

组件树：`BackTopBar`、`BookCover`、`BookTitleAuthor`、`SourceStatus`、`DirectoryPreview`、`BookIntro`、`ReadButton`、`AddToShelfButton`、`Loading`、`Empty`、`Error`、`Offline`、`Permission`

状态集合：
| 状态 | 归属 | 来源 |
| --- | --- | --- |
| `bookId` | `[C]` | 路由参数，Core `book.open` 接收 |
| `bookMeta` | `[C]` | Core `book.parse` / `source.detail` 返回 |
| `bookChapters` | `[C]` | Core `chapter.list` 返回 |
| `tocPreview` | `[C]` | Core `chapter.list` 派生 |
| `pageState` | `[R]` | `default / loading / empty / error / offline / permission` |

入口：`book.detail.open` / `book.action` 事件。
返回：`route.pop`。
overlay：`book-directory` 全屏目录页可经 `reader.directory.open` 推入。

### 4.4 `immersive-reading` / `reader` / `reader_content`

屏幕结构（`immersive-reading`）：
```
ImmersiveReading
  ├─ ReadingBackgroundLayer
  ├─ ReadingTextFlow（章节正文）
  ├─ ReadingInfoLayer（页码 / 章节名）
  ├─ TapZones（左右点击翻页）
  └─ ControlLayer（按需浮起，见 Slice 3）
```

组件树：`ReadingBackgroundLayer`、`ReadingTextFlow`、`ReadingInfoLayer`、`TapZones`、`Loading`、`Error`、`Offline`

状态集合：
| 状态 | 归属 | 来源 |
| --- | --- | --- |
| `bookId` / `chapterId` | `[C]` | Core 持有 |
| `content` | `[C]` | Core `content.load` 返回 |
| `progress` | `[C]` | Core `reader.location.resolve` 返回 canonical location |
| `readerPageIndex` / `readerChapterIndex` / `readerChapterProgress` | `[R]` | `appState.reader*`，由 Core canonical location 派生 |
| `readerMode` | `[R]` | `ui-state.readerMode`（default / loading / empty / error / offline / permission）|
| `readerTurnDirection` | `[R]` | `next / prev`，触发翻页 motion |
| `readerTextSelectionOpen` / `readerSelectedText` | `[R]` | 文本选择状态 |
| `overlay` | `[R]` | `ui-state.overlay` |
| `activeSession` | `[R]` | `ui-state.activeSession`（null / reading / tts / auto-page）|
| `focusTarget` | `[R]` | `ui-state.focusTarget` |
| `dragOffset`（翻页拖动中）| `[E]` | 平台手势 |
| `scrollPixel` | `[E]` | 平台滚动 |
| `layoutMeasurement` | `[E]` | 平台排版测量 |
| `textSelection` | `[E]` | 平台选择 |
| `accessibilityFocus` | `[E]` | 平台无障碍焦点 |

入口：`reader.enter` / `reader.entry.coverToImmersive` / `reader.entry.actionToImmersive` 事件。
返回：`reader.exit` 事件 → `route.pop` 回到 `book-detail` 或 `bookshelf`。
keyboard：沉浸阅读一般不弹键盘；`content-search` / `content-replacement` overlay 打开时接管。
禁止：阅读进度以 Core canonical location 为准；平台排版测量不能反向覆盖业务进度（见 [STATE_OWNERSHIP.md](./STATE_OWNERSHIP.md) §2）。

## 5. Slice 3：Reader overlay / control dock / reader mode

### 5.1 `control-layer-base-v2`

屏幕结构：阅读器顶部 + 底部控制条浮层，覆盖在 `immersive-reading` 之上。
组件树：`Overlay`（包含 `AppTopBar`、`BottomNav` 替身、模块入口 chips）

状态集合：
| 状态 | 归属 | 来源 |
| --- | --- | --- |
| `overlay` | `[R]` | `ui-state.overlay = reader-control` |
| `readerControlSpaceSnapshot` | `[R]` | `appState.readerControlSpaceSnapshot` |
| `readerDockOffsets[key]` | `[R]` | `appState.readerDockOffsets` |
| `motionOverlaySequence` / `motionOverlayRole` / `motionOverlayAction` / `motionOverlayFocusReturn` / `motionOverlayReturnTarget` | `[R]` | `appState.motionOverlay*` |

入口：`reader.control.toggle` 事件（点击阅读区中央切换）。
返回：再点中央 / 系统返回 → `reader.control.toggle` 关闭 overlay。
互斥：与所有 reader overlay 互斥（state-rule fixtures overlay 互斥规则）。

### 5.2 reader overlay 集合

| RouteId | overlay enum | 入口事件 | 关闭事件 |
| --- | --- | --- | --- |
| `reader-appearance-overlay-v2` / `reader-appearance` | `appearance` | `reader.appearance.open` | `reader.settings.close` |
| `reader-tts-overlay-v2` / `tts` | `tts` | `reader.tts.start` / `reader.tts.toggle` | `reader.tts.stop` / `reader.tts.toggle` |
| `reader-settings-overlay-v2` / `reader-settings` | `settings` | `reader.settings.open` | `reader.settings.close` |
| `reader-search-overlay-v2` / `content-search` | `content-search` | `reader.contentSearch.open` | `reader.contentSearch.close` |
| `reader-replace-overlay-v2` / `content-replacement` | `content-replacement` | `reader.contentReplacement.open` | `reader.contentReplacement.close` |
| `reader-directory-overlay-v2` / `toc-bookmarks` | `directory` | `reader.directory.open` | `reader.directory.close` |
| `reader-auto-scroll-overlay-v2` / `auto-page` | `auto-page` | `reader.autoPage.start` | `reader.autoPage.stop` |
| `source-switch` / `source-switch-results` | `source-switch` | `reader.sourceSwitch.open` | `reader.sourceSwitch.close` |
| `reader-night-state-v2` | `null`（不是 overlay，是 readerMode 派生）| `reader.nightState.toggle` | — |

通用规则：
- overlay 之间互斥（一次只开一个）。
- overlay 切换必须经 `null` 中转（transition-guard，见 state-rule fixtures）。
- `activeSession = tts` 或 `auto-page` 时，关闭对应 overlay 不结束 session。
- overlay 关闭顺序：先关闭当前浮层，再返回上级页面（见 [STATE_OWNERSHIP.md](./STATE_OWNERSHIP.md) §6）。

## 6. Slice 4：Progress / session / focus / TTS

### 6.1 session capsule（不单独 route，浮在 `immersive-reading` 上）

状态集合：
| 状态 | 归属 | 来源 |
| --- | --- | --- |
| `activeSession` | `[R]` | `ui-state.activeSession`（null / reading / tts / auto-page）|
| `readerSessionCapsuleSnapshot` | `[R]` | `appState.readerSessionCapsuleSnapshot` |
| `readerAutoPageCountdown` | `[R]` | `appState.readerAutoPageCountdown` |
| `ttsQueue` | `[C]` | Core `tts.queue.plan` 返回 |
| `ttsState` | `[C]` | Core `tts.queue.start/pause/resume/stop` 返回 |

事件：`reader.session.capsuleEnter/Exit/Switch`、`reader.session.controlSpaceEnter/Update/Exit`、`reader.session.ttsStart`、`reader.session.autoPageStart`、`reader.session.capsuleCountdownTick`、`reader.session.capsuleVoiceIconActive`。

互斥：`tts` 与 `auto-page` session 互斥（state-rule fixtures）。

### 6.2 focus 恢复

每个 overlay 关闭时，`motionOverlayFocusReturn` / `motionOverlayReturnTarget` 决定焦点回到哪个组件。平台必须实现：
- 关闭 overlay → focusTarget 回到打开 overlay 的触发器（如 `reader.control.handle`）。
- 系统返回 → 与关闭 overlay 等价。
- 路由 `route.pop` → 焦点回到上一页最后 focusTarget。

### 6.3 progress 更新

事件流：
```
reader.page.next / reader.page.prev / reader.chapter.jump
  -> reducer 更新 readerPageIndex / readerChapterIndex / readerChapterProgress
  -> reducer emit CoreCommand reader.progress.update
  -> Core 返回 CoreEvent reader.progress.updated（canonical location）
  -> reducer 用 canonical location 覆盖本地 readerPageIndex 派生
```

禁止：UI 直接修改 `progress`；平台排版测量不写入 Core。

## 7. Slice 5：RSS / source / search

### 7.1 `rss-detail` / `rss-original` / `rss-original-browser`

屏幕结构（`rss-detail`）：
```
RssDetail
  ├─ BackTopBar
  ├─ Content（rss 正文）
  ├─ List（相关条目）
  └─ Loading / Error / Offline
```

状态集合：
| 状态 | 归属 | 来源 |
| --- | --- | --- |
| `rssItem` | `[C]` | Core `rss.item.read` 返回 |
| `rssOriginalUrl` | `[C]` | Core 持有 |
| `pageState` | `[R]` | `default / loading / error / offline` |

入口：`rss.entry.open` / `rss.entry.openOriginal` / `rss.entry.openOriginalBrowser`。
`rss-original-browser` 走 `HostRequest webview.open`（[CORE_HOST_BOUNDARY.md](./CORE_HOST_BOUNDARY.md) §3）。

### 7.2 `source-management` / `source-detail` / `source-add` / `source-edit` / `source-delete-confirm`

屏幕结构（`source-management`）：`BackTopBar` + `List`（书源列表）+ `FilterBar`。
状态：`sourceList` `[C]`（Core `source.search` / `source.detail` 派生）。
入口：`source.management.open` / `source.detail.open` / `source.add.open` / `source.edit.open`。
破坏性操作（删除）必须 `Dialog` 确认。

### 7.3 `book-search`（与 Slice 2 共享）

见 §4.2。

## 8. Slice 6：Sync / conflict / offline state

### 8.1 `sync-backup` / `webdav-config` / `sync-error`

屏幕结构（`sync-backup`）：`BackTopBar` + `SettingsSection`（同步开关 + 备份入口 + 恢复入口）。
状态：
| 状态 | 归属 | 来源 |
| --- | --- | --- |
| `syncStatus` | `[C]` | Core `sync.snapshot` 返回 |
| `webdavConfig` | `[C]` | Core 持有，经 HostRequest `credential.get/set` |
| `conflictState` | `[C]` | Core `sync.snapshot` 返回 |
| `pageState` | `[R]` | `default / loading / error / offline` |

入口：`settings.sync.open` / `webdav.config.open`。
`sync-error` 不是独立 route，是 `sync-backup` 的 `pageState = error` 派生页（state-rule fixtures error 与 pageState 关联）。

### 8.2 `restore-scopes` / `restore-preview` / `restore-running` / `restore-result` / `restore-conflict`

屏幕结构（`restore-running`）：`BackTopBar` + `ProgressBar` + `Loading`。
状态：
| 状态 | 归属 | 来源 |
| --- | --- | --- |
| `restoreAvailableScopes` / `restoreSelectedScopes` | `[R]` | `appState.restore*` |
| `restoreProgress` | `[C]` | Core `sync.pull` / `backup.run` 返回 |
| `restoreConflict` | `[C]` | Core `sync.conflict.resolve` 返回 |

入口：`restore.scopes.open` / `restore.run`。
async guard：`restore.loading` 时禁止 `route.push`（state-rule fixtures sync loading async guard）。

### 8.3 `offline-state` / `state-offline`

`offline-state` 是 AppShell 层的浮层，不是独立 route。
触发：网络不可用时 reducer 设置 `pageState = offline`。
规则：网络不可用只阻断依赖网络的动作，不阻断本地查看与关闭页面（见 [STATE_OWNERSHIP.md](./STATE_OWNERSHIP.md) §6）。

## 9. 通用状态层

每个 route 都可能进入以下 PageState，对应组件树中的状态层组件：

| PageState | 触发 | 状态层组件 | 归属 |
| --- | --- | --- | --- |
| `loading` | 等待 Core 返回 | `Loading` | `[R]`（loading 标志）+ `[C]`（数据来源）|
| `empty` | Core 返回空集合 | `Empty` | `[R]` + `[C]` |
| `error` | Core 返回错误或 Host 失败 | `Error` | `[R]`（error 对象）+ `[C]`（错误源）|
| `offline` | 网络不可用 | `Offline` | `[R]` + `[C]`（网络状态）|
| `permission` | 权限缺失 | `Permission` | `[R]` + HostRequest `permission.request` |

规则（来自 [STATE_OWNERSHIP.md](./STATE_OWNERSHIP.md) §6）：
- 状态页不得改变底部导航结构。
- 沉浸阅读状态层不得改变页面主结构，只替换对应内容区或显示可恢复反馈。
- 网络不可用只阻断依赖网络的动作。

## 10. 入口 / 返回 / overlay / dialog / sheet / keyboard 通用规则

### 入口

- `route.push`：压入新页面到当前 tab 子栈。
- `route.replace`：替换当前页面（如 `bookshelf` → `bookshelf-empty`）。
- `mainTab.select`：切换 tab，每个 tab 维护独立子栈。
- 冷启动：`app-shell` + 默认 tab `bookshelf`。

### 返回

- `route.pop`：弹出当前页面。
- `route.popToRoot`：回到当前 tab 根。
- 系统返回：等价于 `route.pop`；根 route 由平台决定（通常退出 App）。
- overlay 打开时系统返回：先关闭 overlay，不退出页面。

### overlay / dialog / sheet

- 互斥：一次只允许一个 overlay；dialog 与 overlay 也互斥。
- 关闭顺序：先关闭当前浮层，再返回上级页面。
- sheet 高度：由平台 sheet detent 决定，本仓不规定具体数值（见 [TOKEN_SPEC.md](./TOKEN_SPEC.md)）。

### keyboard

- inset：含输入的 route（`book-search` / `content-search` / `content-replacement` / `webdav-config` / `source-edit` / `source-add`）必须处理 keyboard inset。
- 焦点丢失：`input.blur` 或系统返回必须关闭键盘。
- async guard：键盘弹出期间禁止 `route.push`（避免键盘 inset 与新页面冲突）。

## 11. 与现有页面包的对应

P0 route 对应的 `docs/ui-design/` 页面包：

| Shell | 页面包目录 |
| --- | --- |
| MainTabShell - bookshelf | `docs/ui-design/02-主标签页/书架/` |
| MainTabShell - discover | `docs/ui-design/02-主标签页/发现/` |
| MainTabShell - rss | `docs/ui-design/02-主标签页/RSS/` |
| MainTabShell - settings | `docs/ui-design/02-主标签页/设置/` |
| LibraryShell - bookshelf-empty | `docs/ui-design/03-书架链路/书架空状态/` |
| LibraryShell - book-search | `docs/ui-design/03-书架链路/书籍搜索/` |
| LibraryShell - book-detail | `docs/ui-design/03-书架链路/书籍详情/` |
| LibraryShell - book-directory | `docs/ui-design/03-书架链路/书籍目录/` |
| LibraryShell - local-import | `docs/ui-design/03-书架链路/本地书导入/` |
| LibraryShell - sort-filter | `docs/ui-design/03-书架链路/排序与筛选/` |
| LibraryShell - group-management | `docs/ui-design/03-书架链路/分组管理/` |
| LibraryShell - 书籍操作底表 | `docs/ui-design/03-书架链路/书籍操作底表/` |
| ReaderShell - 沉浸阅读 | `docs/ui-design/04-阅读链路/沉浸阅读/` |
| ReaderShell - 朗读 | `docs/ui-design/04-阅读链路/朗读/` |
| ReaderShell - 内容搜索 | `docs/ui-design/04-阅读链路/内容搜索/` |
| ReaderShell - 内容替换 | `docs/ui-design/04-阅读链路/内容替换/` |
| ReaderShell - 换源 | `docs/ui-design/04-阅读链路/换源/` |

页面包内文件命名规范：`00-说明.md` / `01-页面结构稿.md` / `02-组件规格稿.md` / `03-交互规则稿.md` / `04-状态规则稿.md` / `05-文案稿.md` / `06-禁止项.md` / `08-*视觉规格.md` / `09-资产与验收清单.md` / `10-正式UI设计稿.md`。

## 12. 缺口与下一步

P0 阶段已覆盖 Slice 1-6 关键 route 的页面参考。剩余缺口：
- 部分 RouteId（如 `reader-full-*` 全屏设置页、`source-debug-*` 调试链路、`rss-source-*` RSS 源管理细分）未在本文展开，归入阶段 2 [ROUTE_COMPONENT_MATRIX.md](./ROUTE_COMPONENT_MATRIX.md)。
- demo baseline 中 111 个 unknown id 的产品决策（是否补入 schema、归一化或列为 deprecated/alias 例外）不阻塞本文。
