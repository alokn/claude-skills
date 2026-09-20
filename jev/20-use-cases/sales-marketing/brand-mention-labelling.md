---
id: uc-sales-marketing-brand-mention-labelling
title: Label every inbound brand mention at ingest with four parallel questions and keep the probabilities
verdict: good
domain: sales-marketing
decision_shapes: [classification, detection, feature-extraction, scoring]
primitives: [noul, choice, score]
evidence_level: community-report
sources:
  - https://github.com/Nishfleet/0509/issues/3536  (brand-mention ingest labelling: is_about_brand, sentiment, category, self/competitor, stored with probabilities behind a flag; "mentions under 0.5 brand confidence flagged but retained")
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; parallel questions in one call)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 6 adversarial content; mode 5 context rot)
related: [uc-commerce-review-sentiment-rubric, uc-sales-marketing-buyer-intent-detection, uc-data-ml-map-reduce-corpus-labelling, uc-observability-evals-confidence-threshold-calibration-fitting, au-free-form-value-extraction]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to label brand mentions as they come in?" Also: "our social
listening tool returns everything that matches the word 'Apollo' and most of it is about
NASA — can jev filter it?", "can we tag sentiment and topic on every mention without paying
per-LLM-call?", "should we drop the mentions the model is unsure about?"

## Verdict

**Good.** A public deployment specifies this exact ingest step — `is_about_brand`,
`sentiment`, `category`, and self-versus-competitor, "all stored with probabilities behind a
flag", with "mentions under 0.5 brand confidence flagged but retained"
(github.com/Nishfleet/0509/issues/3536). Every property jev genuinely has is being used here:
four questions ride in one call for one latency, the answer is typed so the ingest schema
cannot be violated, and the probability is stored rather than thresholded away at write time.
It is `good` not `strong` because that deployment publishes a design, not an agreement rate,
and no independent source has measured brand-mention labelling.

## What jev decides

State is one mention: `text` (the post or article excerpt), `source_platform`,
`author_handle`, and `brand_name` plus a one-line `brand_description` you control. The brand
description is what makes the disambiguation possible — without it the model has no way to
know that Apollo is your API company and not the space programme.

```
is_about_brand: Noul
  instructions: "Does `text` refer to the company described in `brand_description`, rather
                 than another thing with the same or a similar name?"

sentiment: Choice
  criteria:
    positive: {what: "The author recommends, praises, or reports a good outcome."}
    neutral:  {what: "Mentioned in passing, factually, or as one option among several."}
    negative: {what: "The author complains, warns others off, or reports a bad outcome."}
    mixed:    {what: "Both a clear positive and a clear negative about the brand."}

category: Choice
  criteria: {pricing: ..., reliability: ..., support: ..., features: ...,
             comparison: ..., hiring: ..., news: ..., other: {what: "None of the above
             fits. Do not force a category."}}

subject: Choice
  criteria:
    us:         {what: "The mention is primarily about the brand in `brand_description`."}
    competitor: {what: "Primarily about a named competitor; our brand is only the comparison."}
    both:       {what: "A genuine head-to-head."}
```

The `other` and `mixed` options are not decoration. A Choice without an escape hatch is
relative and will always name something; the low-confidence answer is the useful one here.

Closest jaggedness mode: **6, adversarial content can move the answer** — mentions include
marketing copy and SEO spam written to be persuasive. The design avoids consequences by
making nothing downstream automatic.

## What stays in code

The fetch, deduplication across platforms, the keyword query that produced the candidate set,
author blocklists, language detection, follower counts and reach arithmetic, date windows,
and every aggregate on the dashboard. Crucially: **the raw mention is written first and never
overwritten.** Labels are a side table keyed by mention id, carrying the probability, the
model version, and the timestamp. That is what lets you re-label the corpus when you change a
criterion, and it is what makes "retained, not dropped" cheap to implement.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A 900-character
mention plus the brand description plus four questions with criteria (~2,400 characters) is
about 830 tokens, **≈ $0.000035 per mention**; multiply by your own mention volume, which this
entry does not supply. The four answers cost one call and one latency rather than four. The deployment
that specifies this publishes the retention rule verbatim — "mentions under 0.5 brand
confidence flagged but retained" — and stores every probability behind a feature flag
(github.com/Nishfleet/0509/issues/3536). No accuracy or agreement figure is published for
this task by that source or any other.

Labelled data is cheap here because the analyst who reads the dashboard is already correcting
labels. Capture the corrections; they are your calibration set.

## When the verdict flips

- **You drop low-confidence mentions instead of flagging them.** The whole design depends on
  retain-don't-drop. Deleting on a probability makes the corpus unrecoverable and the verdict
  **weak**.
- **Something acts on the label automatically** — a PR escalation, an outreach email, a
  paused ad campaign. Then a wrong-but-valid label has a consequence and you need a human
  band, or the verdict is **no** for that path.
- **Mentions are mostly non-English.** Unevaluated per language; see
  `au-non-english-at-scale-unevaluated`.
- **Your brand name is unambiguous.** If `is_about_brand` is true 99.8% of the time, the
  question is not earning its call — keep sentiment and category, drop the filter.
- **You need a summary of what people are saying.** That is generation;
  `au-generate-ticket-summaries` applies.

## Alternatives considered

- **Keyword and boolean queries.** The incumbent, and they stay as stage one because they are
  free and they define the candidate set. They cannot separate your brand from a homonym.
- **Off-the-shelf social-listening sentiment.** Bundled, opaque, and tuned to nothing in
  particular; you cannot edit the criterion when "negative" turns out to mean "sarcastic".
- **Frontier LLM.** Better when you want a written summary of the month; seconds and cents per
  mention, against a stream that is high volume and low value per item.
- **Fine-tuned classifier.** Strong on sentiment once you have labelled data; needs
  retraining every time marketing redefines a category, which is the thing that changes most.
- **Embeddings plus a threshold.** Fine for topic clustering, no way to express
  "about our Apollo, not theirs".
- **Human analysts.** Stay for the flagged band and for anything that reaches a customer.

## Sources

- https://github.com/Nishfleet/0509/issues/3536 — accessed 2026-09-19 (four labels at ingest,
  probabilities stored behind a flag, "mentions under 0.5 brand confidence flagged but
  retained")
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
