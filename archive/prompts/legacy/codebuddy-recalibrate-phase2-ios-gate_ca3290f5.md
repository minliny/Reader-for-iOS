---
name: recalibrate-phase2-ios-gate
overview: 校准项目策略从"Complete full Track D M1–M3 before iOS"纠正为"Minimal Tooling Hardening → Early iOS Gate Review"，更新6个文件的路线/gate/task/state资产
todos:
  - id: update-roadmap
    content: 重写 docs/ROADMAP_PHASE2.md — 策略/gate条件/timeline/tooling排序全面校准
    status: completed
  - id: update-snapshot
    content: 更新 docs/PROJECT_STATE_SNAPSHOT.yaml — phase/gate/focus/milestone/recent_action
    status: completed
    dependencies:
      - update-roadmap
  - id: update-project-status
    content: 更新 docs/AI_HANDOFF/PROJECT_STATUS.md — phase/gate/Track D描述/下一步任务
    status: completed
    dependencies:
      - update-roadmap
  - id: update-open-tasks
    content: 重构 docs/AI_HANDOFF/OPEN_TASKS.md — 关闭OT-005, 新增OT-006~OT-009
    status: completed
    dependencies:
      - update-roadmap
  - id: update-tooling-backlog
    content: 重构 docs/TOOLING_BACKLOG.md — P0/P1 Optional/Deferred Post-iOS重排
    status: completed
    dependencies:
      - update-roadmap
  - id: update-context-prompt
    content: 重写 docs/PROJECT_CONTEXT_PROMPT.md — 全面更新过时内容
    status: completed
    dependencies:
      - update-roadmap
  - id: update-agents
    content: 小幅更新 AGENTS.md — ios_gate.reason + next_best_task
    status: completed
    dependencies:
      - update-snapshot
      - update-project-status
      - update-open-tasks
---

## 用户需求

将项目策略从"Complete full Track D M1–M3 before iOS"校准为"Finish minimal high-ROI tooling subset, then reopen iOS gate early"。

### 核心校准内容

1. **Phase 2 主路线更新**: recommendedTrack = tooling_platform_first, strategy = "Minimal Tooling Hardening → Early iOS Gate Review"
2. **iOS Gate 条件重写**: 旧=M1–M3 complete → 新=M1 complete + minimal M2 subset + Shell smoke validation + architecture review pass
3. **Tooling Backlog 重构**: P0=AdapterIntegrationTestHarness + Request/Response Trace Inspector; P1 Optional=Fixture Replay OR Selector Tester; Deferred Post-iOS=其余5项
4. **OPEN_TASKS 重构**: 关闭旧M1 task, 新增OT-006~OT-009
5. **项目阶段更新**: execution_mode=recalibrated_phase2, active_strategy=minimal_tooling_then_ios

### 约束

- 不修改Core/iOS生产代码
- 不新增capability
- 不扩展tooling范围beyond calibrated roadmap
- 必须清除所有"M1–M3 complete才允许iOS"旧描述残留
- 必须保持三份状态文件一致

## 校准范围

纯文档校准任务，无技术架构变更。所有修改仅涉及规划/状态/gate/task YAML/Markdown文件。

### 需修改的文件清单（6个）

| 文件 | 修改类型 | 关键变更 |
| --- | --- | --- |
| `docs/ROADMAP_PHASE2.md` | 重写 | strategy→minimal_tooling_then_ios, gate条件重写, timeline重写, tooling backlog重新排序 |
| `docs/PROJECT_STATE_SNAPSHOT.yaml` | 更新 | phase, ios_gate, current_focus, active_milestone, recent_action |
| `docs/AI_HANDOFF/PROJECT_STATUS.md` | 更新 | phase, gate条件, 下一步任务, Track D描述 |
| `docs/AI_HANDOFF/OPEN_TASKS.md` | 重构 | 关闭OT-005, 新增OT-006~OT-009, 更新状态约束 |
| `docs/TOOLING_BACKLOG.md` | 重构 | priority_matrix按P0/P1 Optional/Deferred Post-iOS重新编排, milestone_mapping更新 |
| `docs/PROJECT_CONTEXT_PROMPT.md` | 重写 | 全面更新（当前严重过时，仍引用core_contract_stabilization和uncovered_capabilities） |


### 额外需更新的文件（1个）

| 文件 | 修改类型 | 关键变更 |
| --- | --- | --- |
| `AGENTS.md` | 小幅更新 | ios_gate.reason从"M1-M3 complete"改为新gate条件, next_best_task更新 |


### 旧策略残留需清除的位置

- `ROADMAP_PHASE2.md`:275 — "Tooling Track D M1–M3 完成"
- `ROADMAP_PHASE2.md`:303 — "Track D M1–M3 完成后"
- `OPEN_TASKS.md`:109 — "Track D M1–M3 complete"
- `AGENTS.md`:156 — "Track D M1-M3 complete"
- `PROJECT_CONTEXT_PROMPT.md` — 整体过时需重写

### 一致性保障

三份状态文件必须在以下字段保持同一事实基线：

- phase = post_freeze_planning / execution_mode = recalibrated_phase2
- ios_gate.allowed = false, reason = 新gate条件
- active_strategy = minimal_tooling_then_ios
- next_best_task = AdapterIntegrationTestHarness (OT-006)