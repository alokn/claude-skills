#!/usr/bin/env bash
# The tree fingerprint: one SHA-256 over every input that decides whether a verify is owed, and
# the record of the last tree that passed. Its one definition; the gate, the Stop hook and the
# PR check all read it.
#
#   scripts/tree-fingerprint.sh                  print the fingerprint; exit 1 with no output when
#                                                it can't be taken (fail closed: no hash of nothing)
#   scripts/tree-fingerprint.sh --record-pass F [SUMMARY-FILE]
#                                                a full gate passed tree F: recorded only if the
#                                                tree still has fingerprint F now (an edit made
#                                                during the run was never verified)
#   scripts/tree-fingerprint.sh --last-pass      the recorded fingerprint, or nothing
#   scripts/tree-fingerprint.sh --last-pass-summary   the summary kept with it, only while it
#                                                belongs to the current tree
#   scripts/tree-fingerprint.sh --record-fast-pass F / --last-fast-pass
#                                                the same for the fast tier. Kept apart so a fast
#                                                pass can never satisfy a check that asks for a
#                                                full one (the PR check reads last-pass only).
#   source scripts/tree-fingerprint.sh           define the functions only (the hooks do this)
#
# What is hashed: the blob list of everything git would commit under FINGERPRINT_PATHS (tracked,
# untracked and deleted files, .gitignore respected, the real index untouched), plus
# machine_inputs: the machine-local things that change what the gate does (an env file's hash,
# the toolchain's version). Contents, not filenames, and contents only, not HEAD: committing a
# tree that just passed must not make it look new.
#
# Records live in $GIT_DIR/verify-loop/, per worktree, never committed, never pruned (each pass
# overwrites one file, and a stale value matches nothing).
#
# CONFIGURE: FINGERPRINT_PATHS (what to exclude) and machine_inputs() below.

FINGERPRINT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The pinned toolchain, so a hook and the gate measure the same runtime version.
if { [ -f "$FINGERPRINT_ROOT/mise.toml" ] || [ -f "$FINGERPRINT_ROOT/.tool-versions" ]; } && command -v mise >/dev/null 2>&1; then
  eval "$(cd "$FINGERPRINT_ROOT" && mise env -s bash 2>/dev/null)"
fi

# Everything, minus what the gate writes or never reads. Each exclusion starts with a glob so
# that `git add` never fails on an ignored literal prefix.
FINGERPRINT_PATHS=(
  .
  ':(exclude)verify-baseline.json'          # the ratchet's own write
  ':(exclude,glob)**/.verify/**'            # the gate's reports
  ':(exclude,glob)**/*.md'                  # prose: a docs edit costs no verify (drop this line if a test reads docs)
  ':(exclude,glob)**/.claude/worktrees/**'  # nested agent checkouts
  ':(exclude,glob)**/.claude/settings.local.json'
  # Runtime state a framework tracks but the gate rewrites: without these no run could ever
  # match the fingerprint it began with. Rails: tmp/, log/, storage/, db/*.sqlite3*; Django:
  # db.sqlite3; add the repo's own (the interview lists tracked runtime state).
  # ':(exclude,glob)tmp/**' ':(exclude,glob)log/**' ':(exclude,glob)storage/**' ':(exclude,glob)**/*.sqlite3*'
)

# One line per machine-local input, or `absent`. Something present but unmeasurable fails the
# whole fingerprint (return 1), so nothing is silently dropped. Add the files and tools the
# gate depends on: an env file, the lockfile's install marker, the runtime's version.
machine_inputs() {
  file_state .env &&
    tool_version node   # the runtime the gate runs on: node, python3, ruby, go, cargo, php, java
}

file_state() {
  local sum
  if [ ! -e "$1" ] && [ ! -L "$1" ]; then printf '%s absent\n' "$1"; return 0; fi
  sum="$(shasum -a 256 < "$1" 2>/dev/null)" || return 1
  printf '%s %s\n' "$1" "${sum%% *}"
}

tool_version() {
  local v
  command -v "$1" >/dev/null 2>&1 || { printf '%s absent\n' "$1"; return 0; }
  v="$("$1" --version 2>&1 | head -n 1)" || return 1
  [ -n "$v" ] || return 1
  printf '%s %s\n' "$1" "$v"
}

fingerprint() {
  local real dir listed status machine
  real="$(git rev-parse --git-path index 2>/dev/null)" || return 1
  dir="$(mktemp -d)" || return 1
  # cp -p keeps the index's mtime so git re-hashes racily-clean entries and trusts the rest.
  if [ -f "$real" ]; then cp -p "$real" "$dir/index" || { rm -rf "$dir"; return 1; }; fi
  listed="$(GIT_INDEX_FILE="$dir/index" git add -A -- "${FINGERPRINT_PATHS[@]}" 2>/dev/null &&
    GIT_INDEX_FILE="$dir/index" git ls-files -s -- "${FINGERPRINT_PATHS[@]}" 2>/dev/null)"
  status=$?
  rm -rf "$dir"
  [ "$status" -eq 0 ] && [ -n "$listed" ] || return 1
  machine="$(cd "$FINGERPRINT_ROOT" && machine_inputs)" || return 1
  printf '%s\n%s\n' "$listed" "$machine" | shasum -a 256 | cut -d' ' -f1
}

pass_dir() {
  local gitdir
  gitdir="$(git rev-parse --git-dir 2>/dev/null)" || return 1
  printf '%s/verify-loop\n' "$gitdir"
}

# record_as NAME F: write F to the record NAME if the tree still has fingerprint F. Always 0.
record_as() {
  local name="$1" dir now tmp
  [ -n "${2:-}" ] || return 0
  now="$(fingerprint)" || return 0
  [ "$now" = "$2" ] || return 0
  dir="$(pass_dir)" || return 0
  mkdir -p "$dir" 2>/dev/null || return 0
  tmp="$(mktemp "$dir/.$name.XXXXXX" 2>/dev/null)" || return 0
  if printf '%s\n' "$2" > "$tmp" 2>/dev/null && mv -f "$tmp" "$dir/$name" 2>/dev/null; then :; else rm -f "$tmp"; fi
  return 0
}

read_record() {
  local dir
  dir="$(pass_dir)" || return 0
  cat "$dir/$1" 2>/dev/null || true
}

record_pass() {
  local dir
  record_as last-pass "${1:-}"
  [ -n "${2:-}" ] && [ -f "$2" ] && [ "$(last_pass)" = "${1:-}" ] || return 0
  dir="$(pass_dir)" || return 0
  {
    printf 'head %s\n' "$(git rev-parse HEAD 2>/dev/null)"
    printf 'fingerprint %s\n' "$1"
    cat "$2"
  } > "$dir/.summary.$$" 2>/dev/null && mv -f "$dir/.summary.$$" "$dir/last-pass-summary" 2>/dev/null || rm -f "$dir/.summary.$$"
  return 0
}
last_pass() { read_record last-pass; }
last_pass_summary() {
  local record
  record="$(read_record last-pass-summary)"
  case "$record" in *$'\nfingerprint '"${1:-}"$'\n'*) printf '%s\n' "$record" ;; esac
  return 0
}
record_fast_pass() { record_as last-fast-pass "${1:-}"; }
last_fast_pass() { read_record last-fast-pass; }

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  cd "$FINGERPRINT_ROOT" || exit 1
  case "${1:-}" in
    --record-pass) record_pass "${2:-}" "${3:-}"; exit 0 ;;
    --last-pass) last_pass; exit 0 ;;
    --last-pass-summary) last_pass_summary "$(fingerprint)"; exit 0 ;;
    --record-fast-pass) record_fast_pass "${2:-}"; exit 0 ;;
    --last-fast-pass) last_fast_pass; exit 0 ;;
    '') fingerprint || exit 1 ;;
    *) echo "usage: tree-fingerprint.sh [--record-pass F [SUMMARY] | --last-pass | --last-pass-summary | --record-fast-pass F | --last-fast-pass]" >&2; exit 2 ;;
  esac
fi
