# iOS Demo Route Smoke Evidence - 2026-07-03

Demo baseline: `/Users/minliny/Documents/Reader UI/frontend-demo/render-runtime.js`.

Simulator target: iPhone 17, iOS 26.5, UDID `4647E187-8F40-44D2-AEF4-71B5B4B6F7BB`.

## Result

```bash
xcodebuild test -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'id=4647E187-8F40-44D2-AEF4-71B5B4B6F7BB' -only-testing:ReaderAppTests/DemoRouteFamilySimulatorSmokeTests
```

Result: passed. Executed `7` tests, `0` failures.

Result bundle:

`/Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Logs/Test/Test-ReaderForIOSApp-2026.07.03_12-05-58-+0800.xcresult`

## Exported Screenshots

```bash
xcrun xcresulttool export attachments --path /Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Logs/Test/Test-ReaderForIOSApp-2026.07.03_12-05-58-+0800.xcresult --output-path docs/ui-handoff/ios/screenshots/demo-route-smoke-20260703
find docs/ui-handoff/ios/screenshots/demo-route-smoke-20260703 -type f -name '*.png' | wc -l
```

Exported attachments: `110` PNG files plus `manifest.json`.

Screenshot directory:

`docs/ui-handoff/ios/screenshots/demo-route-smoke-20260703/`

## Coverage

| Test | Screenshots | Route family |
|---|---:|---|
| `testAppShellTabletRailAndContentShiftMatchDemoContract` | 3 | AppShell phone, expanded width, tablet rail |
| `testBookshelfRouteFamilyRendersDemoSurfacesOnSimulator` | 7 | Bookshelf root/search/detail/directory/batch/group/import |
| `testDiscoverRouteFamilyRendersAllDemoFeatureStatesOnSimulator` | 34 | Discover root, control, entry/filter/sort/state/login/rule/bulk routes |
| `testReaderRouteFamilyRendersResponsiveDemoSurfacesOnSimulator` | 15 | Reader phone, tablet right dock, compact landscape, ReaderShell states |
| `testRSSRouteFamilyRendersListDetailManagementAndStateSurfacesOnSimulator` | 16 | RSS list/detail/original/subscription/source/state routes |
| `testSettingsBackupImportAndSharedStateFamiliesRenderOnSimulator` | 35 | Settings, WebDAV, source management/import/debug/delete, failed/offline/permission states |

`testAsyncResultGuardKeepsLatestReaderContext` has no screenshot attachment by design; it verifies state ordering.
