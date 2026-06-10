---
name: test-onboarding-and-settings
description: >
  Run Sections 1, 2, and 10 of the Tendril production build test plan in the
  tendril-mac VM via cua-agent-app. Use when testing first-run onboarding,
  coding agent settings, projects, verifications, tunnel, and regression checks.
allowed-tools: Bash Read
license: MIT
metadata:
  effort: medium
---

# test-onboarding-and-settings

Run Sections 1, 2, and 10 of the Tendril production build test plan.

**Execution model:** All Tendril GUI steps run inside the `tendril-mac` Lume VM via [`cua-agent-app`](../../cua-agent-app/) (screenshot → click/type). See [run-tendril-test-plans](../run-tendril-test-plans/SKILL.md) for the CUA contract, coordinate space, and VM prerequisites.

**Prerequisites:**
- Tendril **production build** installed in the VM (`/install-tendril-in-mac-vm`)
- VM running with CUA connectivity (`/connect-cua-lume-macos-vm`)
- All six test repos created and pushed on the host (`/setup-repo-*`); register GitHub URLs or VM-local paths in Tendril Projects

---

## Section 1 — First-Run & Onboarding

### Setup (in the VM)

To simulate a fresh install, launch Tendril from VM Terminal with an isolated home (type via `cua-agent-app`):

```bash
export TENDRIL_HOME=$(mktemp -d -t tendril-test-home)
open -a "Ivy Tendril"
```

Or clear `~/.tendril/` in the VM before the first launch. Host-side `TENDRIL_HOME` does not affect the VM app.

### 1.1 — Fresh onboarding flow

1. Launch Ivy Tendril in the VM (Spotlight or Dock via `cua-agent-app`).
2. **Expected:** `OnboardingApp` loads; the wizard presents steps for agent selection, project setup, and API key entry.
3. Walk through all wizard steps with valid values.
4. ✅ Pass if each step advances and completes without error.

### 1.2 — Onboarding skips on subsequent launch

1. Complete onboarding (1.1), then quit the app (`Cmd+Q` via `keypress`).
2. Relaunch from Dock or Spotlight.
3. **Expected:** App opens directly to `DashboardApp`; onboarding wizard is not shown.
4. ✅ Pass if dashboard loads immediately.

### 1.3 — Config error surface

1. Locate `$TENDRIL_HOME/config.yaml` in the VM (SSH or VM Terminal).
2. Corrupt it by inserting invalid YAML (e.g., `key: [unclosed`).
3. Relaunch Ivy Tendril in the VM.
4. **Expected:** `ConfigErrorApp` loads with a legible error message; no crash or blank screen.
5. ✅ Pass if error message identifies the YAML parse failure.

---

## Section 2A — Coding Agent Settings ★

### 2A.1 — Switch active agent

1. Settings → Coding Agent → change active agent from **Claude Code** to **Codex**.
2. **Expected:** The active agent badge in the nav updates to show Codex.
3. ✅ Pass if badge updates without page reload required.

### 2A.2 — Model-per-profile selection

1. For Claude Code, open the `quick` profile and set a specific model (e.g., `claude-haiku-4-5`).
2. Open the `deep` profile and set a different model (e.g., `claude-opus-4-7`).
3. Create and execute a job under each profile.
4. **Expected:** Each job's model in the output matches the profile's configured model.
5. ✅ Pass if models are stored independently per profile.

### 2A.3 — Model dropdown shows "Default" (regression #885)

1. Open model dropdown for any agent profile.
2. **Expected:** A "Default" option appears at the top of the list.
3. ✅ Pass if "Default" is present.
4. ❌ Fail → log as regression for **#885**.

### 2A.4 — Null model during agent switch

1. Queue a plan for execution but do not start it yet.
2. Go to Settings → Coding Agent and switch the active agent.
3. Start the queued job.
4. **Expected:** No crash; job executes using the correct model for the newly selected agent.
5. ✅ Pass if job completes without a null-reference error.

---

## Section 2B — Projects ★

### 2B.1 — Add first project

1. Settings → Projects → Add → point to **repo-node** local path or GitHub URL.
2. **Expected:** Project appears in the list; Tendril detects stack as **Node.js**.
3. ✅ Pass if stack label shows Node.js (or JS/TypeScript).

### 2B.2 — Edit project (regression #887)

1. With only **repo-node** in the list, click Edit on it (first project).
2. **Expected:** Edit dialog opens pre-populated with repo-node's data.
3. ✅ Pass if correct data shown.
4. ❌ If dialog is empty or shows wrong data → regression **#887**.

### 2B.3 — Add second project and edit first

1. Add **repo-python** (repo-node is already present).
2. Click Edit on **repo-node** (first in list).
3. **Expected:** Edit dialog populates repo-node's data, not repo-python's.
4. ✅ Pass if name/path/stack matches repo-node.
5. ❌ If repo-python data shown → regression **#887**.

### 2B.4 — Remove project

1. Add a project.
2. Delete it using the trash/remove action.
3. **Expected:** Project removed from list; no orphaned worktrees under `$TENDRIL_HOME/`.
4. ✅ Pass if `ls $TENDRIL_HOME/worktrees/` (or equivalent) shows no stale directories for that repo.

---

## Section 2C — Verifications

### 2C.1 — Configure build + test + lint

1. Settings → Verifications → select repo-node.
2. Set:
   - Build: `npm run build`
   - Test: `npm test`
   - Lint: `npm run lint`
3. Save.
4. **Expected:** Commands persisted in `config.yaml`.
5. ✅ Pass if opening Config Editor shows the commands under the repo-node entry.

### 2C.2 — Mark a verification as required

1. Set the `test` verification as `required: true`.
2. **Expected:** `required: true` key appears in config; executing a plan that breaks tests blocks PR creation.
3. ✅ Pass if config reflects the flag and future plan failures are blocked (confirm with 5B.2).

### 2C.3 — Intentionally failing verification

1. Set lint command to `exit 1`.
2. Execute any plan on repo-node.
3. **Expected:**
   - Plan does not advance to PR creation.
   - Verification tab shows `Fail` for lint.
   - A report exists at `<PlanFolder>/Verification/lint.md`.
4. ✅ Pass if all three conditions met.
5. Restore lint command to `npm run lint` afterward.

---

## Section 2D — Tunnel ★

### 2D.1 — Enable tunnel (regression #884)

1. Settings → Tunnel → enable cloudflared tunnel.
2. **Expected:** App waits for the tunnel to become routable before marking status as "Connected".
3. ✅ Pass if "Connected" badge only appears after the tunnel URL is resolvable.
4. ❌ If "Connected" shows immediately before tunnel is ready → regression **#884**.

### 2D.2 — QR code display

1. With tunnel enabled and connected (2D.1 passing).
2. Open Tunnel settings panel.
3. **Expected:** A QR code renders showing the tunnel URL.
4. ✅ Pass if QR code is visible and scannable.

---

## Section 10 — Edge Cases & Regression Checks

Run these in sequence after Sections 1–2. Each maps to a known regression.

| ID | Steps | Regression |
|---|---|---|
| **10.1** | Add repo-node, then repo-python. Edit repo-node. Verify dialog shows repo-node data. | #887 |
| **10.2** | Open model dropdown for any profile. Verify "Default" option present at top. | #885 |
| **10.3** | Enable tunnel. Verify "Connected" appears only after tunnel is routable. | #884 |
| **10.4** | In WallpaperApp, click "New Plan". Verify `CreatePlanDialog` opens. | #879 |
| **10.5** | Queue a job. Switch active agent. Start job. Verify no crash. | #880 |
| **10.6** | *(Windows only)* Configure Codex agent. Execute a plan. Verify `.cmd` path resolves. | #883 |
| **10.7** | Open any running job. Inspect process view button alignment and pulse indicator color. | #882 |

---

## Defect logging

For any failure, add a row to the Defect Log in `tendril-test-plan.md`:

```
| <N> | Section X | <ID> | <Agent> | <Repo> | <Description> | P1–P4 | <cua-agent-app/screenshots/...> |
```
