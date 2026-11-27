#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
workspace="$(cd "$project/../.." && pwd)"
pin="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["core"])' "$project/Scripts/pins.json")"
snapshot="$project/.build/core-source/$pin"
mkdir -p "$(dirname "$snapshot")"
# Extract an immutable Git object, independently of the current Core checkout.
scratch="$(mktemp -d "$project/.build/core-source/input.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
git -C "$workspace/Reader-Core" archive "$pin" > "$scratch/source.tar"
shasum -a 256 "$scratch/source.tar" | awk '{print $1}' > "$project/.build/core-source.sha256"
mkdir "$scratch/checkout"
tar -xf "$scratch/source.tar" -C "$scratch/checkout"
if [[ ! -d "$snapshot/.git" ]]; then
  git clone --quiet --shared --no-checkout "$workspace/Reader-Core" "$scratch/identity"
  if [[ ! -d "$snapshot" ]]; then mv "$scratch/checkout" "$snapshot"; fi
  mv "$scratch/identity/.git" "$snapshot/.git"
  git -C "$snapshot" update-ref --no-deref HEAD "$pin"
  git -C "$snapshot" read-tree HEAD
fi
test "$(git -C "$snapshot" rev-parse HEAD)" = "$pin"
test -z "$(git -C "$snapshot" status --porcelain --untracked-files=all)"
node "$snapshot/scripts/build-input-snapshot.mjs" capture "$project/.build/core-inputs.json"

(
  cd "$snapshot"
  export CARGO_TARGET_DIR="$project/.build/core-target"
  export IOS_XCFRAMEWORK_OUTPUT="$project/.build/ReaderCore.xcframework"
  export IOS_TARGETS=aarch64-apple-ios-sim IPHONEOS_DEPLOYMENT_TARGET=17.0
  export READER_CORE_BUILD_IDENTITY_OUTPUT="$project/.build/core-build-identity.json"
  export CLANG_MODULE_CACHE_PATH="$project/.build/clang-module-cache"
  bash scripts/build-ios-xcframework.sh "$@"
)
node "$snapshot/scripts/build-input-snapshot.mjs" verify "$project/.build/core-inputs.json"
python3 "$project/Scripts/framework-receipt.py" "$project"
