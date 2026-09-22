---
id: uc-commerce-return-reason-classification
title: Classify the real reason behind a free-text return request
verdict: good
domain: commerce
decision_shapes: [classification, detection, feature-extraction]
primitives: [choice, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (e-commerce marketplaces; customer support: classify by issue and intent; ML feature extraction: product interest, churn signals)
  - https://docs.typesafe.ai/cookbooks/classification_using_confidence.md  (confidence bands over a Choice; answering one level coarser when unsure turned 39/60 right into 48/60 useful answers)
  - https://docs.typesafe.ai/patterns/fan-out.md  (the whole decision tree's questions in one call)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 3: return windows are date arithmetic — keep them in code)
related: [uc-commerce-review-sentiment-rubric, uc-support-refund-request-detection, uc-commerce-attribute-extraction]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to classify return reasons?" Also "the dropdown says 'other' on
40% of returns — can jev read the comment box?", "can we tell a sizing return from a quality
return?", and "can jev route returns to the right disposition?".

## Verdict

**Good.** The structured reason a customer picks from a dropdown is famously unreliable —
shoppers choose whatever gets the label printed fastest — while the free-text comment next to
it usually says what actually happened. Reading that comment into your own reason taxonomy is
a short-text classification with a closed answer set, a confidence band, and an obvious human
fallback, so it passes the fit test cleanly. The value is not the label on one return; it is
that a whole quarter of returns becomes a signal about listings, sizing charts and quality,
at a price that lets you reclassify the entire back catalogue.

## What jev decides

State: the free-text comment, the selected dropdown reason, the product title and one line of
description. Not the order record.

```
actual_reason: Choice
  instructions: {question: "What does the customer's comment say was actually wrong?",
                 focus: "Judge the comment, not the reason they selected."}
  criteria:
    sizing_fit:        {what: "The item did not fit or sizes differently than expected",
                        not_for: "The wrong size was shipped"}
    not_as_described:  {what: "The item differs from the listing — colour, material, features"}
    quality_defect:    {what: "The item arrived damaged, faulty, or failed quickly"}
    wrong_item_sent:   {what: "A different item or variant than ordered was shipped"}
    late_delivery:     {what: "Arrived too late to be useful"}
    changed_mind:      {what: "No fault; the customer no longer wants it"}
    found_cheaper:     {what: "Price was the reason"}
    no_reason_given:   {what: "The comment states no reason"}
    other:             {what: "A reason none of the above describes"}

seller_at_fault: Noul
  instructions: "Does the comment describe something the seller or the listing got wrong,
                 as opposed to the customer's own preference changing?"

listing_inaccuracy_claimed: Noul
  instructions: "Does the comment claim the listing's description, photos, or measurements
                 were inaccurate?"

safety_or_hazard: Noul
  instructions: "Does the comment describe injury, a hazard, or a product-safety problem?"

dropdown_matches_comment: Noul
  instructions: "Does `selected_reason` describe the same problem as `comment`?"
```

`no_reason_given` and `other` are what keep the class distribution honest; without them a
Choice assigns a reason to "just returning this" and your sizing metric quietly inflates.
Bands: act on `confidence >= 0.7`; below that, either leave the return in `unclassified` or,
following the classification-with-confidence cookbook, report the coarser parent class
(`seller_fault` / `customer_preference` / `unknown`), which is usually still enough to drive
the disposition decision.

## What stays in code

Refund, restocking, and disposition. The return window, the refund amount, restocking fees
and shipping costs are dates and arithmetic — failure modes 3 and 2. So is everything
aggregate: the return rate by SKU, the share attributable to sizing, and the threshold at
which a listing is pulled for review. The safety Noul feeds a deterministic escalation, not a
dashboard.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 300-character comment plus the
product line plus these five questions with criteria (~2,200 characters) is ≈ 700 tokens,
**≈ $0.000029 per return**, which is what makes a backfill over historical returns a
sub-dollar job for tens of thousands of rows. All five questions ride in one call at no
latency cost, per the fan-out pattern. Latency 70–500 ms. Published accuracy for return
reasons: none. The nearest calibration evidence is the classification-with-confidence
cookbook's split on a 75-option Choice — 27/30 right where confidence was at least 0.9, 12/30
below it (`jev-1.12`, 2026-08-12) — which is the shape of the argument for a band, not a
number to expect on your taxonomy.

## When the verdict flips

- The comment box is empty, which it often is. Then there is nothing to read and the dropdown
  is all you have; do not call.
- The classification drives an automatic seller chargeback. That is money on a probability;
  keep a deterministic rule and a dispute path.
- Comments are multilingual and short, the usual case on a cross-border marketplace. Validate
  per locale.
- You add a twelfth overlapping reason. A Choice picks one; overlapping classes produce
  unstable labels, and the fix is fewer, contrastive classes with `not_for` on each.

## Alternatives considered

- **The dropdown alone.** Free and structurally biased; this exists because it is wrong.
- **Keyword rules on the comment.** "Too small" is easy; "the chart said 10 but this is an 8"
  is not, and that is the comment that tells you to fix the sizing chart.
- **Frontier LLM.** Fine on quality, and you are classifying every return forever — the
  economics decide it.
- **Small LLM.** Roughly an order of magnitude more cost and latency per call on the
  consistency cookbooks' figures, with free-text labels to reconcile against your taxonomy.
- **Fine-tuned classifier on manually coded returns.** Best precision once you have the coded
  set; jev is how you produce that set cheaply in the first place.
- **Manual coding by the returns team.** Accurate on a sample, and a sample is not a metric
  you can break down by SKU.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`,
`cookbooks/classification_using_confidence.md` (27/30 and 12/30 bands; coarser-answer policy;
`jev-1.12`, 2026-08-12), `patterns/fan-out.md`, `model-jaggedness/jev-1.13.md`, `models.md`.
