# Prompt Governance

## Status

```yaml
prompt_governance:
  era: split
  current_repo_role: Reader-Core transition host
  current_host_repo_should_converge_to: Reader-Core
  future_independent_repo: Reader-iOS
  planning_complete: true
  logical_split_complete: false
  physical_split_complete: false
  clean_room: true
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

## Deprecated Prompt Set

- `docs/ROADMAP_PHASE2.md`
- 历史 pre-split / early iOS gate 接手提示词
- `docs/AI_HANDOFF/NEXT_PROMPTS.md`
- `docs/AI_HANDOFF/DECISIONS.md`

## Archived Prompt Root

- `archive/prompts/legacy/`

## Governance Rules

1. 当前主仓 prompt 不得继续引导新的 iOS feature expansion。
2. 当前主仓 prompt 不得把 iOS phase/gate 作为长期主线状态。
3. 当前 prompt 必须明确：iOS 资产仍在仓内，但归属语义为 `pending migration`。
4. Reader-iOS future repo 必须拥有独立 prompt set。
5. Reader-iOS 未来只能依赖 Reader-Core public package/products。
6. 任何带有旧主线、旧阶段、旧轨道或旧 iOS feature 续推语义的 legacy prompt，不得作为 active prompt 使用。
7. 重要历史 prompt 必须归档，不得无痕删除。

## Lockdown Rules

```yaml
lockdown:
  mode: strict
  active_chain_only: true
  fail_on_legacy_marker_reference: true
  legacy_marker_classes:
    - legacy_strategy_marker
    - legacy_shell_sequence_marker
    - legacy_phase_marker
    - legacy_tooling_track_marker
    - legacy_phase_gate_marker
    - legacy_ios_milestone_marker
  current_phase_family: RS
  forbidden_output_semantics_when_phase_is_rs:
    - pre_split_feature_phase
    - legacy_phase_mainline
    - track_d_next_step
    - m_ios_next_step
  failure_action: "abort current prompt path and rebuild context from AGENTS.md -> docs/PROMPT_GOVERNANCE.md -> docs/PROJECT_CONTEXT_PROMPT.md -> docs/AI_HANDOFF.md only"
```

## Audit Policy

```yaml
audit:
  preserve_history: true
  delete_without_trace: false
  archive_before_rewrite: true
  legacy_prompt_archive_root: archive/prompts/legacy
  archive_is_not_active_path: true
```
