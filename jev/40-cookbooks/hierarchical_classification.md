---
id: cb-hierarchical_classification
title: Hierarchical classification
url: https://docs.typesafe.ai/cookbooks/hierarchical_classification.md
decision_shapes: [classification, search, ranking]
primitives: [choice]
related: [uc-search-retrieval-hierarchical-taxonomy-beam-search, uc-commerce-listing-category-normalisation, uc-sdlc-semantic-code-search-ranking, uc-legal-compliance-policy-violation-detection, au-flat-choice-over-255-options]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.12
---

## Task

Traverse a deep taxonomy to the correct leaf node by asking one `Choice` question per
node, comparing greedy descent against parallel beam search. Four hierarchies, one
labelled document each:

- **CPC 2026.05** patent subject matter, from `CPCSchemeXML202605.zip`.
- **Shopify 2026-02** retail product categories, from `product-taxonomy/v2026-02/dist/en/categories.txt`.
- **MeSH 2026** biomedical subjects, from `desc2026.zip`. "MeSH is a DAG, so one
  descriptor can appear under multiple parents; this demo expands its official tree-number
  paths."
- **CookSafe files**, TypeSafe's own cookbook repository, "snapshot 2026-08-06".

Node counts per hierarchy are computed at load time but no value is printed in the page:
not reported. Model is set in code as `MODEL = "jev-1.12"`. No sampling date for the run
itself is stated: not reported.

## Decomposition (state, questions, how answers are combined)

State is the raw document string — `client.system_one(state=state, ...)` where `state` is
`hierarchy.document`, e.g. the CPC one: "Patent abstract: a freestanding structural wooden
perch for poultry or pet birds. ..."

One question, re-instantiated at every node with that node's direct children as options:

```python
question = Choice(
    instructions="Which direct child category best matches this document?",
    criteria=keys,  # {"c0": label0, "c1": label1, ...}
)
```

Options are given opaque keys `c0..cN` and mapped back to labels after the call. A node
with a single child short-circuits to `{labels[0]: 1.0}` with no API call.

Search arithmetic:

```python
MODEL, BEAM_WIDTH, MAX_DEPTH, EPSILON = "jev-1.12", 3, 12, 1e-9
# per edge, only decisions (>1 option) count
probability_product *= max(probabilities[label], EPSILON) if is_decision else 1.0
decision_count += is_decision
score = probability_product ** (1 / decision_count) if decision_count else 1.0
```

- `path_score = product(edge_probabilities) ** (1 / decisions)` — "length-normalized so
  that shallow and deep leaves are compared fairly"; used for pruning and comparing paths.
- Each round expands every frontier candidate in parallel
  (`ThreadPoolExecutor(max_workers=BEAM_WIDTH)`), then
  `beam = sorted(finished + expanded, key=score, reverse=True)[:BEAM_WIDTH]`. Finished
  (leaf) candidates re-enter the sort, so a leaf competes against deeper partial paths.
- `separation = top_path_score / second_path_score`, computed as
  `top_score / max(second_score, EPSILON)` — "useful metric, but not used for pruning".
  Near `1×` is ambiguous; a large ratio means clear separation.
- Greedy takes `max(probabilities, key=probabilities.get)` at each node: "One early
  mistake cannot be recovered."

There is no confidence band and no abstain path: every run returns a leaf.

## Numbers reported (verbatim, with what they compare against and the run date if given)

"Beam search matched 4 of 4 expected leaves; greedy search matched 2 of 4. Keeping three
paths recovered the expected classification for CPC patents, Shopify products."

| Hierarchy | Expected leaf | Greedy leaf | Beam K=3 leaf | Greedy correct | Beam correct |
| --- | --- | --- | --- | --- | --- |
| CPC patents | A01K31/12 Perches for poultry or birds, e.g. roosts | E99Z99/00 Subject matter not otherwise provided for in this section | A01K31/12 Perches for poultry or birds, e.g. roosts | no | yes |
| Shopify products | Cat Window Beds & Perches | Pet Chairs | Cat Window Beds & Perches | no | yes |
| MeSH biomedical subjects | C06.405.469.432.500 Crohn Disease | C06.405.469.432.500 Crohn Disease | C06.405.469.432.500 Crohn Disease | yes | yes |
| CookSafe files | retrievers.py | retrievers.py | retrievers.py | yes | yes |

Configuration constants: beam width `K=3`, `MAX_DEPTH = 12`, `EPSILON = 1e-9`,
`EDGE_TOP_K = 5` (diagram rendering only). Per-run mean probabilities and `top/second`
separation ratios are computed into the table code and the SVGs but no numeric value
appears in the page text; the renderer prints `">999×"` when `separation_ratio > 999`.

Cost: not reported. Latency: not reported. Token counts: not reported. Repeats
(`NUM_SAMPLES`): not reported. Standard deviations: not reported. No comparison against
any named LLM is made — the only comparison is greedy versus beam on the same model.

## Caveats the cookbook itself states

- One document per hierarchy, four in total — every accuracy claim rests on 4 of 4 versus
  2 of 4 single examples.
- The code hierarchy is a frozen listing, deliberately: a live walk "makes the taxonomy --
  and every number derived from it -- depend on the reader's checkout, including untracked
  scratch files". "Line order is significant: sibling options are asked in the order they
  appear here, so it is part of the question, not presentation." Ordering effects are
  acknowledged as part of the input.
- MeSH is a DAG flattened into tree-number paths for this tree-oriented search.
- Numerical warning for deep trees: "use `exp(mean(log(probs)))` instead of
  `product(edge_probabilities) ** (1 / decisions)` to avoid precision errors for
  hierarchies that are very deep (eg >10 layers)".
- The geometric mean is one metric among several; an alternative,
  `min(top_prob/second_top_prob)`, "would optimize for paths that have very clear
  decisions at every node".

## Lessons transferable to other use cases

- Beam search over `Choice` probability distributions: the full distribution, not just the
  argmax, is the payload that makes multi-path search possible.
- Length-normalised path scoring lets leaves at different depths be compared; the code,
  not the model, does the arithmetic.
- Fan-out over the beam is nearly free in wall-clock terms because each path is an
  independent parallel question — "extra exploration adds little wall-clock latency".
- Decomposing a taxonomy into per-node questions buys observability (which node the
  misclassifications sit in, how often each edge is traversed) and testability (unit test
  a hierarchy edit).
- What generalises: any DAG or tree label space too large for one flat question. What does
  not: the 4-of-4 result is four examples, not an accuracy estimate; and a DAG must be
  flattened before this search shape applies.

## Use-case entries this supports

- `uc-search-retrieval-hierarchical-taxonomy-beam-search` — classify into a deep taxonomy with a Choice per node and beam search over the probabilities
- `uc-commerce-listing-category-normalisation` — place a product listing in a deep retail taxonomy
- `uc-sdlc-semantic-code-search-ranking` — find the source file a developer's description points at
- `uc-legal-compliance-policy-violation-detection` — walk a policy tree to the specific clause

**Anti-use-case implied:** `au-flat-choice-over-255-options` — this shape needs a fixed,
enumerable hierarchy whose sibling sets can each be posed as a `Choice`; it does not apply
to open-ended label generation, and greedy single-path descent should not be used where an
early ambiguous node is likely.
