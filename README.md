# Reader for iOS

Reader for iOS is the SwiftUI native host app for the Reader multi-end architecture.

## Current architecture role

This repo owns the iOS native experience. It must consume shared contracts and Core protocol, but it must not become the source of cross-platform business logic.

Architecture direction:

```text
Reader UI Contract
  -> generated Swift route / state / event / motion / token / view-state types

Reader for iOS
  -> SwiftUI Native UI
  -> Swift reducer/coordinator
  -> Reader-Core-Native bridge
  -> iOS Host Adapter

Reader-Core-Native
  -> business source of truth
```

## Responsibilities

This repo owns:

- SwiftUI rendering and native iOS interaction quality.
- iOS navigation/coordinator and `ViewState` rendering.
- Swift reducer for `navigation`、`readerMode`、`overlay`、`activeSession`、
  `focusTarget`、`loading/error`、`async guard`、`reducedMotion`。
- Reader-Core-Native bridge through the stable Core protocol.
- iOS Host Adapter for URLSession、WKWebView、Cookie、Keychain、file access、
  AVSpeechSynthesizer、notification、background task and permission flows.
- iOS device/simulator evidence for the shared reader slices.

This repo does not own:

- Book/source parsing business rules.
- Canonical reading progress semantics.
- Sync conflict strategy.
- Cross-platform UI schema.
- Android or HarmonyOS interaction behavior.

## Modification direction

1. Consume Reader UI Contract generated Swift types when schema/codegen lands.
2. Keep platform-specific temporary visual state local to SwiftUI views.
3. Move durable UI state into a Swift reducer/coordinator.
4. Route Core-owned operations through Reader-Core-Native bridge.
5. Route platform capabilities through Host Adapter, not individual pages.
6. Add reducer golden tests and device/simulator smoke evidence per shared slice.

Primary shared plan:

- `../Reader UI/contracts/CONTRACT_FIRST_NATIVE_UI_PLAN.md`

Current local status entry:

- `docs/PROJECT_STATUS.md`
