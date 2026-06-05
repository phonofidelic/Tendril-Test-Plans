---
name: run-tendril-test-plans
description: >
  Run, validate, and orchestrate the Tendril development branch test plan.
  Use when starting a test session, verifying all skills are present, checking
  skill structure, running the end-to-end test plan, or confirming repo integrity.
allowed-tools: Bash Read
---

# run-tendril-test-plans

This repo is a pure documentation/skills project — no server, no build step, no compiled output. The "app" is a set of agent-runnable test skills for testing the Tendril desktop application. The driver is a smoke script that validates all skills exist and have correct frontmatter.

---

## Run (agent path)

### Smoke check — validate all skills are present and well-formed

```bash
bash .claude/skills/run-tendril-test-plans/smoke.sh
```

Expected output (all 19 checks passing):

```
=== Tendril Test Plan — Skill Smoke Check ===

── Core documents
  ✓ tendril-test-plan.md
  ✓ skills/README.md

── Skill directories
  ✓ setup-repo-node/SKILL.md
  ✓ setup-repo-python/SKILL.md
  ✓ setup-repo-go/SKILL.md
  ✓ setup-repo-react/SKILL.md
  ✓ setup-repo-mono/SKILL.md
  ✓ setup-repo-dotnet/SKILL.md
  ✓ test-onboarding-and-settings/SKILL.md
  ✓ test-plan-creation/SKILL.md
  ✓ test-plan-execution/SKILL.md
  ✓ test-review-and-pr/SKILL.md
  ✓ test-recommendations-and-misc/SKILL.md

── Execution-order check (README)
  ✓ README references setup-repo
  ✓ README references test-onboarding-and-settings
  ... (all pass)

  Passed: 19   Failed: 0
  Status: ALL CHECKS PASSED
```

Exit 0 = all skills present and correctly structured. Exit 1 = at least one skill missing or has broken frontmatter.

---

## Execute the test plan (against a live Tendril instance)

The test skills must be run against a running Tendril binary built from the `development` branch. There is nothing to launch from this repo.

### Execution order

```
1. Set up repos (run in parallel)
   /setup-repo-node    → repo-node (Node.js — required for most tests)
   /setup-repo-go      → repo-go   (Go — required for Section 5D)
   /setup-repo-python  → repo-python
   /setup-repo-react   → repo-react
   /setup-repo-mono    → repo-mono
   /setup-repo-dotnet  → repo-dotnet

2. /test-onboarding-and-settings  ← Sections 1, 2, 10
3. /test-plan-creation            ← Section 3
4. /test-plan-execution           ← Sections 4, 5, 7  ★ primary focus
5. /test-review-and-pr            ← Sections 6, 8
6. /test-recommendations-and-misc ← Sections 9, 11, 12
```

**Minimum required for exit criteria:** repo-node + repo-go, then skills 2–6 in order.

### Required env before starting any test skill

```bash
export TENDRIL_HOME=$(mktemp -d -t tendril-test-home)
```

This keeps test state out of `~/.tendril/` so runs are isolated.

---

## Gotchas

- **No binary here.** The Tendril app must be built separately (typically a **production build**, potentially multiple released versions). This repo contains only test runbooks.
- **TENDRIL_HOME isolation.** Without it, a prior test run's config will cause onboarding to be skipped in Section 1.
- **Minimum repos.** Many test cases in `test-plan-execution` hard-require repo-node to be registered in Tendril first. Skipping setup-repo-node will block you from ~60% of the plan.
- **Skills are in `skills/<name>/SKILL.md`, not `.claude/skills/`.** The test skills live under `skills/` (sibling to this skill), not inside `.claude/`. They are not auto-loaded — invoke them explicitly with `/setup-repo-node`, `/test-plan-execution`, etc.

---

## Troubleshooting

**Smoke check fails with "directory missing"**
→ The skill was deleted or the rename from `skills/*.md` to `skills/*/SKILL.md` was only partially staged. Run `git status` — the untracked directories in `skills/` should cover the deleted `.md` files.

**`smoke.sh: permission denied`**
→ `chmod +x .claude/skills/run-tendril-test-plans/smoke.sh` or run as `bash smoke.sh`.
