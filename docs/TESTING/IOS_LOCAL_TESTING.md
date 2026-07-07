# iOS Local Testing Guide

Scope: this guide covers the legacy SwiftPM targets under `iOS/`. App-level
SwiftUI / contract / reducer verification now uses the canonical Xcode project
commands recorded in `docs/frontend-complete-app/IOS_GAP_MATRIX.md`.

## Prerequisites

Reader-Core must be available as a sibling directory:

```
ln -s /path/to/Reader-Core "../Reader for iOS/Reader-Core"
```

Or the CI remote dependency in Package.swift.

## Recommended Verification Commands

Run from the `iOS/` directory:

```bash
cd iOS
```

### 1. ReaderAppSupport Build

```bash
swift build --target ReaderAppSupport
```

Verifies all 6 model files compile (BookshelfItem, ChapterCacheEntry, ReaderDisplaySettings,
ReadingProgress, SourceIdentity, ReaderAppSupportMarker).

### 2. ReaderAppPersistence Build

```bash
swift build --target ReaderAppPersistence
```

Verifies all 5 persistence stores compile (BookSourceStore, BookshelfStore, ChapterCacheStore,
ReaderSettingsStore, ReadingProgressStore).

### 3. ReaderShellValidation Build

```bash
swift build --target ReaderShellValidation
```

Verifies shell integration layer (CoreBridge, CoreIntegration, Shell) compiles.

### 4. Persistence Test Runner (RECOMMENDED for local dev)

```bash
swift run ReaderAppPersistenceTestRunner
```

Runs 36 persistence surface tests covering all 5 stores on real macOS. Uses temporary
directories — does not touch real app data.

Expected output:
```
PASS: loadSettings returns default when file missing
...
All persistence surface tests PASSED
```

Exit code 0 = all pass.

### 5. XCTest Target Build

```bash
swift build --target ReaderAppPersistenceTests
```

Builds the SwiftPM XCTest bundle for CI build checks. It does not replace
app-level XCTest execution; use the Xcode `build-for-testing` and
`test-without-building` commands in `docs/frontend-complete-app/IOS_GAP_MATRIX.md`
for current app tests.

### 6. ShellSmokeTests Build

```bash
swift build --target ShellSmokeTests
```

## Known Limitations

### SwiftPM full-package test is not the app-level gate

`swift test` exercises the SwiftPM package graph, not the canonical app scheme.
It can still fail or diverge from the Xcode app target because several app
surfaces are platform-specific.

Do not use `swift test` as the sole verification gate for the iOS app.

Use `swift run ReaderAppPersistenceTestRunner` for local persistence
verification, `swift build --target <name>` for individual SwiftPM target
verification, and the Xcode commands in `IOS_GAP_MATRIX.md` for app-level
build/test evidence.

### Current app-level gate

Current local app-level evidence is:
- `xcodebuild build ... ReaderForIOSApp ... ARCHS=arm64` PASS.
- `xcodebuild build-for-testing ... ReaderContractAdapterSlice0Tests ... ReaderReducerSlice1GoldenTests` PASS.
- `xcodebuild test-without-building ... ReaderContractAdapterSlice0Tests` PASS.
- `xcodebuild test-without-building ... ReaderReducerSlice1GoldenTests` PASS.

### Do not confuse evidence tiers

- `swift run ReaderAppPersistenceTestRunner` PASS → persistence stores work correctly
- app-level Xcode tests PASS → selected app/test bundle behavior is verified
- These are independent facts. Runner tests prove store correctness; they do
  not prove SwiftUI route, reducer, or Core bridge behavior.

## Boundary Check

```bash
cd ..
bash scripts/check_ios_boundary.sh
```

Should always PASS before committing.

## Target Dependency Graph

```
ReaderAppPersistenceTestRunner (exec)
  ├── ReaderAppPersistence
  │     ├── ReaderAppSupport
  │     └── ReaderCoreModels
  └── ReaderAppSupport

ShellSmokeTests (test)
  ├── ReaderShellValidation
  │     ├── ReaderAppSupport
  │     ├── ReaderCoreFoundation
  │     ├── ReaderCoreModels
  │     ├── ReaderCoreProtocols
  │     ├── ReaderCoreParser
  │     ├── ReaderCoreNetwork
  │     └── ReaderPlatformAdapters
  ├── ReaderAppSupport
  ├── ReaderCoreModels
  └── ReaderCoreProtocols
```
