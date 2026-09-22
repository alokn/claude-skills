---
id: uc-data-ml-order-by-probability-topic-membership
title: Sort rows by a jev probability, for binary topic membership only
verdict: conditional
domain: data-ml
decision_shapes: [ranking, scoring, classification]
primitives: [noul]
evidence_level: independent-benchmark
sources:
  - https://github.com/yodablocks/jev-orderby-bench  (pre-registered ranking gates; 20 Newsgroups ECE 0.045 / inversion 0.036 passes, Amazon ESCI ECE 0.242 / inversion 0.255 fails)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (jaggedness modes)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-data-ml-semantic-predicates-in-sql, uc-observability-evals-confidence-threshold-calibration-fitting, au-interpolate-magnitude-from-score, uc-search-retrieval-rerank-keyword-shortlist, uc-commerce-listing-category-normalisation]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to `ORDER BY` a jev probability?" Also: "can I rank my rows by how likely
they are to be about X?", "is the probability a usable sort key or just a threshold?", "can we
use it to rank product relevance?".

## Verdict

**Conditional**, and the condition is narrow: **binary-ish membership only** ("is this row
about X"), never a graded relevance scale, and you run the calibration gates on your own data
before shipping the sort. This is not a caution, it is a measurement. One pre-registered study
put identical gates in front of the same primitive on the same model version and got opposite
answers: 20 Newsgroups topic membership passed at **ECE 0.045, inversion 0.036** over 360
labelled rows, and Amazon ESCI graded product relevance failed at **ECE 0.242, inversion
0.255** over 306 pairs, with "23/30 queries over threshold" and — the detail that tells you
what broke — the "Complement" grade ranked *below* "Irrelevant". A sort key that inverts two
adjacent grades is not a sort key.

## What jev decides

One `Noul` per row, absolute and independent of the other rows.

```
about_topic: Noul
  instructions: {question: "Is this document about `topic_name`?",
                 focus: "What the document is about, not what it mentions."}
  true:  "The document's subject is `topic_name`: it is the thing being discussed, argued
          about or reported."
  false: "`topic_name` appears in passing, as an analogy, in a signature, or as one item in
          a list of many."
```

The probability is the sort key and nothing else. Rows are scored independently, so there is
no position or ordering effect between them — that independence is what makes a sort
defensible at all, and it is why a listwise LLM ranking is a different (and more fragile)
thing.

Do **not** ask a graded question ("how relevant is this, 0 to 3"). That is the ESCI shape, and
it is the one that failed. If you need grades, use separate binary questions for separate
grade boundaries and compose in code, and re-run the gates.

## What stays in code

The gates themselves, run once before you ship and again on drift: expected calibration error,
pairwise inversion rate against a labelled sample, and the fraction of queries whose scores sit
above your threshold. Pre-register them — the value of that study is entirely that the gates
were fixed before the scoring. Also in code: every deterministic filter applied before the
scoring pass, tie-breaking (never let the model break ties — use recency or id), the `LIMIT`,
and all arithmetic on the scores (mode 2).

## Numbers

Verbatim from github.com/yodablocks/jev-orderby-bench:

| Dataset | n | ECE | Inversion | Gates |
|---|---|---|---|---|
| 20 Newsgroups, topic membership | 360 labelled rows | 0.045 | 0.036 | **passes** |
| Amazon ESCI, graded product relevance | 306 pairs | 0.242 | 0.255 | **fails** |

On ESCI, "23/30 queries over threshold" and the "Complement" grade ranked below "Irrelevant".
Source reliability, from the corpus evidence table: gates set before scoring (low bias risk),
single English domain each.

Cost by method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A
1,500-character document plus one question with criteria (~700 characters) is about 550
tokens, **≈ $0.0000231 per row** — cheap enough that the gates, not the bill, are what decide
this. For context on how far calibration moves between tasks, the three independent ECE
figures in the corpus are 0.045 (newsgroups), 0.121 (decision triage) and 0.242 (ESCI).

## When the verdict flips

- **Your labels are a graded scale** (exact / substitute / complement / irrelevant, or 1-5
  stars). ESCI is that shape and it failed; this becomes `no` until your own gates say
  otherwise.
- **Your own gates fail.** Run them. ECE 0.045 on someone else's corpus predicts nothing about
  yours — that is the finding, not a caveat on it.
- **The ordering drives money or exposure** (search ranking that sets revenue, a queue that
  sets who gets helped). Then the inversion rate matters more than the mean and you need a
  much larger labelled sample than 300 rows.
- **You interpolate magnitude from the score** ("0.8 means twice as relevant as 0.4"). It does
  not mean that.
- **Rows are compared inside one call.** Independence is the property doing the work; batching
  candidates into a single question reintroduces position effects.

## Alternatives considered

- **Deterministic sort (recency, price, count).** Free and exact; the right answer whenever
  the intent is not semantic.
- **Embeddings + cosine.** Continuous, cheap, and a genuinely good sort key for similarity;
  uncalibrated, so the number is a ranking device only — which is all you need for `ORDER BY`.
- **Cross-encoder reranker.** Purpose-trained for graded relevance, which is exactly where jev
  failed; the right tool for the ESCI shape.
- **Learning-to-rank on your own click data.** The destination if ranking is the product.
- **Threshold instead of sort.** Often the honest reduction: a thresholded yes/no plus a
  deterministic secondary sort avoids relying on the score's spacing at all.

## Sources

- https://github.com/yodablocks/jev-orderby-bench — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
