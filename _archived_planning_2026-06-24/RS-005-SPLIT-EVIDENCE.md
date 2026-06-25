# RS-005 Physical Repo Split — Evidence Index

## Execution Date

2026-04-14

## Split Status

```yaml
reader_ios_repo_initialized: true
physical_split_complete: true
```

## Reader-iOS Independent Repo

- Local path: `../Reader-iOS` (relative to this repo)
- Git initialized: yes
- Skeleton committed: pending first commit in Reader-iOS repo

## What Was Migrated

### Code

- `iOS/App/**` → `Reader-iOS/iOS/App/**`
- `iOS/CoreIntegration/**` → `Reader-iOS/iOS/CoreIntegration/**`
- `iOS/Features/**` → `Reader-iOS/iOS/Features/**`
- `iOS/Modules/**` → `Reader-iOS/iOS/Modules/**`
- `iOS/Shell/**` → `Reader-iOS/iOS/Shell/**`
- `iOS/Tests/**` → `Reader-iOS/iOS/Tests/**`
- `iOS/ValidationSupport/**` → `Reader-iOS/iOS/ValidationSupport/**`
- `iOS/Package.swift` → `Reader-iOS/iOS/Package.swift` (PATCHED)

### Docs

- `docs/IOS_PHASE_GATE_REVIEW.md`
- `docs/ios_gate_remediation_result.yml`
- `docs/ios_shell_ci_gate.yml`
- `docs/ios_architecture_remediation_plan.yml`
- `docs/ios_boundary_violations.yml`
- `docs/IOS_PENDING_MIGRATION_REGISTRY.md`
- `docs/READER_IOS_BOOTSTRAP_PLAN.md`
- `docs/READER_IOS_DEPENDENCY_BOOTSTRAP.md`
- `docs/READER_IOS_MIGRATION_MANIFEST.md`
- `docs/READER_IOS_REPO_INIT_CHECKLIST.md`

### Workflows & Scripts

- `.github/workflows/ios-shell-ci.yml` → `Reader-iOS/.github/workflows/ios-shell-ci.yml` (PATCHED)
- `scripts/check_ios_boundary.sh` → `Reader-iOS/scripts/check_ios_boundary.sh` (PATCHED)

## What Was Patched

### iOS/Package.swift

- Before: `.package(path: "../Core")`
- After: `.package(path: "../../Reader-for-iOS/Core")`
- Reason: iOS is now in a separate sibling repo; Core is in Reader-for-iOS/Core

### ios-shell-ci.yml

- Added: `Checkout Reader-Core (sibling)` step
- Added: `Symlink Reader-Core for local path resolution` step
- Reason: CI must resolve Reader-Core path dependency from independent Reader-iOS repo

### check_ios_boundary.sh

- Added: RS-005 migration note header comment
- Logic unchanged: repo_root resolves to Reader-iOS root, iOS/** paths remain valid

## What Is Retained In Reader-Core As History Pointers

- `iOS/**` — all source files retained, ownership transferred to Reader-iOS
- `docs/IOS_*` — retained as history pointers
- `docs/ios_*` — retained as history pointers
- `.github/workflows/ios-shell-ci.yml` — retained as history; active CI in Reader-iOS
- `scripts/check_ios_boundary.sh` — retained as history

## Post-Split Followup

- RS-005-FU-01: Publish Reader-Core as proper Swift package
- RS-005-FU-02: Update Reader-iOS Package.swift to URL-based dependency
- RS-005-FU-03: Simplify ios-shell-ci (remove symlink step)
- RS-005-FU-04: Rename Reader-for-iOS to Reader-Core

## Clean-Room Statement

- Clean-room maintained: yes
- External GPL code copied: no
- This migration only moved files between repos. No implementation was changed. No Legado Android source was copied.
