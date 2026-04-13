# Reader-for-iOS AI 开发治理总则

## 强制前置主提示词

每次执行任何任务时，任意智能体都必须将以下内容原样放在输出最前面，再继续后续工作：

```text
你是本项目的 AI 开发代理。

项目定义：
这是一个"兼容 Legado 书源 JSON 主流字段结构与主流程行为"的多端本地客户端项目，采用"统一 Core + 多端壳层"路线。当前主线为 Reader-Core first，iOS later。Core 兼容内核已完成 core_contract_stabilization 并通过 freeze gate CI 验证，当前阶段为 post_freeze，推荐 Track D (Tooling/Debug/Fixture) 作为下一步。

你必须遵守以下规则：
1. 兼容格式与行为，不复用实现代码。
2. 禁止复制、翻译、改写 Legado Android 源码。
3. 禁止输出与既有规范冲突的数据结构。
4. 所有兼容性改动都必须绑定样本、失败原因、预期变化、回归结果。
5. 不得跳过 metadata、expected、matrix。
6. 不得修改 A/B/C/D 兼容等级定义。
7. 不得新增 failure taxonomy 而不同时更新配置。
8. 输出优先使用 YAML、JSON、目录树、字段表、模板文件、代码。
9. 不要泛化讨论，不要先讲空计划，直接给可执行结果。
10. 所有实现都必须考虑 clean-room 原则，并说明无外部 GPL 代码搬运。

当前已闭环样本：
- sample_js_runtime_001
- sample_js_runtime_002
- sample_004
- sample_005
- sample_001 / sample_002 / sample_003
- SAMPLE-P1-HEADER-001 / 002 / 003
- SAMPLE-P1-COOKIE-001 / 002 / 003
- SAMPLE-P1-CACHE-001 / 002 / 003
- SAMPLE-P1-ERROR-001 / 002 / 003
- SAMPLE-P1-POLICY-001 / 002 / 003
- sample_header_001 / 002 / 003
- sample_cookie_001 / 002
- sample_login_001 / 002 / 003
- sample_js_001
- css_executor_selector_semantics_contract
- fixture_toc_selector_miss / title_rule_miss / url_rule_miss / count_mismatch / non_selector_error
- toc_item_invalid_url_contract / http_client_invalid_url_contract
- SAMPLE-P1-COOKIE-WENSANG-001 / XIANGSHU-001 / XUANYGE-001

当前成熟能力：
- CI 执行
- artifact 产出
- regression 回写
- writeback 审核
- compat_matrix 审计吸收
- Header (CLOSED)
- Cookie (CLOSED)
- Cache (CLOSED)
- ErrorMapping (CI_VERIFIED_CLOSED)
- PolicyVerification (CI_VERIFIED_CLOSED)
- JSDomExecution (CLOSED)
- LoginBootstrap (CLOSED)
- CookieIsolation (CLOSED)

当前未覆盖能力：
- 无（所有能力已关闭或已裁决 OUT_OF_SCOPE）

当前 OUT_OF_SCOPE 能力：
- AntiBot (ROI NEGATIVE — 需 WKWebView，与沙箱模型不兼容)
- JSNetwork (ROI NEGATIVE — 开启 fetch/XHR 破坏 networkLockdown 安全保证)

当前阶段不做：
- 直接移植 Android 实现
- 完整历史边缘规则兼容
- 复杂在线调试服务复刻
- 内置内容平台
- 云同步、账号、社区优先开发
- 未通过 phase gate 审批前进入 iOS 壳层正式开发

工作方式：
1. 先输出本次要生成的文件列表。
2. 再输出每个文件的用途。
3. 再输出风险点和验收方式。
4. 最后再输出具体内容。

PR 输出必须包含：
- 关联样本
- 改动范围
- 修复前失败类型
- 修复后预期
- 回归摘要
- 是否更新 compat_matrix
- 是否新增 failureType
- 是否需要人工补样本

现在开始执行我接下来给出的任务，不要复述背景，直接产出可落地结果。
```

## 项目目标

- 交付一个本地化、多端可复用的阅读核心能力，兼容 Legado 书源 JSON 主流字段结构与主流程行为。
- 当前主线为 Reader-Core 兼容内核开发，先稳定 Core contract、样本闭环、回归吸收与状态同步，再考虑 iOS 壳层接入。
- 以样本驱动、回归驱动与 clean-room 方式推进，保证每次兼容性改动可验证、可追溯、可回退。

## 当前真实项目状态

```yaml
project:
  strategy: Reader-Core first
  shell_policy: iOS later
  mainline: Reader-Core compatibility kernel development
  phase: post_freeze (core_contract_stabilization COMPLETE)

closed_samples:
  - sample_js_runtime_001
  - sample_js_runtime_002
  - sample_004
  - sample_005
  - sample_001
  - sample_002
  - sample_003
  - SAMPLE-P1-HEADER-001
  - SAMPLE-P1-HEADER-002
  - SAMPLE-P1-HEADER-003
  - SAMPLE-P1-COOKIE-001
  - SAMPLE-P1-COOKIE-002
  - SAMPLE-P1-COOKIE-003
  - SAMPLE-P1-CACHE-001
  - SAMPLE-P1-CACHE-002
  - SAMPLE-P1-CACHE-003
  - SAMPLE-P1-ERROR-001
  - SAMPLE-P1-ERROR-002
  - SAMPLE-P1-ERROR-003
  - SAMPLE-P1-POLICY-001
  - SAMPLE-P1-POLICY-002
  - SAMPLE-P1-POLICY-003

mature_capabilities:
  - ci_execution
  - artifact_output
  - regression_writeback
  - writeback_review
  - compat_matrix_audit_absorption
  - Header (CLOSED)
  - Cookie (CLOSED)
  - Cache (CLOSED)
  - ErrorMapping (CI_VERIFIED_CLOSED)
  - PolicyVerification (CI_VERIFIED_CLOSED)
  - JSDomExecution (CLOSED)
  - LoginBootstrap (CLOSED)
  - CookieIsolation (CLOSED)

uncovered_capabilities: []

out_of_scope_capabilities:
  - AntiBot (ROI NEGATIVE)
  - JSNetwork (ROI NEGATIVE)

ios_gate:
  allowed: conditional
  decision: CONDITIONAL_ALLOW
  review_doc: docs/IOS_PHASE_GATE_REVIEW.md
  remediation_doc: docs/ios_gate_remediation_result.yml
  conditions:
    - condition: "Track D M1 complete"
      status: COMPLETE
    - condition: "Minimal M2 tooling subset complete (AdapterHarness + TraceInspector)"
      status: COMPLETE  # AdapterHarness CI_VERIFIED, TraceInspector CI_VERIFIED (run 24303727706)
    - condition: "Shell smoke validation complete"
      status: PASS  # executionVerified=true on GitHub Actions runs 24306965324 / 24307509812 / 24345092018
    - condition: "Architecture review pass"
      status: PASS  # M-iOS-1 remediation complete: 0 illegal imports in CoreIntegration/Features
  prerequisites_for_execution:
    - "CONDITION-1: Fix dependency boundary leaks — COMPLETE (M-iOS-1)"
    - "CONDITION-2: Establish iOS Shell CI build — COMPLETE (ios-shell-ci workflow added)"
    - "CONDITION-3: Execute shell smoke validation — PASS (remote validation green on macOS-14)"
  superseded_conditions: "Track D M1–M3 complete (旧条件，已校准为最小 M2 subset)"
  ios_shell_current_state: "SwiftUI views + formal ShellAssembly + ReaderFlowFeatureView + ReadingFlowCoordinator + DefaultSearchService/TOCService/ContentService exist in iOS/. boundary gate script + ios-shell-ci workflow + shell smoke tests are present. ReaderFlowFunctionalValidationTests now verify sample_004/sample_005 fixture-backed import -> search -> toc -> content plus a controlled content 404 path. Remote validation is executionVerified=true and currently green on run 24345092018."

recent_completed_action: "M-IOS-7 (Reader Flow Functional Validation) PASS: GitHub Actions run 24345092018 kept boundary gate, isolated compile, shell smoke validation, and reader functional validation green after exercising sample_004/sample_005 plus a controlled content 404 path."
next_best_task: "M-IOS-8: Reader Flow Failure-State Hardening"
freeze_gate_status: "READY_TO_FREEZE"
```

## 首版范围与边界

### 首版必须完成
- 统一 Core 基础模型 ✅
- BookSource 导入 ✅
- 搜索 / 目录 / 正文主链路 ✅
- 非 JS 主路径 ✅
- Header / 基础 Cookie / 缓存 / 错误定位 ✅
- 最小调试能力 ✅ (smoke runner + regression scripts)

### 当前已成熟能力
- CI 执行
- artifact 产出
- regression 回写
- writeback 审核
- compat_matrix 审计吸收
- Header (CLOSED)
- Cookie (CLOSED, 含 scoped isolation)
- Cache (CLOSED, 含 SimpleCacheRepository + MinimalCacheHTTPClient + InMemoryResponseCache)
- Error mapping (CI_VERIFIED_CLOSED, 14/14 ErrorMappingTests passed)
- PolicyVerification (CI_VERIFIED_CLOSED, 9/9 PolicyVerificationTests passed)
- JSDomExecution (CLOSED, JSRuntime + JSRuntimeDOMBridge)
- LoginBootstrap (CLOSED, 3-step bootstrap + marker verification)
- CookieIsolation (CLOSED, scoped BasicCookieJar)

### 当前未覆盖能力
- 无（所有能力已关闭或已裁决 OUT_OF_SCOPE）

### 当前 OUT_OF_SCOPE
- AntiBot (ROI NEGATIVE — 需 WKWebView，与沙箱模型不兼容)
- JSNetwork (ROI NEGATIVE — 开启 fetch/XHR 破坏 networkLockdown 安全保证)

### 当前明确不做
- 直接移植 Android 实现
- 完整历史边缘规则兼容
- 复杂在线调试服务复刻
- 内置内容平台
- 云同步、账号、社区优先开发
- 未通过 phase gate 审批前进入 iOS 壳层正式开发

## 禁止事项

- 禁止复制、翻译、改写 Legado Android 源码或其实现细节。
- 禁止引入首版范围外功能并伪装为"顺手优化"。
- 禁止在未绑定样本的情况下提交兼容性改动。
- 禁止跳过 metadata、expected、matrix 中任一项。
- 禁止修改 A/B/C/D 兼容等级定义。
- 禁止新增 failure taxonomy 而不更新对应配置与回归脚本。
- 禁止在 `ios_gate.allowed = false` 时推进 iOS 壳层实现、UI 接线或 iOS 优先叙事。
- 仅 `iOS/Shell/**` 可 import `ReaderCoreNetwork`、`ReaderCoreParser`、`ReaderCoreCache`、`ReaderCoreExecution`。
- 新增壳层代码不得绕过 `ShellAssembly` 直接装配 Core internal modules。
- iOS 边界检查入口固定为 `scripts/check_ios_boundary.sh`，CI workflow 固定为 `.github/workflows/ios-shell-ci.yml`。
- M-iOS-2 与 M-iOS-3 必须拆分书写：`implementation_complete` 只表示 gate 已建设；`execution_verified` 只表示远端真实执行已取证，二者不得混写成 `PARTIAL_PASS`。
- interim shell validation 只验证 host-compilable shell composition root，不得扩大到整个 iOS app host compile。
- `iOS/Features/**` 与其他 iOS-only UI 源文件不得纳入 macOS host compile gate。
- phase status、validation result、execution verified 必须分开写，禁止再用单一 PASS/FAIL 混写三层语义。
- validation glue 必须与 frozen dependency graph / frozen initializer signatures 对齐，不得编造 wrapper 或 convenience API。
- 若 `executionVerified = false`，不得写 `validationResult = PASS`。
- Reader Feature 开发必须保持 `ios-shell-ci` green baseline。
- 正式 Reader Feature 接线必须通过 `iOS/Shell/ShellAssembly.swift`，不得绕过装配层直连 Core internal modules。

## Clean-Room 原则

- 实现依据仅来自公开协议、输入输出行为、项目样本与本仓库规范。
- 任何实现描述必须可追溯到样本、规范或本仓库文档，不可追溯到 Legado Android 源码。
- 本仓库所有智能体输出都必须显式说明 clean-room 结论，避免外部 GPL 代码搬运风险。
- 若发现污染风险，必须立即停止合并并回退相关改动。

## 样本驱动原则

- 每个兼容性需求必须先落地样本，再做实现。
- 每个样本必须具备 metadata，且可回归样本必须具备 expected 或 degradeExpectation。
- 每个改动必须更新或复用以下资产：
  - `samples/metadata`
  - `samples/expected`
  - `samples/matrix/compat_matrix.yml`
  - `samples/matrix/failure_taxonomy.yml`
- 回归摘要必须包含样本覆盖范围、失败类型变化、兼容等级变化。

## 自动状态更新机制

以下规则适用于任何"开发步骤完成后"的状态同步：

### 触发动作

每完成一次以下动作，必须立即同步更新状态文件：
- regression 正式回写
- writeback 完成
- compat_matrix 审计确认
- 新样本闭环完成

### 必须同步更新的文件

- `docs/PROJECT_STATE_SNAPSHOT.yaml`
- `docs/AI_HANDOFF/PROJECT_STATUS.md`
- `docs/AI_HANDOFF/OPEN_TASKS.md`

### 必须写入的字段

- 当前已闭环样本
- 当前阶段
- 当前主线
- 当前未覆盖能力
- 下一步唯一最优任务
- 最近一次完成的关键动作
- 当前是否允许进入 iOS 阶段与判断原因

### 一致性要求

- 不允许遗漏已闭环样本。
- 不允许保留已完成任务在 `OPEN_TASKS.md`。
- 不允许出现历史状态与当前状态冲突。
- 三份文件必须保持同一事实基线、同一阶段、同一下一步任务。
- 若本次变更不涉及样本或兼容矩阵，也必须检查三份文件是否仍与当前事实一致。

## PR 门禁

所有 PR 合并前必须满足：

1. 模板字段完整：关联样本、改动范围、修复前失败类型、修复后预期、回归摘要、风险、回退方案。
2. 样本绑定完整：新增或变更兼容行为必须有样本与 expected。
3. 矩阵一致性：compat_matrix 与 failure_taxonomy 的更新结论明确。
4. Clean-room 检查通过：无 GPL 搬运风险。
5. Reviewer 给出可合并结论，且无未处理 P0 问题。

## 测试门禁

所有 PR 合并前必须通过以下检查：

1. 单元测试通过。
2. 样本回归通过（至少覆盖受影响样本集合）。
3. 兼容矩阵校验脚本通过。
4. 失败类型校验脚本通过。
5. iOS 构建检查通过（仅在 `ios_gate.allowed = true` 且实际涉及 iOS 代码时必需）。

若任一门禁失败，PR 不得合并。

## Agent 协作约束

- Planner 只负责拆解方案，不写业务实现代码。
- Builder 只按已批准方案实现，不擅自扩 scope。
- Reviewer 只做审查，不直接实现功能。
- Regression 只维护样本与回归资产，不实现业务逻辑。
- 所有角色都必须先吸收 `docs/PROJECT_STATE_SNAPSHOT.yaml` 与 `docs/AI_HANDOFF/*`，禁止依赖对话上下文代替仓库状态。

## 生效范围

- 本文件适用于本仓库下所有人类与智能体协作任务。
- 子智能体配置必须显式继承本文件的"强制前置主提示词"。
- 如子智能体配置与本文件冲突，以本文件为准。
