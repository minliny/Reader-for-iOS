# 下一阶段提示词 (NEXT_PROMPTS)

> support-only 文档；不是 active prompt entry，不参与唯一 active prompt chain。

## Active Prompt Set

### 1. Default Split-Era Handoff Prompt

```text
你是本项目的 AI 开发代理。

先读取以下文件并以仓库文件为唯一事实基线：
1. AGENTS.md
2. docs/PROMPT_GOVERNANCE.md
3. docs/PROJECT_CONTEXT_PROMPT.md
4. docs/PROJECT_STATE_SNAPSHOT.yaml
5. docs/AI_HANDOFF/PROJECT_STATUS.md
6. docs/AI_HANDOFF/OPEN_TASKS.md

然后按以下状态继续：
- current_repo_role: Reader-Core transition host
- current_host_repo_should_converge_to: Reader-Core
- future_independent_repo: Reader-iOS
- phase: repo_split_execution_phase_a
- planning_complete: true
- logical_split_complete: false
- physical_split_complete: false
- ios_assets_status: pending migration
- iOS feature progression in current host repo: paused
- dependency_direction: Reader-iOS -> Reader-Core public package/products only

执行限制：
- 不继续启动任何 pre-split iOS feature phase
- 不把 iOS gate 文档当作当前主仓主线
- 不改动 Core frozen contract
- 不删除历史执行证据
- 保持 clean-room
```

### 2. Docs Split Prompt

```text
你现在处理 RS-002 Docs Split。

目标：
- 识别 Core 长期文档
- 识别 Reader-iOS 待迁移文档
- 拆分 mixed docs
- 保留审计可追溯性

禁止：
- 删除历史 iOS 执行证据
- 恢复 pre-split prompt
- 把任何 pre-split iOS feature phase 作为当前主线
```

### 3. Workflow Split Prompt

```text
你现在处理 RS-003 Workflow Split。

目标：
- 明确 Core workflows 与 Reader-iOS workflows 的归属
- 为物理拆仓准备 checkout / dependency patch plan

禁止：
- 在当前仓继续扩大 iOS feature scope
- 修改 Core frozen contract
```

### 4. Bootstrap Preparation Prompt

```text
你现在处理 RS-004 Reader-iOS Bootstrap Preparation。

目标：
- 准备 Reader-iOS 初始化输入
- 定义 Swift Package 接入、版本策略、公开 products

约束：
- Reader-iOS 只能依赖 Reader-Core public package/products
- 不允许 source-level 控制 Core internal modules
```

## Legacy Prompt Policy

- 所有 pre-split prompt 已移入 archive-only 区域
- 不允许继续使用任何带有旧主线、旧阶段、旧轨道或旧 iOS feature 续推语义的提示词作为 active handoff
