---
id: uc-commerce-catalog-entity-dedup
title: Decide merge, leave, or review for candidate duplicate catalogue entries
verdict: good
domain: commerce
decision_shapes: [verification, classification]
primitives: [score, noul]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/entity_alignment.md  (450 candidate pairs from two beer catalogues; one 3-level Score — different product / related but possibly not the same / same product — plus three field Nouls in one request; outcomes 40 merge (8.9%), 50 curator (11.1%), 360 leave unlinked (80.0%); `jev-1.12`, 2026-08-11; "There is no threshold constant anywhere in this file")
  - https://docs.typesafe.ai/concepts/use-case-map.md  (e-commerce: normalise listings across inconsistent seller catalogs; graphs: "Detect contradictions between records")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 2: comparing two numbers is arithmetic — do it in code)
  - https://docs.typesafe.ai/primitives/score.md  (Score levels carry semantic labels and preserve order)
related: [uc-commerce-listing-category-normalisation, uc-commerce-attribute-extraction, uc-hr-recruiting-candidate-routing]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to deduplicate a product catalogue?" Also "can jev decide if
two seller listings are the same product?", "can we replace our fuzzy-match threshold?", and
"how do we stop bad merges?".

## Verdict

**Good** — the shape is demonstrated by the `entity_alignment` cookbook; no task-matched
labelled accuracy is published; shadow-evaluate against the incumbent before acting. The
published shape: code blocks the space down to candidate pairs, and one three-level
Score decides each pair, because the three levels *are* the three things you can do with
a pair — merge it, leave it, or send it to a curator. The design's distinguishing
property is that there is no threshold to fit. The level descriptions carry the whole
decision, and you can write them before seeing a single score, which is not true of a
similarity cut-off. That matters here because the errors are asymmetric: a wrong merge
propagates every fact from both entities and is expensive to undo, while a missed match
leaves a duplicate.

## What jev decides

State: the two entity records, side by side, with only the comparable fields. One request per
pair.

```
state = {"entity_a": {...}, "entity_b": {...}}

link_state: Score
  instructions: "How do the two product descriptions relate as products?"
  criteria:
    - "They describe two different products."
    - "They describe closely related products that may or may not be the same one:
       a variant, a special edition, a different pack size, or a name that could
       plausibly refer to either."
    - "They describe one and the same product."

same_model_name: Noul   instructions: "Do the two entities state the same product name?"
same_brand: Noul        instructions: "Are the two entities from the same brand or manufacturer?"
same_variant: Noul      instructions: "Do the two entities describe the same variant — colour,
                                       size, pack quantity, or edition?"
```

Code maps the score to the action with the cut points that fall out of the three levels
(below 0.5 leave unlinked, above 1.5 merge, between them to the curator), and the three Nouls
ride along in the same request to tell the curator *which field* the two sources disagree on.
The middle level is the one to write carefully: in the cookbook it deliberately covers
variants and special editions, so those reach a human rather than being merged or dropped.

## What stays in code

Blocking, and everything exact. A shared GTIN, EAN or manufacturer part number is a merge by
identity — never ask. Fuzzy string scores, shared-token blocking, or an embedding shortlist
produce the candidate pairs; you pay per pair, so the blocking stage controls the bill. The
merge itself, provenance, and the undo path are code. Numeric field comparison is arithmetic:
the cookbook gives alcohol content no Noul for exactly this reason, noting "comparing two
numbers is arithmetic; compute it in code if you want it".

## Numbers

Measured (cookbook, `jev-1.12`, 2026-08-11, 450 candidate pairs from the Magellan Beer
benchmark, one request per pair, four questions per request): outcomes were **40 merges
(8.9%)**, **50 to the curator (11.1%)** and **360 left unlinked (80.0%)**. The scores cluster
near 0.25 rather than on whole numbers, and the cookbook notes nine pairs sit within 0.1 of
the merge cut point against 47 near the curator cut point — the expensive boundary is the
sparse one. Text was fed in as published, with HTML entities and mis-decoded characters
intact. Cost, by the standard method: two ~200-character records plus these four questions
(~700 characters) is ≈ 275 tokens, **≈ $0.000012 per pair**; 450 pairs ≈ $0.005. **Precision
and recall against the benchmark's `known_same_as` labels are not reported** — the cookbook
publishes the outcome split, not an accuracy figure, so measure yours on a labelled sample.

## When the verdict flips

- You skip blocking and try every pair. A million-row catalogue is 5×10^11 pairs; the fit
  test fails on volume, not on judgement.
- Identifiers exist and agree. Deterministic merge; do not spend a call.
- Merges are applied automatically with no curator queue. The middle level exists precisely
  because the expensive error needs somewhere to go (fit-test question 6).
- The distinguishing difference is numeric (750ml vs 700ml, 12-pack vs 6-pack). Put the
  parsed values in as named facts, or compare them in code and pass the result in.
- Records are long marketing documents. Filter to the comparable fields first; context rot is
  failure mode 5.

## Alternatives considered

- **Fuzzy string matching (Levenshtein, rapidfuzz).** Keep it as the blocker. As the decider
  it produces false merges on near-identical variant names, which is the costly error.
- **Embedding cosine threshold.** Same role and same weakness: "Ambleside Amber Ale" and
  "Ambleside Amber Ale — Pomegranate & Galena Hops" are maximally similar and are not the same
  product. The cookbook's worked curator case is exactly that pair, at score 1.10.
- **Frontier LLM per pair.** Good judgement, and at 450 pairs it is affordable while at
  450,000 it is not; this is the volume argument in its purest form.
- **Small LLM.** Roughly an order of magnitude more cost and latency per call, with a free-text
  answer you must parse into three outcomes.
- **Trained matcher (Magellan, Ditto).** State of the art with labelled pairs; this needs none.
- **Human curation of every pair.** What the 80% "leave unlinked" and 8.9% "merge" bands remove.

## Sources

Accessed 2026-09-19. `cookbooks/entity_alignment.md` (levels verbatim, 450 pairs, 40/50/360
split, cut-point density, `jev-1.12`, 2026-08-11; no precision/recall reported),
`concepts/use-case-map.md`, `model-jaggedness/jev-1.13.md`, `primitives/score.md`, `models.md`.
