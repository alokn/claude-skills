#!/usr/bin/env python3
"""Does a pull request's body fill .github/pull_request_template.md?

    python3 -I scripts/pr-body.py --body-file PATH --base REV     # the hook and scripts/pr.sh
    python3 -I scripts/pr-body.py --pr N --base REV               # CI: the body read through the API

Every section in SECTIONS is present once and has content: an untouched template comment or
whitespace is empty, "None" is content. "What changed" ends with the LABELLED_LINES, each
"None" or what it is. Then the diff is cross-checked: what HEAD changes since its merge base
with REV (in CI, the trial merge against its first parent, `--base HEAD^1`). Each CROSS_CHECKS
entry makes a kind of file the change adds or edits (a migration, a locked test, a public
contract) be named, by path or file name, in its section. A change to the ratchet's
`allowedDrops` needs a "Ratchet drops" section with a row per drop.

--pr reads the body now (GITHUB_REPOSITORY, GITHUB_TOKEN), so an edit made after the PR was
opened is what gets judged. A PR by a BOT_AUTHORS login is exempt.

Exit 0 when the body passes; 1 naming every problem; 2 when it cannot check at all.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.request

# CONFIGURE ---------------------------------------------------------------------------------
TEMPLATE = ".github/pull_request_template.md"
SECTIONS = [
    "Issue",
    "Why",
    "What changed",
    "Decisions and trade-offs",
    "Checks run beyond the gate",
    "Affected boundaries",
    "Review",
    "Follow-ups and flakes",
]
LABELLED_LINES = {"What changed": ["Security and isolation", "Deploy notes"]}
# Source paths: a change to one may not say plain "None" under Decisions ("None: mechanical" may).
SOURCE = re.compile(r"^(src|lib|app)/")
# (section, path regex, git statuses, what it is). Examples; keep the ones this repo has.
CROSS_CHECKS = [
    ("Affected boundaries", re.compile(r"^(db/migrate|migrations)/"), "A", "the new migration"),
    ("Affected boundaries", re.compile(r"^tests/acceptance/"), "AMD", "a file of the locked catalogue"),
]
BASELINE = "verify-baseline.json"  # scripts/ratchet.py's; its `allowedDrops` is the trail
RATCHET_DROPS = "Ratchet drops"
BOT_AUTHORS = {"github-actions[bot]", "dependabot[bot]"}
# -------------------------------------------------------------------------------------------


def sections(body: str) -> tuple[dict[str, str], list[str]]:
    """The `## ` sections, comments removed and trimmed. A heading inside a code fence is not one."""
    body = re.sub(r"<!--[\s\S]*?(-->|$)", "", body.replace("\r\n", "\n"))
    found: dict[str, str] = {}
    dupes: list[str] = []
    current, fence = None, False
    for line in body.split("\n"):
        if re.match(r"\s*(```|~~~)", line):
            fence = not fence
        m = None if fence else re.match(r"##\s+(.+?)\s*#*\s*$", line)
        if m:
            current = m.group(1)
            if current in found:
                dupes.append(current)
            found[current] = ""
        elif current is not None:
            found[current] += line + "\n"
    return {k: v.strip() for k, v in found.items()}, dupes


def plain(text: str) -> str:
    text = re.sub(r"^[ \t]*(?:[-*+>]|\d+[.)])[ \t]+", "", text, flags=re.M)
    return re.sub(r"[*_`~]", "", text).strip()


def empty(text: str) -> bool:
    """Nothing a reader can read: no letter or digit (a lone dash, an empty table)."""
    return not re.search(r"\w", text.replace("_", ""))


def problems_with(body: str, files: list[tuple[str, str]], drops_changed: bool) -> list[str]:
    found, dupes = sections(body)
    out = [f'"{d}" appears more than once: keep one' for d in dupes]
    for name in SECTIONS:
        if name not in found:
            out.append(f'"{name}" is missing: add the section from {TEMPLATE}')
        elif empty(found[name]):
            out.append(f'"{name}" is empty: fill it ("None" counts where it applies)')
    issue = found.get("Issue", "")
    if not empty(issue) and not re.search(r"#\d+|\b[A-Z]+-\d+\b|https?://|^None:\s*\S", plain(issue), re.I):
        out.append('"Issue" names no issue: give #N, or "None: <why>"')
    for name, labels in LABELLED_LINES.items():
        text = rest = found.get(name, "")
        if name not in found or empty(text):
            continue
        for label in labels:
            line = re.compile(rf"^[ \t]*(?:[-*+][ \t]+)?(?:\*\*)?{re.escape(label)}:(?:\*\*)?[ \t]*(.*)$", re.I | re.M)
            m = line.search(text)
            if not m:
                out.append(f'"{name}" has no "{label}:" line: add "{label}: None", or what it is')
            elif empty(m.group(1)):
                out.append(f'"{name}" has an empty "{label}:" line')
            rest = line.sub("", rest)
        if empty(rest):
            out.append(f'"{name}" has only its labelled lines: say what the change does')
    decisions = plain(found.get("Decisions and trade-offs", ""))
    code = [p for s, p in files if SOURCE.match(p)]
    if re.match(r"none\b", decisions, re.I) and not re.match(r"none:\s*mechanical\b", decisions, re.I) and code:
        out.append(f'"Decisions and trade-offs" says None, but the change touches code ({", ".join(code[:5])}): '
                   'name each decision, or write "None: mechanical"')
    for section, pattern, statuses, what in CROSS_CHECKS:
        text = found.get(section, "")
        for status, path in files:
            if status in statuses and pattern.match(path) and path not in text and os.path.basename(path) not in text:
                out.append(f'"{section}" does not name {path}, {what}')
    if drops_changed:
        rows = [r for r in found.get(RATCHET_DROPS, "").split("\n")[2:]
                if r.strip().startswith("|") and re.search(r"\w", r)]
        if not rows:
            out.append(f'{BASELINE}\'s allowedDrops changed, but "{RATCHET_DROPS}" has no row: add the section, one row per drop')
    return out


def git(*args: str) -> str:
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def drops(rev: str) -> str | None:
    try:
        return json.dumps(json.loads(git("show", f"{rev}:{BASELINE}")).get("allowedDrops", []))
    except (subprocess.CalledProcessError, ValueError, AttributeError):
        return None


def fetch_pr(number: str) -> tuple[str, str]:
    repo = os.environ.get("GITHUB_REPOSITORY")
    if not repo:
        raise OSError("GITHUB_REPOSITORY is not set")
    req = urllib.request.Request(f"https://api.github.com/repos/{repo}/pulls/{number}", headers={
        "Authorization": f"Bearer {os.environ.get('GITHUB_TOKEN', '')}", "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req, timeout=30) as res:
        pr = json.load(res)
    return pr.get("body") or "", (pr.get("user") or {}).get("login", "")


def main() -> int:
    ap = argparse.ArgumentParser()
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--body-file")
    src.add_argument("--pr")
    ap.add_argument("--base", required=True)
    args = ap.parse_args()
    try:
        if args.pr:
            body, author = fetch_pr(args.pr)
        else:
            with open(args.body_file, encoding="utf-8") as f:
                body, author = f.read(), ""
        if author in BOT_AUTHORS:
            print(f"pr body: {author} is a bot, exempt")
            return 0
        base = git("merge-base", args.base, "HEAD").strip()
        files = [tuple(line.split("\t", 1)) for line in git("diff", "--name-status", "--no-renames", base, "HEAD").splitlines()]
        files = [(s[:1], p) for s, p in files]
    except OSError as e:
        print(f"pr body: cannot check: {e}", file=sys.stderr)
        return 2
    except subprocess.CalledProcessError as e:
        print(f"pr body: cannot check: {' '.join(e.cmd)} failed ({e.stderr.strip()}); fetch the base and try again",
              file=sys.stderr)
        return 2
    # A baseline absent at one side has no drops: the PR that adds it records none.
    drops_changed = any(p == BASELINE for _, p in files) and (drops(base) or "[]") != (drops("HEAD") or "[]")
    problems = problems_with(body, files, drops_changed)
    if not problems:
        print("✓ pr body: every section of the template is filled")
        return 0
    print(f"✗ pr body: the description does not fill {TEMPLATE}:\n  " + "\n  ".join(problems), file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
