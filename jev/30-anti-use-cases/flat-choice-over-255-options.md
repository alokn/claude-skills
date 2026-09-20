---
id: au-flat-choice-over-255-options
title: Do not flatten a taxonomy of more than 255 leaves into one Choice
verdict: no
domain: search
decision_shapes: [classification, routing]
primitives: [choice, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/primitives/choice.md  ("A Choice question accepts up to 255 options")
  - https://typesafe.ai/blog/introducing-system-one-models-and-jev  ("Jev supports a cardinality up to 255. For the higher cardinality choices, we do a 2 stage-system ... hence the occasional slowdown")
  - https://docs.typesafe.ai/cookbooks/hierarchical_classification.md  (beam search over Choice probabilities)
  - https://docs.typesafe.ai/cookbooks/skill_suggestion.md  (rank many, re-judge the top few)
related: [au-replace-vector-retrieval-with-jev-rerank, au-average-noul-with-choice, df-rewrites]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to classify into our 4,000-SKU product taxonomy with one jev Choice?" Also "we have
900 support categories, can they all be options", "route to one of 1,200 internal teams in a single
call".

## Verdict

**No** — it is a hard API limit before it is an accuracy question. "A Choice question accepts up to 255
options" (https://docs.typesafe.ai/primitives/choice.md), and the launch post confirms the same ceiling
from the model side: "Jev supports a cardinality up to 255. For the higher cardinality choices, we do a
2 stage-system of scoring independently then making an explicit choice, hence the occasional slowdown."
Note the second half: even inside the supported range, large option sets cost latency.

Not a model failure: **deployment** veto — a hard API limit of 255 options, before accuracy is
discussed.

## What jev would get wrong

A request with more than 255 options is rejected, so the failure is at the API boundary. The workarounds
are where the real damage happens. Truncating to the 255 "most common" leaves means every input belonging
to the tail is silently mapped into the head, because a Choice is relative and always selects something.
Splitting the taxonomy into several independent 255-option Choices and taking the highest probability
across them compares numbers from different distributions — a confidence from one question is not
comparable with a confidence from another, which is the structural-invariants warning on the jaggedness
page in a different costume. And a flat 255-option list with no criteria gives the model nothing to
discriminate on between near-synonymous leaves.

## What stays in code

The taxonomy structure. Code owns the tree, the parent-child edges, the beam width, and the assembly of a
final leaf from a path of decisions. Code also owns the shortlist step when the design is retrieve-then-rank.

Two documented shapes replace the flat Choice. **Hierarchical:** one Choice per level with a manageable
option count at each, and a beam search over the returned probabilities so a wrong turn at level one is
recoverable — the hierarchical classification cookbook is the worked version. **Retrieve then rank:** an
embedding or keyword search shortlists 20-40 leaves, jev Scores each independently in one fan-out call,
and a second call re-judges the top few with full descriptions — the skill-suggestion cookbook does this
over 182 skills and adds a Noul to decide whether to suggest anything at all.

## Numbers

Hard limit: 255 options per Choice (https://docs.typesafe.ai/primitives/choice.md). Adding options "costs
a few tokens each", so a 200-option Choice with short descriptions is on the order of 2,000-4,000 input
tokens, about $0.00008-$0.00017 at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md). A three-level hierarchy with a beam of 3 is three calls per item
rather than one — still cheap, but count them. The launch post warns of an "occasional slowdown" at high
cardinality, so measure p95 latency rather than assuming about 100 ms.

- Field evidence (independent-benchmark): 4esv/jev-eval on Banking77 (77 classes, 300 rows) — jev 0.78 accuracy, 0.20 s, $0.04/1k against GPT-5.6 Terra 0.85, 1.04 s, $2.02/1k: a 6.7-point loss on high-cardinality routing, 2026-09-19. Source: https://github.com/4esv/jev-eval

- Field evidence (independent-benchmark): AbdelStark/jev-benchmarks on 300 held-out rows — DAIR Emotion 0.480 with Brier 0.846, against fastino/gliner2.5-multi-v1 at 0.440 with Brier 0.668: jev wins on accuracy and loses on calibration for fine-grained emotion, 2026-09-19. Source: https://github.com/AbdelStark/jev-benchmarks

## When the verdict flips

It flips to **good** once the answer space at any single question is at or under 255 and each option
carries a contrastive description. Concretely: level-one Choice over 12 departments, level-two Choice over
that department's 40 categories, level-three over its leaves, with beam search across the probabilities;
or a retrieval shortlist followed by per-candidate Scores. Add an explicit `other` or `none of the above`
option at every level so tail inputs surface instead of being absorbed. **No rewrite exists** for a single
flat Choice over 4,000 leaves; the constraint is in the API.

## Alternatives considered

- **Regex / deterministic**: keyword-to-leaf rules for the unambiguous leaves; short-circuit those.
- **Small LLM**: can emit any label string, which reintroduces validation and hallucinated leaves.
- **Frontier LLM**: better on deep taxonomies, at seconds and cents per item.
- **Fine-tuned classifier**: the classical answer for a fixed 4,000-class taxonomy with labelled data, and
  often the strongest; it needs retraining when the taxonomy changes, which a Choice does not.
- **Embeddings**: the right shortlisting step ahead of jev.
- **Human**: curates the taxonomy and reviews the `other` bucket.

## Sources

- https://docs.typesafe.ai/primitives/choice.md — accessed 2026-09-19
- https://typesafe.ai/blog/introducing-system-one-models-and-jev — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/hierarchical_classification.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/skill_suggestion.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
