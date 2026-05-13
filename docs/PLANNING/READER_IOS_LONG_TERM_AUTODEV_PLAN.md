# Reader for iOS — Long-Term Automated Development Plan

Generated: 2026-05-13T20:00+08:00
Status: ACTIVE
Mode: Mock-driven, single-task-per-cycle, cron loop

---

## Overview

This plan guides the 10-minute cron loop development of Reader for iOS.
Each stage builds on the previous. Real Core integration is deferred until CORE-GAP-001 is resolved.
Mock-driven development continues in parallel.

---

## Stage S0: Repo Safety and Loop Baseline ✅ DONE

**Goal**: Establish safe cron loop infrastructure, boundary checks, task queue.

**Done**:
- iOS boundary check script (PASS, 56 files, 0 violations)
- Cron loop command files (.claude/commands/)
- Loop state / backlog / decision register / core gap register
- Auto-resolve decision policy
- Symlink Reader-Core → ../Reader-Core

---

## Stage S1: Core Integration Boundary ✅ DONE_CANDIDATE

**Goal**: Verify only Reader-Core public API consumed; mock bridge functional.

**Done**:
- Public API audit (no illegal imports)
- Boundary rules documentation
- Boundary check script validated
- CoreBridge inventory (ReaderCoreServiceProvider mock mode)
- ShellAssembly + MockReaderCoreService

**Remaining**: IOS-1D ShellSmokeTests coverage (PENDING, blocked by ENV_TEST_BLOCKED)

---

## Stage S2: App Shell and Navigation ✅ DONE_CANDIDATE

**Goal**: Navigation routes, tab structure, modal flow.

**Done**:
- AppNavigationState (Route-based navigation)
- ReaderShellEnvironment
- ReaderModuleBoundary
- All routes: home, bookSourceImport, search, toc, content

---

## Stage S3: Bookshelf MVP ⏸️ LOCKED (needs Core)

**Goal**: Bookshelf with real book data from Core.

**UI exists** (mock-driven): BookshelfView, BookshelfViewModel, BookshelfItemRowView, BookshelfStore
**Blocked by**: CORE-GAP-001 (real Core search pipeline)

---

## Stage S4: Source Management MVP ⏸️ LOCKED (needs Core)

**Goal**: Book source validation, JSON import, enable/disable.

**UI exists** (mock-driven): BookSourceListView, BookSourceImportView, BookSourceViewModel, BookSourceStore
**Blocked by**: CORE-GAP-001 (real Core validation API)

---

## Stage S5: Search / Detail / TOC Flow ⏸️ LOCKED (needs Core)

**Goal**: End-to-end search→detail→TOC→content flow with real Core.

**UI exists** (mock-driven): SearchView, BookDetailView, TOCView, ChapterListView, ContentView
**Blocked by**: CORE-GAP-001 (real Core pipeline)

---

## Stage S6: Reader Page MVP ✅ HARDENED

**Goal**: Chapter navigation, progress tracking, settings application, error states.

**Done (2026-05-13, commit cbc022b)**:
- ReaderViewModel: chapter list, prev/next, progress save/restore, settings, cache
- ReaderView: ReaderStageActionBar + ReaderProgressSurfaceView integration
- All 7 reader states rendered
- 20 unit tests written (blocked by ENV_TEST_BLOCKED)
- Injectible stores for testability

**Remaining**: Real ContentPage from Core (BLOCKED), scroll→progress ratio mapping (P2)

---

## Stage S7: WebDAV Settings and Backup UI ← CURRENT (READY)

**Goal**: WebDAV settings view, Keychain credential storage, backup schedule UI, connection test mock.

**Entry conditions**: Stage S6 hardened ✅
**Scope**:
- `iOS/Features/` — new WebDAV settings view
- Keychain integration (Security framework, system dependency allowed)
- Backup schedule picker (daily/weekly/manual)
- Retention count setting
- Connection test button (mock result initially)
- Mock backup export

**Forbidden**:
- Do NOT implement real WebDAV protocol
- Do NOT auto-sync on progress change
- Do NOT mix backup with progress sync
- Do NOT access network

**DONE condition**: WebDAV URL/credentials persist; connection test mock works; schedule picker functional

---

## Stage S8: Progress Cloud Sync ← PENDING

**Goal**: Progress sync triggers, conflict resolution UI.

**Blocked by**: Core progress sync contract (GAP-005 anticipated)

---

## Stage S9: Local Book Import ← PENDING

**Goal**: File import UI for TXT/EPUB, metadata extraction.

**Blocked by**: Core local book parser contract (GAP-006 anticipated)

---

## Stage S10: WKWebView Adapter ← PENDING

**Goal**: Production WKWebView runtime adapter (not Debug harness).

**Blocked by**: Core Dynamic Runtime contract (GAP-007 anticipated)

---

## Stage S11: TTS and Reader UX ← PENDING

**Goal**: AVSpeechSynthesizer, reading themes, page turn modes.

---

## Stage S12: Release Readiness ← PENDING

**Goal**: Smoke tests, CI verification, release checklist.

---

## Forbidden Actions (All Stages)

- Modify Reader-Core source
- Import Parser / Runtime internal modules
- Implement Core business logic in iOS
- Add third-party dependencies (unless pre-approved)
- Execute network requests from cron loop
- Auto-commit (commits require manual review)
- Hard-reset / force-push / destructive git operations

## Running the Loop

```bash
# Start the cron loop (in Claude Code REPL):
/loop 10m /reader-ios-cron-loop

# Stop the cron loop:
/loop stop

# Check status:
# Review docs/PLANNING/READER_IOS_CRON_LOOP_STATE.yml
```
