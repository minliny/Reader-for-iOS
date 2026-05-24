# iOS App Shell Alignment Fix Queue

## 摘要

| 风险等级 | 数量 |
|---|---:|
| P0 | 0 |
| P1 | 0 |
| P2 | 2 |
| P3 | 0 |

P0/P1 已全部修复；设备复测后剩余 2 个非阻塞 P2 问题。

## 已修复 P1

| Issue ID | 风险等级 | 修复状态 | 修复说明 |
|---|---|---|---|
| APP-SHELL-P1-001 | P1 | RESOLVED / DEVICE_REVIEW_PENDING_PRODUCTION_PATH | ReaderView 添加 `.toolbar(.hidden, for: .tabBar)`；Simulator 复测时生产书架为空且搜索无书源，无法进入生产 ReaderView，不判 REOPENED；新增 P2 后续复测项。 |
| READER-P1-002 | P1 | READY_FOR_CODEX_VERIFY | 亮度条重新修复：从 40x180pt 竖向 overlay 改为 44pt 高横向控制行（sun.min | Slider | sun.max | 系统），位于 top bar + meta row 下方；需 Codex 设备端复测。 |

## Simulator 校对问题

| Issue ID | 风险等级 | 页面/Tab | 问题描述 | 期望表现 | 修复建议 | 是否需要修改 Swift | 是否需要 Claude Code 修复 | 是否阻塞进入下一阶段 |
|---|---|---|---|---|---|---|---|---|
| APP-SHELL-SIM-P2-001 | P2 | 书架 / 书源 | 生产底栏已为中文四项，但书架页标题与空态仍显示 `Bookshelf` / `Empty Bookshelf`，书源页标题与空态仍显示 `Book Sources` / `No Book Sources` / `Import Book Source`。 | 生产 shell 页面文案与四主底栏语义保持中文一致。 | 后续视觉细化阶段统一书架、书源页面标题、空态与按钮文案。 | 是 | 是 | 否 |
| APP-SHELL-SIM-P2-002 | P2 | 生产 ReaderView 路径 | Simulator 复测时生产书架为空，搜索页没有可选书源，搜索会提示 `No book source selected`，因此无法通过生产 UI 进入 ReaderView 设备端验证 tab bar 隐藏。 | 后续提供 fixture-only 的生产 ReaderView 可达路径，或预置本地 mock 书源/章节，便于设备端闭环验证。 | 在不接真实网络/真实书源的前提下补充 debug-only 或 fixture-only ReaderView 复测入口；保持生产入口边界不变。 | 是 | 是 | 否 |

clean-room 结论：本轮仅执行 Simulator GUI 复测、截图与文档记录；未修改 Swift 源码，未修改 Reader-Core，无外部 GPL 代码搬运。
