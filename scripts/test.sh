#!/usr/bin/env bash
set -euo pipefail
ios_root="$(cd "$(dirname "$0")/.." && pwd)"
destination=''
test_target=ReaderTests
selectors=()
while (( $# > 0 )); do
  case "$1" in
    --destination) destination="${2:?--destination requires an exact simulator destination}"; shift 2 ;;
    --target) test_target="${2:?--target requires ReaderTests or ReaderUITests}"; shift 2 ;;
    --only) selectors+=("${2:?--only requires a class or class/method}"); shift 2 ;;
    --help)
      echo 'Usage: scripts/test.sh --destination platform=iOS\ Simulator,id=<UDID> [--target ReaderTests|ReaderUITests] --only Class[/method] [--only ...]'
      echo 'Runs only explicitly selected tests using the existing Core artifact.'
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
if [[ -z "$destination" || ${#selectors[@]} == 0 ]]; then
  echo 'An exact simulator destination and at least one --only selector are required.' >&2
  exit 2
fi
case "$destination" in *id=*) ;; *) echo 'Select a simulator by UDID using id=.' >&2; exit 2 ;; esac
case "$test_target" in
  ReaderTests) test_scheme=ReaderUnit ;;
  ReaderUITests) test_scheme=Reader ;;
  *) echo 'Expected ReaderTests or ReaderUITests.' >&2; exit 2 ;;
esac
selected_tests=()
for selector in "${selectors[@]}"; do
  if [[ ! "$selector" =~ ^[A-Za-z_][A-Za-z_0-9]*(/[A-Za-z_][A-Za-z_0-9]*)?$ ]]; then
    echo "Expected an exact test class or class/method: $selector" >&2
    exit 2
  fi
  selected_tests+=("-only-testing:$test_target/$selector")
done
python3 "$ios_root/scripts/core-dependency.py" verify-framework
bash "$ios_root/scripts/generate-project.sh"
test_derived="$(python3 "$ios_root/scripts/build-paths.py" --kind test-derived)"
test_command=(xcodebuild -project "$ios_root/Reader.xcodeproj" -scheme "$test_scheme"
  -configuration Debug -sdk iphonesimulator -destination "$destination"
  -derivedDataPath "$test_derived"
  -collect-test-diagnostics never
  "${selected_tests[@]}" ARCHS=arm64 ONLY_ACTIVE_ARCH=YES)
# Verify the compiled host before running the selected methods. This does not
# add a test suite or rebuild Core; test-without-building uses these products.
"${test_command[@]}" build-for-testing
python3 "$ios_root/scripts/verify-simulator-identity.py" \
  --app "$test_derived/Build/Products/Debug-iphonesimulator/Reader.app"
"${test_command[@]}" test-without-building
