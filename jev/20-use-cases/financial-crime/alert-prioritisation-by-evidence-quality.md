---
id: uc-financial-crime-alert-prioritisation-by-evidence-quality
title: Order an AML alert queue by the quality of the evidence behind each alert
verdict: good
domain: financial-crime
decision_shapes: [scoring, ranking, routing]
primitives: [score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (financial crime: "Prioritize alerts by risk, relevance, and evidence quality"; "Route ambiguous cases to investigators for review")
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (independent dimensions scored separately, weights owned by code, visibility into the final number)
  - https://docs.typesafe.ai/patterns/fan-out.md  (every question the decision tree might need in one call)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  ("do not use score outputs ... to compute the exact magnitude of a number between two levels"; use the expectation to threshold)
  - https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md  (14 questions in one 111 ms, $0.000043 call; explicit uncertain band)
related: [uc-financial-crime-transaction-narrative-suspicious-characteristics, uc-financial-crime-sar-narrative-element-presence, uc-insurance-fraud-indicator-signals, cb-consistency_noul_cookbook, df-cost-model]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to prioritise our AML alert queue?" Also asked as "can jev tell
us which alerts are worth an investigator's time?", "can we rank alerts by evidence quality
rather than by rule score?", and "can jev auto-close the obviously weak alerts?" — the last
is answered no.

## Verdict

**Good.** The use-case map names it directly: "Prioritize alerts by risk, relevance, and
evidence quality." The problem this solves is real and specific — a transaction monitoring
rules engine emits alerts ordered by rule score and arrival time, and an investigator's first
twenty minutes go on reading enough of the alert narrative and customer file to work out
whether there is anything there at all. That reading is a semantic judgement over text, it
has to happen per alert, and it is currently either unautomated or done with an expensive LLM
call. The constraint that makes it safe is directional: jev reorders the queue and never
empties it. Nothing is closed, dismissed, or de-escalated on a jev answer. The closest
failure mode is 2 by way of the Score warning — the jaggedness page says "do not use score
outputs (e.g., expectations and probability) to compute the exact magnitude of a number", so
the composite is a sort key and a band boundary, not a risk figure anyone quotes.

## What jev decides

State: the alert reason as the rules engine wrote it, the transaction narratives in the
alerting window (code selects them), the customer's stated business and occupation, and the
disposition reasons of that customer's previously closed alerts. Not the full case file —
failure mode 5, and a case file is large.

```
narrative_specificity: Score
  instructions: {question: "How specific is the described activity in `alert.transactions`?",
                 focus: "Judge how much the text says about what the money was for."}
  criteria:
    - "Nothing: references are blank, numeric, or single generic words."
    - "Generic: a purpose word with no detail, such as 'services' or 'invoice'."
    - "Named: a named good, service, or counterparty relationship."
    - "Documented: a named purpose with an invoice, contract, or agreement referenced."

explanation_consistency: Score
  instructions: {question: "How well does the activity in `alert.transactions` fit
                            `customer.stated_business`?",
                 compare: ["`alert.transactions`", "`customer.stated_business`"]}
  criteria:
    - "Contradicts the stated business."
    - "Unrelated to the stated business."
    - "Plausible but not clearly connected."
    - "Clearly consistent with the stated business."

prior_disposition_addresses_this_pattern: Noul
  instructions: {question: "Do `customer.prior_dispositions` already explain the pattern in
                            `alert.reason`?",
                 compare: ["`alert.reason`", "`customer.prior_dispositions`"]}
  criteria: {true:  {what: "A previous closure explains this same pattern for this customer",
                     examples: ["Closed: customer is a licensed money remitter; same pattern"]},
             false: {what: "No prior closure addresses this pattern",
                     not_for: "A prior closure about a different pattern"}}

new_counterparty_relationship_described: Noul
customer_provided_explanation_present: Noul
```

Code composes the priority, with the weights in code so they can be retuned against
disposition outcomes without re-running inference:

```python
priority = (0.40 * (3 - explanation_consistency.score) / 3
          + 0.30 * (1 - prior_disposition_addresses_this_pattern.noul)
          + 0.20 * (3 - narrative_specificity.score) / 3
          + 0.10 * new_counterparty_relationship_described.noul)
```

Bands: the top band goes to the front of the queue with the four answers displayed; the
middle band keeps its existing position; the bottom band is labelled "likely explained by
prior disposition" and stays in the queue at the back. Low confidence on either Score
suppresses the reordering for that alert and it keeps its rule-engine position — the safe
default is "change nothing".

## What stays in code

Everything that determines whether an alert exists: the rules engine, thresholds, aggregation
windows, sanctions and PEP screening, and every regulatory deadline. Deadline arithmetic in
particular is code (failure mode 3) and must dominate the sort — an alert approaching its
regulatory clock goes to the front regardless of what jev said. Disposition, escalation to a
SAR, and closure are investigator actions recorded in code. The weights, the bands, and the
tie-break are code.

## Numbers

Method: `input_tokens ≈ (chars(state) + chars(questions)) / 4`; `cost = tokens × $0.042 /
1e6`, output free. A filtered alert packet of ~4,000 characters plus two Scores and three
Nouls with criteria (~2,000 characters) is about 6,000 / 4 ≈ 1,500 tokens, so **≈ $0.000063
per alert**. Published like-for-like: a 14-question Noul rubric over one claim ran at 111 ms
and $0.000043 per call, sampled 2026-09-11, with comparators at 1,405-13,886 ms and
$0.001089-$0.034275. Because every question shares one state, batching matters: the parallel
questions cookbook measured 13 questions over one ~54,000-character document as "12.2x
cheaper, 10.0x faster" in one call than as thirteen. Investigator time saved, or any
correlation between the composite and eventual SAR filing: **not published**. Your closed
alerts with their disposition reasons are the labelled set; measure rank correlation between
the composite and the outcome before changing anyone's queue.

## When the verdict flips

- To `no` if the composite closes, suppresses, or auto-dispositions an alert. Alert
  disposition is a regulated decision with an audit trail.
- To `weak` if your alerts carry almost no free text. Nothing to read, nothing to judge —
  spend the effort on tuning the rules engine instead.
- To `weak` if investigators work a strict FIFO queue for regulatory reasons; reordering is
  then not permitted and only the displayed answers have value.
- To `conditional` if the alert packet cannot be filtered below the context limit; 64k tokens
  per request is the hard limit and accuracy degrades well before it.

## Alternatives considered

- **Rule score ordering.** The incumbent, free, and already reflects the firm's risk
  appetite. It cannot read the narratives, which is the gap.
- **Fine-tuned model on disposition outcomes.** The strongest option where you have tens of
  thousands of dispositions and stable rules; expensive to maintain and opaque to the
  investigator, where the decomposed answers are readable.
- **Frontier LLM triage per alert.** Better judgement, seconds and cents per alert, and its
  summary may be persuasive when it is wrong; a reasonable escalation for the top band only.
- **Small LLM.** ~13x to 16x the latency and ~26x to 42x the cost on the one published
  like-for-like rubric, with less mass in the uncertain middle.
- **Embeddings over alert text.** Finds similar alerts, which is useful for grouping, not for
  ordering by evidence quality.
- **Human pre-triage.** Exactly the cost being addressed; it stays for the top band.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md` (prioritise alerts by risk, relevance and
evidence quality), `patterns/composite-scoring.md`, `patterns/fan-out.md`,
`model-jaggedness/jev-1.13.md` (Score magnitude warning; context rot),
`cookbooks/consistency_noul_cookbook.md` (111 ms, $0.000043, comparator table, 2026-09-11),
`cookbooks/parallel_questions.md` (12.2x cheaper, 10.0x faster batched), `models.md` (price,
context limit).
