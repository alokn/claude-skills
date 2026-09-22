---
id: uc-search-retrieval-document-answers-query-gate
title: Gate on whether a document answers the query at all before showing or using a result
verdict: good
domain: search-retrieval
decision_shapes: [detection, verification, routing]
primitives: [noul]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/semantic_find.md  (the exists Noul; 0.98 / 0.14 / 0.46 readings; FOUND/ABSENT = 0.7/0.35)
  - https://docs.typesafe.ai/cookbooks/skill_suggestion.md  (Choice picks, Nouls decide whether to say anything)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (structural invariants: Choice is relative, Noul is absolute)
related: [uc-search-retrieval-semantic-find-in-document, uc-search-retrieval-rag-passage-gating, uc-agents-harness-skill-or-tool-selection]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to decide whether our search actually found anything?" Also:
"how do we stop the answer bot answering when the knowledge base has nothing?", "we always
return five results even when none of them fit — can jev say 'no match'?"

## Verdict

**Good** — the shape is demonstrated by the `semantic_find` cookbook's four illustrative
queries, and by `skill_suggestion` on a different task; no task-matched labelled
accuracy is published; shadow-evaluate against the incumbent before acting. Every ranker
that normalises — a Choice, a cosine top-k, a BM25 score ordering — always produces a
winner. Whether the winner is *good enough* is a different question and must be asked
separately, as an absolute Noul. The docs make this explicit: a Choice "is relative,
settling *which* option, while each Noul is absolute and can be low for all of them."
The gate rides in the same request as the ranking, so it costs tokens and little extra
latency (the docs say latency "barely changes", not that it is free).

## What jev decides

State is whatever the ranker saw — the document, the shortlist, or the single top candidate.
One Noul, from `semantic_find.md`:

```python
Noul(instructions=f'Does any line of the document address or answer: "{query}"?',
     criteria=NoulCriteria(
       true="At least one line of the document states or directly implies the answer",
       false="No line of the document addresses this"))
```

Three bands in code rather than a binary, because "partially addressed" is a real outcome:
`FOUND, ABSENT = 0.7, 0.35` — above 0.7 show the result; below 0.35 show "not found"; between,
show the result marked as partial, or ask a clarifying question.

For a shortlist rather than a document, the skill-suggestion shape applies: one `fits::{name}`
Noul per finalist ("Does the skill '{name}' do the specific thing the user's request asks
for?") and `max(fits) < FITS_THRESHOLD` returns empty. Both cookbooks use a Choice and a Noul
together on the same candidates for exactly this reason.

## What stays in code

The ranking itself, the thresholds, the empty-state UI, the fallback (clarifying question,
human handoff, "no results"), and any hard business rule that already forbids an answer
(entitlement, jurisdiction, freshness). Do not turn the threshold into a question.

## Numbers

From `semantic_find.md`, `jev-1.12`, GitHub ToS, 218 lines: "who owns the code I upload?"
`exists` 0.98; "can GitHub kick me off the platform without warning?" 0.97; "do I have to
take disputes to arbitration?" 0.14 **while the top line still scored 0.86**; "can minors use
GitHub with parental permission?" 0.46, reported as partially addressed. Observed separation:
"present answers typically read >=0.9, absent <=0.05". Cost, latency and any scored accuracy
are not reported — four illustrative queries, no labelled set.

From `skill_suggestion.md`, `jev-1.12` with `claude-haiku-4-5-20251001` on 488 requests (173
of them deliberately covered by nothing): adding the gate plus a shortlist judge took needless
loads from 9.8% to 4.0%.

Closest jaggedness mode: **8, common-sense structural invariants.** The failure this entry
prevents is exactly the one the docs warn about — reading a relative probability as if it
were an absolute one.

## When the verdict flips

- **A deterministic signal already says "no match"** — zero rows, BM25 score below a
  calibrated floor, no entitlement. Use it; the gate is then **weak**.
- **The cost of a wrong "no answer" is higher than a wrong answer** (safety information, legal
  deadlines). Bias the bands hard, and keep a human path.
- **The corpus genuinely always contains an answer** (a closed FAQ with full coverage). Then
  the gate fires almost never and buys nothing.
- **The query is ambiguous rather than unanswerable.** A low `exists` conflates "not covered"
  with "I don't understand you"; split into two nouls if the product treats them differently.
- **Adversarial documents** (content written to look authoritative). Mode 6: jev is not a
  security gate.

## Alternatives considered

- **Score threshold on the retriever** (cosine or BM25 floor) — free, and the first thing to
  try; but the cookbook's arbitration query shows a confident-looking top score of 0.86 on a
  document that does not answer the question, which is precisely what a score floor cannot
  catch.
- **Answer-bot self-assessment ("say 'I don't know' if unsure")** — the generating model is
  the party least able to judge its own grounding, costs a second full call, and produces
  prose you must parse.
- **A second LLM judge** — works, but is a full call of latency and cost per query for one
  bit; the guardrails cookbook makes the same argument against per-turn LLM judges.
- **Small fine-tuned answerability classifier** (SQuAD 2.0-style) — genuinely strong if you
  have labelled unanswerables; jev wins when you do not and when the criterion is written in
  English and changes with the product.
- **Human review** — where the middle band goes, not where the volume goes.

## Sources

- https://docs.typesafe.ai/cookbooks/semantic_find.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/skill_suggestion.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
