你是本项目的 AI 开发代理。

以下内容是仓库内统一项目上下文，任何模型在执行任务前必须先吸收，不允许依赖对话历史补足关键信息。

## 1. 当前项目定义

```yaml
project:
  name: Reader-for-iOS
  strategy: Reader-Core first
  shell_policy: iOS later
  mainline: Reader-Core compatibility kernel development
  phase: core_contract_stabilization
  clean_room: true
  ios_allowed_now: false
```

解释：
- 当前主线不是 iOS 壳层开发，而是 Reader-Core 兼容内核开发。
- iOS 相关工作处于后置阶段，只有当核心兼容能力闭环且 `ios_allowed_now` 变为 `true` 时才允许进入。
- 所有实现必须遵守 clean-room，禁止引用或搬运 Legado Android 实现。

## 2. 当前事实基线

### 已闭环样本

```yaml
closed_samples:
  - sample_js_runtime_001
  - sample_js_runtime_002
  - sample_004
  - sample_005
```

### 已成熟能力

```yaml
mature_capabilities:
  - CI 执行
  - artifact 产出
  - regression 回写
  - writeback 审核
  - compat_matrix 审计吸收
```

### 当前未覆盖能力

```yaml
uncovered_capabilities:
  - Header
  - Cookie
  - Cache
  - Error mapping
```

### 当前阶段与主线

```yaml
state:
  phase: core_contract_stabilization
  active_tracks:
    - Reader-Core
    - 非 JS 主路径
  next_best_task: Header capability closure
  recent_completed_action: Header capability closure 已转化为样本驱动任务
  ios_gate:
    allowed: false
    reason: "Header/Cookie/Cache/Error mapping 尚未完成，仍禁止进入 iOS 阶段。"
```

## 3. 当前任务边界

### 当前允许推进
- Reader-Core 兼容内核开发
- 非 JS 主路径闭环
- Header / Cookie / Cache / Error mapping 的样本化与契约稳定
- 状态文件、handoff 文件、agent 提示词的同步维护

### 当前 Header 样本驱动任务
- `SAMPLE-P1-HEADER-001`：基础 Header，search expected
- `SAMPLE-P1-HEADER-002`：Referer/User-Agent，toc expected
- `SAMPLE-P1-HEADER-003`：反爬策略，content expected
- 当前 matrix 状态：expectedLevel A / actualLevel C / failureType NETWORK_POLICY_MISMATCH
- 注意：本阶段仅完成样本驱动任务定义，尚未实现 Core Header 功能。

### 当前不允许推进
- iOS 壳层实现
- Android 实现迁移
- 范围外功能扩展
- 未绑定样本的兼容性修改
- 修改 A/B/C/D 兼容等级定义
- 新增 failure taxonomy 而不更新配置

## 4. 自动状态更新机制

任何模型在完成一次开发步骤后，都必须把仓库状态同步到以下三个文件，确保后续模型无需上下文即可理解当前状态：

```yaml
required_sync_files:
  - docs/PROJECT_STATE_SNAPSHOT.yaml
  - docs/AI_HANDOFF/PROJECT_STATUS.md
  - docs/AI_HANDOFF/OPEN_TASKS.md
```

### 触发条件
- regression 正式回写
- writeback 完成
- compat_matrix 审计确认
- 新样本闭环完成

### 必须同步的内容
- 当前已闭环样本
- 当前阶段
- 当前主线
- 当前未覆盖能力
- 下一步唯一最优任务
- 最近一次完成的关键动作
- 当前是否允许进入 iOS 阶段与判断原因

### 同步规则
- 不允许遗漏已闭环样本。
- 不允许把已完成任务继续保留在 `OPEN_TASKS.md`。
- 不允许三份文件之间出现阶段、主线、下一步任务或 iOS 判断不一致。
- 若一次开发步骤仅改治理文档，也必须同步检查三份文件仍与当前真实状态一致。

## 5. 当前交接阅读顺序

模型进入仓库后建议按以下顺序建立上下文：

1. `AGENTS.md`
2. `docs/PROJECT_STATE_SNAPSHOT.yaml`
3. `docs/AI_HANDOFF/PROJECT_STATUS.md`
4. `docs/AI_HANDOFF/OPEN_TASKS.md`
5. `docs/AI_HANDOFF/DECISIONS.md`
6. `docs/AI_HANDOFF/NEXT_PROMPTS.md`

## 6. Clean-Room 声明

- 本项目当前状态说明仅来自仓库内部事实、样本、回归结果与治理文件。
- 不引用 Legado Android 实现细节。
- 无外部 GPL 代码搬运。
