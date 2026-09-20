---
id: uc-observability-evals-confidence-threshold-calibration-fitting
title: Fit the confidence threshold per question on your own labelled rows before you gate anything
verdict: good
domain: observability-evals
decision_shapes: [verification, scoring, routing]
primitives: [noul, score, choice]
evidence_level: community-report
sources:
  - https://github.com/abhixhek/jevcal  (threshold fitting per question; "~100+ labelled rows per question"; reports accepted accuracy, coverage and ECE; "identical requests may vary slightly")
  - https://github.com/FirasSX914/Janus  (Banking77 threshold 0.67 -> 80.2% accuracy, -53% cost, p50 302 ms, 11.6% escalation; Web of Science "DO NOT ROUTE")
  - https://github.com/yodablocks/jev-orderby-bench  (ECE 0.045 on 20 Newsgroups vs 0.242 on Amazon ESCI with the same primitive)
  - https://github.com/wotai-dev/typesafe-jev-tools  (ECE 0.121 on 149-row decision triage; abstains 34.7%)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-observability-evals-rubric-scoring-llm-judge-replacement, uc-agents-harness-confidence-escalation-to-frontier-model, uc-search-retrieval-confidence-fallback-broader-level, uc-insurance-straight-through-vs-adjuster-routing, au-zero-hallucination-means-always-right, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to fit a confidence threshold for jev, and how?" Also: "what threshold
should we use — 0.8?", "how many labelled rows do we need before we can automate?", "our
threshold worked on the pilot dataset, can we ship it?"

## Verdict

**Good**, and it is the one thing in this corpus you should not skip — the shape is
demonstrated by public threshold-fitting tools and the confidence docs; no task-matched
labelled accuracy is published; shadow-evaluate against the incumbent before acting.
Every other entry that says "above the threshold, automate" depends on a threshold that
was fitted on *your* labelled rows, for *that* question, and re-fitted when the question
changes. A public tool exists for exactly this workflow and states the data requirement
plainly: **"~100+ labelled rows per question"**, reporting accepted accuracy, coverage
and ECE per candidate threshold (github.com/abhixhek/jevcal). Note what is being decided
here: **jev is the thing being measured, not the decider.** This entry describes an
offline measurement workflow you run before a rollout and re-run after every criterion
edit.

## What jev decides

Nothing new — you run the *same* request you intend to ship, unchanged, over a labelled set.
What the workflow produces is a table, and the shape of that table is the deliverable:

```
for t in [0.50, 0.55, ... 0.99]:
    accepted   = rows where p >= t
    coverage   = |accepted| / |all rows|          # how much you automate
    accuracy   = correct(accepted) / |accepted|   # how good the automated part is
    ece        = calibration error over all rows  # is p honest at all
```

Read it as a curve, not a number. You are choosing the point where `accuracy` clears the bar
your business set and `coverage` is still worth the integration. A threshold with 99%
accepted accuracy at 4% coverage is a nice slide and a useless deployment.

Three properties of jev make this workable and each has a catch. The probability is intended
to be calibrated — but measured ECE across published tasks ranges from **0.045** on 20
Newsgroups topic membership to **0.121** on a 149-row decision-triage set to **0.242** on
Amazon ESCI product relevance, with the *same* primitive and model version. The output is
typed, so the harness is trivial. And the model is cheap enough to run the whole fitting
sweep repeatedly — but **"identical requests may vary slightly"**, so fit on more than one
run of the same rows.

## What stays in code

The labelled set and its provenance. The sweep. The accuracy, coverage, ECE and Brier
arithmetic — all of it, because none of it is a judgement. The stored threshold, versioned
alongside the question text and the model version, so that editing a criterion invalidates
the threshold automatically. The shadow-mode logger that keeps producing labelled rows after
launch. The alarm that fires when live coverage drifts from fitted coverage.

## Numbers

The strongest published warning against reusing a threshold is the Janus routing study. On
Banking77 it found a threshold of **0.67** giving **80.2% accuracy, −53% cost, p50 302 ms and
11.6% escalation** — a clear win. On Web of Science, with the same method, its conclusion was
**"DO NOT ROUTE"**: no threshold beat the single best model. The study's own summary is the
line to remember — "a default threshold would therefore be wrong roughly as often as it was
right" (github.com/FirasSX914/Janus).

Cost of the fitting run itself: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`,
output free. 500 rows at ~1,200 tokens each is 600,000 tokens, **≈ $0.025 per sweep** — the
labels cost money, the calls do not. Budget for the annotation, not the API.

Closest jaggedness mode: **8, overconfidence on out-of-distribution input.** The fitting
workflow is the only defence, and it only defends the distribution you fitted on.

## When the verdict flips

It does not flip to weak — but the *result* can say no, and you must be willing to publish
that. Concretely:

- **The curve has no acceptable point.** Accuracy never clears the bar at any coverage worth
  having. Then the answer for that decision is "do not adopt", like Web of Science.
- **Fewer than ~100 labelled rows per question.** You have not fitted a threshold, you have
  fitted noise. Stay advisory and keep logging.
- **You reuse a threshold across datasets, tenants or languages.** That is
  `au-zero-hallucination-means-always-right` territory and the Janus result is the direct
  counter-example. Re-fit per dataset.
- **The question text changed.** A criterion edit invalidates the threshold. Treat them as
  one versioned artefact.
- **The decision is irreversible.** A fitted threshold does not make a ban, a payment or a
  deletion safe; see `au-payments-and-access-control-decision`.

## Alternatives considered

- **A default threshold (0.8, 0.85, 0.9).** The thing everyone does and the thing Janus
  measured as unsafe. Free, fast, wrong about half the time.
- **Vendor-published calibration.** Does not substitute for yours; the independent ECE spread
  across tasks is 0.045 to 0.242 on the same model.
- **Two-model agreement instead of a threshold.** Works, costs a second call, and gives you a
  binary rather than a tunable coverage knob.
- **Always escalate to a human.** Correct while you collect the 100 rows; that is what
  advisory mode is for.
- **Isotonic or Platt recalibration on top of the probability.** Legitimate and cheap once you
  have the labelled set; worth trying before you conclude the curve is unusable.

## Sources

- https://github.com/abhixhek/jevcal — accessed 2026-09-19 ("~100+ labelled rows per
  question"; accepted accuracy, coverage, ECE; "identical requests may vary slightly")
- https://github.com/FirasSX914/Janus — accessed 2026-09-19 (0.67 / 80.2% / −53% / 302 ms /
  11.6% on Banking77; "DO NOT ROUTE" on Web of Science)
- https://github.com/yodablocks/jev-orderby-bench — accessed 2026-09-19 (ECE 0.045 vs 0.242)
- https://github.com/wotai-dev/typesafe-jev-tools — accessed 2026-09-19 (ECE 0.121, 149 rows)
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
