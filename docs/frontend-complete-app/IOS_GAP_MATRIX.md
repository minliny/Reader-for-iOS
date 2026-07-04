# iOS Complete App Gap Matrix

Status: `AUDIT_TEMPLATE_PENDING_IOS_CODE_EVIDENCE`

Date: 2026-07-04

Target repo: `/Users/minliny/Documents/Reader for iOS`

Parent matrix: `docs/frontend-complete-app/FRONTEND_COMPLETE_APP_GAP_MATRIX.md`

## 1. Purpose

This file turns the parent gap matrix into iOS-specific work. It is not yet a final iOS audit because this pass did not select a canonical Xcode project, inspect every SwiftUI view, reducer, adapter, test, or simulator artifact.

iOS must implement native SwiftUI UI. It must not ship `frontend-demo/` through WebView as the production app.

## 2. iOS Preflight

| Check | Current local evidence | Required result |
| --- | --- | --- |
| Repo exists | `/Users/minliny/Documents/Reader for iOS` exists. | Use this repo for iOS implementation evidence. |
| Multiple projects exist | `ReaderForIOS.xcodeproj` and numbered project variants exist. | Choose one canonical build target before auditing or implementing. |
| Swift package entry exists | `iOS/Package.swift` exists; Reader UI has contract-only `Package.swift`. | iOS must consume Reader UI generated Swift types through a stable package or generated artifact path. |
| Core adapter hint exists | `iOS/ReaderCoreNativeAdapter/README.md` exists. | Core bridge audit must confirm actual Swift adapter code and protocol mapping. |

## 3. Required iOS Files Or Equivalents

| Required role | Expected iOS landing | Acceptance |
| --- | --- | --- |
| Contract import | `ReaderUIContract` generated Swift package or equivalent | RouteId, UiEvent, UiState, ViewState, MotionId, Token types compile in app code. |
| Reducer | `ReaderReducer.swift` / `ReaderUiReducer.swift` | Owns route, overlay, activeSession, focus, loading, async guard. |
| Coordinator | `ReaderCoordinator.swift` | Owns NavigationStack/path, sheet/dialog routing, and Core/Host effect scheduling. |
| ViewState mapper | `ReaderViewStateMapper.swift` | SwiftUI views render ViewState or a lossless mapped model. |
| Core bridge | `ReaderCoreBridge.swift` | Maps reducer effects to Reader-Core-Native FFI/protocol. |
| Host Adapter | `HostAdapter.swift` | Owns URLSession, WebView, Cookie, file, permission, system TTS, background tasks, share, notification. |
| Token Adapter | `ReaderTokenAdapter.swift` / SwiftUI environment | Uses generated token registry and theme values. |
| Motion Adapter | `ReaderMotionAdapter.swift` | Maps MotionId/MotionSpec to SwiftUI transitions, animation, matched geometry where legal, and reduced motion. |
| Evidence tests | XCTest, snapshot tests, simulator recordings | Proves native behavior, not browser demo behavior. |

## 4. iOS P0 Matrix

| ID | Gap | Evidence to collect | Acceptance command or artifact |
| --- | --- | --- | --- |
| IOS-P0-01 | Canonical Xcode project not chosen | Selected `.xcodeproj` / package target and scheme. | `xcodebuild -list` and build command documented for the selected target. |
| IOS-P0-02 | Contract dependency not proven | Swift package dependency and imports of generated Swift types. | Selected target builds while using `ReaderUIContract`. |
| IOS-P0-03 | AppShell + four main tabs not proven | SwiftUI source and simulator screenshot/recording. | Main tabs are native and tab switch does not push NavigationStack. |
| IOS-P0-04 | Reducer/coordinator not proven | Reducer/coordinator source and XCTest. | Tests cover route stack, overlay mutex, activeSession mutex, loading guard, focus restore. |
| IOS-P0-05 | Bookshelf to immersive reading not proven | SwiftUI route, reducer transition, Core bridge call, recording. | Open book enters `immersive-reading`; back returns to source; repeated open is latest-intent-wins. |
| IOS-P0-06 | Reader control layer not proven | Reader surface and overlay code plus recording. | Control layer opens/hides without remounting reader context or changing text layout. |
| IOS-P0-07 | TokenAdapter not proven | Swift token adapter and snapshot tests. | Contract-owned SwiftUI uses semantic tokens, not copied literal values. |
| IOS-P0-08 | MotionAdapter not proven | Motion adapter and recordings/tests. | P0 MotionIds map to native SwiftUI motion; `UIAccessibility.isReduceMotionEnabled` is honored. |
| IOS-P0-09 | Core bridge not proven | FFI/protocol mapping tests. | P0 UiEvents emit CoreCommand/HostRequest and stale async results are discarded. |
| IOS-P0-10 | Host Adapter not proven | Host adapter source and capability tests. | URLSession/WebView/Cookie/file/permission/TTS/background/share return structured results. |

## 5. iOS Route Implementation Matrix Template

| RouteId | Priority | SwiftUI owner | ViewState input | UiEvent output | Core/Host effect | MotionIds | Token groups | Tests/evidence | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bookshelf | P0 | TBD | TBD | TBD | Core bookshelf snapshot | tab/app route | app shell, bookshelf cards | TBD | Pending audit |
| immersive-reading | P0 | TBD | TBD | TBD | content load/progress | reader entry, page turn | reader typography/theme | TBD | Pending audit |
| reader | P0 | TBD | TBD | TBD | progress/session | reader control, module switch | reader control tokens | TBD | Pending audit |
| source-switch | P1 | TBD | TBD | TBD | source switch/search | source overlay | source/reader tokens | TBD | Pending audit |

## 6. iOS Acceptance Minimum

iOS cannot be marked frontend-complete until:

1. One canonical project/scheme is selected and builds.
2. It compiles against Reader UI generated Swift contract types.
3. Reducer/coordinator tests pass for P0 state rules.
4. P0 SwiftUI screens render from ViewState or lossless mapped contract DTOs.
5. TokenAdapter and MotionAdapter are present and tested.
6. Core bridge and Host Adapter are connected for first vertical slices.
7. Simulator or device evidence exists for AppShell, reading entry, reader control layer, overlay/focus, session capsule, and orientation.
