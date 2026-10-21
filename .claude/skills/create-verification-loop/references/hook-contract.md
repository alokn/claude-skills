# Claude Code hooks: the contract, the design rules, the tests

## The contract

A hook is a shell command Claude Code runs at a fixed point. The project's hooks live in the
committed `.claude/settings.json`; a user's `~/.claude/settings.json` and a checkout's
`.claude/settings.local.json` add to them. Each entry names an event, a matcher (a regex on the
tool name for tool events; `compact` and friends for SessionStart), a command and a timeout in
seconds. `${CLAUDE_PROJECT_DIR}` is the checkout the session started in.

Events this skill uses: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `Stop`. Also
available: `PostToolUse` (one reference repo sends area docs to worktree subagents with it, since
Claude Code matches `.claude/rules` only against the main checkout), `PreCompact`, `SubagentStop`,
`TaskCompleted` (worth wiring to the same fast gate as Stop when the repo uses tasks).

The command gets JSON on stdin: `session_id`, `cwd`, `hook_event_name`, and for tool events
`tool_name` and `tool_input` (`command` for Bash; `file_path` for Edit/Write). It answers with
its exit code and output:

| The hook… | Claude Code… |
|---|---|
| exits 0, no output | carries on silently |
| exits 0, prints text, on SessionStart or UserPromptSubmit | adds the text to the model's context |
| exits 0, prints JSON | reads it: `systemMessage` is shown to the user; `hookSpecificOutput.additionalContext` goes to the model |
| exits 2 | blocks: a PreToolUse call doesn't run; a Stop doesn't end the turn. stderr goes to the model as the reason |
| any other exit | shows the error and carries on |

Exit 2 with a clear reason on stderr that names the command to run instead is how every guard
works: the model reads the refusal and runs that instead.

## Design rules

1. **Read the command the way the shell runs it.** Source `scripts/lib/command-parse.sh` and use
   `payload_command`: quoted strings and heredoc bodies are stripped first, so `grep "npm install"
   README.md` and an issue body that says "then gh pr create" go through. Only a command that
   would run is judged.
2. **Judge the checkout the payload's `cwd` is in** (`target_checkout`), not the one the script
   lives in. A subagent in its own worktree runs the parent's hooks.
3. **Block only on what the model can fix.** Exit 2 with the fix named. Anything outside the
   model's control (a stopped container, a held lock) is exit 0 and a message that says
   `DID NOT RUN`, never a block, or the session loops. A Stop hook gets a failure budget that a
   human prompt resets.
4. **Keep stdout clean where it becomes context.** On SessionStart and UserPromptSubmit anything
   printed goes to the model.
5. **No jq or node in a guard that may run before init.sh.** The payload is matched raw.
6. **Narrow matcher, short timeout.** A PreToolUse hook on Bash runs before every shell command.
7. **Test it by piping payloads**, including a quoted mention that must pass, and keep those
   tests in the gate when the repo has a test runner (a `scripts/test/*-hook.test.*` or
   `tests/integration/hooks/` file that spawns the hook with each payload).
8. **Back it with the gate.** A rule that matters has a test inside the gate that fails the same
   mistake under any harness. The hook is the early warning.
9. **Document it** in CLAUDE.md's hooks table and in `docs/HOOKS.md`, with the "what still holds
   without it" table: `gh api`, another harness, or a person's terminal skips every hook.

## Payloads to pipe by hand (and to keep as tests)

Read the exit code of the hook itself: never pipe the hook's output into `tail` or `grep`, or
`$?` is the pipe's (redirect to a file instead and read that).

```bash
H=.claude/hooks
# init guard: refused before init.sh stamped the worktree; a quoted mention passes
echo '{"cwd":"'"$PWD"'","tool_name":"Bash","tool_input":{"command":"npm install"}}' | $H/init-guard.sh; echo "exit=$?"
echo '{"cwd":"'"$PWD"'","tool_name":"Bash","tool_input":{"command":"grep \"npm install\" README.md"}}' | $H/init-guard.sh; echo "exit=$?"
# PR guard: refused on an unpushed or unverified tree; the refusal names the commands
echo '{"cwd":"'"$PWD"'","tool_input":{"command":"gh pr create"}}' | $H/pr-guard.sh; echo "exit=$?"
echo '{"cwd":"'"$PWD"'","tool_input":{"command":"gh issue create --body \"run gh pr create later\""}}' | $H/pr-guard.sh; echo "exit=$?"
# PR body hook: refused on an inline body or an unfilled file; a filled file and a mention pass
echo '{"cwd":"'"$PWD"'","tool_input":{"command":"gh pr create --title x --body \"y\""}}' | $H/pr-body.sh; echo "exit=$?"
echo '{"cwd":"'"$PWD"'","tool_input":{"command":"gh pr create --body-file .github/pull_request_template.md"}}' | $H/pr-body.sh; echo "exit=$?"
echo '{"cwd":"'"$PWD"'","tool_input":{"command":"gh pr create --body-file <a filled body>"}}' | $H/pr-body.sh; echo "exit=$?"  # 0
echo '{"cwd":"'"$PWD"'","tool_input":{"command":"gh issue create --body \"then gh pr create --body x\""}}' | $H/pr-body.sh; echo "exit=$?"  # 0
# Stop hook: silent on an unchanged tree; runs on a change; blocks (2) on red; budget; reset
echo '{"session_id":"try"}' | $H/stop-verify.sh --session-start
echo '{"session_id":"try"}' | $H/stop-verify.sh; echo "exit=$?"          # 0, silent
echo "// touched" >> <a source file with no uncommitted changes, so `git checkout -- <file>` reverts only this>
echo '{"session_id":"try"}' | $H/stop-verify.sh; echo "exit=$?"          # runs; 0 + PASSED, or 2 + log tail
<break a test>
echo '{"session_id":"try"}' | $H/stop-verify.sh; echo "exit=$?"          # 2 (attempt 1/2)
echo '{"session_id":"try"}' | $H/stop-verify.sh; echo "exit=$?"          # 2 (attempt 2/2)
echo '{"session_id":"try"}' | $H/stop-verify.sh; echo "exit=$?"          # 0 + "FAILED 2 times — not run again"
echo '{"session_id":"try"}' | $H/stop-verify.sh --user-prompt            # budget reset
rm -rf "$(git rev-parse --git-dir)/verify-loop/stop-hook"/try.*          # tidy
```

The end-to-end check that the wiring is live, when `claude` is installed:

```bash
claude -p --model haiku --permission-mode acceptEdits 'Append a line "// scratch" to <a source file>, then stop.'
# expect: "Stop hook" output naming the fast gate, PASSED or FAILED; then revert the file.
# (No `timeout` wrapper: macOS has none; the Stop timeout in settings.json bounds the gate.)
```

## The `verify` (drive the app) skill: the five sections

When writing one by hand instead of through `pstack:create-verification-skill`, the file is
`.claude/skills/verify/SKILL.md` with frontmatter (`name: verify`, a description naming the
app, the surface and when to use it) and these sections, each grounded in this repo:

- **Launch**: the exact command that starts the app for verification in isolation from the
  developer's own instance (own port, own database or data dir), how to tell it is ready, and
  teardown.
- **Doctor**: one read-only check that says whether this instance is worth driving (process
  up, right build, port owned by us, HEAD not moved since launch).
- **Drive**: the harness recipe with real handles from this repo (ARIA roles, routes, prompt
  strings, endpoints), not examples.
- **Evidence**: what a proof captures and where it goes; the standards: the real user path,
  the action and the state it produced, the side effect as well as the screen, mocks only where
  production already isolates; name what was not driven.
- **Cleanup**: tear down what the run started (never kill by name), keep the evidence.

Plus a `features/README.md` with one file per user-facing feature: what it is, how a user
reaches it, how to drive it, what end state proves it.
