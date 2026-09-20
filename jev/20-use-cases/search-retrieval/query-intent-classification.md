---
id: uc-search-retrieval-query-intent-classification
title: Classify a search query's intent and route it to the right index, filter or handler
verdict: good
domain: search-retrieval
decision_shapes: [classification, routing, detection]
primitives: [choice, noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/patterns/intent-routing.md  (intent Choice + complexity Score; confidence < 0.5 routes to a human)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Search: "find items that match a natural-language query"; Routing: "A category selects the next code path")
  - https://docs.typesafe.ai/cookbooks/function_calling.md  (closed-set argument filling; a `stated` Noul keeps the default)
  - https://docs.typesafe.ai/patterns/fan-out.md  (ask every question the tree might need in one call)
related: [uc-search-retrieval-rerank-keyword-shortlist, uc-agents-harness-function-call-argument-filling, uc-search-retrieval-confidence-fallback-broader-level]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to work out what a search query means before running it?"
Also: "navigational vs informational vs transactional — can jev label that?", "should this
query go to the product index or the help centre?", "can jev turn 'cheap red running shoes
under 100' into filters?"

## Verdict

**Good.** The docs name intent routing as a pattern and search as a decision shape, but no
cookbook measures query-intent classification specifically, so this is the pattern applied
rather than a reproduced result. The mechanism is clear and the economics are right: a search
query is short, so the call is a few hundred input tokens, and 70-500 ms sits inside a typical
search budget. Build it with a confidence floor and a deterministic fallback to the current
behaviour from day one.

## What jev decides

State is the query plus whatever short context the router already has (previous query, current
section, locale). Keep it small — the query is most of the signal.

One Choice for intent, one Score for how much machinery the query needs, and Nouls for the
orthogonal properties, all fanned out in one request:

```python
"intent": Choice(instructions="What is this search query trying to find?", criteria={
    "known_item": "Names a specific thing the user believes exists — a product, page, or document title",
    "exploratory": "Describes a need or topic without naming a specific item",
    "support": "Asks how to do something, or reports something not working",
    "other": "None of the above fits"}),
"specificity": Score(instructions="How narrowly does the query constrain the result set?",
    criteria=["A whole category", "A category with one qualifier",
              "Several qualifiers", "Effectively one item"]),
"mentions_price_constraint": Noul(instructions="Does the query state a price limit or range?"),
"mentions_time_constraint":  Noul(instructions="Does the query restrict results by recency or date?"),
```

Always include an `other` option: the docs recommend adding `other`/`none` "when list may not
cover input", and the function-calling cookbook shows what happens without the escape hatch —
"an argument that must be picked will be picked, plausibly and wrongly."

Bands follow the intent-routing pattern: `if intent.confidence < 0.5: run the default search`.
Per-branch thresholds where a branch is expensive or surprising.

## What stays in code

Query normalisation, spell correction, the index selection itself, the SQL/filter construction,
and every numeric constraint. The Noul says a price limit is present; a regex extracts `100`
and code writes `price <= 100`. Numbers and dates are modes 2 and 3 — never ask jev to compare
them.

## Numbers

Per-call cost: a 40-character query plus four questions is roughly 200-400 input tokens, so
about $0.000008-$0.000017 at $0.042 per million input tokens with free output. Latency 70-500
ms, "most queries about 100 ms". Adding questions adds tokens and low incremental latency — the docs say latency "barely
changes", not that it is free, and the
parallel-questions cookbook measured 13 questions over one document as 12.2x cheaper and 10.0x
faster in one call than as 13 sequential calls, with identical answers, and that ratio grows
with how document-dominated the workload is (a short query will not approach 13x).

No accuracy figure is published for query intent. Do not claim one: TypeSafe's own workflow
evals place jev mid-table (67.8%) on agreement with a two-model reference, not on human ground
truth, and publish no abstention curve.

Closest jaggedness mode: **1, literal reading.** Query text is terse and elliptical, so the
boundary cases ("iphone 15 case" — known-item or exploratory?) must live in the criteria.

## When the verdict flips

- **The intent is lexical.** A query that starts with a SKU, an order number, an error code or
  a `site:` operator is a regex decision. Independent evaluations rejected jev for exactly this
  class of routing; keep the pattern match in front.
- **Click logs already answer it.** If you have millions of query-click pairs, a trained
  classifier or the logs themselves beat a zero-shot judgement and cost nothing at serve time.
  This is the strongest counter-argument in mature search.
- **Head queries dominate.** Cache the decision per normalised query string; jev then runs only
  on the tail, which is also where it is worth the most.
- **Sub-50 ms budgets** (as-you-type suggestions). Route on the submitted query, not each
  keystroke, or keep a deterministic fallback with a hard timeout.
- **Non-English at scale.** English is the primary training language; other languages are
  accepted with lower accuracy. Evaluate per locale.

## Alternatives considered

- **Regex and prefix rules** — win outright on operators, ids and codes; keep them, and let jev
  handle only what falls through.
- **Query-log classifier / gradient-boosted model on click features** — the incumbent in large
  search systems and usually better, because it learns your users. Jev wins at cold start,
  on the tail, and when a new intent must ship without retraining.
- **Embedding nearest-neighbour to labelled example queries** — cheap and decent; needs a
  labelled seed set and a threshold, and gives no confidence you can reason about per action.
- **Frontier LLM** — accurate and far too slow and costly for the request path.
- **Do nothing (one index, one ranking)** — often the correct answer for a small catalogue;
  measure the misroute rate before building anything.

## Sources

- https://docs.typesafe.ai/patterns/intent-routing.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/function_calling.md — accessed 2026-09-19
- https://docs.typesafe.ai/patterns/fan-out.md — accessed 2026-09-19
