# Architecture

状态：Phase 0 架构冻结
日期：2026-07-04
权威源：[CONTRACT_FIRST_NATIVE_UI_PLAN.md](./CONTRACT_FIRST_NATIVE_UI_PLAN.md)

本文冻结 Reader 多端 UI 架构。架构一旦变更必须先改本文与 [BOUNDARY_RULES.md](./BOUNDARY_RULES.md)、[STATE_OWNERSHIP.md](./STATE_OWNERSHIP.md)、[CONTRACT_VERSIONING.md](./CONTRACT_VERSIONING.md)，再向下传导到 schema 和 codegen。

## 1. 架构原则

Reader 不做统一 UI runtime。多端采用 Contract-first Native UI Architecture：

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

架构统一的是行为、状态语义、业务事实源和契约，不要求三端像素级一致。三端必须保留原生体验并用本地 UI 框架实现平台自然的交互。

## 2. 仓库角色

| 仓库 | 当前职责 | 修改方向 |
| --- | --- | --- |
| `Reader UI` | UI demo、handoff、route/motion/token/state 资料 | 升级为机器可读 UI Contract 源，提供 schema、fixtures、codegen、contract tests |
| `Reader-Core-Native` | Rust 业务内核、FFI、protocol、host bus | 收敛为唯一业务事实源，补齐 CoreCommand/CoreEvent/HostRequest/progress/sync contract |
| `Reader for iOS` | SwiftUI 原生 App | 接入 UI Contract generated Swift types，建立 Swift reducer/coordinator、Core bridge、Host Adapter |
| `Reader for Android` | Compose 原生 App | 接入 UI Contract generated Kotlin types，收敛 ReaderUiReducer/ViewModel、Core bridge、Host Adapter |
| `Reader for HarmonyOS` | ArkUI 原生 App | 接入 UI Contract generated ArkTS types，拆分 ArkUI reducer/store、NAPI bridge、Host Adapter，并补 real-device proof |
| `Reader-Core` | 旧 Swift Core、历史样本和兼容参考 | 不再作为新主线扩展；只保留迁移参考、fixture、行为对照和历史兼容证据 |
| `Reader for Windows` | 暂不属于当前 iOS / Android / HarmonyOS 移动三端主线 | 若恢复开发，消费同一套 UI Contract 和 Reader-Core-Native |

## 3. 分层职责

### 3.1 Reader UI Contract（本仓库）

- 产出机器可读 schema：`route` / `ui-event` / `ui-state` / `view-state` / `motion` / `token`。
- 产出 fixtures 与 contract tests 用于三端校验。
- 产出 codegen 入口，生成 Swift / Kotlin / ArkTS 类型。
- 不承载生产 UI，不实现 SwiftUI / Compose / ArkUI 页面。
- 不实现 Reader-Core-Native 的业务协议。
- 不实现跨端共享 reducer runtime。

### 3.2 Reader-Core-Native

- 业务事实源，负责 `book.open / book.parse / chapter.list / content.load / reader.location.resolve / reader.progress.update / source.search / source.detail / rss.list / rss.item.read / tts.queue.plan / sync.snapshot / sync.conflict.resolve`。
- 不负责 SwiftUI / Compose / ArkUI 页面状态、手势识别、平台导航栈、系统权限弹窗、Cookie 保存位置、WebView 生命周期、像素级布局状态。

### 3.3 Platform Interaction Reducer

- 每平台保留本地 reducer/coordinator，必须消费同一套 UI Contract。
- 统一管理：navigation、readerMode、overlay、activeSession、focusTarget、loading/error、async guard、reducedMotion、source switching、sync prompt。
- 不允许：解析书籍、计算业务进度、直接写数据库、直接做 WebDAV 冲突策略、持有平台 View 引用。

### 3.4 Host Adapter

- 平台能力执行层，不混入页面组件。
- 统一能力清单：`http.execute / webview.open / webview.evaluate / cookie.get-set / file.read-write / storage.path / credential.get-set / tts.system.start-stop / permission.request / background.schedule / notification.show / share.invoke`。
- Core 可以发起 `HostRequest`，Reducer 可以发起平台 UI 相关 `HostCommand`。Host Adapter 返回结构化结果，不直接改 Core 或 UI 状态。

### 3.5 Native UI

- 渲染 ViewState，发送 UiEvent。
- 不得直接修改 DomainState。
- 不得跨页面组件互改全局状态。

## 4. 数据流

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

## 5. 仓库内目录骨架

```text
contracts/
  ARCHITECTURE.md
  BOUNDARY_RULES.md
  STATE_OWNERSHIP.md
  CONTRACT_VERSIONING.md
  CONTRACT_FIRST_NATIVE_UI_PLAN.md
  README.md
  route.schema.json
  ui-event.schema.json
  ui-state.schema.json
  view-state.schema.json
  motion.schema.json
  token.schema.json
  fixtures/
  tests/

tools/codegen/
  README.md
  swift/
  kotlin/
  arkts/

generated/
  README.md
  swift/
  kotlin/
  arkts/
```

## 6. 验收门槛

- 三端类型能从同一套 schema 生成或验证。
- demo 中出现的 route / motion / state 必须能在 contract 中找到。
- 不允许只靠 Markdown 描述状态。
- contract 变更必须能触发三端编译或测试失败。
