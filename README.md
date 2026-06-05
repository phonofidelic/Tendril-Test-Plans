# Tendril Test Plans

Agent skills and runbooks for executing the [Tendril](https://github.com/Ivy-Interactive/Ivy-Tendril) desktop application's **production build manual test plan** (across multiple released versions) — repo scaffolding, onboarding, plan creation, execution, review, and recommendations.

This repo is a pure documentation/skills project. There is **no server, build step, or compiled output**. The "app" is a set of agent-runnable test skills that drive a separately-built Tendril binary, plus a small Computer Use Agent helper for screenshotting a macOS VM.

It is packaged as a [Claude Code plugin](.claude-plugin/plugin.json) so the skills can be invoked directly (`/setup-repo-node`, `/test-plan-execution`, etc.).

---

## Repository layout

| Path | Purpose |
|---|---|
| `tendril-test-plan.md` | The source-of-truth manual test plan (sections 1–12, test matrix, exit criteria). Primarily used for **production builds across multiple versions**. |
| `skills/` | Agent-runnable test skills. One folder per skill, each with a `SKILL.md` runbook. See [`skills/README.md`](skills/README.md). |
| `.claude/skills/run-tendril-test-plans/` | Orchestrator skill + `smoke.sh` validator that checks every skill is present and well-formed. |
| `.claude-plugin/plugin.json` | Claude Code plugin manifest. |
| `cua-agent-app/` | Agent-agnostic CUA CLI (screenshot, click, type, …) for the `tendril-mac` Lume VM. |
| `.cursor/skills/install-tendril-in-mac-vm/` | Runbook to install Tendril on the VM via GUI (any Cursor agent). Run before test-plan skills on a fresh VM. |
| `.cursor/skills/connect-cua-lume-macos-vm/` | Connect CUA to the Lume VM and provision `computer-server`. |

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

The test skills run against a running Tendril binary built separately (typically a **production build**; optionally a `development` branch build when validating unreleased changes). There is nothing to launch from this repo. Execute the skills in order:

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

## cua-agent-app and VM install

**Fresh VM (no Tendril):** run the [install-tendril-in-mac-vm](.cursor/skills/install-tendril-in-mac-vm/SKILL.md) skill first. It cold-starts the VM, ensures CUA connectivity ([connect-cua-lume-macos-vm](.cursor/skills/connect-cua-lume-macos-vm/SKILL.md)), and installs Tendril GUI-first with a Terminal fallback. Any Cursor agent can execute it — no nested LLM or API keys in `cua-agent-app`.

```bash
cd cua-agent-app
uv sync
uv run main.py screenshot --out screenshots/00-ready.png
uv run main.py click --x 420 --y 310   # example primitive
```

Requires Python `>=3.12,<3.14`, a running Lume VM, and `computer-server` in the VM. See [`cua-agent-app/README.md`](cua-agent-app/README.md).

---

## Gotchas

- **No binary here.** The Tendril app must be built separately (typically a **production build**, potentially multiple released versions). This repo contains only test runbooks.
- **Skills live in `skills/<name>/SKILL.md`**, not `.claude/skills/`. They are not auto-loaded — invoke them explicitly.
- **`repo-node` is a hard dependency** for ~60% of `test-plan-execution`. Don't skip `setup-repo-node`.
