# Slice Plan

状态：Phase 3 三端开发切片
日期：2026-07-04
权威源：[CONTRACT_FIRST_NATIVE_UI_PLAN.md](./CONTRACT_FIRST_NATIVE_UI_PLAN.md) §9、[PAGE_REFERENCE.md](./PAGE_REFERENCE.md)、[MOTION_SPEC.md](./MOTION_SPEC.md)、[CORE_HOST_BOUNDARY.md](./CORE_HOST_BOUNDARY.md)、[PLATFORM_EVIDENCE_SPEC.md](./PLATFORM_EVIDENCE_SPEC.md)
来源：[frontend-demo/MOTION_IMPLEMENTATION_GAP_AUDIT.md](../frontend-demo/MOTION_IMPLEMENTATION_GAP_AUDIT.md) UI/Platform Ownership Split

本文是阶段 3"三端开发切片"。定义 Slice 0..N 启动顺序、每个 slice 的输入文档、每端必须产出的源码/测试/截图/录屏/设备证据、并行/串行约束。

## 0. 文档边界

本文覆盖：
- Slice 0..N 启动顺序与依赖
- 每个 slice 的输入文档清单
- 每端（iOS / Android / HarmonyOS）必须产出的源码、测试、截图/录屏/设备证据
- 哪些 slice 可并行，哪些必须等 Core bridge 或 contract 先定

本文不覆盖：
- 不写三端实现代码（归各端仓库）
- 不规定具体排期（归各端项目管理）
- 不重复 slice 内的契约内容（见各 slice 输入文档）

## 1. Slice 总览

| Slice | 名称 | 依赖 | 三端可并行？ |
| --- | --- | --- | --- |
| Slice 0 | 契约 + 工具链接入 | 无 | 是（三端各自接入 generated types）|
| Slice 1 | AppShell + main tabs | Slice 0 | 是 |
| Slice 2 | Bookshelf → open book → reader surface | Slice 1 + Core `book.open / content.load / reader.location.resolve` | 是（Core bridge 串行先定）|
| Slice 3 | Reader overlay / control dock / reader mode | Slice 2 | 是 |
| Slice 4 | Progress / session / focus / TTS | Slice 3 + Core `tts.queue.* / reader.progress.update` | 是 |
| Slice 5 | RSS / source / search | Slice 1 + Core `rss.* / source.search` | 是（与 Slice 2-4 并行）|
| Slice 6 | Sync / conflict / offline state | Slice 5 + Core `sync.* / sync.conflict.resolve` | 是 |
| Slice 7 | Host Adapter 补齐 | Slice 0-6 按需 | 是（按 HostRequest 能力并行）|
| Slice 8 | 一致性验证 + 防漂移 | Slice 1-6 完成 | — |

每个 slice 必须三端一起验收，不允许单端无限向前跑（来源：[CONTRACT_FIRST_NATIVE_UI_PLAN.md](./CONTRACT_FIRST_NATIVE_UI_PLAN.md) §9 Phase 3）。

## 2. Slice 0：契约 + 工具链接入

### 2.1 输入文档

- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [BOUNDARY_RULES.md](./BOUNDARY_RULES.md)
- [STATE_OWNERSHIP.md](./STATE_OWNERSHIP.md)
- [CONTRACT_VERSIONING.md](./CONTRACT_VERSIONING.md)
- [CORE_HOST_BOUNDARY.md](./CORE_HOST_BOUNDARY.md)
- [generated/](../generated/) 三端 generated types
- [ffi-protocol-version.md](./ffi-protocol-version.md)

### 2.2 每端交付物

**iOS（SwiftUI）**：
- 源码：
  - `ReaderUIContract` Swift package 接入（from generated/swift/）
  - `ReaderReducer.swift`、`ReaderViewState.swift`、`ReaderCoordinator.swift`、`ReaderCoreBridge.swift`、`HostAdapter.swift` 文件骨架
- 测试：
  - generated types 编译通过
  - `contractConsistencyTest.swift`（校验 generated 与 schema 一致）
- 证据：`slice-0-ios-types-compile.png`（Xcode 编译成功截图）

**Android（Compose）**：
- 源码：
  - `ReaderUIContract` Kotlin module 接入（from generated/kotlin/）
  - `ReaderReducer.kt`、`ReaderUiState.kt`、`ReaderCoordinator.kt`、`ReaderCoreBridge.kt`、`HostAdapter.kt` 文件骨架
- 测试：
  - generated types 编译通过
  - `ContractConsistencyTest.kt`
- 证据：`slice-0-android-types-compile.png`（Android Studio 编译成功截图）

**HarmonyOS（ArkUI）**：
- 源码：
  - `ReaderUIContract` ArkTS module 接入（from generated/arkts/）
  - `ReaderReducer.ets`、`ReaderViewState.ets`、`AppStateStore`、`ReaderNapiBridge.ets`、`HostAdapter.ets` 文件骨架
- 测试：
  - generated types 编译通过
  - `contract_consistency.test.ets`
- 证据：`slice-0-harmony-types-compile.png`（DevEco Studio 编译成功截图）

### 2.3 验收门槛

- 三端 generated types 编译通过
- 三端 reducer / coordinator / bridge / host adapter 文件骨架就位
- `node --test contracts/tests/*.test.mjs` 全绿
- 三端各自仓库 `slice-0-*-types-compile.png` 提交

## 3. Slice 1：AppShell + main tabs

### 3.1 输入文档

- [PAGE_REFERENCE.md](./PAGE_REFERENCE.md) §3 Slice 1
- [MOTION_SPEC.md](./MOTION_SPEC.md) §2.1 §2.2（app.firstOpen / tab / bookshelf.view.switch）
- [TOKEN_SPEC.md](./TOKEN_SPEC.md) §2.6 tab 组、§2.3 卡片组、§2.4 列表组
- [ROUTE_COMPONENT_MATRIX.md](./ROUTE_COMPONENT_MATRIX.md) §1.1 MainTabShell
- [CORE_HOST_BOUNDARY.md](./CORE_HOST_BOUNDARY.md) §2.1 路由/Tab 映射

### 3.2 范围

- `app-shell` + 4 个主 Tab（bookshelf / discover / rss / settings）根页面
- 底部导航 `BottomNav`
- Tab 切换 motion（`tab.item.select` / `tab.switch`）
- 冷启动 `app.firstOpen.enter`
- 状态层 `Loading / Empty / Error / Offline`

### 3.3 每端交付物

**iOS**：
- 源码：`AppShellView.swift`、`MainTabView.swift`、`BottomNavView.swift`、`BookshelfRootView.swift`、`DiscoverRootView.swift`、`RssRootView.swift`、`SettingsRootView.swift`
- 测试：`AppShellReducerTest.swift`（golden test，覆盖 tab 切换 / firstOpen / 状态层）
- 证据：
  - `slice-1-ios-cold-start.mov`（冷启动录屏）
  - `slice-1-ios-tab-switch.mov`（Tab 切换录屏）
  - `slice-1-ios-states.png`（4 个 Tab 的 default / loading / empty / error 截图）

**Android**：
- 源码：`AppShell.kt`、`MainTabScreen.kt`、`BottomNav.kt`、`BookshelfRootScreen.kt`、`DiscoverRootScreen.kt`、`RssRootScreen.kt`、`SettingsRootScreen.kt`
- 测试：`AppShellReducerTest.kt`
- 证据：`slice-1-android-cold-start.mov`、`slice-1-android-tab-switch.mov`、`slice-1-android-states.png`

**HarmonyOS**：
- 源码：`AppShell.ets`、`MainTabs.ets`、`BottomNav.ets`、`BookshelfRoot.ets`、`DiscoverRoot.ets`、`RssRoot.ets`、`SettingsRoot.ets`
- 测试：`app_shell_reducer.test.ets`
- 证据：`slice-1-harmony-cold-start.mov`、`slice-1-harmony-tab-switch.mov`、`slice-1-harmony-states.png`（真机或模拟器）

### 3.4 验收门槛

- 三端 AppShell + 4 Tab 可启动
- Tab 切换 motion 一致（duration / easing / 互斥与 [MOTION_SPEC.md](./MOTION_SPEC.md) 一致）
- 状态层 4 种（loading / empty / error / offline）可触发
- 冷启动 firstOpen 只播一次
- 三端 reducer golden test 通过

## 4. Slice 2：Bookshelf → open book → reader surface

### 4.1 输入文档

- [PAGE_REFERENCE.md](./PAGE_REFERENCE.md) §4 Slice 2
- [MOTION_SPEC.md](./MOTION_SPEC.md) §2.3 reader.entry / page.turn / chapter.jump
- [TOKEN_SPEC.md](./TOKEN_SPEC.md) §2.1 reading-theme、§2.2 reading-typography
- [ROUTE_COMPONENT_MATRIX.md](./ROUTE_COMPONENT_MATRIX.md) §1.2 LibraryShell、§1.3 ReaderShell
- [CORE_HOST_BOUNDARY.md](./CORE_HOST_BOUNDARY.md) §2.2 书架、§2.3 阅读

### 4.2 范围

- `bookshelf` → `book-detail` → `immersive-reading`
- 书架搜索 `book-search`
- 书籍详情 / 目录
- 沉浸阅读主页（ReadingTextFlow + TapZones）
- 翻页 motion + 章节跳转

### 4.3 依赖

- Core bridge 必须先定：`book.open / book.parse / chapter.list / content.load / reader.location.resolve / reader.progress.update / source.detail / source.search / bookshelf.list`
- 三端 Core bridge mapping 至少完成上述命令的对齐

### 4.4 每端交付物

**iOS**：
- 源码：`BookshelfRootView.swift`（扩展）、`BookSearchView.swift`、`BookDetailView.swift`、`BookDirectoryView.swift`、`ImmersiveReadingView.swift`、`ReadingTextFlow.swift`、`TapZonesView.swift`、`ReaderReducer+content.swift`
- 测试：`ReaderEntryReducerTest.swift`（golden test，cover entry / page turn / chapter jump）
- 证据：
  - `slice-2-ios-bookshelf-to-reader.mov`（书架→详情→沉浸阅读链路）
  - `slice-2-ios-page-turn.mov`（翻页录屏，含 next / prev）
  - `slice-2-ios-chapter-jump.mov`（章节跳转录屏）
  - `slice-2-ios-reader-states.png`（readerMode: default / loading / empty / error / offline）

**Android**：
- 源码：`BookshelfRootScreen.kt`（扩展）、`BookSearchScreen.kt`、`BookDetailScreen.kt`、`BookDirectoryScreen.kt`、`ImmersiveReadingScreen.kt`、`ReadingTextFlow.kt`、`TapZones.kt`
- 测试：`ReaderEntryReducerTest.kt`
- 证据：`slice-2-android-*.mov / .png`（同 iOS）

**HarmonyOS**：
- 源码：`BookshelfRoot.ets`（扩展）、`BookSearch.ets`、`BookDetail.ets`、`BookDirectory.ets`、`ImmersiveReading.ets`、`ReadingTextFlow.ets`、`TapZones.ets`
- 测试：`reader_entry_reducer.test.ets`
- 证据：`slice-2-harmony-*.mov / .png`（同 iOS，真机或模拟器）

### 4.5 验收门槛

- 书架 → 详情 → 沉浸阅读链路可走通
- 翻页 motion 与 [MOTION_SPEC.md](./MOTION_SPEC.md) §2.3 一致（duration / 方向 / reduced-motion）
- 章节跳转可触发
- 阅读进度经 Core `reader.progress.update` 更新
- canonical location 覆盖本地 readerPageIndex 派生
- 三端 reducer golden test 通过

## 5. Slice 3：Reader overlay / control dock / reader mode

### 5.1 输入文档

- [PAGE_REFERENCE.md](./PAGE_REFERENCE.md) §5 Slice 3
- [MOTION_SPEC.md](./MOTION_SPEC.md) §2.4 阅读控制层、§2.6 Overlay
- [TOKEN_SPEC.md](./TOKEN_SPEC.md) §2.7 overlay 组
- [ROUTE_COMPONENT_MATRIX.md](./ROUTE_COMPONENT_MATRIX.md) §1.3 ReaderShell overlay
- [CORE_HOST_BOUNDARY.md](./CORE_HOST_BOUNDARY.md) §2.3 阅读 overlay 部分

### 5.2 范围

- `control-layer-base-v2` + 9 个 reader overlay（appearance / tts / settings / content-search / content-replacement / directory / auto-page / source-switch / night-state）
- 控制层 handle / dock 拖拽
- overlay 互斥 + transition-guard
- focus 恢复

### 5.3 每端交付物

**iOS**：
- 源码：`ControlLayerView.swift`、`ReaderOverlayContainer.swift`、`ReaderAppearanceOverlay.swift`、`ReaderTtsOverlay.swift`、`ReaderSettingsOverlay.swift`、`ContentSearchOverlay.swift`、`ContentReplacementOverlay.swift`、`ReaderDirectoryOverlay.swift`、`AutoPageOverlay.swift`、`SourceSwitchOverlay.swift`、`ReaderControlHandle.swift`、`ReaderControlDock.swift`、`ReaderReducer+overlay.swift`
- 测试：`ReaderOverlayReducerTest.swift`（golden test，覆盖 overlay 互斥 / transition-guard / focus 恢复 / handle drag 阈值 / dock drag bounds）
- 证据：
  - `slice-3-ios-control-layer.mov`（控制层开关 + handle 拖拽）
  - `slice-3-ios-overlay-switch.mov`（overlay 互斥切换）
  - `slice-3-ios-dock-drag.mov`（宽屏 dock 长按拖拽，真机或模拟器）
  - `slice-3-ios-focus-restore.mov`（focus 恢复录屏）

**Android** / **HarmonyOS**：同 iOS 对应文件。

### 5.4 验收门槛

- 9 个 overlay 可独立打开 / 关闭
- overlay 互斥规则成立（一次只一个，经 null 中转）
- handle drag 阈值与 [MOTION_SPEC.md](./MOTION_SPEC.md) §3.1 一致
- dock drag bounds 不跨 hinge / 安全区
- focus 恢复正确
- 三端 reducer golden test 通过

## 6. Slice 4：Progress / session / focus / TTS

### 6.1 输入文档

- [PAGE_REFERENCE.md](./PAGE_REFERENCE.md) §6 Slice 4
- [MOTION_SPEC.md](./MOTION_SPEC.md) §2.5 阅读会话胶囊
- [CORE_HOST_BOUNDARY.md](./CORE_HOST_BOUNDARY.md) §2.4 TTS / 自动翻页
- [PLATFORM_EVIDENCE_SPEC.md](./PLATFORM_EVIDENCE_SPEC.md) TTS evidence 要求

### 6.2 范围

- TTS session（`activeSession = tts`）
- auto-page session（`activeSession = auto-page`）
- 运行胶囊（capsule）
- 控制层上方胶囊锚定（controlSpace）
- 进度更新链路

### 6.3 依赖

- Core bridge 必须先定：`tts.queue.plan / start / pause / resume / stop / seek`、`reader.progress.update / snapshot`
- HostRequest `tts.system.*` 必须三端实现

### 6.4 每端交付物

- 源码：`ReaderSessionCapsule.swift / .kt / .ets`、`ReaderControlSpace.swift / .kt / .ets`、`TtsController.swift / .kt / .ets`、`AutoPageController.swift / .kt / .ets`、`ReaderReducer+session.swift / .kt / .ets`
- 测试：`ReaderSessionReducerTest.swift / .kt / .ets`（覆盖 TTS / auto-page 互斥 / capsule enter/exit/switch / controlSpace 锚定 / 进度更新）
- 证据：
  - `slice-4-*-tts-start-stop.mov`（TTS 启动 / 停止录屏）
  - `slice-4-*-auto-page.mov`（自动翻页录屏）
  - `slice-4-*-capsule-switch.mov`（TTS ↔ auto-page 互斥切换）
  - `slice-4-*-control-space.mov`（控制层上方胶囊锚定）
  - `slice-4-*-progress-update.mov`（翻页触发 progress 更新）

### 6.5 验收门槛

- TTS 启动后 `activeSession = tts`，胶囊显示，控制层关闭
- TTS 与 auto-page 互斥
- 胶囊切换时尺寸不抖动
- 控制层上方胶囊锚定正确
- 翻页触发 `reader.progress.update`，Core 返回 canonical location 覆盖本地派生
- 系统 TTS 真机可播放（不是 demo proof）
- 三端 reducer golden test 通过

## 7. Slice 5：RSS / source / search

### 7.1 输入文档

- [PAGE_REFERENCE.md](./PAGE_REFERENCE.md) §7 Slice 5
- [ROUTE_COMPONENT_MATRIX.md](./ROUTE_COMPONENT_MATRIX.md) §1.4 SettingsShell source、§1.7 DiscoverShell、§1.8 RSS 子 route
- [CORE_HOST_BOUNDARY.md](./CORE_HOST_BOUNDARY.md) §2.5 发现 / RSS / 搜索

### 7.2 范围

- RSS 列表 / 详情 / 原文 / 浏览器
- 书源管理 / 调试 / 导入 / 导出
- 发现页（搜索 / 筛选 / 排序）
- 搜索历史（归 Core）

### 7.3 依赖

- Core bridge：`rss.* / rss.subscription.* / source.search / source.detail / source.save / source.delete / source.detect / source.debug.run`
- HostRequest `webview.open`（rss-original-browser）

### 7.4 每端交付物

- 源码：`RssRoot*.swift / .kt / .ets`、`RssDetail*.swift / .kt / .ets`、`SourceManagement*.swift / .kt / .ets`、`SourceDebug*.swift / .kt / .ets`、`DiscoverRoot*.swift / .kt / .ets`、`BookSearch*.swift / .kt / .ets`
- 测试：`RssReducerTest.*`、`SourceReducerTest.*`、`DiscoverReducerTest.*`
- 证据：
  - `slice-5-*-rss-list-detail.mov`
  - `slice-5-*-source-management.mov`
  - `slice-5-*-source-debug.mov`
  - `slice-5-*-discover-search.mov`
  - `slice-5-*-book-search.mov`

### 7.5 验收门槛

- RSS 列表 / 详情可走通
- RSS 原文浏览器经 HostRequest `webview.open`
- 书源管理 CRUD 可走通
- 书源调试可执行
- 发现页搜索 / 筛选 / 排序可走通
- 搜索历史由 Core 持久化（不归平台）
- 三端 reducer golden test 通过

## 8. Slice 6：Sync / conflict / offline state

### 8.1 输入文档

- [PAGE_REFERENCE.md](./PAGE_REFERENCE.md) §8 Slice 6
- [ROUTE_COMPONENT_MATRIX.md](./ROUTE_COMPONENT_MATRIX.md) §1.4 SettingsShell restore
- [CORE_HOST_BOUNDARY.md](./CORE_HOST_BOUNDARY.md) §2.6 设置 / 同步 / 备份

### 8.2 范围

- 同步 / 备份 / 恢复
- WebDAV 配置
- 同步冲突解决
- offline 状态

### 8.3 依赖

- Core bridge：`sync.snapshot / sync.push / sync.pull / sync.conflict.resolve`
- HostRequest `credential.get / set / delete`、`file.write / read`、`storage.path`

### 8.4 每端交付物

- 源码：`SyncBackup*.swift / .kt / .ets`、`WebdavConfig*.swift / .kt / .ets`、`Restore*.swift / .kt / .ets`、`ConflictResolver*.swift / .kt / .ets`、`OfflineState*.swift / .kt / .ets`
- 测试：`SyncReducerTest.*`、`ConflictResolverTest.*`
- 证据：
  - `slice-6-*-sync-push-pull.mov`
  - `slice-6-*-webdav-config.mov`
  - `slice-6-*-restore-flow.mov`
  - `slice-6-*-conflict-resolve.mov`
  - `slice-6-*-offline-state.mov`

### 8.5 验收门槛

- 同步 push / pull 可走通
- WebDAV 配置保存后凭证经 HostRequest `credential.set`
- 恢复 scopes 选择 → preview → running → result 链路完整
- 冲突解决可走通（5 种 resolution）
- offline 状态不阻断本地查看
- 三端 reducer golden test 通过

## 9. Slice 7：Host Adapter 补齐

### 9.1 输入文档

- [CORE_HOST_BOUNDARY.md](./CORE_HOST_BOUNDARY.md) §3 HostRequest 能力清单
- [host-request.schema.json](./host-request.schema.json)
- [ffi-protocol-version.md](./ffi-protocol-version.md)

### 9.2 范围

按 [CONTRACT_FIRST_NATIVE_UI_PLAN.md](./CONTRACT_FIRST_NATIVE_UI_PLAN.md) §9 Phase 4 优先顺序：

1. HTTP（`http.execute / cancel`）
2. Cookie（`cookie.get / set / clear`）
3. WebView（`webview.open / close / evaluate`）
4. File / storage path（`file.read / write / delete / storage.path`）
5. Credential（`credential.get / set / delete`）
6. TTS（`tts.system.start / stop / pause / resume`）
7. Background task（`background.schedule / cancel`）
8. Notification / share（`notification.show / cancel / share.invoke / clipboard.*`）

### 9.3 依赖

- Slice 0-6 按需：每个 slice 用到的 HostRequest 必须在 Slice 7 对应能力补齐前可用
- Slice 4 TTS 依赖 #6 TTS 能力
- Slice 5 RSS 原文浏览器依赖 #3 WebView 能力
- Slice 6 同步依赖 #4 File / #5 Credential 能力

### 9.4 每端交付物

- 源码：`HostAdapter.swift / .kt / .ets` 完整实现，覆盖 30 个 HostRequest type
- 测试：`HostAdapterTest.*`（每个能力至少一个 happy path + 一个 error path）
- 证据：`slice-7-*-host-adapter-coverage.png`（能力覆盖矩阵截图）

### 9.5 验收门槛

- 30 个 HostRequest type 三端全部实现
- 每个能力有 happy + error path 测试
- HostAdapter 不直接改 Core 或 UI 状态
- initiator 边界成立（reducer 不发起 core-only 能力，反之亦然）

## 10. Slice 8：一致性验证 + 防漂移

### 10.1 输入文档

- [ACCEPTANCE.md](./ACCEPTANCE.md)
- [PLATFORM_EVIDENCE_SPEC.md](./PLATFORM_EVIDENCE_SPEC.md)
- [ROUTE_COMPONENT_MATRIX.md](./ROUTE_COMPONENT_MATRIX.md) §6 防漂移检查口径

### 10.2 范围

- contract test（已有，本仓 `contracts/tests/`）
- reducer golden test（三端）
- core protocol test（Reader-Core-Native）
- device smoke test（三端真机）
- 防漂移自动检查（demo / generated / schema 一致性）

### 10.3 依赖

- Slice 1-6 完成
- Slice 7 Host Adapter 完成
- Core bridge mapping 完成

### 10.4 每端交付物

- 测试：全量 reducer golden test、core protocol test、device smoke test
- 证据：
  - `slice-8-*-device-smoke.mov`（真机冷启动 → bookshelf → 打开书 → reader → 翻页 → 控制层 → readerMode → 进度更新 → TTS → 退出再进入 → 同步进度，覆盖 [CONTRACT_FIRST_NATIVE_UI_PLAN.md](./CONTRACT_FIRST_NATIVE_UI_PLAN.md) §9 Phase 5 最低验收链路）
  - `slice-8-*-accessibility.mov`（VoiceOver / TalkBack / 屏幕阅读器 focus 迁移录屏）
  - `slice-8-*-reduced-motion.mov`（reduced-motion 降级录屏）
  - `slice-8-*-fold-orientation.mov`（折叠屏 / 旋转录屏，真机或模拟器）

### 10.5 验收门槛

- [CONTRACT_FIRST_NATIVE_UI_PLAN.md](./CONTRACT_FIRST_NATIVE_UI_PLAN.md) §10 合并门槛 7 问全部答 yes
- 三端 device smoke test 通过
- 防漂移自动检查脚本全绿（见 [PLATFORM_EVIDENCE_SPEC.md](./PLATFORM_EVIDENCE_SPEC.md)）
- 三端无 raw color / spacing / radius / duration（grep + AST 检查）

## 11. 并行 / 串行约束

### 11.1 可并行的 slice

- Slice 0：三端各自接入 generated types，完全并行
- Slice 1：三端各自实现 AppShell + 4 Tab，完全并行
- Slice 2-6：三端各自实现，但依赖 Core bridge 先定对应命令
- Slice 5 可与 Slice 2-4 并行（不同业务域）
- Slice 7 Host Adapter 各能力可并行实现

### 11.2 必须串行的 slice

- Slice 1 → Slice 2（bookshelf → reader 需要 Slice 1 的 AppShell）
- Slice 2 → Slice 3（reader overlay 需要 Slice 2 的 immersive-reading）
- Slice 3 → Slice 4（session 胶囊需要 Slice 3 的控制层）
- Slice 6 需要 Slice 5（sync 需要 source / rss 链路先定）
- Slice 8 需要 Slice 1-7 全部完成

### 11.3 Core bridge 串行约束

每个 slice 的 Core bridge 必须先于该 slice 实现：

| Slice | 必须先定的 Core 命令 |
| --- | --- |
| Slice 2 | `book.open / book.parse / chapter.list / content.load / reader.location.resolve / reader.progress.update / source.detail / source.search / bookshelf.list` |
| Slice 4 | `tts.queue.plan / start / pause / resume / stop / seek` |
| Slice 5 | `rss.* / source.search / source.detail / source.save / source.delete / source.detect / source.debug.run` |
| Slice 6 | `sync.snapshot / sync.push / sync.pull / sync.conflict.resolve` |

Core bridge mapping 归 Reader-Core-Native 仓库。如果某 slice 的 Core 命令未对齐，三端 reducer 可以先用 mock Core bridge 实现，但 device smoke test 必须用真实 Core。

## 12. 三端禁止项

每个 slice 三端实现禁止：

- 禁止绕过 generated types 自己手写 RouteId / MotionId / ComponentType enum
- 禁止在组件代码中硬编码 raw color / spacing / radius / duration（见 [TOKEN_SPEC.md](./TOKEN_SPEC.md) §4）
- 禁止 UI 直接调用 Core（必须经 reducer + CoreCommand）
- 禁止 UI 直接持久化业务数据（见 [CORE_HOST_BOUNDARY.md](./CORE_HOST_BOUNDARY.md) §1.1）
- 禁止用 Web CSS / DOM 行为作为实现依据（见 [MOTION_SPEC.md](./MOTION_SPEC.md) §5）
- 禁止单端无限向前跑（每个 slice 三端一起验收）

## 13. 缺口与下一步

阶段 3 SLICE_PLAN 已定义 Slice 0-8 启动顺序 + 输入文档 + 每端交付物 + 并行/串行约束。剩余缺口：
- 实际排期归各端项目管理
- Core bridge mapping 完成时间归 Reader-Core-Native 仓库
- 真机 / 模拟器 evidence 归各端仓库（见 [PLATFORM_EVIDENCE_SPEC.md](./PLATFORM_EVIDENCE_SPEC.md)）
