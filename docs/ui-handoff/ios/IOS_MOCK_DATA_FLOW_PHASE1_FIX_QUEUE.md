# iOS Mock Data Flow Phase 1 Fix Queue

## 摘要

| 风险等级 | 数量 |
|---|---:|
| P0 | 0 |
| P1 | 0 |
| P2 | 1 |
| P3 | 0 |

MOCK-FLOW-P1-001/P1-002 已完成 Codex 设备端复测并确认解决。剩余 1 个 P2（Book Detail 可见信息不足），不阻塞 Mock Data Flow Phase 1 收口。

## 已修复 P1

| Issue ID | 风险等级 | 状态 | 修复说明 |
|---|---|---|---|
| MOCK-FLOW-P1-001 | P1 | DEVICE_VERIFIED_RESOLVED | V2: 显式 NavigationLink(destination: BookDetailView(result:)) 替代 navigationDestination(item:) + 双 @State |
| MOCK-FLOW-P1-002 | P1 | DEVICE_VERIFIED_RESOLVED | Reader fix: 移除 ReaderView 内层 NavigationStack；TOC 第一章进入 ReaderView 后显示 `第一章 山村少年` 与 mock 正文，主底栏隐藏 |

## 设备端复测问题

| Issue ID | 风险等级 | 页面/流程 | 问题描述 | 期望表现 | 修复建议 | 是否需要修改 Swift | 是否需要 Claude Code 修复 | 是否阻塞进入下一阶段 |
|---|---|---|---|---|---|---|---|---|
| MOCK-FLOW-P2-001 | P2 | Book Detail | READY_FOR_CODEX_VERIFY：Detail 信息已补齐，新增来源（Mock 书源）、最新章节（第一章 山村少年）、简介（mock fallback）、开始阅读（NavigationLink → ReaderView 第一章）、查看目录（5 章）。 | Detail 清晰展示书名、作者、简介、来源、最新章节、目录入口。 | 已补齐：bookDetailContent 增加来源/简介/最新章节 mock fallback + 开始阅读/查看目录按钮。 | 是 | 否（代码侧已补齐） | 否 |

clean-room 结论：本轮使用本仓现有 SwiftUI 结构；未修改 Reader-Core；未引入 parser internals；未接真实网络。
