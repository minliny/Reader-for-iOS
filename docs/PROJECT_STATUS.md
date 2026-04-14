# 项目状态总览

## 当前可信主线

- 可信主线分支：`main`
- 当前仓库过渡角色：`Reader-Core transition host`
- 后续长期身份：`Reader-Core`
- 当前结论：主仓不再继续承载 Core 主线与 iOS 产品壳层主线的长期混合演进。

## 当前阶段

- 项目目标：`Reader-iOS bootstrap preparation`
- 当前阶段：`repo_split_execution_phase_a`
- 当前主线：`split-era governance and Reader-iOS bootstrap preparation`
- 当前下一步：`RS-005 Physical Repo Split Execution`

## 当前 bootstrap 语义

- RS-002 Docs Split：`PASS`
- RS-003 Workflow Split：`PASS`
- 当前正在执行：`RS-004 Reader-iOS Bootstrap Preparation`
- 当前仍未执行：`Reader-iOS physical repo split`

## 文档角色说明

- 本页是主仓总览页，不是 Reader-iOS 的长期状态页。
- 当前 docs 入口以 Reader-Core transition host 视角组织。
- iOS docs 仍在 `docs/` 根目录，但归属语义已经变为 `pending migration`。
- docs 分类与迁移索引见 `docs/DOCS_SPLIT_INDEX.md` 与 `docs/IOS_PENDING_MIGRATION_REGISTRY.md`。
- Reader-iOS bootstrap 输入文档见：
  - `docs/READER_IOS_BOOTSTRAP_PLAN.md`
  - `docs/READER_IOS_DEPENDENCY_BOOTSTRAP.md`
  - `docs/READER_IOS_MIGRATION_MANIFEST.md`
  - `docs/READER_IOS_REPO_INIT_CHECKLIST.md`

## 边界结论

- `Core/**`、`samples/**`、compat/regression/tooling/docs mainline 继续属于 Reader-Core。
- `iOS/**`、iOS gate 文档、`ios-shell-ci` workflow、边界检查脚本属于待迁移 Reader-iOS 资产。
- 现有 iOS 远端执行证据保留，但不再作为 Core 主仓长期状态维护。

## 风险与阻塞

- 若继续在主仓维护任何 pre-split iOS feature phase，会持续污染 Core 主仓状态语义与 CI 归属。
- 若 Reader-iOS 在拆仓后直接 import Core internal modules，会破坏 clean boundary 与版本治理。
- 物理拆仓尚未执行，当前仍需避免误写“已拆仓完成”。

## 推荐下一步

- 按 `docs/READER_IOS_REPO_INIT_CHECKLIST.md` 执行 RS-005 Physical Repo Split Execution。
- 在 RS-005 中新建 Reader-iOS 仓并迁移 `iOS/**`、iOS docs、iOS workflows/scripts。
- 将 Reader-iOS 依赖切换为 Reader-Core public package/products only。

## Clean-Room 说明

- 本次状态重写仅基于仓库内部文件与既有执行证据，不引入或搬运任何外部 GPL 代码。
