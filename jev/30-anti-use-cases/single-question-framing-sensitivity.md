---
id: au-single-question-framing-sensitivity
title: Do not trust a single-question design whose wording and option order you have not varied
verdict: no
domain: ml
decision_shapes: [classification, routing, scoring]
primitives: [choice, score, noul]
evidence_level: independent-benchmark
sources:
  - https://github.com/RINNECODER/jev-behavior-study  (11,621 requests; framing and position effects)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 1, literal reading; mode 7, contradictory instructions)
  - https://docs.typesafe.ai/confidence.md  ("Jev is designed for consistency" across similar meanings)
related: [au-chain-questions-in-one-request, au-multi-hop-and-double-negatives, au-expect-identical-results-across-runs, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to ship this one Choice as written, since it looked right on twenty examples?" Also
"does the order of the options matter?", "we reworded the question slightly, do we need to re-measure?",
"one question or several?".

## Verdict

**No** — not the design, and not the evaluation of it. RINNECODER's behaviour study ran 11,621 requests
and found wording and option position to be first-order effects rather than noise. Changing "5-minute
walk" to "5-minute drive" moved correct answers from 0/20 to 20/20. Placing the correct option first
gave 95/108 correct against 62/108 when the same option sat fourth. A design that rests on one question,
one phrasing and one option order has an untested confound sitting underneath every number you have
collected about it.

## What jev would get wrong

The docs describe the mechanism from the other side: "`jev-1.13` answers the question you wrote, not the
one you meant. Scoping words, negations, and implied conditions are read at face value." The model is
built for *consistency* — "making similar decisions when the meaning stays similar, even if the wording
changes" — but the study shows how far that guarantee bends when a phrase carries an unintended
implicature or when position acts as a prior. The failure is silent: the answer is well-typed, the
confidence can be high, and nothing in the response tells you the result would flip under a paraphrase.

## What stays in code

The test harness. Before a single-question design ships, code should run each question in at least two
paraphrases and with the option order permuted (or randomised per call, seeded by the item id, so
position cannot bias a whole queue in one direction). Store the disagreement rate between variants as a
release gate: if two paraphrases of the same question disagree on 10% of a labelled sample, that is the
error bar on everything downstream. Code also owns the tie-break when variants disagree — escalate,
do not average.

## Numbers

From 11,621 requests (https://github.com/RINNECODER/jev-behavior-study, accessed 2026-09-19): one-word
framing change 0/20 → 20/20; correct option first 95/108 against fourth 62/108, a 30.6-point position
swing; counting tasks 117/216 overall and "raven" miscounted 18/18. The author labels the study a
synthetic probe with post-hoc design decisions disclosed, so treat the magnitudes as indicative and the
direction as established. Running a second paraphrase costs one extra question in the same call — adding
questions "barely changes the response time and costs only the tokens for the extra questions"
(https://docs.typesafe.ai/primitives.md) — roughly a few thousandths of a cent at $0.042 per million
input tokens with output free (https://docs.typesafe.ai/models.md).

## When the verdict flips

It flips to **conditional** as soon as the variance is measured rather than assumed: two or more
paraphrases per decision point, permuted option order, a labelled sample large enough to see a 5-point
difference, and the disagreement rate published alongside the accuracy number. Decomposing into several
atomic questions and combining them in code also dilutes any single phrasing's influence — but see
`au-over-decompose-when-one-question-works`, because decomposition has its own failure mode.

## Alternatives considered

- **Regex / deterministic**: immune to framing; use it wherever the signal is lexical.
- **Small LLM**: same sensitivity, usually worse, and no typed probability to compare variants with.
- **Frontier LLM**: less position-sensitive in published work but not immune; too slow to run variants
  on every item.
- **Fine-tuned classifier**: learns from labels rather than phrasing, which removes this class of bug.
- **Embeddings**: no question to phrase; different failure modes.
- **Human**: needed to adjudicate the items where paraphrases disagree.

## Sources

- https://github.com/RINNECODER/jev-behavior-study — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
- https://docs.typesafe.ai/primitives.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
