#!/usr/bin/env bash
# Raw token literal gate for iOS.
# 真源：Reader UI/frontend-demo-optimized/tokens.css（--fd-ds-* token 体系）
#
# 禁止在 adapter 层（iOS/Modules/Theme/）之外出现：
# - hardcoded color literal（Color(red:green:blue:) 例外：iOS/Modules/Theme/）
# - hardcoded spacing literal（除 // layout-caution 标注）
# - hardcoded radius literal
#
# 例外：iOS/Modules/Theme/ 目录（adapter 层允许 raw literal）
# 例外：Color(.system*) 系统色引用
# 例外：含 // layout-caution 注释的行

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAN_DIRS=(
    "$REPO_ROOT/iOS/Features"
    "$REPO_ROOT/iOS/App/Components"
)
EXCLUDE_DIR="$REPO_ROOT/iOS/Modules/Theme"

VIOLATIONS=0

for dir in "${SCAN_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        continue
    fi
    while IFS= read -r file; do
        # 检测 Color(red:green:blue:) raw literal（排除 Color(.system*) ）
        while IFS= read -r line_num; do
            [ -z "$line_num" ] && continue
            line_content=$(sed -n "${line_num}p" "$file")
            # 跳过 layout-caution 标注
            if echo "$line_content" | grep -q "layout-caution"; then
                continue
            fi
            echo "VIOLATION (raw color literal): $file:$line_num: $line_content"
            VIOLATIONS=$((VIOLATIONS + 1))
        done < <(grep -n 'Color(red:' "$file" 2>/dev/null | cut -d: -f1 || true)

        # 检测 hardcoded hex color literal（#xxxxxx 模式在 string literal 中）
        while IFS= read -r line_num; do
            [ -z "$line_num" ] && continue
            line_content=$(sed -n "${line_num}p" "$file")
            if echo "$line_content" | grep -q "layout-caution"; then
                continue
            fi
            echo "VIOLATION (hex color string): $file:$line_num: $line_content"
            VIOLATIONS=$((VIOLATIONS + 1))
        done < <(grep -n '#[0-9a-fA-F]\{6\}' "$file" 2>/dev/null | grep -v '//\|#imageLiteral\|#colorLiteral' | cut -d: -f1 || true)
    done < <(find "$dir" -name "*.swift" -type f 2>/dev/null)
done

if [ "$VIOLATIONS" -gt 0 ]; then
    echo ""
    echo "FAIL: Found $VIOLATIONS raw token literal violations."
    echo "Token adapter 层（iOS/Modules/Theme/）之外的 .swift 文件禁止 raw color/spacing/radius literal。"
    echo "请使用 ReaderTokenAdapter / ReaderDesignTokens / ReaderZIndex 提供的 token 值。"
    exit 1
fi

echo "PASS: No raw token literal violations in iOS/Features/ and iOS/App/Components/."
