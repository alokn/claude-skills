---
id: uc-sales-marketing-lead-routing
title: Route a qualified lead to the right team, track, and speed of response
verdict: good
domain: sales-marketing
decision_shapes: [classification, routing]
primitives: [choice, score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (lead generation: "Prioritize and route leads")
  - https://docs.typesafe.ai/patterns/intent-routing.md  (classify intent and complexity, then route to a lookup, a specialist, or a human; confidence floor below which everything goes to a person)
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (per-action thresholds scaled to stakes)
  - https://docs.typesafe.ai/patterns/fan-out.md  (routing and its speculative follow-ups in one call)
related: [uc-sales-marketing-buyer-intent-detection, uc-sales-marketing-icp-fit-scoring, uc-support-intent-routing-handlers]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to route leads?" Also "can jev decide which leads an SDR calls
first?", "can we route enterprise enquiries away from the self-serve funnel?", and "can jev
pick the right specialist for a technical question?".

## Verdict

**Good.** Lead routing is the intent-routing pattern with a revenue label on it: classify
fast, send the cases a lookup or a self-serve flow can handle there, send the ones that need a
specialist to the right one, and send everything uncertain to a person. It works because the
categories are yours, the state is short, and there is always a default queue for the
low-confidence band. It is `good` rather than `strong` because most routing inputs — territory,
account ownership, company size, existing pipeline — are structured fields that code should
own, so jev's contribution is the residue: what the message says, when the CRM does not know.
Build it the other way round and you will have made a deterministic problem probabilistic.

## What jev decides

State: the lead's message, the form fields, and a compact list of the routes available with
one line on what each handles.

```
route: Choice
  instructions: {question: "Which team should take this lead first?",
                 focus: "Match what the lead is asking for to what each route handles."}
  criteria:
    self_serve:      {what: "Can start without help; asks how to sign up or try it",
                      not_for: "Asks about contracts, security review, or volume pricing"}
    smb_sales:       {what: "A buying question from a small team"}
    enterprise_sales:{what: "Procurement, security review, volume pricing, or multi-team rollout"}
    partnerships:    {what: "Proposes reselling, integrating, or co-marketing"}
    solutions_eng:   {what: "A technical feasibility or integration question needing an engineer"}
    support:         {what: "An existing customer with a problem"}
    no_route:        {what: "Job enquiry, vendor pitch, student request, or spam"}

complexity: Score
  criteria: ["Answerable from a standard response or the docs",
             "Needs a conversation and some judgement",
             "Unusual requirements, custom terms, or a bespoke integration"]

speed_matters: Noul
  instructions: "Does the message indicate the sender is actively evaluating now — naming a
                 deadline, a trial in progress, or a comparison underway?"

multiple_stakeholders: Noul
  instructions: "Does the message indicate several people or teams are involved in the decision?"
```

Routing, following the pattern: below `route.confidence < 0.6`, go to the general SDR queue
regardless; `self_serve` at low complexity gets the automated response; `enterprise_sales`
needs a higher bar than `smb_sales` because misrouting an enterprise lead down the self-serve
path is the expensive error, and the confidence-routing page's rule is exactly this — the
threshold scales with the consequence. `speed_matters >= 0.6` sets the SLA tier, and the SLA
clock itself is code.

## What stays in code

Ownership and everything the CRM already knows. Territory, named-account mapping, existing
opportunity, partner-sourced flags, round-robin and capacity are deterministic and must run
*before* the call — if the account has an owner, the lead goes to them and no question is
asked. Suppression and opt-out state override everything. Response-time SLAs, escalation
timers and working-hours arithmetic are dates and counts, which failure modes 2 and 3 put
firmly in code.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 600-character message plus
seven route descriptions and four questions (~2,000 characters) is ≈ 650 tokens, **≈ $0.000027
per lead**. Compare with what a misroute costs in response time rather than with what the call
costs: at the volumes most teams run, the inference bill is invisible and the argument is
entirely about routing quality and speed. Latency 70–500 ms, inside the window for routing
before the auto-acknowledgement goes out; the consistency cookbooks measured jev at 111–114 ms
mean round trip against 826 ms to 13.9 s for six LLM conditions on comparable multi-question
calls (sampled 2026-09-11). No published accuracy for lead routing; backtest against the team
that eventually worked each lead, and report the misroute rate for `enterprise_sales`
separately from the aggregate.

## When the verdict flips

- Routing is fully determined by territory and account ownership. Then it is a join, and jev
  is an expensive way to reproduce it.
- The route triggers automated outbound with no human. Keep suppression and consent
  deterministic; a probability must not override an opt-out.
- You have more than a handful of routes with overlapping definitions. A Choice forced between
  indistinguishable options is unstable; merge them or add `not_for` to each.
- Leads are multilingual and unvalidated, or arrive as attachments rather than text.

## Alternatives considered

- **CRM routing rules on form fields.** The incumbent, and correct for everything the fields
  capture. This handles the free-text box and the miscategorised submissions.
- **Round-robin to everyone.** Fair, fast, and it puts enterprise procurement questions in
  front of whoever is next.
- **Frontier LLM router.** Better on ambiguous mixed messages, at seconds and cents per lead
  and with an answer you must parse into a route that exists.
- **Small LLM.** Roughly an order of magnitude on both cost and latency from the measurements
  above, plus occasional parse failures.
- **Fine-tuned classifier on historical routing.** Learns where leads *were* sent, including
  every historical misroute, and needs a retrain whenever a team is added.
- **SDR manually triaging the queue.** The fallback the low-confidence band preserves.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `patterns/intent-routing.md`,
`patterns/confidence-routing.md`, `patterns/fan-out.md`,
`cookbooks/consistency_noul_cookbook.md` and `cookbooks/consistency_choice_cookbook.md`
(latency per condition, sampled 2026-09-11), `model-jaggedness/jev-1.13.md`, `models.md`.
