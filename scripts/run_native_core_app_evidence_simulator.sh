#!/bin/bash
# Runs Native Rust Core ABI/protocol evidence inside ReaderForIOSApp on a booted
# iOS Simulator. This is App-process evidence: wrapper smoke and simulator
# standalone smoke remain separate evidence layers.

set -euo pipefail

DEVICE="iPhone 17 Pro"
BUNDLE_ID="com.reader.ios"
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
            echo "Usage: $0 [--device \"iPhone 17 Pro\"] [--bundle-id com.reader.ios] [--boot-if-needed]"
            exit 1
            ;;
    esac
done

PROJECT_DIR="/Users/minliny/Documents/Reader for iOS"
XCODEPROJ="$PROJECT_DIR/ReaderForIOS.xcodeproj"
SCHEME="ReaderForIOSApp"

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

echo "Installing app on $BOOTED_UDID..."
xcrun simctl install "$BOOTED_UDID" "$APP_PATH"

echo "Launching app evidence autorun..."
xcrun simctl terminate "$BOOTED_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl launch "$BOOTED_UDID" "$BUNDLE_ID" \
    --native-core-evidence-autorun \
    --native-core-evidence-exit-after-run

DATA_CONTAINER=$(xcrun simctl get_app_container "$BOOTED_UDID" "$BUNDLE_ID" data)
RESULT_ROOT="$DATA_CONTAINER/Documents/NativeCoreEvidenceRuns"

echo "Waiting for native_core_evidence_status.json and native_core_evidence.json..."
LATEST_RUN=""
for _ in {1..40}; do
    if [[ -d "$RESULT_ROOT" ]]; then
        LATEST_RUN=$(find "$RESULT_ROOT" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)
        if [[ -n "$LATEST_RUN" && -f "$LATEST_RUN/native_core_evidence_status.json" && -f "$LATEST_RUN/native_core_evidence.json" ]]; then
            break
        fi
    fi
    sleep 0.5
done

if [[ -z "$LATEST_RUN" || ! -f "$LATEST_RUN/native_core_evidence_status.json" || ! -f "$LATEST_RUN/native_core_evidence.json" ]]; then
    echo "Error: complete native core evidence files not found under $RESULT_ROOT" >&2
    exit 1
fi

STATUS_FILE="$LATEST_RUN/native_core_evidence_status.json"
EVIDENCE_FILE="$LATEST_RUN/native_core_evidence.json"

echo ""
echo "===== Native Core Evidence Run ====="
echo "$LATEST_RUN"
echo ""
echo "===== native_core_evidence_status.json ====="
cat "$STATUS_FILE"
echo ""

echo ""
echo "===== native_core_evidence.json ====="
cat "$EVIDENCE_FILE"
echo ""

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required to validate native_core_evidence.json" >&2
    exit 1
fi

python3 - "$STATUS_FILE" "$EVIDENCE_FILE" <<'PY'
import json
import sys

status_path, evidence_path = sys.argv[1], sys.argv[2]
with open(status_path, "r", encoding="utf-8") as fh:
    status = json.load(fh)
with open(evidence_path, "r", encoding="utf-8") as fh:
    evidence = json.load(fh)

def fail(message):
    print(f"Error: {message}", file=sys.stderr)
    sys.exit(1)

if status.get("status") != "success":
    fail(f"native_core_evidence_status.json status is {status.get('status')!r}")

if evidence.get("schemaVersion") != "reader-ios.native-core-evidence.v1":
    fail(f"unexpected schemaVersion {evidence.get('schemaVersion')!r}")

if evidence.get("abiVersion") != 1:
    fail(f"unexpected abiVersion {evidence.get('abiVersion')!r}")

if evidence.get("protocolVersion") != 1:
    fail(f"unexpected protocolVersion {evidence.get('protocolVersion')!r}")

layers = {layer.get("layer"): layer for layer in evidence.get("layers", [])}
required_layers = {"wrapper_smoke", "app_launch", "host_request_loop"}
missing = required_layers.difference(layers)
if missing:
    fail(f"missing evidence layers: {', '.join(sorted(missing))}")

wrapper = layers["wrapper_smoke"]
if wrapper.get("status") != "descriptorOnly" or wrapper.get("liveExecutionClaimed") is not False:
    fail("wrapper_smoke must stay descriptorOnly and must not claim live App execution")

app_launch = layers["app_launch"]
if app_launch.get("status") != "measuredPass" or app_launch.get("liveExecutionClaimed") is not True:
    fail("app_launch must be measuredPass with liveExecutionClaimed=true")

host_loop = layers["host_request_loop"]
if host_loop.get("status") != "measuredPass" or host_loop.get("liveExecutionClaimed") is not True:
    fail("host_request_loop must be measuredPass with liveExecutionClaimed=true")

loop = evidence.get("hostRequestLoop") or {}
if loop.get("capability") != "http.execute":
    fail(f"hostRequestLoop capability is {loop.get('capability')!r}, expected 'http.execute'")

if int(loop.get("operationId") or 0) <= 0:
    fail("hostRequestLoop operationId must be positive")

if int(loop.get("resultBookCount") or 0) <= 0:
    fail("hostRequestLoop resultBookCount must be positive")

print("native_core_evidence.json validation passed")
PY
