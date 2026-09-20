---
id: cb-entity_alignment
title: Knowledge graph entity alignment
url: https://docs.typesafe.ai/cookbooks/entity_alignment.md
decision_shapes: [classification, routing, scoring]
primitives: [score, noul]
related: [uc-data-ml-kg-relationship-typing-and-entity-alignment, uc-commerce-catalog-entity-dedup, uc-financial-crime-entity-matching-inconsistent-names, au-replace-vector-retrieval-with-jev-rerank]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.12
---

## Task

Decide which of 450 candidate pairs from two catalogues describe the same product. "Some
cheap but rough first pass has already... picked out 450 pairs worth a closer look." One
`Score` question carries the whole decision because "its three levels are the three things
you can do with a pair: merge it, leave it unlinked, or hand it to a curator. There is no
threshold to fit". **Read that claim precisely:** rounding the Score to the nearest level *is* a
threshold policy, with implicit cut points at 0.5 and 1.5. The policy is chosen by how the levels
are worded rather than fitted to labelled data, but it is still a policy, and moving those cut
points would move pairs between actions. The cookbook reports no precision or recall for any of
the three routes, and the returned `confidence` is not used in the routing at all. Three `Noul`
questions ride the same request to tell a curator which field the two sources disagree on.

Dataset: "a published benchmark set, the Beer data from the Magellan collection: two beer
catalogues scraped from different websites, already cut down to 450 pairs by that first
rough pass." Four fields per entity: name, brewery, style, alcohol content. Each pair also
carries `known_same_as`, "the benchmark's own answer". "The text is left exactly as
published, without pre-processing: HTML entities that were never converted back to
characters, apostrophes split off as separate words, a few characters decoded wrongly."
"Numbers below came from `jev-1.12` on 2026-08-11."

## Decomposition (state, questions, how answers are combined)

Both entities go into one state, "so the questions are about the *pair* and not about
either side on its own":

```python
state={"entity_a": pair["entity_a"], "entity_b": pair["entity_b"]}
```

Four questions in one request:

```python
LEVELS = [
    "They describe two different products.",
    "They describe closely related products that may or may not be the same one: "
    "a variant, a special edition, or a name that could plausibly refer to either.",
    "They describe one and the same product.",
]
QUESTIONS = {
    "link_state": Score(instructions="How do the two entity descriptions relate as products?",
                        criteria=LEVELS),
    "same_name": Noul(instructions="Do the two entities state the same beer name?"),
    "same_brewery": Noul(instructions="Are the two entities from the same brewery?"),
    "same_style": Noul(instructions="Do the two entities describe the same beer style?"),
}
```

The whole combination rule is rounding to the nearest level:

```python
OUTCOME = {0: "leave unlinked", 1: "curator queue", 2: "assert sameAs"}
def route(score_value: float) -> str:
    return OUTCOME[min(int(score_value + 0.5), len(LEVELS) - 1)]
```

So the cut points are 0.5 and 1.5, and "There is no threshold constant anywhere in this
file." The middle level is the abstain path: pairs that are "neither safe to merge nor safe
to drop" go to a curator, and the three nouls are read only there - "these nouls provide
more detailed information for the curator, if the score lands neither in the 'same product'
nor 'different product' levels". Alcohol content deliberately gets no question, "because
comparing two numbers is arithmetic; compute it in code if you want it". Confidence is
returned and printed per pair but does not drive routing.

Why a Score: "A Noul question could accomplish this indirectly through thresholding on its
output instead, and a Choice question would lose the ordered relationship of the three
outcomes."

## Numbers reported (verbatim, with what they compare against and the run date if given)

Run: `jev-1.12`, 2026-08-11. "One request goes out per pair", 450 requests;
`MAX_WORKERS = 6` with the note "the public endpoint rate-limits above roughly eight";
`timeout=120.0`.

Routing over the 450 pairs:

| outcome | pairs | share |
|---|---|---|
| assert sameAs | 40 | 8.9% |
| curator queue | 50 | 11.1% |
| leave unlinked | 360 | 80.0% |

Worked pairs (score, confidence, then the three nouls name / brewery / style):

| pair | score | confidence | route | nouls |
|---|---|---|---|---|
| c446 | 1.94 | 0.92 | assert sameAs | 0.97 / 0.99 / 0.81 |
| c427 | 0.03 | 0.95 | leave unlinked | 0.02 / 0.09 / 0.08 |
| c100 | 1.30 | 0.27 | curator queue | 0.95 / 0.94 / 0.35 |
| c428 | 1.10 | 0.77 | curator queue | 0.63 / 0.98 / 0.74 |

Distribution: "360 score below the lower cut point and 40 above the upper one, leaving 50
for the curator." "Most land near 0.25." "Nine pairs sit within 0.1 of the upper one, at
1.5, which is the one deciding what gets merged into the graph. Forty-seven sit that close
to the lower one, at 0.5, which only decides whether a curator sees the pair."

Accuracy against `known_same_as`: not reported - the benchmark label is loaded but no
precision, recall or agreement figure is computed. Cost: not reported ("tokens and requests
are the durable units; don't cache a derived cost"). Latency: not reported. Repeats: not
reported; each pair is scored once. Comparison against named LLMs: none run.

## Caveats the cookbook itself states

- Asymmetric error cost: "Merging two entities inappropriately is the more expensive
  mistake, since every fact about either entity now describes the merged one... Missing a
  match only leaves a duplicate", which is why the middle outcome exists.
- "On this set the scores do not sit neatly on the whole numbers", and "What decides a pair
  is which side of a cut point it falls on. How near it sits to a level does not enter into
  it."
- Two beers "with nothing in common might still share a style name", so the model gives the
  middle level some probability instead of none.
- The cookbook says the cut points are not tunable knobs: "Neither number is something you tune.
  Both follow from how you worded the levels, and the wording of the middle level is what moves
  pairs between the curator and the pairs left unlinked." The 0.5 and 1.5 cut points are still a
  threshold policy; what the cookbook means is that it is tuned by rewording rather than by
  fitting to labels, and it was never validated against labels here.
- Cost scales with the first pass, not the catalogues: "what you spend follows the number of
  pairs you were handed rather than the size of either source."
- The input text is dirty by design, and the endpoint rate-limits above roughly eight
  workers.

## Lessons transferable to other use cases

- Levels as outcomes: one Score level per action you can take, and the routing rule is
  rounding — which is a 0.5 / 1.5 threshold policy expressed as wording rather than as numbers.
  Nothing is fitted to data, and the levels can be written before any score exists; equally,
  nothing here shows the resulting split is correct, since no precision or recall is reported.
- Keep a deliberate uncertain middle: variants and ambiguous names land there and go to a
  human queue rather than a coin flip.
- Fan-out for explanations: companion Nouls ride the same request at no extra call and are
  read only when the pair reaches the curator.
- Both sides in one state; comparison questions need the pair as the unit.
- Keep numeric comparison in code - ABV gets no question "because comparing two numbers is
  arithmetic".
- Does not generalise: candidate generation. jev only judges the pairs a blocking or
  similarity pass already produced, and no accuracy against the benchmark label is shown
  here.

## Use-case entries this supports

- `uc-data-ml-kg-relationship-typing-and-entity-alignment` - judge candidate duplicate pairs and route merge / queue / drop
- `uc-commerce-catalog-entity-dedup` - deduplicate product catalogues merged from several sources
- `uc-financial-crime-entity-matching-inconsistent-names` - match vendor or counterparty records across systems

**Anti-use-case implied:** `au-replace-vector-retrieval-with-jev-rerank` - do not use jev to
find candidate pairs across two catalogues; a cheap rough pass does that, and jev judges only
the pairs it hands over. Numeric field comparison (ABV) likewise stays in code.
