# Reader for iOS — Cron Loop Plan

Generated: 2026-05-13T00:00+08:00
Status: DRAFT (cron loop NOT enabled)

---

## 1. Cron Loop Goal

Establish a sustainable, self-checking, stoppable 10-minute automated development loop for Reader for iOS that:

- Executes ONE small, verifiable task per cycle
- Stops immediately on blockers or user decisions needed
- Never modifies Reader-Core
- Never copies Core internals
- Never auto-commits
- Never accesses network without authorization
- Updates loop state after every cycle
- Produces a report for user review

---

## 2. Why 10-Minute Cycles

- **Small blast radius:** One task failure doesn't cascade
- **Quick feedback:** User sees progress every 10 minutes
- **Safe stopping:** Between cycles, user can review and intervene
- **Warm cache:** Under 5 minutes would waste prompt cache; 10 minutes amortizes cache miss reasonably
- **Non-blocking:** Won't occupy Claude Code for hours on end

---

## 3. Cycle Input

At the start of each cycle, read:

1. `docs/PLANNING/READER_IOS_CRON_LOOP_STATE.yml` — current state
2. `docs/PLANNING/READER_IOS_CRON_LOOP_BACKLOG.yml` — task queue
3. `docs/PLANNING/READER_IOS_USER_DECISION_REGISTER.yml` — pending decisions
4. `docs/PLANNING/READER_IOS_CORE_GAP_HANDOFF_REGISTER.yml` — Core gaps

---

## 4. Cycle Preflight

Before selecting a task, check:

### 4.1 Git State Check
- Current branch is `main` (or expected branch)
- No unrelated dirty files in worktree
- HEAD matches last recorded HEAD or is expected forward

### 4.2 Last Cycle Check
- Did last cycle fail?
- Is there an unresolved NEEDS_CONFIRM?
- Is there an active BLOCKED?

### 4.3 Task Readiness Check
- Scan backlog for the single READY task
- Verify READY task does not have unresolved blockers
- Verify READY task's core_dependency is available
- Verify READY task's preflight_checks all pass

### 4.4 Boundary Check
- Run `scripts/check_ios_boundary.sh`
- If FAIL, stop — boundary violation must be fixed first

### 4.5 Blocker Detection (20-point checklist)

For the candidate task, check it does NOT require:

1. New Reader-Core API
2. Reader-Core modification
3. Parser/Runtime internal implementation
4. Legado Android behavior copy
5. New dependency
6. Network access
7. User credentials / Keychain test data
8. Real WebDAV server
9. App Store policy decision
10. Database technology selection
11. Background task entitlement
12. Apple Developer Team
13. Real device
14. Simulator (if currently unavailable)
15. Unverifiable large UI change
16. Auto-commit
17. Cross-repo modification
18. Unfrozen Core contract
19. High-frequency sync policy
20. Privacy/data storage confirmation

If ANY of these are true → STOP, mark task as NEEDS_CONFIRM / BLOCKED / MOVED_TO_CORE.

### 4.6 Output: GO or STOP

- **GO**: No blockers, task is verifiable, proceed to execution.
- **STOP**: At least one blocker. Document reason, update registers, output report.

---

## 5. Task Selection

From the backlog, select the single task with `status: READY`.

Rules:
- Only ONE task may be READY at any time.
- If multiple tasks are READY, prioritize by `priority` (P0 > P1 > P2 > P3).
- If no task is READY, find the highest-priority PENDING task that can become READY (all blockers resolved).
- If no task can become READY, output "NO_READY_TASK" and stop.

---

## 6. Task Execution

Execute ONLY the selected task.

Constraints:
- Do NOT expand scope beyond `implementation_scope`.
- Do NOT touch files outside `allowed_files`.
- Do NOT violate `forbidden_actions`.
- Do NOT start the next task.
- If the task requires more than one cycle, split it.

---

## 7. Post-Execution Validation

After the task:

1. **Boundary check:** `bash scripts/check_ios_boundary.sh`
2. **Build check:** If task changed Swift code, attempt build
3. **Test check:** If task has test validation, run tests
4. **File audit:** Verify no files outside `allowed_files` were modified

If validation fails:
- Mark task status (BLOCKED if Core fault, FAILED if iOS fault)
- Do NOT proceed to next task
- Update loop state

---

## 8. Stop Conditions

Stop the cycle immediately if:

- Preflight returns STOP
- No READY task available
- Boundary check fails
- Build fails (and failure is NOT already-attributed Core issue)
- Test fails
- Task requires network access
- Task requires new dependency
- Task requires Reader-Core modification
- Git worktree has unrelated changes
- User decision is needed and unresolved

**On stop:** Update loop state, output report, do NOT execute development task.

---

## 9. State Update

After each cycle (whether GO or STOP):

Update `docs/PLANNING/READER_IOS_CRON_LOOP_STATE.yml`:
- `last_loop_started_at`
- `last_loop_finished_at`
- `last_selected_task`
- `last_task_status`
- `next_recommended_task`
- `active_blockers` (if any)
- `user_decisions_needed` (if any)

Update `docs/PLANNING/READER_IOS_CRON_LOOP_BACKLOG.yml`:
- Completed task → DONE or DONE_CANDIDATE
- Blocked task → BLOCKED or NEEDS_CONFIRM
- Next task → READY

Update registers if needed:
- `READER_IOS_USER_DECISION_REGISTER.yml`
- `READER_IOS_CORE_GAP_HANDOFF_REGISTER.yml`

---

## 10. Report Generation

After each cycle, output:

```
## Reader iOS Cron Loop Report

### Cycle Summary
- Started: [timestamp]
- Finished: [timestamp]
- Selected task: [id] [title]
- Task status: [DONE / BLOCKED / STOPPED]

### Changes
- modified_files: [list]
- new_files: [list]

### Validation
- boundary_check: [PASS / FAIL / NOT_RUN]
- build: [PASS / FAIL / NOT_RUN]
- test: [PASS / FAIL / NOT_RUN]

### Status
- code_changes: [true / false]
- dependency_changes: false
- network_access: false
- commit_performed: false

### Next
- next_recommended_task: [id]
- blockers: [list]
- user_decisions_needed: [list]
```

---

## 11. Failure Retry Strategy

- If a task fails: Do NOT retry the same task in the next cycle. Mark it and move on.
- If build fails due to Core: Mark as BLOCKED, document Core gap, do NOT fix Core code.
- If test fails due to environment: Mark as NEEDS_CONFIRM, ask user to fix environment.
- Maximum 1 retry per task per session. After that, escalate to user.

---

## 12. Infinite Loop Prevention

- `max_tasks_per_run: 1` — hard limit, enforced by cron loop config
- Each cycle reads fresh state — can't accumulate stale state
- STOP conditions prevent execution when blocked
- No automatic git reset or destructive recovery
- No automatic dependency changes
- No silent workaround of blockers

---

## 13. Boundary Violation Prevention

- Preflight runs `scripts/check_ios_boundary.sh` before every task
- Task `forbidden_actions` explicitly list what must not happen
- `allowed_files` restricts file modifications
- `blocked_write_roots` in cron config blocks writes to Core, .git
- Post-execution validation re-runs boundary check

---

## 14. No Auto-Commit Policy

**Default: commits are NEVER automatic.**

Rationale:
- User must review every change before commit
- Some changes may need squashing
- Commit messages need human judgment
- Security-sensitive changes need explicit review

If user later requests auto-commit:
- Must be explicitly authorized in USER_DECISION_REGISTER
- Only allowed for docs/PLANNING/ changes
- Never for Swift source, Xcode project, CI, scripts
- Each commit must have a clear, descriptive message

---

## 15. Future Auto-Commit Safety Conditions (NOT enabled now)

If user explicitly enables auto-commit (requires separate decision):

1. Only for files in `docs/PLANNING/`
2. Only when boundary check passes
3. Only when no Swift source was modified
4. Only when no dependency was changed
5. Commit message must include cycle report summary
6. User must have pre-approved in USER_DECISION_REGISTER
7. Never for `.xcodeproj`, `Package.swift`, `project.yml`
8. Never when build is broken

**Current status: auto-commit DISABLED.**
