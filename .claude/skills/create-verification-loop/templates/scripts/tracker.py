#!/usr/bin/env python3
"""The tracker rule: every PR names the issue it belongs to, in any tracker.

An accepted ID is KEY-<n> (Linear, Jira, Plane), #<n> (GitHub Issues) or a URL (anything else).
`Tracker: none` is the explicit opt-out. Only two places count, so prose cannot fool the check
("UTF-8", "COVID-19", "see #3" are not IDs):
  1. a `Tracker:` line in the PR body (HTML comments are ignored);
  2. a KEY-<n> at the start of the title ("OFF-1 Add login", "[OFF-1] Add login").
The branch name counts only for pr.sh, and only for the keys in BRANCH_KEYS, because
"node-22-upgrade" looks like an ID. Branches such as `you/off-1-slug` work.

Text goes in through the environment (TITLE, BODY, BRANCH, ISSUE), never argv, so quotes and
newlines in a PR body cannot break a command line.
  tracker.py find    print the ID (or "none"); exit 1 when there is none
  tracker.py check   like find, but title and body only, with the message CI shows
  tracker.py title   print TITLE with the ID in front (unchanged when it has one)
  tracker.py body    print BODY with its Tracker line holding the ID
  tracker.py --selftest

CONFIGURE: BRANCH_KEYS, the project keys your tracker uses in branch names (the interview lists
candidates). Empty means branch names are never read.
"""
import os
import re
import sys

BRANCH_KEYS = []  # e.g. ["OFF", "ENG"]; TRACKER_BRANCH_KEYS="OFF,ENG" overrides

KEY = r"[A-Za-z][A-Za-z0-9]*-[0-9]+"
_COMMENT = re.compile(r"<!--.*?-->", re.S)
_LINE = re.compile(r"^[ \t]*Tracker:[ \t]*(.*?)[ \t]*$", re.I | re.M)
_TITLE = re.compile(r"^\s*\[?(%s)\]?(?=\W|$)" % KEY)
_PLACEHOLDER = re.compile(r"^(id|id or url|<id>|n/?a|tbd|todo|\.\.\.|…)$", re.I)


def normalize(value):
    """An ID as written -> canonical ('OFF-1', '#12', a URL, 'none'), or None."""
    v = (value or "").strip().strip("<>").strip()
    if re.fullmatch(r"none", v, re.I):
        return "none"
    if re.fullmatch(r"#[0-9]+", v):
        return v
    if re.fullmatch(r"[0-9]+", v):
        return "#" + v
    if re.fullmatch(r"https?://\S+", v):
        return v
    if re.fullmatch(KEY, v):
        return v.upper()
    return None


def from_body(body):
    for m in _LINE.finditer(_COMMENT.sub("", body or "")):
        raw = m.group(1).strip()
        if raw and not _PLACEHOLDER.match(raw):
            return normalize(raw)
    return None


def from_title(title):
    m = _TITLE.match(title or "")
    return m.group(1).upper() if m else None


def from_branch(branch, keys):
    for k in keys:
        m = re.search(r"(?:^|/)%s-([0-9]+)(?![0-9])" % re.escape(k), branch or "", re.I)
        if m:
            return "%s-%s" % (k.upper(), m.group(1))
    return None


def keys_from_env():
    raw = os.environ.get("TRACKER_BRANCH_KEYS")
    return [k.strip() for k in raw.split(",") if k.strip()] if raw is not None else BRANCH_KEYS


def find(title, body, branch="", issue="", keys=()):
    if issue:
        got = normalize(issue)
        if not got:
            raise ValueError("--issue %r is not KEY-<n>, #<n>, a URL or none" % issue)
        return got
    return from_body(body) or from_title(title) or from_branch(branch, keys)


def with_title(title, ident):
    if not ident or ident == "none" or from_title(title):
        return title
    if re.fullmatch(KEY, ident):
        return "%s %s" % (ident, title)
    return title


def with_body(body, ident):
    body = body or ""
    if not ident:
        return body
    scrubbed = _COMMENT.sub("", body)
    for m in _LINE.finditer(scrubbed):
        if m.group(1).strip() and not _PLACEHOLDER.match(m.group(1).strip()):
            return body  # already holds one; never overwrite what the author wrote
    stripped = re.sub(r"^[ \t]*Tracker:.*\n?", "", body, flags=re.I | re.M)
    return "Tracker: %s\n\n%s" % (ident, stripped.lstrip("\n"))


def _selftest():
    ok = []

    def eq(got, want, what):
        if got != want:
            sys.exit("selftest FAILED: %s: got %r, want %r" % (what, got, want))
        ok.append(what)

    eq(from_title("OFF-1 Add login"), "OFF-1", "title key")
    eq(from_title("[off-12] Add login"), "OFF-12", "bracketed lower-case title key")
    eq(from_title("Fix UTF-8 handling"), None, "UTF-8 in prose is not an ID")
    eq(from_title("Bump COVID-19 dashboard"), None, "key later in title is not an ID")
    eq(from_body("Tracker: #12"), "#12", "github id")
    eq(from_body("Tracker: https://linear.app/x/issue/OFF-1"), "https://linear.app/x/issue/OFF-1", "url")
    eq(from_body("tracker: none"), "none", "opt-out, any case")
    eq(from_body("Tracker: <!-- ID or URL -->\nsee #3 and UTF-8"), None, "placeholder + prose")
    eq(from_body("<!-- Tracker: OFF-9 -->\nbody"), None, "commented-out line")
    eq(from_body("Tracker: \n\nCloses #4"), None, "empty line")
    eq(from_branch("you/off-1-add-login", ["OFF"]), "OFF-1", "linear branch")
    eq(from_branch("node-22-upgrade", ["OFF"]), None, "unconfigured key ignored")
    eq(from_branch("off-12", ["OFF"]), "OFF-12", "bare branch")
    eq(from_branch("you/off-123x", ["OFF"]), "OFF-123", "digits end at a letter")
    eq(from_branch("you/off-1-x", []), None, "no keys, no branch reading")
    eq(find("T", "", "", "7"), "#7", "issue flag, bare number")
    eq(find("OFF-3 T", "Tracker: OFF-4", "", ""), "OFF-4", "body wins over title")
    eq(with_title("Add login", "OFF-1"), "OFF-1 Add login", "title prefixed")
    eq(with_title("OFF-1 Add login", "OFF-1"), "OFF-1 Add login", "title kept")
    eq(with_title("Add login", "#12"), "Add login", "github id does not touch the title")
    eq(with_body("## P\n", "OFF-1"), "Tracker: OFF-1\n\n## P\n", "line added")
    eq(with_body("Tracker: <!-- ID -->\n\n## P\n", "OFF-1"), "Tracker: OFF-1\n\n## P\n", "placeholder replaced")
    eq(with_body("Tracker: #2\n## P\n", "OFF-1"), "Tracker: #2\n## P\n", "author's line kept")
    print("tracker.py selftest: %d checks passed" % len(ok))


def main(argv):
    if argv[1:2] == ["--selftest"]:
        return _selftest()
    cmd = argv[1] if len(argv) > 1 else ""
    title, body = os.environ.get("TITLE", ""), os.environ.get("BODY", "")
    branch, issue = os.environ.get("BRANCH", ""), os.environ.get("ISSUE", "")
    try:
        if cmd == "find":
            ident = find(title, body, branch, issue, keys_from_env())
            print(ident or "")
            return 0 if ident else 1
        if cmd == "check":
            ident = find(title, body)
            if ident:
                print("tracker: %s" % ident)
                return 0
            print('::error::No tracker ID. Add a "Tracker: <KEY-n | #n | URL>" line to the PR body, '
                  'or start the title with KEY-<n>. "Tracker: none" opts out.')
            return 1
        if cmd in ("title", "body"):
            ident = find(title, body, branch, issue, keys_from_env())
            sys.stdout.write(with_title(title, ident) if cmd == "title" else with_body(body, ident))
            return 0
    except ValueError as e:
        print(e, file=sys.stderr)
        return 2
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
