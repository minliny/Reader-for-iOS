#!/bin/bash
# Standalone macOS-hosted ShellSmokeTests for ReaderCoreNativeAdapter.
#
# Compiles (with swiftc) the adapter and smoke tests against the materialized
# libreader_core.a from Reader-Core-Native, and runs directly without pulling
# in the entire ReaderApp dependency tree (which only builds on iOS/simulator).
#
# This matches the proven pattern from Native repository: bindings/ios/ShellSmokeTests/run.sh
#
# Usage: bash ./run-shell-smoke.sh after running fetch-cabi.sh

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"

# Path to the materialized C ABI + static library (created by fetch-cabi.sh)
cabi_dir="$script_dir/cabi"
adapter_source="$script_dir/ReaderCoreNativeRuntime.swift"
smoke_source="$script_dir/ShellSmokeTests/host_adapter_smoke.swift"
host_lib="$cabi_dir/libreader_core.a"

echo "=== ReaderCoreNativeAdapter standalone ShellSmokeTests ==="
echo "cabi-dir: $cabi_dir"
echo "lib: $host_lib"
echo ""

# Check that libreader_core.a exists
if [[ ! -f "$host_lib" ]]; then
    echo "ERROR: $host_lib does not exist. Run $script_dir/fetch-cabi.sh first." >&2
    exit 1
fi

# Create temp build dir
tmp_dir="$(mktemp -d -t reader-ios-host-smoke)"
trap 'rm -rf "$tmp_dir"' EXIT

# Compile
echo "=== compiling with swiftc (macOS arm64 target) ==="
swiftc \
    -target arm64-apple-macos13 \
    -I "$cabi_dir" \
    "$adapter_source" \
    "$smoke_source" \
    "$host_lib" \
    -o "$tmp_dir/reader-core-native-smoke"

echo "=== running ==="
echo ""
"$tmp_dir/reader-core-native-smoke"