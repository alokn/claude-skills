---
id: uc-verification-document-completeness-checklist
title: Check a document against a fixed checklist of things it must state
verdict: good
domain: verification
decision_shapes: [verification, detection, classification]
primitives: [noul, choice, score]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/parallel_questions.md  (13-question briefing over one 53,777-character document; 12.2x cheaper, 10.0x faster, same answers; per-question std devs)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Scientific discovery: "Flag missing methodological details, such as controls, dataset descriptions, and experimental settings")
  - https://docs.typesafe.ai/patterns/fan-out.md  (ask every question the decision needs in one call)
related: [uc-verification-citation-supports-claim, uc-agents-harness-premature-completion-check, uc-data-ml-systematic-review-screening]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check a document has everything it needs?" Also: "does this
methods section describe its controls and its dataset?", "which required sections are missing
from this submission?", "can we run a 20-point checklist over a long document in one call?"

## Verdict

**Good** — the shape is demonstrated by the `parallel_questions` cookbook and the
fan-out pattern page; no task-matched labelled accuracy is published; shadow-evaluate
against the incumbent before acting. A checklist is N independent yes/no judgements over
one shared state, which is exactly what the fan-out pattern is for — "All questions are
evaluated in parallel, so adding more questions to a call typically doesn't add any
latency" — and the parallel-questions cookbook measured a 13-question briefing over one
long document as one call rather than thirteen. The condition is that each checklist
item be a single, literal, answerable question: one item per question, never "does it
cover methods and data and ethics".

## What jev decides

State is the document under one key, sent once: `{"article": DOCUMENT}`. One question per
checklist item, mixed primitives in the same request. From the cookbook's own battery (8 Noul,
2 Choice, 3 Score over the GDPR article):

```python
"breach_72h": Noul(instructions="Must a personal data breach be reported to the supervisory authority within 72 hours?")
"instrument_type": Choice(instructions="What kind of EU legal instrument is the GDPR?", criteria={
    "Regulation": "Directly binding law in all member states, no national implementation needed.",
    "Directive": "...", "Treaty": "...", "Recommendation": "Non-binding guidance."})
"penalty_severity": Score(instructions="How severe are the penalties the GDPR provides for non-compliance?",
  criteria=["None: no penalties of any kind.", "Symbolic: ...",
            "Substantial: fines large enough to matter to most companies.",
            "Severe: fines scaled to global revenue, material even to the largest companies."])
```

For a completeness check, write each item as a presence Noul with both criteria stated:

```python
"states_control_condition": Noul(
  instructions="Does the methods section describe a control or comparison condition?",
  criteria=NoulCriteria(
    true="The text names what the treatment was compared against.",
    false="The text describes only the treatment arm, or mentions a comparison without saying what it was."))
```

Note the negative control in the cookbook's battery: `us_federal_law` ("Is the GDPR a United
States federal law?") returned 0.010. Include one or two items you know are false — a checklist
that never says no is not being read.

## What stays in code

The checklist itself and its versioning, the threshold per item (a missing ethics statement and
a missing figure caption do not deserve the same band), the count of missing items, the report,
and the routing of borderline documents to a person. Never ask "how many items are missing"
(mode 2) — count the answers.

## Numbers

From `parallel_questions.md`, `jev-1.12`: the GDPR Wikipedia article at pinned revision
`1363040264`, `53,777 characters`, 13 questions, 5 runs per strategy.

| batching | calls | cost | total time |
|---|---|---|---|
| one call, all 13 | 1 | $0.000497 | 0.27s |
| 13 calls, one each | 13 | $0.006090 | 2.71s |

"batching: 12.2x cheaper, 10.0x faster" — with the caveat that "the figure sums the 13
single-call latencies", and if you fire them concurrently "the 13x token cost stays". The saving
is a property of the workload: "The document dominates every request... The bigger the document,
the nearer that saving comes to a full Nx."

Stability matters for a checklist that gates a submission: eleven of the thirteen questions
returned identical means with "std dev exactly 0.0" across 5 runs under both strategies; two
carried noise (`breach_72h` 0.804 vs 0.814 with std 0.0055; `criminal_penalties` 0.108 with std
0.0045 vs 0.0084), and "The noise is a property of the question, not of how you batch."
Accuracy against a gold label: **not measured** — one document, no labelled set.

Closest jaggedness mode: **5, large state full of irrelevant detail.** A 54,000-character
document is near the practical limit; the context ceiling is 32k tokens for state plus the
longest single question. Split long submissions by section and run the relevant items per
section.

## When the verdict flips

- **Presence is structural** — a heading exists, a field is non-empty, a DOI matches a pattern.
  Regex or a schema check; asking is **weak**.
- **The checklist item is really three items.** Decompose, or the answer hides which part failed.
- **The item depends on counts or thresholds** ("at least three replicates", "within 30 days").
  Modes 2 and 3: extract and compare in code.
- **The document is longer than the state budget.** Section it first.
- **The check is a gate with legal force** (regulatory filing acceptance). Keep the authoritative
  rule in code and use jev to triage; the low band goes to a person.
- **Absence is ambiguous.** A missing control may be an omission or may be inapplicable to the
  design. Add a "not applicable" head rather than forcing a false negative.

## Alternatives considered

- **Regex / heading detection** — exact for structural requirements, and the right tool for
  "is there a Methods section"; blind to whether the section says anything.
- **Checklist as a single LLM prompt** — the incumbent for manuscript screening; returns prose
  to parse, seconds per document, and no per-item probability to threshold.
- **One LLM call per item** — accurate and the cost shape this replaces: 13x the document tokens.
- **Keyword presence per item** ("does 'control' appear") — high recall, low precision; useful as
  a pre-filter to decide which items are worth asking.
- **Human checklist review** — the current process for grant, ethics and journal screening, and
  where the borderline items should still go.

## Sources

- https://docs.typesafe.ai/cookbooks/parallel_questions.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/patterns/fan-out.md — accessed 2026-09-19
