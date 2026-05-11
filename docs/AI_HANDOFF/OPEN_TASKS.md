# 开放任务 (OPEN_TASKS)

## 当前任务概览

> 当前仓库已经是 `Reader-iOS` 主仓。Phase 1 (CoreBridge + Mock Service + non-JS UI) 已完成，等待 macOS 验证。

| ID | 任务名称 | 状态 | 优先级 | 前置依赖 | 风险点 | 验收标准 | 是否允许 AI 独立完成 |
|----|----------|------|--------|----------|--------|----------|----------------------|
| RS-001 | Reader-Core / Reader-iOS Logical Split | complete | P0 | 无 | 状态文件继续混写 Core / iOS 主线 | 边界、迁移清单、依赖方向、治理规则已固化到状态文档 | yes |
| RS-002 | Docs Split And Re-anchor | complete | P0 | RS-001 | iOS gate 文档继续污染 Core 状态 | Core docs / iOS docs / split docs 清单明确，主仓状态文件去除 iOS phase 主线叙事 | yes |
| RS-003 | Workflow Ownership Split | complete | P0 | RS-001 | CI 归属不清导致拆仓后 gate 失效 | Core workflow 保留清单、iOS workflow 迁移清单、拆仓后 patch 项明确 | yes |
| RS-004 | Reader-iOS Repo Bootstrap Preparation | complete | P1 | RS-001 + RS-003 | 物理拆仓时依赖、tag、checkout 方案不完整 | 新仓初始化输入清单、包依赖与版本策略明确 | yes |
| RS-005 | Physical Repo Split Execution | complete (2026-04-14) | P1 | RS-001 + RS-002 + RS-003 + RS-004 | 历史执行证据丢失或路径失效 | Reader-iOS 新仓建立、iOS 目录/文档/workflow 迁移、Core 依赖切换完成 | yes |
| M-IOS-1 | Reader-iOS Shell Development — ios-shell-ci 全绿 | complete (2026-04-16) | P1 | RS-005 | SwiftPM identity 错误、CI checkout 路径限制、缺失 import | ios-shell-ci 全部步骤绿，CI run 24465449786 ✅ | yes |
| M-IOS-2 | Phase 1B: PlatformAdapters + Real Mode Probe | complete | P1 | M-IOS-1 | SwiftPM name conflict, protocol mismatch, FoundationNetworking Linux | ReaderIOSPlatformAdapters/LinuxValidationTests 编译通过，边界检查通过 | yes |
| M-IOS-3 | Phase 1C: Linux Test Decoupling + Swift 6 Warnings | complete | P1 | M-IOS-2 | SwiftPM test blocker, actor isolation | 所有非 SwiftUI targets 零 warning，boundary check 通过 | yes |
| M-IOS-4 | Phase 1 macOS Verification | pending | P1 | M-IOS-3 | macOS runner 可用性 | swift test 在 macOS-14 runner 上所有非 SwiftUI 测试通过 | yes (需 macOS) |
| M-IOS-5 | Reader-Core Parser Public Facade | pending (upstream) | P1 | M-IOS-4 | Reader-Core 侧决策 | Core 提供高于 Parser internal 的 public pipeline facade | no (Core 侧任务) |

## 已完成

- RS-005 Physical Repo Split Execution
- Reverse Split / Core Asset Migration
- Prompt Source Lockdown
- Reader-iOS boundary gate hardening
- Reader-iOS docs semantic stabilization
- M-IOS-1 iOS Shell Development (ios-shell-ci green)
- M-IOS-2 Phase 1B PlatformAdapters + Real Mode Probe
- M-IOS-3 Phase 1C Linux Decoupling + Swift 6 Warning Cleanup

## 当前状态约束

- 当前阶段：`Reader-for-iOS 正式开发启动阶段`
- 当前主线：`Phase 1: CoreBridge + Mock Service + non-JS UI` — READY_CANDIDATE
- 当前是否允许新 feature：`yes`（在 Phase 1 范围内）
- 依赖方向：`Reader-iOS -> Reader-Core public package/products only`
- Linux 验证方式：`swift build --target`（SwiftPM `swift test` blocker 已文档化）
- 下一阶段入口条件：macOS swift test 通过 → Reader-Core real mode facade 完成

## SwiftPM Linux Blocker 文档

SwiftPM (截至当前版本) 编译 ALL test targets 的依赖图，无论 `--filter`/`--skip`/`--target`。
Linux 下 `swift test` 会尝试编译 `ReaderApp` (SwiftUI) → `no such module 'SwiftUI'`。
Workaround: Linux CI 使用 `swift build --target <target>` 而非 `swift test`。
Solution: macOS CI 或等待 SwiftPM 支持 test target 隔离。
