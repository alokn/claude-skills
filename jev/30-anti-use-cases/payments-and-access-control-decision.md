---
id: au-payments-and-access-control-decision
title: Do not let jev make the final call on a payment or an access-control decision
verdict: no
domain: finance
decision_shapes: [classification, routing, verification]
primitives: [choice, noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/system-one.md  ("Calibration is measured across groups of predictions; it does not guarantee that an individual answer is correct")
  - https://docs.typesafe.ai/confidence.md  ("Thresholds scale with risk"; approve_transfer example asks the user to confirm)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 6, adversarial content; failure mode 2, math)
  - https://news.ycombinator.com/item?id=49717558  ("it can still emit a completely wrong valid value")
related: [au-sole-security-gate, au-legal-determinations-without-counsel, au-zero-hallucination-means-always-right, au-numeric-thresholds-and-arithmetic]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to approve refunds automatically?" Also "let jev decide whether to release
the payout", "use jev to grant admin access when the request looks legitimate", "auto-approve the
chargeback dispute if jev says the customer is right".

## Verdict

**No** as the final authority, at any confidence threshold. Money movement and privilege grants are
invariants that must hold every time, and jev is a probabilistic model. The System One page states the
limit plainly: "Calibration is measured across groups of predictions; it does not guarantee that an
individual answer is correct." A well-calibrated 0.99 still means roughly one in a hundred is wrong, and
a payout or an admin grant is not a decision you get to be wrong about one time in a hundred.

## What jev would get wrong

Three ways. First, the individual-versus-group gap: calibration constrains the error rate, not which case
errs. Second, the input is attacker-controlled — a refund request is written by the person who benefits,
and failure mode 6 says "Content written to adversarially steer the model ... can move the
answer", including "text that argues for its own classification". Third, the amount is a number, and
"Jev is not a calculator", so the limit check must not run through the model either. The Hacker News
discussion of the launch names the trap that makes all three dangerous in production: type safety is not
correctness, and jev "can still emit a completely wrong valid value" — a valid, schema-conforming
`approve`.

## What stays in code

The decision. The entitlement check, the balance check, the limit comparison, the idempotency key, the
dual-control rule for amounts above a threshold, and the audit record. TypeSafe's confidence
documentation models this itself: in its worked example, `approve_transfer` at high confidence goes to
`confirm_then_execute` — a confirmation step — not to silent execution, because "a confidence threshold
is not one number. Different actions within the same system should be gated at different levels depending
on the consequences of getting it wrong."

Jev's role is triage ahead of the gate: a Noul "Does `ticket` state that the item was never delivered?";
a Noul "Does `ticket` cite an order reference that appears in `order.id`?"; a Score over described levels
of fraud-signal strength. Code computes the amount and the eligibility, jev supplies the semantic
evidence, and a human or a deterministic rule authorises.

## Numbers

A triage fan-out over a 1,200-token case with eight questions is roughly 1,800 input tokens, about
$0.00008 at $0.042 per million input tokens with output free (https://docs.typesafe.ai/models.md),
typically about 100 ms. No published source measures jev's accuracy on payment authorisation. TypeSafe's
own workflow evals reach 67.8% combined and 61.7% on security incidents
(https://evals.typesafe.ai, read 2026-09-19) — nowhere near unattended authority over money.

- Field evidence (community-report): HA-Jev (AboveColin), Home Assistant integration — the author's own exclusion list is "not for locks, heaters, alarms, or tight loops", at ~$0.0001 per voice command with 20 exposed entities rising to ~$0.0007 at 150. Source: https://github.com/AboveColin/HA-Jev

## When the verdict flips

It flips to **conditional** when jev decides *who reviews what*, not *what happens*. Concretely: code
auto-approves refunds under a code-computed amount using a deterministic eligibility rule that predates
jev; jev's high-confidence answers move a case to the fast review queue and its low-confidence answers to
the careful one; every approval above the limit keeps a human in the loop. Also conditional in the safe
direction: jev may *decline* or *hold* automatically, since a false hold costs a delay while a false
approval costs money. It never flips to unattended approval — **no rewrite exists**, because the
disqualifier is the cost of a single wrong answer, not the shape of the question.

## Alternatives considered

- **Regex / deterministic**: entitlements, limits, and dual control belong here. Authoritative.
- **Small LLM**: same probabilistic objection, worse calibration, slower.
- **Frontier LLM**: better reasoning, still no guarantee; usable to brief a reviewer.
- **Fine-tuned classifier**: a fraud model trained on your chargeback outcomes is the right statistical
  tool; it still feeds a rules engine.
- **Embeddings**: match against known fraud patterns to prioritise review.
- **Human**: the approver of record. Jev shrinks the queue they read; it does not replace them.

## Sources

- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://news.ycombinator.com/item?id=49717558 — accessed 2026-09-19
- https://evals.typesafe.ai — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
