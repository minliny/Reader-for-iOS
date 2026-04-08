# Reader-for-iOS AI 开发治理总则

## 强制前置主提示词

每次执行任何任务时，任意智能体都必须将以下内容原样放在输出最前面，再继续后续工作：

```text
你是本项目的 AI 开发代理。

项目定义：
这是一个“兼容 Legado 书源 JSON 主流字段结构与主流程行为”的多端本地客户端项目，采用“统一 Core + 多端壳层”路线。当前主线为 Reader-Core first，iOS later。当前阶段聚焦 Reader-Core 兼容内核开发与 core contract stabilization，先完成非 UI、非壳层、可回归的核心兼容闭环，再决定是否进入 iOS 壳层阶段。

你必须遵守以下规则：
1. 兼容格式与行为，不复用实现代码。
2. 禁止复制、翻译、改写 Legado Android 源码。
3. 禁止输出与既有规范冲突的数据结构。
4. 所有兼容性改动都必须绑定样本、失败原因、预期变化、回归结果。
5. 不得跳过 metadata、expected、matrix。
6. 不得修改 A/B/C/D 兼容等级定义。
7. 不得新增 failure taxonomy 而不同时更新配置。
8. 输出优先使用 YAML、JSON、目录树、字段表、模板文件、代码。
9. 不要泛化讨论，不要先讲空计划，直接给可执行结果。
10. 所有实现都必须考虑 clean-room 原则，并说明无外部 GPL 代码搬运。

当前已闭环样本：
- sample_js_runtime_001
- sample_js_runtime_002
- sample_004
- sample_005

当前成熟能力：
- CI 执行
- artifact 产出
- regression 回写
- writeback 审核
- compat_matrix 审计吸收

当前未覆盖能力：
- Header
- Cookie
- Cache
- Error mapping

当前阶段不做：
- iOS 壳层推进
- 直接移植 Android 实现
- 完整历史边缘规则兼容
- 复杂在线调试服务复刻
- 内置内容平台
- 云同步、账号、社区优先开发

工作方式：
1. 先输出本次要生成的文件列表。
2. 再输出每个文件的用途。
3. 再输出风险点和验收方式。
4. 最后再输出具体内容。

PR 输出必须包含：
- 关联样本
- 改动范围
- 修复前失败类型
- 修复后预期
- 回归摘要
- 是否更新 compat_matrix
- 是否新增 failureType
- 是否需要人工补样本

现在开始执行我接下来给出的任务，不要复述背景，直接产出可落地结果。
```

## 项目目标

- 交付一个本地化、多端可复用的阅读核心能力，兼容 Legado 书源 JSON 主流字段结构与主流程行为。
- 当前主线为 Reader-Core 兼容内核开发，先稳定 Core contract、样本闭环、回归吸收与状态同步，再考虑 iOS 壳层接入。
- 以样本驱动、回归驱动与 clean-room 方式推进，保证每次兼容性改动可验证、可追溯、可回退。

## 当前真实项目状态

```yaml
project:
  strategy: Reader-Core first
  shell_policy: iOS later
  mainline: Reader-Core compatibility kernel development
  phase: core_contract_stabilization

closed_samples:
  - sample_js_runtime_001
  - sample_js_runtime_002
  - sample_004
  - sample_005

mature_capabilities:
  - ci_execution
  - artifact_output
  - regression_writeback
  - writeback_review
  - compat_matrix_audit_absorption

uncovered_capabilities:
  - Header
  - Cookie
  - Cache
  - Error mapping

ios_gate:
  allowed: false
  reason: "Reader-Core 主线仍处于 core_contract_stabilization，未完成 Header/Cookie/Cache/Error mapping 闭环。"

recent_completed_action: "Header capability closure 已转化为样本驱动任务"
next_best_task: "基于 SAMPLE-P1-HEADER-001/002/003 推进 Header 能力实现与回归。"
header_sample_driven_task:
  matrix_state: "expectedLevel A / actualLevel C / failureType NETWORK_POLICY_MISMATCH"
  implementation_done: false
```

## 首版范围与边界

### 首版必须完成
- 统一 Core 基础模型
- BookSource 导入
- 搜索 / 目录 / 正文主链路
- 非 JS 主路径
- Header / 基础 Cookie / 缓存 / 错误定位
- 最小调试能力

### 当前已成熟能力
- CI 执行
- artifact 产出
- regression 回写
- writeback 审核
- compat_matrix 审计吸收

### 当前未覆盖能力
- Header
- Cookie
- Cache
- Error mapping

### 当前明确不做
- 当前阶段不进入 iOS 壳层开发
- 直接移植 Android 实现
- 完整历史边缘规则兼容
- 复杂在线调试服务复刻
- 内置内容平台
- 云同步、账号、社区优先开发

## 禁止事项

- 禁止复制、翻译、改写 Legado Android 源码或其实现细节。
- 禁止引入首版范围外功能并伪装为“顺手优化”。
- 禁止在未绑定样本的情况下提交兼容性改动。
- 禁止跳过 metadata、expected、matrix 中任一项。
- 禁止修改 A/B/C/D 兼容等级定义。
- 禁止新增 failure taxonomy 而不更新对应配置与回归脚本。
- 禁止在 `ios_gate.allowed = false` 时推进 iOS 壳层实现、UI 接线或 iOS 优先叙事。

## Clean-Room 原则

- 实现依据仅来自公开协议、输入输出行为、项目样本与本仓库规范。
- 任何实现描述必须可追溯到样本、规范或本仓库文档，不可追溯到 Legado Android 源码。
- 本仓库所有智能体输出都必须显式说明 clean-room 结论，避免外部 GPL 代码搬运风险。
- 若发现污染风险，必须立即停止合并并回退相关改动。

## 样本驱动原则

- 每个兼容性需求必须先落地样本，再做实现。
- 每个样本必须具备 metadata，且可回归样本必须具备 expected 或 degradeExpectation。
- 每个改动必须更新或复用以下资产：
  - `samples/metadata`
  - `samples/expected`
  - `samples/matrix/compat_matrix.yml`
  - `samples/matrix/failure_taxonomy.yml`
- 回归摘要必须包含样本覆盖范围、失败类型变化、兼容等级变化。

## 自动状态更新机制

以下规则适用于任何“开发步骤完成后”的状态同步：

### 触发动作

每完成一次以下动作，必须立即同步更新状态文件：
- regression 正式回写
- writeback 完成
- compat_matrix 审计确认
- 新样本闭环完成

### 必须同步更新的文件

- `docs/PROJECT_STATE_SNAPSHOT.yaml`
- `docs/AI_HANDOFF/PROJECT_STATUS.md`
- `docs/AI_HANDOFF/OPEN_TASKS.md`

### 必须写入的字段

- 当前已闭环样本
- 当前阶段
- 当前主线
- 当前未覆盖能力
- 下一步唯一最优任务
- 最近一次完成的关键动作
- 当前是否允许进入 iOS 阶段与判断原因

### 一致性要求

- 不允许遗漏已闭环样本。
- 不允许保留已完成任务在 `OPEN_TASKS.md`。
- 不允许出现历史状态与当前状态冲突。
- 三份文件必须保持同一事实基线、同一阶段、同一下一步任务。
- 若本次变更不涉及样本或兼容矩阵，也必须检查三份文件是否仍与当前事实一致。

## PR 门禁

所有 PR 合并前必须满足：

1. 模板字段完整：关联样本、改动范围、修复前失败类型、修复后预期、回归摘要、风险、回退方案。
2. 样本绑定完整：新增或变更兼容行为必须有样本与 expected。
3. 矩阵一致性：compat_matrix 与 failure_taxonomy 的更新结论明确。
4. Clean-room 检查通过：无 GPL 搬运风险。
5. Reviewer 给出可合并结论，且无未处理 P0 问题。

## 测试门禁

所有 PR 合并前必须通过以下检查：

1. 单元测试通过。
2. 样本回归通过（至少覆盖受影响样本集合）。
3. 兼容矩阵校验脚本通过。
4. 失败类型校验脚本通过。
5. iOS 构建检查通过（仅在 `ios_gate.allowed = true` 且实际涉及 iOS 代码时必需）。

若任一门禁失败，PR 不得合并。

## Agent 协作约束

- Planner 只负责拆解方案，不写业务实现代码。
- Builder 只按已批准方案实现，不擅自扩 scope。
- Reviewer 只做审查，不直接实现功能。
- Regression 只维护样本与回归资产，不实现业务逻辑。
- 所有角色都必须先吸收 `docs/PROJECT_STATE_SNAPSHOT.yaml` 与 `docs/AI_HANDOFF/*`，禁止依赖对话上下文代替仓库状态。

## 生效范围

- 本文件适用于本仓库下所有人类与智能体协作任务。
- 子智能体配置必须显式继承本文件的“强制前置主提示词”。
- 如子智能体配置与本文件冲突，以本文件为准。
