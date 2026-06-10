---
name: run-tendril-test-plans
description: >
  Run, validate, and orchestrate the Tendril production build manual test plan
  in the tendril-mac Lume VM via cua-agent-app. Use when starting a test session,
  verifying all skills are present, checking skill structure, provisioning the VM,
  running the end-to-end test plan, or confirming repo integrity.
license: MIT
compatibility: >-
  Requires a macOS host with Lume, uv, cua-agent-app, and a running tendril-mac VM
  with in-VM computer-server on port 8443. Test skills drive the Tendril GUI inside
  the VM using cua-agent-app primitives.
allowed-tools: Bash Read
---

# run-tendril-test-plans

This repo is a pure documentation/skills project — no server, no build step, no compiled output. The "app" is a set of agent-runnable test skills for testing the Tendril desktop application, plus [`cua-agent-app`](../../cua-agent-app/) as eyes and hands inside a Lume VM. The driver is a smoke script that validates all skills exist and have correct frontmatter.

**Primary target:** Tendril **production build** (test across multiple released versions). Use a `development` branch build only when validating unreleased changes.

**Test plan source of truth:** [`tendril-test-plan.md`](../../tendril-test-plan.md)

---

## Run (agent path)

### Smoke check — validate all skills are present and well-formed

```bash
bash skills/run-tendril-test-plans/scripts/smoke.sh
```

It discovers every directory under `skills/` dynamically and checks each `SKILL.md` against the [agentskills.io specification](https://agentskills.io/specification): the `name` field is present and matches the directory, `description` is non-empty, and no unrecognized top-level frontmatter keys are used. It also warns when a `SKILL.md` exceeds the recommended 500 lines.

Expected output (all checks passing):

```
=== Tendril Test Plan — Skill Smoke Check ===

── Core documents
  ✓ skills/README.md

── Skill directories (spec compliance)
  ✓ connect-cua-lume-macos-vm/SKILL.md
  ✓ install-tendril-in-mac-vm/SKILL.md
  ✓ run-tendril-test-plans/SKILL.md
  ... (all skills)

── Execution-order check (README)
  ✓ README references setup-repo
  ... (all pass)

  Passed: 21   Failed: 0   Warnings: 0
  Status: ALL CHECKS PASSED
```

Exit 0 = all skills present and spec-compliant. Exit 1 = at least one skill missing or has broken frontmatter. For full spec validation, run `pnpx check-skills validate skills --recursive` or `skills-ref validate skills/<name>`.

---

## VM & host prerequisites

Tests run **inside the `tendril-mac` Lume VM**. The invoking agent on the host controls the VM GUI through `cua-agent-app` — no nested LLM or API keys in that CLI.

### 1. Configure host environment

```bash
cp .env.example .env   # if not already present
# Fill in LUME_VM_NAME, LUME_VM_IP, LUME_VM_SSH_USER, LUME_VM_SSH_PASSWORD
```

Optional: pin a production release for install (`TENDRIL_VERSION=1.0.51` → `releases/tag/v1.0.51`).

### 2. Install cua-agent-app dependencies

```bash
cd cua-agent-app && uv sync
```

### 3. Start VM and verify CUA connectivity

```bash
set -a && source .env && set +a
lume run "${LUME_VM_NAME:-tendril-mac}"
cd cua-agent-app
uv run main.py screenshot --out screenshots/00-ready.png
```

If screenshots fail, run `/connect-cua-lume-macos-vm` (provision `computer-server`, Screen Recording grant, etc.).

### 4. Install Tendril in the VM (production build)

On a fresh VM or when upgrading versions, run `/install-tendril-in-mac-vm`. It downloads the **`IvyTendril-<version>-osx-arm64.pkg`** from GitHub Releases (production build) and installs via the macOS GUI, with a Terminal script fallback.

**Pass checkpoint:** native Ivy Tendril app window visible in a screenshot.

---

## Execute the test plan (in the VM via cua-agent-app)

There is nothing to launch from this repo except the CUA CLI. All Tendril GUI steps happen **in the VM**; the host agent drives them with screenshot → interpret → act.

### CUA agent contract (all test skills)

Whichever agent runs the test plan must:

1. Control the VM only through `cua-agent-app` CLI commands (from `cua-agent-app/`).
2. **Screenshot after every action** and verify the UI changed before continuing.
3. Save step evidence under `cua-agent-app/screenshots/` (numbered prefixes) or `test-runs/<date>/`.
4. Use logical display coordinates from `lume ls` (e.g. 1024×768), not raw PNG or `dimensions` pixel sizes — see [install-tendril-in-mac-vm](../install-tendril-in-mac-vm/SKILL.md) for the coordinate contract.
5. Never delegate to a nested LLM / `ComputerAgent` inside `cua-agent-app`.

**Core loop:**

```bash
cd cua-agent-app
uv run main.py screenshot --out screenshots/NN-step.png
# interpret image → pick coords → act
uv run main.py click --x X --y Y
uv run main.py type --text "..."
uv run main.py keypress --keys cmd,space
```

### Execution order

```
0. VM + Tendril (host)
   /connect-cua-lume-macos-vm   → computer-server on :8443
   /install-tendril-in-mac-vm    → production .pkg in VM (skip if already installed)

1. Set up repos (run on host — parallel)
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

**Minimum required for exit criteria:** VM + production Tendril installed, repo-node + repo-go, then skills 2–6 in order.

Each test skill describes the Tendril UI steps to perform; translate every "click", "navigate", and "launch" into the CUA loop above inside the VM.

### Required env before Section 1 (fresh onboarding)

To simulate a fresh install inside the VM, either clear `~/.tendril/` in the VM or launch Tendril from VM Terminal with an isolated home:

```bash
# In the VM via cua-agent-app type/keypress into Terminal:
export TENDRIL_HOME=$(mktemp -d -t tendril-test-home)
open -a "Ivy Tendril"
```

Without isolation, a prior test run's config in the VM will cause onboarding to be skipped in Section 1.

Record the production version under test in `tendril-test-plan.md` header fields (`Production version(s)`, `Date`, `Tester`).

---

## Gotchas

- **No binary here.** Tendril is installed in the VM from GitHub Releases (production `.pkg`). This repo contains only test runbooks and the CUA CLI.
- **VM-first.** Do not run Tendril GUI tests on the host — use the Lume VM and `cua-agent-app`.
- **TENDRIL_HOME isolation.** Must be set in the VM before launching Tendril for Section 1; host-side `export TENDRIL_HOME=...` does not affect the VM app.
- **Minimum repos.** Many test cases in `test-plan-execution` hard-require repo-node registered in Tendril first. Skipping `setup-repo-node` blocks ~60% of the plan.
- **Coordinate space.** Clicks use the VM logical display size (`lume ls` display column), not screenshot PNG dimensions. Wrong scaling clicks the wallpaper and flings windows to screen edges.
- **Scroll wheel unreliable.** Prefer dragging scrollbar thumbs or keyboard (`space`, arrows) over `scroll` in the VM.
- **All skills live in `skills/<name>/SKILL.md`.** This is the single canonical tree per [agentskills.io](https://agentskills.io/specification). `.agents/skills` and `.cursor/skills` are symlinks; Claude Code loads via [`.claude-plugin/plugin.json`](../../.claude-plugin/plugin.json). Invoke skills explicitly with `/setup-repo-node`, `/test-plan-execution`, etc.

---

## Troubleshooting

**Smoke check fails with "SKILL.md missing" or "directory missing"**
→ A skill directory under `skills/` is missing its `SKILL.md`. Run `git status` to confirm nothing was left unstaged during a move.

**`smoke.sh: permission denied`**
→ `chmod +x skills/run-tendril-test-plans/scripts/smoke.sh` or run as `bash skills/run-tendril-test-plans/scripts/smoke.sh`.

**`computer-server not ready after 120s` or screenshot errors**
→ Run `/connect-cua-lume-macos-vm` — provision server, grant Screen Recording to `python3.12` in the VM.

**VM stuck at login screen**
→ Log in manually in the Lume window before CUA primitives work (see `install-tendril-in-mac-vm`).

**Clicks land ~2× off target**
→ Re-measure as a fraction of the screenshot, multiply by logical display size (1024×768). See install skill coordinate section.

**Tendril not installed / wrong version**
→ Re-run `/install-tendril-in-mac-vm`; set `TENDRIL_VERSION` in `.env` to pin a release.
