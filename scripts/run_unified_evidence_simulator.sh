#!/bin/bash
# Runs UnifiedEvidenceRunner inside ReaderForIOSApp on a booted iOS Simulator.
# Produces a unified-evidence/1 artifact (evidence-run-ios-<timestamp>.json)
# covering all 15 canonical capabilities.
#
# Expected result after rss.parse/bookmark.crud/tts.queue wiring:
#   11 pass / 4 blocked (manga.pages.extract, local_book.parse, http-tts, sync.webdav)
#
# Usage:
#   scripts/run_unified_evidence_simulator.sh [--device "iPhone 17 Pro"] [--boot-if-needed]

set -euo pipefail

DEVICE="iPhone 17 Pro"
BUNDLE_ID="com.minliny.readerforios.s4proof"
BOOT_IF_NEEDED=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --device)
            DEVICE="$2"
            shift 2
            ;;
        --bundle-id)
            BUNDLE_ID="$2"
            shift 2
            ;;
        --boot-if-needed)
            BOOT_IF_NEEDED=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--device \"iPhone 17 Pro\"] [--bundle-id com.minliny.readerforios.s4proof] [--boot-if-needed]"
            exit 1
            ;;
    esac
done

PROJECT_DIR="/Users/minliny/Documents/Reader for iOS"
XCODEPROJ="$PROJECT_DIR/ReaderForIOS.xcodeproj"
SCHEME="ReaderForIOSApp"
EVIDENCE_DIR="$PROJECT_DIR/docs/frontend-complete-app/evidence/ios-s4-host-proof"

cd "$PROJECT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "Error: xcodegen is required to regenerate ReaderForIOS.xcodeproj from project.yml" >&2
    exit 1
fi

echo "Generating Xcode project..."
xcodegen generate >/dev/null

BOOTED_UDID=$(xcrun simctl list devices booted 2>/dev/null | awk -F '[()]' -v device="$DEVICE" '$0 ~ device && /Booted/{print $2; exit}')
if [[ -z "$BOOTED_UDID" && "$BOOT_IF_NEEDED" == "1" ]]; then
    echo "Booting $DEVICE..."
    xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true
    BOOTED_UDID=$(xcrun simctl list devices booted 2>/dev/null | awk -F '[()]' -v device="$DEVICE" '$0 ~ device && /Booted/{print $2; exit}')
fi

if [[ -z "$BOOTED_UDID" ]]; then
    echo "Error: no booted simulator named '$DEVICE'. Boot it first or pass --boot-if-needed." >&2
    exit 1
fi

echo "Building $SCHEME for $DEVICE..."
BUILD_OUTPUT=$(xcodebuild build \
    -project "$XCODEPROJ" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    CODE_SIGNING_ALLOWED=NO \
    2>&1)

if ! echo "$BUILD_OUTPUT" | grep -q "BUILD SUCCEEDED"; then
    echo "Error: build failed" >&2
    echo "$BUILD_OUTPUT" | tail -40
    exit 1
fi

BUILT_PRODUCTS_DIR=$(xcodebuild -project "$XCODEPROJ" -scheme "$SCHEME" -configuration Debug -destination "platform=iOS Simulator,name=$DEVICE" -showBuildSettings 2>/dev/null | awk '/BUILT_PRODUCTS_DIR/{print $3; exit}')
APP_PATH="$BUILT_PRODUCTS_DIR/$SCHEME.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: App not found at $APP_PATH" >&2
    exit 1
fi

echo "Uninstalling any previous install (clears data container)..."
xcrun simctl uninstall "$BOOTED_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "Installing app on $BOOTED_UDID..."
xcrun simctl install "$BOOTED_UDID" "$APP_PATH"

DATA_CONTAINER=$(xcrun simctl get_app_container "$BOOTED_UDID" "$BUNDLE_ID" data)
RESULT_ROOT="$DATA_CONTAINER/Documents/UnifiedEvidenceRuns"

echo "Launching unified evidence autorun..."
xcrun simctl terminate "$BOOTED_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
# Capture launch output to extract process PID for log streaming.
LAUNCH_OUTPUT=$(xcrun simctl launch "$BOOTED_UDID" "$BUNDLE_ID" \
    --unified-evidence-autorun \
    --unified-evidence-exit-after-run)
echo "$LAUNCH_OUTPUT"

# Wait for the artifact JSON to appear in the app's Documents directory.
LATEST_ARTIFACT=""
for _ in {1..60}; do
    if [[ -d "$RESULT_ROOT" ]]; then
        LATEST_ARTIFACT=$(find "$RESULT_ROOT" -mindepth 1 -maxdepth 1 -name "evidence-run-ios-*.json" -exec stat -f "%m %N" {} \; | sort -n | tail -1 | cut -d' ' -f2-)
        if [[ -n "$LATEST_ARTIFACT" && -f "$LATEST_ARTIFACT" ]]; then
            break
        fi
    fi
    sleep 0.5
done

if [[ -z "$LATEST_ARTIFACT" || ! -f "$LATEST_ARTIFACT" ]]; then
    echo "Error: unified evidence artifact not found under $RESULT_ROOT" >&2
    echo "Checking app launch log for errors..."
    xcrun simctl spawn "$BOOTED_UDID" log show --last 30s --predicate 'processImagePath CONTAINS "ReaderForIOSApp"' 2>&1 | tail -30 || true
    exit 1
fi

echo ""
echo "===== Unified Evidence Artifact ====="
echo "Source: $LATEST_ARTIFACT"
echo ""

# Copy artifact to the evidence directory with a stable name.
mkdir -p "$EVIDENCE_DIR"
SIM_ARTIFACT="$EVIDENCE_DIR/evidence-run-ios-simulator.json"
cp "$LATEST_ARTIFACT" "$SIM_ARTIFACT"
echo "Copied to: $SIM_ARTIFACT"
echo ""

# Print summary using python3.
if command -v python3 >/dev/null 2>&1; then
    python3 - "$SIM_ARTIFACT" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    artifact = json.load(fh)

summary = artifact.get("summary", {})
caps = artifact.get("capabilities", [])
print("===== Summary =====")
print(f"  schemaVersion : {artifact.get('schemaVersion')}")
print(f"  tier          : {artifact.get('tier')}")
print(f"  generatedAt   : {artifact.get('generatedAt')}")
print(f"  total         : {summary.get('total')}")
print(f"  passed        : {summary.get('passed')}")
print(f"  failed        : {summary.get('failed')}")
print(f"  skipped       : {summary.get('skipped')}  (blocked capabilities)")
print(f"  passRate      : {summary.get('passRate'):.4f}")
print()
print("===== Capabilities =====")
for cap in caps:
    status = cap.get("status")
    name = cap.get("capability")
    marker = "PASS" if status == "pass" else ("BLOCK" if status == "blocked" else ("FAIL" if status == "fail" else "SKIP"))
    extra = ""
    if status == "pass":
        extra = f"  method={cap.get('method', '')}  dur={cap.get('durationMs', '?')}ms"
    elif status == "blocked":
        extra = f"  error={cap.get('error', '')}"
    elif status == "fail":
        extra = f"  error={cap.get('error', '')}"
    print(f"  [{marker}] {name}{extra}")

# Validate expected counts: 11 pass / 4 blocked / 0 fail.
passed = summary.get("passed", 0)
blocked = sum(1 for c in caps if c.get("status") == "blocked")
failed = summary.get("failed", 0)
expected_pass = 11
expected_blocked = 4
ok = True
if passed != expected_pass:
    print(f"\nWARNING: expected {expected_pass} passed, got {passed}")
    ok = False
if blocked != expected_blocked:
    print(f"\nWARNING: expected {expected_blocked} blocked, got {blocked}")
    ok = False
if failed != 0:
    print(f"\nWARNING: expected 0 failed, got {failed}")
    ok = False
if ok:
    print(f"\nVALIDATED: {passed} pass / {blocked} blocked / {failed} fail (expected {expected_pass}/{expected_blocked}/0)")
else:
    print(f"\nVALIDATION FAILED: counts do not match expected {expected_pass}/{expected_blocked}/0")
    sys.exit(1)
PY
else
    echo "python3 not available; printing raw artifact:"
    cat "$SIM_ARTIFACT"
fi
