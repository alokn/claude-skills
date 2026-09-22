---
id: uc-sdlc-semantic-code-search-ranking
title: Rank whole functions against a plain-language code search query, never raw matched lines
verdict: good
domain: sdlc
decision_shapes: [ranking, search, retrieval]
primitives: [noul]
evidence_level: community-report
sources:
  - https://github.com/sufianetaouil/every  (semantic code search over a repository; no numbers published)
  - https://github.com/ellipsis-dev/blink  (function-match ranking; no numbers published)
  - https://github.com/kyu1204/jgrep  (semantic grep; no numbers published)
  - https://empryo.com/blog/jev-and-the-harness  (raw grep-line ordering rejected: top-3 accuracy 78.6% -> 74.1%; "single text lines carry too little context")
  - https://docs.typesafe.ai/cookbooks/rerank_typesafe.md  (pairwise relevance noul over a shortlist of 30)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-search-retrieval-rerank-keyword-shortlist, uc-search-retrieval-semantic-find-in-document, uc-search-retrieval-rrf-fusion-with-dense-retriever, au-grep-line-ranking, au-exact-lookup-and-id-matching]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev for semantic code search?" Also: "ripgrep gives me 200 hits and
the right one is never first — can jev order them?", "can an agent ask 'where do we validate
the webhook signature' and get the function back?", "can jev replace our code embeddings?"

## Verdict

**Good, with one hard structural condition: the unit you score must be a whole function or
symbol, never a matched line.** This is not a stylistic preference. A public field report
tested jev on ordering raw grep lines and dropped it: top-3 accuracy fell from **78.6% to
74.1%**, and the stated reason is the whole entry — "single text lines carry too little
context" and lexical position beat semantics
(empryo.com/blog/jev-and-the-harness). Several community tools ship the function-level version
(sufianetaouil/every, ellipsis-dev/blink, kyu1204/jgrep) and none publish numbers, so the
verdict rests on mechanism plus one measured negative that tells you exactly which shape fails.

The difference is information, not model quality. `if (sig !== expected) return 401;` could be
in any of forty files. `verifyWebhookSignature(payload, header, secret) -> boolean`, with its
docstring and its first few lines, is a thing that either does what you asked for or does not.

## What jev decides

Stage one is lexical: ripgrep, a symbol index, or a tags file produces a shortlist. Code then
**expands each hit to its enclosing declaration** — signature, docstring, decorators, the file
path, and the body truncated to a fixed budget. That expansion step is the design.

One `Noul` per (query, symbol) pair, state `{"query": query, "symbol": expanded_symbol}`:

```
does_what_query_describes: Noul
  instructions: {question: "Does this function do what the query describes?",
                 focus: "What the function does when called, not what words appear in it."}
  true:  "Calling this function performs the behaviour the query asks about, or this is the
          definition where that behaviour lives."
  false: "The function only mentions, logs, tests, imports, re-exports or configures that
          behaviour; the behaviour itself is implemented elsewhere."
```

That `false` criterion is where the yield is. Tests, wrappers, re-exports and log strings are
the near-misses lexical search cannot separate, and naming them is what a typed question can
do that cosine similarity cannot.

Companion questions ride free in the same call: `is_test_code`, `is_generated`,
`is_deprecated`. Use them as deterministic filters in code, not by averaging into the score.

No threshold — the probability is a sort key. If the consumer is an agent that needs "or
nothing", add an absolute floor in code.

Closest jaggedness mode: **5, large state full of irrelevant detail**. One query and one symbol
per call, body truncated; never the whole file.

## What stays in code

First-stage search and the top-k slice. The expansion from line to enclosing symbol — a parser
or LSP job, not a model job. Path, language, vendored-directory and `.gitignore` filtering.
Exact matches: if the query is an identifier, an error code or a path, the index is
authoritative and jev should not be called at all (see the exact-lookup anti-use case). The
sort, the concurrency pool, the per-query cost cap, and the timeout falling back to the lexical
order.

## Numbers

No source publishes accuracy for function-level semantic code search with jev. The three
community tools ship without measurements. The one number that exists is the negative:
**78.6% -> 74.1% top-3 accuracy** when the unit was a raw grep line
(empryo.com/blog/jev-and-the-harness).

Cost method: `input_tokens = chars/4`, `cost = tokens x $0.042 / 1e6`, output free. A 1,600-character
expanded symbol plus a short query plus one noul with criteria (~900 characters) is about 640
tokens, **= $0.000027 per candidate**. A shortlist of 30 costs about **$0.0008 per query**.
Latency is per-pair and parallel; the model page gives 70-500 ms, "most queries about 100 ms",
so a 30-way fan-out is one round trip wide, not thirty deep.

The closest measured analogue in the corpus is generic pairwise reranking over a weak first
stage, where an official cookbook moved top-1 from 5% to 18% on legal passages. That is a
different corpus and a different unit; do not carry it across. Collect your own labels — for
code search they are unusually easy, because "which file did the developer actually open" is
logged by the editor.

## When the verdict flips

- **You score matched lines instead of symbols.** Measured loss. This is the anti-use case.
- **The query is an exact token** — a symbol name, an error string, a file path, a SHA. Then
  grep is correct and free, and jev is the wrong tool.
- **Your first stage has poor recall.** Reranking cannot add a function the shortlist missed;
  fix retrieval or fuse with an embedding ranker instead.
- **The repository is large enough that the shortlist must be big.** Cost and latency are linear
  in k; k=200 inside an interactive budget is the wrong shape.
- **An agent invokes it rarely and inconsistently.** One field report on a 390k-line repository
  found a jev file-ranking skill "showed inconsistent results across sessions (appearing as
  either 25% savings or 29% penalty)" and that agents rarely invoked it unprompted
  (github.com/shiftynick/jev-axi). Measure end-to-end task effect, not ranking quality alone.
- **The codebase is mostly non-English identifiers and comments.** Unevaluated.

## Alternatives considered

- **ripgrep / ctags / LSP "find references".** Free, exact, instant, and right whenever the
  query is a token. Keep them as stage one; they are not competitors.
- **Code embeddings (a code-tuned bi-encoder).** The main competitor: no per-query cost, fast,
  and good at paraphrase. Weak exactly where the `false` criterion above is strong — it cannot
  express "the test that mentions it is not the implementation". Fusing the two rankings is the
  measured-best design in the general search case.
- **Cross-encoder reranker.** Purpose-trained, cheap at high k, needs labels or a code-specific
  checkpoint.
- **Frontier LLM reading the shortlist.** Better at explaining *why* a function matches, at
  seconds and cents per query. Fine for a one-off question, not for an editor keystroke path.
- **Agent that greps then reads files itself.** The real incumbent. Slower and far more
  expensive per query, and this pattern exists to cut the number of files it opens.

## Sources

- https://empryo.com/blog/jev-and-the-harness — accessed 2026-09-19 (grep-line ordering top-3
  78.6% -> 74.1%; "single text lines carry too little context")
- https://github.com/sufianetaouil/every — accessed 2026-09-19 (no numbers published)
- https://github.com/ellipsis-dev/blink — accessed 2026-09-19 (no numbers published)
- https://github.com/kyu1204/jgrep — accessed 2026-09-19 (no numbers published)
- https://github.com/shiftynick/jev-axi — accessed 2026-09-19 (file ranking on a 390k-line
  repository: "either 25% savings or 29% penalty")
- https://docs.typesafe.ai/cookbooks/rerank_typesafe.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
