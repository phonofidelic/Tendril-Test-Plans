# test-runs

Formal records of Tendril test-plan executions. One directory per run:

```
test-runs/<timestamp>__<test-plan-name>__<os-under-test>__<tendril-version>__<agent-and-model>/
├── execution-log.md     # run record: header table, environment notes, per-case results, defects
└── screenshots/         # all evidence screenshots
    └── <YYYY-MM-DD_HHMMSS>__<section>__<short-description>.png
```

Fields are separated by `__` (double underscore); within a field use `-` only.
The `timestamp` field keeps a single `_` between date and time, which never
collides with the `__` separator.

Example:

```
test-runs/2026-06-10_1915__section-2B__ubuntu-22.04-utm__tendril-1.0.51__claude-code-claude-fable-5/
```

Naming rules, required `execution-log.md` contents, and the log template live in
[`skills/run-tendril-test-plans`](../skills/run-tendril-test-plans/SKILL.md)
("Test-run output" section) and its
[`templates/execution-log.md`](../skills/run-tendril-test-plans/templates/execution-log.md).

Artifacts predating this convention are kept as-is for history and are exempt
from the rules above: the loose `tendril-test-run-*.md` files at this level, and
the earlier run directory `2026-06-10_1915_ubuntu-22.04-utm_tendril-1.0.51_claude-fable-5_section-2B/`
(single-underscore separators, fields in an older order). New runs must follow
the naming above.
