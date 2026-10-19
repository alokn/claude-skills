#!/usr/bin/env bash
# One script: clean clone -> green gate. Idempotent: every step is safe to run again. Run it
# first, once per worktree; never install the toolchain or dependencies by hand (the Claude Code
# init guard refuses until this has stamped the worktree).
#
#   ./init.sh [--skip-verify] [--fast] [--yes]
#     --skip-verify   stop once the checkout is set up; don't run the gate
#     --fast          run the fast tier instead of the full gate
#     --yes           accept anything this script would ask a person (adding a shell rc line)
#
# Unattended-safe: no step waits on a prompt nobody can answer. Anything that needs a person
# (sudo, a GUI installer) is reported in one line with the command to run, and the script stops.
#
# CONFIGURE: sections 1-6. Keep the shape: preflight collects every missing thing before failing.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

SKIP_VERIFY=0; FAST=0; YES=0
for arg in "$@"; do
  case "$arg" in
    --skip-verify) SKIP_VERIFY=1 ;;
    --fast) FAST=1 ;;
    --yes) YES=1 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done
# Sections that would ask a person (a shell rc line, a system package) read this first.
export INIT_ASSUME_YES="$YES"
log() { printf '\033[1m\033[34m▸\033[0m %s\n' "$*"; }

# ── 1. Preflight: every hard requirement, reported together ──────────────────────────────
log preflight
missing=()
command -v git >/dev/null 2>&1 || missing+=("git")
{ [ -f mise.toml ] || [ -f .tool-versions ]; } && { command -v curl >/dev/null 2>&1 || missing+=("curl (to install mise)"); }
# command -v docker >/dev/null 2>&1 || missing+=("docker (https://docker.com)")
if [ "${#missing[@]}" -gt 0 ]; then
  echo "missing required tools:" >&2; printf '  - %s\n' "${missing[@]}" >&2; exit 1
fi

# ── 2. Toolchain: pinned, installed through the pin file, never "whatever is on PATH" ────
log toolchain
if [ -f mise.toml ] || [ -f .tool-versions ]; then
  if ! command -v mise >/dev/null 2>&1; then
    log "mise not found — installing (https://mise.run)"
    curl -fsSL https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
  mise trust --quiet . 2>/dev/null || true
  mise install
  eval "$(mise env -s bash)"   # reaches this process only; a new terminal needs `mise activate` in its rc
fi
# uv repos: `uv python install` reads .python-version; the venv is made by `uv sync` below.
# Else: check the pinned version exactly and fail in one line naming it, e.g.
# want="$(cut -d. -f1 .nvmrc)"; [ "$(node -v | sed -E 's/^v([0-9]+).*/\1/')" = "$want" ] || { echo "Node $want is required (.nvmrc); found $(node -v)" >&2; exit 1; }

# ── 3. Env file: created from the example, never overwritten ─────────────────────────────
# [ -f .env ] || cp .env.example .env

# ── 4. Dependencies: from the lockfile, exactly ───────────────────────────────────────────
log "installing dependencies"
# npm ci                       # node
# pnpm install --frozen-lockfile
# uv sync --frozen             # python
# bundle install               # ruby
# go mod download              # go
# cargo fetch                  # rust

# ── 5. Services, migrate, seed: idempotent, with a bounded wait for readiness ─────────────
# docker compose up -d db
# for _ in $(seq 1 30); do (exec 3<>/dev/tcp/127.0.0.1/5432) 2>/dev/null && break; sleep 1; done
# npm run db:migrate && npm run db:seed

# ── 6. Stamp: before the gate, so --skip-verify stamps too; set -e means a failed step never does
scripts/init-stamp.sh --write

# ── 7. The gate ───────────────────────────────────────────────────────────────────────────
status="skipped (--skip-verify)"
if [ "$SKIP_VERIFY" = 1 ]; then
  log "--skip-verify: stopping before the gate"
elif [ "$FAST" = 1 ]; then
  scripts/verify.sh fast; status="passed (fast)"
else
  log "running the full gate; its exit code is the definition of done"
  scripts/verify.sh full; status="passed (full)"
fi

# ── 8. Banner: what to run next, printed on every successful path ─────────────────────────
cat <<EOF

ready. gate: $status
  scripts/verify.sh fast     the inner loop
  scripts/verify.sh full     the definition of done
  AGENTS.md                  the rules; CLAUDE.md for Claude Code's hooks
EOF
