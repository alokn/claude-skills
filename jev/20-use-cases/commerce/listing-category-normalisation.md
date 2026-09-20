---
id: uc-commerce-listing-category-normalisation
title: Normalise a seller's product listing into your own category taxonomy
verdict: good
domain: commerce
decision_shapes: [classification]
primitives: [choice]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/hierarchical_classification.md  (one Choice per taxonomy node, greedy vs beam search; on the Shopify 2026-02 retail taxonomy greedy reached "Pet Chairs" and beam K=3 reached the expected "Cat Window Beds & Perches"; beam matched 4 of 4 expected leaves, greedy 2 of 4; K=3, MAX_DEPTH=12)
  - https://docs.typesafe.ai/cookbooks/classification_using_confidence.md  (75 industry groups over 60 filings; "a Choice works reliably up to roughly 240 options"; at conf >= 0.9, 27/30 right, below it 12/30; answering one level coarser turns 39/60 into 48/60 useful answers)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (e-commerce marketplaces: "Classify and normalize product listings across inconsistent seller catalogs")
  - https://docs.typesafe.ai/models.md  (Choice caps at 255 options)
related: [uc-commerce-attribute-extraction, uc-commerce-catalog-entity-dedup, uc-support-ticket-team-routing]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to categorise product listings?" Also "can jev map a seller's
messy title to our taxonomy?", "can we replace the keyword rules that assign category from
the title?", and "our taxonomy has 4,000 leaves — can jev handle it?".

## Verdict

**Good** — the shape is demonstrated by the `hierarchical_classification` and
`classification_using_confidence` cookbooks, neither of which measured product listings;
no task-matched labelled accuracy is published; shadow-evaluate against the incumbent
before acting. The shape depends on taxonomy size: a flat Choice up to roughly 240
options, and a per-level Choice with beam search below that. The
hierarchical-classification cookbook runs exactly this on the Shopify 2026-02 retail
taxonomy and shows why the shape matters — greedy descent landed on "Pet Chairs" while
beam search with K=3 recovered the expected "Cat Window Beds & Perches" from the same
model. Listings are short text, the answer space is closed and yours, confidence gives a
review path, and code owns the write to the catalogue. All seven fit-test questions
pass.

Closest failure mode: **literal reading** — a seller's marketing wording is not the taxonomy's
meaning, so each level's criteria state what the category covers and what it excludes, and
beam search stops one literal match at a high level from deciding the leaf.

## What jev decides

Flat case (one department, ≤ 240 leaves), one call:

```
category: Choice
  instructions: {question: "Which catalogue category does this listing belong in?",
                 focus: "Classify what the item is, not who it is for or how it is sold."}
  criteria:
    cat_bedding_pet:   {what: "Beds, mats, and resting furniture for pets",
                        not_for: "Carriers, crates, or pet clothing",
                        examples: ["cat window perch", "orthopaedic dog bed"]}
    cat_furniture_pet: {what: "Climbing frames, trees, and scratching furniture",
                        not_for: "Beds without a climbing structure"}
    ...
    other:             {what: "No listed category describes this item"}
```

Deep case: one Choice per level over that node's children, descending. Keep the top K=3 paths
by probability rather than committing to the argmax at each level, which is the cookbook's
central finding; code does the beam bookkeeping and the depth limit.

Ride along in the same call: `is_multipack` (Noul), `is_accessory_not_device` (Noul — the
single most common misclassification in electronics), and `listing_is_a_bundle` (Noul).

Bands: the classification-with-confidence cookbook's alternative to abstaining is the useful
one here — when confidence is low, publish the *parent* category rather than the leaf. In its
run, forcing a leaf gave 39/60 right; answering one level up when unsure gave 48/60 useful
answers, with the confident half right 27/30 and the unsure half 12/30 at leaf level.

## What stays in code

The taxonomy, the write, and every deterministic shortcut. A GTIN, an ASIN, a manufacturer
part number or a seller's own mapped category resolves the category by lookup — do not spend
a call when an identifier already answers it. Merchandising rules, restricted-category gates,
and tax-code mapping stay deterministic. Node children are enumerated by code at each level.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 300-character title plus a
400-character description plus 60 short option descriptions (~4,000 characters) is ≈ 1,175
tokens, **≈ $0.000049 per listing** for the flat case. A five-level beam with K=3 is up to 15
node calls, but each carries only that node's children (~600 characters) plus the listing, so
roughly 300 tokens each: **≈ $0.0002 per listing**, still under a fiftieth of a cent.
Latency 70–500 ms per call; a five-level beam is five sequential rounds, so budget 0.5–2.5 s
for the deep case and run it off the request path. Accuracy on your taxonomy is unmeasured —
the cookbook's 4-of-4 is one labelled document per hierarchy, which it states plainly.

## When the verdict flips

- The taxonomy is flat and larger than ~255 leaves. That is the hard Choice cap; the shape
  must become hierarchical or two-stage.
- The category is derivable from a structured identifier. Lookup wins.
- Listings are mostly non-English, which on a global marketplace they are. Run a per-locale
  evaluation; English is the strongest language.
- You need the category to be legally correct (dangerous goods, age-restricted items). Keep
  a deterministic gate on those categories and treat jev as a suggestion.
- You want the model to invent a category for uncovered items. Generation; keep `other` and
  route it to a taxonomy owner.

## Alternatives considered

- **Keyword and title-pattern rules.** What most marketplaces run, and what drowns: sellers
  stuff titles with every synonym, so lexical rules fire on the noise.
- **Embedding nearest-centroid over category exemplars.** Cheap and reasonable; it has no
  notion of "accessory for X is not X", the mistake that costs the most, and it needs a
  threshold you must tune per branch.
- **Frontier LLM.** Best on ambiguous listings and on inventing taxonomy suggestions; too
  slow and too expensive for a full catalogue re-classification, which is the actual job.
- **Small LLM.** Workable; roughly an order of magnitude more cost and latency per call on the
  consistency cookbooks' measurements, and it can return a category that does not exist — a
  Choice structurally cannot.
- **Fine-tuned classifier.** The right answer at very high volume with a stable taxonomy and
  millions of labelled listings; every taxonomy revision is a retrain.

## Sources

Accessed 2026-09-19. `cookbooks/hierarchical_classification.md` (Shopify result, beam vs
greedy, K=3), `cookbooks/classification_using_confidence.md` (240-option guidance; 27/30 and
12/30; 39/60 -> 48/60; `jev-1.12`, 2026-08-12), `concepts/use-case-map.md`, `models.md`.
