#!/usr/bin/env bash
# No source or test file over LIMIT lines. A file doing several jobs looks big from outside;
# the limit is a stand-in for single responsibility that a tool can check.
#
#   scripts/max-lines.sh LIMIT [PATHSPEC...]      e.g. max-lines.sh 400 src test
#
# Writes .verify/max-lines.json. Untracked files count too. Generated files and vendored code should be excluded by
# pathspec (':(exclude)src/generated/**').
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
limit="${1:?limit}"; shift
mkdir -p .verify
problems=()
while IFS= read -r file; do
  [ -f "$file" ] || continue
  case "$file" in *.lock|*.min.*|*.svg|*.json|*.md) continue ;; esac
  n="$(wc -l < "$file" | tr -d ' ')"
  [ "$n" -gt "$limit" ] && problems+=("$file: $n lines (max $limit)")
done < <(git ls-files --cached --others --exclude-standard -- "$@" ':(exclude,glob)**/node_modules/**')
{
  printf '{"gate": "max-lines", "ok": %s, "limit": %s, "problems": [' "$([ "${#problems[@]}" -eq 0 ] && echo true || echo false)" "$limit"
  for i in "${!problems[@]}"; do [ "$i" -gt 0 ] && printf ','; printf '"%s"' "${problems[$i]}"; done
  printf ']}\n'
} > .verify/max-lines.json
if [ "${#problems[@]}" -gt 0 ]; then
  echo "✗ max-lines: ${#problems[@]} file(s) over $limit lines" >&2
  printf '  %s\n' "${problems[@]}" >&2
  exit 1
fi
echo "✓ max-lines"
