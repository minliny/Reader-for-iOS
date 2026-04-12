# 开放任务 (OPEN_TASKS)

## 当前任务概览

| ID | 任务名称 | 状态 | 优先级 | 前置依赖 | 风险点 | 验收标准 | 是否允许 AI 独立完成 |
|----|----------|------|--------|----------|--------|----------|----------------------|
| OT-006 | Adapter Integration Harness | ci_verified | P0 | M1 complete ✅ | Adapter mock 设计遗漏边界场景 | Harness可注入mock/real adapter + contract验证模板 | yes |
| OT-007 | Request/Response Trace Inspector | ci_verified | P0 | M1 complete ✅ | 敏感数据泄露 | HTTPClient decorator记录全链路 + 脱敏 | yes |
| OT-008 | Optional: Fixture Replay / Selector Tester | pending | P1 | OT-006 | scope膨胀 | 二选一工具可用 | yes |
| OT-009 | iOS Phase Gate Review | conditional_allow | P0 | OT-006 + OT-007 ✅ | gate review 不通过 | Shell smoke + Architecture review + gate decision | yes |
| M-iOS-1 | Architecture Remediation (dependency boundary) | complete | P0 | OT-009 CONDITIONAL_ALLOW | 边界修复不彻底 | iOS Shell 零违规 import Core internals | yes |
| M-iOS-2 | Shell Build / CI / Boundary Gate | implementation_complete | P0 | M-iOS-1 ✅ | 已完成，无执行语义 | boundary gate + shell CI + construction smoke tests 建立完成 | yes |
| M-iOS-3 | Remote Shell Validation | fail | P0 | M-iOS-2 implementation_complete | iOS Shell compile 在远端 validation mode 下失败 | 真实 GitHub Actions 证据明确 PASS/FAIL 并记录首阻断点 | yes |

## 当前待办列表

### OT-006: Adapter Integration Harness

- 状态：`ci_verified` ✅
- 优先级：`P0`
- 前置依赖：Track D M1 complete (已满足)
- 风险点：Adapter mock 设计可能遗漏边界场景
- 验收标准：
  - AdapterIntegrationTestHarness: 可注入 mock/real adapter 的测试框架 ✅
  - Adapter contract 验证模板 (HTTP) ✅
  - 新 Adapter 实现可基于模板完成 contract 自检 ✅
  - Core→Adapter 调用链路可验证 ✅
- 交付物：
  - AdapterIntegrationTestHarness 实现 ✅ (Core/Sources/ReaderPlatformAdapters/AdapterIntegrationTestHarness.swift)
  - HTTP Adapter contract 验证模板 ✅ (AdapterContractVerifier.addHTTPContractTests)
  - Storage/Scheduler mock 预留 ✅
  - 测试套件 ✅ (Core/Tests/ReaderPlatformAdaptersTests/AdapterIntegrationTestHarnessTests.swift, 26 test cases)
  - 使用文档 — 内嵌于代码注释
- CI 验证：✅ PASS (macOS-14, Run #24300311259, 26/26 tests passed)
- URL validation fix: MockHTTPAdapter 现在使用 http/https scheme+host 验证，与 URLSessionHTTPClient.validatedURL 一致

### OT-007: Request/Response Trace Inspector

- 状态：`ci_verified` ✅
- 优先级：`P0`
- 前置依赖：Track D M1 complete (已满足)
- 风险点：TraceInspector 可能记录敏感数据（cookie、authorization header）
- 验收标准：
  - HTTPClient decorator 记录所有请求/响应 ✅
  - 支持敏感数据脱敏（cookie、authorization header 等）✅
  - 输出格式为结构化 TraceRecord ✅
  - 可与 AdapterIntegrationTestHarness 配合使用 ✅
- 交付物：
  - TraceInspector 实现（TracingHTTPClient decorator）✅
  - 脱敏配置（HeaderRedactionPolicy）✅
  - Body preview 截断（BodyPreviewConfig）✅
  - InMemoryTraceCollector ✅
  - 测试套件 ✅ (28 test cases, all passed on CI)
  - 使用文档 — 内嵌于代码注释
- CI 验证：✅ PASS (macOS-14, Run #24303727706, 28/28 TraceInspectorTests passed)
- CI fix 1: `await` in XCTest autoclosure → extract to `let` binding
- CI fix 2: URLError description platform-dependent → use non-empty string check

### OT-008: Optional — Fixture Replay / Selector Tester (二选一)

- 状态：`pending`
- 优先级：`P1`
- 前置依赖：OT-006 (AdapterHarness 作为基础设施)
- 风险点：scope 膨胀，可能拖延 gate review 时间
- 验收标准（Fixture Replay）：
  - 本地 fixture 预检工具，读取 fixture → 执行 parse → diff expected
  - 输出人类可读 diff
  - 本地 Windows 环境可用（不依赖 Swift runtime）
- 验收标准（Selector Tester）：
  - 独立 CSS 选择器验证工具
  - 输入：HTML + selector → 输出：匹配节点、提取文本、属性值
  - 无副作用（纯函数）
- 说明：此任务为可选，不阻塞 OT-009 (iOS Gate Review)。可根据 iOS Shell 开发中遇到的实际痛点决定是否执行及选择哪个。
- 是否允许 AI 独立完成：`yes`

### OT-009: iOS Phase Gate Review

- 状态：`pending`
- 优先级：`P0`
- 前置依赖：OT-006 + OT-007 完成
- 风险点：gate review 不通过，需补充条件后重新评估
- 验收标准：
  - Shell smoke validation: ReadingFlowCoordinator 可执行 import → search → selectBook → selectChapter 最短路径
  - Shell smoke validation: DefaultSearchService/TOCService/ContentService 与 Core 对接无编译错误
  - Shell smoke validation: 至少 1 个非 JS 书源端到端可走通
  - Architecture review: Core→Adapter→Shell 依赖方向正确（无循环依赖）
  - Architecture review: iOS Shell 未直接访问 Core 内部模块（仅通过 frozen protocols）
  - Architecture review: Adapter 层边界清晰
  - Gate review decision: approved / deferred with conditions / rejected
  - 若 approved: ios_gate.allowed = true
- 交付物：
  - Shell smoke validation report
  - Architecture review report
  - Gate review decision document
- 是否允许 AI 独立完成：`yes`（执行验证和出具报告，gate decision 需人工确认）

### M-iOS-2: Shell Build / CI / Boundary Gate

- 状态：`implementation_complete`
- 优先级：`P0`
- 前置依赖：`M-iOS-1` 已完成
- 风险点：Windows 本地环境无法直接提供 `swift` / `bash` 执行证据，需依赖 macOS GitHub Actions 完成最终编译验证
- 已完成：
  - `scripts/check_ios_boundary.sh` 已建立，禁止 `iOS/App/**`、`iOS/CoreIntegration/**`、`iOS/Features/**` 直接 import `ReaderCoreNetwork` / `ReaderCoreParser` / `ReaderCoreCache` / `ReaderCoreExecution`
  - `.github/workflows/ios-shell-ci.yml` 已建立，执行顺序为 `boundary gate -> swift build --package-path iOS -> swift test --filter ShellAssemblySmokeTests`
  - `iOS/Tests/ShellSmokeTests/ShellAssemblySmokeTests.swift` 已建立，验证 `ShellAssembly` 与 `ReadingFlowCoordinator` wiring
  - `docs/ios_shell_ci_gate.yml` 已记录当前 gate 结果
- 说明：
  - 该任务只表示 gate 建设完成，不等于远端执行通过
  - 远端执行结果由 `M-iOS-3` 单独记录

### M-iOS-3: Remote Shell Validation

- 状态：`fail`
- 优先级：`P0`
- 前置依赖：`M-iOS-2 implementation_complete`
- 当前远端证据：
  - run `24305799783`
  - workflow: `iOS Shell CI`
  - boundary gate: `PASS`
  - compile: `FAIL`
  - smoke tests: `UNKNOWN`（未启动）
- 第一阻断点：
  - step: `Compile iOS Shell composition root`
  - blocker: `iOS feature sources are not host-compilable under the current SwiftPM macOS validation mode`
  - observed symptoms:
    - `SearchView.swift`: `performSearch` 不在作用域
    - `SearchResultItem` / `TOCItem` 不满足 `Hashable` 的 `ForEach(id: \\.self)` 用法
    - `navigationBarTitleDisplayMode` 在 macOS 下 unavailable
    - `Color(.systemBackground)` 触发 macOS host compile 错误
- 待修项：
  - 先定义并批准 compile validation mode 的最小适配策略
  - 仅修复 compile 首阻断簇后，再重跑 `ios-shell-ci`

## 依赖关系图

```
OT-006 (AdapterHarness) ──┐
                           ├──→ OT-009 (iOS Gate Review)
OT-007 (TraceInspector) ──┘
      │
      └──→ OT-008 (Optional Fixture/Selector, P1, 不阻塞 gate)
```

## 已完成事实，不得继续保留为待办

- OT-005 (Track D M1: Core API Snapshot & Fixture Infrastructure) 已完成 — 4个交付物已创建
- OT-004 (Reader-Core baseline freeze stabilization) 已完成 — baseline 稳定，Track D 已启动
- Track D M1 交付物已创建：Core_Public_API.md, Core_Module_Dependency.md, FIXTURE_INFRA_SPEC.md, TOOLING_BACKLOG.md
- `sample_js_runtime_001` 闭环完成
- `sample_js_runtime_002` 闭环完成
- `sample_004` 闭环完成
- `sample_005` 闭环完成
- `SAMPLE-P1-CACHE-001` 闭环完成
- `SAMPLE-P1-CACHE-002` 闭环完成
- `SAMPLE-P1-CACHE-003` 闭环完成
- `SAMPLE-P1-COOKIE-001` 闭环完成
- `SAMPLE-P1-COOKIE-002` 闭环完成
- `SAMPLE-P1-ERROR-001` 闭环完成
- `SAMPLE-P1-ERROR-002` 闭环完成
- `SAMPLE-P1-ERROR-003` 闭环完成
- `SAMPLE-P1-POLICY-001` executable verification 完成
- `SAMPLE-P1-POLICY-002` executable verification 完成
- `SAMPLE-P1-POLICY-003` executable verification 完成
- `SAMPLE-P1-HEADER-001` executable verification 完成
- `SAMPLE-P1-HEADER-002` executable verification 完成
- `SAMPLE-P1-HEADER-003` executable verification 完成
- `P0 policy executable verification` 完成，runId `24194591412`，result `pass`
- Cookie capability VERIFIED + CLOSED，runId `24200148174`，117 tests pass
- Header capability VERIFIED + CLOSED，runId `24200529880`，117 tests pass
- Cache capability VERIFIED + CLOSED
- ErrorMapping capability CI VERIFIED + CLOSED，runId 24279408481，14/14 tests pass
- PolicyVerification capability CI VERIFIED + CLOSED，runId 24279408481，9/9 tests pass
- OT-003 (CI execution of freeze gate tests) 已完成
- JS DOM execution capability VERIFIED + CLOSED
- Login bootstrap capability VERIFIED + CLOSED
- Cookie isolation capability VERIFIED + CLOSED
- AntiBot capability OUT_OF_SCOPE (ROI NEGATIVE)
- JSNetwork capability OUT_OF_SCOPE (ROI NEGATIVE)
- Capability closure audit v1.1.0 完成
- Local code audit v1.0 完成：AGENTS.md 更新（uncovered_capabilities → 空，closed_samples 补全，iOS Shell 实际状态记录）
- OT-002 (Error mapping / Cache executable verification) 已完成（测试已编写，待 CI 确认）
- policy structure converged
- Core 继续作为统一事实基线
- Multiplatform architecture skeleton 已落地，且 `platformImplementationDone=false`
- Engineering architecture skeleton 已落地，且 `uiImplementationDone=false`
- Platform adapter minimal validation 已完成，`platform=macOS`，且 `fullAdapterLayerImplemented=false`
- Adapter contract hardening 已完成，`platform=macOS`，`validatedSamples=3`
- P0 policy layer convergence 已完成 executable verification
- SwiftPM circular dependency 已修复，ReaderPlatformAdapters 为 Core 内部 target
- Phase 2 strategy recalibrated: minimal_tooling_then_ios (v2.0.0)

## 当前状态约束

- 当前阶段：`m_ios_3_remote_validation_failed`
- 当前主线：`Reader-Core compatibility kernel → M-iOS-3 Remote Shell Validation`
- active_strategy：`minimal_tooling_then_ios`
- active_milestone：`m_ios_3`
- milestone_status：`fail`
- 当前未覆盖能力：无（所有能力已关闭或已裁决 out_of_scope）
- 冻结门禁状态：`READY_TO_FREEZE`
- 冻结门禁证据：ErrorMappingTests 14/14 passed + PolicyVerificationTests 9/9 passed (CI run 24279408481, macOS-14)
- 当前是否允许进入 iOS 阶段：`conditional`
- 判断原因：M-iOS-2 implementation complete；M-iOS-3 execution verified=true，但远端 compile 失败，下一步必须先做 blocker resolution，不能推进 M-iOS-4。
