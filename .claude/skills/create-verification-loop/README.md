<!--
  Developer documentation — NOT read by the agent. Claude loads SKILL.md and the references it
  names. Keep usage and maintenance notes here.
-->

# create-verification-loop

A Claude Code skill that installs, in any repository, a verification loop distilled from
production repos that run agents at scale: one gate command (`scripts/verify.sh fast|full`), a
one-step `init.sh`, a ratchet (`verify-baseline.json`), determinism scans, a tree fingerprint,
Claude Code hooks (Stop, init guard, PR guard), agent docs that load themselves, and a PR path
that carries its evidence. It interviews the repo, not the person.

## Install

Symlink or copy `.claude/skills/create-verification-loop` into `~/.claude/skills/` (user-level) or a
project's `.claude/skills/`. Then in any repo:

```
/create-verification-loop                 # the current directory
/create-verification-loop ~/src/app --plan-only
/create-verification-loop . --skip ci,verify-skill
```

## Layout

```
SKILL.md                     the workflow the agent follows
references/principles.md     P1-P12: what, why, how the two source repos did it, how to adapt
references/gate-recipes.md   per-ecosystem commands for the gate and the figures
references/hook-contract.md  Claude Code hook contract, design rules, payload tests
references/report-template.md
scripts/interview.sh         deterministic repo inventory (read-only)
templates/                   what gets copied into the target repo and configured:
  scripts/verify.sh            the gate runner (bash)
  scripts/ratchet.py           the ratchet (python3 stdlib)
  scripts/figures.sh           report → figure helpers (vitest/jest, JUnit, go, cargo, pytest, istanbul, lcov, cobertura)
  scripts/scan-gate.sh         text-scan gates (no-markers, no-retries, no-sleeps)
  scripts/max-lines.sh
  scripts/tree-fingerprint.sh  fingerprint + last-pass / last-fast-pass records
  scripts/init-stamp.sh        the init stamp the init guard reads
  scripts/pr-check.sh, pr.sh   the PR path
  scripts/tracker.py           the tracker-ID rule (pure logic, --selftest)
  scripts/lib/command-parse.sh payload parsing shared by the guards
  hooks/stop-verify.sh, init-guard.sh, pr-guard.sh
  settings.json                the hook wiring
  init.sh                      the setup skeleton
  .github/workflows/ci.yml, tracker.yml, .github/pull_request_template.md
  AGENTS.md, CLAUDE.md             (repo root)
  docs/HOOKS.md, docs/agents/testing.md
```

Requirements in the target repo: git, bash 3.2+, python3 (the ratchet and figures). No jq, no
node.

## How it was tested

- RED: an Opus subagent given the bare task on a throwaway Node repo (see SKILL.md, "Why this
  process exists").
- Templates: exercised by hand on the same repo: the gate's fast/full/--check modes, the
  ratchet's first write, hold, regression, allowed drop, refused drop and stale-write paths; the
  init guard (missing, stale, ok, quoted mention, heredoc), the PR guard (refused with three
  reasons, quoted mention), the Stop hook (silent, PASSED, exit 2 twice, budget message,
  --user-prompt reset, PREFLIGHT down, live lock held).
- GREEN: Opus subagents running the skill end to end on a Node (npm/vitest) repo, a Python
  (uv/pytest/ruff/mypy) repo and a Rails 8 (minitest/rubocop/brakeman) repo. Their findings
  (a report-file collision, a figures step that failed open, scans that skipped untracked files,
  Node-specific wording) were folded back into the templates and SKILL.md.

## Maintaining

When a repo you run this loop in grows a new mechanism worth generalising (a scoped verify, a
coverage marker on push, a locked catalogue guard), add it to `principles.md` with its why and
a template only if it is ecosystem-neutral. Re-run the GREEN test after any change to SKILL.md.
