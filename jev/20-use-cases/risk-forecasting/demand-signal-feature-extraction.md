---
id: uc-risk-forecasting-demand-signal-feature-extraction
title: Extract purchase intent and supply-concern features from text for a forecasting model
verdict: good
domain: risk-forecasting
decision_shapes: [feature-extraction, detection, scoring]
primitives: [noul, score]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md  (jev probabilities as features for a CatBoost model evaluated against held-out ground truth; proposing and testing feature definitions)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (demand forecasting: "Extract purchase intent, urgency, and product interest"; "Detect supply concerns, competitive pressure, and emerging demand themes"; "Feed those features into a forecasting model alongside historical time-series data"; ML Feature Extraction as a task category)
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  ("For learned composition, use the probabilities as features in a downstream classical machine-learning model")
  - https://docs.typesafe.ai/patterns/fan-out.md  (many questions per record in one call)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; rate limits 250k tokens/s, 1,200 requests/min)
related: [uc-risk-forecasting-incident-report-risk-indicators, uc-risk-forecasting-vendor-assessment-scoring, cb-autoresearch_feature_discovery, df-cost-model, df-fit-test]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to extract demand signals for our forecast?" Also asked as
"can jev turn sales notes and support tickets into features for our demand model?", "can jev
detect supply concerns in customer emails before they show up in orders?", and "can jev
forecast next quarter's demand?".

## Verdict

**Good**, with the last phrasing answered plainly: no, jev does not forecast — the shape
is demonstrated by the `autoresearch_feature_discovery` cookbook, whose held-out RMSE
was measured on wine reviews and not on demand signals; no task-matched labelled
accuracy is published; shadow-evaluate against the incumbent before acting. It reads
text and returns probabilities trained to be calibrated — measure the calibration on your
own data; the forecast is produced by your time-series
or gradient-boosted model, which now has semantic columns it did not have before. That
split is TypeSafe's own recommendation — "For learned composition, use the probabilities
as features in a downstream classical machine-learning model" — and the autoresearch
cookbook shows the full loop, training a CatBoost model on jev outputs and evaluating
feature definitions against held-out ground truth. This is also the cheapest thing jev
does: one call per record, many questions per call, over a corpus you already store.

## What jev decides

State: one record at a time, trimmed to the text and the two or three structured fields the
questions reference — the inquiry body, the account segment, the product line. Not the CRM
history; map-reduce over many small states is the pattern, not one large one.

```
purchase_intent: Score
  instructions: {question: "How close to a purchase decision is the writer of `record.text`?",
                 focus: "Judge the stated stage, not enthusiasm."}
  criteria: ["Gathering information with no stated need",
             "Has a defined need, no timeline stated",
             "Evaluating options, timeline stated",
             "Ready to buy: asking about pricing, contracting, or availability"]

urgency: Score
  criteria: ["No time pressure expressed",
             "Prefers sooner, no consequence stated",
             "A deadline is named",
             "A consequence of delay is named (line stoppage, contractual date, event)"]

quantity_signal_present: Noul("Does `record.text` state or imply a volume, unit count, or
                               order size?")
supply_concern:          Noul("Does `record.text` express concern about availability, lead
                               time, or a shortage?")
competitor_named:        Noul("Does `record.text` name a competing supplier or product?")
switching_language:      Noul("Does `record.text` describe moving business away from, or
                               toward, a supplier?")
price_sensitivity:       Noul("Does `record.text` object to price or ask for a discount?")
new_use_case:            Noul("Does `record.text` describe an application of the product the
                               writer has not used it for before?")
```

Eight features per record in one call. The fan-out pattern is what makes this economic:
questions are evaluated in parallel and "adding more questions to a call typically doesn't
add any latency".

There is no confidence gate here, because nothing acts on a single record. The probability
*is* the feature — do not threshold it to a boolean before handing it to the model, because
thresholding throws away exactly the calibration that makes it useful. Keep `score`,
`confidence` and each `noul` as separate columns and let the downstream model decide what to
do with them.

## What stays in code

Everything numeric and temporal: order quantities, lead times in days, seasonality, the lag
structure, the aggregation from record-level features to a weekly or SKU-level panel. Jev
never sees a date comparison (failure mode 3) or a sum (failure mode 2). Deduplication of
records. The train/test split, the backtest, and the decision about whether a feature earns
its place — the autoresearch cookbook's discipline is that a proposed feature is kept or
dropped on its measured predictive value against held-out ground truth, not on whether it
sounds plausible. The forecast itself.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A
1,200-character record plus two Scores and six Nouls (~2,200 characters of questions) is
about (1,200 + 2,200) / 4 = 850 tokens, so **≈ $0.000036 per record**. At that rate a
100,000-record backfill is about **$3.60** — and note that the backfill is the point, because
you need the features on historical records to train against known outcomes. Throughput is
bounded by the published rate limits, 250,000 tokens per second and 1,200 requests per minute
(dynamic, higher on enterprise), so a large backfill needs a throttle and the SDK's
retry-with-backoff; see `df-cost-model`.

Predictive lift: not published, and not predictable in advance. The autoresearch cookbook's
contribution is the *method* for finding out — propose feature definitions, compute them,
measure them against held-out ground truth, keep the ones that pay. Do not quote a lift
number you have not measured.

## When the verdict flips

- You have no ground-truth outcomes to train against. Then the features are decoration; build
  the label set first.
- The text volume is tiny. A hundred sales notes a quarter will not move a forecast, and the
  fit test's seventh question ("does volume, latency, or brittleness make the current approach
  painful?") fails.
- You want jev to produce the number. It cannot; that is a regression, not a decision.
- The signal is already structured — an RFQ with a quantity field beats any inference from
  prose about quantity.
- The corpus is multilingual and you have not evaluated per language; the feature will be
  noisier for some languages than others, and the model will silently learn that.

## Alternatives considered

- **Keyword counts as features (bag of words, TF-IDF).** The standard baseline, free, and
  genuinely competitive on large corpora. Jev wins on meaning rather than vocabulary and on
  producing a small number of interpretable columns; run both and let the feature-importance
  table decide.
- **Sentiment / topic libraries.** Fixed taxonomy that is not your taxonomy; a "negative"
  sentiment score is not a supply concern.
- **Small LLM (Haiku-class).** Can label the same properties, at seconds and cents per
  record — which for a 100,000-record backfill is the difference between a few dollars and a
  few hundred, plus parse failures to handle.
- **Frontier LLM.** Only worth it for discovering *which* features to propose, which is the
  autoresearch loop's other half.
- **Fine-tuned classifier per feature.** Better once a feature proves itself and the volume
  justifies it; jev is the cheap way to find out which features are worth that investment.
- **Embeddings as features.** Hundreds of uninterpretable dimensions; often effective, never
  explainable to the planner who has to trust the forecast. Jev's columns have names.
- **Human tagging.** Infeasible at backfill scale; keep it for building the evaluation set.

## Sources

Accessed 2026-09-19. `cookbooks/autoresearch_feature_discovery.md` (probabilities as features
for a classical model; evaluating proposed features against held-out ground truth),
`concepts/use-case-map.md` (demand forecasting; ML Feature Extraction),
`concepts/how-to-build-with-system-one.md` ("use the probabilities as features in a
downstream classical machine-learning model"), `patterns/fan-out.md`, `models.md` (price,
rate limits), `model-jaggedness/jev-1.13.md` (modes 2 and 3).
