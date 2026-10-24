#!/usr/bin/env bash
# Claude Code hook: a `gh pr create`, or a `gh pr edit` that sets the body, takes its body from
# `--body-file <path>`, and that file fills .github/pull_request_template.md (scripts/pr-body.py).
# PreToolUse on Bash: exit 2 (block) with what is missing on stderr, so the agent hears it before
# the PR exists, not one CI round later. An inline --body, --fill, --web, an editor or stdin is
# refused: none of them can be checked first. A git hook can't do this: a PR body is not in git.
# CI's `pr body` job is the backstop (the web UI, a person without this hook, an edit afterwards).
#
# The base is `--base`, else the PR's own for an edit (`gh pr view`), else origin's default
# branch. A `cd <literal path>` before the command is followed; one that can't be read blocks.
#
# By hand:
#   echo '{"cwd":"'"$PWD"'","tool_input":{"command":"gh pr create --title x --body \"y\""}}' | .claude/hooks/pr-body.sh; echo "exit=$?"
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib/command-parse.sh"

block() { printf 'pr body: %s\n' "$1" >&2; exit 2; }

# shellcheck disable=SC2034  # payload and cmd are read and set by command-parse.sh
IFS= read -r -d '' payload || true
payload_command || exit 0
pre='(^|[^[:alnum:]_-])'
gh_flags='([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*'
pr_re="${pre}gh${gh_flags}[[:space:]]+pr[[:space:]]+(create|new|edit)([[:space:]]|$)"
# shellcheck disable=SC2154  # cmd: the command with quoted strings and heredoc bodies stripped
[[ $cmd =~ $pr_re ]] || exit 0
verb="${BASH_REMATCH[4]}"

# The arguments, from the unstripped command: the words after `gh … pr <verb>` up to ; & | or a newline.
# shellcheck disable=SC2154
[[ $raw_cmd =~ $pr_re ]] || exit 0
before="${raw_cmd%%"${BASH_REMATCH[0]}"*}"
rest="${raw_cmd#*"${BASH_REMATCH[0]}"}"
word="(\"([^\"\\\\]|\\\\.)*\"|'[^']*'|[^[:space:]\"';&|]+)"
unquote() { local p="$1"; p="${p#[\"\']}"; printf '%s' "${p%[\"\']}"; }
tokens=()
while [[ $rest =~ ^[[:blank:]]*$word ]]; do
  tokens+=("$(unquote "${BASH_REMATCH[1]}")")
  rest="${rest:${#BASH_REMATCH[0]}}"
done

body_file="" inline="" base="" selector=""
for ((i = 0; i < ${#tokens[@]}; i++)); do
  t="${tokens[$i]}"
  case "$t" in
    --body-file=*) body_file="${t#--body-file=}" ;;
    --body-file | -F) body_file="${tokens[$((i + 1))]:-}"; i=$((i + 1)) ;;
    --body=* | -b?*) inline=1 ;;
    --body | -b) inline=1; i=$((i + 1)) ;;
    --base=*) base="${t#--base=}" ;;
    --base | -B) base="${tokens[$((i + 1))]:-}"; i=$((i + 1)) ;;
    --fill | --fill-first | --fill-verbose | --web | -w | --draft | -d | --dry-run | --no-maintainer-edit | -f) ;;
    --*=*) ;;
    -*) i=$((i + 1)) ;;  # every other flag takes a value
    *) [ -n "$selector" ] || selector="$t" ;;
  esac
done
# The directory it runs in: the payload's cwd, then the last `cd`/`pushd` before it.
dir="$(payload_field cwd)" || dir="$PWD"
cd_re="(^|[;&|(])[[:space:]]*(cd|pushd)[[:space:]]+${word}"
while [[ $before =~ $cd_re ]]; do
  to="$(unquote "${BASH_REMATCH[3]}")"
  before="${before#*"${BASH_REMATCH[0]}"}"
  case "$to" in
    *[\$\`]*) block "can't tell which checkout this runs in (cd $to). Use a literal path: \`cd <dir> && gh pr $verb …\`." ;;
    \~*) dir="$HOME${to#\~}" ;;
    /*) dir="$to" ;;
    *) dir="$dir/$to" ;;
  esac
done
top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -f "$top/scripts/pr-body.py" ] || exit 0
[ "$verb" = edit ] && [ -z "$body_file" ] && [ -z "$inline" ] && exit 0
[ -z "$inline" ] || block "an inline --body is not checked. Write the body to a file that fills .github/pull_request_template.md and pass \`--body-file <path>\`."
[ -n "$body_file" ] && [ "$body_file" != - ] ||
  block "\`gh pr $verb\` needs its body from a file: write it to fill .github/pull_request_template.md and pass \`--body-file <path>\` (not --fill, --web, an editor or stdin)."

case "$body_file" in /*) file="$body_file" ;; \~*) file="$HOME${body_file#\~}" ;; *) file="$dir/$body_file" ;; esac
[ -f "$file" ] || block "can't read the body file \`$body_file\`: name a file that exists, by a literal path."

if [ -z "$base" ] && [ "$verb" = edit ]; then
  base="$(cd "$dir" && gh pr view ${selector:+"$selector"} --json baseRefName -q .baseRefName 2>/dev/null)" ||
    block "can't tell this PR's base: pass \`--base <branch>\` (its current base changes nothing)."
fi
[ -n "$base" ] || base="$(git -C "$top" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"
base="${base#origin/}"; base="${base:-main}"
git -C "$top" rev-parse --verify -q "refs/remotes/origin/$base^{commit}" >/dev/null ||
  block "origin/$base does not resolve. Run \`git fetch origin\` and try again."

out="$(cd "$top" && python3 -I scripts/pr-body.py --body-file "$file" --base "origin/$base" 2>&1)" ||
  block "the body in $body_file does not pass (against origin/$base):
$out
Fix the file and run the command again."
exit 0
