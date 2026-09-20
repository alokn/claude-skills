---
id: uc-support-frustration-scoring
title: Score how frustrated a customer is in a support message
verdict: good
domain: support
decision_shapes: [scoring]
primitives: [score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/patterns/fan-out.md  (`frustration` Score with levels "Calm, matter-of-fact", "Frustrated but civil", "Very angry"; `frustration.score > 1.5` flags a priority response)
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (the same Score with structured `signals` per level, and a `confidence >= 0.7` gate)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (customer support: detect frustration; gaming: "score frustration or engagement")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 2: score levels are weak in numerical calibration)
related: [uc-support-urgency-detection, uc-support-churn-risk-signal, uc-commerce-review-sentiment-rubric]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to score customer frustration?" Also "can jev replace our
sentiment API on support messages?", "can we flag angry customers before an agent opens the
ticket?", and "how do we measure tone across a conversation?".

## Verdict

**Good** — the shape is demonstrated by the fan-out pattern page and the how-to-build
guide; no task-matched labelled accuracy is published; shadow-evaluate against the
incumbent before acting. TypeSafe's own pattern page and its full worked triage function
both use exactly this question — a three-level frustration Score read off the ticket
message — and route on it. Frustration is a position on an ordered rubric over short
text, which is the definition of the Score primitive, and the output feeds a reversible
action (flag for a priority response) with an obvious low-confidence path. The one
discipline required: score the *expressed emotion*, not the severity of the issue, and
never treat the returned number as a magnitude.

## What jev decides

State: the customer's own turns only. Filter out agent replies, signatures, quoted history
and boilerplate in code before the call; agent apologies are the classic distractor and this
is failure mode 5. For a thread, send the last two or three customer messages as an array.

```
frustration: Score
  instructions: {question: "How frustrated does the customer appear?",
                 inspect: "`ticket.message`",
                 focus: "Judge expressed frustration, not issue severity."}
  criteria:
    - {what: "Calm and matter-of-fact",
       signals: ["Neutral wording", "No complaint about the experience"]}
    - {what: "Frustrated but civil",
       signals: ["Expresses annoyance", "Remains constructive"]}
    - {what: "Very angry or threatening to leave",
       signals: ["Hostile language", "Threatens cancellation or churn"]}
```

Three levels is the published shape; Score accepts 2 to 10. Add a fourth only if you can
write a concrete situation for it — "somewhat frustrated" is not a level. Two companions
worth riding along in the same call: `abusive_towards_agent` (Noul, because abuse needs its
own handling path and is not simply "more frustrated") and `repeat_contact_complaint`
(Noul — "Does the message complain about having to ask more than once?"), which is the single
best predictor of a bad experience and is not visible in tone alone.

Bands: the docs' worked example uses `frustration.confidence >= 0.7 and frustration.score >=
1.5` to set a high priority. Below the confidence floor, record the score as telemetry and
change nothing.

## What stays in code

The action. Whether a flagged ticket jumps the queue, pages a lead, or suppresses an
automated macro is a policy decision with cost attached. Trend lines, per-account averages,
and any aggregation across tickets are arithmetic and belong in code — including the decision
of what "rising frustration" means, which is a comparison of two stored numbers, not a
question for the model.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 900-character message plus
this Score written out with `signals` (~600 characters) is ≈ 375 tokens, **≈ $0.000016 per
message**, and effectively free when attached to a triage call you already make. Latency
70–500 ms, so it fits in the ticket-create request path. Stability: the noul-consistency
cookbook reported a mean per-question probability standard deviation of `0.0102` for jev
across 15 repeats of a 14-question rubric on one document (sampled 2026-09-11), and the
choice cookbook `0.0098` across 15 repeats of an 8-Choice rubric — relevant here because a
tone score that moves between runs makes a flag untrustworthy. No published accuracy for
frustration; agreement with human raters is the metric to collect, and human raters
disagree with each other on this task too.

## When the verdict flips

- You use `score` as a number in an arithmetic formula or report "average frustration 2.34".
  The jaggedness page states score levels are "weak in numerical calibration" and must not be
  interpolated. Threshold or rank only; if you need finer resolution, add levels with concrete
  descriptions.
- The population is mostly non-English. Tone is the judgement most sensitive to language;
  English is `jev-1.13`'s strongest language and this one needs your own evaluation per locale.
- Frustration drives a customer-visible action such as an automatic goodwill credit. That is
  a money decision and needs a deterministic rule plus, at most, jev as one input.
- You are scoring voice or video. Text only; a transcript loses the signal that matters most.

## Alternatives considered

- **Sentiment library / cloud sentiment API.** Fixed positive/neutral/negative taxonomy that
  does not distinguish "annoyed at the product" from "angry at us", and no criteria you can
  edit. This is the case the primer describes as a fixed taxonomy replaced by your own rubric.
- **Keyword / profanity lists.** Detect abuse, not frustration; a polite cancellation threat
  scores zero.
- **Frontier LLM.** Better nuance on long threads, at seconds and cents per message, for a
  signal you want on every message.
- **Small LLM.** Close on quality; the consistency cookbooks measured 1,485–3,860 ms and
  $0.00095–$0.0035 per rubric call for `claude-haiku-4-5` against 111 ms and $0.000043 for jev.
- **Fine-tuned regressor on CSAT.** Predicts satisfaction, a different and more valuable
  target if you have the labels — and jev's probabilities make good features for it
  (the autoresearch cookbook shows that pattern).

## Sources

Accessed 2026-09-19. `patterns/fan-out.md`, `concepts/how-to-build-with-system-one.md`,
`concepts/use-case-map.md`, `model-jaggedness/jev-1.13.md`,
`cookbooks/consistency_noul_cookbook.md` and `cookbooks/consistency_choice_cookbook.md`
(std dev and latency, sampled 2026-09-11), `models.md`.
