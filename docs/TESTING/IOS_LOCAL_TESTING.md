# iOS Local Testing Guide

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

Builds the XCTest test bundle (for CI use). Does NOT run tests (blocked by ReaderApp).

### 6. ShellSmokeTests Build

```bash
swift build --target ShellSmokeTests
```

## Known Limitations

### full swift test is BLOCKED

`swift test` builds the `ReaderApp` library product, which has pre-existing compile errors
(`ReaderCoreServiceProvider` scope, platform availability, `UIColor`/`CGColor` references).

**Do NOT use `swift test` as the sole verification gate** until ReaderApp target compile
errors are fixed.

**Workaround**: Use `swift run ReaderAppPersistenceTestRunner` for local persistence
verification, and `swift build --target <name>` for individual target verification.

### When full swift test will be available

After ReaderApp target compile errors are resolved:
- `ReaderCoreServiceProvider` not found in scope
- `navigationBarTitleDisplayMode` unavailable on macOS
- `CGColor.secondarySystemBackground` iOS-only
- `UIColor` iOS-only
- `SearchResultItem` members

### Do NOT confuse runner pass with full swift test pass

- `swift run ReaderAppPersistenceTestRunner` PASS → persistence stores work correctly
- `swift test` FAIL → ReaderApp library product has pre-existing compile errors
- These are independent facts. Runner tests prove store correctness. full swift test fail
  is a separate ReaderApp target issue.

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
