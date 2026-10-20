#!/usr/bin/env bash
set -euo pipefail

ios_root="$(cd "$(dirname "$0")/.." && pwd)"
platform=simulator
while (( $# > 0 )); do
  case "$1" in
    --platform) platform="${2:?--platform requires simulator, device or all}"; shift 2 ;;
    --help)
      echo 'Usage: scripts/build-core.sh [--platform simulator|device|all]'
      echo 'Compiles and packages only Reader Core. No test or Swift smoke is run.'
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$platform" in
  simulator) ios_targets='aarch64-apple-ios-sim' ;;
  device) ios_targets='aarch64-apple-ios' ;;
  all) ios_targets='aarch64-apple-ios aarch64-apple-ios-sim' ;;
  *) echo "Unknown platform: $platform" >&2; exit 2 ;;
esac

python3 "$ios_root/scripts/core-dependency.py" sync
core_snapshot="$(python3 "$ios_root/scripts/core-dependency.py" snapshot)"
CARGO_TARGET_DIR="$ios_root/.build/core-target" \
IOS_XCFRAMEWORK_OUTPUT="$ios_root/.build/ReaderCore.xcframework" \
IOS_TARGETS="$ios_targets" \
IPHONEOS_DEPLOYMENT_TARGET=17.0 \
  bash "$core_snapshot/scripts/build-ios-xcframework.sh"
python3 "$ios_root/scripts/core-dependency.py" record-framework --source "$core_snapshot" --deployment-target 17.0
