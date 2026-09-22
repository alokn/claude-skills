---
id: cb-rerank_typesafe
title: Re-ranking
url: https://docs.typesafe.ai/cookbooks/rerank_typesafe.md
decision_shapes: [ranking, search, scoring]
primitives: [noul]
related: [uc-search-retrieval-rerank-keyword-shortlist, uc-search-retrieval-rrf-fusion-with-dense-retriever, uc-search-retrieval-context-selection-for-downstream-ai, au-replace-vector-retrieval-with-jev-rerank]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.12
---

## Task

Two-stage retrieval over legal text: BM25 builds a 30-passage shortlist per query, then one
jev question scores each query-candidate pair and the shortlist is re-sorted by that score.

Dataset: CLERC (`jhu-clsp/CLERC`, `teva_train_dir/train_data.jsonl.gz`), US federal court
opinions. 170 CLERC rows are pooled into one shared corpus of 3,565 court opinion passages;
40 of the 170 rows are evaluated as queries and the other 130 "only ever appear as
candidates". Each query is "an opinion excerpt with a citation removed"; the gold is "the
passage the removed citation pointed to". Model: `TYPESAFE_MODEL = "jev-1.12"`. Date
sampled: not reported; the price constant is annotated "TypeSafe jev-1.12 as of 2026-08".

## Decomposition (state, questions, how answers are combined)

State is two fields, one query and one candidate, per call:

```python
state={"query_excerpt": query, "candidate_passage": candidate}
```

One question, a `Noul` keyed `is_cited_source`:

```python
is_cited_source = Noul(
    instructions=(
        "The query excerpt comes from a US federal court opinion and was written "
        "immediately around a citation to a precedent; the citation itself has been "
        "removed. Could the candidate passage be from that cited precedent - does it "
        "establish the specific legal proposition the query excerpt invokes at its "
        "citation point?"
    ),
    criteria=NoulCriteria(
        true=("The candidate passage states or establishes the specific rule, standard, "
              "holding, or fact pattern that the query excerpt attributes to its removed "
              "citation."),
        false=("The candidate passage is merely on a similar topic or doctrine; it does not "
               "supply the specific proposition the query excerpt relies on."),
    ),
)
```

Combination is pure code. Constants: `N_ROWS = 170`, `N_QUERIES = 40`, `TOP_K = 30`. BM25
retrieves, code slices the top 30, jev is asked once per pair (40 x 30 = "1,200 calls in
total, run concurrently"), and the shortlist is sorted on the returned noul, descending:

```python
reranked = {
    q: sorted(candidates[q], key=lambda c: -pair_scores[q][c]["noul"]) for q in queries
}
```

There are no confidence bands and no abstain path. The noul is used only as a sort key, so
no threshold is applied. Re-ranking "only reorders the top 30 candidates already on the
shortlist. It cannot add a passage that fast search did not select."

## Numbers reported (verbatim, with what they compare against and the run date if given)

Corpus and shortlist: 3,565 candidates, 40 queries, shortlist of 30. Fast search alone puts
the gold passage in the shortlist for "100% of the 40 queries", "But that passage is rarely
the top-ranked one on the shortlist, only 5% of the time."

| Threshold | Fast search (BM25) | + TypeSafe re-rank |
|---|---|---|
| Top 1 | 5% | 18% |
| Top 5 | 15% | 35% |
| Top 10 | 38% | 62% |

Cost and tokens, printed by the notebook: `1200 TypeSafe calls used 1,536,002 input and
25,200 output tokens, costing $0.0645.` Price constant: `PRICE = (0.042, 0.00)` dollars per
1M tokens (input, output), "TypeSafe jev-1.12 as of 2026-08".

Latency: not reported. Comparison against a named general-purpose LLM: not reported (no LLM
baseline is run; the cookbook only discusses the idea in prose). Repeats / `NUM_SAMPLES`:
not reported. Standard deviations: not reported. Run date: not reported.

## Caveats the cookbook itself states

- Re-ranking is bounded by the shortlist: it "cannot add a passage that fast search did not
  select".
- The evaluation is 40 queries only; the shortlist happened to contain the correct passage
  for all 40, "so re-ranking can focus on putting each one in a better position".
- Fast search is deliberately BM25 "and nothing else": "Keeping this step simple leaves the
  attention on re-ranking... The choice of fast search method is a side issue."
- The corpus is pooled, so BM25 "selects 30 candidates from that full corpus, not only the
  20 negatives supplied with that row".
- The one-question-per-pair design is a teaching simplification: "This walkthrough asked one
  question per pair for clarity. A real application would ask several questions about the
  same pair in one call."
- Prices are pinned to a date ("as of 2026-08").

## Lessons transferable to other use cases

- Score-not-generate: a yes/no question plus `NoulCriteria` yields a 0-1 number
  that is directly sortable, so no scoring rubric has to be invented for a general model.
- Pre-parsed candidates: a cheap recall stage (BM25, embeddings, SQL) fixes the candidate
  set; jev only ever does pairwise comparison against a fixed, bounded input.
- Code does the arithmetic: jev returns one number per pair; sorting, slicing and top-k
  accounting all stay in Python.
- Independent pair scoring parallelises trivially (1,200 calls in a 12-worker thread pool)
  and each call is stateless, so no ordering effect exists between candidates.
- What does not generalise: the absolute top-1 and top-10 figures are specific to CLERC
  legal-citation retrieval with a BM25 top-30 shortlist. Recall is capped by stage one, and
  here stage one had 100% recall at 30 - a shortlist that misses the gold caps the gain.

## Use-case entries this supports

- `uc-search-retrieval-rerank-keyword-shortlist` - re-rank a BM25 or embedding shortlist by pairwise relevance
- `uc-search-retrieval-rrf-fusion-with-dense-retriever` - fuse the jev scores with a dense retriever rather than reranking standalone
- `uc-search-retrieval-context-selection-for-downstream-ai` - order retrieved chunks before they enter a RAG prompt

**Anti-use-case implied:** `au-replace-vector-retrieval-with-jev-rerank` - jev should not replace
first-stage retrieval over thousands of documents; it scores a bounded shortlist and cannot
surface a passage fast search never selected.
