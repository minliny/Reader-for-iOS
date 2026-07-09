# iOS Complete App Gap Matrix

Status: `SLICE_0_1_REGISTRY_ADAPTERS_XCTEST_AND_APPSHELL_SCREENSHOT_PROVEN`

Date: 2026-07-04

Target repo: `/Users/minliny/Documents/Reader for iOS`

Parent matrix: `docs/frontend-complete-app/FRONTEND_COMPLETE_APP_GAP_MATRIX.md`

## 1. Purpose

This file turns the parent gap matrix into iOS-specific work. Current pass selected the canonical Xcode project/scheme, wired the generated Reader UI Swift contract into the XcodeGen graph, connected TokenAdapter/MotionAdapter to generated registries, and expanded Slice 0/1 reducer + adapter golden coverage. Focused build-for-testing passes, focused XCTest execution now passes through the existing `.xctestrun` artifact with `xcodebuild test-without-building`, and a Slice 1 native bookshelf AppShell screenshot is captured in-repo. Direct project `xcodebuild test` still blocks during package/test startup.

iOS must implement native SwiftUI UI. It must not ship `frontend-demo-optimized/` through WebView as the production app.

## 2. iOS Preflight

| Check | Current local evidence | Required result |
| --- | --- | --- |
| Repo exists | `/Users/minliny/Documents/Reader for iOS` exists. | Use this repo for iOS implementation evidence. |
| Canonical project/scheme | Selected `ReaderForIOS.xcodeproj` / scheme `ReaderForIOSApp`. `xcodebuild -list -project ReaderForIOS.xcodeproj` resolves packages `ReaderCore` and `Reader UI`. | Keep `ReaderForIOS.xcodeproj` generated from `project.yml`; do not use numbered project variants for Slice 0/1 evidence. |
| Swift contract package | `project.yml` packages: `ReaderUI` path `../Reader UI`; targets `ReaderForIOSApp`, `ReaderShellValidation`, and `ReaderAppTests` depend on product `ReaderUIContract`. `iOS/Package.swift` also depends on `../../Reader UI`. | Generated `RouteId`, `MainTab`, `UiEvent`, `Token`, `TokenRegistry`, `MotionId`, and `MotionSpecRegistry` compile in app/test code. |
| Build command | Passing app build: `xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES ARCHS=arm64`. | Use this as current local Slice 0/1 build command. Generic simulator build without `ARCHS=arm64` still fails because `ReaderCore.xcframework` lacks x86_64 simulator symbols. |
| Core adapter | `iOS/ReaderCoreNativeAdapter/ReaderCoreNativeRuntime.swift`, `iOS/CoreBridge/ReaderCoreBridge.swift`, and `iOS/ReaderCoreNativeAdapter/cabi/ReaderCore.xcframework` are present and compile for arm64 simulator. | Core bridge protocol mapping still needs Slice 2+ command/event coverage tests. |

## 3. Required iOS Files Or Equivalents

| Required role | Expected iOS landing | Acceptance |
| --- | --- | --- |
| Contract import | `project.yml` + `iOS/Package.swift` depend on `ReaderUIContract`; app files import generated types in `iOS/App/ReaderReducer.swift`, `iOS/App/ReaderViewState.swift`, `iOS/CoreBridge/ReaderCoreBridge.swift`. | RouteId, UiEvent, MainTab, Token, MotionId generated types compile in app/test code. |
| Reducer | `iOS/App/ReaderReducer.swift` | Slice 1 handles `UiEventType.mainTab_select`; full route/overlay/session/loading/focus rules remain P0 follow-up. |
| Coordinator | `iOS/App/ReaderCoordinator.swift`; existing app flow coordinator remains `iOS/CoreIntegration/ReadingFlowCoordinator.swift`. | Skeleton exists; Core/Host effect scheduling remains Slice 2+. |
| ViewState mapper | `iOS/App/ReaderViewState.swift`; `AppShellView.contractViewState` exposes the derived state. | Slice 1 maps active tab to generated `MainTab` and root `RouteId`; full ViewState consumption by screens remains incomplete. |
| Core bridge | `iOS/CoreBridge/ReaderCoreBridge.swift`; runtime adapter `iOS/ReaderCoreNativeAdapter/ReaderCoreNativeRuntime.swift`. | Compiles for arm64 simulator; full P0 command/event mapping tests remain incomplete. |
| Host Adapter | Existing host/runtime files under `iOS/CoreBridge/` and `iOS/ReaderCoreNativeAdapter/`; no single complete `HostAdapter.swift` facade yet. | Capability matrix still needs URLSession/WebView/Cookie/file/permission/TTS/background/share structured result proof. |
| Token Adapter | `iOS/Modules/Theme/ReaderTokenAdapter.swift`; existing native values in `iOS/Modules/Theme/ReaderDesignTokens.swift`. | Slice 1/P0 semantic token facade reads generated `TokenRegistry`, maps registry color/length/duration tokens, and is covered by focused tests. Full raw-value lint gate remains incomplete. |
| Motion Adapter | `iOS/Modules/Motion/ReaderMotionAdapter.swift`; existing motion runtime under `iOS/Modules/Motion/`. | P0 duration/reduced-motion facade reads generated `MotionSpecRegistry`, applies `forceZeroDuration`, and is covered by focused tests. Native recordings remain incomplete. |
| Evidence tests | `iOS/Tests/ReaderAppTests/ReaderContractAdapterSlice0Tests.swift`, `iOS/Tests/ReaderAppTests/ReaderReducerSlice1GoldenTests.swift`; manifest `docs/frontend-complete-app/evidence/IOS_SLICE1_EVIDENCE_2026-07-04.md`; screenshot `docs/frontend-complete-app/evidence/ios-slice1-evidence-2026-07-04.png`. | Build-for-testing evidence exists, focused `test-without-building` XCTest proof passes for generated contract reachability, registry-backed TokenAdapter/MotionAdapter, route stack, overlay/session mutex start, reduced-motion bridge, focus restore, and main Tab reducer, and the native bookshelf AppShell screenshot is captured in-repo. |

## 4. iOS P0 Matrix

| ID | Gap | Evidence to collect | Acceptance command or artifact |
| --- | --- | --- | --- |
| IOS-P0-01 | Canonical Xcode project chosen | `ReaderForIOS.xcodeproj`, scheme `ReaderForIOSApp`, package graph includes `Reader UI`. | PASS: `xcodebuild -list -project ReaderForIOS.xcodeproj`. |
| IOS-P0-02 | Contract dependency and registries XCTest-proven | `project.yml` target deps include `ReaderUIContract`; tests `testReaderUIPackageGeneratedTypesAreReachable`, `testTokenAdapterReadsGeneratedTokenRegistry`, `testMotionAdapterReadsGeneratedMotionSpecRegistry`. | PASS: selected arm64 simulator build-for-testing compiles generated types plus `TokenRegistry` / `MotionSpecRegistry`; `test-without-building` executes `ReaderContractAdapterSlice0Tests` with 5 tests and 0 failures. |
| IOS-P0-03 | AppShell + four main tabs source-proven, screenshot-proven for bookshelf shell | `iOS/App/AppShellView.swift`, `iOS/Navigation/AppTab.swift`, `iOS/App/Components/FloatingTabBar.swift`; `AppTab.contractOrder` = `bookshelf/discover/rss/settings`; `docs/frontend-complete-app/evidence/ios-slice1-evidence-2026-07-04.png`. | PASS for Slice 1 shell screenshot: reducer tests prove Tab state flow and main-tab route bridge, and the captured frame shows the native bookshelf AppShell. Still needs recordings and non-bookshelf route screenshots. |
| IOS-P0-04 | Reducer/coordinator skeleton XCTest-proven for Slice 1 | `iOS/App/ReaderReducer.swift`, `iOS/App/ReaderCoordinator.swift`, `iOS/App/ReaderViewState.swift`, `iOS/Navigation/AppNavigationState.swift`. | PARTIAL PASS: `ReaderReducerSlice1GoldenTests` executes through `test-without-building` with 17 tests and 0 failures, covering tab switch, route push/replace/pop, main-tab route bridge, overlay single-slot, activeSession mutex start, reducedMotion bridge, focus restore, and default ViewState. Loading guard remains open. |
| IOS-P0-05 | Bookshelf to immersive reading not proven | SwiftUI route, reducer transition, Core bridge call, recording. | Open book enters `immersive-reading`; back returns to source; repeated open is latest-intent-wins. |
| IOS-P0-06 | Reader control layer not proven | Reader surface and overlay code plus recording. | Control layer opens/hides without remounting reader context or changing text layout. |
| IOS-P0-07 | TokenAdapter registry-backed, raw literal gate incomplete | `iOS/Modules/Theme/ReaderTokenAdapter.swift`; tests `testTokenAdapterMapsSliceOneSemanticTokens`, `testTokenAdapterReadsGeneratedTokenRegistry`. | PARTIAL PASS: Slice 1 semantic color/size/duration tokens map through generated `TokenRegistry`. Full raw literal gate remains open. |
| IOS-P0-08 | MotionAdapter registry-backed, recordings incomplete | `iOS/Modules/Motion/ReaderMotionAdapter.swift`; tests `testMotionAdapterMapsP0TabAndReducedMotion`, `testMotionAdapterReadsGeneratedMotionSpecRegistry`. | PARTIAL PASS: `tab.switch` reads generated `MotionSpecRegistry` and applies `forceZeroDuration` for reduced motion. Full P0 recordings and long-tail native proof remain open. |
| IOS-P0-09 | Core bridge compiles but P0 mapping not proven | `iOS/CoreBridge/ReaderCoreBridge.swift`, `iOS/ReaderCoreNativeAdapter/ReaderCoreNativeRuntime.swift`. | PARTIAL: arm64 app build links bridge. Still needs UiEvent -> CoreCommand/HostRequest mapping tests and stale async discard proof. |
| IOS-P0-10 | Host Adapter not proven | Host adapter source and capability tests. | URLSession/WebView/Cookie/file/permission/TTS/background/share return structured results. |

## 5. iOS Route Implementation Matrix Template

| RouteId | Priority | SwiftUI owner | ViewState input | UiEvent output | Core/Host effect | MotionIds | Token groups | Tests/evidence | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bookshelf | P0 | `iOS/Features/Bookshelf/BookshelfView.swift` inside `AppShellView.rootView(for: .bookshelf)` | `ReaderViewState(routeId: .bookshelf)` for shell-level proof; screen still uses local models | `mainTab.select` via `ReaderReducer`; local actions still use existing navigation/coordinator paths | Core bookshelf snapshot pending | `tab.switch`, `tab.item.select`, bookshelf view switch pending | `ReaderTokenAdapter` + existing `ReaderDesignTokens` | `ReaderReducerSlice1GoldenTests`, `ReaderContractAdapterSlice0Tests` | Slice 1 partial |
| immersive-reading | P0 | `iOS/Features/Reader/ReaderView.swift`; entry state in `AppNavigationState.readerContext` | Local `ReaderContext`; generated ViewState mapping not complete | Existing `enterImmersiveReading` path; generated UiEvent mapping pending | content load/progress pending | `reader.entry.coverToImmersive`, `reader.page.turn.next-prev` adapter durations present; recording pending | reader typography/theme tokens partially present | build only | Pending Slice 2 |
| reader | P0 | `iOS/Features/Reader/ReaderView.swift`, `ReaderStageActionBar.swift`, `ReaderSettingsPanel.swift` | Local reader state; generated overlay/session state mapping pending | Existing view actions; generated UiEvent mapping pending | progress/session pending | reader control/module/session adapter durations present; behavior proof pending | reader control tokens partially present | build only | Pending Slice 3/4 |
| source-switch | P1 | `iOS/Features/Reader/ReaderSourceSwitchFlowView.swift` | Local models | Existing actions | source switch/search pending | `reader.sourceSwitch.open-close` duration mapped; behavior proof pending | source/reader tokens partial | build only | Pending Slice 5 |

## 6. Current Verification

| Command | Result |
| --- | --- |
| `xcodebuild -list -project ReaderForIOS.xcodeproj` | PASS. Resolves packages `ReaderCore` and `Reader UI`; scheme `ReaderForIOSApp` exists. |
| `xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` | FAIL. `ReaderCore.xcframework` lacks x86_64 simulator architecture; linker cannot resolve `_rc_abi_version`, `_rc_runtime_create`, `_rc_runtime_send`, `_rc_runtime_cancel`, `_rc_runtime_destroy`. |
| `xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES ARCHS=arm64` | PASS. App builds with `ReaderUIContract`, TokenAdapter, MotionAdapter, AppShell, Core bridge, and native SwiftUI code. |
| `xcodebuild build-for-testing -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES ARCHS=arm64 -only-testing:ReaderAppTests/ReaderContractAdapterSlice0Tests -only-testing:ReaderAppTests/ReaderReducerSlice1GoldenTests` | PASS. Focused app/test bundle compiles with registry-backed adapters and expanded reducer golden tests. |
| `xcodebuild test -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES ARCHS=arm64 -only-testing:ReaderAppTests/ReaderContractAdapterSlice0Tests` | DIRECT TEST STARTUP LIMITATION. A focused project test attempt timed out after 180 seconds at `Resolve Package Graph` before XCTest execution. Use the proven `build-for-testing` + `test-without-building` path below as the current local app test gate. |
| `xcodebuild test-without-building -xctestrun /Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Build/Products/ReaderForIOSApp_iphonesimulator26.5-arm64.xctestrun -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:ReaderAppTests/ReaderContractAdapterSlice0Tests` | PASS. Executed 5 tests, 0 failures. Result bundle: `/Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bbjjszvaumctdsaiyseiljdlzzdt/Logs/Test/Test-ReaderForIOSApp-2026.07.04_17-57-39-+0800.xcresult`. |
| `xcodebuild test-without-building -xctestrun /Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Build/Products/ReaderForIOSApp_iphonesimulator26.5-arm64.xctestrun -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:ReaderAppTests/ReaderReducerSlice1GoldenTests` | PASS. Executed 17 tests, 0 failures. Result bundle: `/Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-gwwmabpfnayntmbzcxyhalaogicv/Logs/Test/Test-ReaderForIOSApp-2026.07.04_17-58-01-+0800.xcresult`. |
| `xcrun simctl boot 'iPhone 17'`; `xcrun simctl install booted .../ReaderForIOSApp.app`; `xcrun simctl launch booted com.reader.ios`; `xcrun simctl io booted screenshot docs/frontend-complete-app/evidence/ios-slice1-evidence-2026-07-04.png` | PASS for Slice 1 AppShell screenshot. The booted iPhone 17 simulator produced a 2,274,799-byte PNG showing the native bookshelf AppShell. Evidence recorded in `docs/frontend-complete-app/evidence/IOS_SLICE1_EVIDENCE_2026-07-04.md`. |

## 7. iOS Acceptance Minimum

iOS cannot be marked frontend-complete until:

1. One canonical project/scheme is selected and builds.
2. It compiles against Reader UI generated Swift contract types.
3. Reducer/coordinator tests pass for P0 state rules.
4. P0 SwiftUI screens render from ViewState or lossless mapped contract DTOs.
5. TokenAdapter and MotionAdapter are present and tested.
6. Core bridge and Host Adapter are connected for first vertical slices.
7. Simulator or device evidence exists for AppShell, reading entry, reader control layer, overlay/focus, session capsule, and orientation.
