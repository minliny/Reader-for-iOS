# iOS Mock Data Flow Phase 1 Fix Queue

## 摘要

| 风险等级 | 数量 |
|---|---:|
| P0 | 0 |
| P1 | 0 |
| P2 | 0 |
| P3 | 0 |

Phase 1 所有 P0/P1/P2 已设备端确认解决。

## 已修复 P1

| Issue ID | 风险等级 | 状态 | 修复说明 |
|---|---|---|---|
| MOCK-FLOW-P1-001 | P1 | DEVICE_VERIFIED_RESOLVED | V2: 显式 NavigationLink(destination: BookDetailView(result:)) |
| MOCK-FLOW-P1-002 | P1 | DEVICE_VERIFIED_RESOLVED | Reader fix: 移除 ReaderView 内层 NavigationStack |

## 已修复 P2

| Issue ID | 风险等级 | 状态 | 修复说明 |
|---|---|---|---|
| MOCK-FLOW-P2-001 | P2 | DEVICE_VERIFIED_RESOLVED | Detail 信息补齐：简介/来源/最新章节/开始阅读/查看目录，设备端确认通过 |

clean-room 结论：未修改 Reader-Core；未引入 parser internals；未接真实网络。
