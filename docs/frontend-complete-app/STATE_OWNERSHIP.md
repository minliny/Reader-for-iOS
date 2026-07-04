# State Ownership

状态：Phase 0 状态归属冻结
日期：2026-07-04
权威源：[ARCHITECTURE.md](./ARCHITECTURE.md)、[CONTRACT_FIRST_NATIVE_UI_PLAN.md](./CONTRACT_FIRST_NATIVE_UI_PLAN.md) §2

本文冻结三层状态的归属、字段范围与跨层规则。schema 必须按本文字段范围定义。

## 1. 三层状态定义

| 层 | Owner | 内容 |
| --- | --- | --- |
| DomainState | Reader-Core-Native | bookId、chapterId、content、progress、source、rssItem、ttsQueue、syncStatus、conflictState |
| UiState | Platform Interaction Reducer | route、tab、readerMode、overlay、activeSession、focusTarget、loading、error、reducedMotion |
| EphemeralState | Native UI | dragOffset、scrollPixel、layoutMeasurement、pressedState、textSelection、accessibilityFocus |

## 2. DomainState 字段范围

Owner：Reader-Core-Native。本仓库不定义其 schema，只定义 UI 侧引用约束。

- `bookId` / `chapterId`：书籍与章节标识。
- `content`：章节正文。
- `progress`：阅读进度，以 Core 的 canonical location 为准。
- `source`：当前书源。
- `rssItem`：RSS 条目。
- `ttsQueue`：TTS 队列。
- `syncStatus`：同步状态。
- `conflictState`：同步冲突状态。

规则：

- UI 不能直接改 DomainState。
- 平台可以提供视觉排版测量，但不能各自发明业务进度模型。
- 阅读进度以 Core 的 canonical location 为准。

## 3. UiState 字段范围

Owner：Platform Interaction Reducer。本仓库通过 `ui-state.schema.json` 定义。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `route` | RouteId | 当前路由 id，必须存在于 `route.schema.json` |
| `tab` | enum | 主 Tab：`bookshelf / discover / rss / settings` |
| `readerMode` | enum | 阅读模式：`default / loading / empty / error / offline / permission` |
| `overlay` | enum \| null | 当前 overlay：`null / settings / reader-control / directory / tts / appearance / auto-page / content-search / content-replacement / source-switch / book-action / sort-filter / group-management / local-import` |
| `activeSession` | enum \| null | 阅读会话：`null / reading / tts / auto-page` |
| `focusTarget` | string \| null | 当前焦点目标 id |
| `loading` | boolean | 全局 loading 标志 |
| `error` | object \| null | 错误信息：`{ code, message, retryable }` |
| `reducedMotion` | boolean | 是否启用减少动态效果 |

页面级派生 UiState（来自 Reader UI frontend-demo/render-runtime.js 的 `appState.*`）：

- `discoverFilter` / `discoverSort` / `discoverSortOpen`
- `readerTurnDirection`：`next / prev`
- `readerPageIndex` / `readerChapterIndex` / `readerChapterProgress`
- `readerChapterDownloads[key]`：`loading / complete / cached`
- `readerTts` / `readerSettings` / `readerTypography`
- `readerTextSelectionOpen` / `readerSelectedText`
- `readerSessionCapsuleSnapshot` / `readerControlSpaceSnapshot`
- `readerAutoPageCountdown`
- `settingsOverlay` / `settingsExpandedOption`
- `motionOverlaySequence` / `motionOverlayRole` / `motionOverlayAction` / `motionOverlayFocusReturn` / `motionOverlayReturnTarget`
- `viewportOrientationMotion` / `Sequence` / `Timer`
- `motionInterruptMotion` / `Sequence` / `Timer`
- `dropdownMotion` / `dropdownSwitchMotion` / `dropdownSwitchSequence` / `dropdownSwitchTimer`
- `segmentMotion`
- `readerEntryMotion`
- `asyncRouteRequest` / `asyncResultMotion` / `asyncResultSequence`
- `hasPlayedFirstOpen` / `firstOpenMotionTimer`
- `sourceEnabled[item.title]`
- `restoreAvailableScopes` / `restoreSelectedScopes`
- `readerDockOffsets[key]`

页面级状态枚举（来自各页 04-状态规则稿.md）：

- 通用：`default / loading / empty / error / offline / permission`
- 书架特有：`默认封面模式 / 默认列表模式 / 空书架 / loading / error / 无封面 / 长书名`
- 发现：`默认 / 切换来源类型 / 来源无内容 / 来源不可用 / 网络失败`
- RSS：`默认 / 刷新中 / 无订阅 / 无未读 / 网络失败`
- 设置：`默认 / 局部数据加载 / 无备份 / 权限缺失 / 顶栏动作`

## 4. EphemeralState 字段范围

Owner：Native UI。本仓库不为其生成 schema，但定义约束。

允许保留在平台 UI 内：

- `dragOffset` / `scrollPixel` / `layoutMeasurement` / `pressedState` / `textSelection` / `accessibilityFocus`

规则：

- EphemeralState 不能参与业务判断。
- 不能持久化。
- 不能跨页面共享。
- slider / progress / stepper 拖动中必须跟手无 easing，释放后才 snap/commit/重新测量。
- `reader.control.handle.drag` 期间不使用 easing，不改变正文排版。

## 5. 跨层规则

```text
UiState 不能散落在页面组件里
EphemeralState 可以保留在平台 UI 内，但不能参与业务判断
阅读进度以 Core 的 canonical location 为准
平台可以提供视觉排版测量，但不能各自发明业务进度模型
```

## 6. StateRule / 互斥 / async guard

来源：各页交互规则稿与 Reader UI frontend-demo/MOTION_CONTRACT.md。

互斥规则：

- 书架操作底表只允许 `修改` 和 `删除`，不得放置书源、缓存、分组、导出等配置型操作。
- 状态页不得改变底部导航结构。
- 设置首页不直接执行清空/删除/恢复默认；破坏性操作必须在二级页中确认。
- 设置首页不需要全屏空态；本地统计为空也应显示可进入的管理入口。
- 发现首页未展开次级交互只保留入口语义，不生成完整次级页面。
- 发现当前阶段不补 loading/empty/error 图片；后续必须复用 `AppShell.State.*`。
- RSS 当前阶段不生成订阅管理闭环；行内三点菜单只保留入口。
- 沉浸阅读操作提交中禁止重复点击主按钮。
- 浮层关闭顺序：先关闭当前浮层，再返回上级页面。
- 网络不可用只阻断依赖网络的动作，不阻断本地查看与关闭页面。
- 沉浸阅读状态层不得改变页面主结构，只替换对应内容区或显示可恢复反馈。

async guard：

- `appState.asyncRouteRequest` 存在时屏蔽重复路由请求。
- request-scoped async state 必须有 cancellation/discard guards。

motion interrupt guard：

- 新输入打断动画时触发 `cancel / redirect / completeThenReplace`，清除 transient press/drag/dropdown flags。

reduced-motion：

- URL/system reduced-motion 状态可见于 controller。
- transition/animation duration 降到 0ms，禁用翻页和 loading 动画。
