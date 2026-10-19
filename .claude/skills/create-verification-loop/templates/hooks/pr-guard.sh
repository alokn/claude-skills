#!/usr/bin/env bash
# Claude Code hook: no `gh pr create` without a green full gate on the pushed tree. PreToolUse on
# Bash: exit 2 (block) with the reason on stderr. The rule is scripts/pr-check.sh's, shared with
# scripts/pr.sh; this file only decides whether the command is a `gh pr create`, reading it with
# quoted strings and heredoc bodies stripped, so an issue body that mentions one goes through.
#
# By hand:
#   echo '{"cwd":"'"$PWD"'","tool_input":{"command":"gh pr create"}}' | .claude/hooks/pr-guard.sh; echo "exit=$?"
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib/command-parse.sh"

# shellcheck disable=SC2034  # payload and cmd are read and set by command-parse.sh
IFS= read -r -d '' payload || true
payload_command || exit 0

pre='(^|[^[:alnum:]_-])'
post='([^[:alnum:]_-]|$)'
gh_flags='([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*'
# shellcheck disable=SC2154
[[ $cmd =~ ${pre}gh${gh_flags}[[:space:]]+pr[[:space:]]+(create|new)${post} ]] || exit 0

checkout="$(target_checkout)" || exit 0
if [ -x "$checkout/scripts/pr-check.sh" ]; then check="$checkout/scripts/pr-check.sh"
elif [ -f "$checkout/scripts/tree-fingerprint.sh" ]; then check="$ROOT/scripts/pr-check.sh"
else exit 0; fi
"$check" "$checkout" >&2 && exit 0
exit 2
