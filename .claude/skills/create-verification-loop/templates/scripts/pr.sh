#!/usr/bin/env bash
# `scripts/pr.sh [gh pr create args…]`: open a pull request the way the gate wants one opened. It
# runs scripts/pr-check.sh (clean tree, HEAD pushed, a green full gate on this exact tree) and
# refuses if that fails. Otherwise it runs `gh pr create` with your arguments and appends to the
# body a "Verification" block: the summary lines of the gate that passed and the HEAD it passed
# on. No harness needed: a person or any agent runs it.
#
# The body is whatever you pass (--body/-b, --body-file/-F, `-` for stdin), then the block.
#
# Tracker: every PR names its issue (see scripts/tracker.py). `--issue <KEY-n|#n|URL|none>` sets
# it; otherwise the ID is read from a "Tracker:" line in the body, the start of the title, or the
# branch name (configured keys only). pr.sh writes it into the body's Tracker line and, for
# KEY-n, the front of the title. With no ID it warns and still opens the PR; CI's tracker check
# is what makes it required.
set -uo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SELF/pr-check.sh" || exit 1
head_sha="$(git rev-parse HEAD)"

verification_block() {
  local record passed_on
  record="$("$SELF/tree-fingerprint.sh" --last-pass-summary)"
  printf '## Verification\n\n'
  if [ -n "$record" ]; then
    passed_on="$(printf '%s\n' "$record" | sed -n '1s/^head //p')"
    printf 'The full gate passed on `%s`' "$passed_on"
    [ "$passed_on" = "$head_sha" ] || printf ' (this PR is at `%s`, which differs only in files the gate does not read)' "$head_sha"
    printf ':\n\n```\n%s\n```\n' "$(printf '%s\n' "$record" | sed '1,2d')"
  else
    printf 'The full gate passed this tree at `%s` (no summary was recorded).\n' "$head_sha"
  fi
  printf '\nOpened by `scripts/pr.sh`, which checked the tree was clean, pushed and verified.\n'
}

tmp="$(mktemp)" || exit 1
trap 'rm -f "$tmp"' EXIT
args=(); body=""; title=""; issue=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --body | -b) body="${2-}"; shift 2 || shift ;;
    --body=*) body="${1#--body=}"; shift ;;
    --body-file | -F) if [ "${2-}" = "-" ]; then body="$(cat)"; else body="$(cat "${2-}")" || exit 1; fi; shift 2 || shift ;;
    --body-file=*) body="$(cat "${1#--body-file=}")" || exit 1; shift ;;
    --title | -t) title="${2-}"; shift 2 || shift ;;
    --title=*) title="${1#--title=}"; shift ;;
    --issue) issue="${2-}"; shift 2 || shift ;;
    --issue=*) issue="${1#--issue=}"; shift ;;
    *) args+=("$1"); shift ;;
  esac
done
tracker() { TITLE="$title" BODY="$body" BRANCH="$(git rev-parse --abbrev-ref HEAD)" ISSUE="$issue" python3 "$SELF/tracker.py" "$@"; }
tracker find > /dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then tracker find >&2; exit 1; fi  # a bad --issue value
if [ "$rc" -eq 0 ]; then
  body="$(tracker body)"; title="$(tracker title)"
else
  echo "pr.sh: no tracker ID. Pass --issue <KEY-n|#n|URL|none>, or put 'Tracker: …' in the body. Opening anyway; CI's tracker check will fail until the PR names one." >&2
fi
[ -n "$title" ] && args+=(--title "$title")
{ [ -n "$body" ] && printf '%s\n\n' "$body"; verification_block; } > "$tmp"
gh pr create ${args[@]+"${args[@]}"} --body-file "$tmp"
