#!/usr/bin/env bash
# The check between a branch and a pull request: has the full gate passed the tree this PR would
# carry? Shared by the Claude Code hook (.claude/hooks/pr-guard.sh) and `scripts/pr.sh`, so a
# person, an agent and any other harness are held to one rule. Exit 0 when all three hold, else 1
# with every problem named, each with the command that fixes it:
#
#   1. the tree is clean for FINGERPRINT_PATHS (a matching fingerprint must not cover files the
#      PR won't carry);
#   2. HEAD is on a remote branch of the same name;
#   3. last-pass, the record of a green full gate, equals the tree's fingerprint now. A fast pass
#      (the Stop hook's) is never read.
#
# Client-side only: `gh api`, another harness or `--no-verify` skip it. It makes the full gate the
# default path; branch protection and CI are the guarantee.
#
#   scripts/pr-check.sh [DIR]     judge the checkout DIR is in (default: the current one)
set -uo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "${1:-}" ]; then cd "$1" || exit 1; fi
top="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Not inside a git checkout." >&2; exit 1; }
cd "$top" || exit 1
source "$SELF/tree-fingerprint.sh"

GATE="${VERIFY_LOOP_FULL_CMD:-scripts/verify.sh full}"
problems=()
dirty="$(git status --porcelain -- "${FINGERPRINT_PATHS[@]}" 2>/dev/null)"
if [ -n "$dirty" ]; then
  problems+=("The tree has uncommitted changes to files the gate reads, which the PR would not carry:
$(printf '%s\n' "$dirty" | head -n 10 | sed 's/^/    /')
  Commit them, then run \`$GATE\`.")
fi
branch="$(git symbolic-ref --short -q HEAD)" || branch=""
pushed=""
if [ -n "$branch" ]; then
  while IFS= read -r ref; do case "$ref" in */"$branch") pushed=1 ;; esac
  done < <(git for-each-ref --contains HEAD --format='%(refname)' refs/remotes 2>/dev/null)
fi
if [ -z "$pushed" ]; then
  if [ -z "$(git remote 2>/dev/null)" ]; then
    problems+=("This checkout has no remote, so nothing can be pushed or reviewed. Add one (\`git remote add origin <url>\`), then push.")
  else
    problems+=("HEAD is not pushed. Run \`git push -u origin ${branch:-<branch>}\`.")
  fi
fi
now="$(fingerprint)" || now=""
if [ -z "$now" ] || [ "$(last_pass)" != "$now" ]; then
  problems+=("No full gate has passed this exact tree (a Stop-hook fast pass does not count). Run \`$GATE\`, then try again.")
fi
[ "${#problems[@]}" -eq 0 ] && exit 0
{
  echo "Refused: a PR needs a green full gate on the pushed, committed tree."
  for p in "${problems[@]}"; do printf -- '- %s\n' "$p"; done
} >&2
exit 1
