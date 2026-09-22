---
id: au-interpolate-magnitude-from-score
title: Do not interpolate an exact magnitude from a Score
verdict: no
domain: ml
decision_shapes: [scoring]
primitives: [score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  ("Math using score": do not compute the exact magnitude between two levels)
  - https://docs.typesafe.ai/primitives/score.md  ("Different distributions can produce the same score"; "Needs at least two levels and takes up to 10")
related: [au-average-noul-with-choice, au-exact-grade-prediction-high-stakes, au-numeric-thresholds-and-arithmetic]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to read a Score of 1.45 on a three-level severity rubric as 'severity 4.8 out of 10'?"
Also "convert the frustration score into an NPS estimate", "our rubric levels are $0, $500, $2,000 — can
we read the score as a dollar figure", "multiply the score by 20 to get a percentage".

## Verdict

**No.** The jaggedness page has a section for this, headed "Math using score": "Please do not use score
outputs (e.g., expectations and probability) to compute the exact magnitude of a number between two levels
of a criterion. You can use the expectation to check if it passes a particular threshold, but
`jev-1.13`'s score levels are weak in numerical calibration. It will not be able to help you reconstruct
the exact number by interpolating between the nearest two levels." The permitted use — thresholding — is
stated in the same sentence as the prohibited one.

Closest failure mode: **math and counting** — interpolating a magnitude between score levels
is the arithmetic the jaggedness page prohibits; thresholding is the permitted use.

## What jev would get wrong

The returned `score` is not a measurement on your scale; it is a probability-weighted mean of level
*positions*. The Score primitive page makes the consequence concrete: "The score is a probability-weighted
mean of the level numbers", and "Different distributions can produce the same score. A score of 1.0 can
mean all probability is on level 1, or half is on each of levels 0 and 2." Those two situations are
completely different states of the world and they produce an identical number. Interpolating a dollar
amount, a percentile, or a count from that number invents precision that was never in the answer, and the
invented figure will look authoritative in a report.

## What stays in code

Thresholds and ordering. Code compares the score against a cut-off you tuned on your own data, and code
sorts items by score to prioritise a queue. Both are explicitly sanctioned. Code should also read
`probabilities` and `confidence` alongside the score, because the Score page says to: "Read
`probabilities` and `confidence` alongside the score to distinguish these cases."

If you need an actual magnitude, get it the way magnitudes are got. Either the number exists in the data,
in which case code extracts and computes it, or it does not, in which case define more levels that
describe concrete situations — "Use as many levels as you can describe distinctly, up to 10" — and treat
the resulting level as an ordinal bucket, not a value. A Score takes at least two levels and at most ten,
so ten buckets is the finest resolution available, and each must be describable.

## Numbers

Score criteria accept 2 to 10 levels (https://docs.typesafe.ai/primitives/score.md). Adding levels costs
only their description tokens at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md). No source publishes a numerical-calibration figure for jev's score
expectation; the docs state the weakness qualitatively, which is enough to rule the interpolation out.

- Field evidence (independent-benchmark): yodablocks/jev-orderby-bench, 306 Amazon ESCI pairs — inversion rate 0.255 and the "Complement" grade ranked *below* "Irrelevant", i.e. the expectation did not even preserve the intended order of the levels, let alone their spacing; ECE 0.242 on the same run, 2026-09-19. Source: https://github.com/yodablocks/jev-orderby-bench

## When the verdict flips

For reconstructing an exact number, **no rewrite exists** — the docs prohibit it directly. Two adjacent
uses are **good**: (1) thresholding, which the same paragraph permits — "You can use the expectation to
check if it passes a particular threshold"; (2) ranking, where only the order matters. A third flips to
**conditional**: if you need finer granularity, expand to more levels, each describing a concrete
situation rather than a degree, since the Score page warns that "Describe situations, not degrees" and
that levels made only of numbers leave the model "nothing to match against". Even then, read the result as
a bucket.

## Alternatives considered

- **Regex / deterministic**: if the magnitude is stated in the text, parse it. Exact and free.
- **Small LLM / frontier LLM**: will happily emit a precise-looking number with no better grounding, and
  without a probability trained to be calibrated to warn you.
- **Fine-tuned regressor**: the correct tool when you genuinely need a continuous estimate and have
  ground-truth values to train on.
- **Embeddings**: no role.
- **Human**: supplies the ground-truth magnitudes a regressor would need.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/primitives/score.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
