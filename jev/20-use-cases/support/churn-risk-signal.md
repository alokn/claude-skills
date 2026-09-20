---
id: uc-support-churn-risk-signal
title: Extract churn-signal features from support messages for a downstream risk model
verdict: conditional
verdict_as_asked: no
domain: support
decision_shapes: [detection, feature-extraction]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (customer support: "Detect urgency, frustration, churn risk"; ML feature extraction: "churn signals")
  - https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md  (jev probabilities as features for a classical model trained on ground-truth outcomes)
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (independent dimensions, weights in code)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure modes 2 and 3: no counting, no date arithmetic)
related: [au-churn-prediction-from-tickets, uc-support-frustration-scoring, uc-sales-marketing-buyer-intent-detection, uc-support-urgency-detection, au-predict-outcome-instead-of-features]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to predict churn from support tickets?" Also "can jev flag
accounts about to cancel?", "can we add a churn-risk score to the CS dashboard?", and "can
jev read the conversation and tell us if we are going to lose this customer?".

## Verdict

"Can jev predict churn from support tickets?" is answered **no**, in
`au-churn-prediction-from-tickets`: churn depends on usage, billing, tenure, contract
dates and the accounts around this one, none of which is in the ticket text, so the
judgement is not available in the state and the design fails fit-test question 3.

**This entry describes a different proposal, and its verdict is conditional:** jev reads a
message and tells you, reliably and cheaply, whether the customer *said* something that
indicates they are considering leaving. Jev produces *features*; a classical model or a
rule produces the *risk*. The use-case map lists churn signals under ML feature
extraction, not under prediction, and the autoresearch cookbook shows the intended
pattern: jev probabilities as inputs to a model trained on ground-truth outcomes. Used
that way it is a good fit; sold as a churn oracle it is the anti-use-case, and the general
form is `au-predict-outcome-instead-of-features`.

## What jev decides

State: the customer's turns from this conversation only. One call per message, or per
conversation if it is short; do not concatenate a year of history (failure mode 5).

```
cancellation_intent: Noul
  instructions: "Does the customer state they are considering cancelling, not renewing, or
                 leaving for another provider?"
  criteria:
    true:  {what: "Names cancelling, not renewing, or switching",
            examples: ["We're evaluating alternatives", "If this isn't fixed we're out"]}
    false: {what: "No statement about ending the relationship",
            not_for: "Anger with no mention of leaving"}

competitor_mentioned: Noul
  instructions: "Does the customer name a competing product or say they are trialling one?"

unmet_commitment_claimed: Noul
  instructions: "Does the customer say a promise, deadline, or fix was not delivered?"

repeat_contact_complaint: Noul
  instructions: "Does the customer complain about having to raise the same issue more than once?"

blocked_outcome: Score
  criteria: ["The customer's work is unaffected",
             "The customer is inconvenienced but progressing",
             "The customer cannot complete a task they rely on",
             "The customer describes a business outcome of theirs that has already failed"]
```

Five independent signals in one call. None is "churn risk"; each is a fact about the text.
Code (or a downstream model) combines them with tenure, product usage, ticket volume and
renewal date.

## What stays in code

All of it, beyond the reading. "Three tickets in two weeks" is counting (failure mode 2) and
"renewal is 40 days away" is date arithmetic (failure mode 3) — both are code, and both are
stronger predictors than tone. The composite is a weighted sum with weights in config, per
the composite-scoring pattern, or a gradient-boosted model over jev's probabilities plus your
structured features if you have labelled churn outcomes. Who gets contacted, and the save
offer, are policy.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 1,200-character customer turn
plus these five questions (~1,400 characters) is ≈ 650 tokens, **≈ $0.000027 per message**.
Scoring a whole conversation history of 20 messages one at a time is ~$0.00055 for the
account — the reason this is affordable as a batch job over your entire ticket archive, which
is what you need to build the training set. Latency 70–500 ms. No accuracy figure is
published for churn signals; the honest measurement is the lift these features give a model
you already have, evaluated on held-out accounts, which is precisely the experiment the
autoresearch cookbook describes.

## When the verdict flips

- You present the composite as a probability of churn without having calibrated it against
  actual churn. Then it is a made-up number wearing a decimal point, the verdict is **no**,
  and the entry to read is `au-churn-prediction-from-tickets`.
- You have no churn outcomes to validate against. Ship the signals as agent-facing flags only.
- The signal drives an automated discount. Money decision; keep the rule deterministic.
- You try to have jev weigh the signals ("given all this, how likely is churn?"). Multi-hop,
  failure mode 4, and it discards the auditability that made the decomposition worth doing.

## Alternatives considered

- **Keyword list for "cancel", "competitor".** Fires on "cancel my duplicate ticket" and misses
  "we're looking at what else is out there". Precision is the problem, not recall.
- **Frontier LLM over the whole account history.** Can weigh more context and will produce a
  confident narrative; expensive per account, unverifiable, and it still lacks your usage data.
- **Small LLM per message.** Workable; the consistency cookbooks measured 10–125x the latency
  and 22–805x the cost per multi-question rubric call relative to jev, with more run-to-run
  drift on borderline judgements — and borderline is where churn signals live.
- **Pure behavioural model (logins, seats, invoices).** The right backbone. It is blind to
  "we're evaluating alternatives" written in a ticket, which is exactly the gap jev fills.
- **CS manager reading tickets.** Accurate, unscalable; this pushes the reading to the accounts
  where a signal fired.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `cookbooks/autoresearch_feature_discovery.md`,
`patterns/composite-scoring.md`, `model-jaggedness/jev-1.13.md`, `models.md`.
