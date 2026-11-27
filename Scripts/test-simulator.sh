#!/usr/bin/env bash
# An explicit, already-authorized, isolated iOS Simulator is required.
# The two process phases share only synthetic data in the test app's container.
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:?usage: test-simulator.sh build|write|cold <UDID> <derived> <evidence>}"
device="${2:?isolated simulator UDID required}"
derived="${3:?isolated DerivedData path required}"
evidence="${4:?immutable evidence directory required}"
mkdir -p "$evidence"
target="platform=iOS Simulator,id=$device"
case "$mode" in
  build)
    python3 Scripts/sync-inputs.py --check
    test -f .build/framework-receipt.json
    xcodegen generate
    xcodebuild -project ReaderRebuild.xcodeproj -scheme ReaderRebuild -configuration Debug \
      -destination "$target" -derivedDataPath "$derived" -parallelizeTargets -jobs 4 -showBuildTimingSummary \
      ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES \
      build-for-testing
    product="$derived/Build/Products/Debug-iphonesimulator/ReaderApp.app"
    codesign --verify --deep --strict "$product"
    codesign -d -v "$product"
    hosted="$product/PlugIns/ReaderAppTests.xctest"
    if [[ ! -d "$hosted" ]]; then hosted="$(dirname "$product")/ReaderAppTests.xctest"; fi
    python3 Scripts/check-bundle.py "$product" "$hosted"
    ;;
  write|cold)
    shopt -s nullglob
    runs=("$derived"/Build/Products/*.xctestrun)
    [[ ${#runs[@]} -eq 1 ]]
    if [[ "$mode" == write ]]; then
      tests=(
        -only-testing:ReaderAppTests/ClientsRPCIntegrationTests/test01FreshImportWriteAndFence
        -only-testing:ReaderAppTests/ClientsRPCIntegrationTests/test03CapabilityRejectionAndReverseTerminals
        -only-testing:ReaderAppTests/EbookRuntimeIntegrationTests/test04WebKitImportSelectReflowSaveAndRejectOldDocument
      )
    else
      tests=(
        -only-testing:ReaderAppTests/ClientsRPCIntegrationTests/test02ColdProcessReadAndExisting47
        -only-testing:ReaderAppTests/EbookRuntimeIntegrationTests/test05ColdProcessRestoresVisibleEpubAnchor
      )
    fi
    xcodebuild -xctestrun "${runs[0]}" -destination "$target" -parallel-testing-enabled NO \
      -test-timeouts-enabled YES -default-test-execution-time-allowance 60 \
      -collect-test-diagnostics never -resultBundlePath "$evidence/$mode.xcresult" \
      "${tests[@]}" test-without-building
    ;;
  *) exit 2 ;;
esac
