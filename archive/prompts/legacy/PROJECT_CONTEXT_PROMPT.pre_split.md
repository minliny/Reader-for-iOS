你是本项目的 AI 开发代理。

以下内容是仓库内统一项目上下文，任何模型在执行任务前必须先吸收，不允许依赖对话历史补足关键信息。

## 1. 当前项目定义

```yaml
project:
  name: Reader-for-iOS
  strategy: Reader-Core first
  shell_policy: iOS later
  mainline: Reader-Core compatibility kernel development
  phase: post_freeze_planning
  execution_mode: recalibrated_phase2
  active_strategy: minimal_tooling_then_ios
  clean_room: true
  ios_allowed_now: false
```

解释：
- 当前主线不是 iOS 壳层开发，而是 Reader-Core 兼容内核开发。
- Core 兼容内核已完成 core_contract_stabilization 并通过 freeze gate CI 验证。
- 当前阶段为 post_freeze_planning，执行模式为 recalibrated_phase2。
- 校准策略：先完成最小高 ROI tooling subset，再尽早进行 iOS gate review。
- iOS 相关工作需通过 gate review 后才允许进入。
- 所有实现必须遵守 clean-room，禁止引用或搬运 Legado Android 实现。

## 2. 当前事实基线

### 已闭环样本

```yaml
closed_samples:
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
```

### 已成熟能力

```yaml
mature_capabilities:
  - CI 执行
  - artifact 产出
  - regression 回写
  - writeback 审核
  - compat_matrix 审计吸收
  - Header (CLOSED)
  - Cookie (CLOSED, 含 scoped isolation)
  - Cache (CLOSED)
  - ErrorMapping (CI_VERIFIED_CLOSED, 14/14 tests passed)
  - PolicyVerification (CI_VERIFIED_CLOSED, 9/9 tests passed)
  - JSDomExecution (CLOSED)
  - LoginBootstrap (CLOSED)
  - CookieIsolation (CLOSED)
```

### 当前未覆盖能力

```yaml
uncovered_capabilities: []
# 所有能力已关闭或已裁决 OUT_OF_SCOPE
```

### OUT_OF_SCOPE

```yaml
out_of_scope:
  - AntiBot (ROI NEGATIVE — 需 WKWebView，与沙箱模型不兼容)
  - JSNetwork (ROI NEGATIVE — 开启 fetch/XHR 破坏 networkLockdown 安全保证)
```

### 当前阶段与主线

```yaml
state:
  phase: post_freeze_planning
  execution_mode: recalibrated_phase2
  active_strategy: minimal_tooling_then_ios
  active_tracks:
    - Reader-Core (frozen baseline)
    - Minimal Tooling Hardening → Early iOS Gate Review
  active_milestone: m2_minimal
  milestone_status: pending
  next_best_task: "Execute OT-006 (AdapterHarness) + OT-007 (TraceInspector)"
  ios_gate:
    allowed: false
    conditions:
      - "Track D M1 complete ✅"
      - "Minimal M2 tooling subset complete (AdapterHarness + TraceInspector)"
      - "Shell smoke validation complete"
      - "Architecture review pass"
    superseded_conditions: "Track D M1–M3 complete (旧条件，已校准)"
```

## 3. 当前任务边界

### 当前允许推进
- P0: AdapterIntegrationTestHarness (OT-006)
- P0: Request/Response Trace Inspector (OT-007)
- P1 Optional: Fixture Replay / Selector Tester (OT-008, 二选一)
- P0: iOS Phase Gate Review (OT-009, 依赖 OT-006+OT-007)
- 状态文件、handoff 文件、agent 提示词的同步维护

### 当前不允许推进
- iOS 壳层正式开发（需 gate review 通过）
- 修改 Core baseline
- 扩展 capability
- 未绑定样本的兼容性修改
- 修改 A/B/C/D 兼容等级定义
- 新增 failure taxonomy 而不更新配置
- 引入外部 GPL 代码或引用 Legado Android 实现

## 4. Tooling 优先级 (Recalibrated)

```yaml
tooling_priority:
  P0_immediate:
    - AdapterIntegrationTestHarness (OT-006) — 阻塞 iOS gate
    - Request/Response Trace Inspector (OT-007) — 阻塞 iOS gate

  P1_optional_before_ios:
    - Fixture Replay OR Selector Tester (OT-008, 二选一) — 不阻塞 gate

  deferred_until_post_ios:
    - Rule Debugger
    - Regression Dashboard
    - JS Runtime Inspector
    - Login Bootstrap Debugger
    - Fixture Snapshot Recorder
```

## 5. 自动状态更新机制

任何模型在完成一次开发步骤后，都必须把仓库状态同步到以下三个文件，确保后续模型无需上下文即可理解当前状态：

```yaml
required_sync_files:
  - docs/PROJECT_STATE_SNAPSHOT.yaml
  - docs/AI_HANDOFF/PROJECT_STATUS.md
  - docs/AI_HANDOFF/OPEN_TASKS.md
```

### 触发条件
- regression 正式回写
- writeback 完成
- compat_matrix 审计确认
- 新样本闭环完成
- 策略校准

### 必须同步的内容
- 当前已闭环样本
- 当前阶段
- 当前主线
- 当前未覆盖能力
- 下一步唯一最优任务
- 最近一次完成的关键动作
- 当前是否允许进入 iOS 阶段与判断原因

### 同步规则
- 不允许遗漏已闭环样本。
- 不允许把已完成任务继续保留在 `OPEN_TASKS.md`。
- 不允许三份文件之间出现阶段、主线、下一步任务或 iOS 判断不一致。
- 若一次开发步骤仅改治理文档，也必须同步检查三份文件仍与当前真实状态一致。

## 6. 当前交接阅读顺序

模型进入仓库后建议按以下顺序建立上下文：

1. `AGENTS.md`
2. `docs/PROJECT_CONTEXT_PROMPT.md` (本文件)
3. `docs/PROJECT_STATE_SNAPSHOT.yaml`
4. `docs/AI_HANDOFF/PROJECT_STATUS.md`
5. `docs/AI_HANDOFF/OPEN_TASKS.md`
6. `docs/ROADMAP_PHASE2.md`

## 7. Clean-Room 声明

- 本项目当前状态说明仅来自仓库内部事实、样本、回归结果与治理文件。
- 不引用 Legado Android 实现细节。
- 无外部 GPL 代码搬运。
