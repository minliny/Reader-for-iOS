# iOS Phase Gate Review — OT-009

```yaml
review_id: OT-009
date: 2026-04-12
reviewer: AI Development Agent
decision: CONDITIONAL_ALLOW
phase: post_freeze_planning
execution_mode: recalibrated_phase2
baseline: "Reader-Core freeze gate CI VERIFIED (runs 24279408481, 24300311259, 24303727706)"
```

---

## 1. Reader-Core Frozen Baseline Audit

```yaml
baseline_status: FROZEN_AND_VERIFIED

core_contract_stabilization: COMPLETE
freeze_gate_status: READY_TO_FREEZE

closed_capabilities:
  - Header (CLOSED)
  - Cookie (CLOSED, 含 scoped isolation)
  - Cache (CLOSED)
  - ErrorMapping (CI_VERIFIED_CLOSED, 14/14, run 24279408481)
  - PolicyVerification (CI_VERIFIED_CLOSED, 9/9, run 24279408481)
  - JSDomExecution (CLOSED)
  - LoginBootstrap (CLOSED)
  - CookieIsolation (CLOSED)

out_of_scope_capabilities:
  - AntiBot (ROI NEGATIVE)
  - JSNetwork (ROI NEGATIVE)

uncovered_capabilities: []

ci_evidence:
  - "ErrorMappingTests: 14/14 passed (run 24279408481)"
  - "PolicyVerificationTests: 9/9 passed (run 24279408481)"
  - "AdapterIntegrationTestHarnessTests: 26/26 passed (run 24300311259)"
  - "TraceInspectorTests: 28/28 passed (run 24303727706)"

protocol_layer:
  total_protocols: 22
  coverage: "Contracts + Network + Parser + Cache + PlatformAdapter"
  frozen_symbols: 73 (per Core_Public_API.md)

verdict: PASS — Core baseline is frozen, all capabilities closed or out-of-scope, CI evidence sufficient.
```

---

## 2. Tooling Readiness Audit

```yaml
tooling_status: M2_MINIMAL_COMPLETE

OT-006_AdapterIntegrationTestHarness:
  status: CI_VERIFIED
  ci_run: 24300311259
  tests: 26/26 passed
  delivers:
    - "可注入 mock/real adapter 的测试框架"
    - "Adapter contract 验证模板 (HTTP)"
    - "Storage/Scheduler mock 预留"
    - "URL validation (http/https scheme+host)"

OT-007_TraceInspector:
  status: CI_VERIFIED
  ci_run: 24303727706
  tests: 28/28 passed
  delivers:
    - "TracingHTTPClient decorator (HTTPClient → traced HTTPClient)"
    - "HeaderRedactionPolicy (10 default sensitive headers)"
    - "BodyPreviewConfig (1KB default, UTF-8/binary)"
    - "InMemoryTraceCollector (actor-safe)"

OT-008_Optional:
  status: PENDING (不阻塞 gate)
  note: "Fixture Replay 或 Selector Tester 可在 iOS Shell 开发期间按需推进"

verdict: PASS — M2 minimal subset complete. Both P0 tooling items CI verified.
```

---

## 3. Existing iOS Shell Skeleton Audit

```yaml
shell_maturity: SKELETON_WITH_REAL_IMPLEMENTATION

code_inventory:
  total_files: 19 Swift files
  total_lines: ~1500 LOC (estimate)

app_entry:
  - ReaderApp.swift: @main, SwiftUI App, uses ReadingFlowCoordinator.makeDefault()
  - AppEntry.swift: metadata struct (appName, minimumCoreVersion)

core_integration:
  - ReadingFlowCoordinator.swift: @MainActor ObservableObject, 181 LOC
    - Published: selectedSource, searchResults, selectedBook, tocItems, selectedChapter, contentPage, isLoading, currentError
    - Protocol dependencies: BookSourceRepository, BookSourceDecoder, SearchService, TOCService, ContentService, ErrorLogger
    - makeDefault() factory: creates URLSessionHTTPClient + BookSourceRequestBuilder + NonJSRuleScheduler + NonJSParserEngine + InMemoryErrorLogger
    - Flow: importBookSource → search → selectBook → selectChapter

  - DefaultSearchService.swift: implements SearchService protocol ✅
  - DefaultTOCService.swift: implements TOCService protocol ✅
  - DefaultContentService.swift: implements ContentService protocol ✅
  - InMemoryBookSourceRepository.swift: implements BookSourceRepository protocol ✅
  - DefaultBookSourceDecoder.swift: implements BookSourceDecoder protocol ✅

swiftui_views:
  - BookSourceImportView: Form with text import + NavigationLink to SearchView
  - SearchView: Search bar + LazyVStack results list + NavigationLink to TOCView
  - TOCView: LazyVStack chapter list + NavigationLink to ContentView
  - ContentView: ScrollView content reader with title + body

common_views:
  - ErrorView: Displays ReaderError with retry button
  - LoadingView: ProgressView with message

modules:
  - BootstrapModule: protocol + no-op default
  - ReaderModuleBoundary: capability flags (canImportBookSource, canSearch, canReadContent)
  - ReaderShellEnvironment: appEntry + supportsDebugOverlay

test_coverage:
  - SmokeTests.swift: 1 placeholder test (XCTAssertTrue(true))
  - real_coverage: ZERO

missing_capabilities:
  - Disk persistence (InMemoryBookSourceRepository only)
  - Multi-source management (single source selection)
  - Settings/preferences UI
  - Any automated test
  - Chapter navigation (previous/next)
  - Content pagination
  - Search result pagination

assessment: |
  iOS Shell 有完整的 import→search→TOC→content 导航路径代码，
  但缺乏测试验证、磁盘持久化、多书源管理。
  核心流程代码质量尚可，结构清晰，但 makeDefault() 
  工厂方法硬编码了 Core 内部具体类型，构成架构违规。
```

---

## 4. Adapter Boundary Integrity Audit

```yaml
verdict: FAIL — 存在严重依赖边界泄漏

findings:

  FINDING-1: iOS Shell 直接导入 Core 内部实现模块
    severity: HIGH
    files:
      - ReadingFlowCoordinator.swift: import ReaderCoreNetwork + ReaderCoreParser + ReaderCoreCache + ReaderCoreFoundation
      - DefaultSearchService.swift: import ReaderCoreNetwork + ReaderCoreParser
      - DefaultTOCService.swift: import ReaderCoreNetwork + ReaderCoreParser
      - DefaultContentService.swift: import ReaderCoreNetwork + ReaderCoreParser
    total_violations: 10 import statements across 4 files
    expected: Shell 应仅依赖 ReaderCoreProtocols + ReaderCoreModels

  FINDING-2: iOS Shell 未使用 Adapters/ 层
    severity: HIGH
    evidence: |
      - iOS/Package.swift 不依赖 ReaderPlatformAdapters
      - iOS/ 目录下无 import ReaderPlatformAdapters
      - ReadingFlowCoordinator.makeDefault() 直接 new URLSessionHTTPClient / BookSourceRequestBuilder / NonJSRuleScheduler / NonJSParserEngine
      - 已有 Adapters/HTTP/ 提供 HTTPAdapterFactory.makeDefault()，但 iOS Shell 未使用
    expected: Shell 应通过 Adapters/ 层或 CoreAdapterDependencies 获取 HTTP 适配器

  FINDING-3: Default*Service 调用协议签名不匹配的方法
    severity: MEDIUM
    evidence: |
      - SearchParser 协议定义: parseSearchResponse(_:source:query:)
      - DefaultSearchService 调用: searchParser.parse(html:source:)
      - TOCParser 协议定义: parseTOCResponse(_:source:detailURL:)
      - DefaultTOCService 调用: tocParser.parse(html:source:detailURL:)
      - ContentParser 协议定义: parseContentResponse(_:source:chapterURL:)
      - DefaultContentService 调用: contentParser.parse(html:source:chapterURL:)
    explanation: |
      NonJSParserEngine 同时实现了协议方法和 parse(html:) 便捷方法。
      iOS Shell 通过 import ReaderCoreParser 获得了 parse(html:) 的访问权，
      绕过了协议层定义的 Data 输入签名，直接传了 HTML string。
      这意味着 Default*Service 在编译时依赖的是具体类型而非协议。
    impact: "如果替换 Parser 实现，Default*Service 将无法工作"

  FINDING-4: InMemoryBookSourceRepository 和 DefaultBookSourceDecoder 合规
    severity: NONE
    evidence: "仅导入 ReaderCoreModels + ReaderCoreProtocols，完全合规"

  FINDING-5: Adapters/ 层自身合规
    severity: NONE
    evidence: "Adapters/HTTP/Package.swift 仅依赖 ReaderCoreProtocols + ReaderCoreModels"
```

---

## 5. Shell/Core Integration Path Audit

```yaml
dependency_direction:
  expected: "Shell → Adapter → Core (Protocols + Models)"
  actual: "Shell → Core (Protocols + Models + Parser + Network + Cache + Foundation)"
  verdict: VIOLATED

circular_dependencies:
  detected: NONE
  note: "依赖方向正确（无反向依赖），但跨层了"

protocol_usage:
  correctly_used:
    - "ReadingFlowCoordinator 依赖 BookSourceRepository / BookSourceDecoder / SearchService / TOCService / ContentService / ErrorLogger (全部为协议)"
    - "DefaultSearchService / DefaultTOCService / DefaultContentService 声明遵守 Core 协议"
    - "InMemoryBookSourceRepository 声明遵守 BookSourceRepository 协议"
    - "DefaultBookSourceDecoder 声明遵守 BookSourceDecoder 协议"
  
  incorrectly_used:
    - "makeDefault() 直接实例化 URLSessionHTTPClient（属于 ReaderCoreNetwork 内部类型）"
    - "makeDefault() 直接实例化 BookSourceRequestBuilder（属于 ReaderCoreNetwork 内部类型）"
    - "makeDefault() 直接实例化 NonJSRuleScheduler + NonJSParserEngine（属于 ReaderCoreParser 内部类型）"
    - "Default*Service 调用 parse(html:) 而非协议定义的 parseSearchResponse / parseTOCResponse / parseContentResponse"

integration_smoke_feasibility:
  can_compile: "UNKNOWN — iOS Shell 无独立 CI，从未在 macOS/iOS CI 上编译过"
  can_run: "UNKNOWN — 从未在真机或模拟器上运行过"
  can_trace: "YES — TracingHTTPClient 可在 makeDefault() 中包装 URLSessionHTTPClient"
```

---

## 6. Remaining Technical Risks

```yaml
risks:

  RISK-1: iOS Shell 从未编译或运行
    severity: HIGH
    probability: CERTAIN
    mitigation: "Phase 2c 首要任务：建立 iOS Shell CI + smoke test"
    impact: "Shell 代码可能是死代码（虽然结构合理）"

  RISK-2: Parser 协议签名不一致
    severity: HIGH
    probability: CONFIRMED
    mitigation: "修改 Default*Service 使用协议定义的 parseSearchResponse/parseTOCResponse/parseContentResponse 方法签名"
    impact: "无法替换 Parser 实现，违反开闭原则"

  RISK-3: 硬编码 Core 内部类型
    severity: MEDIUM
    probability: CONFIRMED
    mitigation: "将 makeDefault() 迁移到 Adapters/ 层或使用 CoreAdapterDependencies"
    impact: "Core 内部重构将导致 iOS Shell 编译失败"

  RISK-4: InMemoryBookSourceRepository 无持久化
    severity: MEDIUM
    probability: BY_DESIGN
    mitigation: "Phase 2c 实现 DiskBookSourceRepository"
    impact: "App 重启后数据丢失，不可作为生产版本"

  RISK-5: 零测试覆盖
    severity: MEDIUM
    probability: CONFIRMED
    mitigation: "Phase 2c 建立 iOS Shell 测试框架"
    impact: "无法回归验证 Shell 行为"

  RISK-6: Pre-existing CI failures (14 tests)
    severity: LOW
    probability: CONFIRMED
    affected_tests:
      - JSIntegrationTests (3 failures)
      - JSRuntimeDOMBridgeTests (5 failures)
      - LoginBootstrapTests (5 failures)
      - NetworkPolicyLayerTests (1 failure)
    mitigation: "不阻塞 iOS Shell，可在 Phase 2c 并行修复"
    impact: "CI 信号有噪音但不影响 Shell 开发"
```

---

## 7. Gate Conditions Assessment

```yaml
conditions:

  - condition: "Track D M1 complete"
    status: COMPLETE
    evidence: "Core_Public_API.md + Core_Module_Dependency.md + FIXTURE_INFRA_SPEC.md + TOOLING_BACKLOG.md"

  - condition: "Minimal M2 tooling subset complete (AdapterHarness + TraceInspector)"
    status: COMPLETE
    evidence: "OT-006 CI_VERIFIED (run 24300311259, 26/26) + OT-007 CI_VERIFIED (run 24303727706, 28/28)"

  - condition: "Shell smoke validation complete"
    status: NOT_COMPLETE
    sub_conditions:
      - "ReadingFlowCoordinator 可成功执行 import → search → selectBook → selectChapter 最短路径": NOT_VALIDATED
      - "DefaultSearchService/TOCService/ContentService 与 Core 对接无编译错误": NOT_VALIDATED
      - "至少 1 个非 JS 书源端到端可走通": NOT_VALIDATED
    note: "iOS Shell 从未在 CI 或设备上编译/运行"

  - condition: "Architecture review pass"
    status: NOT_COMPLETE
    sub_conditions:
      - "Core→Adapter→Shell 依赖方向正确（无循环依赖）": PARTIAL_PASS
        detail: "方向正确（无循环），但 Shell 绕过 Adapter 层直接访问 Core 内部模块"
      - "iOS Shell 未直接访问 Core 内部模块（仅通过 frozen protocols）": FAIL
        detail: "4 个文件直接 import 3 个内部实现模块，10 处违规"
      - "Adapter 层边界清晰": FAIL
        detail: "iOS Shell 完全未使用 Adapters/ 层，makeDefault() 直接 new 内部类型"
```

---

## 8. Gate Decision

```yaml
decision: CONDITIONAL_ALLOW

rationale: |
  1. Core baseline frozen 且 CI verified — 满足
  2. M2 minimal tooling subset complete 且 CI verified — 满足
  3. iOS Shell 有完整的流程代码（import→search→TOC→content）— 代码存在但未验证
  4. Shell smoke validation — 未执行，不可判定
  5. Architecture review — 依赖方向正确但边界泄漏严重

  综合判断：
  - 不满足无条件 ALLOW（架构违规 + 无 smoke validation）
  - 不判定 DENY（代码存在且结构合理，违规可修复）
  - 判定 CONDITIONAL_ALLOW：允许在满足前置条件后进入 iOS Shell Execution Phase

conditions_to_lift_before_ios_execution:

  CONDITION-1: 修复 iOS Shell 依赖边界泄漏
    action: |
      a. Default*Service 改用协议定义的方法签名（parseSearchResponse/parseTOCResponse/parseContentResponse）
      b. 移除 Default*Service 对 ReaderCoreNetwork/ReaderCoreParser 的直接 import
      c. ReadingFlowCoordinator.makeDefault() 通过 HTTPAdapterFactory 或 CoreAdapterDependencies 获取 httpClient
      d. iOS/Package.swift 移除对 ReaderCoreParser/ReaderCoreNetwork/ReaderCoreCache/ReaderCoreFoundation 的依赖
    acceptance: "iOS Shell 代码仅 import ReaderCoreModels + ReaderCoreProtocols (+ SwiftUI)"

  CONDITION-2: 建立 iOS Shell 编译验证
    action: "在 CI 中添加 iOS Shell build 步骤（xcodebuild 或 swift build）"
    acceptance: "iOS Shell 代码可在 macOS/iOS CI 上成功编译"

  CONDITION-3: 执行 Shell smoke validation
    action: |
      a. 验证 ReadingFlowCoordinator 可成功初始化
      b. 验证 import→search→selectBook→selectChapter 调用链路无崩溃
      c. 至少 1 个非 JS 书源端到端可走通
    acceptance: "Smoke test report 记录成功路径"
```

---

## 9. iOS Phase Plan

```yaml
ios_phase_plan:

  prerequisites:
    - CONDITION-1: 修复依赖边界泄漏（估计 1–2 天）
    - CONDITION-2: 建立 iOS Shell CI 编译（估计 0.5 天）
    - CONDITION-3: Shell smoke validation（估计 1–2 天）

  milestones:

    M-iOS-1: Architecture Remediation
      goal: "修复 iOS Shell 依赖边界泄漏，使其仅通过 protocols 消费 Core"
      duration: "1–2 days"
      deliverables:
        - "Default*Service 使用协议方法签名"
        - "ReadingFlowCoordinator 通过 DI 获取具体类型"
        - "iOS/Package.swift 仅依赖 ReaderCoreModels + ReaderCoreProtocols"
      acceptance:
        - "iOS Shell 代码中零 import ReaderCoreNetwork/ReaderCoreParser/ReaderCoreCache"
        - "swift build 成功"

    M-iOS-2: Shell Smoke Validation
      goal: "验证 iOS Shell 可编译、可运行、主链路可走通"
      duration: "1–2 days"
      deliverables:
        - "iOS Shell CI build step"
        - "ReadingFlowCoordinator smoke test"
        - "端到端测试报告（至少 1 个非 JS 书源）"
      acceptance:
        - "CI build green"
        - "Smoke test report with pass result"

    M-iOS-3: Shell Stabilization
      goal: "从 skeleton 到可用 app"
      duration: "3–4 weeks"
      deliverables:
        - "Disk persistence (DiskBookSourceRepository)"
        - "Multi-source management"
        - "Chapter navigation (previous/next)"
        - "Content pagination"
        - "Settings/preferences UI"
        - "iOS Shell test suite"
      acceptance:
        - "至少 3 个非 JS 书源端到端可走通"
        - "iOS Shell test suite 覆盖率 > 60%"
        - "App 可在模拟器上正常运行"

  workstreams:
    - workstream: "Architecture remediation"
      priority: P0
      milestone: M-iOS-1
    - workstream: "Smoke validation"
      priority: P0
      milestone: M-iOS-2
    - workstream: "Shell feature completion"
      priority: P0
      milestone: M-iOS-3
    - workstream: "Optional tooling (OT-008)"
      priority: P1
      milestone: parallel with M-iOS-3
    - workstream: "Pre-existing CI failure fix"
      priority: P2
      milestone: parallel with M-iOS-3

  risks:
    - risk: "Parser 协议签名改换可能导致 NonJSParserEngine 便捷方法不可用"
      mitigation: "在 Default*Service 中做 Data→String 转换，调用协议方法"
    - risk: "iOS Shell build 可能暴露 Core 内部 API 不兼容"
      mitigation: "M-iOS-1 中发现则立即修复"
    - risk: "InMemoryBookSourceRepository 无法支撑真实使用场景"
      mitigation: "M-iOS-3 优先实现 DiskBookSourceRepository"
```

---

## 10. Clean-Room Statement

```yaml
clean_room:
  no_external_gpl_code: true
  no_legado_android_reference: true
  statement: |
    本 Gate Review 仅基于仓库内部代码、状态文件、CI 证据和架构文档产出。
    所有判断绑定真实代码与状态证据。
    不引用外部 GPL 代码，不引用 Legado Android 实现。
    未修改 Core baseline 或 Tooling 代码。
```

---

## 11. Decision Summary

| Gate Condition | Status | Evidence |
|---|---|---|
| Track D M1 complete | ✅ COMPLETE | 4 deliverables delivered |
| Minimal M2 tooling subset complete | ✅ COMPLETE | OT-006 + OT-007 CI VERIFIED |
| Shell smoke validation complete | ❌ NOT VALIDATED | Never compiled or run |
| Architecture review pass | ⚠️ PARTIAL | Direction correct, boundary violated |

**Gate Decision: CONDITIONAL_ALLOW**

- iOS Shell Execution Phase 允许在满足 3 个前置条件后进入
- 前置条件：修复依赖边界泄漏 + 建立 CI 编译 + 执行 smoke validation
- 预计前置条件满足时间：3–5 天
- 进入后主线：Architecture Remediation → Smoke Validation → Shell Stabilization
