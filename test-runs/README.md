# test-runs

Formal records of Tendril test-plan executions. One directory per run:

```
test-runs/<timestamp>_<test-plan-name>_<os-under-test>_<tendril-version>_<agent-and-model>/
├── execution-log.md     # run record: header table, environment notes, per-case results, defects
└── screenshots/         # all evidence screenshots
    └── <YYYY-MM-DD_HHMMSS>_<section>_<short-description>.png
```

Example:

```
test-runs/2026-06-10_1915_section-2B_ubuntu-22.04-utm_tendril-1.0.51_claude-code-claude-fable-5/
```

Naming rules, required `execution-log.md` contents, and the log template live in
[`skills/run-tendril-test-plans`](../skills/run-tendril-test-plans/SKILL.md)
("Test-run output" section) and its
[`templates/execution-log.md`](../skills/run-tendril-test-plans/templates/execution-log.md).

Loose `tendril-test-run-*.md` files at this level predate the convention and are
kept for history.
