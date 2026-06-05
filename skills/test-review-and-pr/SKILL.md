---
name: test-review-and-pr
description: >
  Run Section 6 (Review & PR Creation) and Section 8 (Dashboard & Statistics) of the Tendril development branch test plan.
  Use when testing the review flow, PR creation rules (default, yolo, multi-repo, draft), and dashboard accuracy.
allowed-tools: Bash Read
license: MIT
metadata:
  effort: medium
---

# test-review-and-pr

Run Section 6 (Review & PR Creation) and Section 8 (Dashboard & Statistics) of the Tendril development branch test plan.

**Prerequisites:**
- At least one plan in `ReadyForReview` state (complete Section 5A first)
- GitHub credentials configured in Tendril (repo-node and/or repo-go accessible)
- For multi-repo tests: repo-mono or a plan spanning repo-node + repo-react

---

## Section 6A — Review Flow

### 6A.1 — Review diff

1. Select a plan in `ReadyForReview` → open `ReviewApp`.
2. **Expected:** The diff viewer displays changed files; individual hunks are visible and readable.
3. ✅ Pass if diff is rendered (not empty) and file names are shown.

### 6A.2 — Approve plan

1. In `ReviewApp`, click **Approve**.
2. **Expected:** Plan moves to the next stage — either PR creation is triggered or queued.
3. ✅ Pass if plan status advances past `ReadyForReview`.

### 6A.3 — Reject with notes

1. In `ReviewApp`, click **Reject** and enter change request notes:
   > *"The endpoint should return HTTP 201 instead of 200 for created items."*
2. **Expected:**
   - Plan moves to `Updating` (or equivalent rejected state).
   - A `RetryPlan` or `UpdatePlan` job is created.
   - The notes are visible in the job's prompt context.
3. ✅ Pass if plan status changes and notes appear in the new job.

### 6A.4 — Sample app preview

1. Create and execute a plan that generates a file under `Tools/` (e.g., a simple HTML demo page).
2. When plan reaches `ReadyForReview`, open `ReviewApp`.
3. **Expected:** The sample app renders in `ReviewApp` alongside the diff.
4. ✅ Pass if preview panel shows rendered content.
5. Record as informational if no sample app was generated (not a failure of the review flow itself).

---

## Section 6B — PR Creation ★

### 6B.1 — Create PR (default rule)

1. Approve a plan (6A.2 done).
2. Let `CreatePr` job run with the `default` PR rule.
3. **Expected:**
   - PR is created on GitHub.
   - `plan.yaml` is updated with a `prUrl:` field.
   - Plan status becomes `Completed`.
4. Verify on GitHub that the PR exists and is open.
5. ✅ Pass if all three conditions met.

### 6B.2 — PR visible in PullRequestApp

1. After 6B.1 completes.
2. Open `PullRequestApp`.
3. **Expected:** The PR appears in the list with its current GitHub status (e.g., Open).
4. ✅ Pass if PR is listed.

### 6B.3 — PR status sync

1. In GitHub, merge or close the PR from 6B.1.
2. Return to Tendril and wait for the sync interval (or trigger a manual refresh).
3. **Expected:** `PullRequestApp` updates the PR status to Merged or Closed within the sync interval.
4. ✅ Pass if status updates without a full app restart.

### 6B.4 — Yolo PR rule

1. Configure a test repo (use repo-go to avoid risk) with PR rule = `yolo`.
2. Approve a trivial plan (e.g., the README plan from 5D).
3. Let `CreatePr` run.
4. **Expected:**
   - PR is created and auto-merged using `--admin`.
   - Remote branch is deleted.
   - `main` is synced locally.
5. ✅ Pass if all three conditions met on the repo.
6. ⚠️ Do not run this on repo-node or repo-dotnet if those branches need protection.

### 6B.5 — Multi-repo PR

1. Execute a multi-repo plan (from 3B.2) spanning repo-node + repo-react.
2. Approve the plan.
3. Let `CreatePr` run.
4. **Expected:**
   - PRs are created on **both** repos.
   - Both PR URLs appear in `plan.yaml` under `prUrls:` (or equivalent).
5. ✅ Pass if two GitHub PRs exist and both are referenced in the plan.

### 6B.6 — Artifact upload

1. Execute a plan that produces a file in `Tools/` (any file — HTML, JSON, etc.).
2. Approve and let `CreatePr` run.
3. **Expected:** The artifact is attached to the GitHub PR (as a comment, PR description, or check attachment).
4. ✅ Pass if the artifact appears on the PR page in GitHub.

### 6B.7 — Worktree cleanup post-PR

1. After `CreatePr` completes successfully.
2. Check the filesystem: `ls $TENDRIL_HOME/worktrees/` (or equivalent).
3. **Expected:** The worktree directories for the completed plan are removed.
4. ✅ Pass if no stale worktree remains for the completed plan.

### 6B.8 — Draft PR mode

1. Configure Tendril (Settings or `config.yaml`) to create PRs as **drafts**.
2. Approve and execute `CreatePr` on a plan.
3. **Expected:** The PR is created as a **Draft** on GitHub.
4. Verify in GitHub that the PR shows the "Draft" label.
5. ✅ Pass if draft flag is applied.

---

## Section 8 — Dashboard & Statistics

### 8.1 — Daily stats accuracy

1. Complete 2 full plan runs (CreatePlan → Execute → PR created) on the same calendar day.
2. Open `DashboardApp`.
3. **Expected:** Stats show: `created = 2`, `completed = 2`, `PRs = 2`, and the cost total matches the sum of both job costs.
4. ✅ Pass if all four values are correct.

### 8.2 — Per-project breakdown

1. Have plans completed on both **repo-node** and **repo-python**.
2. **Expected:** Dashboard shows separate rows (or sections) per project.
3. ✅ Pass if two distinct project entries appear.

### 8.3 — Failed plan counted

1. Let one plan execution fail (use 5B.2 or 5C.2).
2. Check `DashboardApp`.
3. **Expected:** The `failed` counter increments; the average cost/plan calculation reflects the failed run.
4. ✅ Pass if failed counter is non-zero and average cost is recalculated.

---

## Validation checklist

- [ ] 6A.1–6A.4: Review flow (diff, approve, reject, sample preview)
- [ ] 6B.1: PR created on GitHub with URL in plan.yaml
- [ ] 6B.2: PR visible in PullRequestApp
- [ ] 6B.3: PR status syncs after GitHub merge/close
- [ ] 6B.4: Yolo rule auto-merges and cleans up branch
- [ ] 6B.5: Multi-repo plan creates PRs on both repos
- [ ] 6B.6: Artifact attached to PR
- [ ] 6B.7: Worktree cleaned up after PR creation
- [ ] 6B.8: Draft PR mode creates Draft on GitHub
- [ ] 8.1–8.3: Dashboard stats accurate
