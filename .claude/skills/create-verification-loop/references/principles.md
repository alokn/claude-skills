# The principles: what, why, how the reference implementations did it, how to adapt

Read this before interviewing. Each principle says what it is, why it exists (the failure it
closes), what it looked like in the reference implementations (two production TypeScript
monorepos that run coding agents unattended, which this skill distils), and how to adapt it. The gap table in
step 2 of the skill has one row per principle below, P1 to P12.

Two norms run through all of them:

- **A rule a machine can check is a machine rule.** If you find yourself writing "remember
  to…" for an agent, the rule belongs in a config or a gate, with the doc saying what enforces it.
- **The hook is the early warning; the gate is the guarantee.** Every Claude Code hook here is
  backed by something that holds under any harness (a test in the gate, CI, a wrapper script).
  A hook that nothing backs is advice.

## P1. One gate command whose exit 0 is the definition of done

**What.** One command (`pnpm verify`, `scripts/verify.sh full`, `make verify`) runs every check
the repo already has, prints one aligned line per check (✓/✗ name, detail, seconds), writes a
machine-readable report per check into `.verify/`, and exits 0 only when everything passed.
Two tiers: `fast` (lint, typecheck, quick tests, the scans; under about 60 s warm) for the
inner loop and the Stop hook, and `full` (plus coverage, build, e2e, the ratchet) for "done".

**Why.** "Run the tests" leaves lint, types and dead code to memory; a chained
`lint && test` stops at the first failure and says nothing about the rest; without reports no
tool can ratchet anything. One name is what an agent instruction, a hook, CI and a person all
run, so there is one definition of done.

**In the reference implementations.** A `scripts/verify.mjs` that runs the static checks in
parallel (lint, typecheck, boundaries, dead code), then unit tests with coverage, the build,
the browser suite and the ratchet, with `--fast`, `--check` and `--scoped` modes. The second one
runs its gates as a dependency graph: every failure reported, each gate's output held and
printed in one block, `.verify/summary.json`. Both preflight services and tools first and fail
in one actionable line ("postgres unreachable at localhost:5433 — run `pnpm run up`") rather
than a hundred assertion failures.

**Adapt.** Compose from what exists; add nothing new in the first pass except the scans in P4.
Keep the names stable. If the repo's own language has a natural runner (a `verify` script in
`package.json`, a `Makefile`, a `Rakefile`), `verify.sh` can delegate to it, but the one-line-
per-check summary and the `.verify/` reports are not optional. A red gate on the current tree is
reported, with the number and the cause, never routed around (see P3 norms).

## P2. One-step idempotent setup: clean clone to green gate

**What.** `./init.sh [--skip-verify] [--fast]`: preflight that collects every missing hard
requirement before failing, the pinned toolchain (mise, `.nvmrc`, `.tool-versions`,
`.python-version`), the env file from its example, dependencies from the lockfile exactly,
services up with a bounded readiness wait, migrate and seed, then a stamp, then the gate. Safe
to run twice. Unattended-safe: nothing waits on a prompt; what needs a person is one line
naming the command.

**Why.** An agent in a fresh worktree runs the package manager by hand, skipping the version
pin, the browsers, the env file and the seed, and then spends an hour on failures that setup
would have prevented. One script that ends in the gate is also the proof that a clean clone
works.

**In the reference implementations.** One `init.sh` of 240 lines (preflight, mise, browsers
with system deps when root, Postgres and MinIO through a `scripts/lib/stack.sh` shared with the
dev command, migrate and seed, the stamp, the gate, a banner); the other of 16 (mise, install,
git hooks, env file, migrate, the fast gate). The stamp is a hash of the toolchain pins in the
git dir, and the init guard (P6) refuses a hand-run install until it exists.

**Adapt.** Keep the shape even when the body is three lines. The stamp lives in `.git/`, never
in the tree. A repo with no services skips section 5 but keeps the stamp.

## P3. The ratchet: every figure may only improve

**What.** `verify-baseline.json` commits floors (passing tests, coverage, type coverage: may only
rise) and ceilings (TODO markers, lint suppressions, type assertions, oversized files,
duplicated lines: may only fall). The full gate measures them from the reports, fails on a
regression, writes an improvement into the baseline (only while the tree still has the
fingerprint it measured, P5), and CI runs `--check`, which never writes. The one way down is
`--allow-drop NAME --reason "category: why"`, which appends to an `allowedDrops` trail that a
reviewer reads in the PR diff. A test count may drop for two reasons only: duplicate tests
consolidated, or a feature removed together with its only tests because an issue or a person
asked for the removal.

**Why.** A green suite proves the tests that ran passed; it says nothing about the tests that
quietly stopped existing, the coverage that fell, or the suppression that was added to get past
a rule. Per-project counts stop 65 deleted tests hiding behind 65 new ones elsewhere.

**In the reference implementations.** A `scripts/ratchet.mjs` holding test counts per project
and in total, the e2e count, coverage per project (a high-water mark and an absolute floor),
and eleven budgets per package (type assertions, lint suppressions, env reads outside the
composition root, long functions, large files, duplicated lines, ports without a contract
suite). The larger one adds a store branch (`ratchet/figures`) so the main branch records
improvements without touching a PR's tree, mutation-score floors, and an audit that every
lowered figure has its `allowedDrops` entry.

**Norms (quote them in AGENTS.md).** Never lower a baseline, a budget, a coverage floor, or
`.skip` a test to get past the gate; report the number and the reason instead. Never raise a
budget by hand. Never widen a tolerance. A test that passes on a second run is a failing test.

**Adapt.** Start with what is measurable today: `tests.total` (and per project when the runner
reports it), `coverage.lines` when a coverage tool exists, `markers` and `suppressions` as
ceilings from the scans. Add figures as the repo grows measurement.

## P4. Deterministic verification

**What.** The gate's answer depends on the tree and nothing else. Concretely:
- **No retries anywhere**: no `retry`/`retries` in a runner config, on a test, or on a command
  (a scan fails them). A flaky test is fixed or quarantined behind a tag with an issue; never
  `.skip`, never retried.
- **No markers**: no `TODO`, `FIXME`, `.skip`, `.only`, `@pytest.mark.skip`, `#[ignore]`,
  `t.Skip` in source or tests; deferred work goes in an issue, and a comment names it.
- **No sleeps in tests**: poll a condition or use a fake clock.
- **Fakes, not mocks** of the repo's own modules; test doubles at the ports.
- **File size limit** (400 lines in both repos) as a stand-in for single responsibility.
- **Pinned runtime major**: coverage numbers are the runtime's (V8 counts branches differently
  per Node major), so the gate runs on the pinned major or refuses.
- **No network and no paid credential** inside the gate; anything that spends one is a separate
  command, named, never part of `verify`. The same for **date-dependent checks** (an EOL warning,
  a "latest version" probe, an audit database): the gate's answer on a given tree must be the same
  next month, so those run on a schedule, outside it.
- **Machine-local inputs in the fingerprint** (env file hash, installed-deps marker, runtime
  version), so a change to them owes a verify too.
- **Ports and databases derived per worktree**, so two checkouts verify at once without colliding.

**Why.** A retry hides a race until it ships; a skipped test is a deleted test that still looks
present; a sleep is a timeout waiting to happen under load; a gate that needs the network fails
for reasons that are not the code's.

**In the reference implementations.** One-screen scan scripts: `no-retries`, `no-markers`,
`max-lines`, `no-vendor-words` (vendor names banned from the domain layer), `retired-terms`
(the words of removed mechanisms never come back), `coverage-ignores` (refuses every
coverage-ignore hint but one named form). Plus: the gate re-runs itself under the pinned Node
major, a patch that sorts vitest's coverage merge so totals are identical run to run, a
`coverage:stability --runs N` command, per-worker test databases, and a `choosePort` that
swaps a derived port another worktree holds.

**Adapt.** The scans are three lines each with `scripts/scan-gate.sh`; put them in the fast tier
on day one. Clear existing hits by fixing or filing issues; where a hit is deliberate and
numerous, make it a ceiling in the ratchet instead of a hard fail, and ratchet it down.

## P5. The tree fingerprint and the pass record

**What.** One SHA-256 over the blob list of everything git would commit (tracked and untracked,
.gitignore respected) minus what the gate writes or never reads (the baseline, `.verify/`,
Markdown), plus the machine inputs. A green full gate records it as `last-pass` in the git dir,
with the summary lines and the HEAD; a green fast run records `last-fast-pass`, kept apart so it
can never satisfy a check that asks for a full one. The ratchet writes only while the tree still
has the fingerprint the run started with. Contents, not HEAD: committing a tree that just passed
must not look new. Fails closed: no git, nothing to hash, an unmeasurable input, all mean "no
fingerprint", which every reader treats as "changed".

**Why.** It is what lets the Stop hook skip a tree that already passed, lets the PR check ask
"did the full gate pass *this* tree", and ties every report to the tree it measured.

**In the reference implementations.** A `scripts/tree-fingerprint.sh` that is the one
definition, sourced by the hooks and run by the gate and the ratchet; `FINGERPRINT_PATHS` is an
exclusion list, each exclusion commented, because an include list drifted. The other repo keys
its push gate's marker on a git tree id plus the untracked paths.

**Adapt.** Use the template as is; edit the exclusions and `machine_inputs` only.

## P6. Claude Code hooks: the loop enforced, never a trap

**What.** Committed `.claude/settings.json` wiring:
- **Stop** → the fast gate; exit 2 with the tail of the log blocks the turn on red. Five gates
  before it runs: the session changed nothing the gate reads (against the session's own
  baseline taken at SessionStart, not "is the tree dirty"); this tree already passed; a
  service is down → say `DID NOT RUN`, exit 0; it already failed twice unattended → say so, exit
  0, and `UserPromptSubmit` resets the budget; the worktree's lock is held → exit 0. Messages
  keep `PASSED`, `FAILED` and `DID NOT RUN` apart, and a fast pass never says the tree passed.
- **PreToolUse on Bash: the init guard** refuses an install until `init.sh` stamped the worktree.
- **PreToolUse on Bash: the PR guard** refuses `gh pr create` unless the tree is clean, pushed,
  and `last-pass` equals its fingerprint.
- **PreToolUse on Bash: the PR body hook** refuses `gh pr create` or a body-setting `gh pr edit`
  unless the body comes from `--body-file` and passes `scripts/pr-body.py` (P8).
- **Domain guards** where the repo has an irreversible path: a hand-written migration, a push to
  a protected branch, an edit under a locked acceptance-test catalogue (a `.locked` file turns
  the guard on), a push whose branch changes source without a fresh coverage marker.

**Design rules (from the reference `docs/HOOKS.md`).** Read the command the way the shell runs
it: quoted strings and heredoc bodies stripped, so a mention is not a command. Judge the
checkout the payload's `cwd` is in, so a subagent's worktree is judged by its own state. Block
only on what the model can fix; anything else is exit 0 and a message, or the session loops.
Keep stdout clean where it becomes context. Wire the narrowest matcher and a timeout. Test
every hook by piping payloads through it, the quoted mention included. Back it with the gate.
Document it in CLAUDE.md with a "what still holds without it" table.

**Why.** AGENTS.md can say "exit 0 is done"; the Stop hook is what makes a red tree cost the
agent its turn. The guards close the two habits every fresh agent has: installing by hand and
opening a PR on an unverified tree. The loop-safety gates exist because a Stop hook that blocks
on something the model cannot fix traps the session, and Claude Code stops honouring a Stop hook
after enough consecutive blocks anyway.

**Adapt.** The three template hooks fit any repo. Add a domain guard only for a path the repo
genuinely must protect, and write its test first.

## P7. Agent docs that load themselves

**What.** `AGENTS.md` is the portable entry point, short: the loop (init → branch → test first
→ gate → PR), the commands whose effect the name doesn't tell you, the gate and its norms, the
layout, conventions that look like bugs but aren't, a reading map, completion evidence, and
escalation. `CLAUDE.md` is `@AGENTS.md` plus only what is Claude Code's: the hooks (a table:
event, script, what it does, how it answers), the rules, the skills. Area docs in
`docs/agents/<area>.md` carry `paths:` frontmatter and are symlinked from `.claude/rules/`, so
Claude Code loads the doc for an area when a session first reads a file in it. Each rule in a
standards doc is one line of what, one of why, and a tag saying what enforces it (`[tsc]`,
`[lint]`, `[test]`, `[ratchet]`, `[review]`). A vocabulary file (`CONTEXT.md`) names the terms
and the words to avoid. `docs/HOOKS.md` is the human's page on the hooks. A `docs:check`
script fails on a doc that names a path, script or variable that no longer exists.

**Why.** A single long CLAUDE.md is read once and forgotten after compaction; a rule that
loads on the first file read in its area arrives when it is needed. Saying what enforces each
rule tells the reader which ones to check by hand. The reading map answers "what do I read
before touching X" without a person.

**In the reference implementations.** An AGENTS.md of about 200 lines and a CLAUDE.md of about
100, six area docs and a standards doc behind `.claude/rules/` symlinks, a `reading-list
<paths>` script, a `docs:check` script, and a PostToolUse hook that sends area docs to worktree
subagents. The other repo keeps a CONTEXT.md vocabulary and a `docs/adr/` directory.

**Adapt.** Extend an existing AGENTS.md rather than replace it; keep its voice. Start with two
area docs where the repo has two areas with different traps (often: testing-and-the-gate, and
the main runtime). The reading map is the minimum.

## P8. The PR path: a PR carries its evidence, and its body is checked

**What.** `scripts/pr.sh` runs the same check as the PR guard, then `gh pr create` with your
arguments and a Verification block appended: the gate's summary lines and the HEAD they passed
on. Commit with explicit paths, never `git add -A`, because another session's files may be in
the tree. The body itself is held by four parts, each small:

- **A template** (`.github/pull_request_template.md`): Issue; Why; What changed, ending with a
  `Security and isolation:` line and a `Deploy notes:` line; Decisions and trade-offs, one line
  per decision with the alternatives, why, and the cost if wrong, declined review findings
  included; Checks run beyond the gate, and what was not run; Affected boundaries; Review;
  Follow-ups and flakes; Ratchet drops, only when there are drops.
- **A checker** (`scripts/pr-body.py --body-file F | --pr N --base REV`): every section present
  once and non-empty, where "None" is content and an untouched template comment is not; the
  labelled lines present; plain "None" under Decisions refused when source changed ("None:
  mechanical" passes). Then it cross-checks the diff since the merge base: each kind of file
  that needs a reviewer's eye must be named in its section. The template's `CROSS_CHECKS` are
  examples: a new migration, an edit to a locked test catalogue, a public contract. A change
  to the ratchet's `allowedDrops` needs a Ratchet drops row. Bots are exempt.
- **A Claude Code hook** (`.claude/hooks/pr-body.sh`, PreToolUse on Bash): `gh pr create`, or a
  `gh pr edit` that sets the body, must take it from `--body-file <path>`; an inline `--body`,
  `--fill`, `--web`, an editor or stdin is refused. Then it runs the checker against the base.
  `scripts/pr.sh` runs the checker itself, so it holds outside Claude Code too.
- **A CI job** (`pr body`, its own workflow on `opened, edited, reopened, synchronize`): the
  checker with `--pr`, reading the body through the API so the newest edit is judged.

How an agent fills it: write the body to a file, fill every section from the work (the
rulings it made go under Decisions and trade-offs, one line each), pass `--body-file`, and fix
what the hook names.

**Why.** Before this, in the reference repo, the template was ignored by every PR: an agent
passes the body inline with `--body`, which skips the template, and nothing checked. A template
alone is a suggestion. The hook gives the agent the problems before the PR exists, not one CI
round later; a git hook can't, because a PR body is not in git. CI is the backstop for what no
hook sees: the web UI, a person without the hook, an edit after creation. The edit trigger
re-runs only this job, never the heavy gate, and it is a separate required check so a
description edit never replaces the code's `gate` status with a run that verified nothing.
"I ran the tests" in a body is a claim; the summary lines with the SHA are a record, and the
Decisions section is what a reviewer reads to argue with the change, not reconstruct it.

**In the reference implementations.** The checker is `scripts/pr-body.mjs` with its pure part
in a lib and unit tests; the hook follows `cd` like the push gate and reads the PR's own base
for an edit; the cross-checks are new migrations, the locked acceptance catalogues (read from
the lock hook's own list) and the ratchet's `allowedDrops`. Its `pr body` job sits in the main
workflow and feeds `ci result`, the one job that decides a merge: a description edit plans
`rerun=false, body=true`, so only `pr body` runs, and `ci result` takes the code's verdict from
the earlier run on the same head and judges the new body.

**Adapt.** Keep the section names; edit `SECTIONS`, `LABELLED_LINES`, `SOURCE` and
`CROSS_CHECKS` in the checker to match. Keep only the cross-checks for boundaries this repo has.
Where the repo has one job that decides every merge, fold `pr body` into it and carry the code's
verdict on an edit, as above; otherwise require `gate` and `pr body` side by side.

## P9. CI is the same gate on a fresh checkout, never writing

**What.** One workflow runs the full gate with `--check` on every push to the default branch
and every PR into it, uploads `.verify/` as an artifact, and has a `gate` job that fails when
any job was skipped, cancelled or failed. Concurrency: a newer push to a PR cancels its older
run; a run on the default branch always finishes. Branch protection requires `gate` where the
plan allows; where it does not, the docs say so and the rule holds by convention.

**Why.** The local pass record can be hand-edited and the hooks run only on the client; CI on a
fresh checkout is the guarantee. `--check` makes every baseline change a reviewed diff.

**In the reference implementations.** One workflow reuses a passing run by tree id, provisions
self-hosted runners and gives each run its own compose project; the other runs a targeted mode
by zone for PRs, a nightly full run, one `ci result` job that decides every merge, and a record
job that writes the ratchet store.

## P10. Prove it in the running app, with evidence

**What.** A project-local `verify` skill that launches the app for this worktree in isolation,
has a read-only `doctor`, drives one user path with real handles, keeps evidence (screenshots,
transcripts, response bodies, SQL proof of the side effect) outside the teardown, and names
what it did not drive. The gate is still the definition of done; the skill proves behaviour.

**Why.** Tests prove the code; a user-visible change is proven by a user's path through the
running app, and the proof outlives the session only if it is written down.

**Adapt.** When `pstack:create-verification-skill` is available and the repo has a runnable
surface (web, CLI, service), invoke it as the last build step. Otherwise write the five
sections (Launch, Doctor, Drive, Evidence, Cleanup) by hand from its outline in
`hook-contract.md`, or leave it as a named follow-up.

## P11. Completion evidence and escalation

**What.** Two paragraphs in AGENTS.md. Completion: never claim done, fixed or passing without
having just run the command that proves it and read the output; quote the lines. Escalation:
for a choice the docs and code don't settle, take the conservative path, keep going, and file
an issue saying what was chosen and why; never stop to ask, never guess silently, never lower
a gate to route around a real failure.

**Why.** Both repos found that an agent which stops to ask blocks a batch, and one that guesses
silently costs a review round. The conservative-path-plus-issue rule is the middle.

## P12. Flaky tests are failing tests

**What.** No retry anywhere (P4). A test that passes on a second run is found and fixed, or
quarantined behind a tag with an issue that says what fails, how often, and the fix. CI never
re-runs a failed job to get green without recording the flake. A flake ledger (`gh run list`
over the last N runs, the failed jobs that passed on the same tree) tells a red job from a
flaky one before blaming the change.

**Why.** A retry is where a race hides until production.

**Adapt.** The scan in P4 holds the rule; the ledger is a follow-up once CI exists.

## What to skip, and when

- A repo with no tests: P1 still (lint, typecheck, build are checks), P3 with ceilings only,
  and the report says the first test is the next step. Don't write a test suite under this skill.
- A repo that is a library with no runnable surface: skip P10.
- A repo with no git remote: P8 and P9 are written but reported as unproven.
- A repo that already has most of this (the interview shows `.claude/rules`, a baseline, a
  verify script): the gap table says "present" and the work is the missing rows only. Never
  replace a working gate with the template.
