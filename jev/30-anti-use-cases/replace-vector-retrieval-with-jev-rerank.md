---
id: au-replace-vector-retrieval-with-jev-rerank
title: Do not replace a strong vector retriever with jev-only ranking at catalogue scale
verdict: weak
domain: search
decision_shapes: [ranking, search, retrieval]
primitives: [score, choice]
evidence_level: independent-benchmark
sources:
  - https://github.com/zhuyansen/jev-search-rerank-eval  (33,047 entries, 164 queries, 9,831 graded pairs; NDCG@10 figures; judge-circularity)
  - https://docs.typesafe.ai/cookbooks/rerank_typesafe.md  (BM25 shortlist then one question per candidate)
  - https://empryo.com/blog/jev-and-the-harness  (lexical ranking beat jev on grep lines)
related: [au-grep-line-ranking, au-flat-choice-over-255-options, au-expect-headline-speed-cost-multipliers]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to drop our embedding index and rank catalogue results with jev instead?" Also "jev
reranking will fix our search relevance", "we can skip the vector database if jev scores candidates".

## Verdict

**Weak** as a replacement, **good** as a fused addition — and this has been measured at scale. An
independent evaluation over "33,047 skills, MCP servers and coding-agent tools" with "164 real Chinese /
English / mixed queries, 9,831 labelled (query, skill) pairs" reports that "Jev as a standalone reranker
does not beat a good embedding ranker", and concludes "Jev is worth adding only on top of semantic
candidates, and only fused" (https://github.com/zhuyansen/jev-search-rerank-eval).

Closest failure mode: **large state and context rot** — a 33,047-item catalogue cannot go into
one state, so a retriever fixes the candidates and jev only scores pairs; the veto itself is
empirical, not a jaggedness mode — a good embedding ranker wins standalone, so jev earns its
place only fused.

## What jev would get wrong

Jev cannot index. It scores candidates you hand it, so at 33,047 entries something must produce the
shortlist, and that something is the retriever you were proposing to remove. Where jev *was* used as the
reranker over a strong embedding shortlist, it did not add much: NDCG@10 was 0.785 for
`jev-score(bge-m3@30)` against 0.774 for `bge-m3` alone. Under labels from an independent LLM judge —
excluding jev's own scoring, to remove circularity — the reranker was actively *worse*:
"jev-score(bge-m3@30) − bge-m3 = −0.028" versus "+0.012" under merged labels. That gap is the
measurement's most useful lesson: a jev-judged evaluation of jev overstates jev.

## What stays in code

Retrieval and fusion. Keep the embedding index, keep BM25 if you have it, and keep the reciprocal-rank
fusion step — that is where the gain lived. Code owns the shortlist size, the fusion weights, and the
final ordering.

Jev's role is one score per (query, candidate) pair over a shortlist, fanned out in one request, fused
with the retriever's ranking rather than overriding it. TypeSafe's own reranking cookbook is built the
same way: a BM25 shortlist first, then one jev question per candidate. Jev is a reranker in a pipeline,
never the pipeline.

## Numbers

From the independent evaluation (accessed 2026-09-19), NDCG@10: `rrf(bge-m3,jev@30)` 0.864; `bge-m3`
0.774; `jev-score(bge-m3@30)` 0.785; the shipped `ash-0.4.0` baseline 0.609. Fusion gained "+0.090
NDCG@10" over embedding search alone, and "+0.064" under independent-judge labels — the gain survives the
label set jev had no part in, which is the test the author says a claim must pass. Reranking 30 candidates
in one call runs roughly 3,000-6,000 input tokens, about $0.00013-$0.00025 per query at $0.042 per million
input tokens with output free (https://docs.typesafe.ai/models.md). Empryo's finer-grained result points
the same way: lexical ranking beat jev on grep lines, 78.6% against 74.1% top-3.

- Field evidence (independent-benchmark): zhuyansen/jev-search-rerank-eval judge-circularity check over 164 queries and 9,831 graded pairs — jev-rerank minus bge-m3 = **-0.028 [-0.052, -0.004]** under Claude Haiku 4.5 labels, +0.053 under jev-only labels, 2026-09-19. Source: https://github.com/zhuyansen/jev-search-rerank-eval

- Field evidence (independent-benchmark): yodablocks/jev-orderby-bench on 306 Amazon ESCI product-relevance pairs — ECE 0.242, inversion 0.255, 23/30 queries over threshold, and the "Complement" grade ranked *below* "Irrelevant"; the same pre-registered gates passed on 360 20-Newsgroups rows at ECE 0.045, inversion 0.036, 2026-09-19. Source: https://github.com/yodablocks/jev-orderby-bench

## When the verdict flips

It flips to **strong** in the fused configuration the same study measured: embedding retrieval produces
the top 30, jev scores each candidate in one fan-out call, and reciprocal-rank fusion combines the two
orderings. It also flips where there is no strong retriever to begin with — the shipped 0.609 baseline was
beaten by everything — so jev reranking is a large win over weak lexical search and a small or negative
one over a good embedding ranker. Two conditions on any evaluation you run: use a label set jev did not
help produce, and compare against your current ranker rather than against nothing.

## Alternatives considered

- **Regex / BM25**: cheap first-stage retrieval; fuse it rather than discard it.
- **Embeddings (bge-m3 class)**: the measured winner as a standalone ranker at 0.774 NDCG@10. Keep it.
- **Cross-encoder reranker**: the conventional reranking tool; compare it against jev on your own data.
- **Small LLM**: slower per candidate, no typed score.
- **Frontier LLM**: too slow and costly for per-query reranking at catalogue scale.
- **Human**: produces the graded relevance labels the evaluation needs.

## Sources

- https://github.com/zhuyansen/jev-search-rerank-eval — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/rerank_typesafe.md — accessed 2026-09-19
- https://empryo.com/blog/jev-and-the-harness — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
