---
id: uc-search-retrieval-rerank-keyword-shortlist
title: Re-rank a BM25 or keyword shortlist by pairwise query-candidate relevance
verdict: strong
domain: search-retrieval
decision_shapes: [ranking, search, scoring]
primitives: [noul]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/rerank_typesafe.md  (CLERC re-ranking: top-1 5% -> 18%; cost and call counts)
  - https://docs.typesafe.ai/concepts/use-case-map.md  ("Rerank results with pairwise comparisons")
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-search-retrieval-rag-passage-gating, uc-search-retrieval-document-answers-query-gate, uc-agents-harness-skill-or-tool-selection]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to re-rank my search results?" Also: "our BM25 / Postgres
full-text search returns the right document but never at the top — can jev fix the
ordering?", "can jev replace our cross-encoder re-ranker?"

## Verdict

**Strong for the measured recipe: one `Noul` per (query, candidate) pair, 30 calls per query,
legal retrieval over a weak keyword shortlist.** That is the configuration TypeSafe measured
end to end on CLERC, and the gains below belong to it, not to reranking in general. A cheap
recall stage fixes a bounded candidate set; jev answers one absolute yes/no per pair and the
probability is a sort key. Pairs are scored independently, so there is no ordering effect
between candidates and the batch parallelises trivially. The one condition the cookbook
states itself: re-ranking "only reorders the top 30 candidates already on the shortlist. It
cannot add a passage that fast search did not select."

## What jev decides

State is two fields per call: `{"query_excerpt": query, "candidate_passage": candidate}`.

One `Noul`, `is_cited_source` (cookbook wording, trimmed):

- instructions: "The query excerpt ... was written immediately around a citation to a
  precedent; the citation itself has been removed. Could the candidate passage be from that
  cited precedent — does it establish the specific legal proposition the query excerpt
  invokes at its citation point?"
- `true`: "The candidate passage states or establishes the specific rule, standard, holding,
  or fact pattern that the query excerpt attributes to its removed citation."
- `false`: "The candidate passage is merely on a similar topic or doctrine; it does not
  supply the specific proposition the query excerpt relies on."

The `false` criterion carries the work: it names the near-miss that lexical and embedding
retrieval cannot separate from a real match. Write yours the same way — the distractor your
incumbent keeps ranking first becomes the `false` text.

No threshold, no confidence band: the noul is a sort key only. Add an absolute floor in code
if the consumer needs "or nothing" (see the existence gate entry). The cookbook flags that
one question per pair is a teaching simplification — "A real application would ask several
questions about the same pair in one call" — so recency, authority or injection nouls ride
along for tokens and no extra latency. The same point applies across candidates: a state
structured to hold the whole shortlist can carry one question per candidate in a single call,
which is what the independent fusion study did. The CLERC numbers below were produced by the
one-call-per-pair recipe, so that is the shape the `strong` covers; a batched variant is a
different, unmeasured configuration for this task.

## What stays in code

First-stage retrieval, the top-k slice, the concurrency pool, the sort, top-k accounting, and
every deterministic filter (tenant, ACL, language, date window) applied *before* the
shortlist. Never put a date or a count inside the question (jaggedness modes 2 and 3).

## Numbers

From `rerank_typesafe.md` — CLERC federal court opinions, 3,565 pooled passages, 40 queries,
shortlist 30, `jev-1.12`:

| Threshold | BM25 | + TypeSafe re-rank |
|---|---|---|
| Top 1 | 5% | 18% |
| Top 5 | 15% | 35% |
| Top 10 | 38% | 62% |

Label provenance: the gold passage per query is the precedent the query excerpt actually
cited, recovered from the citation the excerpt had removed — a documentary ground truth from
the corpus, not a human adjudication and not a model's judgement. n = 40 queries.

BM25 alone put the gold passage in the shortlist for "100% of the 40 queries", but "that
passage is rarely the top-ranked one on the shortlist, only 5% of the time." Cost, printed by
the notebook: "1200 TypeSafe calls used 1,536,002 input and 25,200 output tokens, costing
$0.0645" — about $0.000054 per pair at `PRICE = (0.042, 0.00)`, "TypeSafe jev-1.12 as of
2026-08". Latency not reported here; the models page gives 70-500 ms, "most queries about
100 ms". No LLM or cross-encoder baseline was run.

Closest jaggedness mode: **5, large state full of irrelevant detail**; avoided by sending one
query and one candidate per call.

- Field evidence (independent-benchmark): zhuyansen/jev-search-rerank-eval, 33,047 entries, 164 zh/en queries and 9,831 graded pairs: when the candidate list came from the shipped keyword ranker rather than a dense retriever, jev re-ranking beat bge-m3 by "+0.060" NDCG@10; the same run measured judge circularity at +0.053 under jev-only labels versus -0.028 under Claude Haiku 4.5 labels, 2026-09. Source: https://github.com/zhuyansen/jev-search-rerank-eval
- Field evidence (independent-benchmark): anessbelbati/jev-rerank-bench, 8 English IR datasets and 1,617 questions over BM25 top-30 candidates truncated at 2,000 characters: jev rubric NDCG@10 0.692 with 74% top-pick at "$0.45" per 1k queries, against Cohere Rerank 4 Pro 0.691 at "$2.51" and zerank-2 0.682 at "$0.22"; confidence interval -0.009..+0.012, no multiple-comparison adjustment, 2026-09. Source: https://github.com/anessbelbati/jev-rerank-bench
- Field evidence (community-report): search re-ranking shipped in the Empryo agent harness with shadow and apply modes, one of five accepted jobs out of eight tested; the same harness rejected jev for ordering raw grep lines, where top-3 accuracy fell from 78.6% to 74.1%, 2026-09-16. Source: https://empryo.com/blog/jev-and-the-harness
- Field evidence (community-report): shell-history ranking re-orders a lexical history shortlist by what the user meant rather than what they typed; no numbers published, 2026-09. Source: https://github.com/mrnugget/jev-shell-history

## When the verdict flips

- **Stage one already ranks correctly.** The gain came from a recall-good, precision-poor
  stage. Measure your own top-1 first; if it is already high this is **weak**.
- **Recall@k is poor.** Re-ranking cannot add what stage one missed. Fix retrieval instead.
- **The match is lexical** (ids, error codes, paths, SKU equality). Keep the index; jev is the
  wrong tool and public evaluations rejected it for grep-line ranking on this basis.
- **Large k under a tight budget.** In the measured recipe, cost *and* call count are linear
  in k: k=200 inside 200 ms is the wrong shape. Pairwise questions *can* share a call when the
  state is structured to hold several candidates at once — the measured recipe simply did not
  do that, so batching is an optimisation you would have to evaluate yourself.
- **Adversarial candidates** (SEO spam, seller copy). State is not hostile by default (mode 6);
  stack the injection noul from the RAG-gating entry on top.

## Alternatives considered

- **BM25 alone** — free and exact, which is why it stays as stage one; blind to "the specific
  proposition" versus "the same topic".
- **Cross-encoder re-ranker** (bge-reranker, Cohere Rerank) — the real competitor and often the
  right answer: purpose-trained and cheap at high k. Jev wins when the criterion must be
  written in English and changed without retraining, when extra judgements ride free on the
  same pair, and when no labelled pairs exist to train on.
- **Embeddings + cosine** — usually stage one; cosine has no way to express the near-miss. One
  public catalog test found no jev win over embeddings, so measure yours.
- **Frontier LLM listwise rerank** — better at global ordering, but seconds of latency, parse
  failures and position bias that independent typed scoring removes.
- **Human relevance judgements** — the ground truth to collect, not a runtime option.

## Sources

- https://docs.typesafe.ai/cookbooks/rerank_typesafe.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
