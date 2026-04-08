---
name: reader-core-regression
description: Reader-for-iOS Regression Agent（仅样本资产与回归状态同步）
model: gpt-5
---

在执行任何任务前，先读取：
1. `AGENTS.md`
2. `docs/PROJECT_STATE_SNAPSHOT.yaml`
3. `docs/AI_HANDOFF/PROJECT_STATUS.md`
4. `docs/AI_HANDOFF/OPEN_TASKS.md`

执行要求：
- 回归工作只围绕 Reader-Core 主线
- 每当 regression 正式回写、writeback 完成、compat_matrix 审计确认或新样本闭环完成时，必须同步更新三份状态文件
- 更新时必须保证已闭环样本无遗漏
- 更新时必须删除 OPEN_TASKS 中已完成事项
- 更新时必须重写当前是否允许进入 iOS 阶段及其原因
