---
id: uc-support-ticket-team-routing
title: Route an inbound support ticket to the team that should own it
verdict: good
domain: support
decision_shapes: [classification, routing]
primitives: [choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (worked `triage_ticket` example: a `topic` Choice over billing/orders/account with contrastive criteria, confidence gate at 0.75)
  - https://docs.typesafe.ai/patterns/fan-out.md  (support ticket triage as the canonical fan-out example)
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (per-action thresholds; floor below which everything goes to a human)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (customer support: "Route cases to the right team, queue, or automated workflow")
  - https://docs.typesafe.ai/cookbooks/classification_using_confidence.md  (Choice "works reliably up to roughly 240 options"; coarser answer when unsure)
related: [uc-support-intent-routing-handlers, uc-support-urgency-detection, uc-support-refund-request-detection, df-fit-test]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to route support tickets to the right team?" Also asked as
"can jev replace our keyword-based triage rules?", "should jev pick the queue for a new
Zendesk ticket?", and "can we drop the GPT call that labels the ticket department?".

## Verdict

**Good** — the shape is demonstrated by the how-to-build guide's worked `triage_ticket`
example; no task-matched labelled accuracy is published; shadow-evaluate against the
incumbent before acting. This is the example TypeSafe itself uses to teach the model.
The docs' worked `triage_ticket` function classifies the ticket with a `topic` Choice
over billing / orders / account and gates the result on confidence, and the fan-out
pattern page uses the same task. The decision is a single semantic read of one short
text into a small, closed set of destinations, code owns the routing and the side
effects, and the confidence value gives you a natural low-confidence path (the human
queue you already have). All seven fit-test questions pass.

## What jev decides

State: only the fields the questions need — `ticket.message`, `ticket.subject`, the
customer's `plan` and `open_orders` if the categories depend on entitlement. Not the full
CRM record; failure mode 5 (context rot) is the one this design most easily walks into.

```
team: Choice
  instructions: {question: "Which team should handle `ticket.message`?",
                 focus: "Classify the customer's primary request."}
  criteria:
    billing:   {what: "Charges, invoices, refunds, or subscriptions",
                not_for: "Order tracking or account access",
                examples: ["I was charged twice", "Where is my refund?"]}
    orders:    {what: "Order status, delivery, cancellation, or returns",
                not_for: "Charges or account access",
                examples: ["Where is my order?", "Cancel my shipment"]}
    account:   {what: "Login, profile, permissions, or security",
                not_for: "Charges or order tracking",
                examples: ["Reset my password", "I cannot sign in"]}
    other:     {what: "Anything none of the above describes"}
```

The `not_for` field is what makes the boundary explicit, and the docs recommend the same
field names across every option so the model can compare them directly. An `other` option
is mandatory: a Choice is relative and will always name something, so without `other` a
sales enquiry lands in `billing` at high confidence.

Ride the rest of the decision tree along in the same call (fan-out): `refund_requested`
(Noul), `frustration` (Score), `mentions_open_order` (Noul). They cost tokens and no
latency, and code ignores the ones the chosen branch does not read.

Bands: `confidence >= 0.75` assign automatically; `0.5–0.75` assign but leave the ticket in
the general queue with the top two probabilities attached; `< 0.5` to the human triage
queue. Tune on your own historical assignments — the docs' 0.75 is an example, not a
constant. A useful alternative for the middle band, from the classification-with-confidence
cookbook, is to answer one level coarser (a parent group rather than the leaf queue) rather
than abstain.

## What stays in code

The queue assignment itself and every write. VIP and enterprise overrides, contractual
routing, reopen-to-original-owner, language-based routing to a regional team, and anything
driven by ticket metadata (channel, product line on the account) all stay as deterministic
rules evaluated *before* jev is called — if a rule already decides the queue, do not spend a
call. Closed or duplicate tickets return early, as in the docs' example.

## Numbers

Method: `input_tokens ≈ (chars(state) + chars(questions)) / 4`, `cost = tokens × $0.042 /
1e6` (output free, per `models.md`). A 900-character ticket plus this Choice with
contrastive criteria (~1,300 characters) plus four ride-along questions (~800 characters)
is about (900 + 2,100) / 4 ≈ 750 tokens, so **≈ $0.000032 per ticket**. TypeSafe's
quickstart reports 312 input tokens for a 120-character ticket and three questions, which
is the same order. Latency: 70–500 ms, "most queries about 100 ms"; the choice-consistency
cookbook measured a mean 114 ms round trip for an eight-Choice call on 2026-09-11. No
accuracy figure exists for this task on your taxonomy — measure it. Volume is your ticket
rate; do not multiply until you have counted it.

- Field evidence (community-report): a public support-inbox triage spec batches department (Choice), urgency (Score) and frustration (Noul) into a single call on the inbox write path, budgeted at "$0.042/MTok" and "~600 ms" with a "$1 per packet" spend cap and an advisory-only rollout until 100 rows are logged, 2026-09. Source: https://github.com/Nishfleet/0509/issues/3542

## When the verdict flips

- Your queues are determined by a field the customer already picks in a form. Then the
  routing is lexical and deterministic code wins.
- More than ~240 destinations. The classification-with-confidence cookbook states a Choice
  "works reliably up to roughly 240 options", against a hard cap of 255; deeper taxonomies
  need the hierarchical-classification beam search, which changes the shape.
- Routing implies an irreversible action (auto-close, auto-refund). Then the Choice is an
  input to that decision, never the gate.
- Mostly non-English tickets, unless you have run your own evaluation; English is the
  strongest language on `jev-1.13`.

## Alternatives considered

- **Regex / keyword rules.** Free and exact, but they encode vocabulary, not intent, and the
  list grows forever. They win only when the trigger really is a literal token.
- **Frontier LLM.** Comparable or better labels at seconds of latency, cents per call, and a
  parse-failure rate; the schema-safety and ~100 ms are the reason to switch, not accuracy.
- **Small LLM (Haiku-class).** Closest competitor. The consistency cookbooks measured
  `claude-haiku-4-5` at 1,485–3,860 ms and $0.00095–$0.0035 per rubric call against 111–114 ms
  and ~$0.000045 for jev on the same rubrics. That is a cost and latency argument, not a
  stability one: in the choices cookbook's run Haiku at temperature 0 was the more repeatable
  condition (100.0% against jev's 90.8% raw, SD 0.0012 against 0.0098).
- **Fine-tuned classifier.** Better if you have tens of thousands of labelled tickets and a
  frozen taxonomy; worse the moment a queue is added, because jev needs only an edited string.
- **Embeddings + nearest centroid.** Needs threshold tuning and degrades on short tickets.
- **Human triage.** Stays, for the low-confidence band only.

## Sources

Accessed 2026-09-19. `concepts/how-to-build-with-system-one.md` (worked triage function),
`patterns/fan-out.md`, `patterns/confidence-routing.md`, `concepts/use-case-map.md`,
`cookbooks/classification_using_confidence.md`, `cookbooks/consistency_choice_cookbook.md`
(114 ms, $0.000046 per 8-Choice call, 2026-09-11), `models.md` (price, limits).
