#!/usr/bin/env bash
# Materialize the Rust Reader-Core-Native C ABI + static libraries for
# macOS-hosted and iOS-simulator SwiftPM/swiftc testing of ReaderCoreNativeAdapter.
#
# This is a LOCAL DEV helper: the materialized libreader_core.a / libreader_core_sim.a
# are built artifacts and are gitignored. Headers (reader_core.h, module.modulemap)
# are committed in cabi/; this script refreshes the static libs (and can refresh
# headers too with --refresh-headers).
#
# Usage:
#   bash iOS/ReaderCoreNativeAdapter/fetch-cabi.sh              # macOS host lib only
#   bash iOS/ReaderCoreNativeAdapter/fetch-cabi.sh --sim        # also iOS-sim lib
#   READER_CORE_NATIVE=/path/to/Reader-Core-Native bash .../fetch-cabi.sh
#   bash .../fetch-cabi.sh --refresh-headers
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cabi_dir="${script_dir}/cabi"
native_root="${READER_CORE_NATIVE:-${script_dir}/../../../Reader-Core-Native}"

if [[ ! -d "$native_root" ]]; then
  echo "fetch-cabi: READER_CORE_NATIVE not found at $native_root" >&2
  echo "set READER_CORE_NATIVE to your Reader-Core-Native checkout" >&2
  exit 1
fi

header_src="$native_root/include/reader_core.h"
modulemap_src="$native_root/bindings/ios/module.modulemap"

refresh_headers=0
fetch_sim=0
for arg in "$@"; do
  case "$arg" in
    --refresh-headers) refresh_headers=1 ;;
    --sim) fetch_sim=1 ;;
    *) echo "fetch-cabi: unknown flag $arg" >&2; exit 1 ;;
  esac
done

if (( refresh_headers == 1 )); then
  echo "fetch-cabi: refreshing headers from $native_root"
  cp "$header_src" "$cabi_dir/reader_core.h"
  cp "$modulemap_src" "$cabi_dir/module.modulemap"
fi

# Build the macOS host static library if missing.
host_lib="$native_root/target/debug/libreader_core.a"
if [[ ! -f "$host_lib" ]]; then
  echo "fetch-cabi: building macOS host libreader_core.a"
  (cd "$native_root" && cargo build -p reader-ffi)
fi

# Materialize the macOS lib into cabi/ (gitignored).
cp "$host_lib" "$cabi_dir/libreader_core.a"
echo "fetch-cabi: materialized $cabi_dir/libreader_core.a (macOS arm64)"
echo "fetch-cabi: headers in $cabi_dir (reader_core.h, module.modulemap)"

# Optionally materialize the iOS-simulator static library (arm64, platform 7).
if (( fetch_sim == 1 )); then
  sim_lib="$native_root/target/aarch64-apple-ios-sim/release/libreader_core.a"
  if [[ ! -f "$sim_lib" ]]; then
    echo "fetch-cabi: building iOS-sim libreader_core_sim.a (aarch64-apple-ios-sim, release)"
    (cd "$native_root" && cargo build -p reader-ffi --release --target aarch64-apple-ios-sim)
  fi
  cp "$sim_lib" "$cabi_dir/libreader_core_sim.a"
  echo "fetch-cabi: materialized $cabi_dir/libreader_core_sim.a (iOS-sim arm64)"
fi

