---
# Claude Code loads this file (through a .claude/rules/ symlink) whenever a session reads a
# file matching these paths. Other agents reach it from AGENTS.md's reading map.
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/test/**"
  - "**/tests/**"
  - "verify-baseline.json"
  - "scripts/verify.sh"
  - "scripts/ratchet.py"
  - "scripts/tree-fingerprint.sh"
  - "scripts/figures.sh"
  - "scripts/scan-gate.sh"
---

# Testing and the gate

Read before adding, removing or changing a test, a test config, the ratchet baseline, or when
`scripts/verify.sh` fails in a way the message doesn't explain.

## The gate

**`scripts/verify.sh full` exiting 0 is what "done" means.** It needs <services or nothing>,
no network and no paid credential, and preflights what it needs before anything runs: what it
can't reach is one line rather than a hundred assertion failures. `fast` is the inner loop
(<what it runs>, about <n> s); the Stop hook runs it. Each check's output is in
`.verify/<name>.log`, its result in `.verify/<name>.json`, the run's in `.verify/summary.json`.

## The ratchet

`scripts/ratchet.py` compares `.verify/figures.json` (what this run measured) with
`verify-baseline.json` (the best so far). Floors (<tests.total, coverage.lines>) may only rise;
ceilings (<markers, …>) may only fall. A passing full run writes an improvement into the
baseline, but only while the tree still has the fingerprint the run started with
(`scripts/tree-fingerprint.sh`, left in `.verify/tree-fingerprint`): an edit made during the run
was never measured. Commit the rewrite with the work that caused it. CI runs `--check`, which
never writes and fails a regression.

**Never lower a figure by hand.** The one way down is
`scripts/verify.sh full --allow-drop <figure> --reason "<category>: <why>"`, which runs the gate
and then appends to `allowedDrops` so the drop is in the PR diff. A test count
may drop for `duplicate-tests:` or `feature-removed:` only, and the PR lists each removed test
and what still covers it. A test that fails, or one you'd rather not fix, is neither.

## What the scans refuse

- `no-markers`: `TODO`, `FIXME`, `.skip`, `.only`, <language-specific markers>. Deferred work goes
  in an issue, and a comment names it (`#N`).
- `no-retries`: a `retry`/`retries` setting in a runner config, on a test, or on a command. A
  test that passes on a second run is a failing test: find the race, the shared resource or
  the timing assumption, and fix it, or quarantine it behind a tag with an issue.
- `max-lines`: no source or test file over <400> lines.

## Writing tests here

- Test names state behaviour.
- Fakes at the ports, never mocks of this repo's own modules.
- No sleeps: poll a condition, or use a fake clock.
- <Test data from builders / fixtures, where the repo has them.>
- <Per-worktree database / port derivation, when there are services.>

## Running one file

```bash
<the one-file command, with the env the gate applies>
```
