# Reader for iOS — Cron Loop Installation Guide

Generated: 2026-05-13T00:00+08:00

---

## Overview

The Reader for iOS cron loop is a 10-minute automated development cycle that:

1. Reads current state from planning documents
2. Runs preflight checks (boundary, blockers, user decisions)
3. Executes ONE small, verifiable task if GO
4. Stops immediately if STOP (blocker or user decision needed)
5. Updates loop state and generates report

**Default status: DISABLED.** You must explicitly enable it.

---

## Prerequisites

- macOS 15+ (for launchd) or Linux (for cron)
- Claude Code CLI installed and authenticated
- Reader for iOS repo at `/Users/minliny/Documents/Reader for iOS`
- Reader-Core repo at `/Users/minliny/Documents/Reader-Core`

---

## 1. Check Configuration

Verify all required files exist:

```bash
cd "/Users/minliny/Documents/Reader for iOS"

# Check planning docs
ls docs/PLANNING/READER_IOS_CRON_LOOP_*.{yml,md}

# Check Claude Code commands
ls .claude/commands/reader-ios-cron-*.md

# Check cron config
ls .claude/reader-ios-cron-loop.yml

# Check scripts
ls scripts/reader_ios_cron_loop.sh
ls scripts/install_reader_ios_cron_loop.sh
```

Expected: 13 files (7 docs/PLANNING/, 3 .claude/, 2 scripts/, 1 docs/PLANNING/ install guide)

---

## 2. Dry-Run

Test the cron loop without executing any tasks:

```bash
cd "/Users/minliny/Documents/Reader for iOS"
bash scripts/reader_ios_cron_loop.sh
```

This will:
- Check the environment
- Run boundary check
- Read current state
- Print what it WOULD do
- NOT execute any task
- NOT modify any files

---

## 3. Manual Single Run

Run one cycle manually:

```bash
cd "/Users/minliny/Documents/Reader for iOS"
claude --command "/reader-ios-cron-loop"
```

Or if using the Claude Code interactive REPL:

```
/reader-ios-cron-loop
```

This executes ONE task and stops. It does NOT set up recurring execution.

---

## 4. macOS launchd (Recommended)

### 4.1 Dry-Run the Installer

```bash
bash scripts/install_reader_ios_cron_loop.sh
```

This shows what would be installed without making changes.

### 4.2 Install the LaunchAgent

```bash
READER_IOS_ENABLE_CRON_LOOP=1 bash scripts/install_reader_ios_cron_loop.sh --enable
```

This creates:
- `~/Library/LaunchAgents/com.reader.ios-cron-loop.plist`

The plist triggers every 10 minutes (600 seconds).

### 4.3 Load the LaunchAgent

```bash
launchctl load ~/Library/LaunchAgents/com.reader.ios-cron-loop.plist
```

### 4.4 Verify It's Running

```bash
launchctl list | grep com.reader.ios
```

### 4.5 Check Logs

```bash
# stdout/stderr from the launchd job
tail -f /tmp/reader-ios-cron-loop.out
tail -f /tmp/reader-ios-cron-loop.err

# Or check system log
log show --predicate 'subsystem == "com.reader.ios-cron-loop"' --last 1h
```

---

## 5. Linux cron

### 5.1 Dry-Run the Installer

```bash
bash scripts/install_reader_ios_cron_loop.sh
```

### 5.2 Install the Crontab Entry

```bash
READER_IOS_ENABLE_CRON_LOOP=1 bash scripts/install_reader_ios_cron_loop.sh --enable
```

This adds to your crontab:
```
*/10 * * * * cd "/Users/minliny/Documents/Reader for iOS" && bash scripts/reader_ios_cron_loop.sh
```

### 5.3 Verify

```bash
crontab -l | grep reader-ios
```

---

## 6. Disable the Cron Loop

### macOS

```bash
# Unload the LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.reader.ios-cron-loop.plist

# Remove the plist
rm ~/Library/LaunchAgents/com.reader.ios-cron-loop.plist
```

### Linux

```bash
# Remove the crontab entry
crontab -l | grep -v reader-ios-cron-loop | crontab -
```

### Claude Code CronCreate (if used)

If you used `/loop` or CronCreate:
```
/cron-delete <job-id>
```

---

## 7. How to Handle STOP State

When the cron loop stops (does not execute a task), it outputs:

1. **Blocker reason** — what specifically caused the stop
2. **User decisions needed** — what you need to answer
3. **Next recommended task** — what would run if unblocked

### Common Stop Scenarios

| Stop Reason | What To Do |
|---|---|
| "Boundary violation detected" | Check `scripts/check_ios_boundary.sh` output, fix imports |
| "User decision needed: DEC-00X" | Check `READER_IOS_USER_DECISION_REGISTER.yml`, provide answer |
| "Core gap blocking: GAP-00X" | Check `READER_IOS_CORE_GAP_HANDOFF_REGISTER.yml`, determine if workaround exists |
| "Build failed" | Check build output, determine Core-side vs iOS-side |
| "Unrelated dirty files in worktree" | Commit or stash unrelated changes |
| "No READY task available" | Review backlog, unblock the next PENDING task |

---

## 8. How to Handle NEEDS_CONFIRM

When a task is marked `NEEDS_CONFIRM`:

1. Read the task's `user_decision_detection` field
2. Check `READER_IOS_USER_DECISION_REGISTER.yml` for related decisions
3. Make a decision
4. Update the register status to `RESOLVED`
5. The next cron cycle will re-evaluate and possibly mark the task READY

You can resolve a decision by editing the YAML:

```yaml
- id: DEC-001
  question: "How to fix Package.swift sibling path?"
  status: "RESOLVED"
  resolution: "Created symlink at iOS/Reader-Core -> ../../Reader-Core"
  resolved_at: "2026-05-13 12:00 +08:00"
```

---

## 9. How to Handle Core Gaps

When a Core gap is discovered:

1. The cron loop automatically adds it to `READER_IOS_CORE_GAP_HANDOFF_REGISTER.yml`
2. The dependent iOS task is marked `BLOCKED` or `MOVED_TO_CORE`
3. To resolve: the Core gap must be fixed in Reader-Core
4. After Core is updated: update the gap status to `RESOLVED`
5. The next cron cycle will unblock the dependent task

---

## 10. Avoiding Infinite Loops

The cron loop has multiple safeguards:

1. **max_tasks_per_run: 1** — hard limit, only one task per cycle
2. **Preflight every cycle** — re-checks all blockers before executing
3. **No auto-retry** — failed tasks are NOT retried without user review
4. **STOP on failure** — build/test failures stop the loop
5. **STOP on blocker** — unresolved blockers prevent execution
6. **No auto-commit** — user must manually commit changes
7. **Fresh state read** — each cycle reads current state, no stale cache
8. **Manual enable** — won't run unless explicitly enabled

---

## 11. Why Default Is Disabled

The cron loop is disabled by default because:

- It modifies files (even if only docs/PLANNING/)
- It needs Claude Code CLI access
- It runs on a timer, which may surprise the user
- Build is currently broken (Core-side issue)
- User decisions are pending (DEC-001, DEC-002, DEC-003)
- Better to start manually and enable automation when stable

**Enable only when:**
- Build is stable (or Core failure is accepted)
- User decisions are resolved
- You've manually run at least 3 successful cycles
- You understand the stop conditions and how to handle them
