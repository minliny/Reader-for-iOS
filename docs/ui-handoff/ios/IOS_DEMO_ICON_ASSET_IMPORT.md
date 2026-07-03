# iOS Demo Icon Asset Import

## Source

- Demo source: `/Users/minliny/Documents/Reader UI/frontend-demo/asset-library`
- Registry: `icons.js`
- Imported icon tokens: `92`
- iOS generated catalog: `iOS/Modules/Assets/ReaderIcons.xcassets`
- SwiftUI access layer: `iOS/Modules/Assets/ReaderAssetIcon.swift`
- Source snapshot: `docs/ui-handoff/ios/demo-icon-library`

## Import Command

```sh
node scripts/import_demo_icon_assets.mjs
```

Set `READER_UI_FRONTEND_DEMO=/path/to/frontend-demo` only when importing from a non-default demo checkout.

## Mapping Rule

| Demo | iOS |
| --- | --- |
| `ReaderAssetIcons.icons[id]` | `ReaderIcons.xcassets/reader-icon-{id}.imageset` |
| `ReaderAssetIcons.renderIcon(id)` | `ReaderIcon(.tokenName)` |
| `bookshelf / discover / rss / settings` | `AppTab.assetIcon` |
| `reader-module-*` | Reader module controls |

Generated SVG assets are template images. SwiftUI controls apply color with the existing foreground style, matching the demo `currentColor` contract.

## Current Usage

- Main tab bar: `FloatingTabBar` uses `AppTab.assetIcon`.
- Reader stage action bar: `ReaderStageActionBar` uses `ReaderAssetIcon` for previous, refresh, directory, and next buttons.
- `AppTab.systemImageName` is kept as a compatibility fallback for older call sites.

## Acceptance

```sh
node scripts/import_demo_icon_assets.mjs
find iOS/Modules/Assets/ReaderIcons.xcassets -name '*.imageset' | wc -l
xcodegen generate
xcodebuild test -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:ReaderAppTests/ReaderIconAssetAlignmentTests
git diff --check
```

Expected results:

- `.imageset` count is `92`.
- `ReaderIconAssetAlignmentTests` passes.
- `git diff --check` passes.
