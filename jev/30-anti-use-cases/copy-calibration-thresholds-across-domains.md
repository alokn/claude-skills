---
id: au-copy-calibration-thresholds-across-domains
title: Do not carry a confidence threshold from one dataset or domain to another
verdict: no
domain: ml
decision_shapes: [routing, scoring, classification]
primitives: [choice, score]
evidence_level: independent-benchmark
sources:
  - https://github.com/FirasSX914/Janus  (Banking77 routes at 0.67; Web of Science "DO NOT ROUTE")
  - https://github.com/yodablocks/jev-orderby-bench  (ECE 0.045 on 20 Newsgroups, 0.242 on Amazon ESCI, same primitive)
  - https://github.com/wotai-dev/typesafe-jev-tools  (ECE 0.121 on decision triage, n=149)
  - https://docs.typesafe.ai/confidence.md  ("The correct threshold values depend on your domain")
related: [au-confidence-as-correctness-gate, au-zero-hallucination-means-always-right, au-expect-identical-results-across-runs, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to reuse the 0.8 confidence cut-off that worked on our support tickets for the new
product-relevance model?" Also "what is the right default threshold for jev?", "we calibrated in
staging on last quarter's data, can we ship that threshold?", "our vendor published a threshold, can we
copy it?".

## Verdict

**No.** A threshold is a property of your data and your cost of error, not of jev. The docs say so in
plain words — "The correct threshold values depend on your domain and the performance of the model for
your use case. Start with conservative thresholds, test with your own data, and adjust as you observe
results" — and the independent evidence puts numbers on how far apart two domains can sit. The three
published independent calibration figures disagree by task: ECE 0.045, 0.121 and 0.242.

Not a model failure: **governance** veto — a threshold is a property of your data and your
cost of error, so it is re-fitted per domain rather than inherited.

## What jev would get wrong

Nothing, necessarily — the model may be perfectly calibrated on one dataset and badly calibrated on the
next, and you cannot tell which from the confidence number alone. Two independent studies ran the same
primitive on two datasets each and got opposite answers. yodablocks' pre-registered ORDER BY gates
passed on 20 Newsgroups topic membership (ECE 0.045, inversion 0.036, 360 labelled rows) and failed on
Amazon ESCI graded product relevance (ECE 0.242, inversion 0.255, 306 pairs, 23 of 30 queries over
threshold, with the "Complement" grade ranked below "Irrelevant"). Same model version, same question
shape, five times the calibration error. FirasSX914/Janus ran confidence routing to a fallback model on
two datasets of 500 items each: Banking77 routed at threshold 0.67 for 80.2% accuracy (+1.4 pt), −53%
cost, p50 302 ms and 11.6% escalation; Web of Science produced the verdict "DO NOT ROUTE". A default
threshold "would therefore be wrong roughly as often as it was right".

## What stays in code

The threshold table, the labelled sample it was fitted on, and the re-fit job. Concretely: hold out a
few hundred labelled items per decision point; plot confidence against accuracy on that sample, which
the docs prescribe ("Test thresholds by plotting confidence against accuracy on your data"); store one
threshold per decision point rather than one per system, because "Different actions within the same
system should be gated at different levels depending on the consequences of getting it wrong"; and
re-run the fit when the data distribution, the question wording, or the pinned model version changes.
Code also owns the fallback path the threshold selects, and the counter that tells you what share of
traffic is escalating.

## Numbers

ECE 0.045 (20 Newsgroups, 360 rows) against ECE 0.242 (Amazon ESCI, 306 pairs) from the same
pre-registered harness (https://github.com/yodablocks/jev-orderby-bench, accessed 2026-09-19). Routing
threshold 0.67 on Banking77 against "DO NOT ROUTE" on Web of Science, 500 + 500 items
(https://github.com/FirasSX914/Janus). ECE 0.121 on a 149-row decision-triage set, against Claude Haiku
4.5 at 0.122 (https://github.com/wotai-dev/typesafe-jev-tools, run 2026-09-18). A calibration run of 500
items at 800 tokens each is 400,000 input tokens, about $0.017 at $0.042 per million input tokens with
output free (https://docs.typesafe.ai/models.md) — the labels cost more than the inference.

## When the verdict flips

It flips to **conditional** — the only version of this that is safe — when the threshold is fitted on a
labelled sample from the same distribution you will serve, stored per decision point, monitored for
drift, and re-fitted after any change to the questions or the pinned version. Borrowing someone else's
number as a *starting point* for that fit is fine; shipping it is not.

## Alternatives considered

- **Regex / deterministic**: no threshold to tune, and where a rule fits it wins outright.
- **Small LLM**: same problem, plus no typed probability to threshold on.
- **Frontier LLM**: same problem; self-reported confidence is usually worse calibrated.
- **Fine-tuned classifier**: calibrate it on the same held-out sample; the labour is identical.
- **Embeddings**: similarity cut-offs transfer no better; they need the same per-domain fit.
- **Human**: reviews the band below the threshold, which is what the threshold is for.

## Sources

- https://github.com/yodablocks/jev-orderby-bench — accessed 2026-09-19
- https://github.com/FirasSX914/Janus — accessed 2026-09-19
- https://github.com/wotai-dev/typesafe-jev-tools — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
