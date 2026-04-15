# 项目状态 (PROJECT_STATUS)

## 项目定义

- 当前仓库名：`Reader-for-iOS`
- 当前仓库过渡角色：`Reader-Core transition host`
- 目标主仓身份：`Reader-Core`
- 目标独立仓身份：`Reader-iOS`
- 当前主线：`repo split governance / reader-ios bootstrap preparation`
- 当前阶段：`repo_split_execution_phase_a`
- 当前是否允许继续推进新的 iOS feature：`no`
- 判断原因：本轮只做 Reader-iOS bootstrap preparation、依赖接入设计、初始化文档与迁移前置清单；不新增 iOS feature scope。

## 为什么现在必须拆仓

- Core compatibility kernel 已完成核心冻结与 freeze gate 验证，已经具备独立仓长期演进条件。
- iOS shell 已累积独立 phase、独立 workflow、独立远端执行证据，继续放在同一主仓会持续污染 Core 主线语义。
- 当前状态文件同时维护 Core closure 与 iOS phase/gate，导致“仓库职责”“CI 归属”“下一步任务”长期漂移。
- Reader-iOS 不应反向拥有 Core 实现控制权；它应只消费 Reader-Core 暴露的 package/product。

## 当前真实边界

### Reader-Core

- 职责：兼容内核、sample/fixture/expected/matrix、regression、policy、parser、network、cache、cookie、login bootstrap、tooling/debug/fixture CLI。
- 当前天然归属路径：
  - `Core/**`
  - `samples/**`
  - `tools/**`
  - `scripts/**` 中 Core 通用脚本
  - `docs/API_SNAPSHOT/**`
  - `docs/FIXTURE_INFRA_SPEC.md`
  - `docs/TOOLING_BACKLOG.md`
  - `docs/decision_engine/**`
  - `docs/process/**`
  - `docs/architecture/**`
- 持续 gate：
  - `core-swift-tests.yml`
  - `fixture-toc-regression-macos.yml`
  - `policy-regression-macos.yml`
  - `sample001-nonjs-smoke.yml`
  - `sample-cookie-001-isolation.yml`
  - `sample-cookie-002-isolation.yml`
  - `sample-login-001-isolation.yml`
  - `sample-login-002-isolation.yml`
  - `sample-login-003-isolation.yml`
  - `auto-sample-extractor.yml`（后续需去掉历史分支绑定）

### Reader-iOS

- 职责：iOS app shell、composition root、core integration glue、reader UX / interaction / navigation / session / presentation 验证。
- 当前天然归属路径：
  - `iOS/**`
  - `docs/IOS_PHASE_GATE_REVIEW.md`
  - `docs/ios_gate_remediation_result.yml`
  - `docs/ios_shell_ci_gate.yml`
  - `docs/ios_architecture_remediation_plan.yml`
  - `docs/ios_boundary_violations.yml`
  - `.github/workflows/ios-shell-ci.yml`
  - `scripts/check_ios_boundary.sh`
- 持续 gate：
  - `ios-shell-ci`
  - shell smoke
  - functional validation
  - hardening validation
  - UX / interaction / session / navigation / presentation validation

## 当前仓库后续如何推进

### Phase A: Logical Split

- 在当前仓库内先完成状态语义切换：主仓视角改写为 Reader-Core。
- 固化目录归属、文档迁移清单、workflow 拆分清单、依赖与版本策略。
- 保留全部 iOS 历史执行证据，但从“主仓当前 phase”降级为“待迁移 Reader-iOS 资产”。

### RS-004: Reader-iOS Bootstrap Preparation

- 当前目标：输出 Reader-iOS 独立仓初始化蓝图、依赖接入方案、bootstrap 文档与迁移 checklist。
- 当前不做：physical split、Reader-iOS 新仓真实创建、iOS feature 扩张。
- bootstrap 完成条件：
  - Reader-iOS repo skeleton 明确
  - Reader-Core public products 接入方案明确
  - 首批代码/docs/workflow/script 迁移清单明确
  - RS-005 可直接按 checklist 执行

### Phase B: Physical Split

- 新建 `Reader-iOS` 仓库。
- 迁移 `iOS/**`、iOS docs、`ios-shell-ci` workflow、边界脚本。
- Reader-iOS 改为通过 Swift Package 依赖 Reader-Core public products。
- Reader-Core 主仓仅保留 Core/sample/regression/tooling/docs mainline。

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
- Cookie (CLOSED)
- Cache (CLOSED)
- ErrorMapping (CI_VERIFIED_CLOSED)
- PolicyVerification (CI_VERIFIED_CLOSED)
- JSDomExecution (CLOSED)
- LoginBootstrap (CLOSED)
- CookieIsolation (CLOSED)

### 当前未覆盖能力

- 无

### 当前 OUT_OF_SCOPE

- AntiBot (ROI NEGATIVE — 需 WKWebView，与沙箱模型不兼容)
- JSNetwork (ROI NEGATIVE — 开启 fetch/XHR 破坏 networkLockdown 安全保证)

## 最近一次动作

- 已完成：Reader-Core / Reader-iOS split planning，并回写状态文件与治理规则。
- 已保留：全部 iOS gate / run evidence，历史指针保留于本仓，主线归属已迁移至 Reader-iOS。
- 已完成：Prompt Governance Cleanup，active prompt set 已切换到 split-era，legacy prompt 已归档到 `archive/prompts/legacy/`。
- 已完成：RS-002 Docs Split。
- 已完成：RS-003 Workflow Split。
- 已完成：RS-004 Reader-iOS Bootstrap Preparation。
- 已完成：RS-005 Physical Repo Split Execution（2026-04-14）。
  - Reader-iOS 独立仓已建立：`../Reader-iOS`
  - iOS 代码/docs/workflows/scripts 已迁移
  - iOS/Package.swift 依赖已切换至独立 Core 路径
  - Reader-Core 主仓 iOS 资产保留历史指针

## 当前状态（Core Asset Migration 完成 2026-04-15）

```yaml
current_repo_role: Reader-iOS
reverse_split_bootstrap_complete: true
core_asset_migration_complete: true
current_repo_role_switched_to_reader_ios: true
dual_repo_consistency_complete: true
```

- 本仓保留资产：iOS/**、scripts/check_ios_boundary.sh、.github/workflows/ios-shell-ci.yml、iOS docs/handoff
- 本仓已移除：Core/**、samples/**、tools/**、Adapters/**、Platforms/**、10 Core workflows、Core docs
- 远端：https://github.com/minliny/Reader-for-iOS（TODO: 改名为 Reader-iOS）
- Reader-Core 远端：https://github.com/minliny/Reader-Core，commit b4dffc4，tag 0.1.0
- Reader-iOS 依赖：`../Reader-Core` (local)，canonical: `https://github.com/minliny/Reader-Core.git`

## CI 验证状态（2026-04-15 — 全量绿，burn-down complete）

```yaml
core_stabilization_blocker_burn_down_status: core_stabilization_blocker_burn_down_complete
reader_core_swift_tests_last_run_id: "24455327984"
reader_core_swift_tests_last_conclusion: success
reader_core_swift_tests_run_date: "2026-04-15"
reader_core_swift_tests_failing_count: 0
reader_core_swift_tests_runner: macos-14
cluster_a_js_dom_bridge_tests: CLOSED (7/7 passing)
cluster_b_js_integration_tests: CLOSED (3/3 passing)
cluster_c_login_bootstrap_tests: CLOSED (all passing)
cluster_d_network_policy_tests: CLOSED (all passing)
```

### 本轮修复记录（CORE_JS_DOM_BRIDGE_CONTRACT_COMPLETION）

**根因：** `domPolyfillScript` IIFE 含 `"use strict"`，严格模式下 IIFE 内 `this` 为 `undefined`，
导致 `this.document = {…}` 抛出 TypeError，JSRuntime 触发 fallback 返回原始 HTML，
全部 Cluster A/B 测试均得到未经处理的原始 HTML 输出。

**修复：**
- `JSRuntimeDOMBridge.swift`：将 `this.document = {` 替换为 `globalThis.document = {`
  — commit `243ef12` (Reader-Core main)
- `JSIntegrationTests.swift`：修正 TOC 测试 fixture，`<li>` 元素改为仅含 chapter title
  （原 `Chapter 1|/ch/1` 导致 `-ok` 被追加到 URL 部分而非 title 部分）
  — commit `1d75720` (Reader-Core main)

**Cluster A/B 收敛结果：**

| Run | 失败数 | Cluster A | Cluster B | Groups C+D |
|-----|--------|-----------|-----------|------------|
| 24452819385 (修复前) | 12 | 7 failing | 3 failing | 2 failing |
| 24453337742 (修复 A) | 3 | 0 failing ✅ | 1 failing | 2 failing |
| 24453443546 (修复 B) | 2 | 0 failing ✅ | 0 failing ✅ | 2 failing |

### 修复记录（CORE_LOGIN_COOKIE_BLOCKER_BURN_DOWN — 2026-04-15）

#### Group C 修复：LoginBootstrapService.swift — commit `e803b8d`
`execute()` 在发送 verificationRequest 前，新增对 submit 响应的 failure marker 检查。
submit body 含 "Invalid password." 时立即 abort，不再消耗 verification 槽位，
避免后续 scope 的 mock 响应全部偏移一位。

#### Group D 修复：BasicCookieJar.swift — commit `e803b8d`
`getCookies(for:path:scopeKey:)` 在 scoped lookup 返回空时，fallback 到 `.default` scope，
使通过 `layer.send()`（无 scopeKey）存入的 bootstrap cookie 对后续 `performSearch` 可见。

## M-IOS-1: iOS Shell CI 全绿（2026-04-16）

```yaml
m_ios_1_status: complete
m_ios_1_ci_run_id: "24465449786"
m_ios_1_ci_conclusion: success
m_ios_1_ci_run_date: "2026-04-16"
m_ios_1_branch: claude/lucid-poincare
```

**修复记录（本轮 — M-IOS-1）：**

| Commit | 说明 |
|--------|------|
| `fe67685` | fix(ci+tests): correct Reader-Core path — sibling to iOS/, not to repo root |
| `5e8cd53` | fix(ios): use package identity 'Reader-Core' matching SwiftPM path-based resolution |
| `b4313af` | fix(tests): add missing ReaderShellValidation import to ReaderPresentationValidationTests |

**根因：**
1. CI `actions/checkout@v4` 禁止 workspace 外路径 → 改用 `git clone Reader-Core`（在 workspace 内，与 `iOS/` 同级）
2. SwiftPM 本地 path dependency 以路径最后一段作为 package identity（`Reader-Core`），而非 Package.swift 中的 `name`（`ReaderCore`） → 全量替换为 `package: "Reader-Core"`
3. `ReaderPresentationValidationTests.swift` 缺失 `import ReaderShellValidation` → 添加缺失 import

**验收状态：** ios-shell-ci 全部 8 个测试步骤 ✅ 通过

## 下一步任务

- 将 Reader-for-iOS 仓重命名为 Reader-iOS（GitHub 仓库设置）
- RS-005-FU-01: 发布 Reader-Core 正式 Swift Package tag（已有 0.1.0，可增量 patch）
- RS-005-FU-02: 更新 Reader-iOS Package.swift 切换到 URL-based 依赖

## Clean-Room 状态

- Clean-room maintained: `yes`
- External GPL code copied: `no`
- 本轮仅依据仓库内目录、文档、workflow 与已有执行证据整理边界，不修改 Core frozen contract，不搬运外部实现。

## Prompt Governance 状态

- active prompt set:
  - `AGENTS.md`
  - `docs/PROMPT_GOVERNANCE.md`
  - `docs/PROJECT_CONTEXT_PROMPT.md`
  - `docs/AI_HANDOFF.md`
- legacy prompt archive: `archive/prompts/legacy/`
- pre-split iOS feature prompts: `forbidden in active governance`
