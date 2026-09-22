---
id: uc-trust-safety-review-abuse-signals
title: Score fake-review and review-abuse signals on a marketplace
verdict: good
domain: trust-safety
decision_shapes: [detection, feature-extraction]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (e-commerce marketplaces: "Detect prohibited listings, counterfeit signals, review abuse, and policy violations")
  - https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md  (jev probabilities as features for a classical model with ground-truth outcomes)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 2: counting is unreliable; ask one question per item and sum in code)
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (independent dimensions, weights in code)
related: [uc-commerce-review-sentiment-rubric, uc-trust-safety-spam-phishing-atomic-signals, uc-trust-safety-user-report-triage]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to detect fake reviews?" Also "can jev spot incentivised
reviews?", "can we flag review brigading?", and "can jev tell if this review is about the
product at all?".

## Verdict

**Good** for the textual signals, as inputs to a model or rule that also sees behaviour.
Review abuse is detected primarily by *patterns across accounts* — bursts, shared devices,
reviewer graphs, purchase verification — and none of that is in the text. What is in the text
is a set of tells that behavioural systems cannot see: a review that describes a different
product, one that mentions receiving the item free in exchange for a rating, one that reads
as a competitor attack, one whose detail is generic enough to have been written without ever
owning the thing. Those are single-hop judgements over short text and jev handles them at
a price that lets you score every review. Treat the output as features, not as a verdict.

## What jev decides

State: the review text, the product title and a one-line product description, and nothing
else. Do not send the reviewer's history — counting reviews is failure mode 2 and belongs in
code.

```
mentions_incentive: Noul
  instructions: "Does `review.text` say the reviewer received the product free, at a discount,
                 or was compensated in exchange for the review?"

product_mismatch: Noul
  instructions: "Does `review.text` describe a product that does not match `product.title` and
                 `product.description`?"
  criteria:
    true:  {what: "Describes features, a category, or a use the product does not have"}
    false: {what: "Consistent with the product",
            not_for: "A complaint about delivery, packaging, or the seller"}

no_evidence_of_use: Score
  instructions: "How much first-hand detail of actually using the product does `review.text` give?"
  criteria: ["Specific, situated detail only an owner would write",
             "Some concrete detail, could be from the listing",
             "Generic praise or complaint with no product-specific detail",
             "Content unrelated to using the product"]

competitor_promotion: Noul
  instructions: "Does `review.text` direct the reader to a different seller, product, or site?"

template_language: Noul
  instructions: "Does `review.text` read as a template, with the product name inserted into
                 otherwise generic sentences?"

review_is_about_delivery_not_product: Noul
  instructions: "Is `review.text` entirely about shipping, packaging, or customer service?"
```

That last one is not abuse — it is the most common reason a rating is unfair, and it is
worth the question because the remedy differs. Composition in code, per the composite-scoring
pattern, with weights you can change without re-running inference.

## What stays in code

Everything relational and numeric. Verified-purchase status, review velocity, reviewer age,
IP and device overlap, rating distribution skew, and the graph of who reviews what together
are all stronger evidence than prose, and all deterministic. So is the action: demoting,
removing, or holding a review is policy. The reviewer-level aggregate ("nine of this
account's twelve reviews mention an incentive") is a sum in code over per-review Nouls, which
is the published rewrite for counting.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 600-character review plus the
product line plus these six questions (~1,300 characters) is ≈ 500 tokens, **≈ $0.000021 per
review** — the number that makes scoring the whole archive feasible, which is what you need
to build a training set. One call covers all six questions at low incremental latency (the docs say latency "barely
changes" as questions are added). Latency
70–500 ms, so it also fits at submission time. No accuracy figure is published for review
abuse; the measurement that counts is the lift these features add to your existing abuse
model on held-out, adjudicated cases, which is the experiment the autoresearch cookbook
describes.

## When the verdict flips

- You treat a high composite as proof and remove reviews automatically. Sellers and
  reviewers both have appeal rights and a wrong removal is visible; keep a human band.
- Your abuse is purely behavioural — bought accounts posting plausible text. Then the text
  signals are near-useless and the money goes into the graph, not the model.
- Reviews are short and multilingual, as most marketplace reviews are. "Great!" carries no
  signal in any language, and non-English needs its own evaluation.
- You ask jev "is this review fake?". One broad question hiding six judgements; the docs'
  standing anti-pattern.

## Alternatives considered

- **Behavioural / graph detection.** The backbone. Add jev, do not replace it.
- **Duplicate-text and near-duplicate hashing.** Exact, cheap, and catches the laziest
  campaigns. Keep it; it is lexical work and code wins.
- **Frontier LLM per review.** Affordable only on a sample, which defeats the purpose of a
  signal meant to run on everything.
- **Small LLM.** Roughly an order of magnitude more cost and latency per multi-question call
  on the consistency cookbooks' measurements, for the same shape of answer.
- **Fine-tuned classifier on adjudicated reviews.** The right end state once you have a few
  thousand adjudications — and jev's probabilities are good features for it.
- **Buyer reporting.** Slow and biased towards negative reviews of one's own product.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `cookbooks/autoresearch_feature_discovery.md`,
`patterns/composite-scoring.md`, `model-jaggedness/jev-1.13.md` (counting rewrite), `models.md`.
