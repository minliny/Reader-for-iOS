#!/bin/bash
# ============================================================
# run_webview_harness_simulator.sh
# iOS Simulator WebView Runtime Harness 自动执行脚本
#
# 授权范围: AUTHORIZE_SINGLE_WEBVIEW_URL_RENDER_TEST
# 约束: maxNavigationCount=1, requireHttps=true
# 禁止: 批量请求, 递归, 翻页, 批量章节, WAF 绕过, 自动重试
# ============================================================

# ===== 默认值 =====
DEVICE="iPhone 17 Pro"
BUNDLE_ID="com.reader.ios"
URL=""
ALLOWED_HOST=""
OUTPUT_DIR=""

# ===== 解析参数 =====
while [[ $# -gt 0 ]]; do
    case $1 in
        --device)
            DEVICE="$2"
            shift 2
            ;;
        --bundle-id)
            BUNDLE_ID="$2"
            shift 2
            ;;
        --url)
            URL="$2"
            shift 2
            ;;
        --allowed-host)
            ALLOWED_HOST="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 --device \"iPhone 17 Pro\" --bundle-id \"com.reader.ios\" --url \"https://...\" --allowed-host \"example.com\" [--output-dir \"/path/to/output\"]"
            exit 1
            ;;
    esac
done

# ===== 验证必要参数 =====
if [[ -z "$URL" ]]; then
    echo "Error: --url is required"
    exit 1
fi

if [[ -z "$ALLOWED_HOST" ]]; then
    echo "Error: --allowed-host is required"
    exit 1
fi

# ===== 项目路径 =====
PROJECT_DIR="/Users/minliny/Documents/Reader for iOS"
XCODEPROJ="$PROJECT_DIR/ReaderForIOS.xcodeproj"
SCHEME="ReaderForIOSApp"

# ===== 检查项目文件 =====
if [[ ! -e "$XCODEPROJ" ]]; then
    echo "Error: Xcode project not found at $XCODEPROJ"
    echo "Please run 'xcodegen generate' first."
    exit 1
fi

# ===== 清理构建 =====
echo "Cleaning build..."
xcodebuild clean -project "$XCODEPROJ" -scheme "$SCHEME" -quiet 2>/dev/null || true

# ===== 构建 App =====
echo "Building app..."
BUILD_OUTPUT=$(xcodebuild build \
    -project "$XCODEPROJ" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    2>&1)

if ! echo "$BUILD_OUTPUT" | grep -q "BUILD SUCCEEDED"; then
    echo "Error: Build failed"
    echo "$BUILD_OUTPUT" | tail -20
    exit 1
fi

echo "Build succeeded."

# ===== 获取 App Container =====
echo "Finding app container..."
DERIVED_DATA=$(xcodebuild -project "$XCODEPROJ" -scheme "$SCHEME" -configuration Debug -destination "platform=iOS Simulator,name=$DEVICE" -showBuildSettings 2>/dev/null | grep "BUILT_PRODUCTS_DIR" | head -1 | awk '{print $3}')
APP_PATH="$DERIVED_DATA/$SCHEME.app"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

# ===== Boot Simulator =====
echo "Booting simulator '$DEVICE'..."
xcrun simctl boot "$DEVICE" 2>/dev/null || true

# ===== 安装 App =====
echo "Installing app..."
xcrun simctl install booted "$APP_PATH" 2>/dev/null || true

# ===== 构建 autorun URL =====
AUTORUN_ARGS="--webview-harness-autorun --webview-url \"$URL\" --webview-allowed-host \"$ALLOWED_HOST\" --webview-source-id \"qianfanxs_user_provided\" --webview-source-name \"千帆小说\" --webview-stage detail"

# ===== 启动 App =====
echo "Launching app with autorun args..."
SIMCTL_OUTPUT=$(xcrun simctl launch booted "$BUNDLE_ID" -- args $AUTORUN_ARGS 2>&1)
echo "$SIMCTL_OUTPUT"

# ===== 等待结果文件 =====
echo "Waiting for result files..."
sleep 5

# ===== 查找 App Container 中的结果文件 =====
DEVICE_ID=$(xcrun simctl list devices | grep "$DEVICE" | grep -o '[0-9a-f-]\{36\}' | head -1)

if [[ -z "$DEVICE_ID" ]]; then
    echo "Warning: Could not find device ID for '$DEVICE'"
else
    APP_CONTAINER=""
    POSSIBLE_PATHS=(
        "$HOME/Library/Developer/CoreSimulator/Devices/$DEVICE_ID/data/Applications"
        "/Users/minliny/Library/Developer/CoreSimulator/Devices/$DEVICE_ID/data/Applications"
    )

    for DIR in "${POSSIBLE_PATHS[@]}"; do
        if [[ -d "$DIR" ]]; then
            APP_ENTRY=$(find "$DIR" -maxdepth 1 -type d -name "*$BUNDLE_ID*" 2>/dev/null | head -1)
            if [[ -n "$APP_ENTRY" ]]; then
                APP_CONTAINER="$APP_ENTRY"
                break
            fi
        fi
    done

    if [[ -n "$APP_CONTAINER" && -d "$APP_CONTAINER" ]]; then
        echo "App container: $APP_CONTAINER"
        RESULT_DIR=$(find "$APP_CONTAINER" -type d -name "WebViewHarnessRuns" 2>/dev/null | head -1)

        if [[ -n "$RESULT_DIR" ]]; then
            echo ""
            echo "===== Result Files Found ====="
            RUN_DIRS=$(find "$RESULT_DIR" -type d -mindepth 1 -maxdepth 1 | sort | tail -1)
            if [[ -n "$RUN_DIRS" ]]; then
                echo "Latest run directory: $RUN_DIRS"
                echo ""
                echo "Files:"
                ls -la "$RUN_DIRS"
                echo ""
                echo "===== webview_run_status.json ====="
                cat "$RUN_DIRS/webview_run_status.json" 2>/dev/null || echo "Not found"
            fi
        else
            echo "No WebViewHarnessRuns directory found yet"
        fi
    fi
fi

echo ""
echo "===== Script Completed ====="
