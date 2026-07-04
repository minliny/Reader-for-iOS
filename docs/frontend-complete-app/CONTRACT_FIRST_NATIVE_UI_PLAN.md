# Contract-first Native UI Architecture

本文是 Reader 多端 UI 架构改造的当前主规划。它用于指导 `Reader UI`、
`Reader-Core-Native`、`Reader for iOS`、`Reader for Android`、
`Reader for HarmonyOS`、旧 `Reader-Core` 和暂不在当前移动三端主线内的
`Reader for Windows` 的职责边界与后续修改方向。

## 1. 架构结论

Reader 不做统一 UI runtime。后续主线采用 Contract-first Native UI Architecture：

```text
Reader-Core-Native
  业务事实源：书源、章节、正文、进度、RSS、TTS queue、同步冲突

Reader UI Contract
  机器可读契约：route / state / event / motion / token / view-state schema + codegen

Platform Interaction Reducer
  三端原生 reducer/coordinator：navigation、readerMode、overlay、session、focus、async guard

Host Adapter
  平台能力：HTTP、WebView、Cookie、文件、权限、后台任务、系统 TTS、Keychain/Keystore

Native UI
  SwiftUI / Compose / ArkUI：渲染 ViewState，发送 UiEvent
```

这套架构统一的是行为、状态语义、业务事实源和契约，不要求三端像素级一致。
三端必须保留原生体验，并用本地 UI 框架实现平台自然的交互。

## 2. 状态边界

```text
DomainState
  Owner: Reader-Core-Native
  bookId、chapterId、content、progress、source、rssItem、ttsQueue、syncStatus、conflictState

UiState
  Owner: Platform Interaction Reducer
  route、tab、readerMode、overlay、activeSession、focusTarget、loading、error、reducedMotion

EphemeralState
  Owner: Native UI
  dragOffset、scrollPixel、layoutMeasurement、pressedState、textSelection、accessibilityFocus
```

规则：

- UI 不能直接改 DomainState。
- UiState 不能散落在页面组件里。
- EphemeralState 可以保留在平台 UI 内，但不能参与业务判断。
- 阅读进度以 Core 的 canonical location 为准。
- 平台可以提供视觉排版测量，但不能各自发明业务进度模型。

## 3. 事件流

```text
Native UI
  -> emit UiEvent

Platform Interaction Reducer
  -> update UiState
  -> emit CoreCommand / HostCommand

Reader-Core-Native
  -> return DomainEvent / DomainResult

Host Adapter
  -> return HostResult

Platform Interaction Reducer
  -> merge DomainEvent / HostResult
  -> produce ViewState

Native UI
  -> render ViewState
```

禁止路径：

```text
UI -> Core -> UI 直接回调
UI -> Storage / Sync 直接写入
UI 页面组件之间互相改全局状态
Core -> 直接调用平台 HTTP / WebView / Cookie
```

## 4. Reader UI Contract 职责

`Reader UI` 是 UI 契约源，不是生产运行时。

必须逐步产出：

```text
contracts/
  route.schema.json
  ui-event.schema.json
  ui-state.schema.json
  view-state.schema.json
  motion.schema.json
  token.schema.json

tools/codegen/
  swift/
  kotlin/
  arkts/

generated/
  swift/
  kotlin/
  arkts/
```

最低契约内容：

- `RouteId`：如 `bookshelf.home`、`reader.surface`、`rss.detail`。
- `UiEvent`：如 `openBook`、`pageNext`、`toggleOverlay`、`startTts`。
- `UiState`：导航、readerMode、overlay、session、focus、loading、error。
- `ViewState`：页面可渲染状态。
- `MotionId`：tab switch、reader overlay、session capsule 等。
- `Token`：颜色、字号、间距、圆角、阅读主题。
- `StateRule`：互斥规则和 async guard。

验收门槛：

- 三端类型能从同一套 schema 生成或验证。
- demo 中出现的 route / motion / state 必须能在 contract 中找到。
- 不允许只靠 Markdown 描述状态。
- contract 变更必须能触发三端编译或测试失败。

## 5. Reader-Core-Native 职责

`Reader-Core-Native` 是业务事实源，不是 UI runtime。

Core 负责：

```text
book.open
book.parse
chapter.list
content.load
reader.location.resolve
reader.progress.update
source.search
source.detail
rss.list
rss.item.read
tts.queue.plan
sync.snapshot
sync.conflict.resolve
```

Core 不负责：

```text
SwiftUI / Compose / ArkUI 页面状态
手势识别
平台导航栈
系统权限弹窗
Cookie 保存位置
WebView 生命周期
像素级布局状态
```

后续 Core 侧应收敛：

```text
core-command.schema.json
core-event.schema.json
host-request.schema.json
progress-location.schema.json
sync-conflict.schema.json
ffi-protocol-version.md
```

## 6. Platform Interaction Reducer 职责

每个平台保留本地 reducer/coordinator，但必须消费同一套 UI Contract。

统一管理：

```text
navigation
readerMode
overlay
activeSession
focusTarget
loading/error
async guard
reducedMotion
source switching
sync prompt
```

不允许：

```text
解析书籍
计算业务进度
直接写数据库
直接做 WebDAV 冲突策略
持有平台 View 引用
```

建议落位：

```text
Reader for iOS
  ReaderReducer.swift
  ReaderViewState.swift
  ReaderCoordinator.swift
  ReaderCoreBridge.swift
  HostAdapter.swift

Reader for Android
  ReaderReducer.kt
  ReaderUiState.kt
  ReaderCoordinator.kt / ReaderViewModel.kt
  ReaderCoreBridge.kt
  HostAdapter.kt

Reader for HarmonyOS
  ReaderReducer.ets
  ReaderViewState.ets
  ReaderAbilityModel / AppStateStore
  ReaderNapiBridge.ets
  HostAdapter.ets
```

## 7. Host Adapter 职责

Host Adapter 是平台能力执行层，不能混入页面组件。

统一能力清单：

```text
http.execute
webview.open
webview.evaluate
cookie.get/set
file.read/write
storage.path
credential.get/set
tts.system.start/stop
permission.request
background.schedule
notification.show
share.invoke
```

Core 可以发起 `HostRequest`，Reducer 可以发起平台 UI 相关 `HostCommand`。
Host Adapter 返回结构化结果，不直接改 Core 或 UI 状态。

## 8. 仓库职责

| 仓库 | 当前职责 | 修改方向 |
| --- | --- | --- |
| `Reader UI` | UI demo、handoff、route/motion/token/state 资料 | 升级为机器可读 UI Contract 源，提供 schema、fixtures、codegen、contract tests |
| `Reader-Core-Native` | Rust 业务内核、FFI、protocol、host bus | 收敛为唯一业务事实源，补齐 CoreCommand/CoreEvent/HostRequest/progress/sync contract |
| `Reader for iOS` | SwiftUI 原生 App | 接入 UI Contract generated Swift types，建立 Swift reducer/coordinator、Core bridge、Host Adapter |
| `Reader for Android` | Compose 原生 App | 接入 UI Contract generated Kotlin types，收敛 ReaderUiReducer/ViewModel、Core bridge、Host Adapter |
| `Reader for HarmonyOS` | ArkUI 原生 App | 接入 UI Contract generated ArkTS types，拆分 ArkUI reducer/store、NAPI bridge、Host Adapter，并补 real-device proof |
| `Reader-Core` | 旧 Swift Core、历史样本和兼容参考 | 不再作为新主线扩展；只保留迁移参考、fixture、行为对照和历史兼容证据 |
| `Reader for Windows` | 暂不属于当前 iOS / Android / HarmonyOS 移动三端主线 | 若恢复开发，消费同一套 UI Contract 和 Reader-Core-Native，建立 Windows reducer/coordinator 与 Host Adapter |

## 9. 开发阶段

### Phase 0：架构冻结

交付：

```text
ARCHITECTURE.md
BOUNDARY_RULES.md
STATE_OWNERSHIP.md
CONTRACT_VERSIONING.md
```

目标：

- 固化 Core / Contract / Reducer / Host / UI 边界。
- 明确 Interaction Layer 不是共享 runtime。
- 明确 Reader UI 不是生产运行时 UI 框架。

### Phase 1：契约基础

交付：

```text
route schema
ui event schema
ui state schema
view state schema
motion schema
token schema
Swift/Kotlin/ArkTS generated types
contract validation tests
```

优先覆盖 AppShell、main tabs、bookshelf -> reader、reader overlay、session、focus。

### Phase 2：Core bridge 规划契约

交付：

```text
CoreCommand / CoreEvent
progress-location model
content model
sync conflict model
host request protocol
```

目标是定义 Reader UI 侧 Core bridge 的规划契约，让三端打开书、章节、正文、进度、同步和 TTS 语义一致。
这不证明 Reader-Core-Native 当前协议已经完全对齐；后续仍需要 Core bridge mapping / 协议收敛，把契约项逐项映射到真实 Core 命令、事件、错误与 Host 边界。

### Phase 3：三端 reducer 落地

按 slice 推进：

```text
Slice 1: AppShell + main tabs
Slice 2: Bookshelf -> open book -> reader surface
Slice 3: Reader overlay / control dock / reader mode
Slice 4: Progress / session / focus / TTS
Slice 5: RSS / source / search
Slice 6: Sync / conflict / offline state
```

每个 slice 需要三端一起验收，不允许单端无限向前跑。

### Phase 4：Host Adapter 补齐

优先顺序：

```text
HTTP
Cookie
WebView
File/storage path
Credential
TTS
Background task
Notification/share
```

### Phase 5：一致性验证

必须具备：

```text
contract test
reducer golden test
core protocol test
device smoke test
```

最低验收链路：

```text
启动 App
进入 bookshelf
打开一本书
进入 reader
翻页
打开控制层
切换 readerMode
更新进度
触发 TTS
退出再进入
同步进度
```

## 10. 合并门槛

每个功能合并前必须回答：

1. 这个状态属于 DomainState、UiState 还是 EphemeralState？
2. 是否已经进入 schema？
3. 三端生成类型是否通过？
4. reducer 是否有 golden test？
5. UI 是否只渲染 ViewState？
6. 是否绕过了 Core 或 Host Adapter？
7. 是否会造成三端行为漂移？

如果任何一项答不上来，不应该进入主线开发。
