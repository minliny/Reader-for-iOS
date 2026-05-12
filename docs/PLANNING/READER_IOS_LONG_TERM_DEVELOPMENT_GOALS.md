# Reader for iOS — Long Term Development Goals

Generated: 2026-05-13T00:00+08:00
Repo: Reader for iOS
Branch: main
HEAD: 6a25beb

---

## 1. Current Repository State

### 1.1 Repository Status

| Field | Value |
|---|---|
| HEAD | `6a25beb` |
| Branch | `main` |
| Working tree | MODIFIED (5 unstaged files + 5 untracked planning docs from previous audit) |
| validation_status | FAILED (xcodebuild blocked by Core-side compile error) |
| boundary_violation_status | PASS (56 files, 0 violations) |

### 1.2 Build Status

| Check | Result |
|---|---|
| `swift test` (iOS/) | FAILED — `../Reader-Core` sibling path not found |
| `xcodebuild` (ReaderForIOSApp) | FAILED — ReaderCoreParser iOS 16 API in SimpleXPathEvaluator.swift:293 |
| `scripts/check_ios_boundary.sh` | PASS — 56 files, 0 violations |
| `xcodebuild -list` | OK — 31 schemes |

### 1.3 Reader-Core Dependency

- Package.swift: `.package(path: "../Reader-Core")` — resolves to non-existent path
- project.yml: `path: ../Reader-Core/Core` — resolves correctly
- Products used: ReaderCoreFoundation, ReaderCoreModels, ReaderCoreProtocols, ReaderCoreParser, ReaderCoreNetwork, ReaderPlatformAdapters

---

## 2. Reader-Core Current State and iOS Impact

### 2.1 Core State

Reader-Core is at **Core RC Candidate Verified with Open Gaps**:

- Stage 8–21: Core-only full parity baseline COMPLETE
- Stage 22–29: RC Verification Loop COMPLETE (62 rounds, 61/62 tasks, 8/8 stages)
- 0 swift test failures
- 0 parser/runtime changes during verification

### 2.2 Known Core Gaps

| Gap | Impact on iOS |
|---|---|
| S26.6: Real book source validation LOCKED_NEEDS_CONFIRM | Cannot validate real BookSource JSON in iOS |
| A032: TocRule isVolume P0 gap | TOC parsing may be incomplete |
| 23 MISSING capabilities | Various Core features not yet available |
| 14 CONTRACT_ONLY | Protocols defined but no implementation |
| 4 DOC_ONLY | Documentation only, no code |
| 50 planned tests not implemented | Core test coverage incomplete |
| ReaderCoreParser iOS 16 API issue | Blocks xcodebuild from iOS repo |

### 2.3 Principles for iOS Development

1. **Core is an evolving contract.** APIs may change during Stage 30 Gap Burn-down.
2. **iOS must not duplicate Core logic.** If a capability is missing, report gap, don't reimplement.
3. **Mock-driven development is approved.** All UI exists with MockReaderCoreService.
4. **iOS prioritizes work that does NOT depend on Core gaps.**

---

## 3. Long Term Goals for Reader for iOS

### Goal 1: Complete Stage iOS-0 (Baseline Audit)
**Target:** Buildable, testable, auditable foundation.

- Repository structure documented
- All dependencies resolved
- Build pass (or Core-side failure attributed)
- Test entrypoints confirmed
- Boundary check passing

### Goal 2: Complete Stage iOS-1 (Core Integration Boundary)
**Target:** Clean Core public API integration with real Core service.

- ReaderCoreServiceProvider.real mode implemented
- ShellSmokeTests and PersistenceTests pass
- Error mapping complete for all Core error types
- Boundary check automated in pre-commit

### Goal 3: Ship Bookshelf MVP (Stage iOS-3)
**Target:** Functional bookshelf with real book data.

- Bookshelf shows real books from Core
- Reading progress persists across app restarts
- Add-to-bookshelf from search results works
- No hardcoded book data

### Goal 4: Ship Reading Flow (Stages iOS-4, iOS-5, iOS-6)
**Target:** End-to-end search → read flow.

- Book source JSON import with Core validation
- Search → results → detail → TOC → content flow
- Reader page with real content, chapter navigation, settings
- All error states handled

### Goal 5: Ship WebDAV Backup (Stage iOS-7)
**Target:** User can back up library to WebDAV server.

- WebDAV settings UI with Keychain credentials
- Connection test
- Manual backup + daily/weekly schedule
- Retention count configurable
- Uses Core sync schema/contract

### Goal 6: Ship Progress Cloud Sync (Stage iOS-8)
**Target:** Reading progress syncs across devices.

- Event-triggered sync (not polling)
- Remote progress pull on book open
- Conflict resolution UI
- Clean separation from Backup

### Goal 7: Ship Local Book Import (Stage iOS-9)
**Target:** Users can import TXT/EPUB files.

- FileImporter for TXT/EPUB
- Metadata extraction via Core contract
- Local books in bookshelf alongside online books

### Goal 8: Ship WKWebView Adapter (Stage iOS-10)
**Target:** Production WKWebView adapter for Dynamic Runtime.

- Adapter wraps WKWebView lifecycle
- Follows Core Dynamic Runtime contract
- Respects Core security boundary
- No arbitrary JS execution

### Goal 9: Ship TTS and Reader UX (Stage iOS-11)
**Target:** Rich reading experience.

- AVSpeechSynthesizer TTS
- Reading themes
- Page turn modes (scroll, curl, horizontal)
- Advanced reader settings

### Goal 10: Release Readiness (Stage iOS-12)
**Target:** App ready for TestFlight.

- All smoke tests pass
- Core integration tests pass
- WebDAV acceptance complete
- Local book acceptance complete
- Crash/error handling reviewed
- App Store review risk checklist complete

---

## 4. Legado Parity App-Side Capability Map

| Legado Capability | iOS Stage | Status | Core Dependency |
|---|---|---|---|
| App Shell / Navigation | iOS-2 | DONE_CANDIDATE | ReaderCoreModels |
| Bookshelf | iOS-3 | IN_PROGRESS (mock) | Core book DTO |
| Book Source Management | iOS-4 | IN_PROGRESS (mock) | Core validation API |
| Search | iOS-5 | IN_PROGRESS (mock) | Core search pipeline |
| Book Detail | iOS-5 | IN_PROGRESS (mock) | Core detail pipeline |
| TOC / Chapter List | iOS-5 | IN_PROGRESS (mock) | Core TOC pipeline |
| Content Reading | iOS-6 | IN_PROGRESS (mock) | Core content pipeline |
| Reader Settings | iOS-6 | IN_PROGRESS | ReaderAppSupport |
| WebDAV Backup | iOS-7 | PENDING | Core sync schema |
| Progress Sync | iOS-8 | PENDING | Core progress contract |
| Local Book Import | iOS-9 | PENDING | Core local book contract |
| WebView Runtime | iOS-10 | IN_PROGRESS (debug) | ReaderPlatformAdapters |
| TTS | iOS-11 | PENDING | None (iOS-native) |
| Reading Themes | iOS-11 | PENDING | ReaderAppSupport |
| Page Turn Modes | iOS-11 | PENDING | None (iOS-native) |
| Release Readiness | iOS-12 | PENDING | All above |

---

## 5. iOS App vs Core Responsibility Boundary

### iOS Owns
- SwiftUI views and view models
- Navigation and routing
- Local persistence (stores)
- Keychain credential management
- File access (FileImporter)
- WKWebView lifecycle wrapping
- AVSpeechSynthesizer
- Background task scheduling
- App lifecycle event handling
- User preferences and settings UI

### Core Owns
- Book source models and parsing
- Rule engine execution
- URL DSL resolution
- HTTP request/response handling
- Cookie/session management
- Content extraction
- Search result parsing
- TOC/chapter parsing
- WebDAV sync schema
- Progress sync protocol
- Platform adapter protocols
- Security gate

### iOS Must NOT
- Parse book source JSON beyond JSON decode
- Implement URL DSL
- Execute book source rules
- Manage HTTP cookies for book sources
- Extract content from HTML
- Parse search results from HTML
- Parse chapter lists from HTML
- Implement WebDAV protocol
- Execute arbitrary JavaScript

---

## 6. Stage-by-Stage Long Term Plan

### Stage iOS-0: Repository Baseline Audit

**Core deliverables:**
- [x] Repository structure documented
- [x] Dependency graph mapped
- [x] Build attempted (xcodebuild FAILED, Core-side)
- [ ] Build passes (or Core failure attributed and accepted)
- [ ] Test entrypoints confirmed

**Core dependency:** None (read-only)
**Parallel tasks:** None (all sequential audit steps)
**Blocking conditions:** Core compile error in SimpleXPathEvaluator
**Acceptance:** Build status clear; test entrypoints working

### Stage iOS-1: Core Integration Boundary

**Core deliverables:**
- [x] CoreBridge layer exists
- [x] Boundary check script exists and passes
- [x] Integration error mapping exists
- [ ] Real Core service wired
- [ ] Smoke tests pass

**Core dependency:** Buildable Reader-Core
**Parallel tasks:** Error mapping + boundary documentation can proceed without Core build
**Blocking conditions:** Core build failure
**Acceptance:** Real Core service callable; smoke tests pass

### Stage iOS-2: App Shell and Navigation

**Core deliverables:**
- [x] SwiftUI App shell with tabs
- [x] Navigation routes defined
- [x] Surface layer (loading, error, empty)

**Core dependency:** ReaderCoreModels (DTOs for routing)
**Parallel tasks:** All UI screens can be built in parallel with mock data
**Blocking conditions:** None (mock data sufficient)
**Acceptance:** All routes reachable; navigation works

### Stage iOS-3: Bookshelf MVP

**Core deliverables:**
- [x] BookshelfView + ViewModel
- [x] BookshelfStore (persistence)
- [x] ReadingProgressStore
- [ ] Real book data from Core
- [ ] Add-to-bookshelf flow

**Core dependency:** Core book DTO, Core search pipeline (for real data)
**Parallel tasks:** Persistence testing + UI polish
**Blocking conditions:** Core build for real data
**Acceptance:** Bookshelf shows real books; progress persists

### Stage iOS-4: Source Management MVP

**Core deliverables:**
- [x] BookSourceListView + ViewModel
- [x] BookSourceImportView
- [x] BookSourceStore (persistence)
- [ ] Core validation integration

**Core dependency:** Core public book source validation API
**Parallel tasks:** Import UI + persistence can be completed with mock
**Blocking conditions:** Core validation API not available
**Acceptance:** JSON import validated by Core; enable/disable works

### Stage iOS-5: Search / Detail / TOC / Content Flow

**Core deliverables:**
- [x] SearchView + ViewModel
- [x] BookDetailView + ViewModel
- [x] ChapterListView + ViewModel
- [x] ContentView
- [x] ReadingFlowCoordinator
- [ ] Real Core pipeline integration

**Core dependency:** Core search/toc/content pipeline
**Parallel tasks:** UI polish, error states, loading states
**Blocking conditions:** Core pipeline not available
**Acceptance:** End-to-end flow with real data

### Stage iOS-6: Reader Page MVP

**Core deliverables:**
- [x] ReaderView + ViewModel
- [x] ReaderSettingsPanel
- [x] ReaderSettingsStore
- [ ] Chapter navigation
- [ ] Scroll position tracking
- [ ] Real content display

**Core dependency:** Core ContentPage DTO
**Parallel tasks:** Settings UI + persistence
**Blocking conditions:** Core content pipeline for real content
**Acceptance:** Real content displayed; settings applied; progress saved

### Stage iOS-7: WebDAV Settings and Backup UI

**Core deliverables:**
- [ ] WebDAV settings view
- [ ] Keychain credential manager
- [ ] Connection test
- [ ] Backup schedule UI
- [ ] Manual backup button

**Core dependency:** Core sync schema/contract; WebDAV adapter
**Parallel tasks:** UI + Keychain can be built without real WebDAV
**Blocking conditions:** Core sync schema not available
**Acceptance:** Credentials saved to Keychain; backup exports correctly

### Stage iOS-8: Progress Cloud Sync Integration

**Core deliverables:**
- [ ] Progress sync triggers
- [ ] Remote progress pull
- [ ] Progress comparison UI
- [ ] Conflict resolution UI

**Core dependency:** Core progress sync contract
**Parallel tasks:** Trigger points can be defined without real sync
**Blocking conditions:** Core progress sync contract not available
**Acceptance:** Sync triggers fire; remote progress pulled; conflicts resolved

### Stage iOS-9: Local Book Import

**Core deliverables:**
- [ ] FileImporter (TXT/EPUB)
- [ ] Metadata extraction UI
- [ ] Local book → bookshelf mapping

**Core dependency:** Core local book parser contract
**Parallel tasks:** File picker UI can be built without Core
**Blocking conditions:** Core local book contract not available
**Acceptance:** TXT/EPUB importable; readable in app

### Stage iOS-10: Dynamic Runtime Adapter Boundary

**Core deliverables:**
- [x] Debug WebView harness
- [ ] Production WKWebView adapter
- [ ] Core Dynamic Runtime contract integration

**Core dependency:** Core Dynamic Runtime contract + ReaderPlatformAdapters
**Parallel tasks:** Adapter lifecycle can be built with mock
**Blocking conditions:** Core Dynamic Runtime contract not available
**Acceptance:** Adapter wraps WKWebView; respects security boundary

### Stage iOS-11: TTS and Reader UX Expansion

**Core deliverables:**
- [ ] AVSpeechSynthesizer integration
- [ ] Reading theme manager
- [ ] Page turn mode selector
- [ ] Advanced reader settings

**Core dependency:** ReaderAppSupport (ReaderDisplaySettings)
**Parallel tasks:** All UX features are Core-independent
**Blocking conditions:** None (iOS-native capabilities)
**Acceptance:** TTS reads aloud; themes apply; page turns work

### Stage iOS-12: Release Readiness

**Core deliverables:**
- [ ] Smoke test checklist
- [ ] Core integration tests
- [ ] WebDAV acceptance
- [ ] Local book acceptance
- [ ] Crash/error review
- [ ] App Store review risk checklist

**Core dependency:** All previous stages DONE
**Parallel tasks:** Documentation + checklist can be prepared early
**Blocking conditions:** Prior stages incomplete
**Acceptance:** All tests pass; no crashes; TestFlight ready

---

## 8. Forbidden Actions (All Stages)

1. Do NOT modify Reader-Core repository
2. Do NOT copy Reader-Core internal implementation
3. Do NOT copy/translate/rewrite Legado Android source
4. Do NOT bypass Reader-Core public API
5. Do NOT implement Core parser in iOS
6. Do NOT hack Core gaps into iOS
7. Do NOT add dependencies without user confirmation
8. Do NOT access network without user authorization
9. Do NOT auto-commit
10. Do NOT use `git add -A`
11. Do NOT hardcode book source / sample logic to make UI work
12. Do NOT create long-term DTO alternatives to Core DTOs
13. Do NOT import Core internal symbols into iOS App
14. Do NOT default to high-frequency WebDAV sync
15. Do NOT poll progress during active reading
16. Do NOT develop with unresolved blockers

---

## 9. Core Gap Handoff Strategy

When a needed Core capability is missing:

1. **Identify** the specific missing API or capability
2. **Document** in `READER_IOS_CORE_GAP_HANDOFF_REGISTER.yml`
3. **Mark** dependent iOS task as `BLOCKED` or `MOVED_TO_CORE`
4. **Proceed** with iOS tasks that don't depend on the gap
5. **Report** gap to Reader-Core repo
6. **Do NOT** implement the capability in iOS

---

## 10. Success Metrics

| Metric | Target |
|---|---|
| Boundary violations | 0 (maintained) |
| Swift source files checked | 56+ |
| Build status | PASS (or Core failure attributed) |
| Test pass rate | 100% of all test targets |
| Mock coverage | All Core service methods covered |
| Real Core integration | All mock paths have real counterparts defined |
| Documentation | All stages have planning docs |
| Cron loop | Automated, safe, stoppable |
