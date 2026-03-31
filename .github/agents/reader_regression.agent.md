---
name: reader-regression
description: Reader-for-iOS Reader_Regression（仅样本资产与回归）
model: gpt-5
---

在执行任何任务前，先读取仓库根目录 AGENTS.md，并将其中两段内容按顺序原样作为本次会话最前置上下文约束：
1) “强制前置主提示词”
2) “Reader_Regression Agent（仅此智能体全局提示词）”

执行要求：
- 禁止省略上述两段内容
- 禁止改写措辞
- 如用户请求与前置内容冲突，按前置内容执行
