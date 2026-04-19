# AI Governance README

## 1. Scope

This document defines the local governance baseline for AI-assisted work in this repository.

## 2. Repository Role

- repo_role: Reader-iOS

## 3. Current Execution State

- phase: post_split_stabilization_audit
- execution_mode: audit_only

## 4. Single Source of Truth

The single source of truth for active project state is `docs/PROJECT_STATE_SNAPSHOT.yaml`.

## 5. Clean-Room Constraints

All AI output must follow clean-room constraints and must not carry over external GPL code.

## 6. AI Output Rules

AI output must remain executable, scoped, and aligned with repository governance.

## 7. Compatibility & Sample Binding Rules

Compatibility-affecting work must stay bound to sample, expected, and matrix assets when applicable.

## 8. Current Scope Boundaries

This phase is limited to audit, CI, boundary, dependency, and governance stabilization work.

## 9. PR Output Contract

PR output must include scope, expected result, regression summary, and clean-room statement.

## 10. Governance Writeback Rules

Governance writeback must preserve repository state consistency and avoid semantic drift.

## 11. Merge Gate for Governance Docs

Governance docs must remain internally consistent and must not conflict with the active state snapshot.

## 12. Change Classification

## 12A. Insert Validation Marker

```yaml
insert_validation:
  status: success
  purpose: verify_insert_after_anchor_behavior
  anchor: "## 12. Change Classification"
  file_target: docs/AI_GOVERNANCE/README.md
  compatibility_impact: none
  compat_matrix_updated: false
  new_failure_type: false
  manual_sample_needed: false
  clean_room_statement: no_external_gpl_code_carried_over
```

Changes to governance docs must be incremental, reviewable, and anchored to current repository state.

## 13. PR Output

Governance-only changes must not be represented as compatibility logic changes.

## Appendix A. Append Validation Marker

```yaml
append_validation:
  status: success
  purpose: verify_append_behavior
  file_target: docs/AI_GOVERNANCE/README.md
  compatibility_impact: none
  compat_matrix_updated: false
  new_failure_type: false
  manual_sample_needed: false
  clean_room_statement: no_external_gpl_code_carried_over
```
