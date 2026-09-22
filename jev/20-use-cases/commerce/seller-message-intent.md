---
id: uc-commerce-seller-message-intent
title: Classify a seller's message and route it to the handler that can resolve it
verdict: good
domain: commerce
decision_shapes: [classification, routing]
primitives: [choice, score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/patterns/intent-routing.md  (intent Choice plus complexity Score routing to deterministic code, specialist LLMs, or a human; confidence floor at 0.5)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (e-commerce marketplaces; customer support: "Route cases to the right team, queue, or automated workflow")
  - https://docs.typesafe.ai/patterns/fan-out.md  (speculative questions cost tokens, not latency)
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (thresholds scale with the stakes of the branch)
related: [uc-support-intent-routing-handlers, uc-commerce-prohibited-counterfeit-signals, uc-commerce-return-reason-classification]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to triage seller support messages?" Also "can jev tell a payout
question from an appeal?", "can we auto-answer seller questions we already have data for?",
and "how do we get appeals out of the general queue?".

## Verdict

**Good.** Seller messages are the intent-routing pattern's shape with higher stakes than
buyer support: a misrouted appeal against a suspension costs a seller their income and costs
you a regulatory complaint, so the confidence floor sits higher and the human band is wider.
The reason it works is that a large share of seller messages are answerable from data you
already hold — payout dates, fee calculations, listing status — so the router's value is
routing those to a lookup instead of a person. It is `good` rather than `strong` because the
published pattern uses consumer support; the mechanism is identical, the thresholds are not.

## What jev decides

State: the message, and a compact list of what the deterministic handlers can answer, so the
model classifies against your actual capabilities rather than the phrase's connotation.

```
intent: Choice
  instructions: "What is the seller's primary request?"
  criteria:
    payout_or_fees:    {what: "Payout timing, fee amounts, reserves, or reconciliation",
                        not_for: "Disputing a specific transaction with a buyer"}
    listing_status:    {what: "Why a listing is not live, or how to reinstate it"}
    policy_appeal:     {what: "Contesting an enforcement action on their account or listing"}
    order_or_buyer:    {what: "A specific order, a buyer dispute, or a return"}
    account_access:    {what: "Login, verification, bank details, or permissions"}
    onboarding_howto:  {what: "How to do something they have not done before"}
    other:             {what: "None of the above"}

complexity: Score
  criteria: ["Answerable from a record lookup",
             "Needs judgement or several steps",
             "Unusual, precedent-setting, or an escalation"]

regulatory_or_legal_language: Noul
  instructions: "Does the message reference a regulator, a lawyer, or a formal legal demand?"

threatens_to_leave_platform: Noul
  instructions: "Does the seller say they will stop selling on the platform or move elsewhere?"

message_is_a_reply_to_enforcement: Noul
  instructions: "Is the message a response to an enforcement notice rather than a new request?"
```

Routing, following the pattern: below `intent.confidence < 0.6` go to a human regardless;
`payout_or_fees` and `listing_status` at low complexity to a deterministic answer built from
the seller's record; `onboarding_howto` to a specialist LLM with the help centre loaded;
`policy_appeal` always to a human, because the pattern's own advice is that thresholds scale
with the stakes and an appeal is the highest-stakes branch on a marketplace.
`regulatory_or_legal_language >= 0.5` overrides everything and routes to the legal queue.

## What stays in code

The handlers, the record lookups, and the overrides. Account tier, suspension state, open
disputes and payout schedules are structured data: if the seller is suspended, every message
routes to the appeals queue before a call is made. Dates ("when is my payout") are computed,
never asked — failure mode 3. The router's timeout and its deterministic fallback to the
general queue are mandatory.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. An 800-character message plus
these five questions with criteria (~1,600 characters) is ≈ 600 tokens, **≈ $0.000025 per
message**. Against what it avoids: the consistency cookbooks priced a single multi-question
call at $0.00095–$0.0035 for a small LLM and $0.028–$0.041 for a reasoning model (prices as of
2026-07, sampled 2026-09-11), so deflecting one message in fifty to a lookup pays for the
router many times over. Latency in those runs: jev 111–114 ms mean round trip against 826 ms
to 13.9 s for the LLM conditions. No accuracy figure is published for seller intent; backtest
against the queue a human eventually moved each message to, and report agreement plus the
misroute rate on the appeals class specifically, because that is the class that matters.

## When the verdict flips

- Sellers already pick a topic in a structured contact form and pick it accurately. Lookup.
- Appeals are auto-resolved on the router's output. Never; the appeal branch exists to reach a
  person.
- The seller base is largely non-English, which on a cross-border marketplace it is. Evaluate
  per language before lowering the human band.
- You let the router decide *and* draft the reply *and* apply it. That is an agent loop; the
  docs are explicit that jev does not choose its own next action.

## Alternatives considered

- **Keyword rules on the message.** The status quo in most seller-support tools; "payout" and
  "fee" appear in appeals too, so precision on the branch that matters is poor.
- **Form-based contact reasons.** Keep them. They are deterministic when the seller is honest
  and calm, and least reliable when the seller is neither.
- **Frontier LLM router.** Better on ambiguous mixed-intent messages; seconds and cents per
  message, for a decision made on every inbound.
- **Small LLM.** Viable; roughly an order of magnitude on both cost and latency from the
  measurements above, plus occasional parse failures, where a Choice cannot return an
  out-of-set label.
- **Fine-tuned intent classifier.** Good with a stable intent set and labelled history; no
  complexity estimate and no per-message probability to escalate on.

## Sources

Accessed 2026-09-19. `patterns/intent-routing.md`, `patterns/confidence-routing.md`,
`patterns/fan-out.md`, `concepts/use-case-map.md`,
`cookbooks/consistency_noul_cookbook.md` and `cookbooks/consistency_choice_cookbook.md`
(cost and latency per condition, sampled 2026-09-11), `model-jaggedness/jev-1.13.md`, `models.md`.
