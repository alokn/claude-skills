---
id: uc-verification-contradiction-between-records
title: Detect that two records or claims contradict each other
verdict: good
domain: verification
decision_shapes: [detection, verification, classification]
primitives: [noul, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Graphs: "Detect contradictions between records or claims")
  - https://docs.typesafe.ai/cookbooks/citation_check.md  (three-way relation Choice: supports / contradicts / says_nothing; confidence gate at 0.8)
  - https://docs.typesafe.ai/cookbooks/classifying_rag_passages.md  (contradicts_query_premise Noul at 0.70; conflicting evidence as its own route)
  - https://docs.typesafe.ai/cookbooks/entity_alignment.md  (per-field Nouls telling a curator which field the sources disagree on)
related: [uc-data-ml-kg-relationship-typing-and-entity-alignment, uc-verification-citation-supports-claim, uc-verification-llm-output-policy-check]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to find contradictions between our records?" Also: "two sources
say different things about the same customer — can jev flag it?", "does this new filing
contradict what the company said last quarter?", "our knowledge graph has conflicting facts and
nobody notices."

## Verdict

**Good.** The use-case map names it — "Detect contradictions between records or claims" — and
three cookbooks demonstrate the pieces (the three-way relation Choice, the
`contradicts_query_premise` Noul routed to its own bucket, the per-field disagreement Nouls) —
but none measures contradiction detection over a record pair as its own task. Two design rules
carry over: pair the two records in one state so every question is about the pair, and make
"contradicts" a distinct outcome from "does not support", because the actions differ.

## What jev decides

State is the pair, with the fields code has already aligned:

```json
{"record_a": {"source": "CRM", "asof": "2026-03-01", "text": "..."},
 "record_b": {"source": "support ticket", "asof": "2026-06-14", "text": "..."}}
```

One three-way Choice, adapted from the citation cookbook, plus per-field Nouls that tell a human
*where* the conflict is — the pattern the entity-alignment cookbook uses to give a curator
something to act on:

```python
"relation": Choice(instructions="How do the two records relate on the facts they both state?",
  criteria={
    "agree":        "Everything both records state about the same thing is consistent",
    "contradict":   "They state different values or opposite facts about the same thing",
    "complementary":"They cover different things and make no overlapping claim",
    "unclear":      "They may refer to different things, so no comparison can be made"}),
"conflict_is_material": Noul("Would acting on record_a instead of record_b lead to a different outcome?"),
"explained_by_time": Noul("Could the difference be explained by the records describing different points in time?",
  true="One record describes a state that could have changed into the other.",
  false="The difference is about a fact that does not change."),
"same_subject": Noul("Do the two records describe the same entity or event?"),
```

`same_subject` is load-bearing: most false contradictions are really two different subjects.
Ask it explicitly rather than assuming the join was right.

Three routes, following the RAG cookbook's ladder: `same_subject` low -> not a conflict;
`contradict` with `conflict_is_material` high -> open a data-quality case; anything else with
moderate confidence -> a review queue. Gate on `confidence`; the citation cookbook's 0.8
auto-accept is a sensible starting point — "start high for more human review as you build trust
in the model."

## What stays in code

The candidate pairing (join keys, blocking, fuzzy shortlist), every numeric and date comparison
— "explained by time" is a *semantic* question about whether a fact is mutable, while *which
record is newer* is a timestamp comparison code must do — the precedence rule that decides which
source wins, the case ticket, and the thresholds.

## Numbers

Transferable measurements, none of them from a contradiction benchmark:

- `citation_check.md`, `jev-1.12` on 2026-08-16: the planted `exp_required` contradiction —
  a quote reproduced word for word whose section also says "Use of this claim is OPTIONAL" —
  came back `contradicts` at confidence 0.99, while accurate citations read `supports` at 0.93
  to 0.99 and genuine non-support read 0.27 and 0.56 and went to review.
- `classifying_rag_passages.md`, `jev-1.12` / `claude-sonnet-5` on 2026-08-27: the passage that
  refutes the query's false premise scored `contradicts_query_premise` 0.92 while its relevance
  read 0.49 and its answer-evidence 0.51 — "those two alone would have dropped it". Contradiction
  is a separate signal from relevance, and the threshold used was 0.70.

Cost: a pair of 500-token records plus four questions is roughly 1,300 input tokens, about
$0.00005 per pair at $0.042 per million input tokens with free output. Latency 70-500 ms.
No precision or recall figure exists for this task; collect labelled conflicting pairs before
setting a threshold.

Closest jaggedness mode: **4, indirection.** "Do these contradict?" hides two hops — same
subject, then same fact different value. The `same_subject` Noul splits the first hop out.

## When the verdict flips

- **The conflict is between typed values** — two amounts, two dates, two enum codes. Compare in
  code; it is exact, and modes 2 and 3 say jev is not. Use jev only for prose fields.
- **You compare every pair.** Cost is linear in pairs; blocking in code must come first, exactly
  as the entity-alignment cookbook assumes ("Some cheap but rough first pass has already
  compared the two sources").
- **A precedence rule already resolves it** ("the ledger always wins"). Then detection is
  cosmetic unless you want a data-quality metric.
- **Records are long and mostly irrelevant.** Mode 5: send the aligned fields, not the documents.
- **The contradiction triggers an automatic write.** Keep a human in the loop; the entity
  alignment cookbook's reasoning applies — the destructive action is the expensive mistake.

## Alternatives considered

- **Field-level diff after normalisation** — exact, free, and the right first tool; it produces
  a flood of false conflicts on prose fields and formatting differences.
- **NLI / entailment model** — purpose-built for contradiction and the strongest specialist
  alternative; it expects sentence pairs, not records, and gives no route for "different subject"
  or "different point in time".
- **Rules engine on known conflict patterns** — durable where the conflicts are known in advance;
  useless for the ones you have not seen.
- **Frontier LLM comparing records** — accurate and returns an explanation, at seconds and cents
  per pair; usable on the flagged tail, not the population.
- **Human data stewards** — the incumbent, and where the material conflicts should still land;
  the point is to hand them a ranked queue instead of a diff report.

## Sources

- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/citation_check.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/classifying_rag_passages.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/entity_alignment.md — accessed 2026-09-19
