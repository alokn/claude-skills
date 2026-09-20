---
id: uc-sales-marketing-buyer-intent-detection
title: Detect buyer intent and pain points in an inbound message
verdict: good
domain: sales-marketing
decision_shapes: [detection, classification, feature-extraction]
primitives: [noul, choice, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (lead generation: "Detect buyer relevance, pain points, and purchase intent"; demand forecasting: "Extract purchase intent, urgency, and product interest")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (decompose: atomic questions rather than one broad judgement)
  - https://docs.typesafe.ai/patterns/fan-out.md  (every question the decision tree might need, in one call)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 1: literal reading; failure mode 8: ask each decision one way)
related: [uc-sales-marketing-icp-fit-scoring, uc-sales-marketing-lead-routing, uc-trust-safety-opt-out-request-detection]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to detect buying intent in inbound messages?" Also "can jev tell
a demo request from a support question?", "can we find the pain point in a contact-form
message?", and "can jev score reply sentiment on our outbound sequences?".

## Verdict

**Good.** Inbound messages are short, the signals are stated rather than inferred, and the
decisions they drive — reply now, nurture, ignore, suppress — are reversible with an obvious
human band. The use-case map names buyer relevance, pain points and purchase intent together,
and they are three different questions: someone can state a pain with no intent to buy, and
someone can ask for pricing with no relevant pain. Decomposed into atomic Nouls, each maps to
one thing a person actually wrote. It is `good` rather than `strong` because no cookbook runs
it and because "intent" is the single most over-claimed concept in this domain: what jev
detects is *expressed* intent, which is a different and much more honest quantity than
predicted propensity.

## What jev decides

State: the message body, the form fields the sender filled in, and a one-line description of
what you sell so "we need this" is interpretable. Not the enrichment record — firmographics
are a separate signal, and mixing them in invites the model to reason about fit instead of
intent.

```
requests_sales_contact: Noul
  instructions: "Does the sender ask to speak to sales, see a demo, or discuss pricing?"
  criteria:
    true:  {what: "Asks for a conversation, a demo, a quote, or pricing",
            examples: ["Can someone walk us through it?", "What does this cost for 200 seats?"]}
    false: {what: "No such request",
            not_for: "A support question from an existing user, or a general enquiry"}

states_a_pain_we_address: Noul
  instructions: "Does the message describe a problem that `our_product.problem_statement`
                 addresses?"

evaluation_stage: Choice
  instructions: "Where in an evaluation does this message place the sender?"
  criteria:
    unaware:      "Asks a general question with no problem stated"
    problem_aware:"States a problem, no solution mentioned"
    solution_aware:"Comparing approaches or asking how the product works"
    vendor_select:"Comparing named vendors, asking about pricing, security, or procurement"
    not_a_buyer:  "Support request, job enquiry, partnership pitch, or spam"

timeline_stated: Noul
  instructions: "Does the message name a time by which they need this resolved or in place?"

is_existing_customer_support: Noul
  instructions: "Is this a support request from someone who already uses the product?"

is_vendor_pitch_or_spam: Noul
  instructions: "Is the sender selling something to us rather than enquiring about our product?"
```

The last two are the volume: on most contact forms, support requests and vendor pitches
outnumber buyers, and routing them away is where the time is saved. Bands: act on
`requests_sales_contact >= 0.6`; `evaluation_stage` at `confidence >= 0.7` selects the
nurture track, below that it goes to the default track rather than a guessed one.

## What stays in code

Assignment, sequencing and suppression. Territory rules, round-robin, existing-opportunity
checks, do-not-contact and opt-out state are deterministic and authoritative — the opt-out
list in particular must never be overridden by an intent score. Lead scoring arithmetic,
decay over time, and "how many times have they visited pricing" are counts and dates: code.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 600-character message plus
these six questions with criteria (~1,900 characters) is ≈ 625 tokens, **≈ $0.000026 per
inbound**. Six questions in one call is the published saving: 13 questions batched measured
12.2x cheaper and 10.0x faster than sequential, with identical means on 11 of 13 and the other
two within 0.01. Latency 70–500 ms, fast enough to route before the auto-reply is sent, which
is the placement that changes response time. No published accuracy for intent detection.
Validate against your own outcome data — meetings booked by predicted stage — and report the
false-negative rate on `requests_sales_contact` separately, because a missed buyer is the
expensive error and a wrongly routed vendor pitch is not.

## When the verdict flips

- You call it "intent" and mean propensity to buy. Propensity needs outcomes and a model; this
  reads what someone wrote. Conflating them produces a forecast nobody should trust.
- The form already has a "reason for contact" dropdown that people fill in honestly. Lookup.
- The score triggers automated outbound. Then a false positive is a cold email to someone who
  asked a support question, and the opt-out and suppression rules must sit in front, in code.
- Messages are mostly non-English, unvalidated.
- You ask "is this a good lead?". One question, four judgements, nothing to tune — the docs'
  standing anti-pattern.

## Alternatives considered

- **Form fields and routing rules.** Free and exact when filled in truthfully; most of the
  signal is in the free-text box, which is why this exists.
- **Keyword rules ("pricing", "demo").** Fire on "your pricing page is broken", which is a
  support ticket.
- **Third-party intent data.** Measures third-party browsing, not what this person said; it
  answers a different question and is complementary.
- **Frontier LLM per inbound.** Excellent, and at inbound volume the cost is arguable rather
  than obvious; the stronger objection is latency in the routing path.
- **Small LLM.** Roughly an order of magnitude more cost and latency per multi-question call
  on the consistency cookbooks' measurements, plus parse failures where a Choice cannot fail.
- **Trained lead-scoring model.** The right end state with enough closed-won history, and
  jev's probabilities make good features for it.
- **SDR reading every inbound.** The baseline, and the destination for the uncertain band.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `concepts/how-to-build-with-system-one.md`,
`patterns/fan-out.md`, `model-jaggedness/jev-1.13.md` (modes 1 and 8),
`cookbooks/parallel_questions.md` (12.2x / 10.0x), `models.md`.
