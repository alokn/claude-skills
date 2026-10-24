@AGENTS.md

# Claude Code notes

Everything that holds for any agent is in `AGENTS.md`, imported above, and the area docs in
`docs/agents/` it points to. This file is only what's specific to working here as Claude Code.

## Hooks

Committed hooks (`.claude/settings.json`) verify for you:

| Event (matcher) | Script | What it does | How it answers |
|---|---|---|---|
| `SessionStart` | `.claude/hooks/stop-verify.sh --session-start` | Records the tree's fingerprint as this session's baseline | Silent |
| `SessionStart` | `.claude/hooks/init-guard.sh --session-start` | Tells you to run `./init.sh --skip-verify` if this worktree hasn't | Text into the context |
| `UserPromptSubmit` | `.claude/hooks/stop-verify.sh --user-prompt` | Resets the Stop hook's failure budget: a person is back | Silent |
| `PreToolUse` (`Bash`) | `.claude/hooks/init-guard.sh` | Refuses a hand-run install until `./init.sh` has stamped the worktree | Exit 2 |
| `PreToolUse` (`Bash`) | `.claude/hooks/pr-guard.sh` | Refuses `gh pr create` unless the tree is clean, pushed, and the full gate passed this exact tree | Exit 2 |
| `PreToolUse` (`Bash`) | `.claude/hooks/pr-body.sh` | Refuses `gh pr create`, or a `gh pr edit` that sets the body, unless the body comes from `--body-file` and fills `.github/pull_request_template.md` (`scripts/pr-body.py`) | Exit 2, naming what is missing |
| `Stop` | `.claude/hooks/stop-verify.sh` | If this session changed an input to the gate, runs `scripts/verify.sh fast` and blocks the turn on red | `systemMessage`; exit 2 on a failure |

The Stop hook is feedback, not the merge gate. It exits 0 *without verifying* when a service is
down, the worktree's lock is held, or it has failed twice with nobody typing, and its message
says `DID NOT RUN` or `FAILED`, never `PASSED`. A fast pass is recorded apart from a full pass
and never satisfies the PR guard. Asking questions and editing docs cost nothing.

Every hook reads the command with quoted strings and heredoc bodies stripped
(`scripts/lib/command-parse.sh`), so a `grep` or an issue body that mentions an install or a PR
goes through. Each judges the checkout the payload's `cwd` is in. Run one by hand with the
payloads in `docs/HOOKS.md`.

**What still holds without the hooks** (`gh api`, another harness, or your own terminal skip
them): `scripts/pr.sh` runs the PR guard's check and the body check; CI's `gate` runs the full
gate on every PR, and `pr body` checks the description on every PR and every edit of it;
`./init.sh` is the documented first step.

## Rules that load themselves

`.claude/rules/` holds symlinks to the docs under `docs/agents/` that carry `paths:`
frontmatter. Claude Code loads a rule when the session reads a file matching its paths, so the
area doc arrives with the first file you open in that area. The reading map in `AGENTS.md` is
still the way in for a change that spans areas: a rule loads on a file read, not on a plan.

## Skills

<`verify` drives the running app and keeps evidence; use it before claiming a user-visible
change works. Delete this section if the repo has no project skills.>
