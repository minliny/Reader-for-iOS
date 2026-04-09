# 项目状态 (PROJECT_STATUS)

## 项目定义

- 项目策略：Reader-Core first
- 壳层策略：iOS later
- 当前主线：Reader-Core 兼容内核开发
- 当前阶段：`core_contract_stabilization`
- 当前是否允许进入 iOS 阶段：`no`
- 判断原因：当前只进入 `Multiplatform architecture rollout` 的骨架阶段，仍不是平台实现完成态

## 当前事实基线

### 已闭环样本
- `sample_js_runtime_001`
- `sample_js_runtime_002`
- `sample_004`
- `sample_005`

### 已成熟能力
- CI 执行
- artifact 产出
- regression 回写
- writeback 审核
- compat_matrix 审计吸收

### 当前未覆盖能力
- 无新的 Core capability 闭环缺口；当前主任务转为架构 rollout

## 最近一次动作

- `SwiftPM build fix: resolved circular dependency, Cookie capability CI-verified`
- 当前结论：
  - `P0 policy executable verification` 已完成
  - SwiftPM 循环依赖已修复：ReaderPlatformAdapters 移入 Core 内部 target
  - runId: `24200148174`
  - runUrl: `https://github.com/minliny/Reader-for-iOS/actions/runs/24200148174`
  - result: `pass`
  - testsRun: `true`
  - totalTests: `115`
  - failedTests: `0`
  - Cookie 测试全部通过：CookieJarIntegration, CookieSample001, CookieSample002, CookieSample003
  - policy-regression-macos runId: `24200148194` 同样通过
  - `platformImplementationDone=false`

## Adapter Validation

- status: `recorded`
- platform: `macOS`
- adapterUsed: `MinimalHTTPAdapter`
- sampleId: `sample_004`
- 验证链路：`sample -> Core -> HTTPAdapter -> response -> parser -> expected`
- 边界：不处理业务逻辑，不做 cache/cookie/error mapping，不代表多平台支持完成

## Adapter Hardening

- status: `recorded`
- platform: `macOS`
- adapterUsed: `MinimalHTTPAdapter`
- validatedSamples:
  - `SAMPLE-P1-HEADER-001`
  - `SAMPLE-P1-COOKIE-001`
  - `SAMPLE-P1-ERROR-001`
- 说明：仅做多样本 contract 验证，不新增 adapter 功能，不实现多平台 adapter，不回改 Core

## P0 Policy Layer Convergence

- status: `executable_verified`
- validatedSamples:
  - `SAMPLE-P1-POLICY-001`
  - `SAMPLE-P1-POLICY-002`
  - `SAMPLE-P1-POLICY-003`
- verificationStatus: `VERIFIED`
- closureDecision: `CLOSED`
- 说明：`swift test --verbose` 已在 macOS CI 真实通过，3 个 policy 样本保持 B/B/C，执行验证完成。

## Multiplatform Architecture Rollout

- status: `architecture_skeleton_only`
- coreSingleSourceOfTruth: `true`
- platformImplementationDone: `false`
- uiImplementationDone: `false`
- rolloutGuide: `docs/architecture/reader_core_multiplatform_rollout.md`
- engineeringSkeletonDoc: `docs/architecture/engineering_architecture_skeleton.md`
- 说明：本阶段只固化 Core / Adapter / Shell 边界与工程骨架，不实现任何平台 UI 或平台专属业务功能。

## Engineering Skeleton

- `Core/Sources/ReaderCoreProtocols/PlatformAdapterProtocols.swift`
- `Adapters/HTTP/`
- `Adapters/Storage/`
- `Adapters/Scheduler/`
- `Platforms/iOS/`
- `Platforms/Android/`
- `Platforms/Windows/`
- 依赖方向：`Shell -> Adapter -> Core`
- 说明：Adapter 只定义协议边界与挂点，Shell 只保留调用入口，不包含 UI 实现。

## Capability 状态

- Header: `CLOSED`
- Cache: `CLOSED`
- Cookie: `CLOSED`
- ErrorMapping: `CLOSED`

## 下一步唯一最优任务

- `P1 capability expansion: Header / Error mapping / Cache executable verification`
- 目标说明：SwiftPM build 已修复，Cookie capability 已 VERIFIED + CLOSED。下一步对 Header、Error mapping、Cache 进行 executable verification。

## 当前不允许做的事

- 未经架构 rollout 方案确认直接进入具体壳层实现
- 将 HarmonyOS 简单等同于 Android
- 引入与当前主线无关的 UI / 平台集成
- 把 architecture rollout 写成平台实现完成
- 修改 A/B/C/D 兼容等级定义
- 未同步 taxonomy 就新增 failureType
- 引入 retry、fallback 或复杂错误策略并伪装为 Error Mapping
- 引入外部 GPL 代码或引用 Legado Android 实现

## Clean-Room 状态

- 本次仅依据仓库内部协议、样本资产结构、已验证 policy regression 与架构文档推进 rollout skeleton
- 无外部 GPL 代码
- 无 Legado Android 实现引用
