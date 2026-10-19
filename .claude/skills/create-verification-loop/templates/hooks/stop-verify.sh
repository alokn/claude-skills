#!/usr/bin/env bash
# Claude Code Stop hook: make the gate's exit code the actual definition of done.
#
# Three modes, wired in .claude/settings.json:
#   --session-start   remember the tree's fingerprint as this session's baseline (write-if-absent,
#                     so a resume or compaction cannot erase it)
#   --user-prompt     reset the failure budget: a person is back in the loop
#   (default)         the Stop hook: run the fast gate and block (exit 2) if it fails
#
# Everything before the run is a gate, because Stop fires at the end of *every* turn and a verify
# costs seconds to minutes:
#   1. this session changed no input to the gate       -> silent exit 0 (compared with the session's
#                                                         own baseline, not "is the tree dirty")
#   2. this exact tree already passed                  -> silent exit 0 (a full pass or a fast pass)
#   3. a service the gate needs is down (PREFLIGHT)    -> say DID NOT RUN, exit 0: never block on
#                                                         something the model cannot fix
#   4. it already failed MAX_ATTEMPTS times unattended -> say FAILED, exit 0: no edit-fail loops.
#                                                         --user-prompt clears the budget
#   5. another verify holds this worktree's lock       -> say DID NOT RUN, exit 0
#
# It is fast feedback, not the merge gate. Its messages keep the outcomes apart:
#   "<gate>: PASSED"            it ran and exited 0 (recorded as a fast pass, never a full one)
#   "<gate>: FAILED (n/2)"      it ran and failed; exit 2, the session keeps working
#   "<gate>: DID NOT RUN — …"   it never ran; the tree is unverified
# Only a green full gate, run by hand or by CI, says the tree passed.
#
# By hand:
#   echo '{"session_id":"try"}' | .claude/hooks/stop-verify.sh --session-start
#   echo '{"session_id":"try"}' | .claude/hooks/stop-verify.sh; echo "exit=$?"
#
# CONFIGURE: VERIFY_CMD, PREFLIGHT, MAX_ATTEMPTS.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 0
if { [ -f mise.toml ] || [ -f .tool-versions ]; } && command -v mise >/dev/null 2>&1; then eval "$(mise env -s bash 2>/dev/null)"; fi

VERIFY_CMD="${VERIFY_LOOP_HOOK_CMD:-scripts/verify.sh fast}"   # the fast tier; a seam for tests
# A command that exits non-zero when the gate could not run anyway (a database down, Docker
# stopped). Its last stderr line is reported. Leave empty when the gate needs no services.
PREFLIGHT=""
# PREFLIGHT='(exec 3<>/dev/tcp/127.0.0.1/5432) 2>/dev/null || { echo "Postgres is not answering on 5432: run \`docker compose up -d db\`" >&2; exit 1; }'
MAX_ATTEMPTS=2
LOCK_WAIT_POLLS=24   # x 5 s

GITDIR="$(git rev-parse --git-dir 2>/dev/null || echo "$ROOT/.git")"
STATE="$GITDIR/verify-loop/stop-hook"
LOCK="$GITDIR/verify-loop/verify.lock"
source "$ROOT/scripts/tree-fingerprint.sh" 2>/dev/null

json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n' ' '; }
# A Stop hook's stdout is parsed as JSON; systemMessage reaches the user, nothing reaches the model.
say() { printf '{"systemMessage": "%s", "suppressOutput": true}\n' "$(json_escape "$1")"; }
UNVERIFIED="This tree is not verified; the full gate is."

payload="$(cat 2>/dev/null || true)"
session="$(printf '%s' "$payload" | sed -nE 's/.*"session_id"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -1)"
session="${session:-unknown}"; session="${session//[^A-Za-z0-9._-]/_}"
mkdir -p "$STATE"
baseline="$STATE/$session.baseline"

if [ "${1:-}" = "--session-start" ]; then
  if [ ! -f "$baseline" ]; then start="$(fingerprint)" && printf '%s\n' "$start" > "$baseline"; fi
  find "$STATE" -type f -mtime +14 -delete 2>/dev/null
  exit 0
fi
if [ "${1:-}" = "--user-prompt" ]; then
  rm -f "$STATE/$session.attempts"
  exit 0
fi

# gate 1: did this session change anything the gate reads?
stamp="$(fingerprint)" || stamp=""
if [ -n "$stamp" ]; then
  if [ -f "$baseline" ]; then
    [ "$(cat "$baseline" 2>/dev/null)" = "$stamp" ] && exit 0
  elif [ -z "$(git status --porcelain -- "${FINGERPRINT_PATHS[@]}" 2>/dev/null)" ]; then
    # No baseline (hook installed mid-session): fall back to "is the tree dirty", and to the
    # last pass for a clean tree whose machine inputs moved.
    lastpass="$(last_pass)"
    { [ -n "$lastpass" ] && [ "$lastpass" != "$stamp" ]; } || exit 0
  fi
fi

# gate 2: has this exact tree already passed, in full or in the fast tier?
[ -n "$stamp" ] && { [ "$(last_pass)" = "$stamp" ] || [ "$(last_fast_pass)" = "$stamp" ]; } && exit 0

# gate 3: can the gate run at all?
if [ -n "$PREFLIGHT" ]; then
  if ! reason="$(bash -c "$PREFLIGHT" 2>&1 >/dev/null)"; then
    say "verify: DID NOT RUN — ${reason:-a service the gate needs is down}. $UNVERIFIED"
    exit 0
  fi
fi

# gate 4: the failure budget for an unattended stretch
attempts_file="$STATE/$session.attempts"
attempts="$(cat "$attempts_file" 2>/dev/null || echo 0)"
case "$attempts" in ''|*[!0-9]*) attempts=0 ;; esac
if [ "$attempts" -ge "$MAX_ATTEMPTS" ]; then
  say "verify: FAILED $MAX_ATTEMPTS times — not run again or blocking until you reply. Run \`$VERIFY_CMD\` yourself, or say something to restore the gate. $UNVERIFIED"
  exit 0
fi

# gate 5: one verify per worktree at a time
acquired=0
for _ in $(seq 1 "$LOCK_WAIT_POLLS"); do
  if mkdir "$LOCK" 2>/dev/null; then printf '%s' "$$" > "$LOCK/pid"; acquired=1; break; fi
  holder="$(cat "$LOCK/pid" 2>/dev/null)"
  if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then rm -rf "$LOCK"; continue; fi
  sleep 5
done
if [ "$acquired" != 1 ]; then
  say "verify: DID NOT RUN — another verify is already running in this worktree. $UNVERIFIED"
  exit 0
fi
trap 'rm -rf "$LOCK"' EXIT

# the gate itself
log="$STATE/$session.log"
if bash -c "$VERIFY_CMD" > "$log" 2>&1; then
  printf '0' > "$attempts_file"
  [ -n "$stamp" ] && record_fast_pass "$stamp"
  say "$VERIFY_CMD: PASSED (the fast tier; the full gate is not run here)"
  exit 0
fi
printf '%s' "$((attempts + 1))" > "$attempts_file"
{
  printf '%s: FAILED (attempt %s/%s). The work is not done. Fix it rather than stopping; never weaken a check to get past it. Full log: %s\n\n' "$VERIFY_CMD" "$((attempts + 1))" "$MAX_ATTEMPTS" "$log"
  tail -n 60 "$log"
} >&2
exit 2
