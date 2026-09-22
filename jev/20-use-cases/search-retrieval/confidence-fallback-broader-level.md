---
id: uc-search-retrieval-confidence-fallback-broader-level
title: Answer at a broader taxonomy level when the narrow classification is not confident
verdict: strong
domain: search-retrieval
decision_shapes: [classification, routing]
primitives: [choice]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/classification_using_confidence.md  (75 SIC groups, 60 filings, 0.9 cutoff, 90% / 40% / 70%)
  - https://docs.typesafe.ai/confidence.md  (three bands; thresholds scale with stakes)
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (per-action thresholds)
related: [uc-search-retrieval-hierarchical-taxonomy-beam-search, uc-search-retrieval-query-intent-classification, uc-agents-harness-model-difficulty-routing]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to classify when we cannot afford a wrong specific label?"
Also: "what do we do with the uncertain half instead of dropping it?", "can we degrade to a
coarser category rather than escalate to a human?", "should we threshold on the winning
option's probability or on confidence?"

## Verdict

**Strong**, wherever the label space has a genuine parent level. Instead of abstaining, the
low-confidence branch answers one level up — still useful, still actionable, and free, because
the parent follows from the child by lookup. "Every filing still comes back with a usable
label. One the model could not classify confidently comes back one level up instead of being
dropped or sent on." The condition: if a division-level answer is too coarse for your product
to act on, that branch is where a person takes over, not where the design ends.

## What jev decides

State is the document text. One Choice over the narrow labels, with each option described from
the taxonomy source rather than by hand:

```python
Choice(instructions=("Which broad industry does this company operate in? Judge the company's "
                     "own operations as this filing describes them."),
       criteria={group: describe(group) for group in sorted(GROUPS)})   # 75 options
```

`describe(group)` emits `f"{umbrella} — includes: {listed}"` with up to 8 named industries,
because "a group's own name is not always there".

Read `confidence`, not the winner's probability. The cookbook's reason is the whole point of
the primitive: "A winner at 0.45 with a runner-up at 0.44, and a winner at 0.45 with the rest
of the weight scattered thinly, are different situations, and `confidence` is what separates
them."

One cutoff, two bands:

```python
CONFIDENT = 0.9
level = "group" if answer["confidence"] >= CONFIDENT else "division"
label = answer["group"] if sure else division(answer["group"])
```

## What stays in code

The cutoff, the child-to-parent lookup (an integer range table here — no second call), the
choice of which band a product will act on, and the handoff to a human when even the parent is
too coarse. Tune the cutoff on your own labelled history; 0.9 is this dataset's number.

## Numbers

From `classification_using_confidence.md`, `jev-1.12`, 2026-08-12: 444 SEC industries rolled
into 75 major groups and 10 divisions; 60 10-K Item 1 sections, 1,438 words on average, one
request each. "a confidence cutoff of 0.9 splits them in half":

| Band | n | Group named every time |
|---|---|---|
| confident (conf >= 0.9) | 30 | 27/30 right |
| unsure (conf < 0.9) | 30 | 12/30 right |
| all | 60 | 39/60 right; 48/60 useful answers with the fallback |

Verbatim: "The confident half is right 90% of the time; the other half, 40%. Reported one level
up, that 40% becomes 70%." Also: "a Choice works reliably up to roughly 240 options, and 75 is
well inside that." Cost, latency and token counts: **not reported**.

Sample size and label provenance, which is what the `strong` rests on: **n = 60 filings**, one
request each. The labels are the SIC codes the filers themselves assigned in EDGAR — pre-existing
human-authored metadata, neither synthetic nor adjudicated for this experiment — and the cookbook
pre-filters the sample: "These 60 were filtered down to filings whose own text supports the code
they carry, so the numbers here measure the recipe rather than the state of EDGAR's metadata."
Read 90/40/70 as the shape of the split on a cleaned 60-row sample, not as an accuracy you will
reproduce.

Closest jaggedness mode: **8, structural invariants** — do not carry a Noul threshold onto a
Choice, and do not read the winner's probability as confidence.

## When the verdict flips

- **The label space is flat.** No parent level means no free fallback; you are back to abstain
  or escalate, and this entry buys nothing (**weak**).
- **The coarse answer cannot be acted on.** If "manufacturing" triggers no different behaviour
  from "chemicals", the fallback is cosmetic. Route to a human instead.
- **Stakes are high enough that 90%-band accuracy is not enough.** The band is a triage tool,
  not a guarantee; the confidence-routing pattern sets per-action thresholds (0.6 to check a
  balance, >0.85 to approve a transfer) for this reason.
- **Your gold labels are self-reported.** The cookbook's caveat applies to most operational
  taxonomies: the label "goes stale when a company sells the business the code names and keeps
  the code." Measure agreement, not accuracy, until you have clean labels.

## Alternatives considered

- **Hard abstain at low confidence** — simplest, and correct when the coarse label is useless;
  costs you a usable answer on half the volume here.
- **Escalate to a frontier LLM on low confidence** — the cascade shape; better answers, real
  cost, and only worth it if the narrow label is what you need.
- **Softmax threshold on a fine-tuned classifier** — strong with labelled data, and calibration
  is the known weak point; jev returns probabilities trained to be calibrated (measure it on your
  data — independent ECE ranges from 0.045 to 0.242 by dataset) plus a confidence that collapses
  the whole distribution, which is what the fallback rule reads.
- **Keyword rules mapped to the taxonomy** — maintainable for a handful of categories,
  hopeless at 75 with overlapping vocabulary.
- **Human coders on everything** — the baseline this replaces; with the fallback, only the
  cases where even the parent is too coarse reach them.

## Sources

- https://docs.typesafe.ai/cookbooks/classification_using_confidence.md — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
- https://docs.typesafe.ai/patterns/confidence-routing.md — accessed 2026-09-19
