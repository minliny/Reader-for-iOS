#!/usr/bin/env bash
set -euo pipefail
ios_root="$(cd "$(dirname "$0")/.." && pwd)"
configuration=Debug
skip_core=0
while (( $# > 0 )); do
  case "$1" in
    --skip-core) skip_core=1; shift ;;
    --configuration) configuration="${2:?--configuration requires Debug or Release}"; shift 2 ;;
    --help)
      echo 'Usage: scripts/build.sh [--skip-core] [--configuration Debug|Release]'
      echo 'Builds the iOS Simulator app. Does not run tests, boot, install or launch.'
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$configuration" in Debug|Release) ;; *) echo 'Expected Debug or Release' >&2; exit 2 ;; esac
if (( skip_core == 0 )); then bash "$ios_root/scripts/build-core.sh" --platform simulator; fi
python3 "$ios_root/scripts/core-dependency.py" verify-framework
bash "$ios_root/scripts/generate-project.sh"
app_run_id="$(python3 "$ios_root/scripts/app-artifact.py" capture --configuration "$configuration")"
app_derived="$(python3 "$ios_root/scripts/build-paths.py" --kind app-derived)/$app_run_id"
app_artifacts="$(python3 "$ios_root/scripts/build-paths.py" --kind artifacts)"
xcodebuild -project "$ios_root/Reader.xcodeproj" -scheme Reader \
  -configuration "$configuration" -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$app_derived" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
python3 "$ios_root/scripts/verify-simulator-identity.py" \
  --app "$app_derived/Build/Products/$configuration-iphonesimulator/Reader.app"
python3 "$ios_root/scripts/core-dependency.py" verify-framework
python3 "$ios_root/scripts/app-artifact.py" record --configuration "$configuration" --run-id "$app_run_id"
python3 "$ios_root/scripts/verify-simulator-identity.py" --app "$app_artifacts/$app_run_id/Reader.app"
