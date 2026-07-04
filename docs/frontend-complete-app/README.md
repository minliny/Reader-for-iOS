# iOS Frontend Complete App Development Entry

Status: `LOCAL_DEVELOPMENT_ENTRY`

Date: 2026-07-04

This directory is the iOS-local entry for frontend complete-app work. It contains the migrated planning docs needed to develop this repo independently from the Reader UI repo.

## Documents

- `FRONTEND_COMPLETE_APP_GAP_MATRIX.md` — cross-repo parent matrix copied from Reader UI for local context.
- `IOS_GAP_MATRIX.md` — iOS-specific implementation and evidence matrix.
- `CONTRACT_FIRST_NATIVE_UI_PLAN.md` — shared architecture plan snapshot for local iOS development.
- `ARCHITECTURE.md` — frozen Contract-first Native UI architecture snapshot.
- `BOUNDARY_RULES.md` — allowed/forbidden layer and repository dependency rules.
- `STATE_OWNERSHIP.md` — DomainState / UiState / EphemeralState ownership rules.
- `CONTRACT_VERSIONING.md` and `VERSION.json` — UI Contract versioning snapshot.
- `ACCEPTANCE.md` — Reader UI contract acceptance baseline and remaining cross-repo gates.
- `ffi-protocol-version.md` — FFI protocol shape snapshot.
- `handoff/` — route, screen, state, slice, evidence, and motion platform mapping snapshots.
- `motion/` — demo motion contract, effects, selector matrix, and motion gap/audit snapshots.

Reader UI remains the upstream contract/schema/codegen source. Files in this directory are local development references so iOS work can proceed from this repository without relying on external prose.

## iOS Ownership

This repo owns native SwiftUI implementation and iOS platform behavior:

- SwiftUI AppShell, routes, reader surface, overlays, sheets, dialogs, and screen components.
- Swift reducer/coordinator for durable UI state and navigation.
- iOS TokenAdapter and MotionAdapter that consume Reader UI contract artifacts.
- Reader-Core-Native bridge wiring for business commands/events.
- iOS Host Adapter for URLSession, WKWebView, Cookie, file, permission, AVSpeechSynthesizer, background, share, and notification capabilities.
- XCTest/simulator/device evidence proving native behavior.

This repo does not own Reader UI schema/codegen source or Core business truth. Bookshelf, RSS subscriptions/articles, persisted search history, content/progress, TTS queue planning, and sync conflict logic must come from Reader-Core-Native through the bridge unless the local matrix explicitly marks a state as ephemeral.

## Development Order

1. Select one canonical Xcode project, target, and scheme, then record the build command in `IOS_GAP_MATRIX.md`.
2. Wire generated Reader UI Swift contracts into the selected target.
3. Implement or audit reducer/coordinator behavior against P0 state rules.
4. Implement TokenAdapter and MotionAdapter before broad screen migration.
5. Connect first vertical slices through Reader-Core-Native bridge and Host Adapter.
6. Attach reducer tests, SwiftUI/snapshot evidence, and simulator/device artifacts to each completed row.

## Completion Bar

iOS frontend work is not complete until `IOS_GAP_MATRIX.md` has concrete source paths, test commands, and evidence artifacts for every P0 row. A browser/static demo screenshot is not valid iOS completion evidence.
