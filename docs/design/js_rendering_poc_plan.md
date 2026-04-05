# JS-Capable Rendering PoC Plan

**Status:** Design phase
**Created:** 2026-04-06
**Trigger:** sample_cookie_001 (wenku8.net) — all 8 isolation steps failed, JS gate confirmed

---

## Problem Statement

Sites protected by Cloudflare Browser Integrity Check (or similar) return HTTP 403 with a JavaScript challenge page. `URLSession` / `ReaderCoreNetwork` cannot execute JavaScript, making these sites inaccessible regardless of headers, cookies, or login pre-fetch strategies.

**Affected tier:** C (js_gate_required)
**Current samples:** sample_cookie_001 (wenku8.net)

---

## Non-Goals (Hard Constraints)

- **Must not** modify `ReaderCoreParser`, `ReaderCoreNetwork`, or any existing module
- **Must not** make WKWebView a dependency of non-JS parsing paths
- **Must not** introduce JS rendering into the main parsing pipeline
- **Must not** block p0_non_js or p1_cookie (non-gate) progress

---

## Architecture Decision: Isolation Boundary

```
┌─────────────────────────────────────────────────────────┐
│  ReaderCoreJSRenderer  (NEW — experimental module)      │
│  - WKWebView wrapper (iOS 15+ / macOS 13+)              │
│  - Async HTML extraction after JS execution             │
│  - Outputs: HTML string (same interface as URLSession)  │
│  - Completely isolated from ReaderCoreParser/Network    │
└────────────────────┬────────────────────────────────────┘
                     │ HTMLString
                     ▼
┌─────────────────────────────────────────────────────────┐
│  ReaderCoreParser  (UNCHANGED)                          │
│  - NonJSParserEngine.parseSearchResponse() etc.         │
│  - Receives HTML string regardless of source            │
└─────────────────────────────────────────────────────────┘
```

The key insight: `ReaderCoreParser` already operates on plain HTML strings. If `ReaderCoreJSRenderer` can produce an HTML string after JS execution, the parser pipeline is unchanged.

---

## Technology Options

### Option 1: WKWebView (iOS/macOS) — Recommended for PoC
- **Pros:** Native Apple SDK, supports Cloudflare challenges in real-world use, no external deps
- **Cons:** Requires main thread, UI context needed on macOS for CI; headless not trivially available
- **iOS:** WKWebView works in background context with workaround
- **macOS CI:** `WKWebView` requires app bundle on macOS — CI complication
- **Verdict:** Primary target for device/production use; CI smoke requires workaround

### Option 2: WKWebView + XCTest host (macOS CI)
- Run tests inside an XCTest bundle with app host — WKWebView available
- **Verdict:** Viable for PoC smoke tests in CI on macOS-14 runner

### Option 3: JavaScriptCore (JSC) alone
- Can execute JS but NOT make network requests — cannot pass Cloudflare
- **Verdict:** Not suitable for JS gate bypass

### Option 4: `swift-html-parser` + headless fetch (no JS exec)
- Already attempted in isolation suite — does not bypass Cloudflare
- **Verdict:** Ruled out

### Selected for PoC: Option 1 + Option 2 fallback

---

## PoC Minimum Target

**Goal:** Demonstrate that WKWebView can load wenku8.net search URL, execute JS challenge, and return parseable HTML.

**Deliverables:**
1. `Core/Sources/ReaderCoreJSRenderer/` — module skeleton (Protocol + WKWebView impl)
2. `Core/Sources/ReaderCoreJSRendererTests/` — unit test: load fixture URL, extract HTML
3. `samples/booksources/p1_js/sample_js_001.json` — tier C booksource (wenku8.net or equivalent)
4. Isolation runner variant: `SampleCookie001JSRenderRunner` — uses JSRenderer instead of URLSession
5. Report: `fetch_jsrender_result_sample_cookie_001.yml`

**PoC Success Criteria:**
- WKWebView loads the target URL
- HTML after JS execution contains the expected CSS selector (`.grid dl dd.title a`)
- Parser extracts at least 1 search result
- No changes to `ReaderCoreParser` or `ReaderCoreNetwork`

---

## Module Skeleton (to be created in step C2)

```swift
// ReaderCoreJSRenderer/JSRenderClient.swift
public protocol JSRenderClient: Sendable {
    func fetchHTML(url: String, timeout: TimeInterval) async throws -> String
}

// ReaderCoreJSRenderer/WKWebViewRenderClient.swift
// iOS 15+ / macOS 13+
@MainActor
public final class WKWebViewRenderClient: NSObject, JSRenderClient {
    // WKWebView-based implementation
    // Loads URL, waits for JS execution, returns document.documentElement.outerHTML
}
```

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| WKWebView unavailable on macOS CI headless | Medium | Use XCTest host bundle |
| Cloudflare still blocks WKWebView (different UA) | Low | WKWebView uses real Safari UA |
| PoC takes >2 weeks | Medium | Time-box: 1 week for skeleton + basic test |
| JS renderer introduces thread safety issues | Low | Isolate to @MainActor, no shared state with parser |

---

## Execution Timeline

| Step | Action | Phase |
|------|--------|-------|
| C1 | This document | Done |
| C2 | Package.swift: add ReaderCoreJSRenderer skeleton target | Next |
| C3 (deferred) | Implement WKWebViewRenderClient | After D-phase samples |
| C4 (deferred) | SampleCookie001JSRenderRunner CI smoke | After C3 |
| C5 (deferred) | sample_js_001 isolation report | After C4 |

---

## Classification Impact

Once ReaderCoreJSRenderer PoC succeeds:
- sample_cookie_001 moves from `blocked_until: PoC` to active testing
- site_access_tiers.yml tier C becomes actionable (not just classified)
- compat_matrix sample_cookie_001 `actualLevel` may change from D to A or B

**Until then: tier C sites remain DO NOT RETRY with URLSession.**
