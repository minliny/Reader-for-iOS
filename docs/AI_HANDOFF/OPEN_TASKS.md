# 开放任务 (OPEN_TASKS)

## 当前任务概览

> 工程整理状态：`main` 已成为当前唯一可信主线，并已与 `origin/main` 对齐；远端历史分支已清理完成。当前 iOS 工作基线已推进到 `M-IOS-7` 并在 GitHub Actions 上真实通过。

| ID | 任务名称 | 状态 | 优先级 | 前置依赖 | 风险点 | 验收标准 | 是否允许 AI 独立完成 |
|----|----------|------|--------|----------|--------|----------|----------------------|
| OT-006 | Adapter Integration Harness | ci_verified | P0 | M1 complete ✅ | Adapter mock 设计遗漏边界场景 | Harness可注入mock/real adapter + contract验证模板 | yes |
| OT-007 | Request/Response Trace Inspector | ci_verified | P0 | M1 complete ✅ | 敏感数据泄露 | HTTPClient decorator记录全链路 + 脱敏 | yes |
| OT-008 | Optional: Fixture Replay / Selector Tester | pending | P1 | OT-006 | scope膨胀 | 二选一工具可用 | yes |
| OT-009 | iOS Phase Gate Review | complete | P0 | OT-006 + OT-007 ✅ | 已完成，无当前阻断 | Shell smoke + Architecture review + gate decision | yes |
| M-iOS-1 | Architecture Remediation (dependency boundary) | complete | P0 | OT-009 CONDITIONAL_ALLOW | 边界修复不彻底 | iOS Shell 零违规 import Core internals | yes |
| M-iOS-2 | Shell Build / CI / Boundary Gate | implementation_complete | P0 | M-iOS-1 ✅ | 已完成，无执行语义 | boundary gate + shell CI + construction smoke tests 建立完成 | yes |
| M-iOS-3 | Remote Shell Validation | complete | P0 | M-iOS-2 implementation_complete | 已完成：首阻断点已定位 | 真实 GitHub Actions 证据明确 PASS/FAIL 并记录首阻断点 | yes |
| M-IOS-4 | Shell Validation Scope Isolation | complete | P0 | M-iOS-3 complete | 已完成，无新增风险 | validation scope 与 execution semantics 分离，并拿到新的远端执行证据 | yes |
| M-IOS-5 | Validation Glue Alignment | complete | P0 | M-IOS-4 complete | 已完成，无当前阻断 | validation-only glue 对齐 frozen dependency graph，boundary/compile/smoke 远端全绿 | yes |
| M-IOS-6 | Reader Feature Wiring | complete | P0 | M-IOS-5 complete | 已完成，无当前阻断 | Reader 主链路入口接入壳层且不破坏 ios-shell-ci green baseline | yes |
| M-IOS-7 | Reader Flow Functional Validation | complete | P1 | M-IOS-6 complete | 已完成，当前仅保留非阻断 warning | 在保持现有 green baseline 的前提下验证最小 Search -> TOC -> Content 功能链路 | yes |
| M-IOS-8 | Reader Flow Failure-State Hardening | pending | P1 | M-IOS-7 complete | 若扩大到产品化 UI 或重新放宽 compile scope 会偏离范围 | 在 M-IOS-7 baseline 上补最小 failure-state / state-sync 覆盖 | yes |

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

- 状态：`complete`
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
  - Shell smoke validation report ✅
  - Architecture review report ✅
  - Gate review decision document ✅
- 当前结论：
  - `ios_gate.allowed = conditional`
  - `decision = CONDITIONAL_ALLOW`
  - 后续 iOS 工作仅允许沿 M-IOS-1 ~ M-IOS-7 既定最小 Reader 路径推进
- 是否允许 AI 独立完成：`yes`

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

- 状态：`complete`
- 优先级：`P0`
- 前置依赖：`M-iOS-2 implementation_complete`
- 当前远端证据：
  - run `24305799783`
  - workflow: `iOS Shell CI`
  - boundary gate: `PASS`
  - compile: `FAIL`
  - smoke tests: `UNKNOWN`（未启动）
- 结果：
  - 已完成真实远端验证取证
  - 已定位原始阻断点：`SwiftPM interim host compile scope 过宽，把 iOS-only Features 层纳入了 macOS host validation`
  - 后续修复已转入 `M-IOS-4`

### M-IOS-4: Shell Validation Scope Isolation

- 状态：`complete`
- 优先级：`P0`
- 前置依赖：`M-iOS-3 complete`
- 已完成：
  - `ReaderShellValidation` 作为 isolated host-compilable validation target 已建立
  - workflow compile 已收敛到 `swift build --package-path iOS --target ReaderShellValidation`
  - workflow smoke 已收敛到 isolated test product，不再把 `iOS/Features/**` 作为首阻断输入
  - phase status / validation result / execution verified 已拆分记录到 `docs/ios_shell_ci_gate.yml`
- 结果：
  - iOS-only Features/UI 已持续排除在 macOS host compile gate 之外
  - 后续 validation glue 对齐已转入 `M-IOS-5` 并完成

### M-IOS-5: Validation Glue Alignment

- 状态：`complete`
- 优先级：`P0`
- 前置依赖：`M-IOS-4 complete`
- 已完成：
  - `iOS/ValidationSupport/ShellAssembly.swift` 已对齐 frozen dependency graph
  - `URLSessionHTTPClient` 已通过 `ReaderPlatformAdapters` 暴露给 `ReaderShellValidation`
  - `NonJSParserEngine` 初始化已对齐为真实 `scheduler:` 签名
  - 远端复验 run `24306965324` 全绿
- 当前远端证据：
  - latest run `24306965324`
  - boundary gate: `PASS`
  - compile: `PASS`
  - smoke tests: `PASS`
  - executionVerified: `true`
- 结果：
  - `phaseStatus=PASS`
  - `validationResult=PASS`
  - `executionVerified=true`

### M-IOS-6: Reader Feature Wiring

- 状态：`complete`
- 优先级：`P0`
- 前置依赖：`M-IOS-5 complete`
- 已完成：
  - `ReaderApp` 启动路径已切到 `ReaderFlowFeatureView`
  - 正式 `iOS/Shell/ShellAssembly.swift` 已用于 app wiring，不再依赖 validation-only glue 作为正式入口
  - `BookSourceImportView` / `SearchView` / `TOCView` / `ContentView` 已修正为可承接最小 reader 主链路
  - `ReaderFlowFeatureState` 已提供最小 feature state 汇总
  - shell smoke 增加 action reachability 验证，并在远端通过
- 当前远端证据：
  - latest run `24307509812`
  - boundary gate: `PASS`
  - compile: `PASS`
  - smoke tests: `PASS`
  - executionVerified: `true`
- 结果：
  - `phaseStatus=PASS`
  - `validationResult=PASS`
  - `executionVerified=true`

### M-IOS-7: Reader Flow Functional Validation

- 状态：`complete`
- 优先级：`P1`
- 前置依赖：`M-IOS-6 complete`
- 约束：
  - 不得重新扩大 `ReaderShellValidation` compile scope
  - 不得把 `iOS/Features/**` / UI 页面重新纳入 host compile gate
  - 必须继续沿用 `phaseStatus / validationResult / executionVerified` 三层语义
- 已完成：
  - `ReaderFlowFunctionalValidationTests` 已建立，并保持在 `iOS/Tests/ShellSmokeTests` 范围内
  - `sample_004` / `sample_005` 已完成 fixture-backed import -> search -> toc -> content 全链路验证
  - content 阶段受控 `HTTP 404` 错误路径已验证为 non-crashing / non-silent
  - `ios-shell-ci` 已增加 functional validation 步骤，且不替代原 shell baseline
- 当前远端证据：
  - latest run `24345092018`
  - artifact `6406027921`
  - boundary gate: `PASS`
  - compile: `PASS`
  - smoke tests: `PASS`
  - functional validation: `PASS`
  - executionVerified: `true`
- 结果：
  - `phaseStatus=PASS`
  - `validationResult=PASS`
  - `executionVerified=true`

### M-IOS-8: Reader Flow Failure-State Hardening

- 状态：`pending`
- 优先级：`P1`
- 前置依赖：`M-IOS-7 complete`
- 约束：
  - 不得破坏 `docs/ios_shell_ci_gate.yml` 记录的 M-IOS-7 functional baseline
  - 不得重新扩大 `ReaderShellValidation` compile scope
  - 不得扩写 UI 产品化需求或新增与 Reader 主链路无关功能
- 目标：
  - 只补最小 failure-state / state-sync 验证
  - 覆盖导入失败、搜索失败、目录失败、正文失败中的高价值最小集合
  - 保持 `phaseStatus / validationResult / executionVerified` 三层语义

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

- 当前阶段：`m_ios_7_reader_flow_functionally_validated`
- 当前主线：`Reader-Core compatibility kernel → M-IOS-7 Reader Flow Functional Validation`
- active_strategy：`minimal_tooling_then_ios`
- active_milestone：`m_ios_7`
- milestone_status：`pass`
- 当前未覆盖能力：无（所有能力已关闭或已裁决 out_of_scope）
- 冻结门禁状态：`READY_TO_FREEZE`
- 冻结门禁证据：ErrorMappingTests 14/14 passed + PolicyVerificationTests 9/9 passed (CI run 24279408481, macOS-14)
- 当前是否允许进入 iOS 阶段：`conditional`
- 判断原因：M-IOS-7 已把最小 Reader 主链路功能验证跑通并保持 baseline 远端全绿；下一步只允许进入 M-IOS-8 的 failure-state hardening，不得回退到宽 scope compile 或扩成完整产品化 UI。
