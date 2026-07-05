# Core / Host Boundary

状态：Phase 1 P0 可执行参考规格
日期：2026-07-04
权威源：[ARCHITECTURE.md](./ARCHITECTURE.md)、[BOUNDARY_RULES.md](./BOUNDARY_RULES.md)、[STATE_OWNERSHIP.md](./STATE_OWNERSHIP.md)、[core-command.schema.json](./core-command.schema.json)、[core-event.schema.json](./core-event.schema.json)、[host-request.schema.json](./host-request.schema.json)
来源：[CONTRACT_FIRST_NATIVE_UI_PLAN.md](./CONTRACT_FIRST_NATIVE_UI_PLAN.md) §5/§7

本文是 P0 阶段"Core / Host 边界"。归并业务域归属、UiEvent→CoreCommand 映射、HostRequest 能力清单、平台持久化禁令。

## 0. 文档边界

本文覆盖：
- 业务域归属（bookshelf / search history / RSS / content / progress / TTS / sync conflict）
- UiEvent → CoreCommand 触发映射
- HostRequest 能力清单（HTTP / WebView / Cookie / 文件 / 权限 / TTS 等）
- 平台持久化禁令

本文不覆盖：
- 不重复 CoreCommand / CoreEvent / HostRequest enum（以 schema 为准）
- 不写 Reader-Core-Native 的 Rust 实现代码
- 不写 Host Adapter 平台实现代码
- 不规定 Core 内部协议（归 Reader-Core-Native 仓库）

## 1. 业务域归属

每个业务域明确 Owner 与边界。

| 业务域 | Owner | 持久化 | UI 可读 | UI 可写 | 说明 |
| --- | --- | --- | --- | --- | --- |
| 书架（bookshelf list / groups）| Core | Core DB | 经 reducer | 经 CoreCommand | UI 不能直接改 |
| 书籍元信息（bookMeta / chapters）| Core | Core DB | 经 reducer | 经 CoreCommand | `book.parse` / `chapter.list` 返回 |
| 正文（content）| Core | Core 缓存 | 经 reducer | 经 CoreCommand | `content.load` 返回 |
| 阅读进度（progress / location）| Core | Core DB + sync | 经 reducer | 经 CoreCommand | canonical location 在 Core |
| 书源（source）| Core | Core DB | 经 reducer | 经 CoreCommand | `source.save` / `source.delete` |
| 搜索历史（search history）| Core | Core DB | 经 reducer | 经 CoreCommand | 不归平台 SharedPreferences |
| RSS 订阅（rss.subscription）| Core | Core DB | 经 reducer | 经 CoreCommand | `rss.subscription.add/update/delete` |
| RSS 条目（rss.item）| Core | Core 缓存 | 经 reducer | 经 CoreCommand | `rss.item.read` |
| TTS 队列（ttsQueue）| Core | 内存 | 经 reducer | 经 CoreCommand | `tts.queue.plan` 返回 |
| 同步状态（syncStatus）| Core | Core DB | 经 reducer | 经 CoreCommand | `sync.snapshot` 返回 |
| 同步冲突（conflictState）| Core | Core DB | 经 reducer | 经 CoreCommand | `sync.conflict.resolve` |
| 缓存（cache）| Core | Core 文件系统 | 经 reducer | 经 CoreCommand | `cache.clear` / `cache.book.prefetch` |
| 备份 / 恢复（backup / restore）| Core | Core + HostRequest file | 经 reducer | 经 CoreCommand | 备份目标路径经 HostRequest `storage.path` |
| WebDAV 配置（webdavConfig）| Core | Core DB | 经 reducer | 经 CoreCommand | 凭证经 HostRequest `credential.set` |
| UI 状态（route / tab / overlay 等）| Reducer | 不持久化（除 lastTab）| — | UiEvent | 见 [STATE_OWNERSHIP.md](./STATE_OWNERSHIP.md) §3 |
| Ephemeral 状态（dragOffset 等）| Native UI | 不持久化 | — | 平台手势 | 不参与业务判断 |

### 1.1 平台持久化禁令

平台（iOS / Android / HarmonyOS）禁止持久化以下业务数据：

- 书架列表 / 分组
- 书籍元信息 / 章节列表
- 正文内容
- 阅读进度
- 书源
- 搜索历史
- RSS 订阅 / RSS 条目
- TTS 队列
- 同步状态 / 同步冲突
- WebDAV 配置 / 凭证

平台允许持久化：
- `ui-state.lastTab`（最后选中的 tab，下次冷启动恢复）
- `ui-state.readerMode.lastTheme`（最后阅读主题，需 Core 同步前用）
- `reducedMotion` 用户设置（与系统级同步）
- Ephemeral 状态不可持久化

平台持久化必须用：
- iOS：`UserDefaults` / `Keychain`（仅上述允许项）
- Android：`DataStore` / `Keystore`
- HarmonyOS：`preferences` / `HUKS`

平台禁止用业务数据 SQLite / Room / CoreData / 关系型数据库。业务数据库归 Core。

### 1.2 Reader-Core-Native 当前协议对齐状态

来源：[ACCEPTANCE.md](./ACCEPTANCE.md) §6。

CoreCommand / CoreEvent 是 **Reader UI 侧 Core bridge 规划契约**，不等于 Reader-Core-Native 当前协议已完全对齐。后续仍需 Core bridge mapping / 协议收敛，把契约项逐项映射到真实 Core 命令、事件、错误与 Host 边界。

P0 阶段不验证 Core 协议对齐；Phase 5 验收门槛覆盖。

## 2. UiEvent → CoreCommand 映射

Native UI 发 UiEvent → Reducer 处理 → 必要时 emit CoreCommand。下表列出 P0 链路的关键映射。完整 UiEvent 集合见 [ui-event.schema.json](./ui-event.schema.json)。

### 2.1 路由 / Tab

| UiEvent | Reducer 行为 | CoreCommand | 说明 |
| --- | --- | --- | --- |
| `route.push` | 更新 `ui-state.route`，压入子栈 | — | 纯 UI 状态 |
| `route.pop` | 弹出子栈 | — | 纯 UI 状态 |
| `route.popToRoot` | 回到根 | — | 纯 UI 状态 |
| `route.replace` | 替换当前 route | — | 纯 UI 状态 |
| `mainTab.select` | 切换 `ui-state.tab` | — | 持久化 lastTab（平台允许）|
| `app.firstOpen.enter` | 设置 `hasPlayedFirstOpen` | — | 纯 UI 状态 |

### 2.2 书架

| UiEvent | Reducer 行为 | CoreCommand |
| --- | --- | --- |
| `bookshelf.view.switch` | 更新 `bookshelfViewMode` | — |
| `bookshelf.group.select` | 更新 `currentGroup` | — |
| `bookshelf.sortFilter.apply` | 更新 sortFilter | — |
| `bookshelf.groupManagement.create` | — | `bookshelf.group.create` |
| `bookshelf.groupManagement.rename` | — | `bookshelf.group.update` |
| `bookshelf.groupManagement.delete` | — | `bookshelf.group.delete` |
| `bookshelf.localImport.apply` | — | `bookshelf.book.add` + `book.parse` |
| `bookshelf.batchManagement.open` | 进入批量管理 mode | — |
| `book.open` | 进入 `book-detail` | `book.open` + `book.parse` |
| `book.action`（加入书架）| — | `bookshelf.book.add` |
| `book.action`（删除）| 弹删除确认 Dialog | — |
| `book.detail.open` | `route.push` 到 `book-detail` | `source.detail` + `chapter.list` |
| `book.directory.open` | `route.push` 到 `book-directory` | `chapter.list` |
| `book.search.submit` | 更新 `searchQuery` | `source.search` |
| `book.search.scopeChange` | 更新 `searchScope` | — |
| `search.submit` | 更新 `searchQuery` | `source.search` |
| `search.clear` | 清空 `searchQuery` | — |
| `search.result.open` | `route.push` 到 `book-detail` | `book.open` |

### 2.3 阅读

| UiEvent | Reducer 行为 | CoreCommand |
| --- | --- | --- |
| `reader.enter` / `reader.entry.coverToImmersive` / `reader.entry.actionToImmersive` | `route.push` 到 `immersive-reading`，`readerMode = loading` | `book.open` + `content.load` + `reader.location.resolve` |
| `reader.exit` | `route.pop` | `book.close`（可选）|
| `reader.page.next` / `reader.page.prev` | 更新 `readerPageIndex` | `reader.progress.update` |
| `reader.chapter.jump` | 更新 `readerChapterIndex` | `content.load` + `reader.progress.update` |
| `reader.control.toggle` | 切换 `overlay = reader-control / null` | — |
| `reader.control.handlePress` / `reader.control.handleRelease` / `reader.control.handleDrag` | 更新 EphemeralState | — |
| `reader.control.dockLongPress` / `reader.control.dockDrag` / `reader.control.dockRelease` | 更新 `readerDockOffsets` + EphemeralState | — |
| `reader.module.switch` | 切换 overlay（经 null 中转）| — |
| `reader.appearance.open` | `overlay = appearance` | — |
| `reader.settings.open` / `reader.settings.close` | 切换 `overlay = settings / null` | — |
| `reader.directory.open` / `reader.directory.close` | 切换 `overlay = directory / null` | `chapter.list` |
| `reader.contentSearch.open` / `reader.contentSearch.close` | 切换 `overlay = content-search / null` | — |
| `reader.contentReplacement.open` / `reader.contentReplacement.close` | 切换 `overlay = content-replacement / null` | — |
| `reader.sourceSwitch.open` / `reader.sourceSwitch.close` | 切换 `overlay = source-switch / null` | — |
| `source.switch.select` | 更新选中 source | — |
| `source.switch.confirm` | — | `source.save`（切换书源）|
| `reader.nightState.toggle` | 切换 readerMode 派生 | — |
| `reader.bookCache.open` | `route.push` 到 `reader-book-cache` | `cache.book.status` |
| `reader.textSelection.change` | 更新 `readerSelectedText` | — |

### 2.4 TTS / 自动翻页

| UiEvent | Reducer 行为 | CoreCommand |
| --- | --- | --- |
| `reader.tts.start` / `reader.tts.toggle` | `activeSession = tts`，`overlay = tts` | `tts.queue.plan` + `tts.queue.start` |
| `reader.tts.stop` | `activeSession = null`，`overlay = null` | `tts.queue.stop` |
| `reader.autoPage.start` | `activeSession = auto-page` | — |
| `reader.autoPage.stop` | `activeSession = null` | — |
| `reader.session.capsuleEnter` / `reader.session.capsuleExit` / `reader.session.capsuleSwitch` | 更新 session capsule 状态 | — |
| `reader.session.capsuleControlPressToggle` | — | `tts.queue.pause` / `tts.queue.resume` |
| `reader.session.capsuleCountdownTick` | 更新 `readerAutoPageCountdown` | — |
| `reader.session.controlSpaceEnter` / `reader.session.controlSpaceExit` | 切换胶囊锚定 | — |
| `reader.session.ttsStart` | 复合事务 | `tts.queue.plan` + `tts.queue.start` |
| `reader.session.autoPageStart` | 复合事务 | — |
| `tts.queue.start` / `tts.queue.stop` | 同上 | 同上 |

### 2.5 发现 / RSS / 搜索

| UiEvent | Reducer 行为 | CoreCommand |
| --- | --- | --- |
| `discover.sourceType.select` | 更新 `discoverSourceType` | `source.search` |
| `discover.filter.apply` / `discover.filter.reset` | 更新 `discoverFilter` | `source.search` |
| `discover.sort.toggle` | 更新 `discoverSort` | — |
| `discover.entry.select` | `route.push` 到 `book-detail` | `book.open` |
| `discover.refresh` | — | `source.search` |
| `discover.source.bulkEnable` / `discover.source.bulkDisable` / `discover.source.bulkRefresh` | — | `source.save` × N |
| `rss.refresh` | `rssRefreshing = true` | `rss.refresh` |
| `rss.filter.select` / `rss.sourceFilter.select` | 更新 `rssFilter` | `rss.list` |
| `rss.entry.open` | `route.push` 到 `rss-detail` | `rss.item.read` |
| `rss.entry.openOriginal` | `route.push` 到 `rss-original` | `rss.item.read` |
| `rss.entry.openOriginalBrowser` | 触发 HostRequest | `rss.item.read` + HostRequest `webview.open` |
| `rss.subscription.open` / `rss.subscription.add` / `rss.subscription.edit` / `rss.subscription.delete` | overlay / route | `rss.subscription.list` / `rss.subscription.add` / `rss.subscription.update` / `rss.subscription.delete` |
| `rss.ruleSubscription.create` / `rss.ruleSubscription.edit` | — | `rss.subscription.add` / `rss.subscription.update` |
| `rss.favorite.add` / `rss.favorite.remove` | — | `rss.subscription.update` |
| `rss.search.submit` | 更新 `searchQuery` | `rss.list`（带 query）|
| `source.management.open` / `source.detail.open` | route | `source.search` / `source.detail` |
| `source.add.open` / `source.edit.open` | route | — |
| `source.delete.confirm` | — | `source.delete` |
| `source.detect.run` | — | `source.detect` |
| `source.debug.run` | — | `source.debug.run` |
| `source.import.open` / `preview` / `apply` | route | `source.save` × N |
| `source.switch.open` / `source.switch.select` / `source.switch.confirm` | overlay | `source.detail`（select）/ `source.save`（confirm）|
| `source.search.submit` / `source.search.clear` | 更新 query | `source.search` |

### 2.6 设置 / 同步 / 备份

| UiEvent | Reducer 行为 | CoreCommand |
| --- | --- | --- |
| `settings.scope.open` / `settings.scope.close` / `settings.overlay.open` / `settings.overlay.close` | 切换 settings overlay | — |
| `settings.entry.open` | `route.push` 到对应二级页 | — |
| `settings.cache.clear` | — | `cache.clear` |
| `settings.localImport.invoke` | 触发 HostRequest | HostRequest `file.read` |
| `settings.sync.open` | `route.push` 到 `sync-backup` | `sync.snapshot` |
| `settings.webdav.save` | — | `sync.snapshot`（更新 config）+ HostRequest `credential.set` |
| `settings.restore.scopeToggle` / `preview` / `run` | 更新 `restoreSelectedScopes` / route | `sync.pull`（preview）/ `sync.pull`（run）|
| `settings.about.open` | `route.push` 到 `about` | — |
| `sync.run` | — | `sync.push` + `sync.pull` |
| `sync.resolveConflict` | — | `sync.conflict.resolve` |
| `sync.conflict.list` / `sync.conflict.dismiss` | overlay | `sync.snapshot` |
| `sync.snapshot.view` | `route.push` 到 `progress-sync-status` | `sync.snapshot` |
| `webdav.config.open` / `webdav.config.save` / `webdav.config.test` / `webdav.config.clear` | route / overlay | `sync.snapshot` + HostRequest `credential.set` / `credential.delete` |
| `backup.run` / `backup.cancel` | — | `sync.push`（备份）|
| `restore.scopes.open` / `restore.scopes.select` / `restore.scopes.toggle` | route / 更新 `restoreSelectedScopes` | `sync.snapshot` |
| `restore.run` / `restore.cancel` | `route.push` 到 `restore-running` | `sync.pull` |
| `restore.result.view` | `route.push` 到 `restore-result` | — |

## 3. HostRequest 能力清单

来源：[host-request.schema.json](./host-request.schema.json) + [ARCHITECTURE.md](./ARCHITECTURE.md) §3.4。

Core 可以发起 `HostRequest`（`initiator: core`），Reducer 可以发起平台 UI 相关 `HostCommand`（`initiator: reducer`）。Host Adapter 返回结构化结果，不直接改 Core 或 UI 状态。

### 3.1 能力清单与归属

| HostRequest type | initiator | 用途 | 触发场景 |
| --- | --- | --- | --- |
| `http.execute` | core | HTTP 请求 | Core 抓取书源 / RSS |
| `http.cancel` | core | 取消 HTTP | 取消抓取 |
| `webview.open` | reducer | 打开 WebView | `rss-original-browser` / `discover-source-login-web` |
| `webview.close` | reducer | 关闭 WebView | — |
| `webview.evaluate` | reducer | WebView 内执行 JS | 登录态获取 cookie |
| `cookie.get` | core | 读 cookie | 书源登录态 |
| `cookie.set` | core | 写 cookie | — |
| `cookie.clear` | core | 清 cookie | 退出登录 |
| `file.read` | reducer | 读文件 | `settings.localImport.invoke` |
| `file.write` | core | 写文件 | 备份 / 缓存 |
| `file.delete` | core | 删文件 | 缓存清理 |
| `storage.path` | core | 获取存储路径 | 备份目标路径 |
| `credential.get` | core | 读凭证 | WebDAV 密码 |
| `credential.set` | core | 写凭证 | `webdav.config.save` |
| `credential.delete` | core | 删凭证 | `webdav.config.clear` |
| `tts.system.start` | core | 系统 TTS 开始 | `tts.queue.start` 后由 Core 触发 |
| `tts.system.stop` | core | 系统 TTS 停止 | `tts.queue.stop` |
| `tts.system.pause` | core | 系统 TTS 暂停 | `tts.queue.pause` |
| `tts.system.resume` | core | 系统 TTS 恢复 | `tts.queue.resume` |
| `permission.request` | reducer | 请求权限 | `permission-required` route |
| `permission.check` | reducer | 检查权限 | 启动时检查存储 / 通知权限 |
| `background.schedule` | reducer | 后台任务调度 | RSS 后台刷新 |
| `background.cancel` | reducer | 取消后台任务 | — |
| `notification.show` | reducer | 显示通知 | RSS 更新 / TTS 状态 |
| `notification.cancel` | reducer | 取消通知 | — |
| `share.invoke` | reducer | 调用分享 | 分享书籍 / RSS 条目 |
| `clipboard.copy` | reducer | 复制到剪贴板 | 复制章节内容 |
| `clipboard.paste` | reducer | 从剪贴板粘贴 | 粘贴书源 URL |
| `device.vibrate` | reducer | 震动反馈 | 翻页 / 长按反馈（轻触觉）|
| `device.screen.keep-on` | reducer | 屏幕常亮 | 阅读时 / TTS 时 |
| `device.screen.release` | reducer | 释放常亮 | 退出阅读 |

### 3.2 HostRequest 不允许的场景

- Reducer 不能发起 `http.execute`（HTTP 抓取归 Core）
- Reducer 不能发起 `cookie.get / set / clear`（cookie 归 Core）
- Reducer 不能发起 `file.write / delete`（文件写入归 Core；`file.read` 仅用于本地导入）
- Reducer 不能发起 `credential.get / set / delete`（凭证归 Core）
- Reducer 不能发起 `tts.system.*`（系统 TTS 由 Core 控制）
- Core 不能发起 `webview.open / close / evaluate`（WebView 是 UI 行为）
- Core 不能发起 `permission.request / check`（权限弹窗是 UI 行为）
- Core 不能发起 `notification.show`（通知展示由 Reducer 决定）
- Core 不能发起 `share.invoke / clipboard.*`（分享 / 剪贴板是 UI 行为）
- Core 不能发起 `device.vibrate / screen.keep-on / screen.release`（设备行为由 Reducer 决定）

### 3.3 HostResult 处理

Host Adapter 返回 HostResult 给发起方：
- Core 发起 → HostResult 返回 Core → Core 转为 CoreEvent 给 Reducer
- Reducer 发起 → HostResult 返回 Reducer → Reducer 更新 UiState

Host Adapter 不允许：
- 直接改 Core state
- 直接改 UiState
- 直接调用 Reducer
- 持有平台 View 引用

## 4. 事件流（完整链路）

来源：[ARCHITECTURE.md](./ARCHITECTURE.md) §4。

```
Native UI
  -> emit UiEvent

Platform Interaction Reducer
  -> update UiState
  -> emit CoreCommand（必要时）
  -> emit HostCommand（必要时，initiator=reducer）

Reader-Core-Native
  -> return CoreEvent（成功 / 失败）
  -> emit HostRequest（必要时，initiator=core）

Host Adapter
  -> return HostResult（给 Core 或 Reducer）

Platform Interaction Reducer
  -> merge CoreEvent / HostResult
  -> produce ViewState

Native UI
  -> render ViewState
```

### 4.1 异常处理

| 失败源 | 处理 |
| --- | --- |
| CoreEvent `*.failed` | Reducer 设置 `pageState = error` + `error = { code, message, retryable }` |
| HostResult 失败 | Reducer 设置 `error`；不传播到 Core |
| Core 内部 panic | Core 返回 `*.failed` + `error.retryable = false` |
| 网络不可用 | Core 返回 `*.failed` 含 `error.code = NETWORK_UNAVAILABLE`；Reducer 设置 `pageState = offline` |
| 权限缺失 | Reducer 设置 `pageState = permission`；不发起 CoreCommand |
| 取消（cancellation）| Reducer 收到 CoreEvent `*.failed` with `error.code = CANCELLED`；discard guard 跳过旧 result |

### 4.2 async guard

来源：[state-rule.fixtures.json](./fixtures/state-rule.fixtures.json)。

- `appState.asyncRouteRequest` 存在时屏蔽重复路由请求
- request-scoped async state 必须有 cancellation/discard guards
- `loading=true` 时禁止 `route.push`（state-rule fixtures loading async guard）
- `overlay` 打开时禁止 `mainTab.select`（state-rule fixtures overlay async guard）
- `search.loading` 时禁止重复 `search.submit`
- `sync.loading` 时禁止 `route.push`
- `restore.loading` 时禁止 `route.push`
- 首次开屏 `firstOpenMotion` 期间禁止 `route.push`

## 5. Core bridge mapping（P0 不阻塞）

Reader UI 侧 CoreCommand / CoreEvent 是规划契约。Core bridge mapping 是把契约项逐项映射到 Reader-Core-Native 真实命令、事件、错误与 Host 边界的过程。

P0 阶段不要求 Core bridge mapping 完成。Phase 5 验收门槛要求：
- 每个 CoreCommand 对应 Reader-Core-Native 真实命令（或明确标记 `unimplemented`）
- 每个 CoreEvent 对应 Reader-Core-Native 真实事件
- 每个 HostRequest 对应平台 Host Adapter 实现
- 错误码统一（Core 返回 `error.code` enum）

Core bridge mapping 归 Reader-Core-Native 仓库，不在本仓范围内。

## 6. 缺口与下一步

P0 阶段已补业务域归属 + UiEvent→CoreCommand 映射 + HostRequest 能力清单 + 平台持久化禁令。剩余缺口：
- Core bridge mapping（Phase 5，归 Reader-Core-Native）
- 错误码 enum 统一（Phase 2 收尾或 Phase 5）
- 部分边缘 UiEvent（如 `tooling.mode.switch` / `selection.*`）未在映射表中展开，归阶段 2 [ROUTE_COMPONENT_MATRIX.md](./ROUTE_COMPONENT_MATRIX.md)
