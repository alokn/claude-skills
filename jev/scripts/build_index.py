#!/usr/bin/env python3
"""Build jev/index.json from the YAML frontmatter of every markdown entry in the corpus.

Usage: python3 jev/scripts/build_index.py [jev-root]
Also validates frontmatter against CORPUS-SCHEMA.md vocabularies and prints problems.
"""
import json
import os
import re
import sys

VERDICTS = {"strong", "good", "conditional", "weak", "no"}
EVIDENCE = {"official-cookbook", "official-docs", "independent-benchmark", "community-report", "inferred"}
SHAPES = {"classification", "detection", "scoring", "routing", "ranking", "verification", "extraction", "search", "retrieval", "feature-extraction"}
PRIMS = {"choice", "score", "noul"}

FM_RE = re.compile(r"^---\n(.*?)\n---\n", re.S)


def parse_frontmatter(text):
    m = FM_RE.match(text)
    if not m:
        return None
    fm = {}
    key = None
    for line in m.group(1).split("\n"):
        if not line.strip():
            continue
        if re.match(r"^\s+-\s", line) and key:
            fm.setdefault(key, [])
            if isinstance(fm[key], list):
                fm[key].append(line.strip()[2:].strip())
            continue
        mm = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if mm:
            key, val = mm.group(1), mm.group(2).strip()
            if val.startswith("[") and val.endswith("]"):
                fm[key] = [v.strip().strip("'\"") for v in val[1:-1].split(",") if v.strip()]
            elif val == "":
                fm[key] = []
            else:
                fm[key] = val.strip("'\"")
    return fm


def main(root):
    entries, problems = [], []
    for dirpath, _, files in os.walk(root):
        if any(part.startswith("_") or part in ("scripts", "50-sources") for part in dirpath.replace(root, "").split(os.sep)):
            continue
        for fn in sorted(files):
            if not fn.endswith(".md") or fn in {"README.md", "CORPUS-SCHEMA.md", "changelog.md", "sources.md", "url-check.md", "adversarial-review-prompt.md"}:
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, root)
            text = open(path, encoding="utf-8").read()
            fm = parse_frontmatter(text)
            if fm is None:
                problems.append(f"{rel}: no frontmatter")
                continue
            for req in ("id", "title", "last_verified"):
                if req not in fm:
                    problems.append(f"{rel}: missing {req}")
            if rel.startswith(("20-use-cases", "30-anti-use-cases")):
                v = fm.get("verdict")
                if v not in VERDICTS:
                    problems.append(f"{rel}: verdict {v!r} not in {sorted(VERDICTS)}")
                if rel.startswith("30-") and v not in {"weak", "no"}:
                    problems.append(f"{rel}: anti-use-case with verdict {v!r} (expected weak/no)")
                if rel.startswith("20-") and v in {"weak", "no"}:
                    problems.append(f"{rel}: use-case with verdict {v!r} (belongs in 30-anti-use-cases)")
                e = fm.get("evidence_level")
                if e not in EVIDENCE:
                    problems.append(f"{rel}: evidence_level {e!r} not in {sorted(EVIDENCE)}")
                for s in fm.get("decision_shapes", []) or []:
                    if s not in SHAPES:
                        problems.append(f"{rel}: decision_shape {s!r} unknown")
                for p in fm.get("primitives", []) or []:
                    if p not in PRIMS:
                        problems.append(f"{rel}: primitive {p!r} unknown")
                if not fm.get("sources"):
                    problems.append(f"{rel}: no sources")
                decides = "## What jev would get wrong" if rel.startswith("30-") else "## What jev decides"
                for sec in ("## The question", "## Verdict", decides, "## What stays in code", "## Numbers", "## When the verdict flips", "## Alternatives considered"):
                    if sec not in text:
                        problems.append(f"{rel}: missing section '{sec}'")
            body = FM_RE.sub("", text, count=1)
            first_para = next((p.strip() for p in body.split("\n\n") if p.strip() and not p.strip().startswith("#")), "")
            entries.append({
                "id": fm.get("id"),
                "path": rel,
                "title": fm.get("title"),
                "verdict": fm.get("verdict"),
                "verdict_as_asked": fm.get("verdict_as_asked"),
                "domain": fm.get("domain"),
                "decision_shapes": fm.get("decision_shapes", []),
                "primitives": fm.get("primitives", []),
                "evidence_level": fm.get("evidence_level"),
                "related": fm.get("related", []),
                "sources": (fm.get("sources") or []) or ([fm["url"]] if fm.get("url") else []),
                "source_model_version": fm.get("source_model_version"),
                "last_verified": fm.get("last_verified"),
                "jev_version": fm.get("jev_version"),
                "summary": first_para[:400],
                "words": len(body.split()),
            })
    ids = [e["id"] for e in entries]
    for dup in {i for i in ids if ids.count(i) > 1 and i}:
        problems.append(f"duplicate id: {dup}")
    known = set(ids)
    for e in entries:
        for r in e["related"] or []:
            if r not in known:
                problems.append(f"{e['path']}: related id {r!r} does not exist")
    out = os.path.join(root, "index.json")
    with open(out, "w", encoding="utf-8") as fh:
        json.dump({"generated_from": "frontmatter", "count": len(entries), "entries": entries}, fh, indent=2)
    by_verdict = {}
    for e in entries:
        by_verdict[e["verdict"]] = by_verdict.get(e["verdict"], 0) + 1
    print(f"index.json: {len(entries)} entries; verdicts: {by_verdict}; total words: {sum(e['words'] for e in entries)}")
    for p in problems:
        print("PROBLEM", p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), ".."))))
