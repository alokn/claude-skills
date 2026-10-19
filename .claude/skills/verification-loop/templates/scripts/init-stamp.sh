#!/usr/bin/env bash
# The init stamp: a hash of the toolchain pin files, written by init.sh when setup finished and
# read by the init guard. Lives in the git dir, per worktree, never committed.
#
#   scripts/init-stamp.sh --write     after a successful init
#   scripts/init-stamp.sh --state     prints missing | stale | ok
#   scripts/init-stamp.sh --check     exit 0 only when ok
#
# CONFIGURE: PIN_FILES, the files whose change means "run init.sh again".
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
PIN_FILES=(mise.toml .tool-versions .nvmrc .node-version .python-version .ruby-version rust-toolchain.toml package.json pyproject.toml go.mod Cargo.toml Gemfile)

path() { printf '%s/verify-loop/init.stamp\n' "$(git rev-parse --git-dir)"; }
current() {
  local f present=()
  for f in "${PIN_FILES[@]}"; do [ -f "$f" ] && present+=("$f"); done
  [ "${#present[@]}" -gt 0 ] || { echo none; return; }
  cat "${present[@]}" | shasum -a 256 | cut -d' ' -f1
}
state() {
  local p; p="$(path)"
  if [ ! -f "$p" ]; then echo missing
  elif [ "$(cat "$p")" != "$(current)" ]; then echo stale
  else echo ok; fi
}
case "${1:-}" in
  --write) mkdir -p "$(dirname "$(path)")" && current > "$(path)" ;;
  --state) state ;;
  --check) [ "$(state)" = ok ] ;;
  *) echo "usage: init-stamp.sh --write | --state | --check" >&2; exit 2 ;;
esac
