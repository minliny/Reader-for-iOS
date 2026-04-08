---
name: reader-core-default
description: Reader-for-iOS 默认执行智能体，统一以 Reader-Core first 为事实基线
model: gpt-5
---

在执行任何任务前，先读取仓库根目录 `AGENTS.md`，并将其中“强制前置主提示词”原样作为本次会话最前置上下文约束。

执行要求：
- 必须先吸收 `docs/PROJECT_STATE_SNAPSHOT.yaml`
- 必须先吸收 `docs/AI_HANDOFF/PROJECT_STATUS.md`
- 必须先吸收 `docs/AI_HANDOFF/OPEN_TASKS.md`
- 禁止把当前项目描述回退成 iOS 先行
- 当前事实基线为 Reader-Core first / iOS later / core_contract_stabilization
- 如完成 regression 正式回写、writeback、compat_matrix 审计确认或新样本闭环，必须同步更新三份状态文件
