---
id: au-expect-headline-speed-cost-multipliers
title: Do not budget on the 193x faster / 444x cheaper headline
verdict: weak
domain: finance
decision_shapes: []
primitives: []
evidence_level: independent-benchmark
sources:
  - https://typesafe.ai/blog/introducing-system-one-models-and-jev  ("we expect that these are on the higher end of real world gains")
  - https://openchamber.dev/blog/jev-typesafe-ai/  (median 7x speed across 215 figures; median 30x cost across 180 figures; 12,759 posts)
  - https://github.com/wotai-dev/typesafe-jev-tools  (p50 455 ms vs Haiku 4.5 631 ms on 150 passages)
  - https://docs.typesafe.ai/models.md  ($0.042 per Mtok input, output free)
related: [au-replace-vector-retrieval-with-jev-rerank, au-tiny-volume-human-reviewed-workflow, df-cost-model]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to write '193x faster, 444x cheaper' into our business case?" Also "we'll cut the AI
bill by two orders of magnitude", "the migration pays for itself because jev is 400x cheaper".

## Verdict

**Weak** as a planning assumption — TypeSafe says so itself, and an independent survey quantifies the gap.
The launch post: "This is where the claims of 193.6x faster, 444.6x cheaper on our home page comes from,
and we expect that these are on the higher end of real world gains." The survey of public reports found
"Median 7× across 215 figures, with quartiles of 2× and 20×" for speed and "Median 30× across 180 figures,
with quartiles of 5× and 85×" for cost (https://openchamber.dev/blog/jev-typesafe-ai/).

Not a model failure: **economic** veto — a budgeting error, not a model defect.

## What jev would get wrong

Nothing — the model performs as documented. The error is in the comparison. The headline figures come from
TypeSafe's own workflow evals, built by "individuals on our model capabilities team, so some bias could
exist", comparing jev against frontier models. Your baseline is probably a small model, a free keyword
rule, or a batched LLM call. Three
ways a projection inflates: comparing a batched jev call against unbatched LLM calls; forgetting that you
still need a generative model for the parts jev cannot do; and ignoring the engineering time to decompose,
evaluate, and tune thresholds.

## What stays in code

The measurement. Instrument the incumbent — p50 and p95 latency, cost per call including output tokens,
parse-failure rate — then shadow jev on the same traffic and compare like with like. Quote per-call
figures with the inputs shown, and never a monthly figure without a measured volume.

The durable, defensible claims are the ones that are structural rather than comparative: $0.042 per
million input tokens with output free; typical latency about 100 ms with a 70-500 ms range; a schema that
cannot be violated, so parse failures go to zero; and probabilities trained to be calibrated, whose
calibration you measure on your data before you threshold on them. Those
hold regardless of what you are migrating from.

## Numbers

Claimed: "193.6× on the homepage, 20 to 200× in the launch thread" for speed; "444.6× on the homepage, 40
to 400× in the launch thread" for cost. Measured across public reports: median 7× speed, median 30× cost,
from "26,896 tweets" filtered to "12,759 relevant posts with usable content" collected 15-18 September
2026. The survey's own caveats matter: "This is a survey of public reports, not an independent benchmark.
We did not rerun the experiments", and "People may publish successful experiments more readily than failed
ones". A controlled head-to-head found a narrower speed margin still: jev p50 455 ms against Claude Haiku
4.5 at 631 ms over 150 passages and 2,400 calls, run 2026-09-18
(https://github.com/wotai-dev/typesafe-jev-tools).

- Field evidence (community-report): two field reports measured latency well above the published 70-500 ms — HA-Jev (AboveColin) reports it "slower from Europe than the published 70 to 500 ms", and dev.classmethod.jp (Morinaga Taishi, 40 calls, 10 per tier) measured median 0.643-0.674 s at $0.000025-$0.000027 per call, 2026-09-17. Sources: https://github.com/AboveColin/HA-Jev and https://dev.classmethod.jp (article dated 2026-09-17; full URL not recorded in `50-sources/`)

## When the verdict flips

It flips to **good** when the number is yours. Run the incumbent and jev side by side on a sample of your
own traffic, with both batched as they would be in production, and quote the ratio you measured with the
inputs shown. Against a frontier-model-per-label incumbent, gains at the high end of the published range
are plausible; against a small model or a free regex, they are not. Use median 7× speed and median 30×
cost as the planning range until you have your own figures, and note the quartiles — 2× to 20× and 5× to
85× — because the spread is the honest part of the finding.

## Alternatives considered

- **Regex / deterministic**: $0 in compute; the saving is maintenance and misroutes, so say which you
  are counting.
- **Small LLM**: the hardest baseline to beat on cost-per-decision; measure it, do not assume.
- **Frontier LLM**: the baseline the headline multipliers were computed against.
- **Fine-tuned classifier**: often cheapest per call once hosted, with training and MLOps cost a
  projection must include.
- **Embeddings**: near-free per call; not a substitute for a judgement.
- **Human**: the only baseline where order-of-magnitude savings are usually real — a labour cost, not a
  compute one.

## Sources

- https://typesafe.ai/blog/introducing-system-one-models-and-jev — accessed 2026-09-19
- https://openchamber.dev/blog/jev-typesafe-ai/ — accessed 2026-09-19
- https://github.com/wotai-dev/typesafe-jev-tools — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
