#!/bin/bash
# iOS-simulator-hosted ShellSmokeTests for ReaderCoreNativeAdapter.
#
# Cross-compiles (with swiftc) the adapter and smoke tests against the
# iOS-simulator libreader_core_sim.a from Reader-Core-Native, then runs the
# resulting Mach-O iOS-sim executable directly inside a booted iPhone simulator
# via `xcrun simctl spawn`. Does NOT pull in the ReaderApp dependency tree.
#
# Prerequisite: run `fetch-cabi.sh --sim` first to materialize libreader_core_sim.a.
# Prerequisite: a booted iPhone simulator (script will boot 'iPhone 17' if none).
#
# Evidence discipline: same source as run-shell-smoke.sh (macOS host), but
# executed on iOS Simulator. Simulator smoke ≠ device completion.
#
# Usage: bash ./run-sim-smoke.sh

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cabi_dir="$script_dir/cabi"
adapter_source="$script_dir/ReaderCoreNativeRuntime.swift"
smoke_source="$script_dir/ShellSmokeTests/host_adapter_smoke.swift"
sim_lib="$cabi_dir/libreader_core_sim.a"
report_file="$script_dir/sim-smoke-report.txt"

echo "=== ReaderCoreNativeAdapter iOS-Simulator ShellSmokeTests ==="
echo "cabi-dir: $cabi_dir"
echo "lib: $sim_lib"
echo ""

# Check that the iOS-sim lib exists.
if [[ ! -f "$sim_lib" ]]; then
    echo "ERROR: $sim_lib does not exist. Run $script_dir/fetch-cabi.sh --sim first." >&2
    exit 1
fi

set +e
# Verify the lib is actually an iOS-sim build (platform 7).
# otool on archive inputs returns non-zero even on success; capture output
# without pipefail tripping by separating the otool and awk calls.
otool_out="$(otool -arch arm64 -l "$sim_lib" 2>&1 || true)"
plat="$(printf '%s\n' "$otool_out" | awk '/platform /{print $2; exit}')"
plat="${plat:-unknown}"
set -e
if [[ "$plat" != "7" ]]; then
    echo "ERROR: $sim_lib is not an iOS-simulator build (platform 7); got platform '${plat:-unknown}'." >&2
    echo "Re-run: READER_CORE_NATIVE=... bash $script_dir/fetch-cabi.sh --sim" >&2
    exit 1
fi
echo "lib platform: $plat (iOS Simulator)"
echo ""

# Locate a booted iPhone simulator; boot one if none is booted.
booted_udid="$(xcrun simctl list devices booted 2>/dev/null | awk -F '[()]' '/iPhone.*Booted/{print $2; exit}')"
if [[ -z "$booted_udid" ]]; then
    echo "=== no booted iPhone simulator; booting 'iPhone 17' ==="
    xcrun simctl boot 'iPhone 17' >/dev/null 2>&1 || true
    # Wait for boot to complete (best-effort).
    xcrun simctl bootstatus 'iPhone 17' -b >/dev/null 2>&1 || true
    booted_udid="$(xcrun simctl list devices booted 2>/dev/null | awk -F '[()]' '/iPhone.*Booted/{print $2; exit}')"
fi
if [[ -z "$booted_udid" ]]; then
    echo "ERROR: could not find/boot an iPhone simulator." >&2
    exit 1
fi
echo "simulator UDID: $booted_udid"
echo ""

# Create temp build dir.
tmp_dir="$(mktemp -d -t reader-ios-sim-smoke)"
trap 'rm -rf "$tmp_dir"' EXIT

# Cross-compile to iOS-simulator arm64.
echo "=== compiling with swiftc (iOS-sim arm64 target) ==="
swiftc \
    -target arm64-apple-ios17.0-simulator \
    -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
    -I "$cabi_dir" \
    "$adapter_source" \
    "$smoke_source" \
    "$sim_lib" \
    -o "$tmp_dir/reader-core-native-sim-smoke" 2>&1 | grep -v "^ld: warning:" || true

echo "=== running inside iPhone simulator ==="
echo ""
# simctl spawn runs the iOS-sim binary directly inside the booted simulator.
xcrun simctl spawn "$booted_udid" "$tmp_dir/reader-core-native-sim-smoke" 2>&1 | tee "$report_file"
