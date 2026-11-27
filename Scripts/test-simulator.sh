#!/usr/bin/env bash
# An explicit, already-authorized, isolated iOS Simulator is required.
# The two process phases share only synthetic data in the test app's container.
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:?usage: test-simulator.sh build|write|cold|wave2write|wave2cold|design|m2host|m2edit|m2write|m2cold|m2ui|m2ui-source|m2ui-online|m3write|m3cold|m3speech <UDID> <derived> <evidence>}"
device="${2:?isolated simulator UDID required}"
derived="${3:?isolated DerivedData path required}"
evidence="${4:?immutable evidence directory required}"
mkdir -p "$evidence"
target="platform=iOS Simulator,id=$device"
case "$mode" in
  build)
    python3 Scripts/sync-inputs.py --check
    python3 Scripts/framework-receipt.py "$PWD" --check
    xcodegen generate
    xcodebuild -project ReaderRebuild.xcodeproj -scheme ReaderRebuild -configuration Debug \
      -destination "${READER_TEST_BUILD_DESTINATION:-$target}" -derivedDataPath "$derived" -parallelizeTargets -jobs 4 -showBuildTimingSummary \
      ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES \
      build-for-testing
    product="$derived/Build/Products/Debug-iphonesimulator/ReaderApp.app"
    # macOS can attach FinderInfo to generated package folders. Strip
    # only this metadata on the isolated output before strict validation.
    xattr -dr com.apple.FinderInfo "$product" 2>/dev/null || true
    codesign --verify --deep --strict "$product"
    codesign -d -v "$product"
    hosted="$product/PlugIns/ReaderAppTests.xctest"
    if [[ ! -d "$hosted" ]]; then hosted="$(dirname "$product")/ReaderAppTests.xctest"; fi
    python3 Scripts/check-bundle.py "$product" "$hosted"
    ui_runner="$(dirname "$product")/ReaderAppUITests-Runner.app"
    xattr -dr com.apple.FinderInfo "$ui_runner" 2>/dev/null || true
    codesign --verify --deep --strict "$ui_runner"
    codesign -d -v "$ui_runner"
    ;;
  write|cold|wave2write|wave2cold|design|m2host|m2edit|m2write|m2cold|m2ui|m2ui-source|m2ui-online|m3write|m3cold|m3speech)
    shopt -s nullglob
    runs=("$derived"/Build/Products/*.xctestrun)
    [[ ${#runs[@]} -eq 1 ]]
    timeout=120
    if [[ "$mode" == m3write ]]; then
      tests=(-only-testing:ReaderAppTests/M3MangaTests/test01LoopbackTransferRetryTilesBudgetAndSave)
    elif [[ "$mode" == m3cold ]]; then
      tests=(-only-testing:ReaderAppTests/M3MangaTests/test02IndependentProcessRestoresLogicalPageAndPoint)
    elif [[ "$mode" == m3speech ]]; then
      tests=(-only-testing:ReaderAppTests/M3SpeechTests)
    elif [[ "$mode" == wave2write ]]; then
      tests=(
        -only-testing:ReaderAppTests/Wave2CoreTextTests
        -only-testing:ReaderAppTests/Wave2ProductJourneyTests/test01ProductImportDetailReadBookmarkAndSave
      )
    elif [[ "$mode" == wave2cold ]]; then
      tests=(-only-testing:ReaderAppTests/Wave2ProductJourneyTests/test02ProductIndependentColdRestoresThreeNativeAnchors)
    elif [[ "$mode" == write ]]; then
      tests=(
        -only-testing:ReaderAppTests/ClientsRPCIntegrationTests/test01FreshImportWriteAndFence
        -only-testing:ReaderAppTests/ClientsRPCIntegrationTests/test03CapabilityRejectionAndReverseTerminals
        -only-testing:ReaderAppTests/EbookRuntimeIntegrationTests/test04WebKitImportSelectReflowSaveAndRejectOldDocument
      )
    elif [[ "$mode" == cold ]]; then
      tests=(
        -only-testing:ReaderAppTests/ClientsRPCIntegrationTests/test02ColdProcessReadAndExisting47
        -only-testing:ReaderAppTests/EbookRuntimeIntegrationTests/test05ColdProcessRestoresVisibleEpubAnchor
      )
    elif [[ "$mode" == design ]]; then
      tests=(-only-testing:ReaderAppTests/DesignContractTests)
    elif [[ "$mode" == m2host ]]; then
      tests=(-only-testing:ReaderAppTests/M2NetworkHostTests)
    elif [[ "$mode" == m2edit ]]; then
      tests=(-only-testing:ReaderAppTests/M2BusinessJourneyTests/test05ConditionalSourceEditConflictsAndPreservesRules)
    elif [[ "$mode" == m2write ]]; then
      tests=(
        -only-testing:ReaderAppTests/M2BusinessJourneyTests/test01SourceManagementV9Transactions
        -only-testing:ReaderAppTests/M2BusinessJourneyTests/test02SearchOnlineReadingAndSourceSwitch
        -only-testing:ReaderAppTests/M2BusinessJourneyTests/test03DownloadControlsAndWriteColdReceipt
      )
    elif [[ "$mode" == m2ui* ]]; then
      selector="-only-testing:ReaderAppUITests/M2ProductUITests"
      case "$mode" in
        m2ui-source) selector="$selector/test01SourceV9ThroughProductUI" ;;
        m2ui-online) selector="$selector/test02SearchReadSwitchAndDownloadThroughProductUI" ;;
      esac
      tests=("$selector")
      timeout=360
    else
      tests=(-only-testing:ReaderAppTests/M2BusinessJourneyTests/test04ColdProcessRecoversOriginalDownload)
    fi
    xcodebuild -xctestrun "${runs[0]}" -destination "$target" -parallel-testing-enabled NO \
      -test-timeouts-enabled YES -default-test-execution-time-allowance "$timeout" \
      -collect-test-diagnostics never -resultBundlePath "$evidence/$mode.xcresult" \
      "${tests[@]}" test-without-building
    ;;
  *) exit 2 ;;
esac
