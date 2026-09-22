---
id: au-grep-line-ranking
title: Do not use jev to rank individual grep match lines
verdict: weak
domain: sdlc
decision_shapes: [ranking, search]
primitives: [score, choice]
evidence_level: independent-benchmark
sources:
  - https://empryo.com/blog/jev-and-the-harness  (top-3 accuracy 78.6% lexical vs 74.1% with jev reranking)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 5, large state / missing context)
  - https://docs.typesafe.ai/cookbooks/rerank_typesafe.md  (reranking works on candidates with enough context)
related: [au-exact-lookup-and-id-matching, au-replace-vector-retrieval-with-jev-rerank, au-predict-next-tool-call]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to rerank the lines a grep returned so the agent sees the most relevant
first?" Also "score each `ripgrep` hit for relevance", "replace our match-ordering heuristic with jev".

## Verdict

**Weak** — measured, and it lost. Empryo's harness evaluation reports: "Ranking individual text match
lines with Jev dropped top-3 accuracy from 78.6% to 74.1%." The lexical ordering the harness already had
was better than jev's semantic reranking. Their explanation is the important part: isolated lines lack
sufficient semantic context compared with complete files or symbols, and where the match is lexical, the
lexical signal is the right one.

## What jev would get wrong

A single grep line is a few dozen characters with no surrounding scope, no file role, and often no
identifier context — there is nothing for a semantic judge to judge. Jev is being asked to compare
candidates that are nearly indistinguishable on the axis it is good at, while the axis that actually
predicts relevance (where the token appears, whether it is a definition or a call site, which directory
the file is in) is structural and already captured by the index. This is the same class of counter-signal
that failure mode 5 describes from the other direction: not too much state, but too little of the
relevant kind, so the judgement has no purchase.

## What stays in code

The ranking. Keep the lexical ordering, the path heuristics (prefer `src/` over `test/`, prefer
definitions over references), and whatever symbol index or LSP you already query. Empryo's conclusion
generalises: "When an exact index, graph traversal, or deterministic heuristic already captures the
signal, deterministic code remains faster, cheaper, and more reliable."

Jev belongs one granularity up. The same study found reranking useful where candidates carry real
context — whole files or symbols rather than lines — and TypeSafe's reranking cookbook is built on
candidates with enough text to judge (a BM25 shortlist reranked with one question per query-candidate
pair, moving top-1 from 5% to 18% and top-10 from 38% to 62%).

## Numbers

Measured: top-3 accuracy 78.6% with lexical ranking, 74.1% with jev reranking — a 4.5 point loss
(https://empryo.com/blog/jev-and-the-harness, accessed 2026-09-19). The lexical ranking also costs $0 and
adds little latency. Reranking 40 lines in one call is roughly 2,000-4,000 input tokens, about
$0.00008-$0.00017 at $0.042 per million input tokens with output free (https://docs.typesafe.ai/models.md),
plus about 100 ms in the agent's inner loop.

- Field evidence (community-report): Empryo harness field report (ProxySoul), "Ranking individual text match lines with Jev dropped top-3 accuracy from 78.6% to 74.1%", 2026-09-16. Source: https://empryo.com/blog/jev-and-the-harness

## When the verdict flips

It flips to **good** when the unit of ranking changes from a line to something with context. Concretely:
group the grep hits by file or by enclosing symbol, give jev the symbol signature plus a few lines of
surrounding code and the file path, and score each *symbol* against the query with a described three- or
four-level Score. Keep the lexical ordering as the tie-breaker rather than discarding it, and measure
against the lexical baseline before shipping — that baseline won once already. It also flips when the
query is natural language that does not lexically match the code ("where do we handle expired
sessions?"), which is the case Empryo says decision models are for: "when semantic interpretation of
natural language is required and words do not match directly."

## Alternatives considered

- **Regex / deterministic**: the incumbent, and the measured winner here at 78.6% top-3. Keep it.
- **Small LLM**: slower in an agent loop and no evidence of a gain.
- **Frontier LLM**: too slow for per-search reranking.
- **Fine-tuned classifier**: could learn the path and symbol heuristics, but so can a rule.
- **Embeddings**: useful for the natural-language query case; combine with lexical via fusion rather than
  replacing it.
- **Human**: not applicable at this latency.

## Sources

- https://empryo.com/blog/jev-and-the-harness — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/rerank_typesafe.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
