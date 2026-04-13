# 项目状态 (PROJECT_STATUS)

## 项目定义

- 项目策略：Reader-Core first
- 壳层策略：iOS later
- 当前主线：Reader-Core 兼容内核开发 → M-IOS-11 Next Phase Planning
- 当前阶段：`m_ios_10_reader_interaction_foundation_verified`
- 当前是否允许进入 iOS 阶段：`conditional`
- 判断原因：M-IOS-10 已通过 macOS 远端 validation。可以开始进入 M-IOS-11 阶段的讨论和计划。

## 当前事实基线

### 已闭环样本
- `sample_js_runtime_001`
- `sample_js_runtime_002`
- `sample_004`
- `sample_005`
- `sample_001` / `sample_002` / `sample_003`
- `SAMPLE-P1-HEADER-001` / `002` / `003`
- `SAMPLE-P1-COOKIE-001` / `002` / `003`
- `SAMPLE-P1-CACHE-001` / `002` / `003`
- `SAMPLE-P1-ERROR-001` / `002` / `003`
- `SAMPLE-P1-POLICY-001` / `002` / `003`
- `sample_header_001` / `002` / `003`
- `sample_cookie_001` / `002`
- `sample_login_001` / `002` / `003`
- `sample_js_001`
- `css_executor_selector_semantics_contract`
- `fixture_toc_selector_miss` / `title_rule_miss` / `url_rule_miss` / `count_mismatch` / `non_selector_error`
- `toc_item_invalid_url_contract` / `http_client_invalid_url_contract`
- `SAMPLE-P1-COOKIE-WENSANG-001` / `XIANGSHU-001` / `XUANYGE-001`

### 已成熟能力
- CI 执行
- artifact 产出
- regression 回写
- writeback 审核
- compat_matrix 审计吸收
- Header (CLOSED)
- Cookie (CLOSED, 含 scoped isolation)
- Cache (CLOSED)
- ErrorMapping (CI_VERIFIED_CLOSED)
- PolicyVerification (CI_VERIFIED_CLOSED)
- JSDomExecution (CLOSED)
- LoginBootstrap (CLOSED)
- CookieIsolation (CLOSED)

### 当前未覆盖能力
- 无（所有能力已关闭或已裁决 out_of_scope）

### 当前 OUT_OF_SCOPE
- AntiBot (ROI NEGATIVE — 需 WKWebView，与沙箱模型不兼容)
- JSNetwork (ROI NEGATIVE — 开启 fetch/XHR 破坏 networkLockdown 安全保证)

## 最近一次动作

- M-IOS-10 Reader Interaction Foundation 已完成：GitHub Actions run `24353675339` 在 `macos-14-arm64` runner 上真实运行。所有的验证步骤（boundary gate, shell compile, smoke, functional, hardening, ux foundation, interaction foundation）均已通过。详见 `docs/ios_shell_ci_gate.yml`。
- 仓库工程整理已完成：远端历史分支已清理完毕，当前应以 `main` 作为唯一可信主线。

## 当前主线结论

- 可信主线分支：`main`
- 已收敛并删除的分支：`codex/cache-ci-evidence`、`claude/fervent-goldstine`、`codex/main`、`codex-cache-ci-evidence-2407`、`codex-policy-regression-verification-20260409`
- 继续保留的远端分支：无（远端仅剩 `origin/main`）
- 本地验证限制：当前 Windows 环境无 `swift`，本次无法执行 Swift 编译/测试；仅完成 Git 一致性、分支差异与收敛验证

## iOS Gate (Recalibrated)

```yaml
ios_gate:
  allowed: conditional
  decision: CONDITIONAL_ALLOW
  review_doc: docs/IOS_PHASE_GATE_REVIEW.md
  conditions:
    - condition: "Track D M1 complete"
      status: COMPLETE
    - condition: "Minimal M2 tooling subset complete (AdapterHarness + TraceInspector)"
      status: COMPLETE
    - condition: "Shell smoke validation complete"
      status: PASS
    - condition: "Architecture review pass"
      status: PASS
  prerequisites_for_execution:
    - "CONDITION-1: Fix dependency boundary leaks — COMPLETE (M-iOS-1)"
    - "CONDITION-2: Establish iOS Shell CI build — COMPLETE (ios-shell-ci workflow added)"
    - "CONDITION-3: Execute shell smoke validation — PASS (run 24306965324)"
  superseded_conditions: "Track D M1–M3 complete (旧条件，已校准)"
```

## M-IOS-9 Gate Result

```yaml
ios_shell_ci_gate:
  report: docs/ios_shell_ci_gate.yml
  executionVerified: true
  phaseStatus: PASS
  validationResult: PASS
  boundary_gate:
    implementationStatus: PASS
    executionStatus: PASS
  shell_ci:
    implementationStatus: PASS
    executionStatus: PASS
  smoke_validation:
    implementationStatus: PASS
    executionStatus: PASS
  validation_scope:
    implementationStatus: PASS
    executionStatus: PASS
  validation_glue:
    implementationStatus: PASS
    executionStatus: PASS
  reader_feature:
    implementationStatus: PASS
    executionStatus: PASS
  reader_functional_validation:
    implementationStatus: PASS
    executionStatus: PASS
    validated_sources:
      - sample_004
      - sample_005
  reader_flow_hardening:
    implementationStatus: PASS
    executionStatus: UNKNOWN
    validated_cases:
      - repeated_search
      - book_switch
      - chapter_switch
      - error_recovery
      - source_switch
      - state_transition_surface
  reader_ux_foundation:
    implementationStatus: PASS
    executionStatus: PASS
    validated_surfaces:
      - loading_surface
      - empty_surface
      - error_surface
      - content_surface
      - chapter_context_surface
  next_phase: "M-IOS-10"
```

## 本轮验证内容

- 验证对象：`ReaderShellValidation` green baseline + fixture-backed Reader functional validation + reader flow hardening validation + reader UX foundation validation
- 真实证据源：GitHub Actions
- runner：`macos-14-arm64`
- executionVerified：`true`
- 远端执行链路：
  - run `24353675339`：boundary gate / isolated compile 通过；shell smoke, functional, hardening, ux foundation, interaction foundation validation 全部通过。

## Phase / Validation / Evidence

- phase status：`PASS`
- validation result：`PASS`
- execution verified：`true`

## 本轮处理内容

- 新增 `ReaderStageActionBar`，提供正文阅读阶段上一章、下一章、重新加载功能的交互。
- 修改 `ContentView` 与 `TOCView` 的空状态，补充重试入口，增强 error recovery affordance。
- 新增 `ReaderInteractionValidationTests`，覆盖重试、空状态、翻页等交互测试，确保 interaction foundation 达到 baseline。

## 当前结论

- validation scope isolation：`PASS`
- validation glue alignment：`PASS`
- reader feature wiring：`PASS`
- reader functional validation：`PASS`
- reader flow hardening：`PASS`
- reader ux foundation：`PASS`
- reader interaction foundation：`PASS`
- boundary gate：`PASS`
- shell compile：`PASS`
- shell smoke validation：`PASS`
- 当前 blocker：`None`；下一步允许开启 `M-IOS-11` 规划。

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
- ErrorMapping: `CI_VERIFIED_CLOSED` (14/14 ErrorMappingTests passed on macOS-14 CI, run 24279408481)
- PolicyVerification: `CI_VERIFIED_CLOSED` (9/9 PolicyVerificationTests passed on macOS-14 CI, run 24279408481)
- JSDomExecution: `CLOSED`
- LoginBootstrap: `CLOSED`
- CookieIsolation: `CLOSED`
- AntiBot: `OUT_OF_SCOPE`
- JSNetwork: `OUT_OF_SCOPE`

## Phase 2 — Recalibrated Strategy

- **active_strategy**: `minimal_tooling_then_ios`
- **execution_mode**: `recalibrated_phase2`
- **active_milestone**: `m2_minimal`
- **milestone_status**: `complete`
- **milestone_name**: AdapterIntegrationTestHarness + Request/Response Trace Inspector

### Tooling Priority

```yaml
P0_immediate:
  - AdapterIntegrationTestHarness (OT-006)
  - Request/Response Trace Inspector (OT-007)

P1_optional_before_ios:
  - Fixture Replay OR Selector Tester (OT-008, 二选一)

deferred_until_post_ios:
  - Rule Debugger
  - Regression Dashboard
  - JS Runtime Inspector
  - Login Bootstrap Debugger
  - Fixture Snapshot Recorder
```

## 下一步唯一最优任务

- `M-IOS-11: Next Phase Planning`
- 目标说明：M-IOS-10 Reader Interaction Foundation 已在 macOS CI 执行验证通过。可以开始开启下一阶段的工作。

## 当前不允许做的事

- 未经架构 rollout 方案确认直接进入具体壳层实现
- 将 HarmonyOS 简单等同于 Android
- 引入与当前主线无关的 UI / 平台集成
- 把 architecture rollout 写成平台实现完成
- 修改 A/B/C/D 兼容等级定义
- 未同步 taxonomy 就新增 failureType
- 引入 retry、fallback 或复杂错误策略并伪装为 Error Mapping
- 引入外部 GPL 代码或引用 Legado Android 实现
- 在 `docs/ios_shell_ci_gate.yml` 未保持 `phaseStatus / validationResult / executionVerified` 三层一致时推进下一阶段

## Clean-Room 状态

- 本次仅执行远端 validation、最小 build wiring 修正与状态回写，依据仓库内部结构、真实 GitHub Actions 日志与 ShellAssembly 装配事实
- 无外部 GPL 代码
- 无 Legado Android 实现引用
