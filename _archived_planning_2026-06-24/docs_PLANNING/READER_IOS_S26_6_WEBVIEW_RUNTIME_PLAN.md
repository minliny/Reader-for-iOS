# Reader-iOS S26.6 WebView Runtime Plan

## 1. Decision

S26.6 unlocked by user. WebView runtime planning active.

## 2. Current Assets

- ProductionWebViewAdapter (disabled by default)
- WebViewSecurityPolicy (host whitelist support)
- WebViewSecurityGate (JS policy enforcement)
- WebViewExecutionSnapshot (snapshot capture)
- xmanhua chapter fixture (23KB, JS-rendered images)

## 3. Phase Plan

| Phase | Scope | Output |
|-------|-------|--------|
| S26.6.2 | Snapshot Runtime Baseline | WKWebView adapter + gate + snapshot/replay |
| S26.6.3 | Xmanhua Content Replay | IOS-5A-NET-001 → DYNAMIC_CONTENT_REPLAY |
| S26.6.4 | Security Freeze | Gate verification |

## 4. Safety

- WebView default: disabled
- JS default: disabled
- Host whitelist: required
- Snapshot: no secrets
- Online: user-authorized only
