---
id: uc-sales-marketing-icp-fit-scoring
title: Score a company against your ideal customer profile from text sources
verdict: good
domain: sales-marketing
decision_shapes: [scoring, classification, feature-extraction]
primitives: [score, noul, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (lead generation: "Match company profiles, executive biographies, and inbound messages to an ideal customer profile"; "Score industry fit and company maturity")
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (score each dimension independently, combine with weights in code, adjust weights without losing nuance)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 2: headcount and revenue bands are arithmetic; failure mode 5: filter the state)
  - https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md  (probabilities as features for a classical model trained on ground-truth outcomes)
related: [uc-sales-marketing-buyer-intent-detection, uc-sales-marketing-lead-routing, uc-hr-recruiting-resume-composite-scoring]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to score ICP fit?" Also "can jev read a company's website and
tell us if they are a fit?", "can we replace the firmographic scoring rules?", and "can jev
prioritise our outbound list?".

## Verdict

**Good**, for the part of ICP fit that lives in prose — the shape is demonstrated by the
use-case map and the composite-scoring pattern page; no task-matched labelled accuracy
is published; shadow-evaluate against the incumbent before acting. The use-case map
names this explicitly under lead generation, and the composite-scoring pattern gives the
shape: several independent dimensions, each a Score with concrete levels, combined with
weights your revenue team owns in code. The reason it beats the firmographic rules it
supplements is that the discriminating facts are usually textual — whether a company
sells to enterprises or to consumers, whether it has an in-house engineering team,
whether it operates in a regulated market — and none of those is a field in a data
provider's record. Keep every firmographic number in code and this passes all seven
fit-test questions.

## What jev decides

State: a compact bundle assembled in code — the company's homepage and product page text
trimmed to a few thousand characters, the "about" section, and recent job-posting titles.
Not the whole site: irrelevant marketing copy is the purest form of failure mode 5.

```
sells_to_enterprise: Score
  instructions: "How much evidence is there that this company sells to large organisations
                 rather than consumers or very small businesses?"
  criteria: ["Clearly consumer or prosumer",
             "Small-business focus, self-serve pricing only",
             "Mixed, with some business customers named",
             "Names enterprise customers, has sales-led pricing or a security page"]

has_inhouse_engineering: Score
  criteria: ["No evidence of technical staff",
             "A small technical team or outsourced development",
             "An engineering function with several open roles",
             "A substantial engineering organisation with specialised roles"]

operates_in_regulated_market: Noul
  instructions: "Does the company describe operating under financial, healthcare, or other
                 sector regulation?"

problem_we_solve_is_evident: Score
  instructions: "How much evidence is there that this company has the problem described in
                 `our_product.problem_statement`?"
  criteria: ["No indication", "Plausible for a company of this type",
             "Describes a related workflow or pain", "States the problem or a workaround for it"]

industry: Choice
  criteria: { <your segment list>, other: "None of the above" }
```

Composition in code, as the pattern publishes it — each Score normalised to 0–1, weighted,
and summed — with a separate weight vector per product so the same inference ranks two
pipelines. Bands: above the threshold, route to outbound; in the middle, enrich further or
hold for a human; below, suppress from the list rather than deleting the record.

## What stays in code

Every firmographic number and every hard qualifier. Headcount, funding, revenue band, country,
existing-customer status, do-not-contact and open-opportunity checks are lookups and
arithmetic — failure mode 2 is explicit that numeric closeness is unreliable, so bucket in
code and pass the bucket as a named fact if a question needs it. Which page text to fetch,
the crawl, the cache, and the suppression list are code. So is the decision to contact.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 4,000-character trimmed site
bundle plus five questions with levels (~2,000 characters) is ≈ 1,500 tokens, **≈ $0.000063
per company**. Scoring a 50,000-company list is therefore about **$3.15** of inference — the
number that changes what is possible, because that list previously got a rules pass or a
sampled human review. Latency 70–500 ms; irrelevant for a batch, useful if you score on
form-fill. Costs scale with how much page text you send, so trimming is both the accuracy
lever and the cost lever. No accuracy figure is published for ICP scoring; the measurement
that matters is win rate and meeting rate by score decile against your own closed
opportunities, which is the autoresearch cookbook's pattern of validating probabilistic
features against ground-truth outcomes.

## When the verdict flips

- The ICP is defined entirely by firmographics you already buy. Then a SQL query is the whole
  answer and jev adds latency and cost for nothing (fit-test question 7).
- You score on the raw website with no trimming. Context rot, plus a bill dominated by
  boilerplate.
- You present the composite as a probability of closing. It is not calibrated to that outcome
  until you have regressed it against outcomes.
- You need the company's actual headcount or revenue. That is a data-provider lookup, not a
  judgement — and asking for a number is the documented weak spot.
- Non-English websites at scale, unvalidated.

## Alternatives considered

- **Firmographic rules on enriched data.** The backbone; keep it, and let jev score what the
  fields cannot express.
- **Data-provider intent and fit scores.** Opaque, built on someone else's definition of fit,
  and identical for you and your competitors.
- **Frontier LLM over each company site.** Best reasoning and a usable rationale, at seconds
  and cents per company — affordable for a 500-account named list, not for 50,000.
- **Small LLM.** Roughly an order of magnitude more cost and latency per multi-question call
  on the consistency cookbooks' figures. Run-to-run stability is not a safe differentiator: in the
  choices cookbook `claude-haiku-4-5` at temperature 0 was the more repeatable condition (100.0%
  against jev's 90.8% raw, SD 0.0012 against 0.0098), so measure it on your own rubric before
  relying on it for a weekly re-run.
- **Embeddings similarity to your best customers.** Cheap and genuinely useful as a shortlister;
  it cannot tell you *why*, so you cannot re-weight it when the ICP changes.
- **Trained propensity model on closed-won data.** The right end state; jev's per-dimension
  probabilities are good features for it, and you need history to build it.
- **SDR research by hand.** 10–20 minutes per account, and what the top band preserves.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `patterns/composite-scoring.md`,
`model-jaggedness/jev-1.13.md` (modes 2 and 5), `cookbooks/autoresearch_feature_discovery.md`,
`models.md`.
