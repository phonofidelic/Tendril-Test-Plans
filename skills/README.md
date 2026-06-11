# Tendril Test Skills — Index

Skills for executing the [production build test plan](../tendril-test-plan.md) inside the `tendril-mac` Lume VM via [`cua-agent-app`](../cua-agent-app/). Each skill is a focused runbook for an agent or human tester.

All skills follow the [agentskills.io specification](https://agentskills.io/specification): one directory per skill, each containing a `SKILL.md` with `name` and `description` frontmatter. Validate them with `bash run-tendril-test-plans/scripts/smoke.sh` (from the repo root: `bash skills/run-tendril-test-plans/scripts/smoke.sh`).

---

## Execution order

```
0. VM + Tendril (host)
   connect-cua-lume-macos-vm → computer-server on :8443
   install-tendril-in-mac-vm  → production .pkg in VM

1. Set up repos (host — parallel)
2. test-onboarding-and-settings   ← Sections 1, 2, 10
3. test-plan-creation             ← Section 3
4. test-plan-execution            ← Sections 4, 5, 7  ★ primary focus
5. test-review-and-pr             ← Sections 6, 8
6. test-recommendations-and-misc  ← Sections 9, 11, 12
```

Test skills 2–6 drive the Tendril GUI in the VM with `cua-agent-app` (see `run-tendril-test-plans`).

---

## Repo setup skills

| Skill | Repo alias | Stack | Primary use |
|---|---|---|---|
| `setup-repo-node` | repo-node | Express / Node.js + TypeScript | Core happy-path; verification gates |
| `setup-repo-python` | repo-python | FastAPI / Python | Project inference; per-project stats |
| `setup-repo-go` | repo-go | Go HTTP server | Cross-agent parity (Section 5D) |
| `setup-repo-react` | repo-react | Vite + React + TypeScript | Multi-repo plan testing |
| `setup-repo-mono` | repo-mono | npm workspaces (two packages) | Multi-repo PR testing (6B.5) |
| `setup-repo-dotnet` | repo-dotnet | ASP.NET Core Web API | Tendril dogfooding |

**Minimum required for exit criteria:** repo-node + repo-go.

---

## Test scenario skills

| Skill | Sections | ★ Priority |
|---|---|---|
| `test-onboarding-and-settings` | 1, 2A, 2B, 2C, 2D, 10 | 2A, 2B, 2D ★ |
| `test-plan-creation` | 3A, 3B | 3A ★ |
| `test-plan-execution` | 4, 5A–5D, 7 | 5 ★★, 7 ★ |
| `test-review-and-pr` | 6A, 6B, 8 | 6B ★ |
| `test-recommendations-and-misc` | 9, 11, 12 | — |

---

## Infrastructure skills

Run these before the test plan on a fresh VM.

| Skill | Purpose |
|---|---|
| `install-tendril-in-mac-vm` | Install Tendril on the `tendril-mac` Lume VM (GUI `.pkg` first, Terminal script fallback). |
| `connect-cua-lume-macos-vm` | Connect a CUA Sandbox to the Lume VM and provision the in-VM `computer-server` on port 8443. |
| `connect-cua-utm-windows-vm` | Connect a CUA Sandbox to a UTM Windows VM via `CUA_HTTP_URL` and provision the in-guest `computer-server` on port 8000. |
| `connect-cua-utm-ubuntu-vm` | Connect a CUA Sandbox to a UTM Ubuntu VM via `CUA_HTTP_URL` and provision the in-guest `computer-server` on port 8000 (Xorg session required). |
| `connect-cua-utm-macos-vm` | Connect a CUA Sandbox to a UTM macOS VM via `CUA_HTTP_URL` and provision the in-guest `computer-server` on port 8000 (Screen Recording grant required). |

---

## Orchestration skill

| Skill | Purpose |
|---|---|
| `run-tendril-test-plans` | Validate that every skill is present and spec-compliant (`scripts/smoke.sh`), then drive the execution order above. |

---

## Exit criteria (from test plan)

- [ ] All ★-marked tests pass on **Claude Code / balanced / repo-node**
- [ ] No P1 or P2 defects open
- [ ] Cost tracking accurate for at least one complete end-to-end run
- [ ] At least one plan executed with Codex or OpenCode (Section 5D)
- [ ] All Section 10 regression checks pass (#879, #880, #882–#885, #887)
