#!/usr/bin/env bash
# The gate: one command whose exit code is the definition of done.
#
#   scripts/verify.sh [fast|full] [--check] [--no-ratchet]
#
#   fast        the inner loop: lint, typecheck, the quick tests, the determinism scans. Must
#               stay under about 60 s warm; the Stop hook runs it.
#   full        everything: fast, then coverage, build, e2e, the figures and the ratchet.
#   --check     CI: compare against verify-baseline.json but never write it.
#   --no-ratchet  skip the baseline comparison while iterating.
#   --allow-drop NAME --reason "category: why"   (full only, repeatable) record a reviewed drop
#               of a figure this run measured lower; the one way down (scripts/ratchet.py).
#
# It runs every check even after one fails and reports each on one line (✓/✗ name, detail,
# seconds), so a red run says everything that is wrong, not just the first thing. Each check's
# output goes to .verify/<name>.log and is printed in full when it fails. Every check writes
# .verify/checks/<name>.json (so a check's own report, e.g. .verify/tests.json, is never
# overwritten); the run writes .verify/summary.json and .verify/summary.txt. Exit 0 means
# an agent may say "done"; anything else means it keeps working.
#
# A green full run records the tree it verified (scripts/tree-fingerprint.sh --record-pass), so
# a Stop hook or `scripts/pr-check.sh` never re-runs the gate over a tree that just passed; a
# green fast run records a fast pass, which only the Stop hook accepts.
#
# CONFIGURE: edit preflight(), fast_checks(), full_checks() and figures() below. Nothing else
# should need to change. Keep the check names stable: the reports and the ratchet use them.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
ROOT="$(pwd -P)"
VERIFY_DIR="$ROOT/.verify"
# A toolchain pinned through mise is on PATH here even when the caller (a hook, a bare shell)
# never ran `mise activate`, so the gate and the hooks measure the same runtime.
if { [ -f mise.toml ] || [ -f .tool-versions ]; } && command -v mise >/dev/null 2>&1; then eval "$(mise env -s bash 2>/dev/null)"; fi

MODE=full; CHECK=0; RATCHET=1; DROPS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    fast|full) MODE="$1" ;;
    --check) CHECK=1 ;;
    --no-ratchet) RATCHET=0 ;;
    --allow-drop) DROPS+=(--allow-drop "${2:?--allow-drop needs a figure name}"); shift ;;
    --reason) DROPS+=(--reason "${2:?--reason needs text}"); shift ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "verify: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done
if [ "${#DROPS[@]}" -gt 0 ] && { [ "$MODE" != full ] || [ "$CHECK" = 1 ]; }; then
  echo "verify: --allow-drop is for a local full run only" >&2; exit 2
fi

# ── Output helpers ──────────────────────────────────────────────────────────────────────────
if [ -t 1 ]; then BOLD=$'\e[1m'; DIM=$'\e[2m'; GREEN=$'\e[32m'; RED=$'\e[31m'; BLUE=$'\e[34m'; RESET=$'\e[0m'
else BOLD=""; DIM=""; GREEN=""; RED=""; BLUE=""; RESET=""; fi
log() { printf '%s%s▸%s %s\n' "$BOLD" "$BLUE" "$RESET" "$*"; }
now_ms() { python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s000; }
json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'BEGIN{ORS="\\n"} {print}' | sed 's/\\n$//'; }

NAMES=(); OKS=(); DETAILS=(); MSS=()
record() { # record NAME OK DETAIL MS
  NAMES+=("$1"); OKS+=("$2"); DETAILS+=("$3"); MSS+=("$4")
  printf '{"gate": "%s", "ok": %s, "detail": "%s", "ms": %s}\n' "$1" "$2" "$(json_escape "$3")" "$4" > "$VERIFY_DIR/checks/$1.json"
}

# check NAME COMMAND [ARGS...]: run one check, capture its output, report one line.
# Set DETAIL_<NAME> (a function `detail_<name>` if defined) to put a figure on the line.
check() {
  local name="$1"; shift
  local started ended ms ok detail logf="$VERIFY_DIR/$1.log"
  logf="$VERIFY_DIR/$name.log"
  log "$name"
  started="$(now_ms)"
  if "$@" > "$logf" 2>&1; then ok=true; else ok=false; fi
  ended="$(now_ms)"; ms=$((ended - started))
  if declare -f "detail_$name" >/dev/null; then detail="$("detail_$name" "$ok" "$logf" 2>/dev/null)"; fi
  if [ "$ok" = true ]; then
    printf '%s✓%s %s %s(%s ms)%s\n' "$GREEN" "$RESET" "$name" "$DIM" "$ms" "$RESET"
    [ "$name" = ratchet ] && grep -E '^  ratchet:' "$logf"
  else
    printf '%s▼ %s failed (%s ms)%s\n' "$RED" "$name" "$ms" "$RESET"
    cat "$logf"
    printf '%s▲ %s%s\n' "$RED" "$name" "$RESET"
    detail="${detail:-see .verify/$name.log}"
  fi
  record "$name" "$ok" "${detail:-}" "$ms"
}

# need TOOL "how to install": collected by preflight, reported together.
PROBLEMS=()
need() { command -v "$1" >/dev/null 2>&1 || PROBLEMS+=("$1 is not on PATH — $2"); }
# need_port HOST PORT "how to start it": a service the checks talk to.
need_port() {
  (exec 3<>"/dev/tcp/$1/$2") 2>/dev/null || PROBLEMS+=("nothing answers at $1:$2 — $3")
}

# ── CONFIGURE ───────────────────────────────────────────────────────────────────────────────
# Everything the checks need, checked before anything runs, every problem named at once.
preflight() {
  need git "install git"
  # need node "run ./init.sh"
  # need_port 127.0.0.1 5432 "run \`docker compose up -d db\`"
  :
}

# The inner loop. Keep it under ~60 s warm. Each line: check <name> <command...>.
fast_checks() {
  # check lint npm run -s lint
  # check typecheck npm run -s typecheck
  # check tests npm test -s -- --reporter=json --outputFile=.verify/tests.json
  # POSIX ERE only (no \b \s \d: Apple's git grep has none; scan-gate.sh refuses them):
  # check no-markers scripts/scan-gate.sh no-markers '(^|[^[:alnum:]_])(TODO|FIXME)([^[:alnum:]_]|$)|\.(skip|only)[[:space:]]*\(' src test
  # check no-retries scripts/scan-gate.sh no-retries '(^|[^[:alnum:]_])(retry|retries)[[:space:]]*[:=(]' '*.config.*'
  # check max-lines scripts/max-lines.sh 400 src test
  :
}

# Everything else: coverage, build, e2e, dead code, duplication. Runs after fast_checks.
full_checks() {
  # check coverage npm test -s -- --coverage --reporter=json --outputFile=.verify/tests.json
  # check build npm run -s build
  :
}

# Write .verify/figures.json from the reports above: {"floors": {...}, "ceilings": {...}}.
# Floors may only rise (tests passed, coverage %); ceilings may only fall (markers, suppressions).
# scripts/figures.sh has helpers for vitest/jest JSON, JUnit XML, istanbul and lcov.
figures() {
  # scripts/figures.sh begin
  # scripts/figures.sh floor tests.total "$(scripts/figures.sh count-vitest .verify/tests.json)"
  # scripts/figures.sh floor coverage.lines "$(scripts/figures.sh coverage-istanbul .verify/coverage/coverage-summary.json lines)"
  # scripts/figures.sh ceiling markers "$(scripts/figures.sh count-problems .verify/no-markers.json)"
  # scripts/figures.sh end
  :
}
# ── END CONFIGURE ───────────────────────────────────────────────────────────────────────────

main() {
  preflight
  if [ "${#PROBLEMS[@]}" -gt 0 ]; then
    printf '%s✗ preflight%s\n' "$RED" "$RESET"
    for p in "${PROBLEMS[@]}"; do printf '  - %s\n' "$p"; done
    exit 1
  fi

  rm -rf "$VERIFY_DIR"; mkdir -p "$VERIFY_DIR/checks"
  local stamp=""
  if [ -x "$ROOT/scripts/tree-fingerprint.sh" ]; then
    stamp="$("$ROOT/scripts/tree-fingerprint.sh" 2>/dev/null)" || stamp=""
    [ -n "$stamp" ] && printf '%s\n' "$stamp" > "$VERIFY_DIR/tree-fingerprint"
  fi
  local run_started; run_started="$(now_ms)"

  fast_checks
  [ "$MODE" = full ] && full_checks
  # An unconfigured gate must not pass: no checks is a configuration error, not a green run.
  if [ "${#NAMES[@]}" -eq 0 ]; then
    echo "verify: no checks configured; edit fast_checks() and full_checks() in scripts/verify.sh" >&2
    exit 2
  fi

  local failed=0 i
  for i in "${!NAMES[@]}"; do [ "${OKS[$i]}" = true ] || failed=1; done

  if [ "$MODE" = full ] && [ "$RATCHET" = 1 ] && [ "$failed" = 0 ] && [ -f "$ROOT/scripts/ratchet.py" ]; then
    # figures() runs under set -e in a subshell: a figure that can't be read fails the gate
    # rather than recording a baseline without it.
    # Not inside `if (…)`: bash ignores set -e in an if condition, functions included.
    local started rc; started="$(now_ms)"
    ( set -e; figures ) > "$VERIFY_DIR/figures.log" 2>&1; rc=$?
    if [ "$rc" = 0 ]; then
      record figures true "$(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d["floors"]), "floors,", len(d["ceilings"]), "ceilings")' "$VERIFY_DIR/figures.json" 2>/dev/null || echo written)" "$(( $(now_ms) - started ))"
    else
      printf '%s▼ figures failed%s\n' "$RED" "$RESET"; cat "$VERIFY_DIR/figures.log"; printf '%s▲ figures%s\n' "$RED" "$RESET"
      record figures false "a figure could not be read; see .verify/figures.log" "$(( $(now_ms) - started ))"
      failed=1
    fi
  fi
  if [ "$MODE" = full ] && [ "$RATCHET" = 1 ] && [ "$failed" = 0 ] && [ -f "$ROOT/scripts/ratchet.py" ]; then
    local args=() now=""
    [ "$CHECK" = 1 ] && args+=(--check)
    args+=(${DROPS[@]+"${DROPS[@]}"})
    [ -x "$ROOT/scripts/tree-fingerprint.sh" ] && now="$("$ROOT/scripts/tree-fingerprint.sh" 2>/dev/null)"
    # ${args[@]+…}: bash 3.2 (macOS) calls an empty array unbound under set -u.
    check ratchet python3 -I "$ROOT/scripts/ratchet.py" --figures "$VERIFY_DIR/figures.json" --measured-on "${stamp:-}" --tree-now "${now:-}" ${args[@]+"${args[@]}"}
    [ "${OKS[${#OKS[@]}-1]}" = true ] || failed=1
  fi

  # ── Summary ───────────────────────────────────────────────────────────────────────────────
  local width=4 n
  for n in "${NAMES[@]}"; do [ "${#n}" -gt "$width" ] && width="${#n}"; done
  {
    for i in "${!NAMES[@]}"; do
      if [ "${OKS[$i]}" = true ]; then m="✓"; else m="✗"; fi
      printf '%s %-*s  %-28s %6.1fs\n' "$m" "$width" "${NAMES[$i]}" "${DETAILS[$i]}" "$(awk "BEGIN{print ${MSS[$i]}/1000}")"
    done
    printf 'exit %s\n' "$failed"
  } > "$VERIFY_DIR/summary.txt"
  echo
  sed -e "s/^✓/${GREEN}✓${RESET}/" -e "s/^✗/${RED}✗${RESET}/" "$VERIFY_DIR/summary.txt"
  {
    printf '{"mode": "%s", "check": %s, "ok": %s, "ms": %s, "fingerprint": "%s", "checks": [' "$MODE" "$([ "$CHECK" = 1 ] && echo true || echo false)" "$([ "$failed" = 0 ] && echo true || echo false)" "$(( $(now_ms) - run_started ))" "$stamp"
    for i in "${!NAMES[@]}"; do
      [ "$i" -gt 0 ] && printf ','
      printf '{"name": "%s", "ok": %s, "detail": "%s", "ms": %s}' "${NAMES[$i]}" "${OKS[$i]}" "$(json_escape "${DETAILS[$i]}")" "${MSS[$i]}"
    done
    printf '], "failed": ['
    local first=1
    for i in "${!NAMES[@]}"; do
      [ "${OKS[$i]}" = true ] && continue
      [ "$first" = 1 ] || printf ','; first=0
      printf '"%s"' "${NAMES[$i]}"
    done
    printf ']}\n'
  } > "$VERIFY_DIR/summary.json"

  if [ "$failed" = 0 ] && [ -n "$stamp" ] && [ -x "$ROOT/scripts/tree-fingerprint.sh" ]; then
    if [ "$MODE" = full ] && [ "$RATCHET" = 1 ]; then
      "$ROOT/scripts/tree-fingerprint.sh" --record-pass "$stamp" "$VERIFY_DIR/summary.txt"
    else
      "$ROOT/scripts/tree-fingerprint.sh" --record-fast-pass "$stamp"
    fi
  fi
  exit "$failed"
}

main
