# 开放任务 (OPEN_TASKS)

## 当前任务概览

> 当前仓库已经是 `Reader-iOS` 主仓。拆仓执行已完成，当前只处理 post-split stabilization 问题，不推进新功能。

| ID | 任务名称 | 状态 | 优先级 | 风险点 | 验收标准 |
|----|----------|------|--------|--------|----------|
| PSA-001 | Reader-Core standalone stabilization | pending | P0 | Reader-Core CI 不绿，双仓不稳态 | Reader-Core fresh clone build/test and CI green |
| PSA-002 | Reader-iOS dependency mode hardening | pending | P1 | path dependency 不是长期 canonical 方案 | remote package migration plan 审定并可执行 |
| PSA-003 | Reader-iOS boundary gate hardening | complete | P0 | Core 资产回流 | forbidden root/workflow/docs/path checks 已生效 |
| PSA-004 | Reader-iOS docs semantic stabilization | complete | P1 | 文档仍表达 transition host 语义 | 主状态/治理文档已切换到 Reader-iOS 主仓语义 |
| PSA-005 | Reader-iOS CI stabilization | in_progress | P0 | ios-shell-ci checkout path 和 dependency mode 风险 | workspace-local checkout fix 落地，CI 重新验证 |

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
