---
id: uc-data-ml-map-reduce-corpus-labelling
title: Label a large corpus row by row and aggregate the labels in code
verdict: good
domain: data-ml
decision_shapes: [classification, detection, scoring]
primitives: [choice, noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (AI Map Reduce over Big Data: "100x cheaper means you can process giant datasets")
  - https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md  (2,000 requests per round; 8 workers "already enough to hit a rate limit on a shared key")
  - https://docs.typesafe.ai/cookbooks/parallel_questions.md  (13 questions in one call: 12.2x cheaper, 10.0x faster, same answers)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 250k tokens/s, 1,200 requests/min)
related: [uc-data-ml-text-features-for-tabular-model, uc-agents-harness-agent-trace-classification, uc-data-ml-transcript-coding-codebook]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to label our whole corpus instead of a sample?" Also: "we have 4
million reviews and only ever read 200", "can we backfill a category column across the history?",
"what does a full-population labelling run actually cost?"

## Verdict

**Good** — the shape is demonstrated by the use-case map and the `parallel_questions`
cookbook; no task-matched labelled accuracy is published; shadow-evaluate against the
incumbent before acting. This is a named headline category — "AI Map Reduce over Big
Data ... 100x cheaper means you can process giant datasets" — and the economics are the
whole argument: output tokens are free, every question shares one state, and a
twenty-label taxonomy costs the same request as one label. The condition is engineering,
not modelling: rate limits, retries, idempotent checkpointing and a cost estimate from a
pilot before the full run.

## What jev decides

One request per row, all labels fanned out. State is the *reduced* row — the fields the questions
need, not the record.

```python
"topic": Choice(instructions="What is this text mainly about?", criteria={...,"other": "None of these fits"}),
"mentions_price":   Noul("Does the text comment on price or value for money?"),
"mentions_delivery":Noul("Does the text comment on delivery, shipping, or packaging?"),
"sentiment": Score(instructions="How favourable is the text about the product?",
  criteria=["Strongly negative", "Mildly negative", "Mixed or neutral", "Mildly positive", "Strongly positive"]),
```

Multi-label means one Noul per label, never a Choice: a Choice is relative and always picks a
winner. Always include `other`/`none` in a Choice. Keep `confidence` and the probabilities in the
output table — a population label set is far more useful with an explicit low-confidence slice
than with everything forced into a bucket.

## What stays in code

Row selection and filtering, the reduction of each row to the fields the questions need (mode 5),
the worker pool and throttle, retry-with-backoff on 429/529, checkpointing so a restart does not
re-pay, deduplication by content hash, every aggregation and count, and the schema of the output
table. Aggregate statistics are arithmetic — never ask jev "how many rows mention price".

## Numbers

Cost scales with rows, not questions. A 400-token row with twelve questions is roughly 700 input
tokens, about $0.00003 per row at $0.042 per million input tokens with output free — about $30
per million rows. That estimate is a calculation from the published price, not a measured
benchmark; run a 1,000-row pilot and multiply the measured `usage.input_tokens`.

Batching is what makes the taxonomy nearly free: the parallel-questions cookbook measured 13
questions over one 53,777-character document as one call at $0.000497 and 0.27s against 13 calls
at $0.006090 and 2.71s — "12.2x cheaper, 10.0x faster" with identical answers. The saving grows
with how document-dominated the workload is, so "N questions over a short state will not approach
Nx."

Throughput: rate limits at the time of writing are 250,000 tokens per second and 1,200 requests
per minute, adjusting dynamically, with higher limits on enterprise plans. The feature-discovery
cookbook ran "one request per row per round, so 100,000 rows is 100,000 requests a round" with a
pool of 8 — and notes "Eight is already enough to hit a rate limit on a shared key."

Consistency is what makes a population run comparable over time: in the parallel-questions run,
eleven of thirteen questions returned identical means with "std dev exactly 0.0" across 5 runs,
and the two noisy ones were noisy "regardless of batching".

Closest jaggedness mode: **5, large state full of irrelevant detail** — the per-row reduction is
the design; and **2**, because every aggregate is code's job.

## When the verdict flips

- **The label is deterministic.** A field, a regex, a lookup. Backfill it with SQL; that is exact
  and free.
- **The taxonomy is not yet known.** Cluster or read a sample first. Jev classifies into labels
  you define; it will not discover them.
- **The corpus is not English.** English is the primary training language and other languages are
  "accepted with lower accuracy". Evaluate per language before a full run.
- **Rows contain regulated data** and the workload cannot leave your infrastructure. Hosting is
  cloud only (US West); zero data retention is an enterprise term.
- **You need a defensible accuracy number.** Label a stratified sample by hand and measure
  agreement first; TypeSafe's own evals put jev mid-table (67.8%) on agreement with a two-model
  reference, not on human ground truth, and publish no abstention curve, so a population run
  without a measured sample is not evidence.
- **The judgement needs multi-hop reasoning across rows.** One call sees one row. Cross-row
  reasoning is code's job, or a second pass over an aggregate.

## Alternatives considered

- **SQL, regex and keyword rules** — free and exact where the label is lexical; keep them, and use
  them to pre-filter which rows are worth a call.
- **Frontier LLM labelling** — the incumbent, and the reason most teams label 200 rows instead of
  4 million; orders of magnitude more expensive per row with output tokens charged.
- **Small LLM labelling** — the real competitor at this scale: cheap, batchable, self-hostable.
  Jev wins on typed output (a label outside your taxonomy is impossible) and on free output
  tokens. Do not add run-to-run stability to that list: the choices cookbook found
  `claude-haiku-4-5` at temperature 0 more repeatable than jev (100.0% against 90.8% raw, SD
  0.0012 against 0.0098). A small LLM may win on unit cost if you own the hardware.
- **Fine-tuned classifier** — cheapest at inference and the right destination once you have
  labels; jev is a fast way to produce the first labelled set and to cover new labels immediately.
- **Embedding clustering** — discovers structure, does not assign your named categories.
- **Human annotation** — the ground truth to measure against, on a sample.

## Sources

- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/parallel_questions.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
