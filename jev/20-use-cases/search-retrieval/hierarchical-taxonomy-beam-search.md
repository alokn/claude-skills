---
id: uc-search-retrieval-hierarchical-taxonomy-beam-search
title: Classify into a deep taxonomy with a Choice per node and beam search over the probabilities
verdict: good
domain: search-retrieval
decision_shapes: [classification, search, ranking]
primitives: [choice]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/hierarchical_classification.md  (CPC / Shopify / MeSH / repo files; beam 4 of 4 vs greedy 2 of 4; path scoring)
  - https://docs.typesafe.ai/primitives/choice.md  (255-option cap)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Graphs: "Support probabilistic traversal and hierarchical classification")
related: [uc-search-retrieval-confidence-fallback-broader-level, uc-data-ml-kg-relationship-typing-and-entity-alignment, uc-search-retrieval-semantic-find-in-document]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to classify into a taxonomy with thousands of leaves?" Also:
"our category tree is too big for one prompt — how do we walk it?", "can jev assign a CPC or
MeSH code?", "our classifier goes wrong at the top of the tree and never recovers."

## Verdict

**Good**, provided the taxonomy is a fixed, enumerable tree (or a DAG you flatten) and you
run beam search rather than greedy descent. The official hierarchical-classification cookbook
demonstrates the mechanism and beats greedy descent (4 of 4 vs 2 of 4 leaves correct), but on only
four labelled documents, which is a demonstration rather than a task-matched measurement; measure leaf
accuracy on your own taxonomy before acting. A flat Choice caps at 255 options and loses
accuracy long before that; one Choice over a node's direct children is small, cheap and
testable. The payload that makes this work is the *full probability distribution*, not the
argmax — greedy throws it away and "One early mistake cannot be recovered."

## What jev decides

State is the raw document. One question, re-instantiated at every node with that node's
direct children as options:

```python
Choice(instructions="Which direct child category best matches this document?",
       criteria=keys)   # {"c0": label0, "c1": label1, ...}
```

Options get opaque keys `c0..cN`, mapped back to labels after the call; a node with one child
short-circuits with no API call. Where a node's own label is uninformative, build the option
description from the taxonomy source rather than by hand (the SIC recipe does this because
"42 of the 75 carry an umbrella title in the SEC's list, and the rest carry none").

There is no confidence band and no abstain in the cookbook: every run returns a leaf. If your
product needs "unclassifiable", add a `none of these` option at each level or use the
confidence roll-up described in the sibling entry.

## What stays in code

All of the search. The beam, the expansion, the arithmetic:

```python
MODEL, BEAM_WIDTH, MAX_DEPTH, EPSILON = "jev-1.12", 3, 12, 1e-9
probability_product *= max(probabilities[label], EPSILON) if is_decision else 1.0
score = probability_product ** (1 / decision_count) if decision_count else 1.0
beam = sorted(finished + expanded, key=score, reverse=True)[:BEAM_WIDTH]
separation = top_path_score / max(second_path_score, EPSILON)
```

Path score is length-normalised "so that shallow and deep leaves are compared fairly";
finished leaves re-enter the sort so a leaf competes with deeper partial paths. For trees
deeper than ~10 levels the cookbook says to "use `exp(mean(log(probs)))`" to avoid precision
errors. Flattening a DAG into tree-number paths is also code.

## Numbers

From `hierarchical_classification.md`, `jev-1.12`, one labelled document per hierarchy (CPC
2026.05 patents, Shopify 2026-02 products, MeSH 2026, TypeSafe's own repo snapshot
2026-08-06): "Beam search matched 4 of 4 expected leaves; greedy search matched 2 of 4.
Keeping three paths recovered the expected classification for CPC patents, Shopify products."
Greedy sent the bird-perch patent to `E99Z99/00 Subject matter not otherwise provided for in
this section`; beam K=3 reached `A01K31/12 Perches for poultry or birds`.

Constants: `K=3`, `MAX_DEPTH = 12`, `EPSILON = 1e-9`. Cost, latency, token counts and repeats:
**not reported**. The accuracy claim is four single examples, not an estimate — treat it as a
demonstration of the mechanism. Each beam round expands candidates in parallel, so "extra
exploration adds little wall-clock latency"; cost is one call per non-trivial node visited,
roughly `beam_width x depth` calls per document at $0.042 per million input tokens.

Closest jaggedness mode: **literal reading (1)** at each node, mitigated by writing sibling
descriptions that contrast; and the option cap, which is why the tree exists at all.

- Field evidence (community-report): a community library implements hierarchical, high-cardinality classification as staged Choices down a tree, one call per level; no numbers published, 2026-09. Source: https://github.com/reachjalil/jev-tree

## When the verdict flips

- **The label space is open-ended** — new categories appear faster than you can enumerate
  them. This becomes **no**; the shape needs a fixed sibling set per node.
- **A single level has more than 255 siblings.** Chunk and rank, then re-run the Choice over
  winners (the two-stage shape from the skill-suggestion cookbook).
- **Leaves are distinguished by numbers or dates** (thresholds on amount, age, version).
  Modes 2 and 3: bucket in code first, let jev decide only the semantic branch.
- **The taxonomy is shallow (two or three levels, under ~200 leaves).** One flat Choice is
  simpler and cheaper; the SIC recipe used 75 options in one call.
- **You need an audit trail of *why*.** You get the per-node distributions, which is more than
  most classifiers give, but no explanation — do not promise one.

## Alternatives considered

- **Flat Choice over every leaf** — right up to a few hundred options; beyond that the cap and
  the accuracy drop force the tree.
- **Hierarchical softmax / fine-tuned per-node classifiers** — better throughput and accuracy
  when you have labelled data at every node; jev wins when you have a taxonomy file and no
  labels, and when a taxonomy edit must ship the same day (you unit-test one edge, not retrain).
- **Embedding nearest-neighbour against leaf descriptions** — cheap and index-friendly, but
  conflates "similar words" with "belongs under"; the Shopify example (Pet Chairs vs Cat Window
  Beds & Perches) is exactly that failure.
- **Frontier LLM with the whole taxonomy in the prompt** — possible for medium trees, expensive
  for big ones, and returns a string you must validate against the tree.
- **Keyword rules per node** — durable where the taxonomy is defined by controlled vocabulary
  (ICD codes in coded fields); useless on free prose.
- **Human coders** — the incumbent for patents and MeSH; use the beam's `separation` ratio to
  decide which documents still need them.

## Sources

- https://docs.typesafe.ai/cookbooks/hierarchical_classification.md — accessed 2026-09-19
- https://docs.typesafe.ai/primitives/choice.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
