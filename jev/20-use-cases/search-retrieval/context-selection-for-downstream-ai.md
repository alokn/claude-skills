---
id: uc-search-retrieval-context-selection-for-downstream-ai
title: Select which records, files or fields enter a downstream AI workflow's context
verdict: good
domain: search-retrieval
decision_shapes: [retrieval, detection, ranking]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  ("Select useful context for downstream AI workflows"; Harness Engineering: "semantic context retrieval")
  - https://docs.typesafe.ai/cookbooks/classifying_rag_passages.md  (worked per-passage relevance gating; threshold ladder)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5: "retrieve and filter in code first"; "you can use a Noul to filter for relevance")
  - https://docs.typesafe.ai/cookbooks/skill_suggestion.md  (progressive disclosure; spend tokens only on the shortlist so prefix caching holds)
related: [uc-search-retrieval-rag-passage-gating, au-context-compaction-by-relevance-scoring, uc-agents-harness-skill-or-tool-selection]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to decide what goes into an LLM's context?" Also: "our prompt is
80k tokens of mostly irrelevant records — can jev prune it?", "which of these 40 files should
the coding agent read?", "how do we pick the right five customer records for the summariser?"

## Verdict

**Good.** The use-case map lists "Select useful context for downstream AI workflows" as a
search use case and names semantic context retrieval under harness engineering, and the
jaggedness page recommends the shape explicitly — "When it's not possible to filter in state,
you can use a [Noul] to filter for relevance" — but the only worked example is the RAG-passage
cookbook, which is one instance of it. The economics are the argument: the downstream call
costs dollars per million tokens and seconds; the selection costs $0.042 per million input
tokens and about 100 ms.

## What jev decides

One call per candidate item, with the *task* and the *item* in the same state so the judgement
is about the pair:

```json
{"task": "Explain why the invoice for account 4471 was rejected",
 "item": {"id": "svc-log-2211", "kind": "service_log", "excerpt": "..." }}
```

Two or three Nouls plus one Score, all in one request:

```python
"bears_on_task": Noul(instructions="Does this item contain information that changes how the task should be answered?",
  criteria=NoulCriteria(
    true="The item states a fact the answer would have to take into account.",
    false="The item is on a related subject but the answer would read the same without it."),
"is_superseded": Noul(instructions="Does this item describe a state that a later item in the set replaces?"),
"specificity": Score(instructions="How specific is this item to the entity named in the task?",
  criteria=["Generic background", "About the same class of entity", "About this entity", "About this exact event"]),
```

The `false` criterion is where the design lives: "on a related subject but the answer would
read the same without it" is the class of item that similarity search keeps and that causes
context rot.

Code sets a floor, sorts on `specificity`, and fills a token budget — a first-match-wins ladder
exactly like the RAG cookbook's `THRESHOLDS` dict. Follow the skill-suggestion cookbook's
progressive disclosure: leave the cheap index alone so prefix caching over it still holds, and
spend the extra tokens only on the shortlist.

## What stays in code

The candidate set (SQL, ACL, tenancy, freshness, the retriever), the token budget and the
packing, deduplication, ordering in the prompt, and any item that must always be present
(the user's own message, the schema, the policy). Never let the selector drop a mandatory
field — keep that list in code.

## Numbers

Cost is linear in candidates: one call per item, roughly (task + item excerpt) tokens each. A
500-token excerpt with three questions is about 700 input tokens, roughly $0.00003 per item, so
100 candidates is about $0.003 per task at $0.042 per million input tokens with free output.
Compare that against what the downstream call pays per thousand tokens it did not need.

The only published measurement of the shape is the RAG cookbook: on six queries over 12
retrieved passages each, "At least two thirds of every bar is excluded", and the assembled
prompt for the first query is "1,282 characters". No accuracy or downstream-quality figure is
published for general context selection — run your own A/B on answer quality, not on the
selector's agreement with your intuition.

Closest jaggedness mode: **5, large state full of irrelevant detail.** This use case *is* the
documented mitigation, applied to the next model in the chain rather than to jev.

- Field evidence (community-report): a web-search tool uses jev twice - once to select which sources are worth fetching, once to rank the results that come back - before any of it reaches the answering model; no numbers published, 2026-09. Source: https://github.com/superagents-lab/jev-search

## When the verdict flips

- **Everything fits in the context window and the downstream model handles it well.** Then
  selection adds a failure mode for no gain — **weak**. Measure before pruning.
- **Dropping a record is unrecoverable** (legal discovery, audit evidence, safety-relevant
  history). Selection must be recall-biased and reviewable, or stay deterministic.
- **Selection depends on arithmetic or recency ordering** ("the three most recent", "everything
  over $10k"). Modes 2 and 3: code does that, jev judges only what code cannot express.
- **Hundreds of candidates in a latency-sensitive path.** One call per item; pre-filter hard, or
  batch candidates into a ranked Choice (255 options max) instead of per-item Nouls.
- **Candidate text is attacker-controlled.** Mode 6; pair with the injection noul.

## Alternatives considered

- **Embedding similarity to the task** — the incumbent, cheap and indexable; it cannot separate
  "related subject" from "changes the answer", which is the distinction that matters here.
- **Recency / heuristic windows** ("last 20 messages", "files touched this week") — free,
  predictable, and genuinely good; start here and only add jev where the heuristic demonstrably
  drops needed items.
- **Let the big model read everything** — simplest, and the thing being paid for; the trade is
  its token bill and its own context rot against the selector's cost and its false drops.
- **A small LLM as selector** — comparable in spirit, but returns prose or JSON to parse and
  gives no typed per-item probability to threshold unless you read logprobs.
- **Human curation** — right for a fixed, small knowledge base; not for per-request selection.

## Sources

- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/classifying_rag_passages.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/skill_suggestion.md — accessed 2026-09-19
