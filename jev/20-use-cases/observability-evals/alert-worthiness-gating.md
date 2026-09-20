---
id: uc-observability-evals-alert-worthiness-gating
title: Decide whether an event pages a human now, waits for the digest, or stays silent
verdict: good
domain: observability-evals
decision_shapes: [scoring, routing, classification]
primitives: [score, noul]
evidence_level: community-report
sources:
  - https://github.com/Nishfleet/0509/issues/3539  (Score 0-3 "worth_alert" against alert fatigue; "551 -> 18" monthly alerts; advisory only)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 context rot: send only what the question needs)
related: [uc-sdlc-api-error-log-triage, uc-sdlc-dependency-alert-triage, uc-support-urgency-detection, uc-observability-evals-confidence-threshold-calibration-fitting, au-sole-security-gate]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to decide which alerts are worth paging someone about?" Also:
"our on-call gets 500 notifications a month and reads none of them — can a model triage
them?", "can jev build the daily digest and leave the real pages alone?", "can we replace the
severity field nobody sets correctly?"

## Verdict

**Good.** One public deployment specifies exactly this decision: a Score 0-3 named
`worth_alert` introduced to fix alert fatigue, reported as taking the volume from
"551 → 18 monthly alerts", and run **advisory only**
(github.com/Nishfleet/0509/issues/3539). The shape is right — a short, self-contained event
description, an ordinal answer, and a routing decision that code makes from the band. It is
`good` and not `strong` for one reason worth stating plainly: **551 → 18 is a reported volume
outcome from a single deployment, not a measured precision or recall.** Nobody has published
how many of the 533 suppressed events should have paged somebody. That is the number that
decides whether this is safe, and you have to produce it yourself.

Closest failure mode: **literal reading** — an event's wording ("timeout", "critical") is not
its operational impact, so the Score criteria describe who is affected and what breaks, and
code owns the band that routes to a page, the digest or silence.

## What jev decides

State is one normalised event: `title`, `source_system`, `first_seen_message` (truncated),
`affected_component`, `environment`, and `is_recurring` as a boolean computed in code. Not
the raw payload, not the stack trace, not the last hour of logs — mode 5 is the failure that
kills this use case.

```
worth_alert: Score
  instructions: {question: "How much does this event need a person to look at it now?",
                 focus: "Judge the consequence of nobody seeing this until tomorrow."}
  criteria:
    - "Nobody needs to see it. Informational, expected, or self-healing."
    - "Worth reading in a daily digest. Someone should know, but not now."
    - "Worth a working-hours ping to the owning team."
    - "Worth waking someone. Users are affected now, or will be within the hour."

user_facing: Noul
  instructions: "Does this event describe something a user of the product would notice?"

already_mitigated: Noul
  instructions: "Does the event text itself say the condition has recovered, been retried
                 successfully, or been handled?"
```

Bands, in code: score in the top band, or `user_facing` above your fitted threshold, pages as
today. Middle bands go to the digest. Bottom band is logged. **The low-confidence path is not
"suppress" — it is today's behaviour.** A suppressed page is the failure that matters and it
is silent; a spurious page is noisy and visible. Design the asymmetry in deliberately.

## What stays in code

Deduplication and grouping (call once per *group*, not per occurrence), rate limits, the
escalation policy, the on-call schedule, maintenance windows, the "this service is in a known
incident" flag, and any alert with an explicit SLO breach attached — that one is arithmetic
and pages unconditionally, whatever jev says. Also: the digest assembly, the delivery, and
the shadow log.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A normalised
event of ~800 characters plus three questions with criteria (~1,600 characters) is about
600 tokens, **≈ $0.000025 per alert group**. Field evidence: the deployment reports the
design target and outcome as "551 → 18 monthly alerts" under an advisory-only rollout
(github.com/Nishfleet/0509/issues/3539). At 551 events a month the model spend is about
$0.014 — the cost is not the interesting variable here, the miss rate is.

Latency does not matter for this decision and should not be used to justify it: an alert
pipeline has seconds to spare. What jev buys is per-event judgement at a price where you can
afford to run it on every event rather than on a sample.

Labelled data arrives free: which alerts were acknowledged, which were actioned, which were
snoozed, and — the one that counts — which incidents were discovered by a customer rather
than by the alert. Fit the page threshold against the last of those.

## When the verdict flips

- **You have not measured the suppressed tail.** Until you know how many of the suppressed
  events should have paged, this stays advisory. Run it in shadow and read the diff.
- **A regulated or safety alert is in the stream.** Those page unconditionally from code.
  Putting them behind a probability makes this `no`; see `au-sole-security-gate`.
- **Your alerts already carry a correct severity.** Then routing is a lookup and jev is a
  network call in the way.
- **The signal is in the metric, not the text.** If worthiness is "error rate above 2% for
  5 minutes", that is arithmetic — `au-numeric-thresholds-and-arithmetic`.
- **Event text is templated and near-identical.** A rules table will match it exactly and for
  free.

## Alternatives considered

- **Severity fields and routing rules.** The incumbent. Exact and free where they are
  maintained; the reason for alert fatigue is that they are not.
- **Deduplication and rate limiting alone.** Cheapest real fix and usually underused. Do it
  first; it removes volume without judgement risk.
- **Frontier LLM.** Can write the digest summary, which jev cannot. Affordable at 551 events
  a month, so the cost argument is weak here — the argument for jev is a typed probability,
  trained to be calibrated, that you can threshold once you have measured calibration on your
  own alerts.
- **Small LLM.** Comparable labels. A below-threshold "unsure" route needs logprobs or a
  self-reported score; set the same policy on both before comparing, because without one a
  small LLM silences a page confidently.
- **Fine-tuned classifier on acknowledgement history.** Strong once you have the labelled
  rows, and the shadow log produces them.
- **Human triage rota.** What the 551 alerts were supposed to be. It does not scale, which is
  the problem being solved.

## Sources

- https://github.com/Nishfleet/0509/issues/3539 — accessed 2026-09-19 (Score 0-3
  `worth_alert`, "551 → 18 monthly alerts", advisory-only rollout)
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
