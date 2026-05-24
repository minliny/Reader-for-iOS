# iOS Mock Data Flow Phase 1 Fix Queue

## 摘要

| 风险等级 | 数量 |
|---|---:|
| P0 | 0 |
| P1 | 0 |
| P2 | 0 |
| P3 | 0 |

Codex 设备端复测发现 1 个 P1：已修复，等待 Codex 复测。

## 设备端复测问题

| Issue ID | 风险等级 | 页面/流程 | 问题描述 | 期望表现 | 修复建议 | 是否需要修改 Swift | 是否需要 Claude Code 修复 | 是否阻塞进入下一阶段 |
|---|---|---|---|---|---|---|---|---|
| MOCK-FLOW-P1-001 | P1 | Search → Book Detail | Search mock results 可返回，但点击 result 后 Book Detail 空白。 | 点击后进入 Book Detail 并显示内容。 | READY_FOR_CODEX_VERIFY：BookDetailView 嵌套 NavigationStack 已移除，改用 sheet 展示 TOC；根因是双 NavigationStack 导致 iOS 18 渲染空白。 | 是 | 否（代码侧已修复） | 否 |

clean-room 结论：本轮仅执行 Simulator GUI 复测、截图与文档记录；未修改 Swift 源码，未修改 Reader-Core，未引入 parser internals，未接真实网络。
