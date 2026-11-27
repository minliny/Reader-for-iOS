#!/usr/bin/env bash
# All rendering and baseline output belongs to the isolated hosted XCTest app.
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:?usage: test-goldens.sh record|record-m2|record-m3|verify|verify-m1|verify-m2|verify-m3 <simulator UDID> <DerivedData> <evidence>}"
device="${2:?dedicated simulator required}"
derived="${3:?prepared build-for-testing DerivedData required}"
evidence="${4:?distinct evidence directory required}"
selector=-only-testing:ReaderAppTests/Wave2GoldenTests
record_flag=""
case "$mode" in
  record)         selector="$selector/testM1Goldens"; record_flag=READER_RECORD_GOLDENS; milestone=M1 ;;
  record-m2)      selector="$selector/testM2Goldens"; record_flag=READER_RECORD_M2_GOLDENS; milestone=M2 ;;
  record-m3)      selector="$selector/testM3Goldens"; record_flag=READER_RECORD_M3_GOLDENS; milestone=M3 ;;
  verify-m3)      selector="$selector/testM3Goldens" ;;
  verify-m1)      selector="$selector/testM1Goldens" ;;
  verify-m2)      selector="$selector/testM2Goldens" ;;
  verify) ;;
  *) exit 2 ;;
esac
mkdir -p "$evidence"
shopt -s nullglob
runs=("$derived"/Build/Products/*.xctestrun)
[[ ${#runs[@]} -eq 1 ]]
run="${runs[0]}"
if [[ -n "$record_flag" ]]; then
  # Keep __TESTROOT__ relative to the same Build/Products directory.
  temporary="$(mktemp "$(dirname "$run")/.golden-record.XXXXXXXX")"
  configured="${temporary}.xctestrun"
  mv "$temporary" "$configured"
  trap 'rm -f "$configured"' EXIT
  record_run="$(python3 -c 'import uuid; print(uuid.uuid4().hex)')"
  python3 - "$run" "$configured" "$record_flag" "$record_run" <<'PY'
import plistlib
import sys
with open(sys.argv[1], "rb") as source:
    run = plistlib.load(source)
host = run["ReaderAppTests"]
assert host["TestHostBundleIdentifier"] == "io.reader.minliny.rebuild.m1"
environment = host.setdefault("EnvironmentVariables", {})
environment[sys.argv[3]] = "1"
environment["READER_GOLDEN_RECORD_RUN"] = sys.argv[4]
with open(sys.argv[2], "wb") as output:
    plistlib.dump(run, output, sort_keys=False)
PY
  run="$configured"
fi

xcodebuild -xctestrun "$run" -destination "platform=iOS Simulator,id=$device" -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 90 -collect-test-diagnostics never \
  -resultBundlePath "$evidence/goldens-$mode.xcresult" \
  "$selector" test-without-building

if [[ -n "$record_flag" ]]; then
  container="$(xcrun simctl get_app_container "$device" io.reader.minliny.rebuild.m1 data)"
  source="$container/Documents/Reader${milestone}Goldens/$record_run"
  mkdir "$evidence/recorded"
  cp "$source"/manifest.json "$source"/*.png "$evidence/recorded/"
fi
