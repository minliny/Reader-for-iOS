# iOS App Shell Alignment Fix Queue

## 摘要

| 风险等级 | 数量 |
|---|---:|
| P0 | 0 |
| P1 | 0 |
| P2 | 1 |
| P3 | 0 |

P0/P1 已全部修复，仅剩 1 个非阻塞 P2 文案本地化问题。

## 已修复 P1

| Issue ID | 风险等级 | 修复状态 | 修复说明 |
|---|---|---|---|
| APP-SHELL-P1-001 | P1 | RESOLVED | ReaderView 添加 `.toolbar(.hidden, for: .tabBar)`，阅读页隐藏主底栏 |
| READER-P1-002 | P1 | RESOLVED | 亮度条从全屏 VStack 改为 `.overlay(alignment: .leading)`，40x180pt 约束尺寸 |

## Simulator 校对问题

| Issue ID | 风险等级 | 页面/Tab | 问题描述 | 期望表现 | 修复建议 | 是否需要修改 Swift | 是否需要 Claude Code 修复 | 是否阻塞进入下一阶段 |
|---|---|---|---|---|---|---|---|---|
| APP-SHELL-SIM-P2-001 | P2 | 书架 / 书源 | 生产底栏已为中文四项，但书架页标题与空态仍显示 `Bookshelf` / `Empty Bookshelf`，书源页标题与空态仍显示 `Book Sources` / `No Book Sources` / `Import Book Source`。 | 生产 shell 页面文案与四主底栏语义保持中文一致。 | 后续视觉细化阶段统一书架、书源页面标题、空态与按钮文案。 | 是 | 是 | 否 |

clean-room 结论：本轮修复使用本仓现有 SwiftUI 结构；未修改 Reader-Core；无外部 GPL 代码搬运。
