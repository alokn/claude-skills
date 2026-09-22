---
id: au-straight-through-claim-payment-decision
title: Do not let jev decide which claims are paid straight through
verdict: no
domain: insurance
decision_shapes: [routing, classification, scoring]
primitives: [choice, score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/confidence.md  (three bands; "thresholds scale with the stakes of the action")
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (per-action thresholds; a 0.6 floor, 0.85 for the risky action)
  - https://docs.typesafe.ai/concepts/system-one.md  ("Calibration is measured across groups of predictions; it does not guarantee that an individual answer is correct")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 2, arithmetic; failure mode 8, overconfidence off-distribution)
  - https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md  (a pipeline that "sorts incoming claims into pay, deny, or send-to-a-human"; the band is "illustrative", neither "a calibrated guarantee nor an optimized threshold")
related: [uc-insurance-straight-through-vs-adjuster-routing, au-payments-and-access-control-decision, au-numeric-thresholds-and-arithmetic, au-decisions-that-need-an-explanation, uc-insurance-rubric-claim-triage-uncertain-band]
last_verified: 2026-09-20
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to decide which claims can be paid straight through?" Also
asked as "can we use the confidence value as an STP gate?", "can jev replace our
straight-through eligibility rules?", and "can jev decide this claim needs no adjuster?".

## Verdict

**No.** Straight-through processing releases money, and the eligibility criteria are
contractual and regulatory invariants rather than judgements about text. A probability
cannot hold an invariant: the System One page says so directly — "Calibration is measured
across groups of predictions; it does not guarantee that an individual answer is correct."
A well-calibrated 0.95 still pays the wrong claim one time in twenty, and there is no
threshold that converts that into a rule you can put in a compliance file. The proposal that
*does* fit — jev moving claims **out** of straight-through processing, never into it —
is a different design with its own verdict, and it lives in
`uc-insurance-straight-through-vs-adjuster-routing`.

## What jev would get wrong

Three things, in order of cost. First, the arithmetic: straight-through eligibility is
mostly amount against ceiling, deductible, per-incident limit, policy-in-force on the loss
date and reporting window. Those are failure modes 2 and 3 — jev "is not a calculator" and
reads dates as text — so a model answer about them is a guess dressed as a decision. The
consistency cookbook illustrates the trap with its own rubric, which contains a
`line_items_sum` and a deductible question, and whose borderline probabilities show why a
near-0.5 answer cannot authorise a payout.

Second, the confidence field is not a probability that the payment is correct: "the answer
tells you what; confidence tells you whether to act", and the pattern's own worked example
puts the risky action behind 0.85 *plus* a human confirmation. Third, there is no rationale —
a regulator asking why this claim was paid without review gets a decimal, not a reason
(`au-decisions-that-need-an-explanation`).

## What stays in code

The gate. Amount against the straight-through ceiling, deductible arithmetic, per-incident
limit, policy in force on the loss date, reporting window, sanctions and watch-list checks,
prior-claim count, payment execution, reserve setting and the audit record. All of it
predates jev and none of it should be routed through a model.

## Numbers

Method: `input_tokens ≈ (chars(state) + chars(questions)) / 4`; `cost = tokens × $0.042 /
1e6`, output free. A 2,000-character narrative plus a four-option Choice, three Nouls and a
Score is about 1,100 tokens, ≈ **$0.000046 per claim**; measured on claim-shaped rubrics
2026-09-11, jev ran 111 ms / $0.000043 against `claude-haiku-4-5` at 1,780 ms / $0.001798.
**Straight-through accuracy, leakage, or agreement with adjuster decisions: not published** —
no source measures jev on this task. The unit cost is irrelevant next to one wrongly paid
claim.

## When the verdict flips

It flips to **conditional** only when the direction reverses and the deterministic gate
stays: your existing eligibility rules run first and remain authoritative, and jev's answers
may only *remove* a claim from straight-through processing and send it to a person. That
design is `uc-insurance-straight-through-vs-adjuster-routing` (`conditional`), with bands
fitted on your own closed claims. It never flips to jev releasing a payment — the
disqualifier is the cost of a single wrong answer, not the shape of the question.

## Alternatives considered

- **Deterministic eligibility rules.** The incumbent and the authority. Exact, auditable, free.
- **Fine-tuned model on closed claims.** A legitimate prioritisation tool; it still feeds the
  rules engine.
- **Frontier LLM.** Better judgement, seconds and cents per claim, same objection: no invariant.
- **Embeddings.** No notion of "eligible for straight-through processing".
- **Human adjuster.** The decision-maker of record; jev can shrink what reaches them, from the
  safe side only.

## Sources

- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-20
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-20
- https://docs.typesafe.ai/patterns/confidence-routing.md — accessed 2026-09-20
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-20
- https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md — accessed 2026-09-20
  (111 ms, $0.000043 and comparator latencies, 2026-09-11; "illustrative" band)
