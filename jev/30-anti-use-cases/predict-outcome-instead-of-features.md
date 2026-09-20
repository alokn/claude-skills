---
id: au-predict-outcome-instead-of-features
title: Do not ask jev to predict churn, conversion, or any future outcome directly
verdict: no
domain: ml
decision_shapes: [scoring, classification, feature-extraction]
primitives: [choice, score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/system-one.md  (System One judges what is present, from the state)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 5, large state; mode 2, numbers)
  - https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md  (text features feeding a downstream model)
  - https://github.com/yodablocks/jev-orderby-bench  (ECE 0.242 once the target stops being a property of the text)
related: [au-interpolate-magnitude-from-score, au-private-knowledge-not-in-state, au-copy-calibration-thresholds-across-domains, uc-support-churn-risk-signal, uc-data-ml-text-features-for-tabular-model]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to ask jev how likely this account is to churn next quarter?" Also "score this lead's
probability of converting", "will this ticket escalate?", "predict whether this invoice will be paid
late", "give me a propensity score".

## Verdict

**No** as a direct prediction. jev judges what is present in the state; churn, conversion and payment
behaviour are events in the future that depend on price changes, a competitor's campaign, the account
team's actions and the customer's budget cycle — none of which is in the text you send. The returned
number will be well-typed, confident-looking and unanchored: a calibrated read of "how much does this
text sound like churn?" is not a calibrated probability of churning. The pattern that works, and that the
feature-discovery cookbook is built on, is the other one: jev extracts the text features, and a model
trained on your outcomes converts features into a probability.

## What jev would get wrong

The base rate, which it has no way to know. If 4% of accounts churn per quarter, a model reading only a
support thread cannot recover that prior, and its "high risk" band fills with whichever accounts sound
most annoyed — a correlate, not the target. The measured shape supports this: yodablocks' pre-registered
gates passed on topic membership, a property of the text (ECE 0.045), and failed on graded commercial
relevance, a judgement about the world (ECE 0.242). A future event sits further from the text than
either. And failure mode 5 means dumping a year of account history into the state makes it worse.

## What stays in code

The model that owns the prediction, and the evaluation that keeps it honest. Logistic regression,
gradient boosting or survival analysis over your own outcome history; jev's outputs join the tabular
features as columns — sentiment trajectory, whether a competitor was named, whether a cancellation was
mentioned, whether the last reply resolved the issue, complaint type. Code holds the base rate, the
temporal split (train on the past, test on the future), the calibration of the final score, and the
threshold on which anyone acts. Store each jev feature with its version so the training set and the
serving path agree.

## Numbers

No published source measures jev on churn or conversion prediction; the closest signal is that calibration
degrades sharply when the target stops being a property of the text — ECE 0.045 on 20 Newsgroups topics
against 0.242 on Amazon ESCI relevance, same harness, same model version
(https://github.com/yodablocks/jev-orderby-bench, accessed 2026-09-19). Feature extraction is cheap: a
2,000-token account digest with twelve feature questions is roughly 2,800 input tokens, about $0.00012 at
$0.042 per million input tokens with output free (https://docs.typesafe.ai/models.md), one call, typically
about 100 ms; multiply by your own account count and refresh rate, which this entry does not
supply. The expensive part is the outcome
labels, which you already have if you have been trading a year.

## When the verdict flips

It flips to **good** the moment the question changes from "will this happen?" to "is this present in the
text?": has the customer mentioned cancelling, named a competitor, asked about contract terms, escalated
twice, or gone quiet after an unresolved issue. Each is a Noul over evidence in the state, each is
auditable, and each becomes a feature. It also flips for *triage* rather than prediction — ordering a
retention queue by how urgent the text sounds is a legitimate System One task, provided nobody calls the
result a probability of churn.

## Alternatives considered

- **Regex / deterministic**: the behavioural signals (logins, usage, invoice age) are in your database
  and belong in the model directly.
- **Small LLM**: same conceptual error, worse features.
- **Frontier LLM**: reasons more fluently about the future and is no better calibrated about it.
- **Fine-tuned classifier**: trained on your outcomes, this is the right tool for the prediction itself.
- **Embeddings**: an alternative feature source; less interpretable than named Nouls.
- **Human**: the account manager's judgement is another feature, with the same base-rate problem.

## Sources

- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md — accessed 2026-09-19
- https://github.com/yodablocks/jev-orderby-bench — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
