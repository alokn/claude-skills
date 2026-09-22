---
id: uc-trust-safety-user-report-triage
title: Triage a user-reported post into the right moderation queue
verdict: good
domain: trust-safety
decision_shapes: [classification, routing, scoring]
primitives: [choice, score]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md  (8-Choice triage rubric on a reported post carrying `user_reports: 4` with reasons `["harassment","spam","threat"]` and `prior_strikes: 1`; 15 repeats; 114 ms, $0.000046 per call; 0.60 top-probability abstain band raises decision agreement 90.8% -> 99.2% with 25.8% uncertain)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (moderation and trust and safety; "Combine severity and confidence to allow, warn, review, or block")
  - https://docs.typesafe.ai/patterns/fan-out.md  (all the questions the decision tree might need, in one call)
  - https://docs.typesafe.ai/confidence.md  (three bands)
related: [uc-trust-safety-toxicity-harassment-detection, uc-trust-safety-policy-violation-bands, uc-support-intent-routing-handlers]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to triage the moderation report queue?" Also "can jev decide
which reports a human needs to see?", "can we route threats to the threat queue
automatically?", and "our report backlog is days deep — can jev sort it?".

## Verdict

**Good** — the shape is demonstrated by the choice-consistency cookbook, which measures
repeatability and not correctness; no task-matched labelled accuracy is published;
shadow-evaluate against the incumbent before acting. The choice-consistency cookbook is,
in substance, this use case: a reported post with report reasons and author history
attached, eight Choice questions in one call covering category, primary risk, target,
action, queue, link handling, review path and severity, and a code-side abstain band. It
fits because the report queue already has a human destination — so the low-confidence
band costs nothing new — and because the value is in *ordering and partitioning* the
queue rather than emptying it. The published run shows what you get: zero conflicting
concrete labels across 15 repeats, and an abstain rule that converts near-ties into one
stable `uncertain` route.

Closest failure mode: **adversarial content** — reported posts are written to evade
moderation, so the post is carried as data rather than instructions, every question is scoped
to it, and the code-side abstain band sends near-ties to the human queue that already exists.

## What jev decides

State: the post text, the reporters' selected reasons, and the parent post if the report is
about a reply. Author history goes in as structured fields only if a question references it;
the counting is code's job.

```
primary_risk: Choice
  criteria: {harassment: "...", violence: "...", link_abuse: "...",
             account_history: "...", low_risk: "...", other: "..."}

queue: Choice
  criteria: {auto: "No human needed; the rule already settles it",
             general: "Ordinary policy call for a first-line moderator",
             threat: "Possible credible threat; needs the safety-trained queue",
             spam: "Commercial or automated abuse",
             ts_lead: "Novel, high-profile, or precedent-setting"}

review_path: Choice
  criteria: {auto: "...", human: "...", senior: "...", legal: "..."}

severity: Score
  criteria: ["No policy concern", "Minor", "Significant harm to an individual or group",
             "Threat, illegality, or risk to life"]

report_matches_content: Noul
  instructions: "Do the reasons in `report.reasons` describe what `post.text` actually contains?"

reporter_dispute_not_violation: Noul
  instructions: "Does `post.text` look like an ordinary disagreement being reported as a
                 policy violation?"
```

The last two are the ones that pay for the integration: most report queues are dominated by
reports that do not describe a violation, and separating those is worth more than grading the
ones that do. Bands, following the cookbook's illustrative rule: take the top label when its
probability is `>= 0.60`, otherwise route `uncertain` to the general human queue. The
cookbook is explicit that 0.60 is illustrative and that production thresholds should come
"using labeled examples and the cost of incorrect actions and human review".

## What stays in code

Enforcement, strike accumulation, report deduplication (ten reports on one post is one item),
reporter reputation weighting, the SLA clock, and the ordering of the queue itself. Anything
that counts — reports, strikes, account age in days — is arithmetic and is code, per failure
mode 2 and 3.

## Numbers

Measured (cookbook, one post, 8 Choice questions, 15 repeats, `jev-latest` resolving to
`jev-1.13.0` on all 15 calls, sampled 2026-09-11): **114 ms** mean round trip, **$0.000046**
per call, **0%** parse failures, mean probability standard deviation **0.0098**, max
single-label 0.0515. Under the 0.60 rule, decision agreement rose from 90.8% to 99.2%, with
25.8% of answers `uncertain` and 74.2% automatic, and "no question produced two different
concrete TypeSafe labels". Comparators in the same run: 826 ms to 13.0 s per call and
$0.00094 to $0.041 per call across six LLM conditions, at 84.2%–94.2% policy agreement (and
100% for Haiku at temperature 0). **Accuracy was not measured** — the cookbook states this
three separate times. For your own estimate: `(chars(state) + chars(questions)) / 4 ×
$0.042/1e6`.

## When the verdict flips

- The automatic band takes enforcement action with no sampling audit. Keep a sampled human
  read of the auto band; a triage system that is never checked drifts silently.
- Reports concern images or video. Text only.
- Your queue is small enough that a moderator reads everything within the SLA. Then this
  changes nothing (fit-test question 7).
- You tune the abstain threshold to maximise the automatic share. The threshold is a cost
  trade-off, and the cookbook warns that "a probability near 0.60 can still move between a
  concrete label and uncertain".

## Alternatives considered

- **First-in-first-out queue.** The status quo; severity-blind, so threats wait behind spam.
- **Report-reason routing.** Cheap and deterministic, and wrong whenever reporters pick the
  wrong reason — which `report_matches_content` is there to measure.
- **Frontier LLM triage.** Better judgement on novel cases, 10–13 s and ~3¢ per item in the
  cookbook's comparable conditions; use it on the `ts_lead` branch only.
- **Small LLM.** Competitive on quality; the cookbook's Haiku-at-temperature-0 condition beat
  jev on repeatability on this single post. The durable arguments are cost, latency, typed
  output and the abstain band, not accuracy.
- **Fine-tuned queue classifier.** Good with labels and a stable policy; re-trained every time
  the policy changes, which for trust and safety is often.

## Sources

Accessed 2026-09-19. `cookbooks/consistency_choice_cookbook.md` (rubric, 114 ms, $0.000046,
0.0098 std dev, 90.8% -> 99.2%, 25.8% uncertain, comparator table; sampled 2026-09-11;
accuracy explicitly not measured), `concepts/use-case-map.md`, `patterns/fan-out.md`,
`confidence.md`, `models.md`.
