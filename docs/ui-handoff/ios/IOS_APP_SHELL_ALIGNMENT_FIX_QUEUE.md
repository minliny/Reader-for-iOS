# iOS App Shell Alignment Fix Queue

## 摘要

| 风险等级 | 数量 |
|---|---:|
| P0 | 0 |
| P1 | 0 |
| P2 | 0 |
| P3 | 0 |

P0/P1/P2 已全部修复；P2-001/P2-002 已完成 Codex 设备端复测确认。

## 已修复 P1

| Issue ID | 风险等级 | 修复状态 | 修复说明 |
|---|---|---|---|
| APP-SHELL-P1-001 | P1 | DEVICE_VERIFIED_RESOLVED | ReaderView 添加 `.toolbar(.hidden, for: .tabBar)`；Codex 通过 `[DEBUG] ReaderView Fixture` 进入真实 ReaderView 设备端复测，确认阅读页隐藏主底栏，返回后主底栏恢复。 |
| READER-P1-002 | P1 | DEVICE_VERIFIED_RESOLVED | Codex 设备端复测通过：亮度条为 44pt 高横向控制行（sun.min / Slider / sun.max / 系统），位于 top bar + meta row 下方；不再占据大量空间，不覆盖四角信息、底部控制层或大面积正文。 |

## Simulator 校对问题

| Issue ID | 风险等级 | 页面/Tab | 问题描述 | 期望表现 | 修复建议 | 是否需要修改 Swift | 是否需要后续实现 | 是否阻塞进入下一阶段 |
|---|---|---|---|---|---|---|---|---|
| APP-SHELL-SIM-P2-001 | P2 | 书架 / 书源 | 书架/书源页面存在英文标题、空态、按钮文案。 | 生产 shell 页面文案中文化。 | DEVICE_VERIFIED_RESOLVED：BookshelfView 与 BookSourceListView 设备端复测均显示中文标题、空态与按钮。 | 是 | 否 | 否 |
| APP-SHELL-SIM-P2-002 | P2 | 生产 ReaderView 路径 | 生产路径无法进入 ReaderView 验证 tab bar 隐藏。 | 提供 fixture-only 复测路径。 | DEVICE_VERIFIED_RESOLVED：`[DEBUG] ReaderView Fixture` 可进入真实 ReaderView，fixture-only，无主底栏，返回后主底栏恢复。 | 是 | 否 | 否 |

clean-room 结论：本轮仅执行 Simulator GUI 复测、截图与文档记录；未修改 Swift 源码，未修改 Reader-Core，无外部 GPL 代码搬运。
