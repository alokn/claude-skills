---
id: uc-data-ml-kg-relationship-typing-and-entity-alignment
title: Decide whether two entity records are the same thing, and what relationship links them
verdict: good
domain: data-ml
decision_shapes: [classification, verification, scoring]
primitives: [score, noul, choice]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/entity_alignment.md  (450 Magellan beer pairs; 3-level Score; 40 sameAs / 50 curator / 360 unlinked; worked pair scores)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Graphs: "Classify relationships and entity types"; Financial crime: "Match entities across inconsistent names")
  - https://docs.typesafe.ai/primitives/score.md  (2-10 ordered levels)
related: [uc-verification-contradiction-between-records, uc-search-retrieval-hierarchical-taxonomy-beam-search, uc-data-ml-map-reduce-corpus-labelling]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev for entity resolution?" Also: "fuzzy matching keeps merging things
that are not the same", "can jev decide which candidate pairs a curator should see?", "how do we
type the relationship between two nodes in our knowledge graph?"

## Verdict

**Good**, on a shortlist that code has already produced, and with a three-outcome Score
rather than a yes/no — the shape is demonstrated by the `entity_alignment` cookbook; no
task-matched labelled accuracy is published; shadow-evaluate against the incumbent
before acting. The cookbook's reasoning is the design: "Merging two entities
inappropriately is the more expensive mistake... Missing a match only leaves a
duplicate, so the judgment call needs a third option: pairs that are neither safe to
merge nor safe to drop." The Score's three levels *are* the three actions, so "There is
no threshold to fit".

## What jev decides

State is the pair, so every question is about the pair and not about either side:

```python
state = {"entity_a": pair["entity_a"], "entity_b": pair["entity_b"]}
```

One Score whose levels are the outcomes, plus one Noul per compared field to tell the curator
where the disagreement is — all four in one request:

```python
LEVELS = [
    "They describe two different products.",
    "They describe closely related products that may or may not be the same one: "
    "a variant, a special edition, or a name that could plausibly refer to either.",
    "They describe one and the same product.",
]
OUTCOME = {0: "leave unlinked", 1: "curator queue", 2: "assert sameAs"}

QUESTIONS = {
    "link_state":   Score(instructions="How do the two entity descriptions relate as products?", criteria=LEVELS),
    "same_name":    Noul(instructions="Do the two entities state the same beer name?"),
    "same_brewery": Noul(instructions="Are the two entities from the same brewery?"),
    "same_style":   Noul(instructions="Do the two entities describe the same beer style?"),
}
```

A Score, not a Choice or a Noul, because the outcomes are ordered and each carries a semantic
label: "A Noul question could accomplish this indirectly through thresholding on its output
instead, and a Choice question would lose the ordered relationship of the three outcomes."

The whole decision rule is one line of code — `OUTCOME[min(int(score_value + 0.5), len(LEVELS)-1)]`
— "the nearest level names the outcome".

For **relationship typing** the same shape applies with a Choice instead: put both nodes and the
sentence that links them in state, and offer the ontology's relation types plus `no_relation` and
`other`.

## What stays in code

Blocking — "Some cheap but rough first pass has already compared the two sources and picked out
450 pairs worth a closer look" — the level wording, the rounding rule, the `sameAs` write, the
curator queue, and every numeric comparison. Alcohol content deliberately gets no question:
"comparing two numbers is arithmetic; compute it in code if you want it."

## Numbers

From `entity_alignment.md`, `jev-1.12` on 2026-08-11. 450 candidate pairs from the Magellan Beer
benchmark (two scraped catalogues), text left exactly as published including mis-decoded
characters, one request per pair, 6 workers.

```
assert sameAs      40  ( 8.9%)
curator queue      50  (11.1%)
leave unlinked    360  (80.0%)
```

Worked pairs: `c446` score 1.94 / confidence 0.92 -> assert sameAs (name 0.97, brewery 0.99,
style 0.81); `c427` score 0.03 / confidence 0.95 -> leave unlinked; `c100` score 1.30 /
confidence 0.27 -> curator queue, where name and brewery read 0.95 and 0.94 but style reads 0.35
because the sources word it differently; `c428` score 1.10 / confidence 0.77 -> curator queue, a
beer against a "Pomegranate & Galena Hops" variant of it.

Crowding around the cut points: "Nine pairs sit within 0.1 of the upper one, at 1.5, which is the
one deciding what gets merged into the graph. Forty-seven sit that close to the lower one, at
0.5." And: "Neither number is something you tune. Both follow from how you worded the levels, and
the wording of the middle level is what moves pairs between the curator and the pairs left
unlinked." Accuracy against `known_same_as` (the benchmark ships it) is **not reported** in the
page; cost, latency and token counts are not reported either.

Closest jaggedness mode: **2, math and numbers** — the ABV field is deliberately left to code.

- Field evidence (community-report): a genealogy practitioner on the launch thread reports that entity alignment at 100,000^2 candidate pairs is infeasible per-pair regardless of per-call cost, and other commenters agree that blocking strategies remain mandatory before any per-pair call, 2026-09. Source: https://news.ycombinator.com/item?id=49717558

## When the verdict flips

- **No blocking stage.** Cost is one call per pair; a full cross-product of two catalogues is
  **no**. Fuzzy score, shared keys or embeddings must cut the pairs first.
- **Identity is determined by a key** — a shared DOI, ISBN, VAT number, GTIN. Join on it.
- **The merge is automatic and irreversible.** Keep the curator queue; the cookbook's whole design
  exists because "Undoing it later means working out which fact came from where."
- **Differences are numeric or date-based** (dosage, ABV, effective date). Compare in code and put
  the boolean in state.
- **The middle level is written loosely.** It is the only knob, and it decides how much curator
  work you create. Rewrite it before you touch anything else.
- **Records are long documents.** Mode 5: align to the compared fields, do not send the profiles.

## Alternatives considered

- **Deterministic key join** — exact and free; use it wherever a key exists.
- **Fuzzy string match (Levenshtein, rapidfuzz, Jaro-Winkler)** — the right blocking stage, and
  the documented failure mode as a decider: "Frost Quake Bourbon Barrel Aged Barley Wine" against
  "Lompoc Bourbon Barrel Aged Proletariat Red Ale" shares a great deal of surface and is not the
  same beer.
- **Embedding cosine over concatenated fields** — better than edit distance and still a threshold
  you must fit, with no way to express "variant, possibly the same".
- **Trained entity-matching model (Magellan, Ditto)** — the strongest option with labelled pairs,
  and this benchmark is exactly what they are trained on; jev wins at cold start, when the
  decision rule must be written in English, and when a third "send to a curator" outcome is
  required.
- **Frontier LLM per pair** — capable and priced per pair in cents, not fractions of a cent.
- **Human curators on everything** — the incumbent; here 20% of pairs still reach them, which is
  the honest saving.

## Sources

- https://docs.typesafe.ai/cookbooks/entity_alignment.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/primitives/score.md — accessed 2026-09-19
