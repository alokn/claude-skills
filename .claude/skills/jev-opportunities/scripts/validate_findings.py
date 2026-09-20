#!/usr/bin/env python3
"""validate_findings.py — gate for jev-opportunities findings.

Usage:
    validate_findings.py <repo-root> <findings.json> [more.json ...] [--out merged.json]

Input: one or more JSON files, each either a list of findings or {"findings": [...]}.
Output: prints a validation report to stdout; writes merged, validated findings to --out
(default: <first-input-dir>/findings.validated.json). Exit code 0 always (report is the gate);
exit 2 on unreadable input.

Checks per finding:
  * required fields present, enums valid
  * every evidence item points at a real file, a real line number, and the snippet occurs
    within ±3 lines of that number (whitespace-insensitive). Findings with zero verifiable
    evidence are REJECTED. Findings with some unverifiable evidence are kept with a warning.
  * primitive sketch sanity: type in {noul, choice, score}; choice <= 255 options;
    score 2..10 levels; instructions non-empty
  * disqualifier screen: rejects findings whose *question instructions* ask jev to generate text,
    count, or compare dates/numbers (unless `rewrite` explains the bounded form); hits in the prose
    are ADJUDICATE warnings for the orchestrator, not drops
  * scanner-declared `rejected` arrays are carried through to the output as `scanner_rejected`
  * dedupe: same primary file + overlapping line window (+-10), across lenses/categories -> keep the
    higher impact, record merged ids and categories
"""
import json
import os
import re
import sys
from collections import defaultdict

REQUIRED = [
    "id", "category", "title", "evidence", "current_behavior", "proposed",
    "decision_shape", "primitive_sketch", "impact", "effort", "confidence", "jev_fit",
]
CATEGORIES = {"replace", "feature", "sdlc"}
SHAPES = {
    "classification", "detection", "scoring", "routing", "ranking", "verification",
    "extraction", "search", "feature-extraction",
}
EFFORTS = {"S", "M", "L"}
CONFIDENCES = {"verified", "inferred", "speculative"}
FITS = {"strong", "ok", "weak"}
PRIMS = {"noul", "choice", "score"}

DISQUALIFIER_PATTERNS = [
    # generation: only verbs of producing text, not nouns like "draft issue"
    (re.compile(r"\b(generat(e|es|ing) (a |the )?(summary|reply|response|text|description|message|code)|summari[sz]e (the|this|each)|rewrite (the|this)|rephrase|compose (a|the)|write (a|the) (reply|summary|response))\b", re.I), "generation"),
    # math: counting/summing as the model's job
    (re.compile(r"\b(jev|model|question|ask(s|ed)?)\b[^.]{0,60}\b(count(s|ing)?|sum(s|ming)?|total(s|ling)?|average|percentage|how many)\b|\b(count|sum|total) (the|all|each)\b", re.I), "math"),
    # dates: temporal comparison, not the prepositions before/after
    (re.compile(r"\b(\d+\s*days? (before|after|since|ago|old)|older than|newer than|overdue|expir(y|ed|es|ation)|due date (passed|comparison)|date (comparison|difference|range|arithmetic)|within \d+ (days|hours|weeks)|since last (activity|update))\b", re.I), "dates"),
    (re.compile(r"\b(image|screenshot|photo|pixel|ocr|audio|video)s?\b(?! (alt text|caption|description|transcript))", re.I), "non-text-input"),
]


def norm(s: str) -> str:
    return re.sub(r"\s+", "", s or "")


SCANNER_REJECTED = []


def load(path):
    """Return the findings list; stash scanner-declared rejections in SCANNER_REJECTED."""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict):
        for r in data.get("rejected", []) or []:
            if isinstance(r, dict):
                r = dict(r); r["_lens"] = data.get("lens"); SCANNER_REJECTED.append(r)
        data = data.get("findings", [])
    if not isinstance(data, list):
        raise ValueError(f"{path}: expected list or {{'findings': [...]}}")
    return data


def check_evidence(root, ev, warnings):
    """Return True if this evidence item is verifiable."""
    if not isinstance(ev, dict):
        warnings.append("evidence item is not an object")
        return False
    file = ev.get("file", "")
    line = ev.get("line")
    snippet = ev.get("snippet", "")
    path = os.path.join(root, file)
    if not file or not os.path.isfile(path):
        warnings.append(f"file not found: {file!r}")
        return False
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            lines = f.read().split("\n")
    except OSError as e:
        warnings.append(f"cannot read {file}: {e}")
        return False
    if not isinstance(line, int) or line < 1 or line > len(lines):
        warnings.append(f"{file}: line {line!r} out of range (1..{len(lines)})")
        return False
    if not snippet or len(norm(snippet)) < 6:
        warnings.append(f"{file}:{line}: snippet missing or too short to verify")
        return False
    target = norm(snippet)
    lo, hi = max(0, line - 4), min(len(lines), line + 3)
    window = norm("\n".join(lines[lo:hi]))
    if target in window:
        # pin the exact line inside the window so the report cites it precisely
        for i in range(lo, hi):
            if target in norm(lines[i]) or (i + 1 < len(lines) and target in norm(lines[i] + lines[i + 1])):
                if i + 1 != line:
                    warnings.append(f"{file}: snippet is at line {i + 1}, not {line} (corrected)")
                    ev["line"] = i + 1
                break
        return True
    # try anywhere in file as a weaker match; report the actual line
    whole = [norm(l) for l in lines]
    for i, l in enumerate(whole, start=1):
        if target and target in l:
            warnings.append(f"{file}: snippet found at line {i}, not {line} (fix the line number)")
            ev["line"] = i
            return True
    warnings.append(f"{file}:{line}: snippet not found in file")
    return False


def check_primitives(sketch, warnings):
    if not isinstance(sketch, dict):
        warnings.append("primitive_sketch must be an object with 'state' and 'questions'")
        return False
    qs = sketch.get("questions")
    if not isinstance(qs, dict) or not qs:
        warnings.append("primitive_sketch.questions missing or empty")
        return False
    ok = True
    for qid, q in qs.items():
        if not isinstance(q, dict):
            warnings.append(f"question {qid}: not an object"); ok = False; continue
        t = q.get("type")
        if t not in PRIMS:
            warnings.append(f"question {qid}: type {t!r} not in {sorted(PRIMS)}"); ok = False
        if not q.get("instructions"):
            warnings.append(f"question {qid}: instructions empty"); ok = False
        crit = q.get("criteria")
        if t == "choice":
            if not isinstance(crit, dict) or len(crit) < 2:
                warnings.append(f"question {qid}: choice needs >=2 options as a map"); ok = False
            elif len(crit) > 255:
                warnings.append(f"question {qid}: choice has {len(crit)} options (max 255)"); ok = False
        if t == "score":
            if not isinstance(crit, list) or not (2 <= len(crit) <= 10):
                warnings.append(f"question {qid}: score needs an ordered list of 2..10 levels"); ok = False
    return ok


def disqualifier_screen(f, warnings):
    """Screen the proposal for non-System-One tasks.

    Hard reject only when a *question's own instructions* ask jev to generate, count, or compare
    dates/numbers. Hits in the title/proposal prose are warnings the orchestrator must adjudicate
    (Step 5.2), because prose legitimately describes what code does around the model.
    """
    sketch = f.get("primitive_sketch") or {}
    q_text = " ".join(str(q.get("instructions", "")) for q in (sketch.get("questions") or {}).values() if isinstance(q, dict))
    prose = " ".join(str(f.get(k, "")) for k in ("title", "proposed"))
    q_hits = {tag for pat, tag in DISQUALIFIER_PATTERNS if pat.search(q_text)}
    p_hits = {tag for pat, tag in DISQUALIFIER_PATTERNS if pat.search(prose)} - q_hits
    rewrite = str(f.get("rewrite", "") or "")
    if q_hits:
        if len(rewrite) >= 40:
            warnings.append(f"ADJUDICATE: question instructions hit {sorted(q_hits)}; 'rewrite' present, orchestrator must confirm the bounded reformulation is real")
            return True
        warnings.append(f"REJECT: question instructions ask jev for a non-System-One task ({', '.join(sorted(q_hits))}) and no 'rewrite' explains the bounded form")
        return False
    if p_hits:
        warnings.append(f"ADJUDICATE: proposal prose mentions {sorted(p_hits)}; confirm that part is done in code, not by jev")
    return True


def main(argv):
    if len(argv) < 3:
        print(__doc__); return 2
    root = os.path.abspath(argv[1])
    out = None
    inputs = []
    it = iter(argv[2:])
    for a in it:
        if a == "--out":
            out = next(it, None)
        else:
            inputs.append(a)
    if not inputs:
        print("no input files"); return 2
    out = out or os.path.join(os.path.dirname(os.path.abspath(inputs[0])), "findings.validated.json")

    findings = []
    for p in inputs:
        try:
            findings.extend(load(p))
        except Exception as e:  # noqa: BLE001
            print(f"ERROR reading {p}: {e}"); return 2

    accepted, rejected = [], []
    for f in findings:
        w = []
        missing = [k for k in REQUIRED if k not in f]
        if missing:
            w.append(f"missing fields: {missing}")
        if f.get("category") not in CATEGORIES:
            w.append(f"category {f.get('category')!r} not in {sorted(CATEGORIES)}")
        if f.get("decision_shape") not in SHAPES:
            w.append(f"decision_shape {f.get('decision_shape')!r} not in {sorted(SHAPES)}")
        if f.get("effort") not in EFFORTS:
            w.append(f"effort {f.get('effort')!r} not in S/M/L")
        if f.get("confidence") not in CONFIDENCES:
            w.append(f"confidence {f.get('confidence')!r} not in {sorted(CONFIDENCES)}")
        if f.get("jev_fit") not in FITS:
            w.append(f"jev_fit {f.get('jev_fit')!r} not in {sorted(FITS)}")
        try:
            imp = int(f.get("impact"))
            if not 1 <= imp <= 5:
                w.append("impact must be 1..5")
        except (TypeError, ValueError):
            w.append("impact must be an integer 1..5")

        ev = f.get("evidence") or []
        verified = [e for e in ev if check_evidence(root, e, w)]
        prim_ok = check_primitives(f.get("primitive_sketch"), w)
        dq_ok = disqualifier_screen(f, w)

        fatal = (not verified) or missing or (not prim_ok) or (not dq_ok)
        if not verified:
            w.insert(0, "REJECT: no verifiable evidence (file:line + snippet must match the repo)")
        if len(verified) < len(ev):
            f["confidence"] = "inferred" if f.get("confidence") == "verified" else f.get("confidence")
        f["_evidence_verified"] = len(verified)
        f["_warnings"] = w
        (rejected if fatal else accepted).append(f)

    # dedupe
    merged = []
    seen = defaultdict(list)
    for f in sorted(accepted, key=lambda x: -int(x.get("impact", 0))):
        pf = f["evidence"][0].get("file")
        pl = f["evidence"][0].get("line", 0)
        dup = None
        for g in seen[pf]:
            gl = g["evidence"][0].get("line", 0)
            if abs(int(gl) - int(pl)) <= 10:
                dup = g; break
        if dup:
            dup.setdefault("_merged_ids", []).append(f["id"])
            if f.get("category") != dup.get("category"):
                dup.setdefault("_merged_categories", []).append(f.get("category"))
            continue
        seen[pf].append(f)
        merged.append(f)

    with open(out, "w", encoding="utf-8") as fh:
        json.dump({"findings": merged, "validator_rejected": rejected, "scanner_rejected": SCANNER_REJECTED}, fh, indent=2)

    print(f"# validate_findings: {len(findings)} in -> {len(merged)} accepted ({len(accepted) - len(merged)} merged as duplicates), {len(rejected)} rejected by validator; {len(SCANNER_REJECTED)} candidates rejected by scanners (carried through for the report's rejected table)")
    print(f"written: {out}\n")
    for f in merged:
        flag = " (warnings)" if f["_warnings"] else ""
        print(f"OK   {f['id']:<8} impact={f['impact']} effort={f['effort']} fit={f['jev_fit']} conf={f['confidence']} ev={f['_evidence_verified']}/{len(f['evidence'])}{flag}  {f['title']}")
        for wmsg in f["_warnings"]:
            print(f"       - {wmsg}")
    for f in rejected:
        print(f"DROP {f.get('id','?'):<8} {f.get('title','(untitled)')}")
        for wmsg in f["_warnings"]:
            print(f"       - {wmsg}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
