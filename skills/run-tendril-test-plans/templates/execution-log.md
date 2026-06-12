# Tendril Test Run — <scope, e.g. Section 2B (Projects)>

| Field | Value |
|---|---|
| **Section / scope** | <section ID(s) or test skill name, or full plan> |
| **Production version** | Ivy Tendril v<X.Y.Z> (<install form: .pkg / `ivy.tendril` dotnet tool>) |
| **Date** | <YYYY-MM-DD> |
| **Tester** | <human> (driven by <model> via cua-agent-app) |
| **Agent Under Test** | <coding agent Tendril shells out to, e.g. Claude Code (CLI `claude` X.Y.Z)> |
| **Host/Guest** | macOS host → <hypervisor> **<guest OS + version>** (<vm-name>, <guest-ip>) |
| **Tendril launch** | <e.g. native app from /Applications, or `tendril` dotnet tool → `https://localhost:5010` in guest Firefox> |
| **Test repo(s)** | <e.g. repo-node (`/home/ubuntu/repo-node`, Express/TS)> |
| **Result** | <N> PASS, <N> FAIL, <N> SKIPPED, <N> BLOCKED |

---

## Environment notes

- <anything a future run needs to reproduce this one: launch env vars,
  onboarding state, TENDRIL_HOME isolation, workarounds applied, known
  defects carried in from earlier runs>

---

## Results

### <section-id> — <case name> — ✅ PASS

**Steps:** <UI path taken, e.g. Settings → Configuration → Projects → Add Project>

**Observed:** <what actually happened, including ground-truth checks
(config files, CLI output) where relevant>

**Assessment:** <observed vs. the plan's expected result; why this is a PASS/FAIL>

Evidence: `<timestamp>_<section>_<desc>.png`, `<timestamp>_<section>_<desc>.png`

### <section-id> — <case name> — ❌ FAIL

**Steps:** …

**Observed:** …

**Assessment:** …

> **DEFECT — <one-line summary>.** <Detailed description: what completes,
> what state is wrong, ground truth (config contents, CLI output). Repro:
> step → step → step. Suspected cause if evident.>

Evidence: `…png`

---

## Summary

| Case | Result |
|---|---|
| <section-id> <name> | ✅ PASS |
| <section-id> <name> | ❌ FAIL (DEFECT: <summary>) |

<closing notes: overall assessment, follow-ups, sections blocked for next run>
