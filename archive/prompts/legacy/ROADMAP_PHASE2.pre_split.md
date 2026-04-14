# Phase 2 Roadmap — Recalibrated: Minimal Tooling → Early iOS Gate Review

```yaml
version: "2.0.0"
generatedAt: "2026-04-11"
recalibratedAt: "2026-04-11"
baseline: "Reader-Core freeze gate CI VERIFIED (run 24279408481)"
stage: "post_freeze_planning"
execution_mode: "recalibrated_phase2"
active_strategy: "minimal_tooling_then_ios"
scope: "planning_only — no implementation"
previous_version: "1.0.0 (Track D M1–M3 full completion before iOS)"
change_summary: "Strategy recalibrated from 'complete full Track D M1–M3 before iOS' to 'minimal high-ROI tooling subset, then early iOS gate review'"
```

---

## Recalibration Rationale

```yaml
recalibration:
  old_strategy: "Complete full Track D M1–M3 before iOS gate review"
  new_strategy: "Minimal Tooling Hardening → Early iOS Gate Review"

  why_recalibrate: |
    旧策略"完成全部 Track D M1–M3 后才允许 iOS gate review"过于保守，理由：

    1. iOS Shell 已有实质实现代码（ReadingFlowCoordinator + DefaultServices + SwiftUI views），
       延迟 gate review 不减少风险，反而延迟了发现 Core↔Shell 边界问题的时机
    2. M1 交付物（API Snapshot + Fixture Spec + Tooling Backlog）已完成，
       仅剩少量 M2 subset 即可支撑 gate review
    3. M3 (Regression Dashboard + Local Pre-check) 和大部分 M2 tooling
       可在 iOS Shell 开发期间并行推进，不需要前置
    4. 早期 gate review 允许 iOS Shell 在受控条件下开始有限开发，
       而非等到 tooling 完备后才"一次性放开"
    5. 高 ROI tooling（AdapterHarness + TraceInspector）覆盖了
       Core↔Shell 集成的最大风险点，其余 tooling ROI 递减

  what_changed: |
    - iOS Gate 条件从"M1–M3 complete"降为"M1 + minimal M2 subset"
    - Tooling 排序：高 ROI 项目前置，低 ROI 延迟到 Post-iOS
    - Timeline 从串行(Tooling→iOS)改为重叠(Minimal Tooling→Gate Review→iOS + Tooling parallel)
    - 新增 Shell smoke validation 和 Architecture review 作为 gate 条件

  what_did_not_change: |
    - Core baseline 仍然 frozen，不修改
    - 所有 8 个 CLOSED capability 状态不变
    - 2 个 OUT_OF_SCOPE (AntiBot, JSNetwork) 不变
    - Clean-room 原则不变
    - Phase gate approval 机制不变（只是条件调整）
```

---

## Frozen Baseline Summary

```yaml
frozen_baseline:
  phase1_status: COMPLETE
  core_contract_stabilization: COMPLETE
  capability_closure: COMPLETE
  freeze_gate_status: READY_TO_FREEZE
  closed_capabilities: 8
  out_of_scope_capabilities: 2
  ci_evidence:
    - "ErrorMappingTests: 14/14 passed (run 24279408481)"
    - "PolicyVerificationTests: 9/9 passed (run 24279408481)"
  architecture_state: "ARCHITECTURE_SKELETON_ONLY"
  adapter_validation: "recorded, macOS, MinimalHTTPAdapter"
  platform_implementation_done: false
  ui_implementation_done: false

  track_d_m1_status: COMPLETE
  m1_deliverables:
    - "docs/API_SNAPSHOT/Core_Public_API.md — 84 public symbols (73 frozen / 8 internal / 3 unstable)"
    - "docs/API_SNAPSHOT/Core_Module_Dependency.md — 8 modules, Mermaid + YAML"
    - "docs/FIXTURE_INFRA_SPEC.md — fixture infrastructure specification"
    - "docs/TOOLING_BACKLOG.md — 10 tooling candidates cataloged"
```

---

## Recalibrated Phase 2 Strategy

```yaml
phase2Strategy:
  recommendedTrack: "tooling_platform_first"
  active_strategy: "minimal_tooling_then_ios"
  strategy_description: |
    先完成最小高 ROI tooling subset，然后尽早进行 iOS gate review。
    Gate review 通过后，iOS Shell 开发与剩余 tooling 并行推进。

  core_principle: |
    "Build the minimum tools needed to safely open iOS,
     then open it — don't wait for perfect tooling."

  phases:
    - phase: "Phase 2a: Minimal Tooling Hardening"
      goal: "Build AdapterIntegrationTestHarness + Request/Response Trace Inspector"
      duration: "1.5–2 weeks"
      gate_output: "iOS Gate Review readiness"

    - phase: "Phase 2b: iOS Gate Review"
      goal: "Evaluate iOS Shell readiness, approve or defer"
      duration: "0.5–1 week"
      gate_output: "ios_gate.allowed decision"

    - phase: "Phase 2c: iOS Shell + Tooling Parallel"
      goal: "iOS Shell stabilization + remaining tooling as needed"
      duration: "4–6 weeks"
      condition: "ios_gate.allowed = true"
```

---

## iOS Gate Conditions (Recalibrated)

```yaml
ios_gate:
  allowed: false
  previous_conditions:
    - "Track D M1–M3 complete"  # OLD — too conservative
    - "iOS Adapter spec verified"
    - "Phase gate checklist answered"

  current_conditions:
    - condition: "Track D M1 complete"
      status: COMPLETE
      evidence: "Core_Public_API.md + Core_Module_Dependency.md + FIXTURE_INFRA_SPEC.md + TOOLING_BACKLOG.md delivered"

    - condition: "Minimal M2 tooling subset complete"
      status: PENDING
      required_items:
        - "AdapterIntegrationTestHarness — 可注入 mock/real adapter 的测试框架"
        - "Request/Response Trace Inspector — HTTP 请求/响应链路追踪工具"
      rationale: "这两项工具覆盖 Core↔Shell 集成的最大风险点：Adapter contract 正确性和 HTTP 层可观测性"

    - condition: "Shell smoke validation complete"
      status: PENDING
      required_items:
        - "ReadingFlowCoordinator 可成功执行 import → search → selectBook → selectChapter 最短路径"
        - "DefaultSearchService/TOCService/ContentService 与 Core 对接无编译错误"
        - "至少 1 个非 JS 书源端到端可走通"
      rationale: "验证 iOS Shell 现有代码确实可与 Core 对接，不是死代码"

    - condition: "Architecture review pass"
      status: PENDING
      required_items:
        - "Core→Adapter→Shell 依赖方向正确（无循环依赖）"
        - "iOS Shell 未直接访问 Core 内部模块（仅通过 frozen protocols）"
        - "Adapter 层边界清晰"
      rationale: "确认架构分层在 iOS Shell 开放后不会被破坏"

  gate_review_process: |
    1. OT-006 (AdapterHarness) + OT-007 (TraceInspector) 完成后
    2. 执行 Shell smoke validation (OT-009 的一部分)
    3. 执行 Architecture review
    4. 出具 Gate Review 结论：approved / deferred with conditions / rejected
    5. 若 approved: ios_gate.allowed = true, 进入 Phase 2c
    6. 若 deferred: 明确补充条件后重新评估
```

---

## Tooling Priority (Recalibrated)

```yaml
tooling_priority:

  P0_immediate:
    - id: "TOOL-AdapterHarness"
      name: "Adapter Integration Test Harness"
      task: "OT-006"
      rationale: |
        Core↔Shell 集成的最大风险点。iOS Adapter 需要验证 contract，
        AdapterHarness 提供标准化验证框架。没有它，iOS Shell 集成
        只能靠手动测试，效率极低。
      delivers: "可注入 mock/real adapter 的测试框架 + Adapter contract 验证模板"

    - id: "TOOL-TraceInspector"
      name: "Request/Response Trace Inspector"
      task: "OT-007"
      rationale: |
        HTTP 层可观测性是 Core↔Shell 调试的基础。当前调试需要 CI log inspection，
        TraceInspector 提供本地即时可见性。与 AdapterHarness 互补。
      delivers: "HTTPClient decorator 记录所有请求/响应，支持敏感数据脱敏"

  P1_optional_before_ios:
    - id: "TOOL-FixtureReplay_OR_SelectorTester"
      name: "Fixture Replay OR Selector Tester（二选一）"
      task: "OT-008"
      rationale: |
        两者均为 P1 可选，不阻塞 iOS gate。Fixture Replay 解决
        本地 Windows 开发环境无法跑 Swift 测试的问题；
        Selector Tester 解决 CSS 选择器调试效率问题。
        选哪个取决于 iOS Shell 开发中遇到的实际痛点。
      delivers: "二选一：本地 fixture 预检 OR CSS 选择器即时验证"

  deferred_until_post_ios:
    - id: "TOOL-003"
      name: "Rule Debugger"
      rationale: "HIGH complexity, 可在 iOS Shell 开发期间按需推进"

    - id: "TOOL-010"
      name: "Regression Dashboard"
      rationale: "HIGH complexity, web frontend, 非阻塞"

    - id: "TOOL-006"
      name: "JS Runtime Inspector"
      rationale: "JSRuntimeDOMBridge unstable, JS inspection 有限"

    - id: "TOOL-007"
      name: "Login Bootstrap Debugger"
      rationale: "依赖 TraceInspector 基础设施，可在 Post-iOS 复用"

    - id: "TOOL-009"
      name: "Fixture Snapshot Recorder"
      rationale: "CI 集成复杂，自动审批流程需设计，非阻塞"
```

---

## Candidate Tracks (Preserved for Reference)

### Track A: iOS Shell First

```yaml
name: iOS Shell First
recommendation: CONDITIONAL_OPEN
recalibrated_status: |
  旧判定: DEFER (需 M1–M3 完成后才可进入)
  新判定: CONDITIONAL_OPEN — 完成最小 tooling subset 后通过 gate review 即可进入
  变更原因: iOS Shell 已有实质实现代码，延迟 gate review 不减少风险
prerequisites:
  - "Track D M1 complete ✅"
  - "AdapterIntegrationTestHarness 完成"
  - "Request/Response Trace Inspector 完成"
  - "Shell smoke validation pass"
  - "Architecture review pass"
  - "Explicit phase gate approval (ios_gate.allowed = true)"
```

### Track B: Multi-Platform Shell Abstraction First

```yaml
name: Multi-Platform Shell Abstraction First
recommendation: DEFER
rationale: |
  仍然 DEFER — 过早抽象风险不变。需要在 iOS Shell 稳定运行后
  才有双平台实证数据支撑抽象决策。
revisitConditions:
  - "iOS Shell 稳定运行至少 4 周"
  - "至少 2 个平台 Adapter 实现完成"
  - "平台差异实证数据收集完成"
```

### Track C: Compatibility Expansion First

```yaml
name: Compatibility Expansion First
recommendation: DEFER
rationale: |
  仍然 DEFER — 无用户反馈驱动扩展方向不可控。
  正确路径：先交付可运行产品，用用户反馈驱动扩展。
revisitConditions:
  - "iOS Shell 上线获得真实用户反馈"
  - "新兼容需求从用户反馈中提取"
```

### Track D: Tooling / Debug / Fixture Platform First

```yaml
name: Tooling / Debug / Fixture Platform First
recommendation: RECOMMENDED (recalibrated scope)
recalibrated_status: |
  旧判定: Track D M1–M3 全量完成后才允许 iOS
  新判定: Track D 最小子集 (M1 + M2 subset) 完成后即可 iOS gate review
  变更原因: M3 和大部分 M2 tooling 不阻塞 iOS Shell 开发，可并行
prerequisites:
  - "Core baseline frozen ✅"
  - "CI pipeline stable ✅"
  - "compat_matrix + failure_taxonomy 稳定 ✅"
  - "M1 deliverables complete ✅"
```

---

## Milestone Breakdown (Recalibrated)

```yaml
milestones:

  M1: Core API Snapshot & Fixture Infrastructure
    status: COMPLETE
    deliverables:
      - "Core_Public_API.md ✅"
      - "Core_Module_Dependency.md ✅"
      - "FIXTURE_INFRA_SPEC.md ✅"
      - "TOOLING_BACKLOG.md ✅"

  M2_minimal: Core↔Adapter Integration + Trace (Minimal Subset)
    status: PENDING
    goal: "完成 iOS Gate 所需的最小 tooling"
    duration: "1.5–2 weeks"
    deliverables:
      - "AdapterIntegrationTestHarness: 可注入 mock/real adapter 的测试框架"
      - "Request/Response Trace Inspector: HTTP 请求/响应链路追踪"
      - "Adapter contract 验证模板 (HTTP)"
    acceptance:
      - "新 Adapter 实现可基于模板完成 contract 自检"
      - "Core→Adapter 调用链路可 trace"
      - "TraceInspector 支持敏感数据脱敏"
    tasks:
      - "OT-006: Adapter Integration Harness"
      - "OT-007: Request/Response Trace Inspector"

  M2_optional: Optional Tooling Before iOS
    status: OPTIONAL
    goal: "可选的效率提升工具，不阻塞 gate"
    duration: "0.5–1 week"
    deliverables:
      - "Fixture Replay OR Selector Tester（二选一）"
    tasks:
      - "OT-008: Optional Fixture Replay / Selector Tester"

  G1: iOS Phase Gate Review
    status: PENDING
    goal: "评估 iOS Shell 进入条件是否满足"
    duration: "0.5–1 week"
    deliverables:
      - "Shell smoke validation report"
      - "Architecture review report"
      - "Gate review decision (approved / deferred / rejected)"
    tasks:
      - "OT-009: iOS Phase Gate Review"

  M3_extended: Extended Tooling (Post-iOS Gate)
    status: DEFERRED
    goal: "iOS Shell 开放后按需推进的 tooling"
    duration: "2–4 weeks (parallel with iOS Shell)"
    deliverables:
      - "Rule Debugger"
      - "Regression Dashboard"
      - "JS Runtime Inspector"
      - "Login Bootstrap Debugger"
      - "Fixture Snapshot Recorder"
      - "Local pre-check script"
      - "CI fixture drift detection"
```

---

## Phase 2 Decision (Recalibrated)

```yaml
phase2Decision:
  recommendedTrack: "tooling_platform_first"
  active_strategy: "minimal_tooling_then_ios"
  recommendation: "Minimal Tooling Hardening → Early iOS Gate Review"

  rationale: |
    校准后的策略优于旧策略，理由：

    1. RISK-CONTROLLED: 最小 tooling subset (AdapterHarness + TraceInspector)
       覆盖了 Core↔Shell 集成的最大风险点。其余 tooling ROI 递减。

    2. EARLY-FEEDBACK: iOS Shell 已有实质代码。尽早 gate review
       允许在受控条件下开始有限开发，比等到 tooling 完备后
       "一次性放开"更安全——问题越早发现，修复成本越低。

    3. PARALLEL-PROGRESS: iOS Shell 开发与剩余 tooling 可并行，
       不再是串行等待。项目整体推进速度提升。

    4. PRAGMATIC: 旧策略假设"tooling 完备后 iOS 开发效率最高"，
       但实际上 iOS Shell 已有代码，tooling 的边际收益递减。
       先用最小 tooling 打开 gate，在实践中决定需要什么 tooling。

  deferredTracks:
    - track: "Multi-Platform Shell Abstraction First"
      deferReason: "过早抽象，缺乏多平台实证数据"
      revisitConditions:
        - "iOS Shell 稳定运行至少 4 周"
        - "至少 2 个平台 Adapter 实现完成"

    - track: "Compatibility Expansion First"
      deferReason: "无用户反馈驱动，边际 ROI 递减"
      revisitConditions:
        - "iOS Shell 上线获得真实用户反馈"
        - "新兼容需求从用户反馈中提取"

  iosShellDecision: |
    何时可以进入 iOS Shell：
    - AdapterIntegrationTestHarness 完成后
    - Request/Response Trace Inspector 完成后
    - Shell smoke validation 通过
    - Architecture review 通过
    - Phase gate review 结论为 approved

    与旧策略的关键区别：
    - 旧：M1–M3 全部完成 → 才允许 gate review
    - 新：M1 + M2 minimal subset → 即可 gate review
    - 结果：iOS Shell 进入时间提前约 2–3 周
```

---

## Timeline Overview (Recalibrated)

```yaml
timeline:
  phase2_start: "2026-04-11"
  recalibrated_at: "2026-04-11"

  phases:
    - phase: "Phase 2a: Minimal Tooling Hardening"
      duration: "1.5–2 weeks"
      milestones: ["M2_minimal"]
      tasks: ["OT-006", "OT-007"]
      gate: "AdapterHarness + TraceInspector complete"

    - phase: "Phase 2b: iOS Gate Review"
      duration: "0.5–1 week"
      milestones: ["G1"]
      tasks: ["OT-009"]
      gate: "ios_gate.allowed decision made"

    - phase: "Phase 2c: iOS Shell + Tooling Parallel"
      duration: "4–6 weeks"
      prerequisites: "Phase 2b gate approved"
      milestones: ["M2_optional", "M3_extended"]
      parallel_tracks:
        - "iOS Shell stabilization + testing"
        - "Optional tooling (Fixture Replay / Selector Tester)"
        - "Extended tooling (Rule Debugger, Dashboard, etc.)"

    - phase: "Phase 2d: Multi-Platform Abstraction (conditional)"
      duration: "4–6 weeks"
      prerequisites: "Phase 2c stable for ≥4 weeks"
      condition: "有第二平台需求时启动"
```

---

## Guardrails

```yaml
guardrails:
  - "本轮只做规划校准，不做功能实现"
  - "不修改 Core baseline"
  - "不扩 capability"
  - "不引入新 failureType"
  - "不修改 compat_matrix"
  - "iOS Shell 进入必须经过 phase gate approval"
  - "Phase gate 条件按新定义执行，不回退到旧 M1–M3 前置"
  - "Multi-Platform Abstraction 必须有双平台实证数据"
  - "Compatibility Expansion 必须有用户反馈驱动"
  - "Clean-room 原则持续有效"
```

## Clean-Room Statement

```yaml
cleanRoom:
  noExternalGplCode: true
  noLegadoAndroidImplementationReference: true
  statement: "本规划仅基于仓库内部状态、已验证能力、架构文档与 CI 证据产出。不引用外部 GPL 代码，不引用 Legado Android 实现。校准仅调整策略优先级和 gate 条件，不涉及实现变更。"
```
