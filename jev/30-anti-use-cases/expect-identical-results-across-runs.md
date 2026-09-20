---
id: au-expect-identical-results-across-runs
title: Do not expect jev to return identical results on a rerun
verdict: no
domain: ml
decision_shapes: [classification, scoring, routing, verification]
primitives: [choice, score, noul]
evidence_level: independent-benchmark
sources:
  - https://docs.typesafe.ai/confidence.md  ("Determinism ... is less valuable than consistency ... Jev is designed for consistency")
  - https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md  (90.8% repeated plurality labels vs Haiku at temperature 0 at 100.0%)
  - https://github.com/4esv/jev-eval  (1.7-3.3% label variance across runs)
  - https://github.com/bestdan/workflow-skills/pull/757  (confidence swinging 0.16-0.48 between runs on the same item)
related: [au-single-question-framing-sensitivity, au-confidence-as-correctness-gate, au-zero-hallucination-means-always-right, cb-consistency_choice_cookbook]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to assume the same input gives the same answer, so we can cache, diff, or snapshot-test
it?" Also "is jev deterministic?", "our CI test flaked — is that a bug?", "why did the confidence change
when nothing changed?".

## Verdict

**No.** TypeSafe distinguishes the two properties itself: "Determinism means returning the same result for
an identical input. This is less valuable than consistency. We define consistency as making similar
decisions when the meaning stays similar, even if the wording changes. Jev is designed for consistency."
The corpus rule follows: run-to-run repeatability is not a jev differentiator. TypeSafe's own
self-consistency cookbook measures `claude-haiku-4-5` at temperature 0 repeating its plurality label
100.0% of the time against jev's 90.8% raw — and notes that repeatability does not imply correctness.

Closest failure mode: **structural invariants** — the schema is the guarantee, determinism is
not, so code must tolerate a label that moves between runs rather than assume a fixed one.

## What jev would get wrong

The label near a threshold, on a rerun, for no reason you can see. Two failure shapes show up in the
field. Labels move: 4esv measured 1.7-3.3% label variance across runs of the same 300-row sets. Confidence
moves further: the bestdan assessment saw confidence swing 0.16-0.48 between runs on the same item, which
is enough to cross any gate you set. TypeSafe's own numbers show why — mean per-question probability
standard deviation 0.0102 sounds tiny until the covered answers "span 0.43 to 0.53, crossing a 0.5
decision threshold", and jev flips on 2 of 8 questions in that run. Downstream, shiftynick's `jev-axi`
file-ranking skill "showed inconsistent results across sessions (appearing as either 25% savings or 29%
penalty)", which is the same instability measured at the product level.

## What stays in code

Idempotency, caching and the test strategy. Cache the decision against a hash of the state and the
question set, so a repeat of the same input reuses the stored answer instead of re-rolling it — this also
removes a class of user-visible flapping. Never snapshot-test an exact probability: assert the branch, or
assert a band, and run the assertion over a labelled set with a tolerance derived from your own measured
variance. Keep a hysteresis margin around every threshold (act at 0.75, revert at 0.65) so an item near
the line does not oscillate between states, and log the version, the probabilities and the confidence
with every stored decision so a later disagreement is diagnosable.

## Numbers

Official: jev repeats its plurality label 90.8% of the time, against LLM distribution settings at
87.5-100.0% and `claude-haiku-4-5` at temperature 0 at 100.0%; mean per-question probability standard
deviation 0.0102; answers spanning 0.43-0.53 across the 0.5 threshold; 2 of 8 questions flip
(https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md). Independent: 1.7-3.3% label variance across
runs (https://github.com/4esv/jev-eval); confidence swings of 0.16-0.48 on the same item
(https://github.com/bestdan/workflow-skills/pull/757); 25% savings or 29% penalty across sessions on the
same ranking task (shiftynick/jev-axi). A cache hit costs $0 against roughly $0.00005 for a re-ask at
$0.042 per million input tokens with output free (https://docs.typesafe.ai/models.md).

## When the verdict flips

It never flips to "deterministic", but it becomes a non-issue when the design tolerates a few points of
label churn: caching for repeat inputs, hysteresis at thresholds, band assertions in tests, and decisions
that are advisory or reversible. Where a byte-identical answer is a hard requirement — a legal record, a
reproducible build, a signed artefact — **no rewrite exists**; compute it in code or store the first
answer and treat it as authoritative.

## Alternatives considered

- **Regex / deterministic**: bit-identical by construction; the answer where reproducibility is required.
- **Small LLM**: temperature 0 gets closer to repeatable, as the cookbook's Haiku result shows, but is
  not a guarantee across versions.
- **Frontier LLM**: same caveat, slower and dearer.
- **Fine-tuned classifier**: deterministic at fixed weights, which is a real advantage for auditability.
- **Embeddings**: deterministic vectors; the threshold still moves the label.
- **Human**: less repeatable than either, which is the honest comparison.

## Sources

- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md — accessed 2026-09-19
- https://github.com/4esv/jev-eval — accessed 2026-09-19
- https://github.com/bestdan/workflow-skills/pull/757 — accessed 2026-09-19
- https://github.com/shiftynick/jev-axi — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
