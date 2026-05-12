#!/usr/bin/env bash

# Reader for iOS — Cron Loop Installer
# Generated: 2026-05-13T00:00+08:00
#
# Installs a macOS launchd agent or Linux cron job to trigger
# the Reader for iOS cron loop every 10 minutes.
#
# Default: dry-run (shows what would be installed, does nothing).
# Install:  READER_IOS_ENABLE_CRON_LOOP=1 bash scripts/install_reader_ios_cron_loop.sh --enable
#
# SAFETY:
# - Does NOT modify Swift source
# - Does NOT modify Reader-Core
# - Does NOT auto-commit
# - Does NOT access network
# - Requires explicit --enable flag AND READER_IOS_ENABLE_CRON_LOOP=1 env var

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ENABLE_FLAG="${1:-dry-run}"
ENV_CONFIRM="${READER_IOS_ENABLE_CRON_LOOP:-0}"

echo "============================================"
echo "Reader for iOS — Cron Loop Installer"
echo "============================================"
echo "Mode: ${ENABLE_FLAG}"
echo "Time: $(date -Iseconds)"
echo ""

# ── Prerequisite Checks ──

echo "## Prerequisites"

# Check repo
if [[ "$(pwd)" != "${REPO_ROOT}" ]]; then
    echo -e "${RED}[FAIL]${NC} Must run from repo root: ${REPO_ROOT}"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} Working directory: $(pwd)"

# Check wrapper script
if [[ -f "${REPO_ROOT}/scripts/reader_ios_cron_loop.sh" ]]; then
    echo -e "${GREEN}[OK]${NC} Wrapper script exists"
else
    echo -e "${RED}[FAIL]${NC} Wrapper script missing: scripts/reader_ios_cron_loop.sh"
    exit 1
fi

# Check Claude Code command
if [[ -f "${REPO_ROOT}/.claude/commands/reader-ios-cron-loop.md" ]]; then
    echo -e "${GREEN}[OK]${NC} Claude Code command exists"
else
    echo -e "${RED}[FAIL]${NC} Claude Code command missing"
    exit 1
fi

echo ""

# ── Platform Detection ──

OS_TYPE=$(uname -s)
echo "## Platform: ${OS_TYPE}"

if [[ "${OS_TYPE}" == "Darwin" ]]; then
    INSTALL_METHOD="launchd"
elif [[ "${OS_TYPE}" == "Linux" ]]; then
    INSTALL_METHOD="cron"
else
    echo -e "${RED}[FAIL]${NC} Unsupported platform: ${OS_TYPE}"
    echo "Only macOS (launchd) and Linux (cron) are supported."
    exit 1
fi

echo "Install method: ${INSTALL_METHOD}"
echo ""

# ── Dry-Run Output ──

echo "## Configuration Preview"
echo ""

WRAPPER_PATH="${REPO_ROOT}/scripts/reader_ios_cron_loop.sh"
INTERVAL_MINUTES=10

if [[ "${INSTALL_METHOD}" == "launchd" ]]; then
    PLIST_LABEL="com.reader.ios-cron-loop"
    PLIST_PATH="${HOME}/Library/LaunchAgents/${PLIST_LABEL}.plist"

    echo "Would create: ${PLIST_PATH}"
    echo ""
    echo "Plist content:"
    cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${WRAPPER_PATH}</string>
        <string>--run</string>
    </array>
    <key>StartInterval</key>
    <integer>$((INTERVAL_MINUTES * 60))</integer>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/reader-ios-cron-loop.out</string>
    <key>StandardErrorPath</key>
    <string>/tmp/reader-ios-cron-loop.err</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>${HOME}</string>
    </dict>
</dict>
</plist>
PLIST
    echo ""

elif [[ "${INSTALL_METHOD}" == "cron" ]]; then
    CRON_ENTRY="*/${INTERVAL_MINUTES} * * * * cd \"${REPO_ROOT}\" && bash \"${WRAPPER_PATH}\" --run >> /tmp/reader-ios-cron-loop.out 2>> /tmp/reader-ios-cron-loop.err"

    echo "Would add to crontab:"
    echo "${CRON_ENTRY}"
    echo ""
fi

# ── Enable Logic ──

if [[ "${ENABLE_FLAG}" != "--enable" ]]; then
    echo "============================================"
    echo "DRY-RUN COMPLETE — Nothing was installed."
    echo "============================================"
    echo ""
    echo "To install:"
    echo "  READER_IOS_ENABLE_CRON_LOOP=1 bash scripts/install_reader_ios_cron_loop.sh --enable"
    echo ""
    echo "Before enabling:"
    echo "  1. Edit .claude/reader-ios-cron-loop.yml → set enabled: true"
    echo "  2. Verify build can pass (or Core failure is documented)"
    echo "  3. Resolve open user decisions"
    echo "  4. Run a manual cycle first: /reader-ios-cron-loop"
    exit 0
fi

# ── Enable: Double Confirmation ──

if [[ "${ENV_CONFIRM}" != "1" ]]; then
    echo -e "${RED}[FAIL]${NC} READER_IOS_ENABLE_CRON_LOOP must be set to 1."
    echo ""
    echo "This is a safety measure. The cron loop modifies files."
    echo "Run with: READER_IOS_ENABLE_CRON_LOOP=1 bash scripts/install_reader_ios_cron_loop.sh --enable"
    exit 1
fi

# ── Check Config Enabled ──

CONFIG="${REPO_ROOT}/.claude/reader-ios-cron-loop.yml"
if grep -q "^enabled: false" "${CONFIG}"; then
    echo -e "${YELLOW}[WARN]${NC} .claude/reader-ios-cron-loop.yml has enabled: false"
    echo "The scheduler will be installed but the loop will not execute tasks."
    echo "Edit the config to set enabled: true when ready."
    echo ""
fi

# ── Install ──

echo "============================================"
echo "INSTALLING"
echo "============================================"

if [[ "${INSTALL_METHOD}" == "launchd" ]]; then
    PLIST_LABEL="com.reader.ios-cron-loop"
    PLIST_PATH="${HOME}/Library/LaunchAgents/${PLIST_LABEL}.plist"

    # Create LaunchAgents dir if needed
    mkdir -p "${HOME}/Library/LaunchAgents"

    # Write plist
    cat > "${PLIST_PATH}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${WRAPPER_PATH}</string>
        <string>--run</string>
    </array>
    <key>StartInterval</key>
    <integer>$((INTERVAL_MINUTES * 60))</integer>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/reader-ios-cron-loop.out</string>
    <key>StandardErrorPath</key>
    <string>/tmp/reader-ios-cron-loop.err</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>${HOME}</string>
    </dict>
</dict>
</plist>
PLIST

    echo -e "${GREEN}[OK]${NC} Created: ${PLIST_PATH}"

    # Unload if already loaded
    launchctl unload "${PLIST_PATH}" 2>/dev/null || true

    # Load
    launchctl load "${PLIST_PATH}"
    echo -e "${GREEN}[OK]${NC} Loaded LaunchAgent"

    echo ""
    echo "============================================"
    echo "INSTALLATION COMPLETE"
    echo "============================================"
    echo ""
    echo "The cron loop will run every ${INTERVAL_MINUTES} minutes."
    echo ""
    echo "To check status:"
    echo "  launchctl list | grep ${PLIST_LABEL}"
    echo ""
    echo "To view logs:"
    echo "  tail -f /tmp/reader-ios-cron-loop.out"
    echo "  tail -f /tmp/reader-ios-cron-loop.err"
    echo ""
    echo "To disable:"
    echo "  launchctl unload ${PLIST_PATH}"
    echo "  rm ${PLIST_PATH}"

elif [[ "${INSTALL_METHOD}" == "cron" ]]; then
    CRON_ENTRY="*/${INTERVAL_MINUTES} * * * * cd \"${REPO_ROOT}\" && bash \"${WRAPPER_PATH}\" --run >> /tmp/reader-ios-cron-loop.out 2>> /tmp/reader-ios-cron-loop.err"

    # Remove existing entry if present
    EXISTING=$(crontab -l 2>/dev/null | grep -v "reader-ios-cron-loop" || true)

    # Add new entry
    echo "${EXISTING}"$'\n'"${CRON_ENTRY}" | crontab -

    echo -e "${GREEN}[OK]${NC} Added to crontab"

    echo ""
    echo "============================================"
    echo "INSTALLATION COMPLETE"
    echo "============================================"
    echo ""
    echo "The cron loop will run every ${INTERVAL_MINUTES} minutes."
    echo ""
    echo "To check crontab:"
    echo "  crontab -l | grep reader-ios"
    echo ""
    echo "To view logs:"
    echo "  tail -f /tmp/reader-ios-cron-loop.out"
    echo ""
    echo "To disable:"
    echo "  crontab -l | grep -v reader-ios-cron-loop | crontab -"
fi

echo ""
echo "IMPORTANT:"
echo "  1. Ensure .claude/reader-ios-cron-loop.yml has enabled: true"
echo "  2. Claude Code must be authenticated"
echo "  3. The wrapper script does NOT auto-commit"
echo "  4. The wrapper script does NOT access the network"
echo "  5. The wrapper script does NOT modify Reader-Core"
echo ""
echo "To test a single manual cycle:"
echo "  cd \"${REPO_ROOT}\" && claude"
echo "  (in REPL) /reader-ios-cron-loop"
