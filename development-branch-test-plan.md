# Tendril Development Branch - Manual Test Plan

**Branch:** `development`
**Date:** 2026-05-27
**Tester:**
**Agent Under Test:**

---

## Test Repositories

Create or fork one repo per stack to cover the most common project types. Keep them small so execution is fast and costs stay low.

| Alias | Suggested Repo | Stack | Purpose |
|---|---|---|---|
| **repo-node** | A minimal Express/Node.js REST API | Node.js | TypeScript/JS stack |
| **repo-python** | A minimal FastAPI or Flask app | Python | Python stack |
| **repo-go** | A minimal Go HTTP server | Go | Compiled, no package manager friction |
| **repo-react** | A Vite + React frontend | React/TS | Frontend-only changes |
| **repo-mono** | A simple monorepo (two packages) | Mixed | Multi-repo plan testing |

Each repo should have:
- A working CI/build command (e.g., `npm run build`, `go build ./...`)
- A test command with at least one passing test
- A lint command
- A `main` branch protected enough to require PRs (optional but realistic)

---

## Test Matrix - Agents × Scenarios

| Agent | Profile | Scenario Coverage |
|---|---|---|
| Claude Code | `balanced` | Core happy-path (primary) |
| Claude Code | `quick` | Speed vs. quality tradeoff |
| Claude Code | `deep` | Complex multi-file plan |
| Codex | `balanced` | Cross-agent parity check |
| OpenCode | `balanced` | Alternative agent parity |

Run at minimum the **Claude Code / balanced** column end-to-end. Run other agents on the subset marked ★ below.

---

## Section 1 - First-Run & Onboarding

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 1.1 | Fresh onboarding flow | Clear `~/.tendril/` or use `TENDRIL_HOME` override. Launch app. | OnboardingApp loads; wizard walks through agent selection, project setup, API key entry. |
| 1.2 | Onboarding skips on subsequent launch | Complete onboarding, quit, relaunch. | App opens directly to DashboardApp; onboarding not shown. |
| 1.3 | Config error surface | Corrupt `config.yaml` (bad YAML). | ConfigErrorApp loads with a legible error message rather than a crash. |

---

## Section 2 - Settings & Configuration

### 2A - Coding Agent Settings ★

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 2A.1 | Switch active agent | Settings → Coding Agent → change from Claude Code to Codex. | Active agent badge updates in nav. |
| 2A.2 | Model-per-profile selection | For Claude Code, set a different model on `quick` vs. `deep` profiles. | Each profile stores its own model; switching profile in a job picks the right model. |
| 2A.3 | Model dropdown shows "Default" | Open model dropdown for any profile. | A "Default" option appears at the top of the list (regression for #885). |
| 2A.4 | Null model during agent switch | Switch agent while a job is queued. | No crash; job picks up correct model for new agent. |

### 2B - Projects ★

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 2B.1 | Add first project | Settings → Projects → Add → point to repo-node. | Project appears in list; Tendril detects stack (Node.js). |
| 2B.2 | Edit project | Add project, then immediately edit it (first project in list). | Edit dialog opens for the correct project - not an index-off-by-one (regression for #887). |
| 2B.3 | Add second project and edit first | Add repo-node, then repo-python. Edit repo-node. | Edit dialog populates repo-node's data. |
| 2B.4 | Remove project | Add a project, then delete it. | Project disappears; no orphaned worktrees remain in `~/.tendril/`. |

### 2C - Verifications

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 2C.1 | Configure build + test + lint | Settings → Verifications → define commands for repo-node. | Commands saved to config. |
| 2C.2 | Mark a verification as required | Set `test` as required. | `required: true` appears in config; execution blocks on failure. |
| 2C.3 | Intentionally failing verification | Set lint command to `exit 1`. Execute a plan. | Plan does not advance to PR creation; Verification tab shows `Fail`; verification report written to `<PlanFolder>/Verification/lint.md`. |

### 2D - Tunnel ★

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 2D.1 | Enable tunnel | Settings → Tunnel → enable cloudflared. | App waits for tunnel to become routable before marking connected (regression for #884). |
| 2D.2 | QR code display | Tunnel enabled and connected. | QR code renders in Tunnel settings panel. |

---

## Section 3 - Plan Creation

### 3A - Happy Path ★

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 3A.1 | Create plan from sidebar | DraftsApp → New Plan button → describe a small feature for repo-node. | CreatePlan job appears in Jobs. Plan moves to `Draft` state with `plan.yaml` and first revision. |
| 3A.2 | Create plan from wallpaper | Switch to WallpaperApp → click "New Plan". | CreatePlanDialog opens (regression for #879). |
| 3A.3 | Plan infers correct project | Describe a change mentioning a file path unique to repo-python. | Plan's `project` field resolves to repo-python. |
| 3A.4 | Duplicate detection | Submit the same description twice. | Second CreatePlan job detects the duplicate and either surfaces a warning or links to existing plan. |
| 3A.5 | GitHub issue search | In description, reference a GitHub issue number or paste an issue URL. | CreatePlan fetches issue body; plan title/description reflects issue content. |

### 3B - Plan Description Quality

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 3B.1 | Vague description | Submit "make it better". | Plan is created but flagged as needing expansion; agent asks for clarification or produces a broad draft. |
| 3B.2 | Multi-repo description | Describe a feature touching both repo-node (backend) and repo-react (frontend). | Plan's `repos` field lists both repos; worktrees are created for each on execute. |

---

## Section 4 - Plan Lifecycle Management

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 4.1 | Expand plan | Select a Draft plan → Expand. | ExpandPlan job runs; plan splits into sub-tasks visible in DraftsApp. |
| 4.2 | Update plan | Select a plan → Update → provide refinement notes. | UpdatePlan job runs; new revision file written (`revision-02.md`); plan YAML reflects changes. |
| 4.3 | Move to Icebox | Select a Draft → Icebox. | Plan status becomes `Icebox`; appears in IceboxApp; gone from DraftsApp. |
| 4.4 | Restore from Icebox | In IceboxApp, restore plan. | Plan returns to `Draft`; appears in DraftsApp. |
| 4.5 | Delete plan | Select a plan → Delete (trash icon). | Plan moves to TrashApp; filesystem folder moves to `~/.tendril/Trash/`. |
| 4.6 | Mark plan Blocked | Set a `dependsOn` for plan B referencing plan A. | Plan B shows status `Blocked` until plan A completes. |
| 4.7 | Skip plan | Mark a Draft as Skipped. | Status becomes `Skipped`; plan is not executed. |

---

## Section 5 - Plan Execution ★

### 5A - Core Execution

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 5A.1 | Execute plan (Claude Code / balanced) | Approve a Draft → Execute. | ExecutePlan job created; isolated git worktree created at correct branch (`tendril/<planId>-<title>`); agent runs against worktree. |
| 5A.2 | Worktree isolation | While plan is Executing, make a change to the main branch of repo-node. | Agent's worktree is unaffected; main branch change doesn't pollute execution. |
| 5A.3 | Plan completes with commits | Let ExecutePlan finish. | `plan.yaml` updated with `commits` list; job shows `Completed`; plan moves to `ReadyForReview`. |
| 5A.4 | Job output streaming | Watch the job in JobsApp during execution. | Output lines stream in real time; cost and token counters update. |
| 5A.5 | Skip re-execution when clean | Execute a plan successfully. Then execute same plan again without changes. | Second execution detects verifications already pass and code is clean; skips agent run. |

### 5B - Verification Gates ★

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 5B.1 | All verifications pass | Repo has working build + test + lint; execute a trivial plan. | All three gates show `Pass`; `summary.md` written; plan advances normally. |
| 5B.2 | Required verification fails | Set test as required; execute plan where agent produces code that breaks tests. | Plan does not advance to PR; status shows `Failed`; verification report details failure. |
| 5B.3 | Optional verification fails | Set lint as non-required; agent produces lint warning. | Plan advances to ReadyForReview; lint shows `Fail` but is non-blocking. |
| 5B.4 | Verification status in UI | After execution, view plan detail. | Verifications tab shows each gate name, status badge (Pass/Fail/Skipped), and link to report. |

### 5C - Timeout & Error Handling

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 5C.1 | 30-minute timeout | Create a plan on a complex task that will run long (or mock via config). | Job is cancelled after timeout; status becomes `Timeout`; worktree preserved for inspection. |
| 5C.2 | Agent process crash | Kill the agent process mid-execution. | Job status becomes `Failed`; error surfaced in Jobs dashboard; worktree not cleaned up automatically. |
| 5C.3 | Retry after failure | After a Failed execution, trigger Retry. | RetryPlan job runs; change request notes are included in prompt; new attempt starts fresh in same worktree. |

### 5D - Cross-Agent Parity ★

For each agent below, run the same small plan on repo-go (a `go build ./...`-safe change like adding a README or a helper function):

| Agent | Profile | 5D.1 Worktree Created | 5D.2 Output Streams | 5D.3 Cost Tracked | 5D.4 Completes |
|---|---|---|---|---|---|
| Claude Code | balanced | | | | |
| Codex | balanced | | | | |
| OpenCode | balanced | | | | |

---

## Section 6 - Review & PR Creation ★

### 6A - Review Flow

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 6A.1 | Review diff | Plan is `ReadyForReview` → open ReviewApp. | Diff viewer shows changed files; individual hunks visible. |
| 6A.2 | Approve plan | In ReviewApp, approve the plan. | Plan moves to next stage (PR creation triggered or queued). |
| 6A.3 | Reject with notes | In ReviewApp, reject and add change request notes. | Plan moves to `Updating`; RetryPlan or UpdatePlan job created with notes passed to agent. |
| 6A.4 | Sample app preview | If the plan includes a sample app in `Tools/`, preview renders in ReviewApp. | Rendered sample app visible alongside the diff. |

### 6B - PR Creation ★

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 6B.1 | Create PR (default rule) | Plan approved → CreatePr runs with `default` PR rule. | PR created on GitHub; `plan.yaml` updated with PR URL; plan status `Completed`. |
| 6B.2 | PR visible in PullRequestApp | After 6B.1. | PR appears in PullRequestApp with status from GitHub. |
| 6B.3 | PR status sync | Merge or close the PR in GitHub. Return to Tendril. | PullRequestApp updates PR status within the sync interval. |
| 6B.4 | Yolo PR rule | Configure repo with `yolo` PR rule. Approve plan. | CreatePr auto-merges PR with `--admin`, deletes remote branch, syncs main. |
| 6B.5 | Multi-repo PR | Execute multi-repo plan. Approve. | CreatePr creates PRs on both repos; both URLs appear in `plan.yaml`. |
| 6B.6 | Artifact upload | Plan produces files in `Tools/` directory. | Artifacts attached to GitHub PR. |
| 6B.7 | Worktree cleanup post-PR | After CreatePr completes. | Worktree directories removed from filesystem. |
| 6B.8 | Draft PR mode | Configure draft PR mode. | PR created as Draft on GitHub. |

---

## Section 7 - Jobs Dashboard ★

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 7.1 | All job types visible | Run CreatePlan, ExecutePlan, CreatePr in sequence. | All three job types appear in JobsApp with correct status icons. |
| 7.2 | Cost + token tracking | Complete a plan end-to-end. | JobsApp shows input tokens, output tokens, cost per job; DashboardApp totals match. |
| 7.3 | Stop a running job | While ExecutePlan is running, click Stop. | Job status becomes `Stopped`; process is killed; worktree preserved. |
| 7.4 | Output line limit | Generate a very verbose job (many output lines). | UI renders smoothly; no crash when output approaches 10,000-line cap. |
| 7.5 | Concurrent jobs | Submit two plans and execute both simultaneously. | Both jobs appear in JobsApp; each has independent cost tracking; no cross-contamination of output. |
| 7.6 | Failed job retry | A job fails. | Retry button appears; clicking it creates a new job rather than mutating the old one. |

---

## Section 8 - Dashboard & Statistics

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 8.1 | Daily stats accuracy | Complete 2 plans with PRs on the same day. | DashboardApp shows created=2, completed=2, PRs=2, correct cost total. |
| 8.2 | Per-project breakdown | Have plans across repo-node and repo-python. | Dashboard shows separate rows per project. |
| 8.3 | Failed plan counted | Let a plan fail. | `failed` counter increments; reflected in average cost/plan calculation. |

---

## Section 9 - Recommendations

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 9.1 | Recommendation appears | After several completed plans, check RecommendationsApp. | AI-generated suggestions visible with impact/risk metadata. |
| 9.2 | Approve recommendation | Click Approve on a recommendation. | Recommendation converts to a Draft plan in DraftsApp. |
| 9.3 | Decline with notes | Click Decline, add notes. | Recommendation removed from list; notes preserved. |

---

## Section 10 - Edge Cases & Regression Checks

| ID | Test Case | Regression For |
|---|---|---|
| 10.1 | Edit first project after adding a second | #887 - project edit dialog index mismatch |
| 10.2 | Model dropdown includes "Default" option | #885 - model dropdown missing Default |
| 10.3 | Tunnel marks connected only after routable | #884 - premature connection declaration |
| 10.4 | Wallpaper New Plan button opens CreatePlanDialog | #879 - button did nothing |
| 10.5 | Null model during agent switch does not crash | #880 - null model reference |
| 10.6 | Windows: Codex/Copilot resolves `.cmd` extension | #883 - PTY command resolution (Windows only) |
| 10.7 | Process view button alignment and pulse color | #882 - UI layout regression |

---

## Section 11 - Config Editor & Raw Config

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 11.1 | Open raw config | Nav → Config Editor. | `config.yaml` contents displayed in editor. |
| 11.2 | Edit and save valid YAML | Make a minor change (e.g., change a label). | Config saved; change reflected in Settings UI. |
| 11.3 | Save invalid YAML | Introduce a YAML parse error. | ConfigErrorApp loads; error message shown; previous config not overwritten. |

---

## Section 12 - Agent Playground (AgentApp)

| ID | Test Case | Steps | Expected |
|---|---|---|---|
| 12.1 | Start live session | AgentApp → select agent + repo → start. | Agent spawns; output streams in real time. |
| 12.2 | Send message mid-session | Type a prompt and submit. | Agent receives prompt and responds; cost updates. |
| 12.3 | Stop session | Click Stop. | Agent process terminates cleanly; session log preserved. |

---

## Defect Log

| # | Section | Test ID | Agent | Repo | Description | Severity | Screenshot/Log |
|---|---|---|---|---|---|---|---|
| | | | | | | | |

**Severity:** P1 (crash/data loss) · P2 (feature broken) · P3 (degraded UX) · P4 (cosmetic)

---

## Exit Criteria

- All ★-marked tests pass on Claude Code / balanced / repo-node
- No P1 or P2 defects open
- Cost tracking is accurate (within rounding) for at least one complete end-to-end run
- At least one plan executed successfully with each additional agent (Codex or OpenCode)
- All Section 10 regression checks pass
