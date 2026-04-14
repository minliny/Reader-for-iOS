你是本项目的 AI 开发代理。

以下内容是当前 split-era 的统一项目上下文。执行任何任务前，必须先经过唯一 active prompt chain，不得继续使用 pre-split prompt 语义。

## 1. 当前项目定义

```yaml
project:
  name: Reader-for-iOS
  current_repo_role: Reader-Core transition host
  current_host_repo_should_converge_to: Reader-Core
  future_independent_repo: Reader-iOS
  phase: repo_split_execution_phase_a
  planning_complete: true
  logical_split_complete: false
  physical_split_complete: false
  clean_room: true
  ios_feature_progression_in_host_repo: paused
```

解释：
- 当前仓库不再以 pre-split 主线口径作为运行中的 active prompt。
- 当前仓库的唯一主线是 split-era 治理与边界收敛。
- iOS 资产仍位于本仓，但归属语义已经变为 `pending migration`。
- Reader-iOS 未来只能依赖 Reader-Core public package/products。

## 2. 当前事实基线

```yaml
reader_core_primary_ownership:
  - Core/**
  - samples/**
  - tools/**
  - docs/API_SNAPSHOT/**
  - docs/FIXTURE_INFRA_SPEC.md
  - docs/TOOLING_BACKLOG.md
  - docs/decision_engine/**
  - docs/process/**
  - docs/architecture/**

ios_assets_pending_migration:
  - iOS/**
  - docs/ios_shell_ci_gate.yml
  - docs/IOS_PHASE_GATE_REVIEW.md
  - docs/ios_gate_remediation_result.yml
  - docs/ios_architecture_remediation_plan.yml
  - docs/ios_boundary_violations.yml
  - .github/workflows/ios-shell-ci.yml
  - scripts/check_ios_boundary.sh
```

## 3. 当前允许与禁止

### 当前允许
- split governance cleanup
- logical split execution
- docs split planning
- workflow split planning
- Reader-iOS bootstrap preparation
- 与 split/bootstrap 直接相关的最小 iOS 改动

### 当前禁止
- 继续执行任何 pre-split iOS feature phase
- 将 iOS gate 文档继续当作主仓长期状态页
- 改动 Core frozen contract
- 未绑定样本的兼容性改动
- 引入外部 GPL 代码或引用 Legado Android 实现

## 4. Prompt Governance Rules

```yaml
prompt_governance:
  active_prompt_chain:
    - AGENTS.md
    - docs/PROMPT_GOVERNANCE.md
    - docs/PROJECT_CONTEXT_PROMPT.md
    - docs/AI_HANDOFF.md
  state_inputs:
    - docs/PROJECT_STATE_SNAPSHOT.yaml
    - docs/AI_HANDOFF/PROJECT_STATUS.md
    - docs/AI_HANDOFF/OPEN_TASKS.md
  forbidden_legacy_prompt_marker_classes:
    - legacy_strategy_marker
    - legacy_shell_sequence_marker
    - legacy_phase_marker
    - legacy_tooling_track_marker
    - legacy_phase_gate_marker
    - legacy_ios_milestone_marker
  archived_prompt_root: archive/prompts/legacy
```

## 5. 当前交接阅读顺序

1. `AGENTS.md`
2. `docs/PROMPT_GOVERNANCE.md`
3. `docs/PROJECT_CONTEXT_PROMPT.md`
4. `docs/AI_HANDOFF.md`

## 6. 当前状态读取顺序

1. `docs/PROJECT_STATE_SNAPSHOT.yaml`
2. `docs/AI_HANDOFF/PROJECT_STATUS.md`
3. `docs/AI_HANDOFF/OPEN_TASKS.md`

## 7. Lockdown Fail Rule

- 若任一 active path 或 state input 重新引用 legacy markers，必须直接判定当前 prompt path 失效并回到唯一 active prompt chain 重建上下文。
- 当当前 active phase 属于 `RS-*` 时，禁止输出 pre-split 主线、旧阶段、旧 iOS feature phase 语义。

## 8. Clean-Room 声明

- 本项目当前状态说明仅来自仓库内部事实、样本、回归结果与治理文件。
- 不引用 Legado Android 实现细节。
- 无外部 GPL 代码搬运。
