# iOS Mock Data Flow Phase 1 Fix Queue

## 摘要

| 风险等级 | 数量 |
|---|---:|
| P0 | 0 |
| P1 | 0 |
| P2 | 0 |
| P3 | 0 |

MOCK-FLOW-P1-001 已重新修复（V2），等待 Codex 设备端复测。

## 设备端复测问题

| Issue ID | 风险等级 | 页面/流程 | 问题描述 | 期望表现 | 修复建议 | 是否需要修改 Swift | 是否需要 Claude Code 修复 | 是否阻塞进入下一阶段 |
|---|---|---|---|---|---|---|---|---|
| MOCK-FLOW-P1-001 | P1 | Search → Book Detail | REOPENED → READY_FOR_CODEX_VERIFY：上轮移除内层 NavigationStack 后仍空白。V2 定位真正根因为 `navigationDestination(item: $bookRoute)` 的 @State 双变量竞态导致 selectedResult 为 nil 时返回空白视图。 | 点击 mock search result 进入 Book Detail，显示书名/作者/简介/来源/目录入口。 | V2 修复：改用显式 `NavigationLink(destination: BookDetailView(result:))` 包裹结果行，移除 bookRoute/selectedResult 中间变量和 navigationDestination(item:) 绑定。 | 是 | 否（代码侧已重新修复） | 否 |

clean-room 结论：本轮使用本仓现有 SwiftUI 结构；未修改 Reader-Core；未引入 parser internals；未接真实网络。
