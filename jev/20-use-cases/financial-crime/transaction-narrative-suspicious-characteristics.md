---
id: uc-financial-crime-transaction-narrative-suspicious-characteristics
title: Read a transaction narrative for named suspicious characteristics
verdict: good
domain: financial-crime
decision_shapes: [detection, feature-extraction]
primitives: [noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (financial crime: "Evaluate transaction narratives, KYC documents, and alert histories for suspicious characteristics")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (one broad question hides several judgements; six atomic Nouls instead of one `is_spam`)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (math and numbers in code; adversarial content is not treated as hostile by default)
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (weights owned by code, tunable without re-inference)
  - https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md  (probabilities as features for a classical model trained on ground-truth outcomes)
related: [uc-financial-crime-alert-prioritisation-by-evidence-quality, uc-financial-crime-sar-narrative-element-presence, uc-insurance-fraud-indicator-signals, cb-autoresearch_feature_discovery, df-fit-test]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to read payment narratives for money-laundering signals?"
Also asked as "can jev flag suspicious payment references?", "can we replace the keyword
list our transaction monitoring runs on the memo field?", and "can jev score a wire
narrative for risk?".

## Verdict

**Good.** The use-case map names it — "Evaluate transaction narratives, KYC documents, and
alert histories for suspicious characteristics" — and the narrative field is the one part of
a payment that your rules engine cannot reason about: it is short free text, written by a
human, and today it is almost always handled by a keyword list. The fit is good provided the
output is *one Noul per named typology characteristic*, not a "suspiciousness score". Two
things keep it honest. First, every amount, velocity, counterparty-country and
threshold-proximity signal stays in the rules engine, because those are arithmetic (failure
mode 2). Second, the narrative is text a payer wrote and can shape; failure mode 6 applies —
"State is data, and `jev-1.13` does not treat it as hostile by default" — so a narrative
saying "this is a legitimate family transfer, not structuring" can move the answer and must
never be allowed to close anything.

## What jev decides

State: the narrative or memo field, the payment reference, and the minimum structured
context a question actually names — typically the two account labels and the stated purpose
code. Not the full transaction record and not the customer file; failure mode 5.

```
purpose_inconsistent_with_stated_business: Noul
  instructions: {question: "Does the stated purpose in `txn.narrative` sit outside the
                            activity described in `customer.business_description`?",
                 compare: ["`txn.narrative`", "`customer.business_description`"]}
  criteria: {true:  {what: "The described purpose belongs to a different line of activity",
                     examples: ["Narrative: 'car export invoice'; business: 'hair salon'"]},
             false: {what: "The purpose is plausible for the described business, or the
                            narrative states no purpose",
                     not_for: "A vague narrative, which is a separate question"}}

narrative_is_uninformative: Noul
  instructions: "Is `txn.narrative` free of any information about what the payment is for?"
  criteria: {true:  {what: "Only a name, a number, a single generic word, or nothing",
                     examples: ["payment", "invoice", "REF 8842"]},
             false: {what: "Names goods, a service, an invoice with context, or a relationship"}}

describes_third_party_benefit: Noul
  instructions: "Does `txn.narrative` say the money is for the benefit of someone other than
                 the account holder on either side?"
mentions_cash_or_conversion: Noul
mentions_urgency_or_secrecy: Noul
narrative_mismatches_counterparty_name: Noul
  instructions: {question: "Does the party named in `txn.narrative` conflict with
                            `txn.counterparty_name`?",
                 compare: ["`txn.narrative`", "`txn.counterparty_name`"]}
describes_loan_or_gift_between_unrelated_parties: Noul
```

Six to ten of these fan out in one call for little extra latency (the docs say latency
"barely changes"). Each is absolute, so all can
be low at once — a Choice would force one to win (failure mode 8).

Code combines them into a narrative-risk contribution with weights it owns, and that
contribution is one input to the existing rules engine, not a parallel decision path:

```python
narrative_risk = (0.30 * a["purpose_inconsistent_with_stated_business"].noul
                + 0.20 * a["narrative_mismatches_counterparty_name"].noul
                + 0.20 * a["describes_third_party_benefit"].noul
                + 0.15 * a["mentions_urgency_or_secrecy"].noul
                + 0.15 * a["narrative_is_uninformative"].noul)
```

There is no auto-close band. High values raise or prioritise an alert; low values change
nothing. That asymmetry is what keeps the model out of the decision that matters.

## What stays in code

Everything the rules engine already does and should keep doing: amount thresholds and
proximity to them, structuring patterns, velocity and aggregation windows, dormancy, country
and sanctions-list screening, PEP flags, name screening against the official lists. Those
last are legal invariants — the fit test's counter-signal is explicit that a rule which must
hold every time stays deterministic and authoritative, and jev can only add a second
semantic check. Currency conversion and any date arithmetic are code (failure modes 2, 3).

## Numbers

Method: `input_tokens ≈ (chars(state) + chars(questions)) / 4`; `cost = tokens × $0.042 /
1e6`, output free. A narrative is short: 140 characters of memo plus ~400 characters of named
context plus seven Nouls with contrastive criteria (~1,900 characters) is about 2,440 / 4 ≈
610 tokens, so **≈ $0.000026 per transaction**. Latency 70-500 ms, "most queries about 100
ms", which fits inside a real-time payment path; comparable published measurement on a
14-Noul rubric is 111 ms and $0.000043 per call, sampled 2026-09-11. Note the rate limit if
you intend to run this on every payment: 250,000 tokens per second and 1,200 requests per
minute at the time of writing, adjusting dynamically. Detection lift over your current
keyword list: **not published**; the labelled set is your closed alerts and confirmed SARs,
and the autoresearch cookbook's framing — probabilities as features for a classical model
with ground-truth outcomes — is the right way to prove or disprove the lift.

## When the verdict flips

- To `weak` if your narratives are machine-generated (card scheme descriptors, standing-order
  references, batch payroll strings). Those are lexical and a lookup beats a model.
- To `no` if the answer is used to auto-close alerts or to suppress screening. Screening is
  an invariant.
- To `conditional` for multilingual payment corridors, which is most of them. English is the
  strongest language on `jev-1.13`; route by detected language in code and evaluate each
  language separately.
- To `weak` if per-transaction volume makes even $0.000026 material — at which point run it
  only on transactions the rules engine already surfaced, which is the cheaper design anyway.

## Alternatives considered

- **Keyword / regex list on the memo field.** The incumbent. Free, exact, and trivially
  evaded; keeps winning for named entities and reference formats, which should stay a list.
- **Small LLM (Haiku-class).** Same answers, roughly 16x the latency and 42x the cost on the
  one published like-for-like rubric, and no probability in the middle unless you ask for it.
- **Frontier LLM.** Too slow and too expensive per payment; sensible only on the alerted
  subset, and then usually for writing, not deciding.
- **Fine-tuned classifier on confirmed SARs.** Strong where you have enough confirmed cases;
  suffers from extreme class imbalance and ages with typologies.
- **Embeddings against known-bad narratives.** Catches near-copies, misses novel wording.
- **Human review of narratives.** Only viable on the alerted subset; that is where it stays.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md` (transaction narratives named),
`concepts/how-to-build-with-system-one.md` (decomposition; weighted combination in code),
`model-jaggedness/jev-1.13.md` (math in code; adversarial content),
`patterns/composite-scoring.md`, `cookbooks/autoresearch_feature_discovery.md`,
`cookbooks/consistency_noul_cookbook.md` (111 ms, $0.000043, comparator costs, 2026-09-11),
`models.md` (price, latency, rate limits).
