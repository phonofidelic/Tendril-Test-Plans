---
name: test-plan-creation
description: >
  Run Section 3 (Plan Creation) of the Tendril development branch test plan.
  Use when testing plan creation, duplicate detection, project inference, and multi-repo descriptions.
allowed-tools: Bash Read
effort: medium
---

# test-plan-creation

Run Section 3 (Plan Creation) of the Tendril development branch test plan.

**Prerequisites:**
- Tendril running on `development` branch
- repo-node and repo-python added to Settings → Projects
- Verifications configured for repo-node (build/test/lint)

---

## Section 3A — Happy Path ★

### 3A.1 — Create plan from sidebar

1. Open `DraftsApp`.
2. Click **New Plan**.
3. Describe a small feature: e.g., *"Add a POST /items endpoint that accepts a JSON body with a `name` field and returns the created item."*
4. **Expected:**
   - A `CreatePlan` job appears in the Jobs dashboard.
   - After the job completes, the plan moves to `Draft` state.
   - A `plan.yaml` file is written to the plan folder.
   - A first revision file (e.g., `revision-01.md`) is present.
5. ✅ Pass if plan folder contains both `plan.yaml` and a revision file.

### 3A.2 — Create plan from wallpaper (regression #879)

1. Navigate to `WallpaperApp`.
2. Click the **New Plan** button.
3. **Expected:** `CreatePlanDialog` opens.
4. ✅ Pass if dialog opens.
5. ❌ If button does nothing → regression **#879**.

### 3A.3 — Plan infers correct project

1. In the description, reference a file path unique to repo-python, e.g.:
   > *"Refactor `src/app.py` to extract the `/items` handler into its own module."*
2. **Expected:** The plan's `project` field in `plan.yaml` resolves to **repo-python**, not repo-node.
3. ✅ Pass if `project:` in `plan.yaml` matches repo-python.

### 3A.4 — Duplicate detection

1. Submit the same description twice (use the exact text from 3A.1).
2. **Expected:** The second `CreatePlan` job either:
   - Surfaces a warning indicating a duplicate plan exists, or
   - Links to the existing plan rather than creating a new one.
3. ✅ Pass if duplicate is detected and handled gracefully.
4. Record observed behavior in the defect log if it silently creates a second plan.

### 3A.5 — GitHub issue search

1. In the plan description, include a GitHub issue reference, e.g.:
   > *"Fix issue #12 — add input validation to POST /items"*
   Or paste a full issue URL.
2. **Expected:**
   - `CreatePlan` job fetches the issue body from GitHub.
   - The resulting plan title and/or description reflects the issue content.
3. ✅ Pass if `plan.yaml` title/description mentions content from the referenced issue.

---

## Section 3B — Plan Description Quality

### 3B.1 — Vague description

1. Submit the description: **"make it better"**.
2. **Expected:** Plan is created but one of the following occurs:
   - It is flagged as needing expansion.
   - The agent asks for clarification.
   - The plan body acknowledges the vagueness and produces a broad draft.
3. ✅ Pass if the plan does not silently generate a nonsensical or empty spec.
4. Record the specific behavior observed.

### 3B.2 — Multi-repo description

1. Submit a description that mentions both backends:
   > *"Add a `POST /items` endpoint to the Node API and create a corresponding ItemForm component in the React frontend."*
2. **Expected:**
   - The plan's `repos` field in `plan.yaml` lists both **repo-node** and **repo-react**.
   - When executed, Tendril creates worktrees for each repo.
3. ✅ Pass if `repos:` in `plan.yaml` contains both repo identifiers.

---

## Validation checklist

- [ ] 3A.1: `plan.yaml` + `revision-01.md` created for new plan
- [ ] 3A.2: `CreatePlanDialog` opens from WallpaperApp (regression #879)
- [ ] 3A.3: Project inferred correctly from file path in description
- [ ] 3A.4: Duplicate description triggers warning or link to existing plan
- [ ] 3A.5: GitHub issue content reflected in plan
- [ ] 3B.1: Vague description handled without silent failure
- [ ] 3B.2: Multi-repo description results in `repos:` listing both projects
