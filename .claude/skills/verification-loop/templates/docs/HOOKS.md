# How the Claude Code hooks work

This repo ships Claude Code hooks that check a session while it works: they refuse some
commands, verify changes when a session stops, and say when a worktree isn't set up. This page
is for a person who wants to know what they are, how they fire, how to watch one, and how to
change one. `CLAUDE.md`, "Hooks", is the agent's reference; each script's header is its spec.

## What a hook is

A hook is a shell command Claude Code runs at a fixed point in a session, wired in the committed
`.claude/settings.json`. It gets JSON on stdin (`session_id`, `cwd`, and for tool events
`tool_name` and `tool_input`) and answers with its exit code: 0 carries on (text on
SessionStart goes to the model; JSON `systemMessage` goes to you), 2 blocks the call or the
turn and sends stderr to the model as the reason, anything else shows an error and carries on.

## The hooks here

| Event (matcher) | Script | What it does | Answer |
|---|---|---|---|
| SessionStart | `.claude/hooks/stop-verify.sh --session-start` | Records the tree's fingerprint as the session's baseline | silent |
| SessionStart | `.claude/hooks/init-guard.sh --session-start` | Says to run `./init.sh` when the worktree isn't stamped | text |
| UserPromptSubmit | `.claude/hooks/stop-verify.sh --user-prompt` | Resets the Stop hook's failure budget | silent |
| PreToolUse (Bash) | `.claude/hooks/init-guard.sh` | Refuses an install until `./init.sh` stamped the worktree | exit 2 |
| PreToolUse (Bash) | `.claude/hooks/pr-guard.sh` | Refuses `gh pr create` on a dirty, unpushed or unverified tree | exit 2 |
| Stop | `.claude/hooks/stop-verify.sh` | Runs `scripts/verify.sh fast` when the session changed an input to the gate; blocks on red | JSON; exit 2 |

Three things they share: they read a command with quoted strings and heredoc bodies stripped
(`scripts/lib/command-parse.sh`), so a mention is not a command; they judge the checkout the
payload's `cwd` is in; and they never trap a session: the Stop hook exits 0 *without verifying*
when a service is down, the lock is held, or after two failures with nobody typing, and says
`DID NOT RUN` or `FAILED`, never `PASSED`.

## Watch one fire

```bash
echo '{"cwd":"'"$PWD"'","tool_name":"Bash","tool_input":{"command":"<install command>"}}' | .claude/hooks/init-guard.sh; echo "exit=$?"
echo '{"cwd":"'"$PWD"'","tool_input":{"command":"gh pr create"}}' | .claude/hooks/pr-guard.sh; echo "exit=$?"
echo '{"session_id":"try"}' | .claude/hooks/stop-verify.sh --session-start
echo '{"session_id":"try"}' | .claude/hooks/stop-verify.sh; echo "exit=$?"
rm -rf "$(git rev-parse --git-dir)/verify-loop/stop-hook"/try.*
```

`/hooks` inside Claude Code lists every hook that's loaded.

## What they can't do

The hooks run on your machine, inside Claude Code. `gh api`, another harness, or a command in
your own terminal skips every one. Each guard is the early warning; something else is the
guarantee:

| Hook | What still holds without it |
|---|---|
| Init guard | `./init.sh` is the documented first step (`AGENTS.md`) |
| PR guard | `scripts/pr.sh` runs the same check; CI's `gate` runs the full gate on every PR |
| Stop hook | `scripts/verify.sh full` by hand, and CI. A fast pass never counts as a full one |

## Changing or adding a hook

1. Write the script under `.claude/hooks/` with a header saying which event it's wired to, what
   it refuses or adds, and a "by hand" example.
2. Read the payload with `scripts/lib/command-parse.sh` (`payload_command`, `target_checkout`).
3. Block only on what the model can fix: exit 2 with the command to run instead. Anything else
   is exit 0 and a message.
4. Keep stdout clean where it becomes context.
5. Wire it in `.claude/settings.json` with the narrowest matcher and a timeout.
6. Test it by piping payloads, including a quoted mention that must go through, and keep the
   test in the gate.
7. Back it with the gate if the rule matters.
8. Document it in `CLAUDE.md` and in the tables above.
