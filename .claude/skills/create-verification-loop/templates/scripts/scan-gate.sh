#!/usr/bin/env bash
# A determinism gate that is a text scan: fail on any line matching PATTERN in the tracked
# files under PATHS. Writes .verify/NAME.json ({gate, ok, problems}) so the ratchet can count it.
#
#   scripts/scan-gate.sh NAME PATTERN [PATHSPEC...]
#
# Examples (the ones every repo wants):
#   scan-gate.sh no-markers '(^|[^[:alnum:]_])(TODO|FIXME)([^[:alnum:]_]|$)|\.(skip|only|todo)[[:space:]]*\(|@pytest\.mark\.skip|#\[ignore\]|[^[:alnum:]_]t\.Skip\(' src test
#   scan-gate.sh no-retries '(^|[^[:alnum:]_])(retry|retries|reruns|flaky)[[:space:]]*[:=(]|retryTimes\(|--(retry|retries|reruns)([^[:alnum:]_]|$)' '*.config.*' 'package.json' 'pytest.ini' 'pyproject.toml' '.github/workflows'
#   scan-gate.sh no-sleeps 'time\.sleep\(|Thread\.sleep\(|setTimeout\([^,]*,[[:space:]]*[0-9]{3,}' test tests
#
# PATTERN is a POSIX extended regex (git grep -E). Never use \b, \s or \d: Apple's git on macOS
# links the system regex library, where \b matches nothing, so a scan written with it passes
# everything there and fails only on Linux. Write (^|[^[:alnum:]_]) and ([^[:alnum:]_]|$) for
# word edges, [[:space:]] and [0-9] for classes. This script refuses a pattern holding \b, \s,
# \d or \w (exit 2) so the mistake cannot pass silently. PATHSPEC follows git's rules; an exclusion is
# ':(exclude)path'. Untracked files are scanned too (a new test with .skip must not pass by being
# new). This script's own file is always excluded, and so is anything under node_modules.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
name="${1:?name}"; pattern="${2:?pattern}"; shift 2
case "$pattern" in *'\b'*|*'\s'*|*'\d'*|*'\w'*)
  echo "✗ $name: the pattern uses \\b, \\s, \\d or \\w, which Apple's git grep does not support (the scan would pass everything on macOS). Use (^|[^[:alnum:]_]) / ([^[:alnum:]_]|$), [[:space:]] and [0-9]." >&2
  exit 2 ;;
esac
mkdir -p .verify
self="scripts/$(basename "${BASH_SOURCE[0]}")"
hits="$(git grep --untracked -nE "$pattern" -- "$@" ":(exclude)$self" ':(exclude,glob)**/node_modules/**' ':(exclude)verify-baseline.json' 2>/dev/null | head -200)"
{
  printf '{"gate": "%s", "ok": %s, "problems": [' "$name" "$([ -z "$hits" ] && echo true || echo false)"
  first=1
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ "$first" = 1 ] || printf ','; first=0
    printf '"%s"' "$(printf '%s' "$line" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/ /g')"
  done <<< "$hits"
  printf ']}\n'
} > ".verify/$name.json"
if [ -n "$hits" ]; then
  echo "✗ $name: $(printf '%s\n' "$hits" | wc -l | tr -d ' ') line(s) match /$pattern/" >&2
  printf '%s\n' "$hits" | head -50 >&2
  exit 1
fi
echo "✓ $name"
