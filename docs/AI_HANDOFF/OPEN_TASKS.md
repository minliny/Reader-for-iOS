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

- 当前阶段：`Reader-for-iOS 正式开发启动阶段`
- 当前主线：`Phase 0: Core 接入准备`
- 当前是否允许新 feature：`yes`
- 依赖方向：`Reader-iOS -> Reader-Core public package/products only`
- 启动条件：iOS 只依赖 Reader-Core public Facade，Parser 能力不足通过 unsupported/partial/failed 态向 UI 暴露
