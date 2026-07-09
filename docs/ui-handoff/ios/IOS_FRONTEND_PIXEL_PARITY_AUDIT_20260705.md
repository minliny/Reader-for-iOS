# iOS Frontend Pixel Parity Audit - 2026-07-05

## Scope

本报告承接前端五层审计中的第 1 层视觉还原审计，只比较 `Reader UI/frontend-demo` 与 iOS 原生 XCTest 截图在同 route、同 viewport 下的像素差异。

- 合同来源：`/Users/minliny/Documents/Reader UI/frontend-demo-optimized/route-contract.js`
- Web baseline：`/Users/minliny/Documents/Reader UI/frontend-demo-optimized/index.html?motionReduced=1&captureRoute=<route>`
- iOS 原生证据：`/tmp/reader-ios-frontend-audit-20260705-complete/manifest.json`
- Pixel audit 输出：`/tmp/reader-ios-frontend-pixel-parity-20260705-full`

## Result

- routes requested: 200
- comparable routes: 200
- routes without native attachment: 0
- captures completed: 200
- capture errors: 0
- average mismatch ratio: 18.91%
- worst mismatch ratio: 93.69%

结论：iOS 当前 native screenshot evidence 已闭合，但 pixel-level 视觉还原未完成。全量 200 route 都能建立 web/native 对照，说明证据管线可复跑；同时平均 18.91% mismatch 和多个高风险 route 的大比例差异，说明还不能宣称视觉还原完成。

## Command

```bash
NODE_PATH=/Users/minliny/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules \
/Users/minliny/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  scripts/audit_ios_frontend_pixel_parity.mjs \
  --output-dir /tmp/reader-ios-frontend-pixel-parity-20260705-full
```

The script writes:

- `/tmp/reader-ios-frontend-pixel-parity-20260705-full/pixel-parity-report.md`
- `/tmp/reader-ios-frontend-pixel-parity-20260705-full/pixel-parity-report.json`
- `/tmp/reader-ios-frontend-pixel-parity-20260705-full/web/*.png`
- `/tmp/reader-ios-frontend-pixel-parity-20260705-full/diff/*.png`

## Worst Routes

| route | viewport | mismatch | avg delta |
| --- | --- | ---: | ---: |
| `immersive-reading` | 390x844 | 93.69% | 45.97 |
| `source-delete-confirm` | 390x844 | 84.78% | 58.01 |
| `bookshelf-book-more-menu` | 390x844 | 77.89% | 87.29 |
| `discover-cache-confirm` | 390x844 | 76.80% | 58.47 |
| `reader` | 390x844 | 59.36% | 30.57 |
| `source-code-view` | 390x844 | 52.64% | 95.84 |
| `sort-filter` | 390x844 | 42.82% | 52.64 |
| `bookshelf-cover-mode` | 390x844 | 40.11% | 62.86 |
| `bookshelf` | 390x844 | 39.50% | 52.95 |
| `main-tabs` | 390x844 | 39.21% | 60.23 |
| `toc-bookmarks` | 1180x500 | 39.14% | 28.79 |
| `app-shell` | 390x844 | 37.74% | 51.52 |
| `reader_content` | 390x844 | 28.94% | 35.55 |
| `reader-directory-overlay-v2` | 390x844 | 27.38% | 34.95 |
| `reader-appearance` | 390x844 | 27.18% | 34.99 |
| `reader-appearance-overlay-v2` | 390x844 | 27.17% | 35.01 |
| `reader-night-state-v2` | 390x844 | 27.17% | 35.01 |
| `auto-page` | 390x844 | 26.78% | 34.24 |
| `reader-auto-scroll-overlay-v2` | 390x844 | 26.77% | 34.25 |
| `tts` | 390x844 | 26.46% | 33.77 |

## Interpretation

- `immersive-reading`, `reader`, `reader_content`, `reader-*overlay-v2`, `tts`, `auto-page` indicate Reader visual parity is still the largest open area.
- `bookshelf`, `bookshelf-cover-mode`, `bookshelf-book-more-menu`, `sort-filter` show Bookshelf is renderable but still visually divergent from the web contract.
- `main-tabs` and `app-shell` show Shell-level layout is structurally present but not pixel-matched.
- `source-delete-confirm`, `source-code-view`, `discover-cache-confirm` show deep Settings/Discover confirmation and code surfaces need route-specific visual repair before parity can pass.

## Audit Boundary

This is a bitmap audit, not an interaction or data audit. It does not verify click flows, return stack, keyboard behavior, CoreCommand, ViewState, HostRequest, offline/error transitions, or real device release readiness.

The next closure step is to triage the worst routes by shell family and repair shared primitives first: ReaderShell, MainTabShell/Bookshelf cards, dialog/sheet primitives, typography tokens, status bar/safe area, and bottom navigation spacing.
