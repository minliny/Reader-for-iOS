# Route Component Matrix

状态：Phase 2 完整矩阵
日期：2026-07-04
权威源：[route.schema.json](./route.schema.json)、[view-state.schema.json](./view-state.schema.json)、[motion.schema.json](./motion.schema.json)、[token.schema.json](./token.schema.json)、[ui-state.schema.json](./ui-state.schema.json)
来源：[PAGE_REFERENCE.md](./PAGE_REFERENCE.md)、[MOTION_SPEC.md](./MOTION_SPEC.md)、[TOKEN_SPEC.md](./TOKEN_SPEC.md)

本文是阶段 2"完整 route/component/state/motion/token 矩阵"。覆盖全部 RouteId（200+）× Shell × PageState × Motion × Token 分组，给三端实现提供完整索引。P0 链路的详细描述见 [PAGE_REFERENCE.md](./PAGE_REFERENCE.md)。

## 0. 文档边界

本文覆盖：
- 全量 RouteId × Shell × 主 Tab × PageState 集合
- 全量 ComponentType × 所属 shell / route
- 关键 route × MotionId 映射
- 关键 route × Token 分组映射

本文不覆盖：
- 不重复 P0 route 的详细描述（见 [PAGE_REFERENCE.md](./PAGE_REFERENCE.md)）
- 不重复 MotionId 详细规则（见 [MOTION_SPEC.md](./MOTION_SPEC.md)）
- 不重复 Token 数值（见 [token.fixtures.json](./fixtures/token.fixtures.json)）

## 1. Route × Shell × mainTab 全量矩阵

来源：[route.schema.json](./route.schema.json) enum（200 项）。

### 1.1 MainTabShell（4 个主 Tab 根 + AppShell）

| RouteId | mainTab | 说明 |
| --- | --- | --- |
| `app-shell` | null | App 根容器 |
| `main-tabs` | null | 主 Tab 切换器（不单独渲染）|
| `bookshelf` | bookshelf | 书架根 |
| `discover` | discover | 发现根 |
| `rss` | rss | RSS 根 |
| `settings` | settings | 设置根 |
| `bookshelf-empty` | bookshelf | 书架空态（同根）|
| `bookshelf-cover-mode` | bookshelf | 书架封面模式（同根）|
| `bookshelf-list-mode` | bookshelf | 书架列表模式（同根）|
| `bookshelf-book-more-menu` | bookshelf | 书籍更多菜单（overlay）|

### 1.2 LibraryShell（书架链路二级页）

| RouteId | 说明 |
| --- | --- |
| `bookshelf-group-management` | 书架分组管理 |
| `book-batch-management` | 批量管理 |
| `sort-filter` | 排序与筛选（底表）|
| `group-management` | 分组管理（别名）|
| `local-import` | 本地书导入 |
| `book-search` | 书籍搜索 |
| `search-home` | 搜索首页 |
| `search-results` | 搜索结果 |
| `search-loading` | 搜索中 |
| `search-empty` | 搜索空态 |
| `search-error` | 搜索错误 |
| `book-detail` | 书籍详情 |
| `book-detail-toc-preview` | 详情内目录预览 |
| `book-directory` | 全屏目录 |

### 1.3 ReaderShell（阅读链路）

| RouteId | overlay enum | 说明 |
| --- | --- | --- |
| `immersive-reading` | null | 沉浸阅读主页 |
| `reader` | null | reader 别名 |
| `reader_content` | null | 阅读正文层 |
| `control-layer-base-v2` | reader-control | 控制层基础 |
| `reader-appearance-overlay-v2` / `reader-appearance` | appearance | 外观 |
| `reader-tts-overlay-v2` / `tts` | tts | 朗读 |
| `reader-settings-overlay-v2` / `reader-settings` | settings | 设置 |
| `reader-search-overlay-v2` / `content-search` | content-search | 内容搜索 |
| `reader-replace-overlay-v2` / `content-replacement` | content-replacement | 内容替换 |
| `reader-directory-overlay-v2` / `toc-bookmarks` | directory | 目录书签 |
| `reader-auto-scroll-overlay-v2` / `auto-page` | auto-page | 自动翻页 |
| `source-switch` / `source-switch-results` | source-switch | 换源 |
| `reader-night-state-v2` | null | 夜间态派生（非 overlay）|
| `reader-full-font` / `reader-full-theme` / `reader-full-theme-edit` / `reader-full-layout` / `reader-full-page-turn` / `reader-full-directory` / `reader-full-tts` / `reader-full-appearance` / `reader-full-settings` | null | 全屏设置页（从 overlay 展开）|
| `reader-book-cache` | null | 书籍缓存管理 |
| `reader-debug-info` | null | 调试信息 |

### 1.4 SettingsShell（设置链路）

| RouteId | 说明 |
| --- | --- |
| `global-settings` | 全局设置 |
| `settings-general` | 通用设置 |
| `bookshelf-search-settings` | 书架搜索设置 |
| `about-feedback` | 关于反馈 |
| `sync-backup` | 同步备份 |
| `webdav-config` | WebDAV 配置 |
| `restore-scopes` / `restore-preview` / `restore-running` / `restore-result` / `restore-confirm` / `restore-progress` / `restore-conflict` | 恢复链路 |
| `sync-error` | 同步错误（派生）|
| `sync-settings-entry` / `reading-settings-entry` / `source-settings-entry` / `backup-settings` | 设置入口 |
| `progress-sync-status` / `progress-sync` | 同步状态 |
| `remote-webdav-books` | 远程 WebDAV 书籍 |
| `about` / `about-version` | 关于 |
| `source-management` / `source-detail` / `source-add` / `source-edit` / `source-delete-confirm` / `source-detect` / `source-rule-edit` / `source-debug` / `source-debug-running` / `source-debug-result` / `source-logs` / `source-code-view` / `source-test-result` / `source-batch` / `source-groups` / `source-import-options` / `source-import-preview` / `source-edit-debug` | 书源管理链路 |
| `source-debug-search-result` / `source-debug-detail-result` / `source-debug-catalog-result` / `source-debug-content-log` | 书源调试结果 |

### 1.5 FlowShell（浮层链路）

| RouteId | 说明 |
| --- | --- |
| `source-switch`（从 ReaderShell 内打开）| 换源窗口，不全屏遮罩 |
| `rss-original-browser` | RSS 原文浏览器 |

### 1.6 全局状态层（不是独立 route，但存在于 schema enum）

| RouteId | 说明 |
| --- | --- |
| `global-loading` | 全局 loading |
| `global-empty` | 全局空态 |
| `global-error` | 全局错误 |
| `offline-state` / `state-offline` | 离线态 |
| `permission-required` | 权限缺失 |
| `state-error` | 错误态 |

### 1.7 DiscoverShell 子 route（实际属于 MainTabShell - discover 派生）

| RouteId | 说明 |
| --- | --- |
| `discover-home` / `discover-control` / `discover-sort` | 发现首页 / 控制 / 排序 |
| `discover-entry-category` / `discover-entry-source` / `discover-entry-ranking` / `discover-entry-bestseller` / `discover-entry-finished` / `discover-entry-latest` / `discover-entry-new` / `discover-entry-booklist` | 发现入口 |
| `discover-filter-source-type` / `discover-filter-category` / `discover-filter-keyword` / `discover-filter-male` / `discover-filter-female` | 发现筛选 |
| `discover-no-results` / `discover-loading` / `discover-refreshing` / `discover-infinite-loading` | 发现状态 |
| `discover-page-two` | 发现第二页 |
| `discover-cache-empty` / `discover-cache-stale` / `discover-cache-fresh` / `discover-cache-confirm` / `discover-cache-toast` | 发现缓存 |
| `discover-login-return` / `discover-source-login` | 发现登录 |
| `discover-switching-source` / `discover-switched-source` | 发现换源 |
| `discover-entry-error` / `discover-empty` / `discover-error` | 发现错误 |
| `discover-rule-test` / `discover-source-bulk` | 发现规则测试 / 批量 |

### 1.8 RSS 子 route（属于 MainTabShell - rss 派生）

| RouteId | 说明 |
| --- | --- |
| `rss-all` / `rss-starred` / `rss-source-feed` / `rss-original` | RSS 视图 |
| `rss-source-category-novel` / `rss-source-category-tech` / `rss-source-category-booklist` / `rss-source-category-releases` / `rss-source-category-issues` / `rss-source-category-discussions` | RSS 分类 |
| `rss-refreshing` / `rss-search` / `rss-detail` | RSS 状态 / 搜索 / 详情 |
| `rss-subscription-management` / `rss-source-add` / `rss-source-edit` / `rss-source-delete-confirm` | RSS 订阅管理 |
| `rss-rule-subscription-create` / `rss-rule-subscription-edit` / `rss-rule-subscription` / `rss-rule-subscription-detail` / `rss-rule-subscription-test` / `rss-rule-subscription-apply` | RSS 规则订阅 |
| `rss-favorite-add` / `rss-favorite-remove` / `rss-favorite-groups` / `rss-favorite-group-edit` / `rss-favorite-clear` | RSS 收藏 |
| `rss-empty` / `rss-error` | RSS 状态 |
| `rss-source-actions` / `rss-source-debug` / `rss-source-vars` / `rss-source-login` / `rss-source-login-web` / `rss-source-login-cookie` / `rss-source-login-clear` / `rss-source-groups` / `rss-source-group-edit` / `rss-source-batch` / `rss-source-export` / `rss-source-export-detail` / `rss-source-export-result` / `rss-source-pin` / `rss-source-disable` / `rss-source-batch-disable` / `rss-source-import` / `rss-source-import-detail` / `rss-source-import-result` | RSS 源管理 |
| `rss-read-record` / `rss-record-clear` | RSS 阅读记录 |

## 2. ComponentType × Shell 归属

来源：[view-state.schema.json](./view-state.schema.json) ComponentType enum（64 项）。

| ComponentType | 主要 Shell | 主要用途 |
| --- | --- | --- |
| `AppTopBar` | MainTabShell | 主 Tab 顶部栏 |
| `BackTopBar` | Library / Reader / Settings | 二级页顶部栏（含返回）|
| `SearchEntry` | MainTabShell | 搜索入口（点击进 `book-search`）|
| `SourceTypeSegment` | MainTabShell - discover | 来源类型分段控制 |
| `CurrentSourceCard` | MainTabShell - discover | 当前源卡片 |
| `SourceCategoryChips` | MainTabShell - discover | 源分类 chip |
| `DiscoveryContentCard` | MainTabShell - discover | 推荐内容卡片 |
| `SourceStatusBar` | MainTabShell - discover | 源状态条 |
| `BottomNav` | MainTabShell | 底部导航 |
| `ShelfChipGroup` | MainTabShell - bookshelf | 书架分组 chip |
| `ContinueReadingCard` | MainTabShell - bookshelf | 继续阅读卡片 |
| `RecentUpdateCard` | MainTabShell - bookshelf | 最近更新卡片 |
| `ShelfSectionHeader` | MainTabShell - bookshelf | 书架区段标题 |
| `BookCard` | MainTabShell - bookshelf | 书籍卡片（封面模式）|
| `BookListItem` | MainTabShell - bookshelf | 书籍列表项（列表模式）|
| `ProgressBar` | Reader / Settings | 进度条（阅读进度 / 恢复进度）|
| `SubscriptionSummaryCard` | MainTabShell - rss | RSS 订阅汇总 |
| `FeedStatusChips` | MainTabShell - rss | RSS 状态 chip |
| `FeedSourceChips` | MainTabShell - rss | RSS 源 chip |
| `RssEntryItem` | MainTabShell - rss | RSS 条目 |
| `UnreadIndicator` | MainTabShell - rss | 未读标识 |
| `LocalOverviewCard` | MainTabShell - settings | 本地概览 |
| `QuickEntryGrid` | MainTabShell - settings | 快速入口网格 |
| `SettingsSection` | MainTabShell - settings / SettingsShell | 设置区段 |
| `SettingsListItem` | MainTabShell - settings / SettingsShell | 设置列表项 |
| `SearchInputBox` | LibraryShell - book-search | 搜索输入框 |
| `ScopeSelector` | LibraryShell - book-search | 范围选择器 |
| `GroupSelector` | LibraryShell | 分组选择器 |
| `SearchHistoryList` | LibraryShell - book-search | 搜索历史 |
| `SearchResultList` | LibraryShell - book-search | 搜索结果 |
| `AddToShelfButton` | LibraryShell - book-search / book-detail | 加入书架按钮 |
| `ReadButton` | LibraryShell - book-detail | 阅读按钮 |
| `BookCover` | LibraryShell - book-detail | 书籍封面 |
| `BookTitleAuthor` | LibraryShell - book-detail | 书名作者 |
| `SourceStatus` | LibraryShell - book-detail | 源状态 |
| `DirectoryPreview` | LibraryShell - book-detail | 目录预览 |
| `BookIntro` | LibraryShell - book-detail | 书籍简介 |
| `ConfigEntry` | SettingsShell | 配置入口 |
| `ReadingBackgroundLayer` | ReaderShell | 阅读背景层 |
| `ReadingTextFlow` | ReaderShell | 阅读正文层 |
| `ReadingInfoLayer` | ReaderShell | 阅读信息层（页码 / 章节名）|
| `TapZones` | ReaderShell | 点击翻页区 |
| `Loading` | 全 Shell | 状态层 - loading |
| `Empty` | 全 Shell | 状态层 - empty |
| `Error` | 全 Shell | 状态层 - error |
| `Offline` | 全 Shell | 状态层 - offline |
| `Permission` | 全 Shell | 状态层 - permission |
| `Toast` | 全 Shell | Toast 反馈 |
| `Sheet` | 全 Shell | 底表 |
| `Dialog` | 全 Shell | 弹窗 |
| `Overlay` | 全 Shell | 通用 overlay |
| `List` | Library / Reader / Settings | 通用列表 |
| `ListRow` | Library / Reader / Settings | 通用列表行 |
| `Card` | 全 Shell | 通用卡片 |
| `Chip` | 全 Shell | 通用 chip |
| `Button` | 全 Shell | 通用按钮 |
| `Toggle` | 全 Shell | 通用 toggle |
| `Slider` | Reader / Settings | 通用 slider |
| `Stepper` | Reader / Settings | 通用 stepper |
| `Segment` | Reader / Settings | 通用分段控制 |
| `Dropdown` | Reader / Settings | 通用下拉 |
| `Input` | Library / Settings | 通用输入 |
| `FormSection` | SettingsShell | 表单区段 |
| `FilterBar` | Library / Settings | 筛选条 |
| `Content` | ReaderShell / RSS | 内容容器（rss 正文 / 阅读正文容器）|
| `WebView` | FlowShell - rss-original-browser | WebView 容器 |

## 3. PageState × Route 集合

来源：[view-state.schema.json](./view-state.schema.json) PageState enum（22 项）。

| PageState | 适用 route |
| --- | --- |
| `default` | 全部 route |
| `loading` | 全部 route（等待 Core 返回）|
| `empty` | `bookshelf` / `book-search` / `rss` / `discover` |
| `error` | 全部 route |
| `offline` | 全部 route（网络相关）|
| `permission` | 全部 route（权限相关）|
| `cover-mode` | `bookshelf` / `bookshelf-cover-mode` |
| `list-mode` | `bookshelf` / `bookshelf-list-mode` |
| `shelf-empty` | `bookshelf-empty` |
| `no-cover` | `bookshelf`（无封面派生）|
| `long-title` | `bookshelf`（长书名派生）|
| `switching-source-type` | `discover` / `discover-switching-source` |
| `source-empty` | `discover` / `discover-empty` |
| `source-unavailable` | `discover` / `discover-source-login` |
| `network-failed` | `discover` / `rss` / `book-search` |
| `refreshing` | `rss` / `rss-refreshing` / `discover-refreshing` |
| `no-subscription` | `rss` |
| `no-unread` | `rss` |
| `local-data-loading` | `settings` |
| `no-backup` | `sync-backup` |
| `permission-missing` | `settings` |
| `topbar-action` | `settings` |

## 4. Route × MotionId 映射（关键链路）

完整 MotionId 集合见 [motion.schema.json](./motion.schema.json)（84 项）+ [MOTION_SPEC.md](./MOTION_SPEC.md)。

### 4.1 MainTabShell

| Route | 触发 MotionId |
| --- | --- |
| `app-shell` | `app.firstOpen.enter`（冷启动）|
| `main-tabs` / `bookshelf` / `discover` / `rss` / `settings` | `tab.item.select` / `tab.switch` |
| `bookshelf` / `bookshelf-cover-mode` / `bookshelf-list-mode` | `bookshelf.view.switch` |
| `bookshelf-book-more-menu` | `overlay.sheet.enter` / `overlay.sheet.exit` |

### 4.2 LibraryShell

| Route | 触发 MotionId |
| --- | --- |
| `book-search` / `search-home` / `search-results` / `search-loading` / `search-empty` / `search-error` | `app.route.push.forward` / `search.state.replace` / `state.loading.inline` |
| `book-detail` / `book-detail-toc-preview` / `book-directory` | `app.route.push.forward` / `app.route.pop.backward` |
| `sort-filter` | `overlay.sheet.enter` / `overlay.sheet.exit` / `filter.apply.commit` |
| `group-management` / `bookshelf-group-management` | `app.route.push.forward` / `app.route.pop.backward` |
| `local-import` | `app.route.push.forward` |
| `book-batch-management` | `app.route.push.forward` |

### 4.3 ReaderShell

| Route | 触发 MotionId |
| --- | --- |
| `immersive-reading` / `reader` / `reader_content` | `reader.entry.coverToImmersive` / `reader.entry.actionToImmersive` / `reader.page.turn.next-prev` / `reader.chapter.jump` / `reader.control.handle.press` / `reader.control.handle.release` / `reader.control.dock.longPress` / `reader.control.dock.drag` / `reader.control.dock.release` / `reader.control.dock.rebound` / `reader.control.hide` |
| `control-layer-base-v2` | `reader.module.switch` |
| `reader-appearance-overlay-v2` / `reader-tts-overlay-v2` / `reader-settings-overlay-v2` / `reader-search-overlay-v2` / `reader-replace-overlay-v2` / `reader-directory-overlay-v2` / `reader-auto-scroll-overlay-v2` | `overlay.sheet.enter` / `overlay.sheet.exit` / `reader.module.switch`（互斥切换）|
| `tts` / `auto-page` | `reader.session.capsule.enter` / `reader.session.capsule.update` / `reader.session.capsule.exit` / `reader.session.capsule.switch` / `reader.session.controlSpace.enter` / `reader.session.controlSpace.exit` / `reader.session.tts.start` / `reader.session.autoPage.start` |
| `source-switch` / `source-switch-results` | `reader.sourceSwitch.open-close` |
| `reader-night-state-v2` | `state.content.replace` |
| `reader-full-*` | `app.route.push.forward` / `app.route.pop.backward` |
| `reader-book-cache` | `app.route.push.forward` |
| `reader-debug-info` | `app.route.push.forward` |

### 4.4 SettingsShell

| Route | 触发 MotionId |
| --- | --- |
| `global-settings` / `settings-general` / `bookshelf-search-settings` / `about-feedback` | `app.route.push.forward` / `app.route.pop.backward` / `reader.module.switch`（settings.overlay）|
| `sync-backup` / `webdav-config` / `sync-error` | `app.route.push.forward` / `state.loading.inline` |
| `restore-scopes` / `restore-preview` | `app.route.push.forward` |
| `restore-running` / `restore-progress` | `state.loading.inline` |
| `restore-result` / `restore-conflict` / `restore-confirm` | `app.route.push.forward` / `overlay.dialog.enter` / `overlay.dialog.exit` |
| `source-management` / `source-detail` / `source-add` / `source-edit` / `source-delete-confirm` | `app.route.push.forward` / `overlay.dialog.enter` / `overlay.dialog.exit` |
| `source-detect` / `source-debug` / `source-debug-running` / `source-debug-result` | `state.loading.inline` |
| `progress-sync-status` / `progress-sync` | `state.loading.inline` |

### 4.5 FlowShell

| Route | 触发 MotionId |
| --- | --- |
| `rss-original-browser` | `reader.sourceSwitch.open-close`（同源轻浮现）|
| `source-switch`（从 ReaderShell）| `reader.sourceSwitch.open-close` |

### 4.6 全局状态层

| Route / 状态 | 触发 MotionId |
| --- | --- |
| `global-loading` / `state.loading.inline` | `state.loading.inline` |
| `offline-state` / `state-offline` | `state.content.replace` |
| `permission-required` | `overlay.dialog.enter` / `overlay.dialog.exit` |
| Toast 反馈 | `feedback.toast.enter` / `feedback.toast.update` / `feedback.toast.exit` |
| 打断 | `motion.interrupt.cancel` / `motion.interrupt.redirect` / `motion.interrupt.completeThenReplace` |
| 折叠 / 旋转 | `viewport.orientation.prepare` / `viewport.orientation.reshape` / `viewport.orientation.settle` |

## 5. Route × Token 分组映射

来源：[TOKEN_SPEC.md](./TOKEN_SPEC.md) §2 语义 token 分组。

| Route | 主要 Token 分组 |
| --- | --- |
| `app-shell` / `main-tabs` | tab + list + card |
| `bookshelf` / `bookshelf-cover-mode` / `bookshelf-list-mode` / `bookshelf-empty` | card + list + button |
| `discover` | card + list + tab |
| `rss` | list + rss-status + card |
| `settings` / `global-settings` | list + card |
| `book-search` / `search-*` | list + button |
| `book-detail` / `book-detail-toc-preview` / `book-directory` | card + button |
| `immersive-reading` / `reader` / `reader_content` | reading-theme + reading-typography |
| `control-layer-base-v2` | overlay + reading-theme |
| `reader-appearance-overlay-v2` / `reader-full-font` / `reader-full-theme` / `reader-full-layout` / `reader-full-page-turn` | overlay + reading-typography |
| `reader-tts-overlay-v2` / `tts` / `reader-full-tts` | overlay + reading-theme |
| `reader-settings-overlay-v2` / `reader-full-settings` / `reader-full-appearance` | overlay + list |
| `reader-search-overlay-v2` / `content-search` | overlay + list |
| `reader-replace-overlay-v2` / `content-replacement` | overlay + list + button |
| `reader-directory-overlay-v2` / `toc-bookmarks` / `reader-full-directory` | overlay + list |
| `reader-auto-scroll-overlay-v2` / `auto-page` | overlay + reading-theme |
| `source-switch` / `source-switch-results` | overlay + list |
| `reader-night-state-v2` | reading-theme + night-mode |
| `sync-backup` / `webdav-config` / `sync-error` | list + button |
| `restore-*` | list + card + button |
| `source-management` / `source-detail` / `source-add` / `source-edit` | list + button + card |
| `source-debug-*` / `source-logs` / `source-code-view` | list + card |
| `rss-detail` / `rss-original` | list + card |
| `rss-original-browser` | overlay + list |
| `permission-required` | overlay + button |
| `global-loading` / `state.loading.inline` | motion + overlay |
| `offline-state` / `state-offline` | overlay + button |

## 6. 防漂移检查口径

阶段 2 矩阵的检查口径：

1. **schema 完整性**：每个 RouteId 必须在 [route.schema.json](./route.schema.json) enum 中。
2. **Component 覆盖**：每个 RouteId 对应的 ViewState 必须能由 [view-state.schema.json](./view-state.schema.json) ComponentType 组合表达。
3. **MotionId 覆盖**：每个 route 的关键 motion 必须在 [motion.schema.json](./motion.schema.json) enum 中。
4. **Token 分组覆盖**：每个 route 的视觉必须能由 [TOKEN_SPEC.md](./TOKEN_SPEC.md) §2 分组覆盖；不允许使用未分组的 raw 值。
5. **PageState 覆盖**：每个 route 的状态集合必须是 [view-state.schema.json](./view-state.schema.json) PageState enum 子集。

P0 阶段已实现本仓矩阵覆盖检查：`contracts/tests/matrix-coverage.test.mjs`。阶段 3 [PLATFORM_EVIDENCE_SPEC.md](./PLATFORM_EVIDENCE_SPEC.md) 继续定义三端侧检查口径。

## 7. 缺口与下一步

阶段 2 已补全量 RouteId × Shell × ComponentType × PageState × MotionId × Token 分组矩阵。剩余缺口：
- 部分 RouteId（如 `rss-source-export-*` / `rss-source-import-*` 细分链路）的详细组件树未展开，归 P1。
- demo baseline 中 111 个 unknown id 的产品决策不阻塞本文；若后续收敛，应递减。
- 三端源码级矩阵证据归阶段 3 / 各平台仓库。
