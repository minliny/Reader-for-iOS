# Reader-iOS Repo Init Checklist

## Purpose

- 提供 `RS-005 Physical Repo Split Execution` 的直接执行 checklist。

## Usage Timing

- 当前使用时机：`RS-004`
- 实际执行时机：`RS-005`

## Historical Status

- future destination 已执行：`Reader-iOS/docs/READER_IOS_REPO_INIT_CHECKLIST.md`
- 当前状态：`historical split record retained in Reader-iOS repo`

## Checklist

1. create `Reader-iOS` repository
2. initialize `README.md`, `AGENTS.md`, `docs/`, `docs/AI_HANDOFF/`, `.github/workflows/`, `scripts/`
3. migrate `iOS/**` and `iOS/Package.swift`
4. migrate iOS docs listed in `docs/READER_IOS_MIGRATION_MANIFEST.md`
5. migrate `ios-shell-ci.yml` and `check_ios_boundary.sh`
6. configure Reader-Core dependency using validated public products
7. patch workflow checkout and package reference assumptions
8. verify `ios-shell-ci` green baseline in Reader-iOS
9. verify docs/handoff landing pages in Reader-iOS
10. leave history pointers and migration notes in Reader-Core

## Done Definition

- `reader_ios_repo_initialized = true`
- `physical_split_complete = true`
- Reader-iOS bootstrap docs are present in the new repo
- Reader-iOS builds and tests against Reader-Core dependency
- Reader-Core retains history pointers for migrated iOS evidence

## Risks

- same-repo path assumptions break workflow execution until patched
- artifact / evidence links may lose discoverability if history pointers are omitted
- version drift if Reader-Core dependency starts on floating refs before validated tags are used
