#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

readonly restricted_paths=(
  "iOS/App"
  "iOS/CoreIntegration"
  "iOS/Features"
  "iOS/Modules"
  "iOS/Shell"
)

readonly forbidden_modules=(
  "ReaderCoreNetwork"
  "ReaderCoreParser"
  "ReaderCoreCache"
  "ReaderCoreExecution"
)

readonly forbidden_root_paths=(
  "Core"
  "samples"
  "tools"
  "Adapters"
  "Platforms"
  "Package.swift"
)

readonly forbidden_workflows=(
  "core-swift-tests.yml"
  "fixture-toc-regression-macos.yml"
  "policy-regression-macos.yml"
  "sample001-nonjs-smoke.yml"
  "sample-cookie-001-isolation.yml"
  "sample-cookie-002-isolation.yml"
  "sample-login-001-isolation.yml"
  "sample-login-002-isolation.yml"
  "sample-login-003-isolation.yml"
  "auto-sample-extractor.yml"
)

readonly forbidden_docs=(
  "docs/API_SNAPSHOT"
  "docs/FIXTURE_INFRA_SPEC.md"
  "docs/TOOLING_BACKLOG.md"
  "docs/architecture"
  "docs/decision_engine"
  "docs/process"
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

check_forbidden_presence() {
  local relative_path="$1"
  if [[ -e "${repo_root}/${relative_path}" ]]; then
    violations+=("presence:${relative_path}")
  fi
}

check_forbidden_workflow() {
  local workflow_name="$1"
  if [[ -e "${repo_root}/.github/workflows/${workflow_name}" ]]; then
    violations+=("workflow:${workflow_name}")
  fi
}

check_forbidden_reference() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  local line
  while IFS= read -r line; do
    violations+=("${file}:${line}:${label}")
  done < <(grep -nE "${pattern}" "$file" || true)
}

for relative_path in "${forbidden_root_paths[@]}"; do
  check_forbidden_presence "$relative_path"
done

for relative_path in "${forbidden_docs[@]}"; do
  check_forbidden_presence "$relative_path"
done

for workflow_name in "${forbidden_workflows[@]}"; do
  check_forbidden_workflow "$workflow_name"
done

operational_files=(
  "${repo_root}/iOS/Package.swift"
  "${repo_root}/.github/workflows/ios-shell-ci.yml"
)

for file in "${operational_files[@]}"; do
  [[ -f "${file}" ]] || continue
  check_forbidden_reference "$file" "\\.package\\(path:[[:space:]]*\"\\.\\./Core\"\\)" "legacy_core_path_dependency"
  check_forbidden_reference "$file" "\\.\\./Reader-for-iOS|\\.\\./iOS|\\.\\./\\.\\./Reader-for-iOS/Core" "split_leak_path_reference"
done

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
echo "forbidden_root_paths=${forbidden_root_paths[*]}"
echo "forbidden_docs=${forbidden_docs[*]}"
echo "forbidden_workflows=${forbidden_workflows[*]}"

if (( ${#violations[@]} > 0 )); then
  echo "result=FAIL"
  for violation in "${violations[@]}"; do
    if [[ "${violation}" == presence:* ]]; then
      echo "violation kind=forbidden_presence path=${violation#presence:}"
      continue
    fi
    if [[ "${violation}" == workflow:* ]]; then
      echo "violation kind=forbidden_workflow file=.github/workflows/${violation#workflow:}"
      continue
    fi
    IFS=":" read -r file line_no module <<< "${violation}"
    echo "violation file=${file#${repo_root}/} line=${line_no} marker=${module}"
  done
  exit 1
fi

echo "result=PASS"
