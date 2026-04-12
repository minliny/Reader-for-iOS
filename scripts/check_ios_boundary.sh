#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

readonly restricted_paths=(
  "iOS/App"
  "iOS/CoreIntegration"
  "iOS/Features"
)

readonly forbidden_modules=(
  "ReaderCoreNetwork"
  "ReaderCoreParser"
  "ReaderCoreCache"
  "ReaderCoreExecution"
)

violations=()
checked_files=0

check_file() {
  local file="$1"
  local line

  for module in "${forbidden_modules[@]}"; do
    while IFS= read -r line; do
      violations+=("${file}:${line}:${module}")
    done < <(grep -nE "^[[:space:]]*import[[:space:]]+${module}([[:space:]]|$)" "$file" || true)
  done
}

for relative_path in "${restricted_paths[@]}"; do
  absolute_path="${repo_root}/${relative_path}"
  if [[ ! -d "${absolute_path}" ]]; then
    continue
  fi

  while IFS= read -r file; do
    checked_files=$((checked_files + 1))
    check_file "$file"
  done < <(find "${absolute_path}" -type f -name "*.swift" | sort)
done

echo "iOS boundary gate"
echo "checked_files=${checked_files}"
echo "restricted_paths=${restricted_paths[*]}"
echo "forbidden_modules=${forbidden_modules[*]}"

if (( ${#violations[@]} > 0 )); then
  echo "result=FAIL"
  for violation in "${violations[@]}"; do
    IFS=":" read -r file line_no module <<< "${violation}"
    echo "violation file=${file#${repo_root}/} line=${line_no} import=${module}"
  done
  exit 1
fi

echo "result=PASS"
