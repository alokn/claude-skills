# Agent instructions

<!-- Portable rules for any agent working in this repo, in any harness. This is the entry point
and it stays short: what every task needs is here; each area's conventions and traps are in
docs/agents/, reached from the reading map. CLAUDE.md holds only what is specific to Claude
Code and imports this file. CONFIGURE every <…> and delete this comment. -->

<One paragraph: what this repository is, its architecture in a sentence, the words it uses.>

## One ticket, start to finish

```bash
./init.sh --skip-verify        # FIRST, once per worktree. Never install the toolchain or dependencies
                               # by hand: init.sh pins the toolchain, writes the env file, starts the
                               # services and stamps the worktree
git checkout -b <branch> origin/<default>
<dev command>                  # this worktree's own instance; the banner has the URL
                               # TDD: a failing test first, then the code that passes it
scripts/verify.sh fast         # the inner loop, ~<n> s
scripts/verify.sh full         # THE gate: exit 0 is the definition of done
git push -u origin <branch>    # explicit paths only when committing: never `git add -A`
scripts/pr.sh --title "…" --body-file <file>   # checks the body, opens the PR with its Verification block
```

## Commands

Every script is in `<manifest>`. The ones whose effect the name doesn't tell you:

```bash
scripts/verify.sh fast         # lint, types, quick tests, the scans; what the Stop hook runs
scripts/verify.sh full         # everything, plus coverage and the ratchet; records a pass
scripts/verify.sh full --check # what CI runs: never writes verify-baseline.json
scripts/verify.sh full --allow-drop <figure> --reason "<category>: <why>"
                               # the one way to lower a figure; lands in the PR diff
<other commands with non-obvious effects: reseed, down, a paid eval, a smoke that spends a credential>
```

## The gate

`scripts/verify.sh full` exiting 0 is what "done" means. It needs <services, or "nothing but the
toolchain"> and no network or paid credential. It prints one line per check and writes a report
per check into `.verify/`. A red check is read from `.verify/<name>.log`.

**Never lower a baseline, a budget, a coverage floor, or `.skip` a test to get past the gate.**
Report the number and the reason instead. The sanctioned exceptions go through
`--allow-drop`, for two reasons only: consolidating true duplicate tests, and deleting a feature
together with the only tests that exercised it, when the deletion is what the PR is for. Each
needs a table in the PR mapping every removed test to what still covers it.

The ratchet (`verify-baseline.json`) holds: <tests.total, coverage.lines, markers, …>. Floors
may only rise; ceilings may only fall; a passing full run rewrites improvements, which you
commit with the work. CI runs `--check` and never writes it.

**Flaky tests are failing tests.** No test is ever retried (the `no-retries` scan fails one). A
test that passes on a second run is fixed, or quarantined behind a tag with an issue saying
what fails, how often, and the fix. Never `.skip`.

## Layout

```
<dir>      <what it is, one line>
```

<Dependency rules and what enforces them, when the repo has any.>

## Conventions that look like bugs but aren't

<Each: one bold sentence of what, one of why, where it lives. Delete the section if empty.>

## Reading map

| Before touching… | Read first |
|---|---|
| A test, the gate, `verify-baseline.json`, or a `scripts/verify.sh` failure its message doesn't explain | `docs/agents/testing.md` |
| <area> | `docs/agents/<area>.md` |
| Why it's built this way | <DESIGN.md / docs/adr/> |

## Completion evidence

Don't claim a change is done, fixed, or passing without having just run the command that proves
it and read its output. Quote the output (or the relevant lines) in your report.
`scripts/verify.sh full` exiting 0 is what "done" means for anything that touches code, tests
or config.

A PR body is a file that fills `.github/pull_request_template.md`, passed with `--body-file`
(never an inline `--body`): every section, "None" where it applies. Each ruling you made goes
under "Decisions and trade-offs" as one line (what, the alternatives, why, the cost if wrong),
declined review findings too. `scripts/pr-body.py` checks it before the PR opens and in CI.

## Escalation

For a choice this file, `docs/agents/` and the code don't already settle: take the conservative
path (the one least likely to need undoing), keep going, and file an issue describing the
choice and why. Don't stop to ask; don't guess silently either. Never lower a gate to route
around a real failure: that's a bug report, not a decision to make unilaterally.
