---
name: run-tendril-test-plans
description: >
  Run, validate, and orchestrate the Tendril production build manual test plan
  in a test VM (Lume macOS, or UTM macOS/Ubuntu/Windows) via cua-agent-app. Use
  when starting a test session, verifying all skills are present, checking skill
  structure, provisioning a VM, running the end-to-end test plan, recording
  test-run output under test-runs/, or confirming repo integrity.
license: MIT
compatibility: >-
  Requires a macOS host with uv and cua-agent-app, plus a running guest VM with
  cua computer-server: tendril-mac under Lume (port 8443) or a UTM
  macOS/Ubuntu/Windows guest (port 8000, connected via CUA_HTTP_URL). Test
  skills drive the Tendril UI inside the guest using cua-agent-app primitives.
allowed-tools: Bash Read Write
---

# run-tendril-test-plans

This repo is a pure documentation/skills project — no server, no build step, no compiled output. The "app" is a set of agent-runnable test skills for testing the Tendril application, plus [`cua-agent-app`](../../cua-agent-app/) as eyes and hands inside a guest VM (Lume macOS, or UTM macOS/Ubuntu/Windows). The driver is a smoke script that validates all skills exist and have correct frontmatter, and every test session must produce a formal run record under [`test-runs/`](../../test-runs/) (see "Test-run output" below).

**Primary target:** Tendril **production build** (test across multiple released versions). Use a `development` branch build only when validating unreleased changes.

**Test plan source of truth:** [`test-plans/tendril-test-plan.md`](../../test-plans/tendril-test-plan.md)

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
  ✓ test-plans/tendril-test-plan.md

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

Tests run **inside a guest VM** — never on the host. The invoking agent on the host controls the guest UI through `cua-agent-app` — no nested LLM or API keys in that CLI. Pick the connect skill that matches the OS under test:

| OS under test | Hypervisor | Connect skill | computer-server |
|---|---|---|---|
| macOS | Lume (`tendril-mac`) | `/connect-cua-lume-macos-vm` | port 8443 |
| macOS | UTM | `/connect-cua-utm-macos-vm` | port 8000, `CUA_HTTP_URL` |
| Ubuntu | UTM | `/connect-cua-utm-ubuntu-vm` | port 8000, `CUA_HTTP_URL` |
| Windows | UTM | `/connect-cua-utm-windows-vm` | port 8000, `CUA_HTTP_URL` |

### 1. Configure host environment

```bash
cp .env.example .env   # if not already present
# Lume path: fill in LUME_VM_NAME, LUME_VM_IP, LUME_VM_SSH_USER, LUME_VM_SSH_PASSWORD
# UTM path:  set CUA_HTTP_URL=http://<guest-ip>:8000 (and optionally CUA_VM_NAME)
```

Optional: pin a production release for install (`TENDRIL_VERSION=1.0.51` → `releases/tag/v1.0.51`).

### 2. Install cua-agent-app dependencies

```bash
cd cua-agent-app && uv sync
```

### 3. Start VM and verify CUA connectivity

```bash
set -a && source .env && set +a
lume run "${LUME_VM_NAME:-tendril-mac}"   # Lume; for UTM start the VM in UTM / via utmctl
cd cua-agent-app
uv run main.py screenshot --out screenshots/$(date +%Y-%m-%d_%H%M)_scratch/00-ready.png
```

If screenshots fail (connection refused, black/empty image, 2× click offsets), run the connect skill for your target from the table above — each one covers provisioning `computer-server` plus its OS-specific gotchas (TCC/Screen Recording on macOS, Wayland→Xorg on Ubuntu, scaling on Windows).

### 4. Install Tendril in the guest (production build)

- **macOS guests:** run `/install-tendril-in-mac-vm`. It downloads the **`IvyTendril-<version>-osx-arm64.pkg`** from GitHub Releases (production build) and installs via the macOS GUI, with a Terminal script fallback. **Pass checkpoint:** native Ivy Tendril app window visible in a screenshot.
- **Ubuntu/Windows guests:** Tendril is **not a desktop app** there — it is the `ivy.tendril` dotnet tool. Install via `dotnet tool install -g ivy.tendril`, launch `tendril` with `DOTNET_ROOT=$HOME/.dotnet` and `~/.local/bin` on PATH (it shells out to the coding-agent CLI), and drive the web UI at `https://localhost:5010` in the guest browser. **Pass checkpoint:** Tendril dashboard visible in the guest browser.

---

## Execute the test plan (in the VM via cua-agent-app)

There is nothing to launch from this repo except the CUA CLI. All Tendril UI steps happen **in the VM**; the host agent drives them with screenshot → interpret → act.

### CUA agent contract (all test skills)

Whichever agent runs the test plan must:

1. Control the VM only through `cua-agent-app` CLI commands (from `cua-agent-app/`).
2. **Screenshot after every action** and verify the UI changed before continuing.
3. Save evidence screenshots into the run directory's `screenshots/` folder using the naming convention in "Test-run output" below. Working/scratch shots may go in a timestamped subdirectory under `cua-agent-app/screenshots/`, but everything cited as evidence must end up in `test-runs/<run-dir>/screenshots/`.
4. Use logical display coordinates (from `lume ls` on Lume, or the guest's logical resolution on UTM), not raw PNG or `dimensions` pixel sizes — see [install-tendril-in-mac-vm](../install-tendril-in-mac-vm/SKILL.md) and the UTM connect skills for the coordinate contract.
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
0. VM + Tendril (host) — pick the connect skill for the OS under test
   /connect-cua-lume-macos-vm | /connect-cua-utm-macos-vm |
   /connect-cua-utm-ubuntu-vm | /connect-cua-utm-windows-vm
                                 → computer-server reachable, screenshot OK
   /install-tendril-in-mac-vm    → production .pkg in macOS VM (skip if installed;
                                   Ubuntu/Windows: dotnet tool, see prerequisites §4)

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

Record the production version under test in `test-plans/tendril-test-plan.md` header fields (`Production version(s)`, `Date`, `Tester`) **and** in the run's `execution-log.md` header (below).

---

## Test-run output (required)

Every test session produces exactly one run directory under [`test-runs/`](../../test-runs/). This is the formal record of the run — if it isn't in `test-runs/`, the run didn't happen.

### Run directory naming

```
test-runs/<timestamp>__<test-plan-name>__<os-under-test>__<tendril-version>__<agent-and-model>/
```

Fields are separated by `__` (double underscore); within a field use `-`, never `__`. The `timestamp` field keeps a single `_` between its date and time — that never collides with the `__` separator, so splitting the name on `__` always yields exactly five fields. `agent-and-model` is one combined human-readable label (its internal hyphens are not parsed into sub-fields). All lowercase except section IDs.

| Field | Format | Examples |
|---|---|---|
| timestamp | `YYYY-MM-DD_HHMM`, run start, local time (`date +%Y-%m-%d_%H%M`) | `2026-06-10_1915` |
| test-plan-name | scope of the run: section ID(s) or test skill name, or `full-plan` | `section-2B`, `test-plan-creation`, `full-plan` |
| os-under-test | guest OS + version + hypervisor | `macos-15-lume`, `ubuntu-22.04-utm`, `windows-11-utm` |
| tendril-version | `tendril-<version>` | `tendril-1.0.51` |
| agent-and-model | executing agent, then the model driving it | `claude-code-claude-fable-5`, `cursor-gpt-5` |

Example:

```
test-runs/2026-06-10_1915__section-2B__ubuntu-22.04-utm__tendril-1.0.51__claude-code-claude-fable-5/
```

### Run directory contents

```
<run-dir>/
├── execution-log.md     # required — the run record
└── screenshots/         # required — all evidence screenshots from the run
```

Create the directory skeleton at run start, before the first test case. Anchor `RUN_DIR` to the repo root with an absolute path so the same variable resolves identically whether you are in the repo root or in `cua-agent-app/`:

```bash
RUN_DIR="$(git rev-parse --show-toplevel)/test-runs/$(date +%Y-%m-%d_%H%M)__<plan>__<os>__tendril-<version>__<agent>-<model>"
mkdir -p "$RUN_DIR/screenshots"
```

### execution-log.md

Start from the template at [`templates/execution-log.md`](templates/execution-log.md). It must contain:

1. **Header table** — section/scope, production version, date, tester, agent under test, host/guest, Tendril launch method, test repo(s), and an overall result tally (`N PASS, N FAIL, N BLOCKED, N SKIPPED`).
2. **Environment notes** — anything a future run needs to reproduce this one (launch env vars, onboarding state, workarounds applied).
3. **Per-case results** — one `### <section-id> — <name> — ✅ PASS / ❌ FAIL / ⏭ SKIPPED / 🚫 BLOCKED` block per test case, with steps, observed behavior, assessment against the plan's expected result, and an **Evidence:** line citing screenshot filenames.
4. **Defect blocks** — every FAIL gets a `> **DEFECT — <summary>**` blockquote with repro steps, ground-truth checks (config files, CLI output), and suspected cause.

### Screenshot naming

All evidence screenshots go in `<run-dir>/screenshots/`, named with the same `__` field separator as the run directory:

```
<timestamp>__<section>__<short-description>.png
```

- **timestamp** — `YYYY-MM-DD_HHMMSS` at capture time (`date +%Y-%m-%d_%H%M%S`); makes the directory listing chronological. As with the run directory, its single internal `_` never collides with the `__` separator.
- **section** — the test-plan section/case ID the shot evidences (`2B.1`, `setup`, `onboarding`).
- **short-description** — 2–5 hyphenated words (`add-project-dialog`, `projects-after-refresh`).

Example: `2026-06-10_191530__2B.1__add-project-dialog.png`. Capture directly into the run directory — `$RUN_DIR` is absolute (above), so this works unchanged from `cua-agent-app/`:

```bash
uv run main.py screenshot --out "$RUN_DIR/screenshots/$(date +%Y-%m-%d_%H%M%S)__2B.1__add-project-dialog.png"
```

Scratch shots (coordinate probing, retries) may go in `cua-agent-app/screenshots/<timestamped-subdir>/`; copy any that become evidence into the run directory with a conforming name before writing the log.

---

## Gotchas

- **No binary here.** Tendril is installed in the guest from GitHub Releases (`.pkg` on macOS) or as the `ivy.tendril` dotnet tool (Ubuntu/Windows). This repo contains only test runbooks and the CUA CLI.
- **VM-first.** Do not run Tendril UI tests on the host — use a guest VM and `cua-agent-app`.
- **Linux/Windows Tendril is a web app.** No desktop window: `tendril` serves `https://localhost:5010` and the UI is the guest browser. Launch it with `DOTNET_ROOT=$HOME/.dotnet` and `~/.local/bin` on PATH or agent verification in onboarding fails.
- **Run record is mandatory.** Create the `test-runs/<run-dir>/` skeleton before the first test case and write screenshots into it as you go — reconstructing evidence afterwards loses shots.
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
