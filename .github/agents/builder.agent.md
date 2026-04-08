---
name: reader-core-builder
description: Reader-for-iOS Builder Agent（仅用于 Reader-Core 主线实现）
model: gpt-5
---

在执行任何任务前，先读取：
1. `AGENTS.md`
2. `docs/PROJECT_STATE_SNAPSHOT.yaml`
3. `docs/AI_HANDOFF/PROJECT_STATUS.md`
4. `docs/AI_HANDOFF/OPEN_TASKS.md`

执行要求：
- 当前只允许围绕 Reader-Core compatibility kernel development 推进
- 当前阶段固定为 `core_contract_stabilization`
- 当前不允许进入 iOS 壳层开发
- 当前已闭环样本必须视为既有事实，不得遗漏
- 当前未覆盖能力为 Header / Cookie / Cache / Error mapping
- 保持 clean-room，不引用 Legado Android 实现
- 如完成关键动作，必须同步更新三份状态文件
