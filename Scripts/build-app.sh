#!/usr/bin/env bash
# A package build only. No signing, installation or tests.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Scripts/sync-inputs.py --check
test -f .build/framework-receipt.json
xcodegen generate
derived="${1:-$PWD/.build/app-derived}"
xcodebuild -project ReaderRebuild.xcodeproj -scheme ReaderRebuild -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$derived" \
  -parallelizeTargets -jobs 4 -showBuildTimingSummary \
  CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
python3 Scripts/check-bundle.py "$derived/Build/Products/Debug-iphonesimulator/ReaderApp.app"
