# Tendril Test Plans

Agent skills and runbooks for executing the [Tendril](https://github.com/phonofidelic) desktop application's **`development` branch manual test plan** — repo scaffolding, onboarding, plan creation, execution, review, and recommendations.

This repo is a pure documentation/skills project. There is **no server, build step, or compiled output**. The "app" is a set of agent-runnable test skills that drive a separately-built Tendril binary, plus a small Computer Use Agent helper for screenshotting a macOS VM.

It is packaged as a [Claude Code plugin](.claude-plugin/plugin.json) so the skills can be invoked directly (`/setup-repo-node`, `/test-plan-execution`, etc.).

---

## Repository layout

| Path | Purpose |
|---|---|
| `development-branch-test-plan.md` | The source-of-truth manual test plan (sections 1–12, test matrix, exit criteria). |
| `skills/` | Agent-runnable test skills. One folder per skill, each with a `SKILL.md` runbook. See [`skills/README.md`](skills/README.md). |
| `.claude/skills/run-tendril-test-plans/` | Orchestrator skill + `smoke.sh` validator that checks every skill is present and well-formed. |
| `.claude-plugin/plugin.json` | Claude Code plugin manifest. |
| `cua-agent-app/` | Computer Use Agent helper (Python + [`cua`](https://pypi.org/project/cua/)) for screenshotting a local macOS Lume VM. |

---

## Skills

### Repo setup skills

| Skill | Repo alias | Stack |
|---|---|---|
| `setup-repo-node` | repo-node | Express / Node.js + TypeScript |
| `setup-repo-python` | repo-python | FastAPI / Python |
| `setup-repo-go` | repo-go | Go HTTP server |
| `setup-repo-react` | repo-react | Vite + React + TypeScript |
| `setup-repo-mono` | repo-mono | npm workspaces (two packages) |
| `setup-repo-dotnet` | repo-dotnet | ASP.NET Core Web API |

**Minimum required for exit criteria:** `repo-node` + `repo-go`.

### Test scenario skills

| Skill | Test plan sections |
|---|---|
| `test-onboarding-and-settings` | 1, 2, 10 |
| `test-plan-creation` | 3 |
| `test-plan-execution` | 4, 5, 7 — primary focus |
| `test-review-and-pr` | 6, 8 |
| `test-recommendations-and-misc` | 9, 11, 12 |

---

## Getting started

### 1. Validate the skills are intact

```bash
bash .claude/skills/run-tendril-test-plans/smoke.sh
```

Exit `0` means all skills are present and correctly structured.

### 2. Isolate test state

```bash
export TENDRIL_HOME=$(mktemp -d -t tendril-test-home)
```

This keeps test state out of `~/.tendril/` so each run starts clean (otherwise onboarding is skipped in Section 1).

### 3. Run the plan

The test skills run against a running Tendril binary built separately from the `development` branch — there is nothing to launch from this repo. Execute the skills in order:

```
1. Set up repos (in parallel)
   /setup-repo-node    → repo-node (required for most tests)
   /setup-repo-go      → repo-go   (required for Section 5D)
   /setup-repo-python /setup-repo-react /setup-repo-mono /setup-repo-dotnet

2. /test-onboarding-and-settings   ← Sections 1, 2, 10
3. /test-plan-creation             ← Section 3
4. /test-plan-execution            ← Sections 4, 5, 7
5. /test-review-and-pr             ← Sections 6, 8
6. /test-recommendations-and-misc  ← Sections 9, 11, 12
```

---

## Exit criteria

- [ ] All ★-marked tests pass on **Claude Code / balanced / repo-node**
- [ ] No P1 or P2 defects open
- [ ] Cost tracking accurate for at least one complete end-to-end run
- [ ] At least one plan executed with Codex or OpenCode (Section 5D)
- [ ] All Section 10 regression checks pass

---

## cua-agent-app

A small helper that connects to a local macOS [Lume](https://github.com/trycua/cua) VM (named `tendril-mac`) to capture screenshots — useful for visually verifying the Tendril UI during a test run.

```bash
cd cua-agent-app
uv sync
uv run main.py   # saves screenshots/test-screenshot.png
```

Requires Python `>=3.12,<3.14` and a running Lume VM. See `cua-agent-app/main.py`.

---

## Gotchas

- **No binary here.** The Tendril app must be built separately from the `development` branch. This repo contains only test runbooks.
- **Skills live in `skills/<name>/SKILL.md`**, not `.claude/skills/`. They are not auto-loaded — invoke them explicitly.
- **`repo-node` is a hard dependency** for ~60% of `test-plan-execution`. Don't skip `setup-repo-node`.
