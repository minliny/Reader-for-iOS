#!/usr/bin/env bash
set -euo pipefail
ios_root="$(cd "$(dirname "$0")/.." && pwd)"
core_manifest_args=()
if (( $# > 0 )); then
  if [[ "$1" != "--local-core-manifest" || $# != 2 ]]; then
    echo 'Usage: scripts/generate-project.sh [--local-core-manifest PATH]' >&2; exit 2
  fi
  core_manifest_args=(--local-core-manifest "$2")
fi
python3 "$ios_root/scripts/core-dependency.py" sync "${core_manifest_args[@]}"
cd "$ios_root"
xcodegen generate --spec project.yml
