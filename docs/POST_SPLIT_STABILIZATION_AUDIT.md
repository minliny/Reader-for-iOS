# Post-Split Stabilization Audit

## Purpose

- 审计 Reader-Core / Reader-iOS 反向拆仓后的长期稳态。
- 仅记录结构、依赖、CI、boundary gate、文档语义问题。

## Audit Scope

- Batch 1: Reader-Core standalone audit
- Batch 2: Reader-iOS dependency strategy audit
- Batch 3: boundary gate hardening
- Batch 4: docs semantic audit
- Batch 5: CI audit

## Audit Date

- 2026-04-15

## Findings Summary

- Reader-Core fresh clone can be obtained independently.
- Reader-Core latest CI is not green; `Reader Core Swift Tests` failed on GitHub Actions.
- Reader-iOS still used path dependency as the active integration mode.
- Reader-iOS ios-shell-ci had a broken checkout path outside workspace.
- Reader-iOS docs still contained transition-host semantics after reverse split.

## Fixes Applied In This Repo

- Patched `ios-shell-ci.yml` checkout path from outside-workspace to workspace-local `Reader-Core`.
- Hardened `scripts/check_ios_boundary.sh` against Core asset reintroduction and legacy path references.
- Rewrote Reader-iOS status/governance docs away from `Reader-Core transition host` semantics.

## Non-local Findings

- Reader-Core standalone CI/test failures require fixes in the Reader-Core repo.
- Reader-iOS should migrate from path dependency to remote package dependency once Reader-Core release flow is stable.
