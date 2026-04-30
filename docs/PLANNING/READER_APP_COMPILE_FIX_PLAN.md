# ReaderApp Target Compile Fix Plan

**Status**: WAVE1_COMPLETE
**Created**: 2026-04-30
**Last Updated**: 2026-04-30

---

## 1. Current State

| Target | Build | Notes |
|--------|-------|-------|
| ReaderAppSupport | PASS | 6 models, zero deps |
| ReaderAppPersistence | PASS | 5 stores, ReaderAppSupport + ReaderCoreModels |
| ReaderShellValidation | PASS | CoreBridge/CoreIntegration/Shell |
| ReaderAppPersistenceTestRunner | PASS 36/36 | executable runner |
| ReaderAppPersistenceTests | PASS (build) | XCTest target |
| **ReaderApp** | **FAILED** | ~45 errors across ~30 files |
| full swift test | BLOCKED | ReaderApp library product build required |

---

## 2. Error Inventory

### Category A: Missing Type/Import (5 errors, 5 files)

| # | File | Error | Root Cause |
|---|------|-------|------------|
| A1 | ChapterListViewModel.swift:45 | `ReaderCoreServiceProvider` not in scope | Missing `import ReaderShellValidation` |
| A2 | BookDetailViewModel.swift:40 | `ReaderCoreServiceProvider` not in scope | Missing `import ReaderShellValidation` |
| A3 | ReaderViewModel.swift:45 | `ReaderCoreServiceProvider` not in scope | Missing `import ReaderShellValidation` |
| A4 | SearchViewModel.swift:48 | `ReaderCoreServiceProvider` not in scope | Missing `import ReaderShellValidation` |
| A5 | BookDetailView.swift:13 | `SourceIdentityFactory` not in scope | Missing `import ReaderShellValidation` |

**Fix**: Add `import ReaderShellValidation` to each file. ReaderApp already depends on ReaderShellValidation in Package.swift.

### Category B: Platform Availability — iOS-only APIs on macOS (18 errors, 15 files)

| # | API | Files |
|---|-----|-------|
| B1 | `Color.platformSecondaryGroupedBackground` | ErrorView, LoadingView, ReaderEmptyStateView, ReaderFlowFeatureView, ReaderProgressSurfaceView, ReaderSessionSummaryView, ReaderStageActionBar, ReaderStatusCardView (8) |
| B2 | `Color.platformGroupedBackground` | ContentView (1) |
| B3 | `Color.platformTertiaryGroupedBackground` | ReaderStatusCardView (1) |
| B4 | `CGColor.secondarySystemBackground` | BookDetailView, BookSourceRowView, BookshelfItemRowView, SearchResultRowView (4) |
| B5 | `CGColor.systemBackground` | ReaderSettingsPanel (1) |
| B6 | `navigationBarTitleDisplayMode` | ReaderView, BookSourceImportView (2) |
| B7 | `navigationBarTrailing` | ReaderView (1) |
| B8 | `inlineNavigationBarTitle` | ContentView, TOCView (2) |
| B9 | `UIColor` | ReaderFlowFeatureView, AppEmptySurface, AppErrorSurface, AppLoadingSurface (4) |

**Fix options**:
- `#if os(iOS)` conditional compilation blocks
- Replace with cross-platform `Color(nsColor:)` / `Color(uiColor:)` alternatives
- Define macOS fallback for custom color extensions
- Use `.toolbar` placement alternatives (`topBarTrailing` for visionOS/macOS)

### Category C: Model/API Signature Mismatches (8 errors, 6 files)

| # | File | Error | Notes |
|---|------|-------|-------|
| C1 | ChapterRowView.swift:18 | `chapterIndex` not Optional | `if let` unwrap on non-optional `Int` |
| C2 | BookDetailView.swift:152 | `SearchResultItem.latestChapter` doesn't exist | Field removed from Reader-Core |
| C3 | BookDetailView.swift:222 | `SearchResultItem.latestChapter` doesn't exist | Same |
| C4 | BookshelfViewModel.swift:78 | `SearchResultItem.latestChapter` doesn't exist | Same |
| C5 | SearchResultRowView.swift:30 | `SearchResultItem.latestChapter` doesn't exist | Same |
| C6 | ReaderFlowFeatureView.swift:41,48 | `ReaderShellEnvironment.appEntry` doesn't exist | Member removed |
| C7 | ReaderView.swift:7 | `@Environment(\.dismiss)` type annotation | SwiftUI `Environment` vs ReaderCoreModels `Environment` ambiguity |

### Category D: Argument/Initializer Signature Mismatches (4 errors, 4 files)

| # | File | Error |
|---|------|-------|
| D1 | ReaderApp.swift:56 | Argument passed to call that takes no arguments |
| D2 | BookSourceListView.swift:40 | Argument passed to call that takes no arguments |
| D3 | ReaderFlowFeatureView.swift:29 | Argument passed to call that takes no arguments |
| D4 | ChapterListView.swift:130 | No exact matches in call to `append` |

### Category E: SwiftUI Conformance Requirements (3 errors, 3 files)

| # | File | Error |
|---|------|-------|
| E1 | SearchView.swift:19 | `navigationDestination` requires `SearchResultItem: Hashable` |
| E2 | ChapterListView.swift:23 | `navigationDestination` requires `TOCItem: Hashable` |
| E3 | SearchView.swift:31 | `Picker` requires `BookSource: Hashable` |

### Category F: Type Ambiguity (1 error, 1 file)

| # | File | Error |
|---|------|-------|
| F1 | ReaderView.swift:7 | `Environment` ambiguous — ReaderCoreModels.Environment vs SwiftUI.Environment |

---

## 3. Error Count Summary

| Category | Errors | Files | Difficulty | Recommended Approach |
|----------|--------|-------|-----------|---------------------|
| A: Missing Import | 5 | 5 | TRIVIAL | Add `import ReaderShellValidation` |
| B: Platform Availability | 18 | 15 | MEDIUM | `#if os(iOS)` or cross-platform fallbacks |
| C: Model/API Signature | 8 | 6 | MEDIUM | Align with Reader-Core API changes |
| D: Argument Mismatch | 4 | 4 | MEDIUM | Fix init call sites |
| E: SwiftUI Conformance | 3 | 3 | MEDIUM | Add Hashable conformance |
| F: Type Ambiguity | 1 | 1 | LOW | Qualify with module name |

---

## 4. Fix Strategy Comparison

### Plan A: Minimal Import/Dependency Fix Only

- Fix Category A (missing imports) — 5 files, trivial
- Does NOT fix platform/B/C/D/E/F
- **Result**: ReaderApp still fails (~40 errors remain)
- **Recommended**: NO (insufficient alone)

### Plan B: Import Fix + Platform Availability Guards

- Fix Category A (imports)
- Add `#if os(iOS)` guards for B errors, or cross-platform Color extensions
- Fix Category F (Environment ambiguity) with `SwiftUI.Environment`
- Leave C/D/E for separate planning
- **Result**: ~20-25 errors remain (C/D/E)
- **Risk**: LOW-MEDIUM (conditional compilation doesn't change iOS behavior)
- **Recommended**: YES as immediate next step

### Plan C: Full Fix (All Categories)

- Fix all ~45 errors across ~30 files
- Requires:
  - import fixes
  - platform guards or cross-platform abstractions
  - model alignment with Reader-Core (SearchResultItem, TOCItem, BookSource, Environment)
  - call site fixes
  - Hashable conformance additions
- **Risk**: HIGH — large blast radius, may introduce regressions
- **Recommended**: NOT in single round; break into sub-steps

---

## 5. Recommended Approach: Plan B

### Step 1: Fix Category A (missing imports) — 5 files

```
ChapterListViewModel.swift  → add import ReaderShellValidation
BookDetailViewModel.swift   → add import ReaderShellValidation
ReaderViewModel.swift       → add import ReaderShellValidation
SearchViewModel.swift       → add import ReaderShellValidation
BookDetailView.swift        → add import ReaderShellValidation
```

**Expected**: 5 errors eliminated.

### Step 2: Fix Category F (Environment ambiguity) — 1 file

```
ReaderView.swift → qualify @Environment as @SwiftUI.Environment
```

**Expected**: 1 error eliminated.

### Step 3: Platform guards for Category B — ~15 files

Use `#if os(iOS)` blocks for iOS-only APIs:

```swift
#if os(iOS)
.background(Color.platformSecondaryGroupedBackground)
#else
.background(Color(nsColor: .windowBackgroundColor))
#endif
```

Or define macOS-compatible extensions for `Color`:

```swift
extension Color {
    #if os(macOS)
    static let platformSecondaryGroupedBackground = Color(nsColor: .controlBackgroundColor)
    static let platformGroupedBackground = Color(nsColor: .windowBackgroundColor)
    #endif
}
```

### Step 4: Post-Plan B — Categories C/D/E require separate investigation

These errors likely stem from Reader-Core model changes that need to be reconciled:
- `SearchResultItem` lost `latestChapter` field
- `chapterIndex` changed from Optional to non-Optional
- `ReaderShellEnvironment` restructured
- `TOCItem`, `SearchResultItem`, `BookSource` missing Hashable conformance

---

## 6. Files NOT to Touch This Round

- `Reader-Core` (any file)
- `ReaderAppSupport/` (already PASS)
- `ReaderAppPersistence/` (already PASS)
- `CoreBridge/ReaderCoreServiceProvider.swift` (defines the type, not the problem)
- `CoreBridge/SourceIdentityFactory.swift` (correctly placed)

---

## 7. Verification Criteria

After Step 1-3:
- `swift build --target ReaderApp` → fewer errors, ideally 0 in categories A/B/F
- `swift build --target ReaderAppSupport` → still PASS
- `swift build --target ReaderAppPersistence` → still PASS
- `swift run ReaderAppPersistenceTestRunner` → still 36/36 PASS
- Boundary check → still PASS

---

## 8. Next Steps

1. Execute Plan B Step 1-3 (categories A, B, F)
2. Verify ReaderApp build error count reduction
3. Plan separate round for C/D/E (requires Reader-Core API investigation)
4. Goal: `swift build --target ReaderApp` PASS → `swift test` PASS

---

## 9. Rollback

- `git reset --hard 6fbf87a` restores pre-fix state

---

## Wave 1 Result (2026-04-30)

### Before: ~45 errors across ~30 files
### After: 15 errors across 12 files (67% reduction)

### Changes Made

| File | Change | Category |
|------|--------|----------|
| ChapterListViewModel.swift | +`import ReaderShellValidation` | A |
| BookDetailViewModel.swift | +`import ReaderShellValidation` | A |
| ReaderViewModel.swift | +`import ReaderShellValidation` | A |
| SearchViewModel.swift | +`import ReaderShellValidation` | A |
| BookDetailView.swift | +`import ReaderShellValidation` | A |
| ReaderView.swift | `@SwiftUI.Environment` qualifier + `#if os(iOS)` guard | F + B |
| BookSourceImportView.swift | `#if os(iOS)` guard for navigationBarTitleDisplayMode | B |
| Color+PlatformCompat.swift | NEW: macOS Color/UIColor/CGColor/View/ToolbarItemPlacement compat | B |

### Remaining Errors (all C/D/E — out of scope for Wave 1)

| Category | Errors | Files | Root Cause |
|----------|--------|-------|------------|
| C: Model mismatch | 5 | 4 files | `SearchResultItem.latestChapter` removed, `appEntry` removed |
| D: Argument mismatch | 5 | 4 files | Init signatures changed, `append` mismatch, `chapterIndex` type change |
| E: SwiftUI conformance | 4 | 3 files | `SearchResultItem`, `TOCItem`, `BookSource` missing `Hashable` |

### Verification

- `swift build --target ReaderAppSupport`: PASS
- `swift build --target ReaderAppPersistence`: PASS
- `swift build --target ReaderShellValidation`: PASS
- `swift run ReaderAppPersistenceTestRunner`: 36/36 PASS
- Boundary check: PASS (checked_files=52)
- `swift build --target ReaderApp`: 15 errors remain (all C/D/E)
