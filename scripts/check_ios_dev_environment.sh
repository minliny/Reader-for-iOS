#!/usr/bin/env bash

# Reader for iOS - iOS 开发环境检查脚本
# 检查项目是否正确配置，能否正常构建

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

passed=0
warned=0
failed=0

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    passed=$((passed + 1))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    warned=$((warned + 1))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    failed=$((failed + 1))
}

echo "============================================"
echo "iOS 开发环境检查"
echo "============================================"
echo ""

# Step 1: 检查当前目录
echo "## Step 1: 当前目录检查"
if [[ "$(pwd)" == "/Users/minliny/Documents/Reader for iOS" ]]; then
    pass "当前目录正确: $(pwd)"
else
    fail "当前目录错误: $(pwd)，应该是 /Users/minliny/Documents/Reader for iOS"
fi
echo ""

# Step 2: 检查必要工具
echo "## Step 2: 必要工具检查"

check_tool() {
    local tool=$1
    local version_cmd=$2
    if command -v "$tool" &> /dev/null; then
        local version=$($version_cmd 2>&1 | head -1 || echo "unknown")
        pass "$tool 可用: $version"
    else
        fail "$tool 不可用"
    fi
}

check_tool "xcodebuild" "xcodebuild -version"
check_tool "swift" "swift --version"
check_tool "git" "git --version"
check_tool "xcodegen" "xcodegen --version"
echo ""

# Step 3: 检查关键文件
echo "## Step 3: 关键文件检查"

check_file() {
    local file=$1
    local desc=$2
    if [[ -f "$REPO_ROOT/$file" ]]; then
        pass "$desc 存在: $file"
    else
        fail "$desc 缺失: $file"
    fi
}

check_file "project.yml" "project.yml"
check_file "CLAUDE.md" "CLAUDE.md"
check_file ".claude/commands/ios-dev.md" "iOS Dev 命令"
check_file "scripts/check_ios_boundary.sh" "iOS Boundary 脚本"
echo ""

# Step 4: 检查 project.yml 危险 source
echo "## Step 4: project.yml 危险 source 检查"

dangerous_sources=$(grep -A 30 "ReaderForIOSApp:" "$REPO_ROOT/project.yml" 2>/dev/null | grep -E "(path:\s*\.\.|path:\s*\.|path:\s*Core|path:\s*\/.*Reader-Core)" || true)

if [[ -z "$dangerous_sources" ]]; then
    pass "ReaderForIOSApp sources 未发现危险路径"
else
    fail "ReaderForIOSApp sources 包含危险路径:"
    echo "$dangerous_sources" | while read line; do
        echo "  $line"
    done
fi
echo ""

# Step 5: 检查 Reader-Core 依赖配置
echo "## Step 5: Reader-Core 依赖配置检查"

if grep -q "ReaderCore:" "$REPO_ROOT/project.yml" && grep -q "path: ../Reader-Core/Core" "$REPO_ROOT/project.yml"; then
    pass "Reader-Core 通过 packages path dependency 正确引入"
else
    fail "Reader-Core 依赖配置可能不正确"
fi
echo ""

# Step 6: 检查 .xcodeproj
echo "## Step 6: Xcode 项目检查"

if [[ -d "$REPO_ROOT/ReaderForIOS.xcodeproj" ]]; then
    pass "ReaderForIOS.xcodeproj 存在"
else
    warn "ReaderForIOS.xcodeproj 不存在，需要运行 xcodegen generate"
fi
echo ""

# Step 7: 检查 iOS boundary 脚本
echo "## Step 7: iOS Boundary 检查"

if bash "$REPO_ROOT/scripts/check_ios_boundary.sh" &> /dev/null; then
    pass "iOS boundary check PASS"
else
    fail "iOS boundary check FAIL"
fi
echo ""

# Step 8: Simulator 检查
echo "## Step 8: Simulator 检查"

simulator=$(xcrun simctl list devices available 2>/dev/null | grep "iPhone 17 Pro (Booted)" || true)
if [[ -n "$simulator" ]]; then
    pass "iPhone 17 Pro 可用 (Booted)"
else
    warn "iPhone 17 Pro 未启动，可用的模拟器:"
    xcrun simctl list devices available 2>/dev/null | grep "iPhone" | head -5
fi
echo ""

# 总结
echo "============================================"
echo "检查结果总结"
echo "============================================"
echo -e "通过: ${GREEN}$passed${NC}"
echo -e "警告: ${YELLOW}$warned${NC}"
echo -e "失败: ${RED}$failed${NC}"
echo ""

if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}环境检查通过！${NC}"
    exit 0
else
    echo -e "${RED}环境检查失败，需要修复上述问题。${NC}"
    exit 1
fi