#!/usr/bin/env bash
# All rendering and baseline output belongs to the isolated hosted XCTest app.
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:?usage: test-goldens.sh record|verify <simulator UDID> <DerivedData> <evidence>}"
device="${2:?dedicated simulator required}"
derived="${3:?prepared build-for-testing DerivedData required}"
evidence="${4:?distinct evidence directory required}"
case "$mode" in record|verify) ;; *) exit 2 ;; esac
mkdir -p "$evidence"
shopt -s nullglob
runs=("$derived"/Build/Products/*.xctestrun)
[[ ${#runs[@]} -eq 1 ]]
run="${runs[0]}"
if [[ "$mode" == record ]]; then
  # Keep __TESTROOT__ relative to the same Build/Products directory.
  temporary="$(mktemp "$(dirname "$run")/.golden-record.XXXXXXXX")"
  configured="${temporary}.xctestrun"
  mv "$temporary" "$configured"
  trap 'rm -f "$configured"' EXIT
  python3 - "$run" "$configured" <<'PY'
import plistlib
import sys
with open(sys.argv[1], "rb") as source:
    run = plistlib.load(source)
host = run["ReaderAppTests"]
assert host["TestHostBundleIdentifier"] == "io.reader.minliny.rebuild.m1"
host.setdefault("EnvironmentVariables", {})["READER_RECORD_GOLDENS"] = "1"
with open(sys.argv[2], "wb") as output:
    plistlib.dump(run, output, sort_keys=False)
PY
  run="$configured"
fi

xcodebuild -xctestrun "$run" -destination "platform=iOS Simulator,id=$device" -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 90 -collect-test-diagnostics never \
  -resultBundlePath "$evidence/goldens-$mode.xcresult" \
  -only-testing:ReaderAppTests/Wave2GoldenTests/testM1Goldens test-without-building

if [[ "$mode" == record ]]; then
  container="$(xcrun simctl get_app_container "$device" io.reader.minliny.rebuild.m1 data)"
  source="$container/Documents/ReaderM1Goldens"
  mkdir "$evidence/recorded"
  cp "$source"/manifest.json "$source"/*.png "$evidence/recorded/"
fi
