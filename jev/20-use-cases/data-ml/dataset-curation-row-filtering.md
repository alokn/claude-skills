---
id: uc-data-ml-dataset-curation-row-filtering
title: Filter rows out of a synthetic or scraped training set against written quality criteria
verdict: good
domain: data-ml
decision_shapes: [classification, detection, feature-extraction]
primitives: [noul, score]
evidence_level: community-report
sources:
  - https://github.com/AkashPriyadarshii/jev-curate  (synthetic-dataset curation: filter JSONL/Parquet rows; no numbers published)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 context rot; mode 2 arithmetic)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-data-ml-map-reduce-corpus-labelling, uc-data-ml-systematic-review-screening, uc-data-ml-text-features-for-tabular-model, uc-verification-document-completeness-checklist, df-cost-model]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to clean a training set?" Also: "we generated 800k synthetic
examples and half are junk — can jev pick the keepers?", "can we filter a scraped corpus
without paying for an LLM pass over every row?", "can jev decide which rows go in the
fine-tune?".

## Verdict

**Good.** Row-level keep/drop against written criteria is the canonical map step: the unit is
one row, the answer set is bounded, the rows are independent, and the whole argument is unit
economics — a per-row frontier-LLM pass over a million rows is a budget conversation, a per-row
jev pass is a rounding error. A public curation tool ships exactly this over JSONL and Parquet.
It is `good` and not `strong` because no source publishes a measured agreement rate between
jev's keep/drop and human curation, and because the failure here is silent: a filter that is
subtly biased does not error, it just ships a skewed model.

Closest failure mode: **large state and context rot** — the design passes one row per call, so
state stays short and the written criteria, not neighbouring rows, decide keep or drop.

## What jev decides

One call per row, several independent Nouls in that one call (parallel questions cost tokens,
not latency). Send the row, not the file — a whole shard in the state is mode 5.

```
on_task: Noul
  instructions: "Does this example actually demonstrate the task described in `task_spec`?"
  false: "It is on-topic but demonstrates something else, or the response ignores the prompt."
truncated_or_incomplete: Noul
  instructions: "Does the text stop mid-sentence, mid-list or mid-code-block?"
answer_leaked_into_prompt: Noul
  instructions: "Does the prompt already contain the answer the response is supposed to derive?"
boilerplate_duplicate: Noul
  instructions: "Is the response mostly template, refusal, or filler rather than content?"
  true: "Apology-and-decline text, a generic preamble with no substance, or repeated stock phrasing."
instruction_following: Score
  criteria: ["Ignores an explicit constraint in the prompt.",
             "Follows the constraints loosely.",
             "Follows every explicit constraint."]
```

Nothing is dropped inside the call. Write all five probabilities back onto the row and let
code apply the cut. That is the difference between a filter you can retune and a filter you
have to re-pay for.

## What stays in code

Exact and near-exact deduplication (minhash, hashing) — free, and it removes the largest slice
before any call. Length, token-count and language-id filters. PII scrubbing. Schema validation
and JSON parsing. The threshold arithmetic, the stratified sample, the train/eval split, and
the shard-level accounting — all mode 2. The Parquet write.

## Numbers

**No accuracy or agreement number is published** for this task. Cost by method:
`input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A row of ~1,200
characters plus five questions with criteria (~2,000 characters) is about 800 tokens,
**≈ $0.0000336 per row** — so a 1,000,000-row corpus is **≈ $34** for one full pass, and a
re-cut against stored probabilities is free. Latency is irrelevant offline; throughput is set
by your concurrency and the rate limits, and note that a public calibration study was cut
short by rate limiting at launch, so plan the batch around them.

Labelled data for calibration comes from hand-curating a stratified sample of ~200 rows: 100
that jev kept and 100 it dropped, sampled across the probability range.

## When the verdict flips

- **You drop rows without sampling the dropped set.** Distribution shift is the real risk and
  it is invisible in aggregate metrics. Hand-check a stratified sample of drops every run;
  without that, the verdict is `conditional`.
- **The criterion is really deduplication or length.** Minhash and a token count do it exactly,
  for free.
- **Quality is graded rather than binary.** Sorting rows by a probability on a graded scale is
  a separate, weaker case — run the calibration gates first.
- **The rows are long documents.** Mode 5; chunk, or ask about an extract chosen in code.
- **Your corpus is mostly non-English** without a per-language check of your own.

## Alternatives considered

- **Heuristic filters (length, perplexity, repetition, n-gram).** Free, fast, and they should
  run first; blind to "on-topic but demonstrates the wrong thing".
- **Minhash / exact dedup.** Exact for the duplicate question, and strictly better than jev at it.
- **A small model scoring each row.** Comparable cost at scale once you have labels; the point
  of jev here is the cold start, when you have none.
- **Frontier LLM pass.** Better judgement and can explain the drop; the cost per million rows
  is the reason this entry exists.
- **A fine-tuned quality classifier.** The right destination once the shadow pass has produced
  a few thousand labelled rows — and jev's stored probabilities plus your hand-checks are that
  training set.
- **Human curation.** The ground truth for the sample, not a strategy for the corpus.

## Sources

- https://github.com/AkashPriyadarshii/jev-curate — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
