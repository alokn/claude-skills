# Scanner subagent prompt template

Fill every `{PLACEHOLDER}` and dispatch with the Agent tool (`subagent_type: general-purpose`,
`model: sonnet` by default, `opus` for `--deep`). One agent per lens (and per module group on large repos).
Agents run in parallel; each writes JSON to its own file and returns only a 5-line summary.

---

You are scanning a codebase for places where **jev** (TypeSafe AI's System One model) would add value.
Lens for this run: **{LENS}** ({LENS_DESCRIPTION}). For lens C this includes the repo's own agent harness (`.claude/`, `AGENTS.md`, hooks), so a finding may propose changing the repo's Claude skills or hooks; say so plainly in the title.
Scope: files under `{SCOPE_PATHS}` in repo `{REPO_ROOT}`. Do not modify any file in the repo.

## Read first (in this order, fully)
1. `{SKILL_DIR}/references/jev-primer.md` — what jev is, the three primitives, hard limits, failure modes.
   Apply its freshness rule if you have WebFetch (live models + jaggedness pages win over the snapshot)
2. `{SKILL_DIR}/references/fit-rubric.md` — fit test, disqualifiers, scoring, evidence rules
3. `{SKILL_DIR}/references/detection-signals.md` — section for your lens, plus Counter-signals
4. The repo orientation below (hotspots for your lens are candidates, not findings)

## Repo orientation (from `scripts/orient.sh --lens {LENS_CODE}`)
{ORIENT_EXCERPT}

## Domain context
{DOMAIN_SUMMARY}

## Method
- Start from the hotspot files for your lens, then widen with your own greps using the cheatsheet.
- **Open every file you cite.** Read the decision site and its callers. Determine whether a value is an
  input (user/request-provided) or an output (computed/decided). Only outputs are replace candidates.
- For each candidate run the fit test. Reject anything hitting a disqualifier unless you can write the
  bounded rewrite. Rejections with a one-line reason go in `rejected`.
- Sketch the primitives: state shape (only the fields needed), 2-8 questions with types and criteria,
  which answer drives which branch, confidence bands.
- Estimate cost/latency with the method in the rubric. Source volume from code/config or say unknown.
- Prefer fewer, deeper findings. Target 3-5 accepted findings for this lens (the orchestrator ships 8-12 across all lenses); cap at 6. Put everything else you seriously considered in `rejected` with the reason.
- Finish within ~{BUDGET_MINUTES} minutes of work.

## Output
Write **only JSON** to `{OUT_FILE}` with this shape, then reply with a 5-line summary (counts, top 3 titles).

```json
{
  "lens": "{LENS}",
  "findings": [
    {
      "id": "{LENS_CODE}-01",
      "category": "replace | feature | sdlc",
      "title": "Short imperative title",
      "evidence": [
        {"file": "relative/path.py", "line": 123, "snippet": "verbatim line from the file"}
      ],
      "current_behavior": "What the code does today, 1-3 sentences, mechanism not vibes",
      "proposed": "What jev decides, where the call sits, what code does with the answer",
      "decision_shape": "classification | detection | scoring | routing | ranking | verification | extraction | search | feature-extraction",
      "primitive_sketch": {
        "state": {"example_field": "description of what goes here"},
        "questions": {
          "question_id": {"type": "choice", "instructions": "...", "criteria": {"opt_a": "what/not_for", "other": null}},
          "another_id":  {"type": "score",  "instructions": "...", "criteria": ["level 0", "level 1", "level 2"]},
          "third_id":    {"type": "noul",   "instructions": "...", "criteria": {"true": "...", "false": "..."}}
        }
      },
      "confidence_gating": "answer X >= 0.85 auto-apply; 0.6-0.85 suggest; below: existing path / human",
      "volume_estimate": {"value": "per request on POST /intake; unknown volume", "source": "code | config | unknown"},
      "cost_latency": {"current": "...", "proposed": "~1,200 input tokens -> $0.00005/call, ~100 ms", "method": "chars/4; price $0.042/Mtok"},
      "impact": 4, "effort": "M", "confidence": "verified", "jev_fit": "strong",
      "disqualifiers_checked": ["generation", "math", "dates", "images", "indirection", "adversarial", "deterministic-rule-exists"],
      "rewrite": "Only if a disqualifier word appears: how the task becomes a bounded Choice/Score/Noul",
      "closest_cookbook": "rerank_typesafe",
      "risks": "What could go wrong; what stays deterministic",
      "rollout": "shadow mode -> audit + calibrate on <existing labelled data> -> flip high band with fallback kept -> retire <redundant heuristic> after measured gates; <invariant> stays authoritative",
      "user_and_moment": "(feature findings) who benefits and where in the product it fires"
    }
  ],
  "rejected": [
    {"title": "...", "file": "path", "reason": "lexical match; regex wins | date arithmetic | generation | ..."}
  ],
  "coverage_notes": "What you scanned, what you skipped, where you ran out of time"
}
```

Rules: no finding without a verbatim snippet you saw in the file; no file you did not open; no accuracy
claims; no monthly dollar figures without a sourced volume. If the validator later flags a disqualifier,
fix the *design* (move the arithmetic/date/generation into code and say so in `rewrite`) or move the
finding to `rejected`; do not reword the prose to dodge the screen. Question ids are for code; write the full
question in `instructions`.
