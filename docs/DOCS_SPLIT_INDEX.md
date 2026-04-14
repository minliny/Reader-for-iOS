# Docs Split Index

## Status

```yaml
docs_split:
  phase: RS-002
  current_docs_role: Reader-Core transition host docs
  planning_complete: true
  logical_split_complete: false
  docs_split_complete: true
  physical_split_complete: false
  clean_room: true
```

## Core Docs

- `docs/PROJECT_STATE_SNAPSHOT.yaml`
- `docs/PROJECT_STATUS.md`
- `docs/PROMPT_GOVERNANCE.md`
- `docs/PROJECT_CONTEXT_PROMPT.md`
- `docs/AI_HANDOFF.md`
- `docs/AI_HANDOFF/PROJECT_STATUS.md`
- `docs/AI_HANDOFF/OPEN_TASKS.md`
- `docs/AI_HANDOFF/DECISIONS.md`
- `docs/AI_HANDOFF/NEXT_PROMPTS.md`
- `docs/API_SNAPSHOT/**`
- `docs/FIXTURE_INFRA_SPEC.md`
- `docs/TOOLING_BACKLOG.md`
- `docs/architecture/**`
- `docs/decision_engine/**`
- `docs/process/**`

## iOS Pending Migration Docs

- `docs/ios_shell_ci_gate.yml`
- `docs/IOS_PHASE_GATE_REVIEW.md`
- `docs/ios_gate_remediation_result.yml`
- `docs/ios_architecture_remediation_plan.yml`
- `docs/ios_boundary_violations.yml`

这些文档当前仍位于主仓，仅作为历史证据与迁移索引保留。
未来长期维护权属于 Reader-iOS，不属于 Reader-Core。

## Deprecated Docs

- `docs/ROADMAP_PHASE2.md`
- `docs/BRANCH_AUDIT_AND_PRUNE_REPORT.md`
- `docs/DEV_CHECKPOINT.md`
- `docs/design/**`
- `docs/dev_state/**`

## Archived Docs

- `archive/prompts/legacy/**`

## Rules

1. 当前主仓 docs 入口以 Reader-Core transition host 视角为准。
2. iOS gate / phase 文档不得再作为主仓当前主线文档。
3. iOS 历史证据保留，但语义为 pending migration。
4. deprecated docs 不再作为 active source。
5. archived docs 仅用于审计追溯。
