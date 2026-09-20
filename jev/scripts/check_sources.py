#!/usr/bin/env python3
"""Check that every URL cited in the corpus resolves (HTTP < 400) and list them by file.

Usage: python3 jev/scripts/check_sources.py [jev-root] [--write 50-sources/url-check.md]
Uses only the standard library. Skips localhost. Follows redirects. 12 s timeout per URL.
"""
import concurrent.futures as cf
import os
import re
import sys
import urllib.request
import urllib.error

URL_RE = re.compile(r"https?://[^\s)\]>\"'`]+")


def check(url):
    req = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "Mozilla/5.0 corpus-check"})
    try:
        with urllib.request.urlopen(req, timeout=12) as r:
            return url, r.status
    except urllib.error.HTTPError as e:
        if e.code in (403, 405):  # some hosts reject HEAD; retry GET
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 corpus-check"})
                with urllib.request.urlopen(req, timeout=12) as r:
                    return url, r.status
            except Exception as e2:  # noqa: BLE001
                return url, getattr(e2, "code", str(e2))
        return url, e.code
    except Exception as e:  # noqa: BLE001
        return url, str(e)[:60]


def main(argv):
    root = os.path.abspath(argv[1] if len(argv) > 1 and not argv[1].startswith("--") else os.path.join(os.path.dirname(__file__), ".."))
    write = None
    if "--write" in argv:
        write = os.path.join(root, argv[argv.index("--write") + 1])
    urls = {}
    for dirpath, _, files in os.walk(root):
        if "/scripts" in dirpath or "/_drafts" in dirpath:
            continue
        for fn in files:
            if fn.endswith(".md"):
                p = os.path.join(dirpath, fn)
                for u in URL_RE.findall(open(p, encoding="utf-8").read()):
                    u = u.rstrip(".,;:")
                    if "<" in u or ">" in u:  # template placeholder, not a real URL
                        continue
                    urls.setdefault(u, set()).add(os.path.relpath(p, root))
    print(f"checking {len(urls)} distinct URLs ...")
    with cf.ThreadPoolExecutor(max_workers=16) as ex:
        results = dict(ex.map(check, urls))
    bad = {u: s for u, s in results.items() if not (isinstance(s, int) and (s < 400 or s == 405))}
    lines = [f"# URL check ({len(urls)} URLs, {len(bad)} failing)", ""]
    for u in sorted(urls):
        status = results[u]
        mark = "OK " if u not in bad else "BAD"
        lines.append(f"- {mark} `{status}` {u}  ← {', '.join(sorted(urls[u]))}")
    text = "\n".join(lines)
    if write:
        with open(write, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
        print(f"written {write}")
    for u, s in sorted(bad.items()):
        print(f"BAD {s} {u}  ({', '.join(sorted(urls[u]))})")
    print(f"{len(urls) - len(bad)} ok, {len(bad)} failing")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
