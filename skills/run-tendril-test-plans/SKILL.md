---
name: run-tendril-test-plans
description: >
  Run, validate, and orchestrate the Tendril development branch test plan.
  Use when starting a test session, verifying all skills are present, checking
  skill structure, running the end-to-end test plan, or confirming repo integrity.
license: MIT
allowed-tools: Bash Read
---

# run-tendril-test-plans

This repo is a pure documentation/skills project — no server, no build step, no compiled output. The "app" is a set of agent-runnable test skills for testing the Tendril desktop application. The driver is a smoke script that validates all skills exist and have correct frontmatter.

---

## Run (agent path)

### Smoke check — validate all skills are present and well-formed

```bash
bash skills/run-tendril-test-plans/scripts/smoke.sh
```

It discovers every directory under `skills/` dynamically and checks each `SKILL.md` against the [agentskills.io specification](https://agentskills.io/specification): the `name` field is present and matches the directory, `description` is non-empty, and no unrecognized top-level frontmatter keys are used. It also warns when a `SKILL.md` exceeds the recommended 500 lines.

Expected output (all 21 checks passing):

```
=== Tendril Test Plan — Skill Smoke Check ===

── Core documents
  ✓ skills/README.md

── Skill directories (spec compliance)
  ✓ connect-cua-lume-macos-vm/SKILL.md
  ✓ install-tendril-in-mac-vm/SKILL.md
  ✓ run-tendril-test-plans/SKILL.md
  ✓ setup-repo-dotnet/SKILL.md
  ✓ setup-repo-go/SKILL.md
  ✓ setup-repo-mono/SKILL.md
  ✓ setup-repo-node/SKILL.md
  ✓ setup-repo-python/SKILL.md
  ✓ setup-repo-react/SKILL.md
  ✓ test-onboarding-and-settings/SKILL.md
  ✓ test-plan-creation/SKILL.md
  ✓ test-plan-execution/SKILL.md
  ✓ test-recommendations-and-misc/SKILL.md
  ✓ test-review-and-pr/SKILL.md

── Execution-order check (README)
  ✓ README references setup-repo
  ✓ README references test-onboarding-and-settings
  ... (all pass)

  Passed: 21   Failed: 0   Warnings: 0
  Status: ALL CHECKS PASSED
```

Exit 0 = all skills present and spec-compliant. Exit 1 = at least one skill missing or has broken frontmatter. For full spec validation, run `pnpx check-skills validate skills --recursive` or `skills-ref validate skills/<name>`.

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
- **All skills live in `skills/<name>/SKILL.md`.** This is the single canonical tree, following the [agentskills.io specification](https://agentskills.io/specification). The `.agents/skills` and `.cursor/skills` directories are symlinks to `skills/` for cross-client discovery, and Claude Code loads the same tree via [`.claude-plugin/plugin.json`](../../.claude-plugin/plugin.json). Invoke skills explicitly with `/setup-repo-node`, `/test-plan-execution`, etc.

---

## Troubleshooting

**Smoke check fails with "SKILL.md missing" or "directory missing"**
→ A skill directory under `skills/` is missing its `SKILL.md`. Run `git status` to confirm nothing was left unstaged during a move.

**`smoke.sh: permission denied`**
→ `chmod +x skills/run-tendril-test-plans/scripts/smoke.sh` or run as `bash skills/run-tendril-test-plans/scripts/smoke.sh`.
