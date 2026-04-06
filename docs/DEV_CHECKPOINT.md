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

| cp_D6_20260405 | 2026-04-05T20:33:32Z | D | D6 | completed | D7 |
| cp_F1_20260405 | 2026-04-05T20:33:32Z | F | F1 | completed | D7 |
| cp_D7_20260406 | 2026-04-06T04:12:28Z | D | D7 | completed | D8 |
| cp_D8_20260406 | 2026-04-06T04:20:43Z | D | D8 | completed | E3/D9 |
| cp_D9_20260406 | 2026-04-06T06:09:30Z | D | D9 | completed | D10 |

**lastCompletedStep:** D9
**nextStep:** D10 (switch p1 login validation to the-internet.herokuapp.com and rerun real isolation)

---

## Current Risks
- sample_cookie_002 (qidian.com) confirmed level D — HTTP 202 shell, JS rendering required (not Cloudflare)
- sample_login_001 (biquge.com.cn) domain unreachable from CI — retained as reference only
- sample_login_002 real CI run proved the site is anonymously reachable — invalid as LOGIN_REQUIRED sample
- Only the login candidate reached level A, but it was invalidated because the site is anonymous tier A rather than login-gated
- LOGIN_REQUIRED still has no confirmed real sample; fallback site execution is still required
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

## D9 Outcome
- `sample_login_001` is formally demoted to a `NETWORK_POLICY_MISMATCH` reference case.
- `sample_login_002` completed real GitHub Actions execution in run `24021028584`.
- `practice.expandtesting.com/secure` is anonymously reachable and therefore not a valid B3 sample.
- `sample_login_002` is retained as a negative reference showing why it must not be used for LOGIN_REQUIRED validation.
- Candidate selection assets now exist:
  - `samples/reports/latest/candidate_login_sites.yml`
  - `samples/reports/latest/reachability_probe_report.yml`
  - `samples/booksources/p1_login/sample_login_002.json`
  - `samples/metadata/p1_login/sample_login_002.yml`
  - `samples/expected/search/sample_login_002.json`
  - `samples/reports/latest/fetch_result_sample_login_002.yml`
  - `samples/reports/latest/fetch_isolation_step_records_sample_login_002.yml`
  - `samples/reports/latest/fetch_isolation_decision_summary_sample_login_002.yml`
