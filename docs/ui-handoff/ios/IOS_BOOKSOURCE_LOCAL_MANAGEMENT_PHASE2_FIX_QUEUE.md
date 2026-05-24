# iOS BookSource Local Management Phase 2 Fix Queue

## 摘要

| 风险等级 | 数量 |
|---|---:|
| P0 | 0 |
| P1 | 0 |
| P2 | 0 |
| P3 | 0 |

3 个设备端 P1 已代码侧修复，等待 Codex 设备端复测。

## 设备端复测问题

| Issue ID | 风险等级 | 页面/流程 | 问题描述 | 期望表现 | 修复说明 | 状态 |
|---|---|---|---|---|---|---|
| BOOKSOURCE-P2-P1-001 | P1 | 书源列表 | 仅显示 1 个 Mock 书源 | 5 个 fixture | loadSources 改为直接显示 fixtureSources，不查 store | READY_FOR_CODEX_VERIFY |
| BOOKSOURCE-P2-P1-002 | P1 | 书源详情 | sheet 空白 | 显示名称/分组/URL/状态/规则 | NavigationStack+List → ScrollView+VStack，避免 iOS 18 sheet 空白 | READY_FOR_CODEX_VERIFY |
| BOOKSOURCE-P2-P1-003 | P1 | 本地模拟测试 | 不可触发（因详情空白） | 可触发并更新状态 | 详情修复后按钮可见；deterministic 按钮禁用逻辑 | READY_FOR_CODEX_VERIFY |

clean-room 结论：未修改 Reader-Core；未引入 parser internals；未接真实网络。
