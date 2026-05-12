# Reader for iOS — Legado Parity App-Side Roadmap

Generated: 2026-05-12T23:55+08:00
Based on: Actual repository state audit (READ-ONLY, no code changes)

---

## Overview

This roadmap defines the app-side stages for Reader for iOS to reach Legado feature parity. It covers iOS-specific UI, persistence, platform integration, and Core API consumption. Core parser/runtime implementation is OUT OF SCOPE — that is Reader-Core's responsibility.

---

## Stage iOS-0: Repository Baseline Audit

**Status: DONE_CANDIDATE** (this audit completes it)

### Objectives
- Confirm Reader for iOS repository structure
- Confirm iOS/Package.swift exists
- Confirm Reader-Core dependency declaration
- Confirm public API import paths
- Confirm test entrypoints
- Confirm CI or local build status

### Deliverables
- [x] Repository structure documented (iOS/App, iOS/Features, iOS/CoreBridge, iOS/CoreIntegration, iOS/Shell, iOS/Tests, iOS/AppSupport)
- [x] Package.swift reviewed (5 targets, 6 Core product dependencies)
- [x] project.yml reviewed (4 targets, 6 Core product dependencies)
- [x] Test targets identified (ShellSmokeTests, ReaderAppPersistenceTests, ReaderAppPersistenceTestRunner)
- [x] CI workflow exists (.github/workflows/ios-shell-ci.yml)
- [x] Build attempted — xcodebuild FAILED (Core-side issue)

### Core Dependency
- ReaderCoreModels, ReaderCoreProtocols, ReaderCoreFoundation, ReaderCoreParser, ReaderCoreNetwork, ReaderPlatformAdapters

### Acceptance
- All repository structure facts documented
- Dependency graph clear
- Build failures understood and attributed

---

## Stage iOS-1: Core Integration Boundary

**Status: IN_PROGRESS** (CoreBridge exists, boundary PASS, but real Core not wired)

### Objectives
- Use only Reader-Core public API
- Establish ReaderCoreBridge / CoreService / DTO mapper
- Forbid Parser internals leakage
- Establish boundary check script
- Establish integration error mapping
- Establish smoke tests

### Deliverables
- [x] CoreBridge layer (ReaderCoreServiceProvider, MockReaderCoreService, AppReaderError, LoadState, SourceIdentityFactory)
- [x] CoreIntegration layer (DefaultBookSourceDecoder, DefaultSearchService, DefaultContentService, DefaultTOCService, InMemoryBookSourceRepository, ReadingFlowCoordinator)
- [x] Boundary check script (scripts/check_ios_boundary.sh) — PASS
- [x] Boundary violations document (docs/ios_boundary_violations.yml) — resolved
- [x] Integration error mapping (AppReaderError codes)
- [ ] Real Core service wired (BLOCKED by Core build)
- [ ] smoke tests passing (BLOCKED by Package.swift sibling path)
- [ ] ShellSmokeTests verified (BLOCKED by Package.swift sibling path)

### Core Dependency
- ReaderCoreModels (DTO types), ReaderCoreProtocols (service contracts)

### Acceptance
- `scripts/check_ios_boundary.sh` PASS ✓
- No ReaderCoreParser/Network/Cache/Execution imports in restricted paths ✓
- Real Core service buildable and callable from iOS ✗ (BLOCKED)
- Smoke tests pass ✗ (BLOCKED)

---

## Stage iOS-2: App Shell and Navigation

**Status: DONE_CANDIDATE** (shell exists with navigation)

### Objectives
- Establish minimal SwiftUI App shell
- Bookshelf / Search / Discovery / Settings / Reader page routing
- No real network dependency
- Use mock data or Core fixture DTO

### Deliverables
- [x] ReaderApp.swift (App entry point)
- [x] AppNavigationState.swift
- [x] Route.swift (navigation routes)
- [x] ReaderShellEnvironment.swift
- [x] ShellAssembly.swift (dependency injection)
- [x] Surface layer (AppEmptySurface, AppErrorSurface, AppLoadingSurface)
- [x] Common UI (ErrorView, LoadingView, ReaderEmptyStateView)

### Core Dependency
- ReaderCoreModels (for route parameter types)

### Acceptance
- App shell compiles and navigates between tabs
- Routes defined for all main screens
- Mock data drives all screens

---

## Stage iOS-3: Bookshelf MVP

**Status: IN_PROGRESS** (UI exists, persistence exists, mock-driven)

### Objectives
- Local bookshelf list
- Book metadata display
- Recently read tracking
- Reading progress display
- Local persistence
- Core book DTO mapping

### Deliverables
- [x] BookshelfView.swift + BookshelfViewModel.swift
- [x] BookshelfItemRowView.swift
- [x] BookshelfStore.swift (persistence)
- [x] ReadingProgressStore.swift (persistence)
- [x] BookshelfItem.swift (AppSupport model)
- [x] ReadingProgress.swift (AppSupport model)
- [ ] Real book data from Core (BLOCKED)
- [ ] Add-to-bookshelf from search results (not implemented)

### Core Dependency
- ReaderCoreModels (BookSource metadata types)

### Acceptance
- Bookshelf shows mock books with progress
- Persistence layer stores and retrieves books
- Progress updates persist across app restarts (tested)
- ~~Real book data~~ (deferred to Core integration)

---

## Stage iOS-4: Source Management MVP

**Status: IN_PROGRESS** (UI exists, import UI exists)

### Objectives
- Book source list
- Book source import (JSON)
- Book source enable/disable
- Book source grouping
- Call Core public validation
- Do NOT implement parser

### Deliverables
- [x] BookSourceListView.swift + BookSourceViewModel.swift
- [x] BookSourceRowView.swift
- [x] BookSourceImportView.swift
- [x] BookSourceStore.swift (persistence)
- [x] DefaultBookSourceDecoder.swift
- [x] InMemoryBookSourceRepository.swift
- [ ] Core public validation call (BLOCKED by Core build)
- [ ] Real JSON book source import validated (BLOCKED)

### Core Dependency
- ReaderCoreModels (BookSource type)
- ReaderCoreProtocols (validation protocol)
- Core public validation function (TBD)

### Acceptance
- Book source list renders
- JSON import UI works
- Enable/disable toggle works
- ~~Real Core validation~~ (deferred)
- NO parser implementation in iOS

---

## Stage iOS-5: Search / Detail / TOC / Content Flow

**Status: IN_PROGRESS** (all screens exist, mock-driven)

### Objectives
- Search page with keyword input
- Search results list
- Book detail page
- Chapter list (TOC) page
- Content reading page
- Error handling per stage
- Loading states
- Uses Core facade (mock currently)

### Deliverables
- [x] SearchView.swift + SearchViewModel.swift + SearchResultRowView.swift
- [x] BookDetailView.swift + BookDetailViewModel.swift
- [x] ChapterListView.swift + ChapterListViewModel.swift + ChapterRowView.swift
- [x] ContentView.swift + ReaderContentSectionView.swift
- [x] ReadingFlowCoordinator.swift (orchestrates flow)
- [x] DefaultSearchService, DefaultTOCService, DefaultContentService (mock adapters)
- [ ] Real Core search/detail/TOC/content (BLOCKED)

### Core Dependency
- ReaderCoreModels (SearchResultItem, TOCItem, ContentPage)
- ReaderCoreProtocols (SearchService, TOCService, ContentService)
- Real Core search/toc/content pipeline (TBD)

### Acceptance
- Search → results → detail → TOC → content flow works with mock data
- Error states render correctly
- Loading states render correctly
- ~~Real network flow~~ (deferred)

---

## Stage iOS-6: Reader Page MVP

**Status: IN_PROGRESS** (Reader UI exists, settings panel exists)

### Objectives
- Content display
- Font / background / line spacing basic settings
- Scroll reading
- Basic chapter switching
- Local reading progress save
- Progress update on return to bookshelf

### Deliverables
- [x] ReaderView.swift + ReaderViewModel.swift
- [x] ReaderSettingsPanel.swift
- [x] ReaderFlowFeatureView.swift
- [x] ReaderProgressSurfaceView.swift
- [x] ReaderSessionSummaryView.swift
- [x] ReaderStageActionBar.swift
- [x] ReaderStatusCardView.swift
- [x] ReaderSettingsStore.swift (persistence)
- [x] ReaderDisplaySettings.swift (AppSupport model)
- [x] ReaderModuleBoundary.swift
- [ ] Chapter navigation (next/prev) with real content (partial)
- [ ] Scroll position tracking (not implemented)
- [ ] Font size/type persistence applied (partial)

### Core Dependency
- ReaderCoreModels (ContentPage)
- ReaderAppSupport (ReaderDisplaySettings)

### Acceptance
- Content renders with mock text
- Settings panel opens and modifies display
- Progress saves on exit
- ~~Real chapter content~~ (deferred)

---

## Stage iOS-7: WebDAV Settings and Backup UI

**Status: PENDING** (not started)

### Objectives
- WebDAV server URL configuration
- Username / password input
- Keychain credential storage
- Connection test button
- Manual backup trigger
- Daily / weekly schedule setting
- Retention count configuration
- NO default high-frequency sync

### Deliverables
- [ ] WebDAV settings view
- [ ] Keychain credential manager
- [ ] Connection test logic
- [ ] Backup schedule picker
- [ ] Manual backup button
- [ ] Local DB export logic

### Core Dependency
- Core sync schema/contract (for backup format)
- WebDAV adapter protocol (ReaderCoreProtocols)

### Acceptance
- WebDAV URL/credentials saved to Keychain
- Connection test succeeds with valid server
- Manual backup exports local DB as Core-defined format
- Schedule UI configures daily/weekly backup
- Backup does NOT auto-sync on every read progress change

---

## Stage iOS-8: Progress Cloud Sync Integration

**Status: PENDING** (not started)

### Objectives
- Trigger progress sync on: exit reader, return to bookshelf, app background, app terminate
- Pull remote progress on app launch / book open
- Show "remote is newer" prompt
- Conflict resolution UI
- NOT real-time sync
- NOT polling during reading

### Deliverables
- [ ] Progress sync trigger (lifecycle events)
- [ ] Remote progress fetch on book open
- [ ] Progress comparison UI
- [ ] Conflict resolution dialog
- [ ] Sync status indicator

### Core Dependency
- ReaderCoreProtocols (progress sync contract)
- WebDAV adapter

### Acceptance
- Progress syncs when leaving reader
- Remote progress pulled on book open
- Conflict dialog shown when needed
- No background polling during reading

---

## Stage iOS-9: Local Book Import

**Status: PENDING** (not started)

### Objectives
- FileImporter for TXT/EPUB
- File permission handling
- Metadata extraction/save
- Core local book parser contract call
- Local books appear in bookshelf

### Deliverables
- [ ] File import picker (UTType: txt, epub)
- [ ] File permission manager
- [ ] Metadata extractor
- [ ] Local book → BookshelfItem mapping
- [ ] Core local book parser integration

### Core Dependency
- Core local book parser contract

### Acceptance
- TXT/EPUB files importable
- Metadata appears correctly
- Books appear in bookshelf
- Files accessible for reading

---

## Stage iOS-10: Dynamic Runtime Adapter Boundary

**Status: IN_PROGRESS** (Debug harness exists, adapter boundary defined)

### Objectives
- Prepare WKWebView runtime adapter
- Implement adapter boundary and lifecycle only
- Follow Core Dynamic Runtime contract
- NO custom rule behavior without Core contract

### Deliverables
- [x] WebViewRuntimeHarnessView.swift (Debug)
- [x] WebViewRuntimeHarnessViewModel.swift (Debug)
- [x] WebViewRuntimeAutorunView.swift (Debug)
- [x] WebViewRuntimeAutorunConfiguration.swift (Debug)
- [ ] Production WKWebView adapter (not started)
- [ ] Core Dynamic Runtime contract integration (TBD)

### Core Dependency
- ReaderPlatformAdapters (WKWebView adapter protocol)
- ReaderCoreModels
- Core Dynamic Runtime contract

### Acceptance
- Debug harness can render single URL in WKWebView
- Adapter respects Core security boundary
- NO arbitrary JS execution
- NO bypass of Core runtime contract

---

## Stage iOS-11: TTS and Reader UX Expansion

**Status: PENDING** (not started)

### Objectives
- AVSpeechSynthesizer integration
- Reading themes (more than basic)
- Page turn modes (scroll, curl, horizontal)
- Richer reader settings
- Maintain Core DTO boundary

### Deliverables
- [ ] TTS player with play/pause/speed
- [ ] Theme manager (color schemes)
- [ ] Page turn mode selector
- [ ] Advanced reader settings (margins, paragraph spacing, etc.)
- [ ] ReaderDisplaySettings expansion

### Core Dependency
- ReaderAppSupport (ReaderDisplaySettings)
- ReaderCoreModels (ContentPage)

### Acceptance
- TTS reads content aloud
- Themes apply correctly
- Page turn modes work
- All settings persist

---

## Stage iOS-12: Release Readiness

**Status: PENDING** (not started)

### Objectives
- App smoke test
- Core integration tests
- WebDAV manual acceptance
- Local book acceptance
- Crash/error handling review
- TestFlight readiness or local release checklist

### Deliverables
- [ ] Full app smoke test checklist
- [ ] Core integration test suite
- [ ] WebDAV acceptance test
- [ ] Local book acceptance test
- [ ] Crash reporter integration
- [ ] Release checklist document

### Core Dependency
- All previous stages complete
- Core RC stable

### Acceptance
- All smoke tests pass
- No crash on main flows
- WebDAV backup/restore works
- Local book import works
- App ready for TestFlight submission

---

## WebDAV / Sync Three-Way Separation

This roadmap enforces strict separation of three independent WebDAV capabilities:

### 1. Backup (Stage iOS-7)
- Low-frequency full backup
- Daily / weekly / manual
- Full backup each time
- For disaster recovery, migration, cross-device restore
- Configurable retentionCount
- Local book files NOT auto-backed up (user opt-in)
- iOS: backup settings UI, manual button, schedule, Keychain, local DB export, Core sync schema

### 2. Progress Cloud Sync (Stage iOS-8)
- Only syncs actual reading progress
- Event-triggered (NOT real-time, NOT polling)
- Triggers: exit reader, return to bookshelf, app background, app terminate, manual
- Pull remote progress on app launch / book open
- Show diff when remote is newer

### 3. Remote WebDAV Books (Future)
- Independent remote library capability
- NOT mixed with Backup
- NOT mixed with Progress Cloud Sync
- Separate UI and logic

---

## Current Stage Assessment

Based on repository audit (2026-05-12):

- **Stage iOS-0**: DONE_CANDIDATE (this audit completes it)
- **Stage iOS-1**: IN_PROGRESS (CoreBridge exists, boundary PASS, but real Core not wired, build BLOCKED)
- **Stage iOS-2**: DONE_CANDIDATE (shell, navigation, routing all exist)
- **Stage iOS-3**: IN_PROGRESS (UI + persistence exist, mock-driven)
- **Stage iOS-4**: IN_PROGRESS (UI + persistence exist, mock-driven)
- **Stage iOS-5**: IN_PROGRESS (all screens exist, mock-driven)
- **Stage iOS-6**: IN_PROGRESS (reader UI + settings exist, mock-driven)
- **Stage iOS-7**: PENDING
- **Stage iOS-8**: PENDING
- **Stage iOS-9**: PENDING
- **Stage iOS-10**: IN_PROGRESS (Debug harness only)
- **Stage iOS-11**: PENDING
- **Stage iOS-12**: PENDING

**Overall assessment:** The app has a mock-driven UI for stages 2-6 and 10, but the foundational Core integration (Stage iOS-1) is incomplete. The app cannot currently build against real Reader-Core. All UI features exist but are backed by MockReaderCoreService.

---

## Decision Log

| Decision | Rationale | Date |
|---|---|---|
| Build all UI with mock data first | Allows parallel UI/Core development | 2026-04 |
| ReaderCoreServiceProvider as swap point | Single point to switch mock→real | 2026-04 |
| Stage iOS-1 must complete before stages 3-6 can be marked DONE | Real Core integration is prerequisite for DONE status | 2026-05-12 |
