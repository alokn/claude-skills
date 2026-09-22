---
id: uc-search-retrieval-negation-sensitive-relevance
title: Judge relevance for queries that contain a negation or an exclusion
verdict: good
domain: search-retrieval
decision_shapes: [ranking, retrieval, detection]
primitives: [noul]
evidence_level: independent-benchmark
sources:
  - https://github.com/anessbelbati/jev-rerank-bench  (NevIR negation pairs: jev 71% vs Cohere Rerank 4 Pro 67%; 14 datasets, 1,617 questions overall)
  - https://docs.typesafe.ai/cookbooks/rerank_typesafe.md  (pairwise noul as a sort key; the false criterion carries the work)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-search-retrieval-rerank-keyword-shortlist, uc-search-retrieval-rrf-fusion-with-dense-retriever, uc-search-retrieval-document-answers-query-gate, au-multi-hop-and-double-negatives, au-replace-vector-retrieval-with-jev-rerank]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev when our search queries contain negations?" Also: "users search
for 'laptop that is not a MacBook' and we return MacBooks — can jev fix that?", "our embeddings
cannot tell 'granted' from 'did not grant' — what do we do?", "can jev filter out the thing the
query excludes?"

## Verdict

**Good.** Negation is the one place where a typed English question is structurally better
suited than cosine similarity, and it is the place jev's clearest measured ranking edge shows
up: **71% against Cohere Rerank 4 Pro's 67%** on NevIR negation pairs
(github.com/anessbelbati/jev-rerank-bench). An embedding of "did not grant the motion" sits
next to an embedding of "granted the motion"; a Noul whose `false` criterion says *"the passage
states the opposite of what the query excludes"* can separate them.

It is `good` and not `strong` for one honest reason: 71% on a benchmark purpose-built around
negation is a modest number. Four points of separation from the best commercial reranker on a
task designed to be its weakness means this is a **reordering signal, not a filter**. Use the
probability to demote; do not use it to delete.

## What jev decides

The state is one query and one candidate. The whole design is in the criteria — restate the
exclusion as a positive property of the wrong answer, so the model is not asked to reason
through the negation itself (jaggedness mode 4, indirection, is the one to avoid here, and
double negatives are a known anti-use case).

```
satisfies_query: Noul
  instructions: {question: "Does the candidate satisfy the query, including the part the query rules out?",
                 focus: "Treat the excluded property as disqualifying, not as a topic hint."}
  true:  "The candidate is the kind of thing the query asks for AND does not have the property
          the query excludes."
  false: "The candidate has the property the query excludes, or is about that property,
          even if it is otherwise a close match on topic."
```

Where the exclusion is enumerable, split it. One Noul for "is this the kind of thing asked
for" and a second, separately named Noul for "does this have the excluded property" — then
combine in code as `is_kind AND NOT has_excluded`. Two clear questions beat one question with
a "not" in it, and both ride in the same call for the same latency.

Bands: the probability is a sort key. If you must act on it, demote below the fold rather than
drop, and keep a floor low enough that 71%-grade accuracy cannot silently remove a correct
answer.

## What stays in code

Parsing the exclusion out of the query — "not", "except", "excluding", "-term", facet
deselection — and, crucially, **converting it to a hard filter whenever it maps to a field you
index**. "Not a MacBook" against a `brand` column is a `WHERE brand != 'Apple'`, and that is
free, exact and not a ranking problem at all. jev is for the exclusions that are not indexed:
propositions, outcomes, conditions, phrasing in the body text. Also in code: the first-stage
retrieval, the shortlist slice, the boolean combination of the two nouls, the sort, and the
timeout that falls back to the unmodified ranking.

## Numbers

From github.com/anessbelbati/jev-rerank-bench, accessed 2026-09-19:

| Ranker | NevIR negation pairs |
|---|---|
| jev rubric | **71%** |
| Cohere Rerank 4 Pro | 67% |

The NevIR subset size is **not published** in that repository; the 1,617-question figure covers
all 14 datasets, so do not attribute it to this row. The same study's headline general result
is NDCG@10 0.692 for jev against Cohere Rerank 4 Pro's 0.691 with a confidence interval of
-0.009 to +0.012 — parity overall, with negation as the exception. Its own method caveats apply:
BM25 top-30 candidates only, 2,000-character truncation, and no multiple-comparison adjustment
across 14 datasets, which is the reason to treat a single four-point win as suggestive.

Cost method: `input_tokens = chars/4`, `cost = tokens x $0.042 / 1e6`, output free. A 100-character
query plus a 600-character candidate plus two nouls with criteria (~1,200 characters) is about
475 tokens, **= $0.00002 per pair**; at a shortlist of 30 that is about $0.0006 per query.
Cohere Rerank 4 Pro was priced at $2.51 per 1,000 queries against jev's $0.45 in the same study.

## When the verdict flips

- **The exclusion is an indexed field.** Then it is `no`: write the filter. A model call to
  re-derive a `WHERE` clause is the wrong tool.
- **The query has two or more stacked negations**, or a negation inside a conditional. That is
  the multi-hop and double-negative anti-use case; a behaviour study measured 32-link tasks at
  7/18 against 8-link at 12/18 for chained indirection.
- **You use the probability as a hard filter.** At 71% you will delete correct results. Demote.
- **Recall is the problem, not ordering.** Negation-aware ranking cannot add a candidate the
  first stage never returned.
- **Non-English queries.** No source measures negation handling outside English here, and
  independent work found weaker behaviour on other languages generally.

## Alternatives considered

- **Structured filters / faceted search.** Free, exact, and the right answer whenever the
  excluded property is a column. Always try this first.
- **Embeddings alone.** Structurally blind to negation — the antonym is the nearest neighbour.
  This is the failure that creates the use case.
- **Cross-encoder rerankers (Cohere Rerank 4 Pro, zerank-2).** The direct competitor, measured
  at 67% here against jev's 71%, and cheaper per query in the zerank-2 case ($0.22 per 1k). Run
  both on your own negated queries before choosing.
- **Frontier LLM listwise reranking.** Better at reasoning through a negation, at seconds of
  latency and cents per query — viable only for low query volumes.
- **Query rewriting into a boolean expression.** A generation task, which jev cannot do, but a
  small LLM can — and the result is a deterministic filter, which is strictly better when it
  works.
- **Fine-tuned cross-encoder on your own negated queries.** Best ceiling, needs labels. jev
  buys the cold start.

## Sources

- https://github.com/anessbelbati/jev-rerank-bench — accessed 2026-09-19 (NevIR 71% vs Cohere
  Rerank 4 Pro 67%; overall NDCG@10 0.692 vs 0.691, CI -0.009..+0.012; $0.45 vs $2.51 per 1k
  queries; 14 datasets, 1,617 questions; NevIR subset size not published)
- https://docs.typesafe.ai/cookbooks/rerank_typesafe.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://github.com/RINNECODER/jev-behavior-study — accessed 2026-09-19 (chained indirection
  7/18 at 32 links vs 12/18 at 8 links)
