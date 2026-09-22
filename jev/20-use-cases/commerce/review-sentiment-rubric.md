---
id: uc-commerce-review-sentiment-rubric
title: Score product reviews on a rubric you define rather than a sentiment label
verdict: good
domain: commerce
decision_shapes: [scoring, detection, feature-extraction]
primitives: [score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (demand forecasting: "Enrich forecasting models with semantic signals from ... product reviews"; scoring: "severity, relevance, quality, frustration, suitability")
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (independent dimensions scored separately, weights in code)
  - https://docs.typesafe.ai/patterns/fan-out.md  (many questions over one state in a single call)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 2: score levels are weak in numerical calibration — threshold or rank, do not interpolate)
related: [uc-trust-safety-review-abuse-signals, uc-support-frustration-scoring, uc-commerce-return-reason-classification]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to analyse product reviews?" Also "can jev give us sentiment
per feature instead of one star rating?", "can we find out what people actually complain
about?", and "can jev replace our sentiment API on reviews?".

## Verdict

**Good.** The star rating already tells you the sentiment; what it does not tell you is
*what about the product* the reviewer is reacting to, and that is the question a fixed
positive/neutral/negative taxonomy can never answer. Jev lets the rubric be yours — sizing,
durability, instructions, delivery, value — each scored independently and combined in code,
which is the composite-scoring pattern applied to a text you get thousands of. It is `good`
rather than `strong` because no cookbook runs review analysis end to end, and because reviews
are short, multilingual and often uninformative, so the honest expectation is a useful signal
on the subset that says something, not a verdict on every review.

## What jev decides

State: the review text, the star rating, and one line of product context so "runs small" is
interpretable. One call per review.

```
aspect_fit_sizing: Score
  instructions: "What does `review.text` say about how the item fits or sizes?"
  criteria: ["Says nothing about fit or sizing",
             "Fit is as expected or described as accurate",
             "Fit is slightly off — mentions running small or large",
             "Fit is wrong enough that the item is unusable or was returned"]

aspect_durability: Score
  criteria: ["Says nothing about durability",
             "Holding up well, no problems",
             "Early wear, minor damage, or a part failing",
             "Broke or failed in normal use"]

aspect_instructions_or_setup: Score
  criteria: ["Not mentioned", "Setup was straightforward",
             "Setup was confusing or the instructions were poor",
             "Could not complete setup"]

value_for_money: Score
  criteria: ["Not mentioned", "Considered good value", "Considered overpriced"]

mentions_safety_incident: Noul
  instructions: "Does `review.text` describe the product causing injury, fire, or a safety hazard?"

wrong_item_received: Noul
  instructions: "Does `review.text` say the item received was not the item ordered?"

blames_delivery_not_product: Noul
  instructions: "Is the reviewer's dissatisfaction entirely about shipping or packaging?"
```

Each aspect carries a "not mentioned" level, which is what makes the scores aggregatable:
without it, silence becomes a middling score and washes out the signal. `mentions_safety_
incident` is a Noul, not a level, because it routes to a different place entirely — a
product-safety queue, immediately, regardless of the star rating.

## What stays in code

Aggregation and every number. Share of reviews mentioning sizing, trend over time, comparison
against the category, and the decision to flag a SKU are all arithmetic; failure mode 2 also
forbids treating a Score expectation as a magnitude, so aggregate the *share above a
threshold*, not the mean score. Which aspects exist per category is a configuration, and the
safety escalation is a deterministic rule on the Noul.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 500-character review plus
seven questions with levels (~1,800 characters) is ≈ 575 tokens, **≈ $0.000024 per review**.
Seven questions in one call rather than seven calls is the published saving: 13 questions
batched measured 12.2x cheaper and 10.0x faster than sequential, with identical means on 11
of 13 questions and the other two agreeing within 0.01. Latency 70–500 ms. Stability matters
when you are trending a metric across months: the noul-consistency cookbook measured jev's
mean per-question probability standard deviation at 0.0102 over 15 repeats, the choice one at
0.0098, both sampled 2026-09-11. No accuracy figure exists for aspect scoring; validate
against a few hundred hand-coded reviews before anyone presents a chart from it.

## When the verdict flips

- You report "average durability score 2.4". The score is not a magnitude; report the share
  of reviews above a level instead.
- Reviews are predominantly non-English, as they are on most marketplaces. Validate per
  locale; this is the fit test's non-English counter-signal.
- You need the aspects discovered rather than defined. Topic discovery is not a bounded
  decision — cluster with embeddings or ask an LLM to propose the rubric, then score with jev.
- The rubric changes per category and nobody owns it. Thirty rubrics nobody maintains is
  worse than one star rating.

## Alternatives considered

- **Star ratings alone.** Free, already there, and the baseline any of this must beat.
- **Sentiment API / lexicon.** Fixed taxonomy, no aspects, no criteria you can edit — the
  case the primer describes as replaceable by a rubric of your own.
- **Aspect-based sentiment models (ABSA).** Purpose-built and good, with a fixed aspect
  inventory and a retrain to change it.
- **Topic modelling / embeddings clustering.** The right tool for *discovering* what people
  talk about; useless for scoring a defined aspect consistently.
- **Frontier LLM per review.** Best nuance, and at review volume the cost is the whole
  objection; use it to design the rubric, not to run it.
- **Human coding.** The validation set, not the pipeline.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `patterns/composite-scoring.md`,
`patterns/fan-out.md`, `model-jaggedness/jev-1.13.md` (score-magnitude warning),
`cookbooks/parallel_questions.md` (12.2x / 10.0x), `cookbooks/consistency_noul_cookbook.md`
and `cookbooks/consistency_choice_cookbook.md` (std dev, sampled 2026-09-11), `models.md`.
