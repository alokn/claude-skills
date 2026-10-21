# Report template

Write `$WORK/report.md` (and tell the user the absolute path). Every claim of "works" quotes
the command and the lines of its output that prove it. Nothing is reported as done that was
not run.

```markdown
# Verification loop: <repo name> (<absolute path>)

Run on <date> by the create-verification-loop skill. Branch: <branch>. Nothing was committed.

## What the repo is

<Two or three sentences from the interview: ecosystem, package manager, test runner, services,
CI, what agent docs existed.>

## Gap table (before → after)

| # | Principle | Before | After | Notes |
|---|---|---|---|---|
| P1 | One gate command | absent | `scripts/verify.sh fast|full`; 7 checks | |
| P2 | init.sh | absent | `./init.sh`; stamp in .git | |
| P3 | Ratchet | absent | 3 figures; baseline committed? no (uncommitted) | |
| P4 | Determinism scans | 2 TODOs | no-markers, no-retries, max-lines 400 | TODOs filed as #… |
| P5 | Fingerprint | absent | `scripts/tree-fingerprint.sh` | |
| P6 | Hooks | absent | Stop, init guard, PR guard | |
| P7 | Agent docs | AGENTS.md (40 lines) | extended; 2 area docs; .claude/rules | |
| P8 | PR path | absent | pr.sh, PR template, pr-body.py + hook + `pr body` job | unproven: no remote |
| P9 | CI | ci.yml (tests only) | verify --check + gate job | unproven: not pushed |
| P10 | verify skill | absent | skipped: library, no surface | |
| P11 | Completion evidence / escalation | absent | in AGENTS.md | |
| P12 | Flaky policy | absent | in AGENTS.md; scan in gate | |

## Proof

### The gate on the current tree
```
<the summary block of `scripts/verify.sh full`, with exit 0>
```

### Fresh worktree → init.sh → green
```
<the commands and the last lines>
```

### Hooks, by payload
```
<each payload and its exit code; the Stop hook red→block→green cycle>
```

### What was red before, and what was done about it
<e.g. "typecheck had 4 errors on the current tree; 2 were missing JSDoc params (fixed in
src/notes.js), 2 were a real nullable return (fixed by returning the created note). No rule was
weakened.">

## Not done, and why

- <item>: <reason>; <where it is recorded (an issue, a TODO in the report, never in a file the
  no-markers scan reads)>

## Next steps for a person

1. Review and commit (explicit paths): <list>.
2. Push and open the first PR with `scripts/pr.sh` to prove P8 and P9.
3. <...>
```
