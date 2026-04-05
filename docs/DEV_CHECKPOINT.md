# DEV_CHECKPOINT — Long-Running Unattended Execution Index

> Recovery: read this file → find `lastCompletedStep` → load checkpoint from `tools/checkpoints/` → resume from `nextStep`

## Master Plan Reference
- Plan horizon: `long_running_unattended`
- Schema: `tools/checkpoints/checkpoint_schema.yml`
- Phases: A (close p1_cookie) → B (site tiers) → C (JS PoC) → D (expand samples) → E (recovery mech) → F (milestone)

---

## Execution Log

| checkpointId | timestamp | phase | stepId | status | nextStep |
|---|---|---|---|---|---|
| cp_A1_20260405 | 2026-04-05T20:30:00Z | A | A1 | completed | A2 |
| cp_A2_20260405 | 2026-04-05T20:30:00Z | A | A2 | completed | A3 |
| cp_A3_20260405 | 2026-04-05T20:30:00Z | A | A3 | completed | B1 |
| cp_E1_20260405 | 2026-04-05T20:30:00Z | E | E1 | completed | E2 |
| cp_E2_20260405 | 2026-04-05T20:30:00Z | E | E2 | completed | B1 |
| cp_B1_20260406 | 2026-04-06T00:00:00Z | B | B1 | completed | B2 |
| cp_B2_20260406 | 2026-04-06T00:00:00Z | B | B2 | completed | B3 |
| cp_B3_20260406 | 2026-04-06T00:00:00Z | B | B3 | completed | C1 |
| cp_C1_20260406 | 2026-04-06T00:00:00Z | C | C1 | completed | C2 |
| cp_C2_20260406 | 2026-04-06T00:00:00Z | C | C2 | completed | D1 |
| cp_D1_20260406 | 2026-04-06T00:00:00Z | D | D1 | completed | D2 |
| cp_D2_20260406 | 2026-04-06T00:00:00Z | D | D2 | completed | D3 |
| cp_D3_20260406 | 2026-04-06T00:00:00Z | D | D3 | completed | D4 |
| cp_D4_20260406 | 2026-04-06T00:00:00Z | D | D4 | completed | D5 |
| cp_D5_20260406 | 2026-04-06T00:00:00Z | D | D5 | completed | D6 |

**lastCompletedStep:** D5
**nextStep:** D6 (CI smoke for sample_004 + sample_005 — requires push to trigger)

---

## Current Risks
- sample_004/005 smoke not yet CI-verified (pushed, awaiting run)
- sample_cookie_002 (qidian.com) may also have JS gate — needs real isolation run to confirm
- sample_login_001 (biquge.com.cn) domain availability uncertain
- JS rendering PoC (C3+) deferred — WKWebView CI headless needs XCTest host bundle
- CI concurrent push race: mitigated with git pull --rebase

## Blocked
(none — all deferred items have clear next actions)

## Files Modified in Last Batch
- docs/decisions/js_gate_cloudflare_classification.yml (new)
- docs/AI_HANDOFF/DECISIONS.md (updated)
- docs/design/js_rendering_poc_plan.md (new)
- docs/DEV_CHECKPOINT.md (this file)
- samples/classification/site_access_tiers.yml (new)
- samples/classification/sample_tier_mapping.yml (new)
- samples/matrix/failure_taxonomy.yml (v0.1.0 → v0.2.0)
- samples/matrix/compat_matrix.yml (v0.3.1 → v0.4.0)
- samples/booksources/p0_non_js/sample_004.json (new)
- samples/booksources/p0_non_js/sample_005.json (new)
- samples/booksources/p1_cookie/sample_cookie_002.json (new stub)
- samples/booksources/p1_login/sample_login_001.json (new stub)
- samples/booksources/p1_js/sample_js_001.json (new classified)
- samples/fixtures/html/sample_004_{search,toc,content}.html (new)
- samples/fixtures/html/sample_005_{search,toc,content}.html (new)
- samples/expected/{search,toc,content}/sample_004.json (new)
- samples/expected/{search,toc,content}/sample_005.json (new)
- samples/metadata/p0_non_js/sample_{004,005}.yml (new)
- samples/metadata/p1_cookie/sample_cookie_002.yml (new stub)
- samples/metadata/p1_login/sample_login_001.yml (new stub)
- samples/metadata/p1_js/sample_js_001.yml (new classified)
- Core/Sources/Sample004NonJSSmokeRunner/ (new)
- Core/Sources/Sample005NonJSSmokeRunner/ (new)
- Core/Sources/ReaderCoreJSRenderer/ (new skeleton)
- Core/Package.swift (updated)
- .github/workflows/sample001-nonjs-smoke.yml (updated)
