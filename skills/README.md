# Tendril Test Skills — Index

Skills for executing the `development` branch test plan. Each skill is a focused runbook for an agent or human tester.

---

## Execution order

```
1. Set up repos (parallel)
2. test-onboarding-and-settings   ← Sections 1, 2, 10
3. test-plan-creation             ← Section 3
4. test-plan-execution            ← Sections 4, 5, 7  ★ primary focus
5. test-review-and-pr             ← Sections 6, 8
6. test-recommendations-and-misc  ← Sections 9, 11, 12
```

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

## Exit criteria (from test plan)

- [ ] All ★-marked tests pass on **Claude Code / balanced / repo-node**
- [ ] No P1 or P2 defects open
- [ ] Cost tracking accurate for at least one complete end-to-end run
- [ ] At least one plan executed with Codex or OpenCode (Section 5D)
- [ ] All Section 10 regression checks pass (#879, #880, #882–#885, #887)
