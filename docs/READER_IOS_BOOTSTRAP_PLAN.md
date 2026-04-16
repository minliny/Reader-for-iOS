# Reader-iOS Bootstrap Plan

## Purpose

- 定义未来 `Reader-iOS` 独立仓的初始化蓝图。
- 为 `RS-005 Physical Repo Split Execution` 提供可直接执行的 bootstrap 输入。

## Usage Timing

- 当前使用时机：`RS-004 Reader-iOS Bootstrap Preparation`
- 后续执行时机：`RS-005 Physical Repo Split Execution`

## Historical Status

- future destination 已执行：`Reader-iOS/docs/READER_IOS_BOOTSTRAP_PLAN.md`
- 当前状态：`historical split record retained in Reader-iOS repo`

## Bootstrap Scope

- 新建 Reader-iOS 仓库骨架
- 迁移 `iOS/**`
- 迁移 iOS docs / workflows / scripts
- 接入 Reader-Core public package/products
- 建立 Reader-iOS handoff / status / governance docs

## Required Initial Paths

- `README.md`
- `AGENTS.md`
- `iOS/`
- `docs/`
- `docs/AI_HANDOFF/`
- `.github/workflows/`
- `scripts/`

## Deferred Paths

- `docs/archive/`
- `examples/`
- `Fixtures/`（仅当 Reader-iOS 后续需要 repo-local UI/validation fixtures）

## Bootstrap Deliverables

- Reader-iOS repo skeleton
- Reader-iOS package dependency wiring to Reader-Core
- migrated iOS code tree
- migrated iOS docs and history pointers
- migrated `ios-shell-ci` and `check_ios_boundary.sh`

## Constraints

- 本文档不是物理拆仓完成声明。
- Reader-iOS 只能依赖 Reader-Core public package/products。
- Reader-iOS 不得拥有 Core frozen contract 的实现控制权。
- 历史 iOS gate / phase / CI evidence 必须保留可追溯性。

## Done Definition For RS-005

- Reader-iOS repository created
- bootstrap skeleton committed
- iOS code/docs/workflows/scripts migrated
- Reader-iOS builds against Reader-Core package dependency
- Reader-Core retains history pointers
