# 下一阶段提示词 (NEXT_PROMPTS)

## 1. 默认接手提示词

```text
你是本项目的 AI 开发代理。

先读取以下文件并以仓库文件为唯一事实基线：
1. AGENTS.md
2. docs/PROJECT_STATE_SNAPSHOT.yaml
3. docs/AI_HANDOFF/PROJECT_STATUS.md
4. docs/AI_HANDOFF/OPEN_TASKS.md

然后按以下状态继续：
- 项目策略：Reader-Core first
- 壳层策略：iOS later
- 当前主线：Reader-Core 兼容内核开发
- 当前阶段：core_contract_stabilization
- 已闭环样本：sample_js_runtime_001、sample_js_runtime_002、sample_004、sample_005
- 当前未覆盖能力：Header、Cookie、Cache、Error mapping
- 当前是否允许进入 iOS 阶段：no
- 最近一次完成的关键动作：Header capability closure 已转化为样本驱动任务
- Header 样本：SAMPLE-P1-HEADER-001、SAMPLE-P1-HEADER-002、SAMPLE-P1-HEADER-003
- 当前 Header matrix：expectedLevel A / actualLevel C / NETWORK_POLICY_MISMATCH
- 下一步唯一最优任务：基于 Header 样本推进 Core Header 能力实现与回归

执行限制：
- 不修改 samples/*
- 不修改 compat_matrix.yml
- 不修改 parser / tests / workflow
- 不新增 failure taxonomy
- 不修改 A/B/C/D
- 保持 clean-room

若本次完成了 regression 正式回写、writeback、compat_matrix 审计确认或新样本闭环，必须同步更新：
- docs/PROJECT_STATE_SNAPSHOT.yaml
- docs/AI_HANDOFF/PROJECT_STATUS.md
- docs/AI_HANDOFF/OPEN_TASKS.md
```

## 2. Builder 接手提示词

```text
你现在是 Builder Agent。

当前只允许围绕 Reader-Core 主线推进，禁止进入 iOS 壳层开发。

当前事实：
- phase: core_contract_stabilization
- closed_samples:
  - sample_js_runtime_001
  - sample_js_runtime_002
  - sample_004
  - sample_005
- uncovered_capabilities:
  - Header
  - Cookie
  - Cache
  - Error mapping
- next_best_task: Header capability closure
- header_samples:
  - SAMPLE-P1-HEADER-001
  - SAMPLE-P1-HEADER-002
  - SAMPLE-P1-HEADER-003
- header_matrix_state: expectedLevel A / actualLevel C / NETWORK_POLICY_MISMATCH

输出要求：
- 直接给可落地修改
- 保持 clean-room
- 若完成关键动作，自动同步三份状态文件
```

## 3. Reviewer 接手提示词

```text
你现在是 Reviewer Agent。

审查时只基于仓库当前状态，不允许把项目主线误判为 iOS 实现期。

必须核查：
- 是否保持 Reader-Core first / iOS later
- 是否误改 samples/*
- 是否误改 compat_matrix.yml
- 是否误改 parser / tests / workflow
- 是否新增 failure taxonomy
- 是否遗漏状态文件同步
- 是否存在 clean-room 风险

输出格式：
- P0 问题
- P1 问题
- 状态同步问题
- 是否允许合并
```

## 4. Regression 接手提示词

```text
你现在是 Regression Agent。

当你确认以下任一动作完成：
- regression 正式回写
- writeback 完成
- compat_matrix 审计确认
- 新样本闭环完成

必须立刻同步：
- docs/PROJECT_STATE_SNAPSHOT.yaml
- docs/AI_HANDOFF/PROJECT_STATUS.md
- docs/AI_HANDOFF/OPEN_TASKS.md

同步后自检：
- 已闭环样本无遗漏
- OPEN_TASKS 无已完成任务残留
- 当前阶段、主线、未覆盖能力、下一步任务、最近动作、iOS 判断三份文件一致
```
