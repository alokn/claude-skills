#!/usr/bin/env bash
# Claude Code hook: a worktree is set up by ./init.sh, never by a hand-run install.
#
# An agent in a fresh worktree tends to run the package manager itself, which skips the pinned
# toolchain, the env file, the services and the seed. init.sh ends by writing a stamp (a hash of
# the toolchain pin files, scripts/init-stamp.sh --write), and this hook refuses an install until
# that stamp exists and matches.
#
#   (default)         PreToolUse on Bash: exit 2 (block) on an install while the stamp is missing
#                     or stale
#   --session-start   print the same instruction into the session's context, or nothing
#
# The checkout judged is the one the payload's cwd is in, so a subagent in its own worktree is
# judged by its own stamp. No jq or node: the payload is matched raw.
#
# By hand:
#   echo '{"cwd":"'"$PWD"'","tool_name":"Bash","tool_input":{"command":"npm install"}}' | .claude/hooks/init-guard.sh; echo "exit=$?"
#
# CONFIGURE: INSTALL_RE (the installs this ecosystem has).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 0
source scripts/lib/command-parse.sh

# shellcheck disable=SC2034  # payload and cmd are read and set by command-parse.sh
IFS= read -r -d '' payload || true

pre='(^|[^[:alnum:]_./-])'
post='([^[:alnum:]_-]|$)'
flags='([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*'
# Keep the alternatives for this repo's ecosystem; drop the rest.
INSTALL_RE="${pre}((pnpm|npm|yarn|bun)${flags}[[:space:]]+(install|i|ci|add|update|up)|pip3?[[:space:]]+install|uv[[:space:]]+(sync|pip[[:space:]]+install|add)|poetry[[:space:]]+(install|add)|pipenv[[:space:]]+(install|sync)|bundle[[:space:]]+(install|add)|cargo[[:space:]]+(add|fetch)|go[[:space:]]+mod[[:space:]]+(download|tidy)|composer[[:space:]]+(install|require)|mix[[:space:]]+deps\.get|playwright[[:space:]]+install|mise[[:space:]]+install)${post}"

stamp_state() { # missing | stale | ok, for checkout $1; nothing for a checkout of another repo
  ( cd "$1" && [ -x scripts/init-stamp.sh ] || exit 0; scripts/init-stamp.sh --state )
}

if [ "${1:-}" = "--session-start" ]; then
  checkout="$(target_checkout)" || exit 0
  case "$(stamp_state "$checkout")" in
    missing) echo "The worktree at $checkout has not run ./init.sh. Run \`./init.sh --skip-verify\` there before installing anything; never install dependencies by hand." ;;
    stale) echo "A toolchain pin changed since ./init.sh last ran in $checkout. Run \`./init.sh --skip-verify\` there again before installing anything." ;;
  esac
  exit 0
fi

payload_command || exit 0
# shellcheck disable=SC2154
[[ $cmd =~ /init\.sh${post} ]] && exit 0
[[ $cmd =~ $INSTALL_RE ]] || exit 0

checkout="$(target_checkout)" || exit 0
case "$(stamp_state "$checkout")" in
  missing)
    echo "Blocked: the worktree at $checkout has not run ./init.sh, so it has no pinned toolchain, env file or services. Run \`./init.sh --skip-verify\` there instead (idempotent; drop the flag to also run the gate). Do not install dependencies by hand." >&2
    exit 2 ;;
  stale)
    echo "Blocked: a toolchain pin changed since ./init.sh last ran in $checkout, so what is installed may be wrong. Run \`./init.sh --skip-verify\` there again. Do not install dependencies by hand." >&2
    exit 2 ;;
esac
exit 0
