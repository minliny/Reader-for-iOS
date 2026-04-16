# Reader-iOS Migration Manifest

## Purpose

- 记录 RS-005 首批必须迁移到 Reader-iOS 的资产。

## Usage Timing

- 当前使用时机：`RS-004`
- 实际执行时机：`RS-005`

## Historical Status

- future destination 已执行：`Reader-iOS/docs/READER_IOS_MIGRATION_MANIFEST.md`
- 当前状态：`historical split record retained in Reader-iOS repo`

## Code To Move

- `iOS/App/**`
- `iOS/CoreIntegration/**`
- `iOS/Features/**`
- `iOS/Modules/**`
- `iOS/Shell/**`
- `iOS/Tests/**`
- `iOS/ValidationSupport/**`
- `iOS/Package.swift`

## Docs To Move

- `docs/IOS_PHASE_GATE_REVIEW.md`
- `docs/ios_gate_remediation_result.yml`
- `docs/ios_shell_ci_gate.yml`
- `docs/ios_architecture_remediation_plan.yml`
- `docs/ios_boundary_violations.yml`
- `docs/IOS_PENDING_MIGRATION_REGISTRY.md`

## Workflows And Scripts To Move

- `.github/workflows/ios-shell-ci.yml`
- `scripts/check_ios_boundary.sh`

## Bridge Or Later Items

- `docs/DOCS_SPLIT_INDEX.md` reader-ios references
- Reader-Core history pointers / redirect notes
- migrated artifact link index if RS-005 needs stable evidence landing pages

## Constraints

- 本文档不表示上述资产已迁移。
- 所有历史执行证据必须保留。
- 迁移后维护权归 Reader-iOS，历史指针仍保留在 Reader-Core。
