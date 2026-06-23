# Docs Split Index

## Status

```yaml
docs_split:
  status: historical_record
  current_docs_role: Reader-iOS primary docs host
  reverse_split_complete: true
  post_split_stabilization_audit: in_progress
  agent_prompt_governance_removed: true
  clean_room: true
```

## Current Active Docs

- `docs/PROJECT_STATUS.md`
- `docs/POST_SPLIT_STABILIZATION_AUDIT.md`

## Reader-iOS Mainline Docs

- `docs/IOS_PHASE_GATE_REVIEW.md`
- `docs/ios_gate_remediation_result.yml`
- `docs/ios_shell_ci_gate.yml`
- `docs/ios_architecture_remediation_plan.yml`
- `docs/ios_boundary_violations.yml`

## Historical Split Docs

- `docs/READER_IOS_BOOTSTRAP_PLAN.md`
- `docs/READER_IOS_DEPENDENCY_BOOTSTRAP.md`
- `docs/READER_IOS_MIGRATION_MANIFEST.md`
- `docs/READER_IOS_REPO_INIT_CHECKLIST.md`
- `docs/RS-005-SPLIT-EVIDENCE.md`

## Deprecated Docs

- `docs/BRANCH_AUDIT_AND_PRUNE_REPORT.md`
- `docs/DEV_CHECKPOINT.md`
- `docs/design/**`
- `docs/dev_state/**`

## Rules

1. 本仓 docs 主身份是 Reader-iOS 主仓，而不是 Reader-Core transition host。
2. split-era planning/bootstrap docs 仅保留历史语义，不再作为当前主线执行入口。
3. 旧 agent / prompt / handoff 配置已移除，不再作为项目文档入口维护。
4. active docs 入口必须反映 Reader-iOS 当前实现、构建、测试与发布状态。
