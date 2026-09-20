---
id: au-zero-hallucination-means-always-right
title: Do not read "cannot hallucinate" as "cannot be wrong"
verdict: no
domain: ml
decision_shapes: []
primitives: [choice, noul, score]
evidence_level: community-report
sources:
  - https://typesafe.ai/blog/introducing-system-one-models-and-jev  ("it's optimized for structured outputs and can't hallucinate"; "Our number is not empirical. Schema matching is guaranteed")
  - https://news.ycombinator.com/item?id=49717558  ("it can still emit a completely wrong valid value"; "Type safety is not factual correctness")
  - https://docs.typesafe.ai/concepts/system-one.md  ("Calibration is measured across groups of predictions; it does not guarantee that an individual answer is correct")
  - https://evals.typesafe.ai  (67.8% combined accuracy vs Opus 5 73.1%)
related: [au-payments-and-access-control-decision, au-sole-security-gate, au-expect-headline-speed-cost-multipliers, au-review-loop-pass-fail-gate]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to remove our human review step because jev can't hallucinate?" Also "the output is
type-safe so we don't need validation", "zero hallucination means we can auto-apply the answer", "we
don't need an eval, it's guaranteed correct".

## Verdict

**No.** The guarantee is real and it is narrower than the phrase suggests. The launch post's own framing
is "While Jev gives up string generation, it's optimized for structured outputs and can't hallucinate",
and in the same post: "Our number is not empirical. Schema matching is guaranteed, thus we can confidently
add 0% into the plots." What is guaranteed is schema conformance. The Hacker News discussion of the launch
puts the distinction bluntly: "it can still emit a completely wrong valid value", and "Type safety is not
factual correctness."

Closest failure mode: **structural invariants** — schema conformance is what is guaranteed; a
valid value can still be the wrong one, so accuracy has to be measured separately.

## What jev would get wrong

The same things any model gets wrong, in a well-formed way. Ask "which team owns this ticket?" over eight
teams and you always receive one of those eight; you do not always receive the right one. TypeSafe's own docs make the limit explicit: "Calibration is measured across
groups of predictions; it does not guarantee that an individual answer is correct." A commenter on the
launch thread extends the point to confidence: "if it puts a high confidence value on a wrong answer,
thats still hallucinating." And because a Choice is relative and always selects something, an input
outside your option set is absorbed rather than refused — "if the user input is outside of the range of a
boolean, it's forced to hallucinate. It can't abstain" — unless you supplied an explicit `other` or
`none of the above` option.

## What stays in code

Everything the schema guarantee does not cover. Semantic validation (does the chosen team exist and is it
accepting work), cross-checks against your own records, the confidence gate, the review queue, and the
audit log. Also the `other` / `none of the above` option in every Choice whose option list might not cover
an input, which is the mechanism that gives the model somewhere to put "I don't recognise this".

What you correctly stop writing is parse-failure handling: no JSON repair, no retry-on-malformed, no
regex over prose. That is the whole of what "can't hallucinate" buys.

## Numbers

TypeSafe's own workflow evals place jev at 67.8% combined accuracy against Opus 5 at 73.1%, Sonnet 5 at
67.8% and Luna at 66.8%, with its weakest categories at 61.8% (invoice processing) and 61.7% (security
incidents) (https://evals.typesafe.ai, read 2026-09-19). An independent head-to-head found jev and Claude
Haiku 4.5 tied at 66.0% accuracy over 150 passages and 2,400 calls, with jev abstaining on 34.7% of cases
against Haiku's 2.7% and calibration error of 0.121 against 0.122
(https://github.com/wotai-dev/typesafe-jev-tools, run 2026-09-18). Roughly a third of answers are wrong.
That is the number a "no review needed" plan has to survive.

## When the verdict flips

It does not — **no rewrite exists**, because the claim being corrected is a claim, not a task. What the
guarantee legitimately supports: deleting output-parsing code, deleting schema-validation retries, and
trusting that a returned value is one of yours. What it does not support: deleting the eval, the
confidence gate, or the human review path. The honest framing to use in a design document is "the output
is type-safe and the probabilities are trained to be calibrated; calibration and accuracy are both
unknown until we measure them on our data."

## Alternatives considered

- **Regex / deterministic**: cannot be wrong where the rule is exact. A different guarantee from jev's.
- **Small LLM with structured output**: as one commenter notes, "You can enforce structured output from an
  LLM too" — schema conformance is not unique to jev.
- **Frontier LLM**: higher accuracy on the same workflows (73.1% for Opus 5), still no correctness
  guarantee.
- **Fine-tuned classifier**: also constrained to its label set, also wrong sometimes.
- **Embeddings**: no guarantees at all.
- **Human**: the reviewer this claim argues away. Keep them on the low-confidence band.

## Sources

- https://typesafe.ai/blog/introducing-system-one-models-and-jev — accessed 2026-09-19
- https://news.ycombinator.com/item?id=49717558 — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-19
- https://evals.typesafe.ai — accessed 2026-09-19
- https://github.com/wotai-dev/typesafe-jev-tools — accessed 2026-09-19
