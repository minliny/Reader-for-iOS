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
| IOS-1D | S1 | P1 | PENDING | CoreBridge inventory and smoke tests | ShellSmokeTests mock coverage | All mock scenarios tested | ENV_TEST_BLOCKED |
| IOS-2A | S2 | P0 | DONE | App shell route inventory | Route audit | All routes documented | — |
| IOS-3A | S3 | P1 | LOCKED | Bookshelf MVP with real data | BookshelfView + BookshelfStore | Real book data displayed | CORE-GAP-001 |
| IOS-4A | S4 | P1 | LOCKED | Source management with real validation | BookSourceView + BookSourceStore | Real JSON import validated | CORE-GAP-001 |
| IOS-5A | S5 | P1 | LOCKED | Search/detail/TOC real Core pipeline | SearchView + TOCView + ContentView | Real search→read flow | CORE-GAP-001 |
| IOS-6A | S6 | P0 | DONE | Reader page MVP hardening | ReaderViewModel + ReaderView | Chapter nav, progress, settings | — |
| IOS-7A | S7 | P1 | IN_PROGRESS | WebDAV settings and backup UI | New WebDAV settings feature | URL/credentials persisted; mock connection test | — |
| IOS-7B | S7 | P2 | READY | Keychain credential storage | Security framework integration | Credentials secure; read/write works | — |
| IOS-8A | S8 | P2 | PENDING | Progress sync triggers | Progress sync UI | Triggers + conflict UI | CORE-GAP-005 (anticipated) |
| IOS-9A | S9 | P2 | PENDING | Local book import UI | FileImporter feature | TXT/EPUB importable | CORE-GAP-006 (anticipated) |
| IOS-10A | S10 | P2 | PENDING | WKWebView production adapter | Production adapter | Adapter wraps WKWebView safely | CORE-GAP-007 (anticipated) |
| IOS-11A | S11 | P3 | PENDING | TTS and reader UX | AVSpeechSynthesizer + themes | TTS reads; themes apply | — |
| IOS-12A | S12 | P3 | PENDING | Release readiness | Smoke tests + checklist | All acceptance tests pass | All prior stages |

---

## Current Cycle Info

- Last cycle: 2026-05-13 ~20:15 — IOS-7A WebDAV settings UI skeleton created
- Next READY task: **IOS-7B** (Keychain credential storage)
- Active blocker: CORE-GAP-001 (accepted, mock-driven continues)
- Test status: ENV_TEST_BLOCKED (macOS link)
- Boundary: PASS (58 files, 0 violations)
