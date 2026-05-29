---
name: test-plan-execution
description: >
  Run Sections 4, 5, and 7 of the Tendril development branch test plan.
  Use when testing plan lifecycle management, core execution, verification gates, timeout/error handling, cross-agent parity, and jobs dashboard.
allowed-tools: Bash Read
effort: medium
---

# test-plan-execution

Run Sections 4, 5, and 7 of the Tendril development branch test plan.

**Prerequisites:**
- repo-node, repo-go set up and added to Tendril
- At least one `Draft` plan created (see `test-plan-creation` skill)
- Verifications configured for repo-node: build=`npm run build`, test=`npm test`, lint=`npm run lint`
- Agent: **Claude Code / balanced** (primary); Codex and OpenCode for Section 5D

---

## Section 4 — Plan Lifecycle Management

### 4.1 — Expand plan

1. Select a `Draft` plan → click **Expand**.
2. **Expected:** `ExpandPlan` job runs; plan body splits into sub-tasks visible in `DraftsApp`.
3. ✅ Pass if sub-tasks appear in the plan detail view.

### 4.2 — Update plan

1. Select a plan → click **Update** → add refinement notes (e.g., *"Also add input validation"*).
2. **Expected:**
   - `UpdatePlan` job runs.
   - A new revision file `revision-02.md` is written.
   - `plan.yaml` reflects the updates.
3. ✅ Pass if `revision-02.md` exists and `plan.yaml` is updated.

### 4.3 — Move to Icebox

1. Select a `Draft` → click **Icebox**.
2. **Expected:** Plan status becomes `Icebox`; it appears in `IceboxApp`; it is gone from `DraftsApp`.
3. ✅ Pass if plan moves correctly between views.

### 4.4 — Restore from Icebox

1. In `IceboxApp`, click **Restore** on an iceboxed plan.
2. **Expected:** Plan returns to `Draft`; appears in `DraftsApp`.
3. ✅ Pass if round-trip succeeds.

### 4.5 — Delete plan

1. Select a plan → click the trash icon → confirm deletion.
2. **Expected:**
   - Plan appears in `TrashApp`.
   - Plan folder moved to `$TENDRIL_HOME/Trash/`.
3. ✅ Pass if plan is gone from DraftsApp and present in TrashApp.

### 4.6 — Mark plan Blocked

1. Create plan A and plan B.
2. Set plan B's `dependsOn` to reference plan A.
3. **Expected:** Plan B shows status `Blocked` in the UI until plan A is completed.
4. ✅ Pass if `Blocked` badge is shown for plan B.

### 4.7 — Skip plan

1. Select a `Draft` → mark as **Skipped**.
2. **Expected:** Status becomes `Skipped`; plan is not executed when running a batch.
3. ✅ Pass if status persists and plan is excluded from execution queue.

---

## Section 5A — Core Execution ★

### 5A.1 — Execute plan (Claude Code / balanced)

1. Approve a `Draft` plan → click **Execute**.
2. **Expected:**
   - `ExecutePlan` job is created and visible in `JobsApp`.
   - An isolated git worktree is created at branch `tendril/<planId>-<title>` inside the repo.
   - Agent runs against the worktree.
3. Verify worktree branch name: `git -C <worktree-path> branch --show-current`
4. ✅ Pass if branch name matches the pattern.

### 5A.2 — Worktree isolation

1. While a plan is executing (5A.1 in progress):
2. Make a change to `main` in repo-node (e.g., `git commit --allow-empty -m "test isolation"`).
3. **Expected:** The agent's worktree is unaffected; `git log` in the worktree does not include the new commit.
4. ✅ Pass if worktrees are isolated.

### 5A.3 — Plan completes with commits

1. Let `ExecutePlan` finish (5A.1).
2. **Expected:**
   - `plan.yaml` contains a `commits:` list with at least one entry.
   - Job shows `Completed` status.
   - Plan moves to `ReadyForReview`.
3. ✅ Pass if all three conditions met.

### 5A.4 — Job output streaming

1. While ExecutePlan is running, watch the job in `JobsApp`.
2. **Expected:** Output lines stream in real time; cost counter and token counters increment as the job runs.
3. ✅ Pass if output is live (not batch-loaded at end) and counters update.

### 5A.5 — Skip re-execution when clean

1. Execute a plan to completion (5A.3 done).
2. Without making any changes, execute the same plan again.
3. **Expected:** Second execution detects verifications already pass and working tree is clean; skips the agent run.
4. ✅ Pass if second job completes quickly with a "skipped" or "clean" message.

---

## Section 5B — Verification Gates ★

### 5B.1 — All verifications pass

1. Use a plan that makes a trivial, safe change to repo-node (e.g., add a comment).
2. Execute it.
3. **Expected:** Build, test, and lint gates all show `Pass`; `summary.md` is written to `<PlanFolder>/Verification/`; plan advances to `ReadyForReview`.
4. ✅ Pass if all three gates show Pass.

### 5B.2 — Required verification fails

1. Set test as `required: true` in Verifications settings.
2. Create a plan with instructions that will break existing tests (e.g., *"Delete the health check route"*).
3. Execute the plan.
4. **Expected:**
   - Plan does not advance to PR creation.
   - Plan status shows `Failed`.
   - Verification report details the test failure.
5. ✅ Pass if execution is blocked and report exists.

### 5B.3 — Optional verification fails

1. Set lint as `required: false` (non-required).
2. Create a plan that produces a lint warning (e.g., *"Add an unused variable to src/app.ts"*).
3. Execute the plan.
4. **Expected:**
   - Plan advances to `ReadyForReview` despite lint failure.
   - Lint gate shows `Fail` in the Verifications tab but is non-blocking.
5. ✅ Pass if plan advances and lint shows Fail (non-blocking).

### 5B.4 — Verification status in UI

1. After any completed execution, open the plan detail view.
2. Click the **Verifications** tab.
3. **Expected:** Each gate shows: name, status badge (Pass/Fail/Skipped), and a clickable link to the report file.
4. ✅ Pass if all three elements present for each gate.

---

## Section 5C — Timeout & Error Handling

### 5C.1 — 30-minute timeout

1. Configure the execution timeout to 1 minute (if configurable in dev mode), or mock a long-running task.
2. Execute a plan designed to time out.
3. **Expected:**
   - Job is cancelled after timeout.
   - Status becomes `Timeout`.
   - Worktree is preserved (not cleaned up) for inspection.
4. ✅ Pass if all three conditions met.

### 5C.2 — Agent process crash

1. Start ExecutePlan.
2. Find the agent process PID (visible in JobsApp or via `ps aux | grep claude`).
3. Kill it: `kill -9 <PID>`.
4. **Expected:**
   - Job status becomes `Failed`.
   - Error surfaced in Jobs dashboard.
   - Worktree is not automatically cleaned up.
5. ✅ Pass if all three conditions met.

### 5C.3 — Retry after failure

1. After a `Failed` execution (5C.2):
2. Add change request notes: *"Please ensure the health check route is not removed."*
3. Click **Retry**.
4. **Expected:**
   - A `RetryPlan` job is created (not a mutation of the old job).
   - Change request notes are included in the agent's prompt context.
   - A new execution attempt begins in the same worktree.
5. ✅ Pass if new job created and notes are visible in the job's prompt/output.

---

## Section 5D — Cross-Agent Parity ★

Use **repo-go** for all agents. Plan: *"Add a README.md with a short project description and usage instructions."*

For each agent, verify:

| Agent | Profile | 5D.1 Worktree created | 5D.2 Output streams | 5D.3 Cost tracked | 5D.4 Completes |
|---|---|---|---|---|---|
| Claude Code | balanced | | | | |
| Codex | balanced | | | | |
| OpenCode | balanced | | | | |

**5D.1** — After execution starts, confirm a worktree directory exists under the repo.
**5D.2** — Watch JobsApp during execution; output lines appear incrementally.
**5D.3** — After completion, job shows a non-zero cost or token count.
**5D.4** — Job status reaches `Completed`; plan moves to `ReadyForReview`.

Fill in the table with ✅ / ❌ for each cell.

---

## Section 7 — Jobs Dashboard ★

### 7.1 — All job types visible

1. Run CreatePlan → ExecutePlan → CreatePr in sequence.
2. **Expected:** All three job types appear in `JobsApp` with correct status icons.
3. ✅ Pass if all three job type labels are visible.

### 7.2 — Cost + token tracking

1. After a complete end-to-end run.
2. **Expected:**
   - JobsApp shows input tokens, output tokens, and cost per job.
   - DashboardApp totals match the sum of individual job costs.
3. ✅ Pass if totals are consistent (within rounding).

### 7.3 — Stop a running job

1. While `ExecutePlan` is running, click **Stop**.
2. **Expected:**
   - Job status becomes `Stopped`.
   - Agent process is killed.
   - Worktree is preserved.
3. ✅ Pass if all three conditions met.

### 7.4 — Output line limit

1. Create a plan with instructions that produce verbose agent output (e.g., *"List every file in the repo with its line count"*).
2. **Expected:** UI renders smoothly up to and past 10,000 output lines; no crash or freeze.
3. ✅ Pass if UI remains responsive.

### 7.5 — Concurrent jobs

1. Submit two plans and execute both simultaneously.
2. **Expected:**
   - Both jobs appear in JobsApp with independent progress.
   - Output in job A does not appear in job B.
   - Cost tracked separately for each.
3. ✅ Pass if all three conditions met.

### 7.6 — Failed job retry

1. After a job reaches `Failed` status.
2. **Expected:** A **Retry** button is present; clicking it creates a *new* job rather than modifying the existing one.
3. ✅ Pass if a second job entry appears in JobsApp after clicking Retry.

---

## Validation checklist

- [ ] 5A.1–5A.5: Core execution happy path complete
- [ ] 5B.1–5B.4: All four verification gate scenarios pass
- [ ] 5C.1–5C.3: Timeout, crash, and retry handled correctly
- [ ] 5D: All three agents complete the README plan on repo-go
- [ ] 7.1–7.6: Jobs dashboard functions verified
