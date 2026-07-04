# Reader Frontend Complete App Gap Matrix

Status: `DRAFT_AFTER_THREE_SELF_REVIEWS`

Date: 2026-07-04

Canonical source: `/Users/minliny/Documents/Reader UI/frontend-demo`

This document answers a narrower question than the architecture plan: what is still missing before the Reader frontend can be called a complete usable app. In the current architecture, "complete usable frontend app" means native iOS / Android / HarmonyOS apps that consume Reader UI contracts and render native UI. It does not mean shipping `frontend-demo/` as a WebView or shared Web runtime.

## 1. Scope

This matrix covers:

- `Reader UI` contract, demo, codegen, token, motion, and handoff gaps.
- Required gaps in `Reader for Android`, `Reader for iOS`, and `Reader for HarmonyOS`.
- Required gaps in `Reader-Core-Native` bridge and platform Host Adapter integration.
- Test, CI, device evidence, accessibility, lifecycle, and performance gaps.

This matrix does not claim current native implementation coverage for Android / iOS / HarmonyOS. That requires a separate live audit of each platform repository. Items for platform repos are therefore written as required evidence and acceptance criteria until code evidence is attached.

Follow-up matrices:

- `FRONTEND_COMPLETE_APP_GAP_MATRIX_ANDROID.md`
- `FRONTEND_COMPLETE_APP_GAP_MATRIX_IOS.md`
- `FRONTEND_COMPLETE_APP_GAP_MATRIX_HARMONYOS.md`
- `FRONTEND_COMPLETE_APP_GAP_MATRIX_CORE_BRIDGE.md`

Use this file as the parent checklist. Use the follow-up matrices as platform/Core implementation worksheets.

## 2. Current Evidence Snapshot

| Area | Current evidence | Meaning |
| --- | --- | --- |
| Demo route render | Browser smoke previously verified `131/131` `captureRoute` pages open with non-empty active stage. | Demo is useful as canonical visual and interaction sample. |
| Motion coverage | `node frontend-demo/verify/motion/verify-motion-coverage.mjs` passes `29/29`; route render coverage `131`, unresolved `0`, selector data coverage `151/183`. | Demo motion registry is strong, but not a full native implementation. |
| Contract tests | `node --test contracts/tests/*.test.mjs` passes `143/143`. | Schema, fixtures, generated type consistency, and slice fixtures are healthy. |
| Codegen drift | `node tools/codegen/check-drift.mjs` passes; `generated/` matches schema + fixtures. | Generated Swift / Kotlin / ArkTS files are reproducible. |
| Handoff readiness | `verify-ui-handoff-readiness.mjs` has `1/8` failure: `Package.swift` is treated as an unexpected production entry. | Handoff policy needs to allow contract-only Swift Package or remove it. |
| Demo contract consistency | `verify-demo-contract-consistency.mjs` reports `found=432 unknown=209`. | Current "unknown" is tracked but not blocking. Complete app work needs hard gates. |
| Route source drift | `route.schema.json` has `139` route ids; `frontend-demo/route-contract.js` has `131` routes. | Canonical route source is not fully converged. |
| Motion spec completeness | `motion.schema.json` has `84` MotionId values; `motion.fixtures.json` has `47` specs. | Missing `37` concrete MotionSpec fixture entries. |
| Production app shape | No top-level production Web app entry such as app-level `package.json`, Vite config, React/Vue/TS app, build pipeline, or release script. | `Reader UI` is not a standalone production frontend app. |

## 3. Completion Levels

| Level | Description | Current status |
| --- | --- | --- |
| L0: docs only | Markdown plans exist, no executable checks. | Passed. |
| L1: contract input ready | Schema, fixtures, codegen, and demo proof can guide platform work. | Mostly achieved. |
| L2: hard contract gate ready | Demo, schema, generated files, token, and motion ids have zero drift. | Not achieved. |
| L3: native vertical slices ready | Each platform has AppShell, reducer, TokenAdapter, MotionAdapter, Core bridge, Host Adapter, and device proof for first slices. | Not verified and should be treated as missing until each platform repo is audited. |
| L4: complete app ready | Priority routes, real data, sync, lifecycle, accessibility, performance, and device matrix are all verified. | Not achieved. |

Current overall assessment:

- Reader UI as development input: usable with caveats.
- Reader UI as complete app: not applicable by design.
- Three native apps as complete frontend: not proven and should be treated as incomplete until platform evidence exists.

## 4. P0 Gap Matrix

| ID | Gap | Owner | Current evidence | Impact | Acceptance |
| --- | --- | --- | --- | --- | --- |
| P0-01 | Canonical route source not converged | Reader UI | Schema `139` ids, demo `131` routes, two-way route drift exists. | Platform route mapping can fork from demo and generated types. | Choose canonical route source; update schema, fixtures, demo, generated; strict check passes with route unknown `0`. |
| P0-02 | Demo contract consistency is non-blocking | Reader UI | `demo-consistency.test.mjs` allows total unknown `< 500`; current unknown `209`. | Drift is visible but still mergeable. | Add strict mode and CI gate: route unknown `0`, motion unknown `0`, token unknown `0`, or documented deprecated exceptions. |
| P0-03 | MotionId naming drift | Reader UI | Demo runtime uses historical ids such as `reader.session.capsule.control.press/toggle`; schema uses `reader.session.capsule.control.press-toggle`. | Platform codegen and demo runtime can describe different animations. | Normalize MotionId names; keep aliases only through explicit deprecated mapping; generated drift and motion coverage pass. |
| P0-04 | MotionSpec registry incomplete | Reader UI | `84` MotionId values, `47` fixture specs, `37` missing concrete specs. | Platforms cannot consume complete duration/easing/token/guard data from generated code. | `motion.fixtures.json` covers `84/84`; codegen emits Swift/Kotlin/ArkTS `MotionSpecRegistry`; tests enforce full coverage. |
| P0-05 | Token registry not strong enough | Reader UI + platforms | Token schema/category exists, `tokens.css` names pass pattern, but platform value usage is not gated. | Native teams can handwrite colors, spacing, radius, font, and motion duration, causing drift. | Generate token registries with values; platform lint or tests reject non-contract color/spacing/radius/type/motion values for contract-owned UI. |
| P0-06 | Handoff readiness policy conflicts with contract package | Reader UI | Handoff readiness fails only on `Package.swift`. | CI may block a valid contract-only package or hide a real production runtime violation. | Update verifier to allow contract-only Swift package, or move/remove `Package.swift`; readiness passes `8/8`. |
| P0-07 | Platform reducer not proven | Android / iOS / HarmonyOS | `ACCEPTANCE.md` says Phase 3 reducer landing is not started in Reader UI scope. | UI behavior can diverge even when ViewState types compile. | Each platform has reducer/coordinator golden tests for navigation, overlay, activeSession, focus, loading, async guard, and reduced motion. |
| P0-08 | Native UI does not have required evidence | Android / iOS / HarmonyOS | `FRONTEND_DEVELOPMENT_READINESS.md` lists platform implementation evidence as missing outside Reader UI. | Demo proof can be mistaken for app completion. | Each platform provides build, route, screenshot/recording, and test evidence for Slice 1 to Slice 5 before broad route migration. |
| P0-09 | Core bridge not mapped to real Core protocol | Reader-Core-Native + platforms | Reader UI has `CoreCommand` / `CoreEvent` planning schemas, but cross-repo mapping is not closed. | Platform reducers may fake data or persist domain state locally. | Every P0 UiEvent that needs data maps to CoreCommand/CoreEvent or HostRequest; core protocol tests pass. |
| P0-10 | Host Adapter not implemented and verified | Android / iOS / HarmonyOS | Host request schema exists, but platform capability implementation evidence is outside Reader UI. | HTTP, WebView, Cookie, file, permission, TTS, background, share, notification can diverge. | Each platform has Host Adapter implementation and tests for required Slice 1 to Slice 6 capabilities. |

## 5. P1 Gap Matrix

| ID | Gap | Owner | Current evidence | Impact | Acceptance |
| --- | --- | --- | --- | --- | --- |
| P1-01 | ViewState fixtures are not platform rendering proof | Platforms | `view-state.schema.json` and fixtures exist; no platform rendering proof in this repo. | Native UI may render from local ad hoc models instead of contract ViewState. | Platform screens accept generated ViewState or mapped contract DTOs; snapshot/golden tests cover key states. |
| P1-02 | UiEvent coverage is not connected to native interactions | Platforms | `ui-event.schema.json` has `209` types. | Native click/gesture actions can bypass reducer and mutate local state. | Platform event tests prove UI emits UiEvent into reducer before Core/Host effects. |
| P1-03 | Motion evidence is representative, not exhaustive | Reader UI + platforms | Evidence manifest has representative proof; motion docs say platform recordings remain missing. | High-risk animation can differ across platforms. | For each P0 motion chain, platform recordings or automated animation-state assertions exist. |
| P1-04 | Selector coverage is not complete | Reader UI | Motion verifier reports `151/183` `data-*` directly mapped. | Some demo interactions still rely on fallback or implicit mapping. | Either map all interaction selectors or explicitly classify non-interactive metadata/debug selectors. |
| P1-05 | Real data lifecycle is not attached | Reader-Core-Native + platforms | Demo uses fixtures and fallback defaults. | Bookshelf, RSS, search history, progress, sync, and TTS can remain fake or duplicated per platform. | P0 slices use Core-backed repositories/events for domain state; fixture-only paths are disabled in production builds. |
| P1-06 | DomainState / UiState / EphemeralState handoff is not executable | Reader UI + platforms | State ownership docs exist. | Teams can still place bookshelf/RSS/search history/sync state in platform UI stores. | State ownership tests or audits prove DomainState comes from Core, UiState from reducer, EphemeralState from native view only. |
| P1-07 | Accessibility evidence is missing | Platforms | Evidence request exists only as requirement. | Overlay focus, hidden state, reader controls, and text selection can be unusable. | TalkBack, VoiceOver, and ArkUI focus evidence for Slice 1 to Slice 5. |
| P1-08 | Performance evidence is missing | Platforms | Evidence request exists only as requirement. | Reader scroll, pagination, control layer, and motion can jank on low-end devices. | Trace/profiler evidence and budget for route switch, reader control layer, page turn, and session capsule. |
| P1-09 | Lifecycle evidence is missing | Platforms + Core | Readiness lists background, lock screen, lifecycle outside Reader UI. | TTS, auto page, progress save, sync, and restore can break on app background/resume. | Lifecycle tests cover background/resume, process recreation where relevant, and stale async result handling. |
| P1-10 | CI gates are incomplete | All repos | Reader UI local checks pass, but cross-repo gates are not described as enforced. | Contract changes may not break platform builds early. | CI runs schema validation, codegen drift, platform compile, reducer tests, Core protocol tests, and selected device smoke. |

## 6. P2 Gap Matrix

| ID | Gap | Owner | Current evidence | Impact | Acceptance |
| --- | --- | --- | --- | --- | --- |
| P2-01 | Demo renderer maintainability | Reader UI | `frontend-demo/render-runtime.js` is over 10k lines and owns 131 route cases. | Changes are risky and hard to review. | Split renderer by shell or feature without changing route/motion/state output. |
| P2-02 | Full 131-route native migration strategy | Platforms | Slice matrix warns against all-at-once route migration. | Teams may attempt broad shallow parity and miss behavior. | Maintain route priority tiers: P0 slices first, P1 business flows next, P2 long tail last. |
| P2-03 | Large screen and fold matrix | Platforms | Motion docs define orientation/fold expectations, platform proof missing. | Tablet/fold layouts can break reader context and overlay focus. | Add device matrix and acceptance recordings for orientation, fold, hinge, pane, and resize. |
| P2-04 | Localization and content scale | Platforms + Reader UI | Demo text is Chinese fixture-heavy, with some long-title samples. | Dynamic text, language, and accessibility size can overflow. | Snapshot tests for long text, dynamic font size, and platform-specific text scaling. |
| P2-05 | Release and rollback process | All repos | Not covered by Reader UI demo. | Contract breaking changes can strand platform releases. | Versioned contract release notes, compatibility window, deprecated id policy, rollback path. |

## 7. Route and Screen Closure Requirements

Before any platform claims route parity:

1. Each route must map to one of: native screen, native overlay, native state variant, deprecated route, or deferred route.
2. Each route must have owner repository and priority.
3. Each implemented route must have ViewState input shape, UiEvent outputs, reducer transition, and Core/Host effects where needed.
4. Each route must have at least one acceptance artifact: unit test, snapshot/golden, simulator screenshot, device recording, or explicit non-visual protocol test.

Required route matrix columns:

```text
RouteId
Shell
Priority
Native owner
Native component
ViewState fixture
UiEvent list
CoreCommand / HostRequest
MotionId list
Token groups
State ownership
Acceptance command
Evidence path
Status
```

## 8. Motion Closure Requirements

Motion is not complete until all of these are true:

1. Schema, demo runtime, motion docs, fixtures, and generated code use the same canonical MotionId names.
2. `motion.fixtures.json` has one concrete MotionSpec per non-deprecated MotionId.
3. Codegen emits platform-consumable MotionSpec registries, not only enum types.
4. Each platform implements a native MotionAdapter that maps MotionId to SwiftUI / Compose / ArkUI primitives.
5. Reduced motion is a first-class branch, not an afterthought.
6. Interrupt behavior is covered by reducer tests: cancel, redirect, completeThenReplace, stale async result, route change, back, overlay close.
7. Evidence exists for P0 chains:
   - main tab switch
   - bookshelf to immersive reading
   - reader control layer open and hide
   - reader module switch
   - session capsule enter, update, switch, exit
   - overlay enter and exit
   - orientation reshape
   - source switch overlay

## 9. Token Closure Requirements

Token work is not complete until all of these are true:

1. `token.schema.json` models token categories and token value payloads needed by platforms.
2. `token.fixtures.json` contains production values for color, type, spacing, radius, elevation, opacity, z-index, motion duration, and reader themes.
3. Codegen emits Swift/Kotlin/ArkTS token registries with values and semantic names.
4. Platform UI imports token registries instead of copying literal values.
5. Tests reject contract-owned UI that uses raw color, spacing, radius, or motion duration values outside the registry.
6. Screenshots or snapshots prove the same semantic tokens are applied in light, dark, and reader theme states.

## 10. State and Data Closure Requirements

State ownership for complete app work:

| State | Owner | Required closure |
| --- | --- | --- |
| Bookshelf content, groups, sort, latest progress | DomainState in Reader-Core-Native | Platform reducer requests Core data; UI never writes persistence directly. |
| Search history | DomainState if persisted or synced; EphemeralState only for current input focus/value before submit | Core owns saved history; UI owns transient input field state. |
| RSS subscriptions and articles | DomainState in Reader-Core-Native | Core/RSS repository is source of truth; platform storage only through Host Adapter if Core requests it. |
| Reader progress and location | DomainState in Reader-Core-Native | Core canonical progress/location; platform may provide layout measurement but not business progress truth. |
| Reader route, overlay, readerMode, activeSession, focus, loading | UiState in Platform Interaction Reducer | Reducer golden tests cover legal transitions and mutex rules. |
| Drag offset, pressed state, scroll pixels, layout measurement, accessibility focus | EphemeralState in Native UI | Kept local and never used as business truth. |

## 11. Test and Evidence Closure Requirements

Minimum cross-repo acceptance set:

| Test layer | Required evidence |
| --- | --- |
| Reader UI contract | schema tests, fixtures validation, codegen drift, demo consistency strict mode, handoff readiness. |
| Reducer | golden tests per platform for route, overlay, session, focus, loading, async guard, interrupt. |
| Core protocol | CoreCommand/CoreEvent mapping tests and stale/failed result handling. |
| Host Adapter | HTTP, WebView, Cookie, file, permission, TTS, background, notification, share capability tests where used. |
| Native UI | screenshot/golden tests for AppShell, bookshelf, reader, overlays, source switch, RSS/settings as they enter priority scope. |
| Device smoke | install/start, navigation, reader entry, control layer, keyboard, sheet/dialog, session capsule, orientation. |
| Accessibility | focus trap, focus restore, hidden state, label/role, reader control semantics. |
| Performance | route switch, reader page turn, control layer open/hide, session capsule, list scrolling. |
| Lifecycle | background/resume, active session, progress save, stale async result, process recreation where applicable. |

## 12. Immediate Work Order

The next work should not be "implement all screens". It should be:

1. Reader UI P0 gate closure:
   - strict demo/schema consistency
   - route source convergence
   - MotionId normalization
   - `84/84` MotionSpec fixtures
   - TokenRegistry generation
   - handoff readiness `8/8`
2. Platform Slice 0 to Slice 3:
   - AppShell and main tabs
   - bookshelf to immersive reading
   - reader control layer minimum
   - token and motion adapter skeleton
   - reducer golden test skeleton
3. Core and Host minimum bridge:
   - open book, chapter/content load, progress update
   - host file/network/webview boundaries only where needed by first slices
4. Evidence loop:
   - each platform attaches build log, screenshot/recording, and test output before claiming completion.

## 13. How To Use The Follow-Up Matrices

The parent matrix is enough for planning, but implementation should happen through the follow-up files:

| File | Use it for | First action |
| --- | --- | --- |
| `FRONTEND_COMPLETE_APP_GAP_MATRIX_ANDROID.md` | Android Compose implementation and evidence. | Fill Gradle command, contract dependency, reducer, TokenAdapter, MotionAdapter, and Slice 1-5 evidence. |
| `FRONTEND_COMPLETE_APP_GAP_MATRIX_IOS.md` | iOS SwiftUI implementation and evidence. | Pick canonical Xcode project/scheme, then fill Swift contract dependency and reducer/coordinator evidence. |
| `FRONTEND_COMPLETE_APP_GAP_MATRIX_HARMONYOS.md` | HarmonyOS ArkUI implementation and evidence. | Fill ArkTS contract import, store/reducer, NAPI/Core bridge, token/motion adapters, and device smoke evidence. |
| `FRONTEND_COMPLETE_APP_GAP_MATRIX_CORE_BRIDGE.md` | Reader-Core-Native mapping and domain ownership. | Map P0 UiEvents to CoreCommand/CoreEvent/HostRequest and prove stale-result handling. |

Each follow-up matrix must eventually replace `TBD` and `Pending audit` with concrete file paths, commands, test names, screenshots, recordings, or links to platform repo evidence.

## 14. Self Review 1

Question: is this document enough after the first matrix?

Answer: not enough.

Missing items found:

- It had high-level P0/P1/P2 gaps, but not enough definition of route closure.
- Motion was listed as a gap, but not expanded into complete acceptance rules.
- Token closure was still too broad and could allow name-only compliance.
- State ownership was not explicit enough for bookshelf, search history, RSS, progress, and session.

Supplement added:

- Section 7 Route and Screen Closure Requirements.
- Section 8 Motion Closure Requirements.
- Section 9 Token Closure Requirements.
- Section 10 State and Data Closure Requirements.

## 15. Self Review 2

Question: is this document enough after adding closure rules?

Answer: still not enough.

Missing items found:

- It described what to build but did not define what evidence is required.
- It did not separate contract tests, reducer tests, Core protocol tests, Host Adapter tests, native UI tests, and device evidence.
- It could still be used to claim "ready" without accessibility, lifecycle, or performance proof.

Supplement added:

- Section 11 Test and Evidence Closure Requirements.
- Explicit rows for accessibility, performance, lifecycle, and device smoke.
- P1 evidence rows for accessibility, performance, lifecycle, and CI.

## 16. Self Review 3

Question: is this document now complete enough?

Answer: complete enough as a cross-repo planning and audit entry, but not complete enough as a final current-state audit.

Why it is enough for planning:

- It has scope, evidence snapshot, completion levels, P0/P1/P2 gap matrices, route/motion/token/state/test closure criteria, and immediate work order.
- Each P0 gap has owner, evidence, impact, and acceptance.
- It prevents the main misread: demo proof is not native app completion.

Why it is not a final implementation audit:

- It does not inspect current Android, iOS, HarmonyOS, or Reader-Core-Native code in this pass.
- Platform rows are required gaps until each platform repo provides code and device evidence.
- It does not estimate person-days because that requires current native implementation inventory.

Follow-up documents created for platform/Core audits:

```text
FRONTEND_COMPLETE_APP_GAP_MATRIX_ANDROID.md
FRONTEND_COMPLETE_APP_GAP_MATRIX_IOS.md
FRONTEND_COMPLETE_APP_GAP_MATRIX_HARMONYOS.md
FRONTEND_COMPLETE_APP_GAP_MATRIX_CORE_BRIDGE.md
```

Each follow-up must fill concrete current evidence, file paths, route coverage, MotionAdapter status, TokenAdapter status, reducer tests, Core/Host mapping, and device proof.
