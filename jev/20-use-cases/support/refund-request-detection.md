---
id: uc-support-refund-request-detection
title: Detect whether a support message actually requests a refund
verdict: good
domain: support
decision_shapes: [detection]
primitives: [noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (`refund_requested` Noul with true/false criteria and the `not_for` "a complaint or billing question without a requested remedy")
  - https://docs.typesafe.ai/patterns/fan-out.md  (`refund_requested` read only on the billing branch; acted on at `noul > 0.7`)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 8, worked on this exact question: Noul 0.22 vs Choice yes 0.01 on "I'm not happy with the fit")
  - https://docs.typesafe.ai/concepts/use-case-map.md  (customer support: detect refund requests)
related: [uc-support-policy-supports-request, uc-support-ticket-team-routing, uc-commerce-return-reason-classification]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to detect refund requests?" Also "can jev tell us which
billing tickets are asking for money back?", "can we auto-flag refund intent on ticket
creation?", and "can jev trigger the refund workflow?".

## Verdict

**Good** for detecting the request; **never** for granting it — the shape is
demonstrated by the how-to-build guide and the fan-out pattern page; no task-matched
labelled accuracy is published; shadow-evaluate against the incumbent before acting. The
docs use this exact Noul in their worked triage function and the fan-out pattern reads
it at `noul > 0.7` to flag a billing ticket. It is a single-hop, absolute yes/no about
the text in front of the model, with a written boundary that matters commercially: a
complaint about a charge is not a refund request. The jaggedness page uses this very
question to show that a Noul and a yes/no Choice are not interchangeable — ask it one
way, as a Noul, in the direction you will threshold.

## What jev decides

State: `ticket.message` only (plus `ticket.subject` if your channel splits them). The order
record is not needed to answer "did they ask".

```
refund_requested: Noul
  instructions: {question: "Does the customer explicitly request a refund or credit?",
                 inspect: "`ticket.message`",
                 focus: "Require a requested remedy, not a billing complaint alone."}
  criteria:
    true:  {what: "Directly asks for money back or an account credit",
            examples: ["Please refund the duplicate charge", "Can I get my money back?"]}
    false: {what: "Does not ask for a refund or credit",
            not_for: "A complaint or billing question without a requested remedy",
            examples: ["Why was I charged twice?", "This is not what I ordered"]}
```

Companions in the same call, because the branches differ: `cancellation_requested`
("Does the customer ask to cancel a subscription or order?"), `chargeback_threatened`
("Does the customer say they will dispute the charge with their bank or card issuer?"), and
`duplicate_charge_claimed`. Each is its own Noul — this is a multi-label problem, and the
primer's rule is one Noul per label, not a Choice.

Bands: the docs act at `0.7`. Below `0.3`, do nothing. `0.3–0.7` attaches "possible refund
request" to the ticket for the agent to confirm. Do not carry this threshold to any Choice
question (failure mode 8), and do not assume `P(refund) + P(not refund) = 1` — the
jaggedness page shows those two Nouls summing to 1.19 on one ticket.

## What stays in code

The refund. Eligibility, the amount, the window, the payment-processor call, and the
approval rule are deterministic and authoritative. Jev tells you a human or a workflow
should look at this ticket as a refund; it does not decide that one is owed and it must not
be the only thing standing between a message and a payment. Amounts are arithmetic
(failure mode 2) and windows are dates (failure mode 3): both belong in code.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 900-character message plus
four refund-family Nouls with criteria (~1,200 characters) is ≈ 525 tokens, **≈ $0.000022 per
ticket**; attached to the triage call it is a few tokens of marginal cost, because the state
is already paid for. Latency 70–500 ms. Published data point on the primitive's behaviour, not
its accuracy: on "I'm not happy with the fit. What are my options here?" the docs report
Noul `0.22` against a yes/no Choice giving `yes` `0.01` at confidence `0.97` — the same
judgement, two incomparable numbers. No accuracy figure is published for refund detection.
Backtest against tickets that actually resulted in a refund being issued, and report
precision at your chosen threshold.

## When the verdict flips

- You wire the Noul directly to issuing money. Then it is a sole safety-and-money gate and
  the verdict is **no**.
- Your refund intent arrives as a structured button click in the product. Deterministic.
- You need the *amount* as well as the intent. That is extraction: have a regex enumerate
  candidate amounts and let jev pick with a Choice (the pre-parsed value extraction
  cookbook), and never ask jev for the figure directly.
- You need "has the refund window expired". Dates: extract parts with Choice if you must,
  compare in code.

## Alternatives considered

- **Regex for "refund", "money back", "chargeback".** High recall, poor precision: "no refund
  needed, just fix it" and "I read your refund policy" both fire. Maintenance is endless.
- **Frontier LLM.** Handles the same nuance; at seconds and cents per ticket for a signal you
  want on every billing ticket, and it returns prose you must parse.
- **Small LLM.** Reasonable; the consistency cookbooks measured 10–125x higher latency and
  22–805x higher cost per rubric call than jev on comparable multi-question rubrics, and
  jev's probabilities were more stable across repeats.
- **Fine-tuned classifier.** Strong if you have labelled refund outcomes; it also learns
  whatever your agents did historically, which is not the same as what customers asked for.
- **Human review of every billing ticket.** What this replaces at the top and bottom bands,
  and keeps in the middle.

## Sources

Accessed 2026-09-19. `concepts/how-to-build-with-system-one.md` (the question verbatim),
`patterns/fan-out.md` (0.7 threshold), `model-jaggedness/jev-1.13.md` (Noul/Choice table;
0.72 + 0.47 = 1.19 example), `concepts/use-case-map.md`,
`cookbooks/pre_parsed_value_extraction_cookbook.md` (amounts as Choice over regex candidates),
`models.md`.
