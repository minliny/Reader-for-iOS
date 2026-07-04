# 项目状态总览

## 当前多端架构定位（2026-07-04）

Reader iOS 当前纳入 Contract-first Native UI Architecture 主线。完整规划入口：

```text
../Reader UI/contracts/CONTRACT_FIRST_NATIVE_UI_PLAN.md
```

本仓职责：

- 作为 SwiftUI 原生 App，渲染 `ViewState` 并发送 `UiEvent`。
- 保留 iOS 原生导航、动效、可访问性和系统集成体验。
- 建立 Swift reducer/coordinator，统一管理 navigation、readerMode、overlay、
  activeSession、focus、loading/error、async guard、reducedMotion。
- 通过 Reader-Core-Native bridge 访问 Core 业务事实源。
- 通过 iOS Host Adapter 执行 URLSession、WKWebView、Cookie、Keychain、文件、
  AVSpeechSynthesizer、权限、通知和后台任务。

本仓不负责：

- 书源解析、章节正文、canonical progress、RSS、TTS queue、sync conflict 等业务事实源。
- Reader UI Contract schema/codegen 的源头。
- Android / HarmonyOS 的 reducer 或 UI 实现。

修改方向：

- 新增或收敛 `ReaderReducer.swift`、`ReaderViewState.swift`、
  `ReaderCoordinator.swift`、`ReaderCoreBridge.swift`、`HostAdapter.swift` 等边界。
- 等 `Reader UI/contracts` 的 schema/codegen 落地后，消费 generated Swift 类型。
- UI 组件只保留 drag offset、layout measurement、pressed state、selection 等临时视觉状态。
- 每个 shared slice 需要 reducer golden test 和 simulator/device smoke evidence。

## 历史拆仓状态（保留）

以下内容保留用于追溯 iOS 与旧 `Reader-Core` 的拆仓过程，不代表当前 Contract-first Native UI Architecture 的主线职责。

- 可信主线分支：`main`
- 当前仓库身份：`Reader-iOS 主仓`
- Reader-Core 已独立为：`../Reader-Core` / `https://github.com/minliny/Reader-Core`
- 当前结论：反向拆仓已完成，但双仓尚未达到长期稳态；当前阶段是 `post_split_stabilization_audit`。

## 历史阶段记录

- 项目目标：`Post-Split Stabilization Audit`
- 当前阶段：`post_split_stabilization_audit`
- 当前主线：`Reader-iOS standalone hardening with Reader-Core external dependency`
- 当前下一步：`修复 Reader-Core CI failures and migrate Reader-iOS off path dependency`

## 历史审计结论

- Reader-Core fresh clone：`可独立获取`
- Reader-Core standalone CI：`not green`
- Reader-iOS dependency direction：`correct`
- Reader-iOS active dependency mode：`path dependency, not yet stable as long-term mode`
- Reader-iOS ios-shell-ci：`存在 checkout path 风险，已在本仓修复`
- Reader-iOS docs semantics：`旧 agent / prompt / handoff 配置已清理`

## 仓库角色说明

- 本仓是 Reader-iOS 主仓，不再是 Reader-Core transition host。
- 本仓长期归属：
  - `iOS/**`
  - `docs/IOS_*`
  - `docs/ios_*`
  - `.github/workflows/ios-shell-ci.yml`
  - `scripts/check_ios_boundary.sh`
- Reader-Core 长期归属：
  - `Core/**`
  - `samples/**`
  - `tools/**`
  - `Adapters/**`
  - `Platforms/**`
  - Core-only workflows

## 历史拆仓风险

- Reader-Core 最新 `Reader Core Swift Tests` 失败，说明双仓还未达到真正稳态。
- Reader-iOS 仍以 path dependency 作为活动依赖模式，不适合长期 CI/发布稳态。
- 历史拆仓文档仍有 retained-for-history 语义，需要与当前主线严格区分。

## 推荐下一步

- 在 Reader-Core 仓修复 standalone test failures，恢复 core-swift-tests green baseline。
- 在 Reader-iOS 完成 remote package dependency 切换方案评审后，移除 path dependency。
- 持续保留 boundary gate，防止 Core 资产和 Core-only docs/workflows 回流到 Reader-iOS。

## Clean-Room 说明

- 本次审计仅基于当前仓与 Reader-Core fresh clone、CI 运行记录和现有文档。
- 未开发新 feature，未修改业务逻辑，未搬运外部 GPL 代码。
