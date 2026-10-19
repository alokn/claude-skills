#!/usr/bin/env python3
"""The ratchet: every figure may only improve.

    python3 -I scripts/ratchet.py --figures .verify/figures.json [--check]
        [--measured-on FINGERPRINT --tree-now FINGERPRINT]
        [--allow-drop NAME --reason "category: why"]... [--baseline verify-baseline.json]

Figures come from the run that just finished (scripts/verify.sh writes .verify/figures.json):

    {"floors": {"tests.total": 128, "coverage.lines": 91.4}, "ceilings": {"markers": 0}}

A floor may only rise (passing tests, coverage, type coverage); a ceiling may only fall
(TODO markers, lint suppressions, type assertions, files over the size limit). The committed
baseline, verify-baseline.json, holds the best each figure has reached and an `allowedDrops`
trail of every deliberate step backwards.

Default (a local full run): a figure worse than its baseline fails, naming it. A figure that
improved, or is measured for the first time, is written into the baseline, but only while the
tree still has the fingerprint the run started on (`--measured-on` equals `--tree-now`): an edit
made during the run was never measured. Commit the rewritten baseline with the work that
caused it.

--check (CI): never writes. A regression fails. An improvement is a notice telling you to run the
gate locally and commit the baseline, so every raise reaches the main branch as a diff someone
reviewed, never as a write inside a CI workspace nobody sees. A missing baseline fails.

--allow-drop NAME --reason "category: why" (repeatable): the one sanctioned way down. It
records {name, from, to, reason, date} in `allowedDrops` and sets the figure to what this run
measured. It refuses a figure that did not get worse, a missing reason, and a run on a tree that
changed since it was measured. Never edit the baseline by hand; the entry is what a reviewer
reads. Nothing here ever lowers a figure on its own.

Exit 0 when every figure holds; 1 on a regression, a stale write, or a refused drop.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import date
from pathlib import Path

TOLERANCE = 1e-9


def load(path: Path) -> dict:
    return json.loads(path.read_text()) if path.exists() else {}


def fmt(value: float) -> str:
    return str(int(value)) if float(value).is_integer() else f"{value:.2f}"


def main() -> int:
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("--figures", default=".verify/figures.json")
    parser.add_argument("--baseline", default="verify-baseline.json")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--measured-on", default="")
    parser.add_argument("--tree-now", default="")
    parser.add_argument("--allow-drop", action="append", default=[], metavar="NAME")
    parser.add_argument("--reason", action="append", default=[], metavar="TEXT")
    args = parser.parse_args()

    figures_path = Path(args.figures)
    if not figures_path.exists():
        print(f"✗ ratchet: no figures at {figures_path}; the gate's figures() step wrote nothing", file=sys.stderr)
        return 1
    figures = json.loads(figures_path.read_text())
    floors = {k: float(v) for k, v in figures.get("floors", {}).items()}
    ceilings = {k: float(v) for k, v in figures.get("ceilings", {}).items()}
    if not floors and not ceilings:
        print("✗ ratchet: figures.json holds no figures", file=sys.stderr)
        return 1

    if len(args.allow_drop) != len(args.reason):
        print("✗ ratchet: every --allow-drop needs its own --reason", file=sys.stderr)
        return 1
    drops = dict(zip(args.allow_drop, args.reason))
    for name, reason in drops.items():
        if ":" not in reason or not reason.split(":", 1)[1].strip():
            print(f"✗ ratchet: --reason for {name} must read \"category: why\" (e.g. \"duplicate-tests: …\", \"feature-removed: …\")", file=sys.stderr)
            return 1
    if drops and args.check:
        print("✗ ratchet: --allow-drop is a local, reviewed change, never --check", file=sys.stderr)
        return 1

    baseline_path = Path(args.baseline)
    baseline = load(baseline_path)
    first = not baseline_path.exists()
    if first and args.check:
        print(f"✗ ratchet: no {baseline_path}; run the full gate locally and commit it", file=sys.stderr)
        return 1
    base_floors = {k: float(v) for k, v in baseline.get("floors", {}).items()}
    base_ceilings = {k: float(v) for k, v in baseline.get("ceilings", {}).items()}
    allowed = list(baseline.get("allowedDrops", []))

    stale = bool(args.measured_on or args.tree_now) and args.measured_on != args.tree_now
    problems: list[str] = []
    improvements: list[str] = []
    recorded: list[str] = []
    new_floors = dict(base_floors)
    new_ceilings = dict(base_ceilings)
    changed = first
    used_drops: set[str] = set()

    def visit(kind: str, measured: dict, base: dict, out: dict, better):
        nonlocal changed
        for name, value in sorted(measured.items()):
            if name not in base:
                out[name] = value
                changed = True
                recorded.append(f"{name} = {fmt(value)} (first measurement)")
                continue
            bar = base[name]
            if abs(value - bar) <= TOLERANCE:
                continue
            if better(value, bar):
                out[name] = value
                changed = True
                improvements.append(f"{name}: {fmt(bar)} → {fmt(value)}")
            elif name in drops:
                used_drops.add(name)
                allowed.append({"name": name, "from": bar, "to": value, "reason": drops[name], "date": date.today().isoformat()})
                out[name] = value
                changed = True
                recorded.append(f"{name}: {fmt(bar)} → {fmt(value)} (allowed drop: {drops[name]})")
            else:
                word = "fell" if kind == "floor" else "rose"
                problems.append(f"{name} {word}: {fmt(bar)} → {fmt(value)} ({kind} may only {'rise' if kind == 'floor' else 'fall'})")

    visit("floor", floors, base_floors, new_floors, lambda v, b: v > b)
    visit("ceiling", ceilings, base_ceilings, new_ceilings, lambda v, b: v < b)

    for name in drops:
        if name not in used_drops:
            problems.append(f"--allow-drop {name}: the figure did not get worse, or is not measured; nothing to allow")
    missing = [n for n in list(base_floors) + list(base_ceilings) if n not in floors and n not in ceilings]
    for name in missing:
        problems.append(f"{name} is in the baseline but was not measured this run: a figure that stops being measured is a drop")

    for line in recorded:
        print(f"  ratchet: {line}")
    for line in improvements:
        print(f"  ratchet: improved {line}")

    if problems:
        print("✗ ratchet: not every figure holds. Never lower the baseline by hand to get past this; fix the cause, or record a reviewed drop: scripts/verify.sh full --allow-drop NAME --reason \"category: why\" (or run this script with the same flags against the last run's figures).", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        return 1

    if args.check:
        if improvements or recorded:
            print("  ratchet: improvements are not written in --check mode; run the full gate locally and commit verify-baseline.json")
        print("✓ ratchet: every figure holds")
        return 0

    if changed:
        if stale:
            if drops or first:
                print("✗ ratchet: the tree changed while the gate ran, so these figures were not measured on it; run the gate again", file=sys.stderr)
                return 1
            print("  ratchet: the tree changed while the gate ran; improvements not written (the next run will)")
        else:
            baseline_path.write_text(json.dumps({"floors": new_floors, "ceilings": new_ceilings, "allowedDrops": allowed}, indent=2) + "\n")
            print(f"  ratchet: wrote {baseline_path}; commit it with the work that moved it")
    print("✓ ratchet: every figure holds")
    return 0


if __name__ == "__main__":
    sys.exit(main())
