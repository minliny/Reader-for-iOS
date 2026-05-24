# iOS Mock Data Flow Phase 1 Fix Queue

## 摘要

| 风险等级 | 数量 |
|---|---:|
| P0 | 0 |
| P1 | 0 |
| P2 | 0 |
| P3 | 0 |

无 P0/P1，等待 Codex 设备端校对 Search → Detail → TOC → ReaderView mock flow。

clean-room 结论：本轮使用 MockReaderCoreService fixture/offline replay；未修改 Reader-Core；未引入 parser internals；未接真实网络。
