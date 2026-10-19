#!/usr/bin/env bash
# Helpers that turn test and coverage reports into the figures the ratchet holds. Used from
# verify.sh's figures(): `begin`, then one `floor`/`ceiling` line per figure, then `end`.
#
#   figures.sh begin                              start .verify/figures.json
#   figures.sh floor NAME VALUE                   a figure that may only rise
#   figures.sh ceiling NAME VALUE                 a figure that may only fall
#   figures.sh end                                finish the file
#
#   figures.sh count-vitest FILE                  passed tests in a vitest/jest JSON report
#   figures.sh count-junit FILE                   passed tests in a JUnit XML report (pytest, go, maven, rspec)
#   figures.sh count-go FILE                      passed tests in `go test -json` output
#   figures.sh count-cargo FILE                   passed tests in `cargo test` output
#   figures.sh count-pytest FILE                  passed tests from pytest's last summary line
#   figures.sh count-minitest FILE                passed tests from minitest's summary line (bin/rails test output)
#
#   Any other runner, without touching this file (the two generic readers):
#   figures.sh count-regex FILE ERE               sum of the first capture group over every match in FILE,
#                                                 e.g. count-regex out.txt '([0-9]+) passed' / '([0-9]+) examples, 0 failures'
#   figures.sh pct-regex FILE ERE                 the first capture group of the LAST match, as a number,
#                                                 e.g. pct-regex cov.txt 'TOTAL.* ([0-9.]+)%' / 'Lines: *([0-9.]+)%'
#   figures.sh coverage-istanbul FILE lines|branches|statements|functions   % from coverage-summary.json
#   figures.sh coverage-lcov FILE                 line % from an lcov.info
#   figures.sh coverage-cobertura FILE            line % from a cobertura XML (coverage.py, go, jacoco)
#   figures.sh coverage-pytest FILE               TOTAL % from `coverage report` text output
#   figures.sh count-problems FILE                `problems` entries in a scan-gate JSON report
#
# Every number is printed on its own line; a report that can't be read prints nothing and exits 1,
# and `floor`/`ceiling` refuse an empty value, so verify.sh's figures step (run under set -e) fails
# the gate rather than recording a baseline without the figure.
set -uo pipefail
OUT="${VERIFY_DIR:-.verify}/figures.json"
py() { python3 -I -c "$1" "${@:2}"; }

case "${1:-}" in
  begin) printf '{"floors": {}, "ceilings": {}}\n' > "$OUT" ;;
  floor|ceiling)
    [ -n "${3:-}" ] || { echo "figures: $2 has no value" >&2; exit 1; }
    kind="$([ "$1" = floor ] && echo floors || echo ceilings)"
    py 'import json,sys; p,k,n,v=sys.argv[1:5]; d=json.load(open(p)); d[k][n]=float(v); json.dump(d,open(p,"w"),indent=2)' "$OUT" "$kind" "$2" "$3" ;;
  end) py 'import json,sys; d=json.load(open(sys.argv[1])); assert d["floors"] or d["ceilings"], "no figures"' "$OUT" ;;
  count-vitest) py 'import json,sys; d=json.load(open(sys.argv[1])); print(d["numPassedTests"])' "$2" ;;
  count-junit) py '
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
suites = [root] if root.tag == "testsuite" else root.iter("testsuite")
passed = 0
for s in suites:
    for c in s.iter("testcase"):
        if not any(ch.tag in ("failure", "error", "skipped") for ch in c): passed += 1
print(passed)' "$2" ;;
  count-go) py '
import json,sys
n=0
for line in open(sys.argv[1]):
    try: e=json.loads(line)
    except ValueError: continue
    if e.get("Action")=="pass" and e.get("Test"): n+=1
print(n)' "$2" ;;
  count-cargo) py '
import re,sys
total=0
for m in re.finditer(r"test result: \w+\. (\d+) passed", open(sys.argv[1]).read()): total+=int(m.group(1))
print(total)' "$2" ;;
  count-pytest) py '
import re,sys
m=re.findall(r"(\d+) passed", open(sys.argv[1]).read())
print(sum(int(x) for x in m))' "$2" ;;
  count-minitest) py '
import re,sys
m=re.findall(r"(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips", open(sys.argv[1]).read())
if not m: sys.exit(1)
r,a,f,e,s=map(int,m[-1]); print(r-f-e-s)' "$2" ;;
  count-regex) py '
import re,sys
m=re.findall(sys.argv[2], open(sys.argv[1], errors="replace").read())
if not m: sys.exit(1)
print(sum(int(x if isinstance(x,str) else x[0]) for x in m))' "$2" "${3:?regex}" ;;
  pct-regex) py '
import re,sys
m=re.findall(sys.argv[2], open(sys.argv[1], errors="replace").read())
if not m: sys.exit(1)
x=m[-1]; print(float(x if isinstance(x,str) else x[0]))' "$2" "${3:?regex}" ;;
  coverage-istanbul) py 'import json,sys; print(json.load(open(sys.argv[1]))["total"][sys.argv[2]]["pct"])' "$2" "${3:-lines}" ;;
  coverage-lcov) py '
import sys
found=hit=0
for line in open(sys.argv[1]):
    if line.startswith("LF:"): found+=int(line[3:])
    elif line.startswith("LH:"): hit+=int(line[3:])
print(round(100*hit/found,2) if found else 0)' "$2" ;;
  coverage-cobertura) py 'import sys,xml.etree.ElementTree as ET; print(round(100*float(ET.parse(sys.argv[1]).getroot().get("line-rate")),2))' "$2" ;;
  coverage-pytest) py '
import re,sys
m=re.search(r"^TOTAL\s+.*?(\d+(?:\.\d+)?)%\s*$", open(sys.argv[1]).read(), re.M)
print(m.group(1)) if m else sys.exit(1)' "$2" ;;
  count-problems) py 'import json,sys; print(len(json.load(open(sys.argv[1])).get("problems", [])))' "$2" ;;
  *) sed -n '2,24p' "$0"; exit 2 ;;
esac
