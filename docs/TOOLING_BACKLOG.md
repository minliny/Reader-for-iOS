# Tooling & Debug Backlog (Recalibrated)

```yaml
version: "2.0.0"
generatedAt: "2026-04-11"
recalibratedAt: "2026-04-11"
baseline: "Reader-Core freeze gate CI VERIFIED (run 24279408481)"
scope: "tooling_candidate_catalog"
status: "backlog — recalibrated priority per minimal_tooling_then_ios strategy"
previous_version: "1.0.0 (flat P1/P2/P3 by value-complexity)"
change_summary: "Priority recalibrated: P0=items blocking iOS gate; P1 Optional=items helpful but not blocking; Deferred=items for post-iOS parallel work"
```

---

## Overview

This document catalogs candidate tooling capabilities for the Reader-Core project, **recalibrated per the minimal_tooling_then_ios strategy**. Only the minimum high-ROI tooling subset is required before iOS gate review; remaining tools are deferred to post-iOS parallel work.

---

## Recalibrated Priority Structure

```yaml
priority_structure:
  P0_immediate:
    description: "必须完成，阻塞 iOS gate review"
    items:
      - TOOL-AdapterHarness
      - TOOL-TraceInspector

  P1_optional_before_ios:
    description: "可选，不阻塞 gate，但可提升开发效率"
    items:
      - TOOL-FixtureReplay_OR_SelectorTester

  deferred_until_post_ios:
    description: "延迟到 iOS Shell 开放后按需推进"
    items:
      - TOOL-RuleDebugger
      - TOOL-RegressionDashboard
      - TOOL-JSRuntimeInspector
      - TOOL-LoginBootstrapDebugger
      - TOOL-SnapshotRecorder
```

---

## Candidate Catalog (Recalibrated Order)

### P0 / Immediate

#### TOOL-AdapterHarness: Adapter Integration Test Harness

```yaml
id: TOOL-AdapterHarness
name: "Adapter Integration Test Harness"
task: "OT-006"
priority: P0
description: |
  可注入 mock/real adapter 的测试框架。新 Adapter 实现可基于模板
  完成 contract 自检。Core→Adapter 调用链路可验证。

  这是 iOS gate review 的前置条件之一。没有它，iOS Adapter
  的 contract 正确性无法系统性验证。

value:
  user_impact: HIGH
  rationale: |
    Core↔Shell 集成的最大风险点。iOS Adapter 需要验证 contract，
    AdapterHarness 提供标准化验证框架。没有它，iOS Shell 集成
    只能靠手动测试，效率极低且不可靠。

complexity:
  effort: MEDIUM
  rationale: |
    基于 ReaderCoreProtocols.HTTPClient / StorageAdapterProtocol /
    SchedulerAdapterProtocol 设计 mock 和 contract 模板。
    核心工作是定义 Adapter contract schema 和验证逻辑。

dependencies:
  - "ReaderCoreProtocols (frozen)"
  - "M1 API snapshot (complete)"

acceptance:
  - "可注入 mock/real adapter 的测试框架"
  - "Adapter contract 验证模板 (HTTP)"
  - "新 Adapter 实现可基于模板完成 contract 自检"
  - "Core→Adapter 调用链路可验证"

risk: "Adapter mock 设计可能遗漏边界场景"
```

#### TOOL-TraceInspector: Request/Response Trace Inspector

```yaml
id: TOOL-TraceInspector
name: "Request/Response Trace Inspector"
task: "OT-007"
priority: P0
description: |
  HTTPClient decorator 记录所有请求/响应，支持敏感数据脱敏。
  输出格式为结构化 JSON/YAML。可与 AdapterHarness 配合使用。

  这是 iOS gate review 的前置条件之一。没有它，HTTP 层调试
  依赖 CI log inspection，无法在本地快速定位问题。

value:
  user_impact: HIGH
  rationale: |
    HTTP 层可观测性是 Core↔Shell 调试的基础。当前调试需要
    CI log inspection，TraceInspector 提供本地即时可见性。
    与 AdapterHarness 互补。

complexity:
  effort: MEDIUM
  rationale: |
    可实现为 HTTPClient decorator。ReaderCoreProtocols.HTTPClient
    是自然的 seam。Decorator 方式不修改 production Core。

dependencies:
  - "HTTPClient protocol (frozen)"
  - "M1 API snapshot (complete)"

acceptance:
  - "HTTPClient decorator 记录所有请求/响应"
  - "支持敏感数据脱敏（cookie、authorization header 等）"
  - "输出格式为结构化 JSON/YAML"
  - "可与 AdapterIntegrationTestHarness 配合使用"

risk: "TraceInspector 可能记录敏感数据；脱敏配置必须默认开启"
```

---

### P1 / Optional Before iOS

#### TOOL-FixtureReplay_OR_SelectorTester: Fixture Replay / Selector Tester (二选一)

```yaml
id: TOOL-FixtureReplay_OR_SelectorTester
name: "Fixture Replay OR Selector Tester（二选一）"
task: "OT-008"
priority: P1_optional
description: |
  两个工具均为可选，不阻塞 iOS gate review。选择哪个取决于
  iOS Shell 开发中遇到的实际痛点。

  Fixture Replay: 本地 fixture 预检工具，解决 Windows 开发环境
  无法跑 Swift 测试的问题。

  Selector Tester: 独立 CSS 选择器验证工具，解决选择器调试
  效率问题。

value:
  user_impact: MEDIUM
  rationale: |
    Fixture Replay 解决 BLOCKED_BY_ENVIRONMENT 问题，
    Selector Tester 解决 CSS 调试效率问题。两者都是
    开发者效率工具，不阻塞 gate 但可提升开发体验。

complexity:
  effort: MEDIUM (Fixture Replay) / LOW (Selector Tester)
  rationale: |
    Fixture Replay: CLI runner + diff engine
    Selector Tester: 纯函数包装 (CSSExecutor)

dependencies:
  - "OT-006 (AdapterHarness as infrastructure)"

acceptance:
  fixture_replay:
    - "本地 fixture 预检工具，读取 fixture → 执行 parse → diff expected"
    - "输出人类可读 diff"
  selector_tester:
    - "输入：HTML + selector → 输出：匹配节点、提取文本、属性值"
    - "无副作用（纯函数）"

risk: "scope 膨胀，可能拖延 gate review 时间；应控制为一选一做"
```

---

### Deferred Until Post-iOS

#### TOOL-RuleDebugger: Rule Debugger

```yaml
id: TOOL-RuleDebugger
name: "Rule Debugger"
priority: deferred_post_ios
description: |
  Step-through debugger for rule evaluation. Given a BookSource rule
  string and HTML input, shows which CSS selector matched, what text
  was extracted, and how Replace/Regex transforms modified the output.

why_deferred: |
  HIGH complexity (需 instrument RuleScheduler/CSSExecutor/RuleParser),
  不阻塞 iOS gate。可在 iOS Shell 开发期间按需推进。

revisit_condition: "iOS Shell 稳定运行后，开发者反馈 rule debugging 是最大痛点时启动"
```

#### TOOL-RegressionDashboard: Regression Dashboard

```yaml
id: TOOL-RegressionDashboard
name: "Regression Dashboard"
priority: deferred_post_ios
description: |
  Web-based dashboard showing recent CI regression results, fixture
  drift trends, capability status over time, and per-sample level
  history.

why_deferred: |
  HIGH complexity (web frontend + data pipeline), 非阻塞。
  CI log inspection 虽不理想但可用。

revisit_condition: "回归测试数量超过 50 个 sample 或 fixture drift 频繁发生时启动"
```

#### TOOL-JSRuntimeInspector: JS Runtime Inspector

```yaml
id: TOOL-JSRuntimeInspector
name: "JS Runtime Inspector"
priority: deferred_post_ios
description: |
  Tool that shows what JavaScript code was executed in JSRuntimeDOMBridge,
  what DOM mutations occurred, and what the final HTML looks like after
  JS preprocessing.

why_deferred: |
  JSRuntimeDOMBridge is unstable module, JavaScriptCore inspection 有限。
  JS 相关调试可在 iOS Shell 中通过实际运行验证。

revisit_condition: "JS 预处理成为 iOS Shell 高频问题时启动"
```

#### TOOL-LoginBootstrapDebugger: Login Bootstrap Debugger

```yaml
id: TOOL-LoginBootstrapDebugger
name: "Login Bootstrap Debugger"
priority: deferred_post_ios
description: |
  Tool that traces the login bootstrap flow: shows the login form request,
  submitted credentials, Set-Cookie headers, and session verification.

why_deferred: |
  依赖 TraceInspector 基础设施（OT-007），但 login debugging
  不是 iOS gate 的前置。可在 Post-iOS 复用 TraceInspector。

revisit_condition: "login-required 书源在 iOS Shell 中频繁失败时启动"
```

#### TOOL-SnapshotRecorder: Fixture Snapshot Recorder

```yaml
id: TOOL-SnapshotRecorder
name: "Fixture Snapshot Recorder"
priority: deferred_post_ios
description: |
  Tool that captures Core output (search/toc/content results) as
  snapshot files during CI runs. Automatically generates expected
  files from successful CI runs.

why_deferred: |
  CI 集成复杂，自动审批流程需设计，非阻塞。
  当前 hand-crafted expected files 模式可用。

revisit_condition: "expected files 维护成为瓶颈时启动"
```

---

## Original Catalog Reference

以下为 v1.0.0 原始编目，保留供参考。ID 映射：

| v1.0.0 ID | v2.0.0 ID | 新优先级 |
|-----------|-----------|----------|
| TOOL-001 (Core Playground) | 合并入 TOOL-AdapterHarness | P0 |
| TOOL-002 (Fixture Replay) | TOOL-FixtureReplay_OR_SelectorTester | P1 Optional |
| TOOL-003 (Rule Debugger) | TOOL-RuleDebugger | Deferred |
| TOOL-004 (Request/Response Inspector) | TOOL-TraceInspector | P0 |
| TOOL-005 (Selector Tester) | TOOL-FixtureReplay_OR_SelectorTester | P1 Optional |
| TOOL-006 (JS Runtime Inspector) | TOOL-JSRuntimeInspector | Deferred |
| TOOL-007 (Login Bootstrap Debugger) | TOOL-LoginBootstrapDebugger | Deferred |
| TOOL-008 (Compatibility Diff Tool) | 合并入 TOOL-AdapterHarness | P0 |
| TOOL-009 (Fixture Snapshot Recorder) | TOOL-SnapshotRecorder | Deferred |
| TOOL-010 (Regression Dashboard) | TOOL-RegressionDashboard | Deferred |

---

## Milestone Mapping (Recalibrated)

```yaml
milestone_mapping:
  M1_complete:
    status: DONE
    items:
      - "Core_Public_API.md"
      - "Core_Module_Dependency.md"
      - "FIXTURE_INFRA_SPEC.md"
      - "TOOLING_BACKLOG.md"

  M2_minimal:
    status: PENDING
    gate_requirement: true
    items:
      - TOOL-AdapterHarness (OT-006)
      - TOOL-TraceInspector (OT-007)

  M2_optional:
    status: OPTIONAL
    gate_requirement: false
    items:
      - TOOL-FixtureReplay_OR_SelectorTester (OT-008)

  G1_ios_gate_review:
    status: PENDING
    items:
      - "Shell smoke validation"
      - "Architecture review"
      - "Gate decision"

  M3_extended:
    status: DEFERRED
    condition: "Post iOS gate approval, parallel with iOS Shell"
    items:
      - TOOL-RuleDebugger
      - TOOL-RegressionDashboard
      - TOOL-JSRuntimeInspector
      - TOOL-LoginBootstrapDebugger
      - TOOL-SnapshotRecorder
```

---

## Constraints

```yaml
constraints:
  - "No tool may modify Core production code"
  - "Tools must interact with Core via frozen protocols only"
  - "Tools must not introduce new dependencies that constrain Core evolution"
  - "Tool output must be machine-parseable (JSON/YAML) + human-readable"
  - "Tools must work on macOS CI and ideally on local Windows (via fixture replay)"
  - "No external GPL code in tool implementations"
  - "Clean-room principle applies to tool implementations"
  - "P0 tools must be complete before iOS gate review"
  - "P1 optional tools must not delay gate review"
  - "Deferred tools must not be started before gate review"
```

---

## Clean-Room Statement

```yaml
cleanRoom:
  basis: "Project state, capability status, and developer pain points documented in AGENTS.md and ROADMAP_PHASE2.md"
  noExternalGplCode: true
  noLegadoAndroidImplementationReference: true
  statement: "本工具编目仅基于仓库内部状态和已文档化的开发者需求产出。不引用外部 GPL 代码，不引用 Legado Android 实现。优先级校准仅基于 ROI 判断，不涉及实现变更。"
```
