---
id: au-churn-prediction-from-tickets
title: Do not ask jev to predict churn from support conversations
verdict: no
domain: support
decision_shapes: [detection, classification, scoring]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (churn signals are listed under ML feature extraction, not under prediction)
  - https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md  (jev probabilities as features for a classical model trained on ground-truth outcomes)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 2 counting, mode 3 dates, mode 4 multi-hop)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms)
related: [uc-support-churn-risk-signal, au-predict-outcome-instead-of-features, au-private-knowledge-not-in-state, uc-data-ml-text-features-for-tabular-model]
last_verified: 2026-09-20
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to predict churn from support tickets?" Also: "can jev flag
accounts about to cancel?", "can we put a churn-risk score on the CS dashboard?", "can jev
read the conversation and tell us if we are going to lose this customer?".

## Verdict

**No.** Churn is a future event determined mostly by things that are not in the ticket:
seat usage, login trend, billing history, tenure, contract dates, the renewal calendar and
what is happening in the accounts around this one. The judgement is not available in the
state, so the design fails fit-test question 3 before any accuracy question arises. This is
the general case in `au-predict-outcome-instead-of-features`, and the use-case map agrees
with the boundary: it lists churn signals under **ML feature extraction**, not under
prediction. The design that works — jev reads the message for what the customer *said*, a
model or a rule computes the risk — is `uc-support-churn-risk-signal` (`conditional`).

## What jev would get wrong

It would produce a confident number for a question it cannot see the evidence for. Ask "how
likely is this account to churn?" and you get a probability that is really a summary of tone,
because tone is the only input; the account's usage collapse last month is invisible. That is
failure mode 8 territory — a plausible answer off the distribution the question implies — and
worse, it is unfalsifiable at the point of use, because nobody sees the missing features to
notice they were missing.

Two further mismatches. "Three tickets in two weeks" is counting (failure mode 2) and
"renewal is 40 days away" is date arithmetic (failure mode 3) — both stronger predictors than
sentiment, both code's job. And weighing several signals into one risk number in one question
is multi-hop (failure mode 4), which discards the per-signal auditability that makes the
decomposition worth doing. Presenting the result as a *probability of churn* without
calibrating it against actual churn outcomes is a made-up number wearing a decimal point.

## What stays in code

Everything beyond the reading. Ticket counts, tenure, renewal dates, usage and billing
features, the weighted composite or the gradient-boosted model over jev's probabilities, the
threshold, who gets contacted, and any save offer — a save offer that spends money must stay
a deterministic rule.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 1,200-character customer turn
with five signal questions is ≈ 650 tokens, **≈ $0.000027 per message**, 70-500 ms. **No
accuracy figure is published for churn signals or churn prediction**, first-party or
independent. The only honest measurement is the lift these features give a model you already
have, evaluated on held-out accounts — the experiment the autoresearch cookbook describes,
which is also the reason the feature framing is the supported one.

## When the verdict flips

It flips to **conditional** when the goal is rewritten from prediction to feature extraction:
jev answers narrow, checkable questions about the text (did the customer name cancelling, did
they name a competitor, did they say a commitment was missed) and code or a trained model
combines those with your behavioural data — `uc-support-churn-risk-signal`. If you have no
churn outcomes to validate against, ship the signals as agent-facing flags only and label
them as flags, not as risk.

## Alternatives considered

- **Behavioural churn model (logins, seats, invoices).** The right backbone; blind to
  "we're evaluating alternatives" in a ticket, which is the gap the features fill.
- **Keyword list for "cancel" and competitor names.** Fires on "cancel my duplicate ticket"
  and misses the polite version. Precision is the problem.
- **Frontier LLM over the account history.** A confident narrative, still no usage data;
  expensive per account, unverifiable.
- **Small LLM per message.** Workable; slower and costlier per multi-question call.
- **CS manager reading tickets.** Accurate, unscalable; the features order their reading.

## Sources

- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-20
- https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md — accessed 2026-09-20
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-20
- https://docs.typesafe.ai/models.md — accessed 2026-09-20
