---
id: au-whole-document-in-state
title: Do not put the whole document in state and ask one question about it
verdict: no
domain: search
decision_shapes: [classification, search, verification]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 5, Large state full of irrelevant detail)
  - https://docs.typesafe.ai/models.md  (64k per request; 32k for state plus longest question)
  - https://docs.typesafe.ai/cookbooks/classifying_rag_passages.md  (Noul filters passages)
  - https://docs.typesafe.ai/cookbooks/semantic_find.md  (score line ids against a query)
related: [au-multi-hop-and-double-negatives, au-private-knowledge-not-in-state, df-rewrites]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to paste the whole contract / the full log file / the entire wiki page into state and
ask jev whether it contains a liability cap?" Also "we have 40k tokens of context, jev can take it",
"send the full customer record so it has everything it needs".

## Verdict

**No**, and it fails for a reason that is not the context limit. Failure mode 5: "Accuracy falls as the
state grows with content unrelated to the decision. Unrelated detail acts as a distractor, and a large
state makes it harder to tell which part of the input produced a wrong answer." The document may fit —
64k tokens per request, 32k for the state plus the longest single question — and still give worse answers
than a filtered excerpt. Fitting is a necessary condition, not a sufficient one.

## What jev would get wrong

Three things degrade at once. Accuracy drops as distractors accumulate, so a clause buried in a
forty-page contract competes with thirty-nine pages of noise. Debuggability drops: when the answer is
wrong you cannot tell which passage caused it, so you cannot fix the question. And the design quietly
invites multi-hop failure (mode 4), because a question over a whole document usually has to locate the
relevant part *and then* judge it — two hops in one Noul. The closing reminder on the jaggedness page
lists this among the things to avoid: "Giving it more context in `state` than the question needs. Jev
suffers from context rot, so unrelated material in the `state` costs you accuracy."

## What stays in code

Retrieval and filtering, first. "Retrieve and filter in code first, and send only the fields the question
needs." Code chunks the document by section, runs BM25 or an embedding search to shortlist candidates,
and sends the shortlist. Code owns pagination across chunks and owns the aggregation of per-chunk answers.

Where code cannot filter, the docs offer a model-side filter: "When it's not possible to filter in state,
you can use a Noul to filter for relevance", with the classifying RAG passages cookbook as the worked
example. The two-pass shape is: pass one asks a cheap relevance Noul per chunk in a single fan-out call;
pass two asks the real questions only of the chunks that survived. The semantic find cookbook does the
same over line ids, scoring 218 of them against a plain-language query in one request and adding a
document-level Noul for "does the doc answer it at all".

## Numbers

A 40k-token document in one call is about $0.0017 at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md); a filtered 2k-token excerpt with eight questions is about $0.0001.
So filtering is roughly an order of magnitude cheaper *and* the docs say it is more accurate — the two
arguments point the same way. Latency stays around 100 ms in both cases; it is the accuracy and the
debuggability you are buying. No published benchmark quantifies jev's context-rot curve.

- Field evidence (community-report): Langfuse (Annabell, 2026-09-18), writing up 6,003 rubric checks with Good Start Labs, names "context rot" as a distinct failure — accuracy drops with irrelevant input — alongside forced answers with no abstention option in their setup. Source: https://langfuse.com (post dated 2026-09-18; full URL not recorded in `50-sources/`)

## When the verdict flips

It flips to **good** when the document is decomposed: code chunks it, a retrieval step or a relevance
Noul narrows it, and each surviving chunk gets atomic questions whose answers code combines. It also
flips for genuinely short, self-contained documents where nearly every sentence bears on the question —
a single ticket, a single commit message, a single product description. The test is not "does it fit" but
"is any of this irrelevant to the question I am asking".

## Alternatives considered

- **Regex / deterministic**: section splitting, heading detection, and keyword prefilters are free; do them.
- **Small LLM**: same context-rot problem, plus higher cost per token.
- **Frontier LLM with long context**: genuinely better at whole-document reasoning; use it for the small
  number of documents that survive the filter and need synthesis.
- **Fine-tuned classifier**: document-level labels lose the location of the evidence.
- **Embeddings**: the right tool for the retrieval step that precedes jev.
- **Human**: reads the chunks jev flags as uncertain.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/classifying_rag_passages.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/semantic_find.md — accessed 2026-09-19
