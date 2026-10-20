#!/usr/bin/env bash
set -euo pipefail
ios_root="$(cd "$(dirname "$0")/.." && pwd)"
if (( $# > 0 )); then
  echo 'Usage: scripts/generate-project.sh (synchronizes pinned binding and generates Xcode project only)' >&2
  exit 2
fi
python3 "$ios_root/scripts/core-dependency.py" sync
cd "$ios_root"
xcodegen generate --spec project.yml
