---
id: uc-search-retrieval-rrf-fusion-with-dense-retriever
title: Fuse jev relevance scores with a dense retriever by reciprocal rank fusion rather than reranking standalone
verdict: good
domain: search-retrieval
decision_shapes: [ranking, search, retrieval, scoring]
primitives: [noul]
evidence_level: independent-benchmark
sources:
  - https://github.com/zhuyansen/jev-search-rerank-eval  (33,047 entries, 164 zh/en queries, 9,831 graded pairs; rrf(bge-m3, jev@30) NDCG@10 0.864 vs bge-m3 0.774; standalone jev-score 0.785; judge-circularity -0.028 vs +0.053. Measured implementation: batched **Score** reranking, one API call per query; only 30 of the 164 queries were hand-adjudicated, the rest carry model-written labels)
  - https://docs.typesafe.ai/cookbooks/rerank_typesafe.md  (pairwise relevance noul as a sort key; shortlist of 30)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-search-retrieval-rerank-keyword-shortlist, uc-search-retrieval-negation-sensitive-relevance, uc-search-retrieval-rag-passage-gating, uc-search-retrieval-document-answers-query-gate, au-replace-vector-retrieval-with-jev-rerank]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to improve my existing vector search?" Also: "our bge-m3
retriever is decent — will a jev rerank on top make it better?", "should jev replace the
embedding ranking or be combined with it?", "how do I add semantic judgement without losing
what the embeddings already get right?"

## Verdict

**Good — as fusion, not as replacement.** The largest independent reranking study
in this corpus ran both designs on the same data and they came out on opposite sides. Letting
jev re-sort a good dense retriever's shortlist *loses* ground under independent labels
(-0.028 NDCG@10). Fusing the two rankings by reciprocal rank fusion *gains* a lot:
`rrf(bge-m3, jev@30)` reached **NDCG@10 0.864 against bge-m3's 0.774**, and the author reports
the gain as "+0.064 even under independent labels"
(github.com/zhuyansen/jev-search-rerank-eval).

It is `good` rather than `strong` because of label provenance: only **30 of the 164 queries
were hand-adjudicated**, and the remaining relevance labels were written by a model. The
effect size is large and the direction is consistent, but the ground truth underneath most of
it is another model's judgement, and the same study shows that swapping the judge reverses the
standalone result — so label provenance is material here, not clerical.

The mechanism is the reason to believe it. The embedding and the typed question fail on
different queries — embeddings on negation and on "same topic, wrong proposition", jev on
lexical identity and long-tail vocabulary. RRF keeps a document that either ranker liked and
demotes only what both disliked, so the fused list inherits the union of their strengths
instead of substituting one set of errors for another. Discarding the dense ranking, which is
what standalone reranking does, throws away the half you already paid for.

## What jev decides

**The measured design: one batched `Score` call per query.** This is what the study actually
ran, and it is the shape the 0.864 belongs to. State carries the query and the whole
shortlist, and one Score question is asked per candidate in the same request:

```
state: {"query": query,
        "candidates": [{"id": "c1", "text": ...}, ... 30 of them]}

relevance_c1 ... relevance_c30: Score   (one question per candidate, all in one call)
  instructions: "How well does candidate `c<i>` supply what `query` asks for?"
  criteria: ["Different subject; does not address the query.",
             "Same subject area, but does not supply what was asked, or supplies the opposite.",
             "Supplies part of what was asked, or supplies it indirectly.",
             "Supplies the specific thing the query asks about."]
```

Write the second level around the distractor your dense retriever keeps ranking first — that
is the error RRF is being asked to fix. The expected score is a sort key only, and then only
an input to fusion. There is no threshold and no confidence band at this stage: RRF consumes
**ranks**, not scores, which is part of why it is robust to jev's calibration varying by
domain.

**The Noul-per-pair variant is unmeasured here.** One `Noul` per (query, candidate) pair, as
in the pairwise reranking pattern (`uc-search-retrieval-rerank-keyword-shortlist`), is a
reasonable alternative and is what the official cookbook teaches — but no number in this entry
was produced by it. It costs 30 calls per query instead of one, and if you run it you are
running a design nobody has measured for fusion. Extra judgements (recency, authority,
injection) ride along in the same call for the same latency in either shape; use them as
separate fusion inputs or as hard filters, not by averaging them into the relevance score.

Fusion, in code: `rrf_score(d) = sum over rankers r of 1 / (k + rank_r(d))`, conventionally
k = 60. Documents ranked by only one ranker still score; documents both ranked score most.

Closest jaggedness mode: **5, large state full of irrelevant detail** — avoided by sending one
query and one candidate per call and nothing else.

## What stays in code

First-stage dense retrieval and the embedding index. The top-30 slice. Every deterministic
filter (tenant, ACL, language, date window) applied *before* the shortlist, never as a question.
The RRF arithmetic — it is arithmetic, so it belongs in code. The concurrency pool, the
per-query cost cap, and the timeout that falls back to the unfused dense ranking.

## Numbers

From github.com/zhuyansen/jev-search-rerank-eval — 33,047 indexed entries, 164 Chinese and
English queries, 9,831 graded pairs, artefacts frozen:

| Ranking | NDCG@10 |
|---|---|
| **rrf(bge-m3, jev@30)** | **0.864** |
| jev-score(bge-m3@30), standalone rerank | 0.785 |
| bge-m3 alone | 0.774 |
| bm25 | 0.633 |
| ash-0.4.0 | 0.609 |

Implementation measured: **batched `Score` reranking, one API call per query** over the
30-candidate shortlist — not one call per pair. Cost reported at approximately **$0.0002 per
query** for the jev leg at a shortlist of 30. Method for your own estimate:
`input_tokens = chars/4`, `cost = tokens x $0.042 / 1e6`, output free; 30 candidates of roughly
600 characters each plus the question block is about 6,000 tokens in one request, around
$0.00025.

The same study is the only source that measured **judge circularity**: jev-rerank minus bge-m3
came out at **-0.028 [-0.052, -0.004]** when Claude Haiku 4.5 wrote the labels, and **+0.053**
when jev wrote them. That is one measurement of one self-preference gap on one corpus, not a
transferable discount rate — read it as a reason to use an independent judge or human labels,
not as a number to subtract from your own results. The fusion gain of +0.064 is reported as
holding under the independent labels.

Label provenance, which the verdict depends on: **only 30 of the 164 queries were
hand-adjudicated**; the rest of the 9,831 graded pairs carry model-written labels. And 80 of
164 queries are Chinese, so the English-only reading of these numbers rests on about half the
data.

## When the verdict flips

- **Your first stage is weak.** Then plain pairwise reranking is the better design and the
  measured gains are larger (see the BM25 shortlist entry). RRF needs two rankings worth fusing.
- **You drop the dense ranking from the fusion.** That is the anti-use case, measured at -0.028.
  Fusion is the claim; rerank-on-top is not.
- **k is large under a tight budget.** Tokens grow linearly in shortlist size, and if you use
  the Noul-per-pair variant so does the call count; the measured configuration is one batched
  call over 30 candidates. (Pairwise questions *can* share a call when the state is structured
  to hold all the candidates, as the measured run did; the cookbook's one-call-per-pair recipe
  is a teaching simplification, not a constraint.)
- **Recall@30 is poor.** Neither ranker can promote a document the first stage never returned.
- **You evaluate with jev as the judge.** The measured self-preference swing is up to +0.081
  NDCG@10. Use an independent judge or human labels, or you will ship a regression that your
  dashboard shows as a win.
- **Your corpus is one where graded commercial relevance is the target** (product search). A
  pre-registered study failed jev badly there: ECE 0.242, inversion 0.255 on Amazon ESCI.

## Alternatives considered

- **Dense retriever alone.** The baseline this beats by +0.090 NDCG@10 in the measured run, and
  it is free at query time. Keep it as the fallback leg.
- **Standalone jev rerank of the dense shortlist.** Measured at -0.028 under independent labels.
  Do not.
- **Cross-encoder reranker (bge-reranker, Cohere Rerank).** The real competitor. A separate
  study put jev at NDCG@10 0.692 against Cohere Rerank 4 Pro's 0.691 at $0.45 versus $2.51 per
  1,000 queries. A cross-encoder can also be a fusion leg — nothing about RRF requires jev.
- **RRF of dense and BM25 with no model at all.** Cheap, standard, and the honest baseline to
  beat before adding a paid leg. This study does not report it; run it yourself.
- **Learning to rank over your click logs.** Better ceiling once you have the logs, and no
  per-query cost. jev buys the cold start.
- **Human relevance judgements.** The ground truth to collect, not a runtime option.

## Sources

- https://github.com/zhuyansen/jev-search-rerank-eval — accessed 2026-09-19, re-read 2026-09-20
  (0.864 / 0.785 / 0.774 / 0.633 / 0.609; "+0.064 even under independent labels"; ~$0.0002 per
  query; judge circularity -0.028 [-0.052, -0.004] vs +0.053; 164 queries, 9,831 graded pairs,
  33,047 entries. Implementation: batched **Score** reranking, one API call per query; only 30
  of 164 queries hand-adjudicated, the rest model-labelled)
- https://docs.typesafe.ai/cookbooks/rerank_typesafe.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://github.com/anessbelbati/jev-rerank-bench — accessed 2026-09-19 (cross-encoder
  comparison: 0.692 vs Cohere Rerank 4 Pro 0.691, $0.45 vs $2.51 per 1k queries)
- https://github.com/yodablocks/jev-orderby-bench — accessed 2026-09-19 (ESCI ECE 0.242,
  inversion 0.255)
