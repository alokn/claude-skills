---
id: au-exact-grade-prediction-high-stakes
title: Do not use jev to predict an exact grade or score that decides someone's outcome
verdict: no
domain: education
decision_shapes: [scoring]
primitives: [score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  ("Math using score"; score levels "weak in numerical calibration")
  - https://docs.typesafe.ai/primitives/score.md  ("Different distributions can produce the same score"; "Describe situations, not degrees")
  - https://docs.typesafe.ai/concepts/system-one.md  ("Calibration ... does not guarantee that an individual answer is correct")
  - https://docs.typesafe.ai/confidence.md  ("Low confidence: Do not act")
related: [au-interpolate-magnitude-from-score, au-payments-and-access-control-decision, au-legal-determinations-without-counsel]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to award the final mark on these exam essays?" Also "score candidates out
of 100 and cut the bottom half", "assign the performance-review rating with jev", "give each application
a credit grade from A to G".

## Verdict

**No** as the deciding score. Two independent disqualifiers stack. The numeric one: jev's "score levels
are weak in numerical calibration", so a `score` of 6.4 on a ten-level rubric is not a mark out of ten —
see `au-interpolate-magnitude-from-score`. The individual-case one: "Calibration is measured across groups
of predictions; it does not guarantee that an individual answer is correct." A grade is consumed one
person at a time, and the person affected is entitled to a decision that is right for them, not one drawn
from a well-calibrated distribution.

Closest failure mode: **math and counting** — a grade is a magnitude, and Score levels are
"weak in numerical calibration", so code computes any mark from rubric answers rather than
reading it off a score.

## What jev would get wrong

The `score` looks like a mark and is not one. The Score page shows why: it is "a probability-weighted mean
of the level numbers", and "Different distributions can produce the same score. A score of 1.0 can mean
all probability is on level 1, or half is on each of levels 0 and 2." A candidate the model is genuinely
torn about and a candidate it confidently places in the middle receive identical marks. There is also no
appeal surface: a Score returns no rationale — System One models "do not ... generate explanations of
their reasoning" — so you cannot tell the person why, which most graded settings require.

## What stays in code

The mark, the weighting, and the record. Code combines per-dimension judgements with weights you can show
and defend, code applies any deterministic rubric elements (word count, required sections, submitted on
time), and code holds the audit trail of who confirmed the grade.

Jev's defensible contribution is per-dimension, ordinal, and advisory: a Score over four or five described
levels for "how clearly is the thesis stated", another for "how well is the claim supported by cited
evidence", a Noul "Does `essay` address the question asked?", a Noul "Does `essay` contain unattributed
text matching `source`?" Each level must describe a situation, not a degree — "Describe situations, not
degrees. 'Broken or degraded feature, but workaround exists' gives the model something to match the state
against. 'Moderately severe' doesn't." A marker reads these and assigns the grade.

## Numbers

Score criteria accept 2 to 10 levels (https://docs.typesafe.ai/primitives/score.md). A 1,200-word essay
with six dimensions is roughly 2,200 input tokens, about $0.00009 at $0.042 per million input tokens with
output free (https://docs.typesafe.ai/models.md), typically about 100 ms — cheap enough to pre-score every
submission. No published source measures jev's agreement with
human markers; TypeSafe's own workflow evals report 67.8% combined accuracy against Opus 5's 73.1% on
unrelated tasks (https://evals.typesafe.ai, read 2026-09-19).

## When the verdict flips

It flips to **conditional** when jev advises and a human decides. The conditions: several narrow
dimensions rather than one overall mark; four to six levels each describing a concrete situation; the
final grade computed in code from weights that are published; a measured agreement study against human
markers on your own scripts before launch; and the low-confidence band routed to a second marker, per
"Low confidence: Do not act. Route to a human." It also flips to **good** for pure triage — ordering the
pile so markers see the borderline scripts first. It never flips to an unattended grade of record;
**no rewrite exists** for that, because the barrier is accountability, not accuracy.

## Alternatives considered

- **Regex / deterministic**: word counts, structure checks, submission deadlines, required citations.
  Exact and uncontestable.
- **Small LLM**: worse calibration and no typed rubric.
- **Frontier LLM**: better qualitative judgement and can explain itself; not the grade of record.
- **Fine-tuned regressor / automated essay scoring model**: the established tool when you have thousands
  of human-marked scripts; still normally deployed as a second marker.
- **Embeddings**: plagiarism and near-duplicate detection across the cohort.
- **Human**: the marker of record.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/primitives/score.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
- https://evals.typesafe.ai — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
