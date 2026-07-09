# iOS Frontend Visual Evidence Audit - 2026-07-05

## Scope

本报告承接前端五层审计中的第 1 层和第 5 层，只审计 iOS 原生截图证据覆盖，不把截图 smoke 误判为完整视觉还原。

- 合同来源：`/Users/minliny/Documents/Reader UI/frontend-demo-optimized/route-contract.js`
- iOS 路由来源：`iOS/Navigation/DemoRouteMapping.swift`
- iOS 原生证据：`DemoRouteFamilySimulatorSmokeTests` 的 xcresult 附件导出
- 本轮导出目录：`/tmp/reader-ios-frontend-audit-20260705-complete`

## Result

- demo contract routes: 200
- Swift-owned routes: 200
- iOS screenshot attachments: 211
- demo routes with native screenshot evidence: 200
- Swift-owned routes with native screenshot evidence: 200
- Swift-owned routes missing native screenshot evidence: 0
- unmapped native attachments: 0

结论：iOS 当前 200 条 demo contract route 已全部具备可回溯到 XCTest 的原生截图证据，native screenshot evidence gate 已闭合。但视觉还原仍不能判定完成，因为当前还没有同 route、同 state、同 viewport 的 `frontend-demo` vs iOS pixel diff。

## Command

```bash
node scripts/audit_ios_frontend_visual_evidence.mjs \
  --ios-manifest /tmp/reader-ios-frontend-audit-20260705-complete/manifest.json \
  --format json \
  --output /tmp/reader-ios-frontend-audit-20260705-complete/visual-evidence-audit.json
```

Native smoke rerun command:

```bash
READER_IOS_DEMO_SMOKE_SCREENSHOT_DIR=/tmp/reader-ios-frontend-audit-20260705-complete \
xcodebuild test \
  -project ReaderForIOS.xcodeproj \
  -scheme ReaderForIOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:ReaderAppTests/DemoRouteFamilySimulatorSmokeTests
```

When screenshots are only present inside the `.xcresult`, export them with:

```bash
xcrun xcresulttool export attachments \
  --path /Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Logs/Test/Test-ReaderForIOSApp-2026.07.05_17-15-25-+0800.xcresult \
  --output-path /tmp/reader-ios-frontend-audit-20260705-complete
```

## Missing Native Screenshot Evidence

- none

The final four closed routes were interaction or transient states and were covered by real initial state seams in the existing native views, not unrelated static stand-ins:

- `bookshelf-book-more-menu`: opens the bookshelf item focus/more overlay as the initial render state.
- `sort-filter`: opens the bookshelf filter popover as the initial render state.
- `search-loading`: initializes the real search flow with `SearchState.loading`.
- `source-switch-results`: initializes the same `ReaderSourceSwitchFlowView` with a confirmed `SourceSwitchResultState` inside `FlowShell`.

## Audit Boundary

This is an evidence coverage report. It verifies that native XCTest screenshot attachments can be mapped back to demo contract routes. It does not compare pixels, colors, typography, spacing, radius, shadows, safe area, status bar, bottom navigation, sheet placement, or route state against `frontend-demo`.

The matching web `frontend-demo` capture and bitmap comparison now lives in `IOS_FRONTEND_PIXEL_PARITY_AUDIT_20260705.md`. Until the high-mismatch routes are repaired and rerun through that pixel audit, visual restoration remains partial even when native smoke tests pass.
