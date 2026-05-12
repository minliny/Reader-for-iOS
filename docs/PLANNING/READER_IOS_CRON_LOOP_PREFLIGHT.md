# Reader for iOS — Cron Loop Preflight Checklist

Generated: 2026-05-13T00:00+08:00
Status: ACTIVE (used by every cron loop cycle)

---

## Preflight Execution Order

Every 10-minute cron cycle MUST execute these checks in order BEFORE selecting or executing any development task.

---

## Block 1: Environment Checks

### 1.1 Working Directory
```bash
pwd
```
- [ ] Current directory is `/Users/minliny/Documents/Reader for iOS`
- If NOT: STOP — wrong repository

### 1.2 Current Branch
```bash
git branch --show-current
```
- [ ] Branch is `main` or expected development branch
- If NOT: STOP — wrong branch, user must confirm

### 1.3 Git Status
```bash
git status --short
```
- [ ] No unrelated dirty files (files modified outside of allowed_files for loop)
- [ ] No merge conflicts
- [ ] No detached HEAD
- If unrelated dirty files: STOP — ask user to commit or stash

### 1.4 Current HEAD
```bash
git rev-parse --short HEAD
```
- [ ] HEAD matches expected (compare with last loop state `current_head`)
- If changed unexpectedly: WARN — user may have made manual changes

---

## Block 2: Previous Cycle State

### 2.1 Read Previous State
Read `docs/PLANNING/READER_IOS_CRON_LOOP_STATE.yml`

- [ ] `last_task_status` is NOT "FAILED" (or failure is understood and accepted)
- [ ] No active `BLOCKED` items without resolution plan
- [ ] No unresolved `NEEDS_CONFIRM` items

If `last_task_status` is FAILED:
- STOP — investigate failure before proceeding
- Do not retry same task blindly

### 2.2 Check for Unresolved Decisions
Read `docs/PLANNING/READER_IOS_USER_DECISION_REGISTER.yml`

- [ ] No entries with `status: OPEN` that block the current READY task
- If blocking decision exists: STOP — ask user

### 2.3 Check for Core Gaps
Read `docs/PLANNING/READER_IOS_CORE_GAP_HANDOFF_REGISTER.yml`

- [ ] No entries with `ios_status: BLOCKED` that block the current READY task
- If blocking gap exists: STOP — mark task as BLOCKED

---

## Block 3: Boundary and Build State

### 3.1 Boundary Check
```bash
bash scripts/check_ios_boundary.sh
```
- [ ] Result is PASS
- [ ] Checked file count matches expected (56+)
- [ ] 0 violations
- If FAIL: STOP — boundary violation must be fixed before any development

### 3.2 Build State Check
Check if last known build state is FAILED.

- [ ] If Core-side FAILED: task must be Core-independent to proceed
- [ ] If iOS-side FAILED: STOP — fix iOS build before new development
- [ ] If build state unknown: run quick build check

### 3.3 Test State Check
Check if last known test state is FAILED.

- [ ] If FAILED: task must not depend on passing tests unless fixing tests is the task
- [ ] If unknown: task should include test verification

---

## Block 4: Task Candidate Blocker Scan

For the candidate READY task, scan all 20 blocker categories.

### 4.1 Core API Dependency
- [ ] Task does NOT require a Reader-Core public API that doesn't exist
- If it does: STOP — mark MOVED_TO_CORE

### 4.2 Reader-Core Modification
- [ ] Task does NOT require changing Reader-Core source
- If it does: STOP — mark MOVED_TO_CORE

### 4.3 Parser/Runtime Implementation
- [ ] Task does NOT require implementing parser/runtime/rule engine in iOS
- If it does: STOP — mark BLOCKED (cannot do in iOS)

### 4.4 Legado Android Copy
- [ ] Task does NOT require copying/translating Legado Android code
- If it does: STOP — mark BLOCKED

### 4.5 New Dependency
- [ ] Task does NOT require adding a new Swift package or framework dependency
- If it does: STOP — mark NEEDS_CONFIRM

### 4.6 Network Access
- [ ] Task does NOT require HTTP/HTTPS network access
- If it does: STOP — mark NEEDS_CONFIRM (user must authorize)

### 4.7 User Credentials
- [ ] Task does NOT require real user credentials or Keychain test data
- If it does: STOP — mark NEEDS_CONFIRM

### 4.8 Real WebDAV Server
- [ ] Task does NOT require a real WebDAV server for validation
- If it does: STOP — mark NEEDS_CONFIRM

### 4.9 App Store Policy
- [ ] Task does NOT require App Store policy decision
- If it does: STOP — mark NEEDS_CONFIRM

### 4.10 Database Technology Selection
- [ ] Task does NOT require choosing a database beyond existing persistence pattern
- If it does: STOP — mark NEEDS_CONFIRM

### 4.11 Background Task Entitlement
- [ ] Task does NOT require adding background task entitlements
- If it does: STOP — mark NEEDS_CONFIRM

### 4.12 Apple Developer Team
- [ ] Task does NOT require Apple Developer Team configuration
- If it does: STOP — mark NEEDS_CONFIRM

### 4.13 Real Device
- [ ] Task does NOT require a physical iOS device for testing
- If it does: STOP — mark NEEDS_CONFIRM

### 4.14 Simulator Availability
- [ ] If task requires simulator: it is available
- Check: `xcrun simctl list devices available | grep iPhone`
- If not available: STOP — mark NEEDS_CONFIRM

### 4.15 Unverifiable UI Change
- [ ] Task can be verified by automated check (boundary/build/test), not just visual
- If purely visual: WARN — ensure verification plan exists

### 4.16 Auto-Commit
- [ ] Task does NOT require auto-commit
- Auto-commit is DISABLED by default
- If task description mentions commit: STOP — remove commit from scope

### 4.17 Cross-Repo Modification
- [ ] Task does NOT require modifying Reader-Core or any other repo
- If it does: STOP — mark MOVED_TO_CORE

### 4.18 Unfrozen Core Contract
- [ ] Task does NOT depend on an unfrozen/evolving Core API without accepting risk
- If risk exists: WARN — document in task notes

### 4.19 High-Frequency Sync
- [ ] Task does NOT implement high-frequency WebDAV sync (< 1 minute interval)
- If it does: STOP — violates sync policy

### 4.20 Privacy/Data Storage
- [ ] Task does NOT require user privacy or data storage policy decisions
- If it does: STOP — mark NEEDS_CONFIRM

---

## Block 5: Allowed Files Check

### 5.1 Verify Task's allowed_files
- [ ] Task's `allowed_files` list is not empty
- [ ] No files in `allowed_files` are in `blocked_write_roots`
- [ ] No Swift source files are in `allowed_files` unless task explicitly requires it
- [ ] Core files are NEVER in `allowed_files`

### 5.2 Verify No Blocked Paths
- [ ] `../Reader-Core` — NEVER allowed
- [ ] `.git` — NEVER allowed
- [ ] `.build` — NEVER allowed
- [ ] `DerivedData` — NEVER allowed

---

## Block 6: Verification Capability

### 6.1 Can the task be verified?
- [ ] Task has a `validation` field with specific commands or criteria
- [ ] Validation command can run in current environment
- [ ] Validation does not require network, real device, or user interaction

### 6.2 Can the task succeed in one cycle?
- [ ] Task scope fits within a single 10-minute cycle
- [ ] If too large: STOP — split task into smaller sub-tasks
- [ ] If unclear: WARN — may need to split after attempt

---

## Final Decision

### GO Conditions (ALL must be true)
- [ ] Block 1: Environment OK
- [ ] Block 2: No unresolved previous failures/decisions/gaps
- [ ] Block 3: Boundary PASS, build state acceptable
- [ ] Block 4: 0 blocker categories triggered
- [ ] Block 5: Allowed files are safe
- [ ] Block 6: Task is verifiable

### Output

**GO** → Execute the READY task. Proceed to `/reader-ios-cron-loop` execution phase.

**STOP** → Document reason, update registers, output report. Do NOT execute.

---

## Preflight Quick-Reference

| Check | Command/Source | Critical? |
|---|---|---|
| pwd | `pwd` | YES |
| branch | `git branch --show-current` | YES |
| status | `git status --short` | YES |
| boundary | `bash scripts/check_ios_boundary.sh` | YES |
| previous state | `READER_IOS_CRON_LOOP_STATE.yml` | YES |
| user decisions | `READER_IOS_USER_DECISION_REGISTER.yml` | YES |
| core gaps | `READER_IOS_CORE_GAP_HANDOFF_REGISTER.yml` | YES |
| build state | from loop state | YES |
| simulator | `xcrun simctl list devices available` | NO (only if task needs it) |
