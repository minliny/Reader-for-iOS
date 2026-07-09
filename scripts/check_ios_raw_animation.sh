#!/usr/bin/env bash
#
# Raw animation lint — audit/warn mode + whitelist.
#
# 扫描业务 View（iOS/App, iOS/Features, iOS/Shell）里的裸 `.animation(...)` /
# `withAnimation(...)` 调用，凡是走 `ReaderMotionAdapter.animation(for: MotionRequest)`
# 或 `ReaderMotionAdapter.start(request:)` 的不算违规。
#
# 白名单文件：scripts/ios_raw_animation_whitelist.txt
# 每行一条，格式：相对路径:行号:原因（# 开头为注释）。
#
# 模式：
#   - audit/warn（默认）：发现非白名单裸调用时打印 WARN，exit 0
#   - strict（参数 --strict）：发现非白名单裸调用时 exit 1
#
# 真源：Reader UI `frontend-demo-optimized/MOTION_CONTRACT.md` §5 MotionPolicy /
#       §6 ReaderMotionResolver —— 业务 View 应通过 MotionRequest 走 resolver，
#       不直接硬编码 duration/easing。

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
whitelist_file="${repo_root}/scripts/ios_raw_animation_whitelist.txt"

# strict 模式：新增裸 .animation / withAnimation 会 fail CI
strict=0
if [[ "${1:-}" == "--strict" ]]; then
  strict=1
fi

# 业务 View 扫描范围（不含 iOS/Modules/Motion，因为那是 motion 框架内部实现）
scan_paths=(
  "iOS/App"
  "iOS/Features"
  "iOS/Shell"
)

# 读取白名单为临时文件（path:line 格式，每行一条）
whitelist_keys_file="$(mktemp)"
trap 'rm -f "${whitelist_keys_file}"' EXIT
if [[ -f "${whitelist_file}" ]]; then
  while IFS= read -r line; do
    # 跳过注释和空行
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    # 提取 path:line（:后面跟数字，再跟:原因）
    if [[ "${line}" =~ ^([^:]+):([0-9]+): ]]; then
      echo "${BASH_REMATCH[1]}:${BASH_REMATCH[2]}" >> "${whitelist_keys_file}"
    fi
  done < "${whitelist_file}"
fi

# 裸调用模式：.animation( 或 withAnimation(
# 排除已经走 ReaderMotionAdapter 的调用（同行包含 ReaderMotionAdapter）
violations=()
checked_files=0
total_raw_calls=0
whitelisted_calls=0

is_whitelisted() {
  local key="$1"
  if [[ ! -s "${whitelist_keys_file}" ]]; then
    return 1
  fi
  grep -Fxq "${key}" "${whitelist_keys_file}"
}

check_file() {
  local file="$1"
  local rel_path="${file#${repo_root}/}"
  # 读取整个文件到数组，便于向前看后续行
  local -a lines
  while IFS= read -r line; do
    lines+=("${line}")
  done < "${file}"
  local total_lines=${#lines[@]}
  local line_num=0
  local line

  while [[ ${line_num} -lt ${total_lines} ]]; do
    line="${lines[${line_num}]}"
    line_num=$((line_num + 1))

    # 跳过注释行
    [[ "${line}" =~ ^[[:space:]]*// ]] && continue

    # 检测裸调用模式
    if [[ "${line}" =~ \.animation\( || "${line}" =~ withAnimation\( ]]; then
      # 排除同行已经走 ReaderMotionAdapter 的调用
      if [[ "${line}" =~ ReaderMotionAdapter ]]; then
        continue
      fi

      # 向前看最多 5 行，检查是否走 ReaderMotionAdapter（多行 .animation( 调用）
      local look_ahead=1
      local found_adapter=0
      while [[ ${look_ahead} -le 5 && $((line_num + look_ahead - 1)) -lt ${total_lines} ]]; do
        local next_line="${lines[$((line_num + look_ahead - 1))]}"
        if [[ "${next_line}" =~ ReaderMotionAdapter ]]; then
          found_adapter=1
          break
        fi
        # 如果遇到闭合的 value: 或 ) 则停止向前看
        if [[ "${next_line}" =~ value:.*\) ]]; then
          break
        fi
        look_ahead=$((look_ahead + 1))
      done
      if [[ ${found_adapter} -eq 1 ]]; then
        continue
      fi

      total_raw_calls=$((total_raw_calls + 1))

      local key="${rel_path}:${line_num}"
      if is_whitelisted "${key}"; then
        whitelisted_calls=$((whitelisted_calls + 1))
        continue
      fi

      violations+=("${rel_path}:${line_num}: ${line#"${line%%[![:space:]]*}"}")
    fi
  done
  checked_files=$((checked_files + 1))
}

# 扫描所有 .swift 文件
for scan_path in "${scan_paths[@]}"; do
  abs_path="${repo_root}/${scan_path}"
  if [[ ! -d "${abs_path}" ]]; then
    continue
  fi
  while IFS= read -r -d '' file; do
    check_file "${file}"
  done < <(find "${abs_path}" -name "*.swift" -print0)
done

# 输出报告
echo "Raw animation lint (audit/warn mode)"
echo "checked_files=${checked_files}"
echo "scan_paths=${scan_paths[*]}"
echo "total_raw_calls=${total_raw_calls}"
echo "whitelisted_calls=${whitelisted_calls}"
echo "unwhitelisted_violations=${#violations[@]}"

if [[ ${#violations[@]} -gt 0 ]]; then
  echo ""
  echo "--- WARN: unwhitelisted raw .animation/withAnimation calls ---"
  for v in "${violations[@]}"; do
    echo "  ${v}"
  done
  echo ""
  echo "To fix: migrate to ReaderMotionAdapter.animation(for: MotionRequest)"
  echo "        or add to scripts/ios_raw_animation_whitelist.txt with reason."

  if [[ ${strict} -eq 1 ]]; then
    echo "result=FAIL (strict mode)"
    exit 1
  else
    echo "result=WARN (audit mode)"
  fi
else
  echo "result=PASS"
fi

exit 0
