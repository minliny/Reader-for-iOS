#!/usr/bin/env bash
# Materialize the Rust Reader-Core-Native C ABI + macOS static library for
# macOS-hosted SwiftPM testing of ReaderCoreNativeAdapter.
#
# This is a LOCAL DEV helper: the materialized libreader_core.a is a built
# artifact and is gitignored. Headers (reader_core.h, module.modulemap) are
# committed in cabi/; this script refreshes the static lib only (and can
# refresh headers too with --refresh-headers).
#
# Usage:
#   bash iOS/ReaderCoreNativeAdapter/fetch-cabi.sh
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
if [[ "${1:-}" == "--refresh-headers" ]]; then
  refresh_headers=1
fi

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

# Materialize the lib into cabi/ (gitignored).
cp "$host_lib" "$cabi_dir/libreader_core.a"
echo "fetch-cabi: materialized $cabi_dir/libreader_core.a"
echo "fetch-cabi: headers in $cabi_dir (reader_core.h, module.modulemap)"
