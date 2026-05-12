#!/usr/bin/env bash

# Reader for iOS — Cron Loop Wrapper
# Generated: 2026-05-13T00:00+08:00
#
# This script is a SAFETY WRAPPER for the Reader for iOS cron loop.
# It checks the environment before invoking Claude Code.
# It does NOT execute development tasks directly.
# It does NOT modify Swift source or Xcode projects.
# It does NOT auto-commit.
# It does NOT access the network.
# It does NOT modify Reader-Core.
#
# Usage:
#   bash scripts/reader_ios_cron_loop.sh          # Dry-run: check env, print what would happen
#   bash scripts/reader_ios_cron_loop.sh --run    # Execute one cycle via Claude Code CLI

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

RUN_MODE="${1:-dry-run}"

echo "============================================"
echo "Reader for iOS — Cron Loop Wrapper"
echo "============================================"
echo "Mode: ${RUN_MODE}"
echo "Time: $(date -Iseconds)"
echo ""

# ── Check 1: Working Directory ──
echo "## Check 1: Working Directory"
if [[ "$(pwd)" == "/Users/minliny/Documents/Reader for iOS" ]]; then
    pass "Correct directory: $(pwd)"
else
    fail "Wrong directory: $(pwd)"
    echo "Expected: /Users/minliny/Documents/Reader for iOS"
    echo "STOP: Wrong repository directory."
    exit 1
fi
echo ""

# ── Check 2: Git State ──
echo "## Check 2: Git State"
BRANCH=$(git branch --show-current)
HEAD=$(git rev-parse --short HEAD)
echo "Branch: ${BRANCH}"
echo "HEAD: ${HEAD}"

if [[ "${BRANCH}" != "main" ]]; then
    warn "Not on main branch: ${BRANCH}"
    echo "STOP: Branch mismatch. Switch to main or confirm."
    exit 1
fi
pass "On main branch"

DIRTY_FILES=$(git status --short)
if [[ -n "${DIRTY_FILES}" ]]; then
    warn "Dirty worktree:"
    echo "${DIRTY_FILES}"
    echo ""
    echo "Check if these are expected (loop planning files) or unrelated."
    # Don't hard-stop for dirty files — preflight in Claude Code will decide
else
    pass "Clean worktree"
fi
echo ""

# ── Check 3: Required Files ──
echo "## Check 3: Required Files"

REQUIRED_FILES=(
    ".claude/commands/reader-ios-cron-loop.md"
    ".claude/commands/reader-ios-cron-preflight.md"
    ".claude/reader-ios-cron-loop.yml"
    "docs/PLANNING/READER_IOS_CRON_LOOP_STATE.yml"
    "docs/PLANNING/READER_IOS_CRON_LOOP_BACKLOG.yml"
    "docs/PLANNING/READER_IOS_USER_DECISION_REGISTER.yml"
    "docs/PLANNING/READER_IOS_CORE_GAP_HANDOFF_REGISTER.yml"
    "docs/PLANNING/READER_IOS_CRON_LOOP_PREFLIGHT.md"
    "scripts/check_ios_boundary.sh"
)

MISSING=0
for f in "${REQUIRED_FILES[@]}"; do
    if [[ -f "${REPO_ROOT}/${f}" ]]; then
        pass "Found: ${f}"
    else
        fail "Missing: ${f}"
        MISSING=$((MISSING + 1))
    fi
done

if [[ ${MISSING} -gt 0 ]]; then
    echo "STOP: ${MISSING} required files missing."
    exit 1
fi
echo ""

# ── Check 4: Boundary ──
echo "## Check 4: iOS Boundary"
if bash "${REPO_ROOT}/scripts/check_ios_boundary.sh" &> /dev/null; then
    pass "Boundary check PASS"
else
    fail "Boundary check FAIL"
    echo "STOP: Fix boundary violations before running cron loop."
    bash "${REPO_ROOT}/scripts/check_ios_boundary.sh"
    exit 1
fi
echo ""

# ── Check 5: Reader-Core Not in Blocked Roots ──
echo "## Check 5: Reader-Core Protection"
if [[ -d "${REPO_ROOT}/../Reader-Core" ]]; then
    pass "Reader-Core exists at expected location (not in iOS repo)"
else
    warn "Reader-Core not found at ../Reader-Core"
    echo "This is expected if using the canonical path structure."
fi
echo ""

# ── Check 6: Cron Config ──
echo "## Check 6: Cron Loop Config"

CONFIG="${REPO_ROOT}/.claude/reader-ios-cron-loop.yml"
ENABLED=$(grep -E "^enabled:" "${CONFIG}" | awk '{print $2}')

if [[ "${ENABLED}" == "false" ]]; then
    warn "Cron loop is DISABLED in config."
    echo "To enable: edit .claude/reader-ios-cron-loop.yml and set enabled: true"
    echo "Or run: READER_IOS_ENABLE_CRON_LOOP=1 bash scripts/install_reader_ios_cron_loop.sh --enable"
    echo ""
    echo "Running in dry-run mode (no tasks will execute)."
fi
echo ""

# ── Check 7: Claude Code CLI ──
echo "## Check 7: Claude Code CLI"
if command -v claude &> /dev/null; then
    CLAUDE_VERSION=$(claude --version 2>&1 | head -1 || echo "unknown")
    pass "Claude Code CLI available: ${CLAUDE_VERSION}"
else
    warn "Claude Code CLI not found in PATH."
    echo "The cron loop requires Claude Code CLI to execute tasks."
    echo ""
    echo "Manual alternative:"
    echo "  1. Open Claude Code in this repo: cd \"${REPO_ROOT}\" && claude"
    echo "  2. Run the command: /reader-ios-cron-loop"
    echo ""
    if [[ "${RUN_MODE}" == "--run" ]]; then
        echo "STOP: Claude Code CLI not available."
        exit 1
    fi
fi
echo ""

# ── Check 8: Read Loop State ──
echo "## Check 8: Current Loop State"
STATE_FILE="${REPO_ROOT}/docs/PLANNING/READER_IOS_CRON_LOOP_STATE.yml"
if [[ -f "${STATE_FILE}" ]]; then
    echo "Next recommended task: $(grep 'next_recommended_task:' "${STATE_FILE}" | head -1 | sed 's/.*: //' | tr -d '"')"
    echo "Validation status: $(grep 'validation_status:' "${STATE_FILE}" | head -1 | sed 's/.*: //' | tr -d '"')"
    echo "Active blockers: $(grep -c 'ACTIVE\|DEPENDS_ON' "${STATE_FILE}" || echo "0")"
else
    fail "Loop state file not found"
    exit 1
fi
echo ""

# ── Summary ──
echo "============================================"
echo "Preflight Summary"
echo "============================================"
echo "Repository: OK"
echo "Branch: ${BRANCH}"
echo "HEAD: ${HEAD}"
echo "Boundary: PASS"
echo "Config: enabled=${ENABLED}"
echo ""

if [[ "${RUN_MODE}" == "--run" ]]; then
    if [[ "${ENABLED}" != "true" ]]; then
        echo "Cannot run: cron loop is disabled in config."
        echo "Enable it first, then re-run with --run."
        exit 1
    fi

    if ! command -v claude &> /dev/null; then
        echo "Cannot run: Claude Code CLI not available."
        exit 1
    fi

    echo "Executing one cron loop cycle via Claude Code..."
    echo "Command: claude --command '/reader-ios-cron-loop'"
    echo ""
    echo "TODO: Implement Claude Code CLI invocation."
    echo "Currently, Claude Code CLI must be invoked manually or via the REPL."
    echo ""
    echo "Manual steps:"
    echo "  1. cd \"${REPO_ROOT}\""
    echo "  2. claude"
    echo "  3. /reader-ios-cron-loop"
    echo ""
    echo "For automated invocation, use the launchd/cron installer:"
    echo "  bash scripts/install_reader_ios_cron_loop.sh"
else
    echo "Dry-run complete. No tasks executed."
    echo ""
    echo "To run one cycle manually:"
    echo "  1. Open Claude Code: cd \"${REPO_ROOT}\" && claude"
    echo "  2. Type: /reader-ios-cron-loop"
    echo ""
    echo "To install automated scheduler:"
    echo "  bash scripts/install_reader_ios_cron_loop.sh"
    echo ""
    echo "To enable cron loop:"
    echo "  Edit .claude/reader-ios-cron-loop.yml → set enabled: true"
fi

echo ""
echo "============================================"
