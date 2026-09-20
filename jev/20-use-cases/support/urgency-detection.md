---
id: uc-support-urgency-detection
title: Detect how urgent an inbound support ticket is
verdict: good
domain: support
decision_shapes: [scoring, detection]
primitives: [score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (customer support: "Detect urgency, frustration, churn risk, and refund requests")
  - https://docs.typesafe.ai/patterns/fan-out.md  (`bug_severity` as a 3-level Score riding along with the category Choice)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 2: "do not use score outputs to compute the exact magnitude of a number between two levels")
  - https://docs.typesafe.ai/primitives/score.md  (Score takes 2 to 10 ordered level descriptions)
related: [uc-support-frustration-scoring, uc-support-ticket-team-routing, uc-support-churn-risk-signal]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to work out how urgent a ticket is?" Also "can jev set
priority on new tickets?", "can we stop using the `URGENT!!` keyword rule?", and "can jev
tell a P1 from a P3?".

## Verdict

**Good.** Urgency as *described impact* is an ordered rubric over one short text, which is
exactly what Score is for, and the use-case map names urgency detection directly. It is
`good` rather than `strong` because no published cookbook runs this task end to end, and
because the common failure is not the model but the rubric: teams write "1 to 5, how urgent"
and get a number with no meaning. Levels must describe concrete situations. Separate
*urgency* (how bad is the impact, and how soon) from *frustration* (how the customer feels);
they correlate loosely and conflating them produces a priority driven by tone.

## What jev decides

State: `ticket.subject`, `ticket.message`, and — only if your rubric references it — the
account's plan tier and whether the product is currently in a production incident. Nothing
else.

```
impact: Score
  instructions: {question: "How much is the customer's described problem blocking them right now?",
                 inspect: "`ticket.message`",
                 focus: "Judge the described impact on the customer's work, not their tone."}
  criteria:
    - {what: "A question, a request, or a cosmetic annoyance. Nothing is blocked."}
    - {what: "A feature is degraded or broken but the customer describes a workaround they can use."}
    - {what: "A feature the customer needs is unusable and no workaround is described."}
    - {what: "The customer cannot use the product at all, or money, data, or a live customer-facing
              service of theirs is affected right now."}

deadline_stated: Noul
  instructions: "Does `ticket.message` state a specific external deadline or event the customer
                 must meet, such as a launch, an audit, or a shipment?"
  criteria: {true: "Names a dated or imminent external commitment",
             false: "Expresses impatience without naming a commitment"}

security_or_data_loss: Noul
  instructions: "Does `ticket.message` report data loss, data exposure, or unauthorised access?"
```

Three signals, one call, alongside the routing Choice. Code composes them. The Score's
`confidence` gates whether the suggested priority is applied or only suggested; the fan-out
pattern page reads `bug_severity.score > 1.5` together with a second Noul before escalating,
and the same guard applies here.

## What stays in code

Everything numeric and contractual. SLA clocks, business-hours arithmetic, "the customer has
been waiting 26 hours" — dates are failure mode 3 and must never be a question. Plan-tier
floors ("enterprise never starts below P2"), incident-linked auto-escalation, and the final
priority field write are deterministic. A reasonable composition:
`priority = max(tier_floor, band(0.6*impact/3 + 0.2*deadline_stated + 0.2*security_or_data_loss))`,
with the weights in a config file, per the composite-scoring pattern.

## Numbers

Method as in the cost model: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A
900-character ticket plus these three questions (~1,100 characters) is ≈ 500 tokens, about
**$0.000021 per ticket**, and it is free to attach them to the routing call you are already
making — the parallel-questions cookbook measured 13 questions in one call as 12.2x cheaper
and 10.0x faster than 13 separate calls, with the same answers. Latency 70–500 ms. No
published accuracy for urgency; validate by replaying historical tickets against the
priority a human eventually settled on, and report agreement, not accuracy.

## When the verdict flips

- You ask for "urgency on a scale of 1 to 10" and then use the returned number as a
  magnitude. The jaggedness page is explicit that Score levels are weakly calibrated
  numerically and must not be interpolated. Use the score to threshold or rank only.
- Urgency in your business is defined by contract, not by text (severity is whatever the
  SLA matrix says for that account and product). Then it is a lookup and jev adds nothing.
- Urgency determines a paging decision with no human in the loop. Keep a deterministic
  floor; a Score is a suggestion, not a pager.
- Customers learn that writing "URGENT" changes priority. Adversarial framing moves the
  answer (failure mode 6) and the rubric wording must resist it — hence "described impact,
  not tone".

## Alternatives considered

- **Keyword list (`urgent`, `asap`, `down`).** Cheap, and precisely what customers game.
  It cannot tell "the site is down" from "I was down with flu".
- **Frontier LLM.** Same judgement, seconds and cents; the reason to prefer jev is that this
  runs on every ticket at creation time.
- **Small LLM.** Viable. The noul-consistency cookbook found LLM probabilities moving between
  repeats even at temperature 0, while jev's mean per-question standard deviation was 0.0102 —
  but the choices cookbook's run went the other way, with `claude-haiku-4-5` at temperature 0
  the more repeatable condition (100.0% against 90.8% raw, SD 0.0012 against 0.0098). Scope any
  stability claim to the configuration you test on your own tickets.
- **Fine-tuned classifier on historical priorities.** Learns your past priority *behaviour*,
  including its biases; useful as a complement, and it cannot be reconfigured by editing text.
- **Human triage.** Still the destination for the low-confidence band.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `patterns/fan-out.md`,
`model-jaggedness/jev-1.13.md` (score-magnitude and date warnings),
`primitives/score.md`, `cookbooks/parallel_questions.md` (12.2x / 10.0x),
`cookbooks/consistency_noul_cookbook.md` (0.0102 mean std dev, sampled 2026-09-11),
`models.md` (price, latency).
