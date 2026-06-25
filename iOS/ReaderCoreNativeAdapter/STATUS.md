# iOS Rust Core Host Adapter — STATUS

## Round 1: ABI Connectivity Skeleton (COMPLETED)

**Commit:** TBD (pending first commit on `codex/ios-rust-host-adapter`)

### Capability Table

| # | Capability | Type | Evidence | Status |
|---|-----------|------|----------|--------|
| 1 | `rc_abi_version()` returns 1 | `[core]` | ShellSmokeTests PASS | ✅ |
| 2 | `core.info` returns abiVersion + protocolVersion | `[core]` | ShellSmokeTests PASS | ✅ |
| 3 | `runtime.ping` returns pong=true | `[core]` | ShellSmokeTests PASS | ✅ |
| 4 | Unknown method surfaces UNKNOWN_METHOD error | `[core]` | ShellSmokeTests PASS | ✅ |
| 5 | Malformed JSON send fails with non-zero status | `[core]` | ShellSmokeTests PASS | ✅ |
| 6 | Core emits `host.request` for host capabilities | `[core]` | ShellSmokeTests PASS | ✅ |
| 7 | Cancel surfaces CANCELLED error code | `[core]` | ShellSmokeTests PASS | ✅ |
| 8 | Runtime create + destroy | `[app-side]` | ShellSmokeTests PASS | ✅ |
| 9 | Invalid config create fails | `[app-side]` | ShellSmokeTests PASS | ✅ |
| 10 | pollEvent drains result event | `[app-side]` | ShellSmokeTests PASS | ✅ |
| 11 | pollEvent returns nil for consumed event | `[app-side]` | ShellSmokeTests PASS | ✅ |

### Run command
```bash
cd iOS/ReaderCoreNativeAdapter
bash ./fetch-cabi.sh   # first time: materialize libreader_core.a from ../Reader-Core-Native
bash ./run-shell-smoke.sh
```

### Pre-existing baseline issues (recorded, not fixed by this lane)
- `scripts/check_ios_boundary.sh` FAIL — `iOS/CoreIntegration/CoreRSSFeedService.swift:3` imports `ReaderCoreParser` (documented in `docs/ios_boundary_violations.yml`)
- `swift build --target ReaderApp` FAIL on macOS — `ReaderApp.swift` references iOS-only APIs (`WebViewRuntimeAutorunView`, `topBarTrailing`); CI treats this as non-failing diagnostic

### Gap list
- Service-protocol backing (SearchService/TOCService/ContentService via Rust) — future rounds
- iOS simulator / device runs — blocked by pre-existing `ReaderApp` target breakage; not this lane
- xcframework integration for iOS builds — future round when `ReaderApp` build is fixed
