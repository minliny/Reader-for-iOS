# iOS Slice 1 Evidence Manifest

Date: 2026-07-04

Repo: `/Users/minliny/Documents/Reader for iOS`

Scheme: `ReaderForIOSApp`

Destination: `platform=iOS Simulator,name=iPhone 17,OS=26.5`

## Build Artifacts

- App artifact: `/Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Build/Products/Debug-iphonesimulator/ReaderForIOSApp.app`
- Bundle identifier: `com.reader.ios`
- Test bundle: `/Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Build/Products/Debug-iphonesimulator/ReaderForIOSApp.app/PlugIns/ReaderAppTests.xctest`

## Commands

### Focused Test Build

```
xcodebuild build-for-testing -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES ARCHS=arm64 -only-testing:ReaderAppTests/ReaderContractAdapterSlice0Tests -only-testing:ReaderAppTests/ReaderReducerSlice1GoldenTests
```

Result: PASS. The app target and focused test bundle compile against `ReaderUIContract`, including generated `TokenRegistry` and `MotionSpecRegistry`.

### Focused Test Execution

```
xcodebuild test -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES ARCHS=arm64 -only-testing:ReaderAppTests/ReaderContractAdapterSlice0Tests -only-testing:ReaderAppTests/ReaderReducerSlice1GoldenTests
```

Result: DIRECT PROJECT TEST BLOCKED in this local run. A focused single-class retry:

```
xcodebuild test -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES ARCHS=arm64 -only-testing:ReaderAppTests/ReaderContractAdapterSlice0Tests
```

timed out after 180 seconds at `Resolve Package Graph`, before XCTest execution.

The same build-for-testing artifact was then executed directly with `test-without-building`.

```
xcodebuild test-without-building -xctestrun /Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Build/Products/ReaderForIOSApp_iphonesimulator26.5-arm64.xctestrun -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:ReaderAppTests/ReaderContractAdapterSlice0Tests
```

Result: PASS. Executed 5 tests, 0 failures.

Result bundle:

```
/Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bbjjszvaumctdsaiyseiljdlzzdt/Logs/Test/Test-ReaderForIOSApp-2026.07.04_17-57-39-+0800.xcresult
```

```
xcodebuild test-without-building -xctestrun /Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Build/Products/ReaderForIOSApp_iphonesimulator26.5-arm64.xctestrun -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:ReaderAppTests/ReaderReducerSlice1GoldenTests
```

Result: PASS. Executed 17 tests, 0 failures.

Result bundle:

```
/Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-gwwmabpfnayntmbzcxyhalaogicv/Logs/Test/Test-ReaderForIOSApp-2026.07.04_17-58-01-+0800.xcresult
```

### Simulator Launch / Screenshot

```
xcrun simctl boot 'iPhone 17'
xcrun simctl install booted /Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Build/Products/Debug-iphonesimulator/ReaderForIOSApp.app
xcrun simctl launch booted com.reader.ios
xcrun simctl io booted screenshot docs/frontend-complete-app/evidence/ios-slice1-evidence-2026-07-04.png
```

Result (2026-07-04 rerun, environment restored): `simctl` is now responsive. Booted device: iPhone 17 (UDID `4647E187-8F40-44D2-AEF4-71B5B4B6F7BB`), iOS 26.5 runtime, state Booted. `xcrun simctl launch booted com.reader.ios` returned a live PID (16421) and `xcrun simctl io booted screenshot` wrote a 2,274,799-byte PNG to `docs/frontend-complete-app/evidence/ios-slice1-evidence-2026-07-04.png`.

The captured frame shows the Reader native AppShell on the bookshelf tab, including the top title/search/menu controls, continue-reading card, bookshelf grid, and floating tab bar. This proves the booted simulator + app install + launch + `simctl io screenshot` path now executes end-to-end for the Slice 1 shell.

## Proof Classification

- Build proof: PASS via focused `build-for-testing`.
- XCTest proof: PASS via focused `test-without-building` against the generated `.xctestrun` artifact.
- Simulator screenshot proof: PASS for Slice 1 AppShell. `simctl io screenshot` now succeeds end-to-end and the PNG is written in-repo (2,274,799 bytes). The captured frame is the Reader native bookshelf AppShell.

## Focused XCTest Rerun (2026-07-04, environment restored)

The focused `test-without-building` runs were re-executed against the existing xctestrun artifact to re-confirm Slice 0 + Slice 1 on the booted iPhone 17 (iOS 26.5).

- xctestrun path: `/Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Build/Products/ReaderForIOSApp_iphonesimulator26.5-arm64.xctestrun`
- Slice 0 (`ReaderContractAdapterSlice0Tests`): PASS — `Executed 5 tests, with 0 failures (0 unexpected) in 0.007 (0.011) seconds`. New xcresult: `/Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-hhrhdqiysizadadjzyuefaplhtyx/Logs/Test/Test-ReaderForIOSApp-2026.07.04_19-03-29-+0800.xcresult`.
- Slice 1 (`ReaderReducerSlice1GoldenTests`): PASS — `Executed 17 tests, with 0 failures (0 unexpected) in 0.016 (0.024) seconds`. New xcresult: `/Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-ejkotqadspyznaeteemdxgaxcpij/Logs/Test/Test-ReaderForIOSApp-2026.07.04_19-03-50-+0800.xcresult`.
- Screenshot artifact: `docs/frontend-complete-app/evidence/ios-slice1-evidence-2026-07-04.png` (2,274,799 bytes; frame = Reader native bookshelf AppShell).
- simctl state: iPhone 17 UDID `4647E187-8F40-44D2-AEF4-71B5B4B6F7BB`, iOS 26.5, Booted.

## Remaining Evidence Gap

- Native SwiftUI AppShell screenshot exists for the bookshelf shell. Recording evidence and deeper route evidence are still missing.
- Generic x86_64 simulator builds remain blocked by the existing `ReaderCore.xcframework` simulator slice gap; this was not changed.
- Core bridge command/event mapping remains Slice 2+ work.
