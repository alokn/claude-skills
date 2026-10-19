---
name: verification-loop
description: >
  Use when asked to set up, install, harden or audit a repository's verification loop, definition
  of done, agent guardrails, Claude Code hooks, AGENTS.md/CLAUDE.md, init script, ratchet or
  deterministic verification, or to make a repo "agent-ready" with a gate, hooks and a ratchet.
  Works on any repo and language (Node and React Native, Python, Ruby/Rails, PHP, Go, Rust, JVM,
  .NET); interviews the repo, not the user.
argument-hint: "[path] [--plan-only] [--skip hooks,ci,docs,pr,verify-skill]"
---

# Verification loop

You install, in one repo, a verification loop proven in production repos: one gate command whose
exit 0 is the definition of done, a one-step idempotent `init.sh`, a ratchet that lets figures
only improve, determinism scans, a tree fingerprint, Claude Code hooks that enforce the loop
without trapping a session, agent docs that load themselves, and a PR path that carries its
evidence. You interview the repo, not the person: every decision comes from what is on disk,
and the few that can't are made conservatively and written down.

Read `references/principles.md` now, in full. It is the doctrine (P1 to P12), with why each
exists and what to skip when. `references/gate-recipes.md` has the commands per ecosystem;
`references/hook-contract.md` has the hook contract and the payload tests.

## Why this process exists (observed without it)

An unguided agent given this task produced a chained `lint && typecheck && test` script that
stops at the first failure and writes no reports; a Stop hook that re-ran on every turn and
blocked only once; no init script, so the next agent in a fresh worktree would still install by
hand; no ratchet, fingerprint or determinism scans, so a deleted test or an added retry would
pass; no PR guard; a single AGENTS.md with no area docs or reading map; and it widened scope
into changing the server's HTTP behaviour "while it was there". Every step below closes one of
those. Do them in order; each is proven before the next.

## Arguments

`$ARGUMENTS`: a repo path (default: cwd); `--plan-only` (write the gap table and plan, build
nothing); `--skip <list>` to leave out `hooks`, `ci`, `docs`, `pr` or `verify-skill`.

## Rules that hold throughout

- **Never weaken a check to make it pass.** A red lint, type or test on the current tree is a
  finding: fix the real cause when it is small and clearly a bug (a missing type annotation, a
  nullable return), otherwise report it with the number and leave the check red in the report.
  Never relax a config, add an ignore, lower a figure, add a retry, or `.skip`.
- **Setup is not a feature.** Change source code only to make an existing check honest (above).
  No new endpoints, behaviours or refactors. If the gate exposes a bug, file it in the report.
- **Compose, don't replace.** Use the commands, configs and docs the repo already has. A check
  counts as existing when its tool is already a dependency or config of the repo (a formatter's
  `--check`, a type checker that is installed but unscripted), plus the scans. Extend an
  existing AGENTS.md, CI workflow or verify script; never overwrite one that works.
- **Every file you add is run before you move on.** A hook is tested by piping payloads; a
  script by running it; `init.sh` in a fresh worktree. "Written" is not "done".
- **A red tree is proven in a throwaway worktree.** When the gate is red on the current tree
  for a cause you must not fix (a dependency change, a real bug outside setup), do every proof
  that needs green (the ratchet's first write, the Stop hook's PASSED step, `init.sh --fast`) in
  `git worktree add --detach "$WORK/proof" HEAD` with the smallest fix applied there and marked
  PROOF-ONLY, quote the proof, delete the worktree, and leave the repo red with the cause named
  in the report. The repo's own baseline is written by the person after the fix lands.
- **Unknown ecosystem is not a blocker.** The recipes are examples. The procedure at the top of
  `gate-recipes.md` derives the gate for any language from the repo's own commands and the
  runner's own output (`figures.sh count-regex` / `pct-regex` read any text).
- **Commit nothing** unless asked. Stage nothing with `-A`. The report lists what to commit.
- **Templates are starting points.** `templates/` is bash + python3 + git, so it runs anywhere;
  edit the `CONFIGURE` blocks, keep the shape. If the repo already owns a scripting language
  for its tooling (`scripts/*.mjs`, a `Rakefile`), you may port a template, but then port its
  behaviour exactly, tests included.

## Workflow

### Step 0: Setup

```bash
SKILL_DIR=<absolute path of this skill directory>
REPO=<absolute repo path>
WORK=<scratchpad dir>/verification-loop-$(date +%s); mkdir -p "$WORK"
```

### Step 1: Interview (deterministic, then by hand)

```bash
bash "$SKILL_DIR/scripts/interview.sh" "$REPO" > "$WORK/interview.md"
```

Read it, then read what it points at: README and CONTRIBUTING (the documented commands, in the
repo's words), every CI workflow, the test runner config (reporters, coverage, retries), the
manifest scripts, and any existing AGENTS.md/CLAUDE.md/`.claude/`. Run the repo's own
documented commands once each (install if needed is fine here, this is you, not a hook) and
record what is green and what is red on the current tree, with the first lines of each failure.

Write `$WORK/facts.md`: ecosystem and package manager; the exact lint, type, test, coverage,
build and dead-code commands (existing or the recipe's); services and env the gate needs; what
is red today; what agent docs and hooks exist; the runnable surface (web, CLI, service, library).

### Step 2: Gap table and plan

Write `$WORK/plan.md`: one row per principle P1 to P12 with `present | partial | absent`, what
you will do for this repo in one line, or `skip: <reason>` from the "What to skip" list in
`principles.md`. Then the ordered build list. With `--plan-only`, copy it to
`$REPO/verification-loop-plan.md` and stop here with its path.

### Step 3: Build, in this order, each proven before the next

Copy from `$SKILL_DIR/templates/` into the repo: `scripts/` → `scripts/`, `hooks/` →
`.claude/hooks/`, `settings.json` → `.claude/settings.json`, `init.sh`, `.github/`, `docs/`,
`AGENTS.md` and `CLAUDE.md` to the same places at the root. `chmod +x` the scripts, add
`.verify/` to `.gitignore`, note any untracked file the setup depends on (a lockfile: the
interview lists them; it must be committed for `init.sh` and CI to work), then configure:

1. **The gate (P1, P4).** Fill `preflight()`, `fast_checks()`, `full_checks()` and `figures()`
   in `scripts/verify.sh` from `facts.md` and `gate-recipes.md`. Put the three scans
   (`no-markers`, `no-retries`, `max-lines`) in the fast tier. Run `scripts/verify.sh fast` and
   `full`. Red checks: apply the first rule above. Existing marker hits that are legitimate
   deferred work: file them (an issue, or the report) and make the scan a ratchet ceiling
   instead of a hard fail until they are gone. Do not continue until the summary block is what
   the report will quote.
2. **Fingerprint (P5).** Edit `FINGERPRINT_PATHS` exclusions (the interview's "tracked runtime
   state" row: `tmp/`, `log/`, sqlite files, anything the gate rewrites) and `machine_inputs()`
   in `scripts/tree-fingerprint.sh` for this ecosystem. Prove: run it twice (same hash), touch a
   source file (different), revert (same), edit a `.md` (same).
3. **Ratchet (P3).** `figures()` emits at least `tests.total` and the `markers` ceiling;
   `coverage.lines` when the runner has coverage built in or a provider is already installed
   (otherwise list the provider as a follow-up; don't add it here). Run `full` to write
   `verify-baseline.json`;
   run `full --check` (holds); delete one test and run `full` (fails, naming the figure);
   restore. Quote both in the report. The sanctioned way down, for the docs:
   `scripts/verify.sh full --allow-drop <figure> --reason "<category>: <why>"`.
4. **init.sh (P2).** Fill sections 1 to 5 from `facts.md`; keep the stamp and the gate. Edit
   `PIN_FILES` in `scripts/init-stamp.sh`. Prove in a fresh worktree:
   `git worktree add --detach "$WORK/wt" HEAD && (cd "$WORK/wt" && ./init.sh --fast)`; then
   `git worktree remove --force "$WORK/wt"`.
   (The worktree has no untracked template files yet, so commit nothing: copy the new files
   into the worktree for the proof, or prove on the main checkout with `./init.sh --fast` and
   say so.)
5. **Hooks (P6)** unless `--skip hooks`. Check `VERIFY_CMD`, `PREFLIGHT` and `INSTALL_RE` (the
   defaults fit a repo with no services; keep only this ecosystem's installs).
   Run every payload in `hook-contract.md` and record each exit code: init guard refused then
   allowed after the stamp, the quoted mention allowed; PR guard refused with three reasons;
   Stop hook silent, then PASSED after a touch, then exit 2 twice on a broken test, then the
   budget message, then reset. Merge the hook entries into an existing `.claude/settings.json`
   rather than replacing it. If `claude` is on PATH (`command claude`, in case a shell function
   wraps it), run the one-line live check (one short Haiku call; skip it only if the user has
   said not to spend model calls).
6. **Docs (P7, P11, P12)** unless `--skip docs`. `AGENTS.md` from the template, extended into
   an existing one if there is one (keep its voice and facts); `CLAUDE.md` as `@AGENTS.md` plus
   the hooks table; `docs/agents/testing.md` with real `paths:` and a `.claude/rules/testing.md`
   symlink (`ln -s ../../docs/agents/testing.md .claude/rules/testing.md`); one more area doc
   where the interview found a second area with its own traps; `docs/HOOKS.md`. Every command
   named in a doc exists: check with
   `find . -name '*.md' -not -path '*/node_modules/*' | xargs grep -ohE 'scripts/[a-z-]+\.(sh|py)' | sort -u`
   against `ls scripts`.
7. **PR path (P8)** unless `--skip pr`: `scripts/pr.sh`, `scripts/pr-check.sh`, the PR
   template. Prove `scripts/pr-check.sh` refuses now (dirty, unpushed) with the commands named.
8. **CI (P9)** unless `--skip ci`: a new workflow from the template, or `scripts/verify.sh full
   --check` added to the existing one, plus the `gate` job. Validate the YAML
   (`python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' <file>` or
   `ruby -ryaml -e 'YAML.load_file(ARGV[0])' <file>`, whichever exists); it is reported as
   unproven until a run exists.
9. **The verify (drive-the-app) skill (P10)** unless `--skip verify-skill` or the repo has no
   runnable surface: invoke `pstack:create-verification-skill` when it is listed in your skills
   (it carries its own launch-drive-cleanup proof, which takes a while; do it last), else write
   the five sections from `hook-contract.md`, or name it as the first follow-up.

### Step 4: Prove the whole loop once

From the configured repo: `scripts/verify.sh full` (green), the fingerprint equals
`--last-pass`, `scripts/pr-check.sh` names exactly what is left (push), and the Stop hook cycle
from step 5. Keep the output.

### Step 5: Report

Write `$WORK/report.md` from `references/report-template.md`: the gap table before → after,
every proof as command plus quoted lines, what was red and what was done about it, what was not
done and why, and the files to commit. Tell the user the absolute path.

## Red flags: stop and re-read the rules

| Thought | Reality |
|---|---|
| "The typecheck is red; I'll loosen `strict`" | Fix the cause or report the number. The gate's job is to be red here. |
| "This test is flaky; a retry will stabilise the hook" | A retry is where a race hides. The scan refuses it. Quarantine with an issue. |
| "The Stop hook is slow; I'll skip it" | Make the fast tier fast (drop coverage and e2e from it), not absent. |
| "I'll write the docs and test the hooks later" | A hook nobody piped a payload through is a guess. Step 5 before step 6. |
| "While I'm here, this endpoint should return 400" | Setup is not a feature. File it. |
| "The repo already has a verify script; the template is cleaner" | Compose, don't replace. Add what's missing around it. |
| "No tests exist, so there's nothing to ratchet" | Ceilings still ratchet (markers, suppressions). Say in the report that the first test is next. |
| "I'll commit so the worktree proof works" | Copy the files into the worktree instead. Committing is the user's call. |
