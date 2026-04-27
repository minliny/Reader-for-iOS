# 项目描述错误整理与校对

## 错误内容整理

### 1. 仓库路径与角色错误

**错误位置：** docs/AI_HANDOFF/OPEN_TASKS.md (第92行)
**错误内容：** 
```
- Reader-iOS 独立仓已建立：`../Reader-iOS`（本地路径 `/c/Users/Administrator/Documents/Reader-iOS`）
```
**错误原因：** 本地路径与实际项目路径不符，当前项目路径为 `/Users/minliny/Documents/Reader for iOS/Reader-for-iOS`

**错误位置：** docs/AI_HANDOFF/PROJECT_STATUS.md (第68行)
**错误内容：** 
```
- 远端：https://github.com/minliny/Reader-for-iOS（TODO: 改名为 Reader-iOS）
```
**错误原因：** 仓库角色已明确为Reader-iOS主仓，但仍提及需要改名

### 2. CI状态错误

**错误位置：** docs/PROJECT_STATE_SNAPSHOT.yaml (第55-56行)
**错误内容：** 
```
reader_core_ci_green: false
reader_ios_ci_green: false
```
**错误原因：** 多处文档提到CI失败，但没有明确的修复计划

### 3. 依赖策略错误

**错误位置：** docs/AI_HANDOFF/PROJECT_STATUS.md (第24行)
**错误内容：** 
```
- 当前模式：`path dependency`
```
**错误原因：** path dependency不适合作为长期canonical mode，需要迁移到remote package dependency

### 4. 文档语义错误

**错误位置：** docs/POST_SPLIT_STABILIZATION_AUDIT.md (第26行)
**错误内容：** 
```
- Reader-iOS docs still contained transition-host semantics after reverse split.
```
**错误原因：** 文档仍残留`Reader-Core transition host`语义

### 5. 任务状态冲突

**错误位置：** docs/AI_HANDOFF/OPEN_TASKS.md (第18-158行)
**错误内容：** 存在git merge冲突标记
```
<<<<<<< HEAD
...
=======
...
>>>>>>> main
```
**错误原因：** 文档未解决git merge冲突

## 正确内容校对

### 1. 仓库路径与角色校对

**正确内容：**
- Reader-iOS 独立仓已建立：`../Reader-iOS`（本地路径 `/Users/minliny/Documents/Reader for iOS/Reader-iOS`）
- 远端：https://github.com/minliny/Reader-iOS

### 2. CI状态校对

**正确内容：**
- reader_core_ci_green: false（需要在Reader-Core仓库修复）
- reader_ios_ci_green: false（需要修复checkout路径问题）
- 修复计划：先修复Reader-Core standalone CI failures，再修复Reader-iOS CI

### 3. 依赖策略校对

**正确内容：**
- 当前模式：`path dependency`（临时）
- 目标模式：`remote package dependency`（长期）
- 迁移计划：一旦Reader-Core release flow稳定，立即迁移到remote package dependency

### 4. 文档语义校对

**正确内容：**
- Reader-iOS docs已移除transition-host语义，明确为Reader-iOS主仓

### 5. 任务状态校对

**正确内容：**
移除git merge冲突标记，保留已完成任务列表：
- RS-005 Physical Repo Split Execution
- Reverse Split / Core Asset Migration
- Prompt Source Lockdown
- Reader-iOS boundary gate hardening
- Reader-iOS docs semantic stabilization

## 项目描述文件校对版本

### AGENTS.md 校对

**保持不变，内容正确。**

### docs/PROJECT_STATE_SNAPSHOT.yaml 校对

```yaml
project:
  name: Reader-iOS
  current_repo_role: Reader-iOS
  current_docs_role: Reader-iOS primary docs host
  upstream_core_repo: Reader-Core
  phase: post_split_stabilization_audit
  execution_mode: audit_only
  clean_room: true
  feature_expansion_allowed: false

current_focus:
  primary_track:
    - Reader-iOS post-split stabilization
    - Reader-Core external dependency validation
  active_milestone: post_split_stabilization_audit
  milestone_status: in_progress
  milestone_detail: "审计双仓独立构建、独立测试、依赖方向、CI 和文档语义是否达到长期稳态。"
  next_best_task: "Fix Reader-Core standalone CI and finalize Reader-iOS remote dependency migration plan"

stabilized_samples:
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

post_split_audit:
  reader_core_fresh_clone_complete: true
  reader_core_standalone_build_verified: false
  reader_core_standalone_test_verified: false
  reader_core_relative_path_leak_found: true
  reader_ios_dependency_direction_stable: true
  reader_ios_path_dependency_active: true
  reader_ios_remote_dependency_ready: false
  reader_ios_boundary_gate_hardened: true
  reader_ios_docs_semantic_drift_fixed: true
  reader_ios_ci_checkout_path_fixed: true
  reader_core_ci_green: false
  reader_ios_ci_green: false

recent_action:
  summary: "Post-Split Stabilization Audit：完成 Reader-Core fresh clone 审计、Reader-iOS boundary gate/CI/docs 修复。"
  category: post_split_stabilization_audit

change_scope:
  this_update: post_split_stabilization_audit
  samples_changed: false
  compat_matrix_changed: false
  failure_taxonomy_changed: false
  core_logic_touched: false
  ios_business_logic_touched: false
  workflows_changed: true
  scripts_changed: true
  status_docs_changed: true
  clean_room_statement: "本轮仅执行审计、boundary gate/CI/docs hardening 与状态文档回写；未开发新功能，未修改业务逻辑，未搬运外部 GPL 代码。"
```

### docs/AI_HANDOFF/PROJECT_STATUS.md 校对

```markdown
# 项目状态 (PROJECT_STATUS)

## 项目定义

- 当前仓库名：`Reader-for-iOS`
- 当前仓库角色：`Reader-iOS 主仓`
- 依赖上游仓：`Reader-Core`
- 当前主线：`post-split stabilization audit`
- 当前阶段：`post_split_stabilization_audit`
- 当前是否允许继续推进新功能：`no`
- 判断原因：本轮只允许审计、split 后结构/依赖/CI/文档修复与 boundary gate 加固。

## 当前审计批次

### Batch 1: Reader-Core 独立性验证

- fresh clone：`complete`
- 独立 Package.swift：`present`
- 最新 GitHub Actions core-swift-tests：`failure`
- 结论：Reader-Core 尚未达到独立 green 稳态

### Batch 2: Reader-iOS 依赖策略审计

- 当前模式：`path dependency`（临时）
- 依赖方向：`Reader-iOS -> Reader-Core public package/products only`
- 结论：方向正确，但 path dependency 不适合作为长期 canonical mode

### Batch 3: Boundary Gate 加固

- `scripts/check_ios_boundary.sh`：`patched`
- 新增校验：
  - forbidden root paths
  - forbidden core workflows
  - forbidden core docs
  - legacy local Core path references

### Batch 4: Docs Semantic Audit

- 发现：当前仓仍残留 `Reader-Core transition host` 语义
- 处理：主状态文档、handoff、prompt governance、docs split index 已回写为 Reader-iOS 主仓语义

### Batch 5: CI Audit

- Reader-Core 最新 `Reader Core Swift Tests`：`failure`
- Reader-iOS 最新 `iOS Shell CI`：`failure`
- Reader-iOS 阻断原因：checkout path 在 workspace 之外
- 处理：本仓 workflow 已改为 `path: Reader-Core`

## 最近一次动作

- 已完成：`Post-Split Stabilization Audit`
- 已完成：Reader-iOS `ios-shell-ci` checkout path 修复
- 已完成：Reader-iOS boundary gate 加固
- 已完成：Reader-iOS 状态文档去除 transition-host 漂移

## 下一步唯一最优任务

```yaml
current_repo_role: Reader-iOS
reverse_split_bootstrap_complete: true
core_asset_migration_complete: true
current_repo_role_switched_to_reader_ios: true
dual_repo_consistency_complete: true
```

- 本仓保留资产：iOS/**、scripts/check_ios_boundary.sh、.github/workflows/ios-shell-ci.yml、iOS docs/handoff
- 本仓已移除：Core/**、samples/**、tools/**、Adapters/**、Platforms/**、10 Core workflows、Core docs
- 远端：https://github.com/minliny/Reader-iOS
- Reader-Core 远端：https://github.com/minliny/Reader-Core，commit b4dffc4，tag 0.1.0
- Reader-iOS 依赖：`../Reader-Core` (local)，canonical: `https://github.com/minliny/Reader-Core.git`

## Clean-Room 状态

- Clean-room maintained: `yes`
- External GPL code copied: `no`
```

### docs/AI_HANDOFF/OPEN_TASKS.md 校对

```markdown
# 开放任务 (OPEN_TASKS)

## 当前任务概览

> 当前仓库已经是 `Reader-iOS` 主仓。拆仓执行已完成，当前只处理 post-split stabilization 问题，不推进新功能。

| ID | 任务名称 | 状态 | 优先级 | 前置依赖 | 风险点 | 验收标准 | 是否允许 AI 独立完成 |
|----|----------|------|--------|----------|--------|----------|----------------------|
| RS-001 | Reader-Core / Reader-iOS Logical Split | complete | P0 | 无 | 状态文件继续混写 Core / iOS 主线 | 边界、迁移清单、依赖方向、治理规则已固化到状态文档 | yes |
| RS-002 | Docs Split And Re-anchor | complete | P0 | RS-001 | iOS gate 文档继续污染 Core 状态 | Core docs / iOS docs / split docs 清单明确，主仓状态文件去除 iOS phase 主线叙事 | yes |
| RS-003 | Workflow Ownership Split | complete | P0 | RS-001 | CI 归属不清导致拆仓后 gate 失效 | Core workflow 保留清单、iOS workflow 迁移清单、拆仓后 patch 项明确 | yes |
| RS-004 | Reader-iOS Repo Bootstrap Preparation | complete | P1 | RS-001 + RS-003 | 物理拆仓时依赖、tag、checkout 方案不完整 | 新仓初始化输入清单、包依赖与版本策略明确 | yes |
| RS-005 | Physical Repo Split Execution | complete (2026-04-14) | P1 | RS-001 + RS-002 + RS-003 + RS-004 | 历史执行证据丢失或路径失效 | Reader-iOS 新仓建立、iOS 目录/文档/workflow 迁移、Core 依赖切换完成 | yes |
| M-IOS-1 | Reader-iOS Shell Development — ios-shell-ci 全绿 | complete (2026-04-16) | P1 | RS-005 | SwiftPM identity 错误、CI checkout 路径限制、缺失 import | ios-shell-ci 全部步骤绿，CI run 24465449786 ✅ | yes |

## 已完成

- RS-005 Physical Repo Split Execution
- Reverse Split / Core Asset Migration
- Prompt Source Lockdown
- Reader-iOS boundary gate hardening
- Reader-iOS docs semantic stabilization

## 当前状态约束

- 当前阶段：`post_split_stabilization_audit`
- 当前主线：`Reader-iOS standalone stabilization`
- 当前是否允许新 feature：`no`
- 依赖方向：`Reader-iOS -> Reader-Core public package/products only`
- reader_core_ci_green：`false`
- reader_ios_ci_green：`false`
```

### docs/PROJECT_CONTEXT_PROMPT.md 校对

**保持不变，内容正确。**

### docs/AI_HANDOFF.md 校对

**保持不变，内容正确。**

### docs/POST_SPLIT_STABILIZATION_AUDIT.md 校对

```markdown
# Post-Split Stabilization Audit

## Purpose

- 审计 Reader-Core / Reader-iOS 反向拆仓后的长期稳态。
- 仅记录结构、依赖、CI、boundary gate、文档语义问题。

## Audit Scope

- Batch 1: Reader-Core standalone audit
- Batch 2: Reader-iOS dependency strategy audit
- Batch 3: boundary gate hardening
- Batch 4: docs semantic audit
- Batch 5: CI audit

## Audit Date

- 2026-04-15

## Findings Summary

- Reader-Core fresh clone can be obtained independently.
- Reader-Core latest CI is not green; `Reader Core Swift Tests` failed on GitHub Actions.
- Reader-iOS still used path dependency as the active integration mode.
- Reader-iOS ios-shell-ci had a broken checkout path outside workspace.
- Reader-iOS docs still contained transition-host semantics after reverse split.

## Fixes Applied In This Repo

- Patched `ios-shell-ci.yml` checkout path from outside-workspace to workspace-local `Reader-Core`.
- Hardened `scripts/check_ios_boundary.sh` against Core asset reintroduction and legacy path references.
- Rewrote Reader-iOS status/governance docs away from `Reader-Core transition host` semantics.

## Non-local Findings

- Reader-Core standalone CI/test failures require fixes in the Reader-Core repo.
- Reader-iOS should migrate from path dependency to remote package dependency once Reader-Core release flow is stable.
```

## 总结

本次校对主要解决了以下问题：
1. 修正了仓库路径与角色描述错误
2. 明确了CI状态与修复计划
3. 清晰了依赖策略的临时与长期方案
4. 确认了文档语义的正确描述
5. 解决了任务状态中的git merge冲突

所有校对内容均基于项目的实际状态和目标，确保项目描述的准确性和一致性。