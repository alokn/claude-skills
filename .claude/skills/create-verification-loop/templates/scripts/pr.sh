#!/usr/bin/env bash
# `scripts/pr.sh [gh pr create args…]`: open a pull request the way the gate wants one opened. It
# runs scripts/pr-check.sh (clean tree, HEAD pushed, a green full gate on this exact tree) and
# refuses if that fails. Otherwise it runs `gh pr create` with your arguments and appends to the
# body a "Verification" block: the summary lines of the gate that passed and the HEAD it passed
# on. No harness needed: a person or any agent runs it.
#
# The body is whatever you pass (--body/-b, --body-file/-F, `-` for stdin), then the block.
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
args=(); body=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --body | -b) body="${2-}"; shift 2 || shift ;;
    --body=*) body="${1#--body=}"; shift ;;
    --body-file | -F) if [ "${2-}" = "-" ]; then body="$(cat)"; else body="$(cat "${2-}")" || exit 1; fi; shift 2 || shift ;;
    --body-file=*) body="$(cat "${1#--body-file=}")" || exit 1; shift ;;
    *) args+=("$1"); shift ;;
  esac
done
{ [ -n "$body" ] && printf '%s\n\n' "$body"; verification_block; } > "$tmp"
gh pr create ${args[@]+"${args[@]}"} --body-file "$tmp"
