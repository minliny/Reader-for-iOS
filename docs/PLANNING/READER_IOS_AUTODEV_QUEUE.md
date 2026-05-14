# Reader for iOS — Automated Development Task Queue

Generated: 2026-05-13T20:00+08:00
Updated: per cron cycle

Status enum: READY | IN_PROGRESS | DONE | BLOCKED | SKIPPED | NEEDS_USER_DECISION

---

| ID | Stage | Priority | Status | Goal | Scope | Acceptance | Blocked By |
|----|-------|----------|--------|------|-------|------------|------------|
| IOS-0A | S0 | P0 | DONE | Repository baseline audit | Read-only audit | Structure documented | — |
| IOS-0B | S0 | P0 | DONE | Build/test entrypoint confirmation | Symlink, build status | Symlink created; ENV_TEST_BLOCKED documented | CORE-GAP-001 (accepted) |
| IOS-1A | S1 | P0 | DONE | Public API dependency audit | Import audit | No illegal imports | — |
| IOS-1B | S1 | P0 | DONE | Core boundary rules documentation | Docs | Boundary rules doc exists | — |
| IOS-1C | S1 | P0 | DONE | Boundary check script validation | Script | PASS, 56 files, 0 violations | — |
| IOS-1D | S1 | P1 | DONE | CoreBridge inventory and smoke tests | ShellSmokeTests mock + real coverage | 28 tests, 0 failures (xcodebuild test, iOS Sim) | — |
| IOS-2A | S2 | P0 | DONE | App shell route inventory | Route audit | All routes documented | — |
| IOS-3A | S3 | P1 | DONE | Bookshelf MVP with real data | BookshelfView + BookshelfStore | Real/mock toggle + factory + smoke tests | ReaderCoreServices wired (4ecb3c2) |
| IOS-4A | S4 | P1 | DONE | Source management with real validation | BookSourceView + BookSourceStore | Real JSON decode validation (validateBookSource) | ReaderCoreServices wired (4ecb3c2) |
| IOS-5A | S5 | P1 | DONE | Search/detail/TOC real Core pipeline | SearchView + TOCView + ContentView | Real search→read flow with BookSource param | ReaderCoreServices wired (4ecb3c2) |
| IOS-6A | S6 | P0 | DONE | Reader page MVP hardening | ReaderViewModel + ReaderView | Chapter nav, progress, settings | — |
| IOS-7A | S7 | P1 | DONE | WebDAV settings and backup UI | New WebDAV settings feature | URL/credentials persisted; mock connection test; backup export mock | — |
| IOS-7B | S7 | P2 | DONE | Keychain credential storage | Security framework integration | Credentials secure; read/write works | — |
| IOS-8A | S8 | P2 | PENDING | Progress sync triggers | Progress sync UI | Triggers + conflict UI | S34 Sync/WebDAV inventoried (contract exists) |
| IOS-9A | S9 | P2 | READY | Local book import UI | FileImporter feature | TXT/EPUB importable | S33 contracts frozen (LocalBook models exist) |
| IOS-10A | S10 | P2 | PENDING | WKWebView production adapter | Production adapter | Adapter wraps WKWebView safely | S35 Adapter protocol inventoried |
| IOS-11A | S11 | P3 | DONE | TTS and reader UX | AVSpeechSynthesizer + themes | TTS reads; themes apply; page turn mode | — |
| IOS-12A | S12 | P3 | PENDING | Release readiness | Smoke tests + checklist | All acceptance tests pass | All prior stages |
| IOS-3A-NET-001 | S3 | P1 | DONE | Real search snapshot | Book source JSON + offline fixtures (auto_09966b3b) | Snapshot saved, 4 fixture files in test_inputs/fixtures/ | — |
| IOS-3A-FIXTURE-001 | S3 | P1 | DONE | Offline search replay | RealServiceOfflineReplayTests (4 tests) | Search/TOC/Content + Factory wiring verified | IOS-3A-NET-001 |
| IOS-4A-NET-001 | S4 | P2 | PENDING | Real TOC snapshot | TOCService E2E, 1 req | Snapshot saved | Book source JSON |
| IOS-5A-NET-001 | S5 | P2 | PENDING | Real content snapshot | ContentService E2E, 1 req | Snapshot saved | Book source JSON |

---

## Current Cycle Info

- IOS-3A/4A/5A DONE: Real search→read Core pipeline complete
- READY: IOS-9A (Local book import UI) — only unblocked task remaining
- PENDING: IOS-1D (ENV_TEST_BLOCKED), IOS-8A (S34), IOS-10A (S35), IOS-12A (prior stages)
- Network E2E: IOS-4A-NET-001/IOS-5A-NET-001 pending (more book source fixtures needed)
- Boundary: PASS
