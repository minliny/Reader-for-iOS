# Prompt Governance

## Status

```yaml
prompt_governance:
  era: post_split
  current_repo_role: Reader-iOS
  upstream_core_repo: Reader-Core
  clean_room: true
  active_mode: stabilization_audit
```

## Active Prompt Chain

1. `AGENTS.md`
2. `docs/PROMPT_GOVERNANCE.md`
3. `docs/PROJECT_CONTEXT_PROMPT.md`
4. `docs/AI_HANDOFF.md`

## State Inputs Outside Prompt Chain

- `docs/PROJECT_STATE_SNAPSHOT.yaml`
- `docs/AI_HANDOFF/PROJECT_STATUS.md`
- `docs/AI_HANDOFF/OPEN_TASKS.md`

## Governance Rules

1. 当前仓库 prompt 必须以 Reader-iOS 主仓语义运行。
2. 任何 `transition host`、`monorepo`、或“Reader-for-iOS contains Core”语义不得再作为 active source。
3. 允许引用 Reader-Core，但只能作为外部依赖仓。
4. 禁止在 stabilization audit 轮次扩展为 feature 开发。
5. 重要历史 prompt 和 split-era planning docs 只可作为审计记录。

## Lockdown Rules

```yaml
lockdown:
  active_chain_only: true
  fail_on_legacy_role_reference: true
  failure_action: "rebuild context from AGENTS.md -> docs/PROMPT_GOVERNANCE.md -> docs/PROJECT_CONTEXT_PROMPT.md -> docs/AI_HANDOFF.md"
```
