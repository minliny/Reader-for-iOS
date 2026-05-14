# Reader for iOS — S0-S12 Foundation RC Audit

Generated: 2026-05-15
Tag: `reader-ios-rc1` (6fa61ad)

---

## 1. RC Definition

`reader-ios-rc1` is a **Foundation / Core Integration / Native Capability Baseline** RC.

**It IS**:
- App shell with TabView navigation (9 routes)
- Reader-Core public API integration (ReaderCoreServiceProvider real/mock dual mode)
- Real SearchService / TOCService / ContentService wiring via ReaderCoreServices
- Offline fixture-based E2E replay (4 tests)
- Book source import with structural JSON validation
- Bookshelf MVP with factory, add-to-bookshelf, detail view
- Reader page with chapter nav, progress, settings, TTS
- WebDAV settings UI + Keychain + backup export
- Progress sync manager with injectable adapter + conflict resolution
- WKWebView production adapter with security gate
- Local book import (FileImporter UI)
- 54 tests, 0 failures across 6 suites
- Boundary check PASS (67 files, 0 violations)
- xcodebuild BUILD SUCCEEDED

**It is NOT**:
- A complete frontend UI product RC
- A TestFlight-ready app
- A visually polished consumer application

---

## 2. UI Scope

Frontend UI design is handled by **Stitch** (multi-platform common design workflow).

The following UI concerns are **NOT in Reader-iOS current scope**:
- Visual design / pixel-perfect layout
- Component design system
- Design tokens (colors, fonts, spacing, icons)
- Multi-screen size adaptation rules
- Interaction flow diagrams
- Accessibility audit

Reader-iOS provides the **native capability surface** that Stitch UI will consume.

---

## 3. Stage Completion

All S0-S12 tasks: 18/18 DONE, 2 DEFERRED (manual network snapshot).

| Stage | Status |
|-------|:---:|
| S0 Repo Baseline | DONE |
| S1 Core Integration | DONE |
| S2 App Shell | DONE |
| S3 Bookshelf MVP | DONE |
| S4 Source Management | DONE |
| S5 Search/TOC/Content | DONE |
| S6 Reader Page | DONE |
| S7 WebDAV Settings | DONE |
| S8 Progress Sync | DONE |
| S9 Local Book Import | DONE |
| S10 WKWebView Adapter | DONE |
| S11 TTS & Reader UX | DONE |
| S12 Release Readiness | DONE |

---

## 4. Known Limitations

- Real search/TOC/content network E2E deferred (requires manual session)
- WebView execution disabled by default (security gate)
- Progress sync uses fake adapter (real WebDAV not configured)
- UI is functional but not visually refined (Stitch scope)

## 5. Reader-Core Dependency

- Phase 2: `4ecb3c2` (ReaderCoreServices, Adapter Protocol, Sync/WebDAV)
- Latest main: `125a7aa` (Phase 3 ACF parser started)
