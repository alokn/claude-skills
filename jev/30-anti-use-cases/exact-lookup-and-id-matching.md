---
id: au-exact-lookup-and-id-matching
title: Do not use jev for exact lookups, id matching, or dictionary joins
verdict: no
domain: data
decision_shapes: [search, verification]
primitives: [choice, noul]
evidence_level: independent-benchmark
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  ("Asking the model something code can compute exactly")
  - https://empryo.com/blog/jev-and-the-harness  ("When an exact index, graph traversal, or deterministic heuristic already captures the signal, deterministic code remains faster, cheaper, and more reliable")
  - https://docs.typesafe.ai/cookbooks/entity_alignment.md  (blocking in code, jev judges the shortlist)
related: [au-http-status-enum-routing, au-grep-line-ranking, au-archive-after-n-days-rule]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to find which SKU this order line refers to?" Also "match the customer id
in the email to our accounts table", "look up the feature flag name", "resolve this error code to its
description".

## Verdict

**No.** Exact matching is a hash lookup. The jaggedness page's closing reminder names this class
directly — avoid "asking the model something code can compute exactly" — and Empryo's independent
evaluation reached the same conclusion from measurement: "decision models excel when semantic
interpretation of natural language is required and words do not match directly. When an exact index,
graph traversal, or deterministic heuristic already captures the signal, deterministic code remains
faster, cheaper, and more reliable."

Closest failure mode: **math and counting** — an exact match is a computation, and the
jaggedness page's own rule is not to ask the model what code can compute exactly.

## What jev would get wrong

A Choice is relative: it settles *which* option wins, and it always picks one. Given a list of SKUs and
an order line whose true SKU is absent, a Choice returns the closest-looking option with a confidence
value attached, and your code writes the wrong id to the database. Adding a `none of these` option
mitigates but does not remove this; a dictionary lookup simply returns nothing. Ids and codes are also
the worst possible input shape for a model that reads numeric and alphanumeric tokens as text — the same
weakness that makes hex comparison unreliable applies to `SKU-40192` versus `SKU-40912`.

## What stays in code

The index. A hash map, a database join, a unique constraint, a trie. These are exact, constant-time, free,
and auditable. Keep them, and keep them authoritative — nothing jev returns should overwrite a key match.

Jev earns a place only at the point where exact matching has already failed and the remaining question is
semantic. That is the entity-alignment shape: code blocks the candidate space (shared keys, fuzzy score,
trigram similarity) down to a shortlist, and jev judges each pair with a three-level Score — merge, leave
unlinked, send to a curator. Code does the blocking because it is exact and cheap; jev does the "is this
the same thing?" judgement because that is genuinely semantic.

## Numbers

An index lookup is microseconds and $0. A jev call over a shortlist of ten candidate records is roughly
1,500-3,000 input tokens, about $0.00006-$0.00013 at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md), typically about 100 ms. Empryo's harness study measured the adjacent
lexical case and found jev behind: ranking individual text-match lines with jev "dropped top-3 accuracy
from 78.6% to 74.1%" (https://empryo.com/blog/jev-and-the-harness).

- Field evidence (community-report, opinion not measurement): the HN launch thread (498 comments) on genealogy-style entity matching — 100,000^2 candidate pairs is infeasible at any per-call price, so blocking and deterministic keys stay mandatory and jev can only adjudicate the shortlist, 2026-09-19. Source: https://news.ycombinator.com/item?id=49717558

## When the verdict flips

It flips to **conditional** only after the deterministic match fails and a human would need to read the
text to resolve it. The conditions: code runs the exact join first and short-circuits on a hit; code
produces a bounded shortlist (blocking); the jev question includes an explicit "not the same" or
"send to a curator" outcome so the model can decline; and the confidence gate routes the uncertain
band to a person rather than merging records. It never flips for a lookup that an index already answers.

## Alternatives considered

- **Regex / deterministic**: wins outright for exact and normalised matching. This is the answer.
- **Fuzzy string match (Levenshtein, rapidfuzz, trigram)**: the right blocking step; fast and tunable,
  though prone to false merges on its own — which is where jev's judgement adds value.
- **Small LLM**: slower, unstructured, no typed confidence.
- **Frontier LLM**: for the hardest residual pairs only.
- **Fine-tuned classifier**: strong for record linkage at scale if you have labelled merge decisions.
- **Embeddings**: good for generating the shortlist; poor at deciding identity.
- **Human**: the curator tier the Score routes to.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://empryo.com/blog/jev-and-the-harness — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/entity_alignment.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
