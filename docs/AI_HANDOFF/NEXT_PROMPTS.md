# 下一阶段提示词 (NEXT_PROMPTS)

> support-only 文档；不是 active prompt entry，不参与唯一 active prompt chain。

## Reference Prompt Set

### 1. Default Post-Split Handoff Prompt

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
- current_repo_role: Reader-iOS
- upstream_core_repo: Reader-Core
- phase: post_split_stabilization_audit
- feature_expansion_paused: true
- dependency_direction: Reader-iOS -> Reader-Core public package/products only

执行限制：
- 不开发新 feature
- 不改动 Core 业务逻辑
- 不扩 scope
- 只处理审计、结构/依赖/CI/文档问题与 boundary hardening
```

### 2. Stabilization Audit Prompt

```text
你现在处理 Post-Split Stabilization Audit。

目标：
- 验证双仓独立构建/测试/CI/文档/边界是否达到长期稳态
- 修复 split 后结构、依赖、CI、文档问题
- 保留审计可追溯性

禁止：
- 开发新 feature
- 改动 Core 业务逻辑
- 伪造双仓稳态
```

## Legacy Prompt Policy

- 所有 pre-split prompt 已移入 archive-only 区域
- 不允许继续使用任何带有旧主线、旧阶段、旧轨道或旧 iOS feature 续推语义的提示词作为 active handoff
